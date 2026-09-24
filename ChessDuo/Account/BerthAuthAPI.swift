import Foundation

enum AccountError: LocalizedError {
    case network
    case server(status: Int, code: String, message: String)
    case invalid
    case cancelled

    var errorDescription: String? {
        switch self {
        case .network, .invalid: return L10n.t("error.network")
        case .cancelled: return nil
        case .server(let status, let code, let message):
            if status == 401 && message.localizedCaseInsensitiveContains("password") { return L10n.t("account.error.credentials") }
            if status == 401 && message.localizedCaseInsensitiveContains("code") { return L10n.t("account.error.code") }
            if status == 409 { return L10n.t("account.error.exists") }
            if code == "rate_limited" { return L10n.t("account.error.slowDown") }
            return message
        }
    }

    var isUnauthorized: Bool {
        if case .server(let status, _, _) = self { return status == 401 }
        return false
    }
}

struct AccountUser: Codable, Hashable {
    var id: String
    var email: String?
}

struct AccountSession: Codable {
    var user: AccountUser
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
}

/// Client for the app's end-user auth and owner-only tables. The publishable key rides in `apikey`
/// so `Authorization` can carry the signed-in user's access token.
struct BerthAuthAPI {
    private let baseURL: URL
    private let publishableKey: String
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
        let configured = Bundle.main.object(forInfoDictionaryKey: "ACCOUNT_API_URL") as? String
        baseURL = URL(string: configured ?? "https://api.atberth.com/v1/apps/chessduo")!
        publishableKey = Bundle.main.object(forInfoDictionaryKey: "API_PUBLISHABLE_KEY") as? String ?? ""
    }

    // MARK: - Auth

    func logIn(email: String, password: String) async throws -> AccountSession {
        try await sessionCall("auth/login", ["email": email, "password": password])
    }

    func requestCode(email: String) async throws {
        _ = try await call("POST", "auth/code", body: ["email": email])
    }

    func requestPasswordReset(email: String) async throws {
        _ = try await call("POST", "auth/recover", body: ["email": email])
    }

    func confirmPasswordReset(email: String, code: String, password: String) async throws -> AccountSession {
        try await sessionCall("auth/reset", ["email": email, "code": code, "password": password])
    }

    enum SignUpOutcome {
        case session(AccountSession)
        case verificationRequired
    }

    func signUp(email: String, password: String, name: String) async throws -> SignUpOutcome {
        let object = try await call("POST", "auth/signup", body: ["email": email, "password": password, "data": ["display_name": name]])
        if object["verification_required"] as? Bool == true { return .verificationRequired }
        guard let access = object["access_token"] as? String, let refresh = object["refresh_token"] as? String,
              let user = object["user"] as? [String: Any], let id = user["id"] as? String else { throw AccountError.invalid }
        let expiresIn = (object["expires_in"] as? Double) ?? 3600
        return .session(AccountSession(user: AccountUser(id: id, email: user["email"] as? String), accessToken: access, refreshToken: refresh, expiresAt: Date().addingTimeInterval(expiresIn)))
    }

    func requestEmailChange(newEmail: String, token: String) async throws {
        _ = try await call("POST", "auth/email", body: ["email": newEmail], token: token)
    }

    func confirmEmailChange(newEmail: String, code: String, token: String) async throws {
        _ = try await call("POST", "auth/email/confirm", body: ["email": newEmail, "code": code], token: token)
    }

    func verifyCode(email: String, code: String) async throws -> AccountSession {
        try await sessionCall("auth/verify", ["email": email, "code": code])
    }

    func apple(idToken: String, nonce: String, authorizationCode: String?, name: String?) async throws -> AccountSession {
        var body: [String: Any] = ["id_token": idToken, "nonce": nonce]
        if let authorizationCode { body["authorization_code"] = authorizationCode }
        if let name, !name.isEmpty { body["data"] = ["display_name": name] }
        return try await sessionCall("auth/apple", body)
    }

    func google(idToken: String, nonce: String, name: String?) async throws -> AccountSession {
        var body: [String: Any] = ["id_token": idToken, "nonce": nonce]
        if let name, !name.isEmpty { body["data"] = ["display_name": name] }
        return try await sessionCall("auth/google", body)
    }

    func refresh(_ refreshToken: String) async throws -> AccountSession {
        try await sessionCall("auth/refresh", ["refresh_token": refreshToken])
    }

    func logOut(token: String, everywhere: Bool = false) async throws {
        if everywhere {
            _ = try await call("POST", "auth/sign-out-everywhere", body: [:], token: token)
        } else {
            _ = try await call("POST", "auth/logout", body: [:], token: token)
        }
    }

    func deleteAccount(token: String) async throws {
        _ = try await call("DELETE", "auth/me", token: token)
    }

    // MARK: - Rows

    func rows(_ table: String, query: [URLQueryItem], token: String) async throws -> (rows: [[String: Any]], next: String?) {
        let object = try await call("GET", "tables/\(table)/rows", query: query, token: token)
        return (object["rows"] as? [[String: Any]] ?? [], object["next_cursor"] as? String)
    }

    @discardableResult
    func upsert(_ table: String, onConflict: String, rows: [[String: Any]], token: String) async throws -> [[String: Any]] {
        let query = [URLQueryItem(name: "upsert", value: "true"), URLQueryItem(name: "on_conflict", value: onConflict)]
        let object = try await call("POST", "tables/\(table)/rows", query: query, body: rows, token: token)
        return object["rows"] as? [[String: Any]] ?? []
    }

    // MARK: - Internals

    private func sessionCall(_ path: String, _ body: [String: Any]) async throws -> AccountSession {
        let object = try await call("POST", path, body: body)
        guard let access = object["access_token"] as? String, let refresh = object["refresh_token"] as? String,
              let user = object["user"] as? [String: Any], let id = user["id"] as? String else { throw AccountError.invalid }
        let expiresIn = (object["expires_in"] as? Double) ?? 3600
        return AccountSession(user: AccountUser(id: id, email: user["email"] as? String), accessToken: access, refreshToken: refresh, expiresAt: Date().addingTimeInterval(expiresIn))
    }

    private func call(_ method: String, _ path: String, query: [URLQueryItem] = [], body: Any? = nil, token: String? = nil) async throws -> [String: Any] {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query
            // `+` in timestamps would otherwise arrive as a space.
            components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        }
        var req = URLRequest(url: components.url!)
        req.httpMethod = method
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(publishableKey, forHTTPHeaderField: "apikey")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw AccountError.network
        }
        guard let http = response as? HTTPURLResponse else { throw AccountError.invalid }
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200..<300).contains(http.statusCode) else {
            throw AccountError.server(status: http.statusCode, code: object["error"] as? String ?? "", message: object["message"] as? String ?? "Request failed (\(http.statusCode)).")
        }
        return object
    }
}
