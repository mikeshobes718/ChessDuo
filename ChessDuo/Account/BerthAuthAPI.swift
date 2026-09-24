import Foundation
import UIKit

enum AccountError: LocalizedError {
    case network
    /// `retryAfter` comes from the `Retry-After` header; `reason` is Berth's extra detail, e.g. `locked_out`.
    case server(status: Int, code: String, message: String, retryAfter: Int? = nil, reason: String? = nil, email: String? = nil)
    case invalid
    case cancelled

    /// What the UI needs to know, so it never has to match on message text.
    enum Kind: Equatable {
        case network
        case invalidCredentials
        case wrongCode
        case rateLimited(seconds: Int)
        case lockedOut(seconds: Int)
        case weakPassword(String)
        case emailTaken
        case emailNotVerified(email: String?)
        case signedOut
        case other(String)
    }

    var kind: Kind {
        switch self {
        case .network, .invalid: return .network
        case .cancelled: return .other("")
        case .server(let status, let code, let message, let retryAfter, let reason, let email):
            if status == 429 {
                let seconds = max(1, retryAfter ?? 60)
                return reason == "locked_out" ? .lockedOut(seconds: seconds) : .rateLimited(seconds: seconds)
            }
            if code == "weak_password" { return .weakPassword(message) }
            if code == "email_not_verified" { return .emailNotVerified(email: email) }
            if status == 409 { return .emailTaken }
            if status == 401 && message.localizedCaseInsensitiveContains("code") { return .wrongCode }
            if status == 401 && message.localizedCaseInsensitiveContains("password") { return .invalidCredentials }
            if status == 401 { return .signedOut }
            return .other(message)
        }
    }

    var errorDescription: String? {
        switch kind {
        case .network: return L10n.t("error.network")
        case .invalidCredentials: return L10n.t("account.error.credentials")
        case .wrongCode: return L10n.t("account.error.code")
        case .rateLimited: return L10n.t("account.error.slowDown")
        case .lockedOut: return L10n.t("account.error.locked")
        case .weakPassword(let message): return message
        case .emailTaken: return L10n.t("account.error.exists")
        case .emailNotVerified: return L10n.t("account.error.unverified")
        case .signedOut: return L10n.t("account.error.signedOut")
        case .other(let message): return message.isEmpty ? nil : message
        }
    }

    var isUnauthorized: Bool {
        if case .server(let status, _, _, _, _, _) = self { return status == 401 }
        return false
    }
}

struct AccountUser: Codable, Hashable {
    var id: String
    var email: String?
    var emailVerified: Bool

    init(id: String, email: String?, emailVerified: Bool) {
        self.id = id
        self.email = email
        self.emailVerified = emailVerified
    }

    init?(json: [String: Any]?) {
        guard let json, let id = json["id"] as? String else { return nil }
        self.id = id
        email = json["email"] as? String
        emailVerified = json["email_verified"] as? Bool ?? (json["email_verified_at"] is String)
    }

    /// Sessions saved before 2.2 have no flag. They could only exist once the email was verified.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        emailVerified = try c.decodeIfPresent(Bool.self, forKey: .emailVerified) ?? true
    }

    /// Apple sign ins that hide the address get a placeholder the user never typed.
    var realEmail: String? {
        guard let email, !email.hasSuffix("@users.invalid") else { return nil }
        return email
    }
}

struct AccountSession: Codable {
    var user: AccountUser
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
}

/// One sign in on one device, from `GET /auth/sessions`.
struct AccountDevice: Identifiable, Hashable {
    var id: String
    var userAgent: String?
    var ip: String?
    var signedInAt: Date?
    var lastRefreshAt: Date?
    var isCurrent: Bool

    /// Chess Duo sends `ChessDuo/<version> (<model>; iOS <version>)`; anything else is shown as a generic device.
    var deviceName: String {
        guard let agent = userAgent else { return L10n.t("account.sessions.unknownDevice") }
        if let open = agent.firstIndex(of: "("), let close = agent[open...].firstIndex(of: ")") {
            let parts = agent[agent.index(after: open)..<close].split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2 { return "\(parts[0]) · \(parts[1])" }
            if let first = parts.first, !first.isEmpty { return first }
        }
        if agent.contains("iPad") { return "iPad" }
        if agent.contains("iPhone") || agent.contains("CFNetwork") { return "iPhone" }
        return L10n.t("account.sessions.unknownDevice")
    }
}

/// The app's password rule, from `GET /auth/settings`. The server still has the final word.
struct PasswordPolicy: Equatable {
    var minLength = 8
    var maxLength = 200
    var requireLetter = true
    var requireNumber = true
    var requireSymbol = false

    init() {}

    init(json: [String: Any]) {
        minLength = json["min_length"] as? Int ?? minLength
        maxLength = json["max_length"] as? Int ?? maxLength
        requireLetter = json["require_letter"] as? Bool ?? requireLetter
        requireNumber = json["require_number"] as? Bool ?? requireNumber
        requireSymbol = json["require_symbol"] as? Bool ?? requireSymbol
    }

    struct Rule: Identifiable {
        var id: String
        var label: String
        var met: Bool
    }

    /// Mirrors Berth's check_password: length, a letter, and optionally a digit and a symbol.
    func rules(for password: String) -> [Rule] {
        var out = [Rule(id: "length", label: L10n.t("account.password.rule.length", "\(minLength)"),
                        met: (minLength...maxLength).contains(password.count))]
        if requireLetter { out.append(Rule(id: "letter", label: L10n.t("account.password.rule.letter"), met: password.range(of: "[A-Za-z]", options: .regularExpression) != nil)) }
        if requireNumber { out.append(Rule(id: "number", label: L10n.t("account.password.rule.number"), met: password.range(of: "\\d", options: .regularExpression) != nil)) }
        if requireSymbol { out.append(Rule(id: "symbol", label: L10n.t("account.password.rule.symbol"), met: password.range(of: "[^\\w\\s]|_", options: .regularExpression) != nil)) }
        return out
    }

    func accepts(_ password: String) -> Bool { rules(for: password).allSatisfy(\.met) }
}

/// Client for the app's end-user auth and owner-only tables. The publishable key rides in `apikey`
/// so `Authorization` can carry the signed-in user's access token. Never log request bodies or
/// responses here: they carry passwords, codes and tokens.
struct BerthAuthAPI {
    private let baseURL: URL
    private let publishableKey: String
    private let session: URLSession
    private let userAgent: String

    init(session: URLSession = .shared) {
        self.session = session
        let configured = Bundle.main.object(forInfoDictionaryKey: "ACCOUNT_API_URL") as? String
        baseURL = URL(string: configured ?? "https://api.atberth.com/v1/apps/chessduo")!
        publishableKey = Bundle.main.object(forInfoDictionaryKey: "API_PUBLISHABLE_KEY") as? String ?? ""
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        userAgent = "ChessDuo/\(version) (\(UIDevice.current.model); iOS \(UIDevice.current.systemVersion))"
    }

    // MARK: - Auth

    func settings() async throws -> PasswordPolicy {
        let object = try await call("GET", "auth/settings")
        return PasswordPolicy(json: object["password"] as? [String: Any] ?? [:])
    }

    func logIn(email: String, password: String) async throws -> AccountSession {
        try await sessionCall("auth/login", ["email": email, "password": password])
    }

    func requestCode(email: String) async throws {
        _ = try await call("POST", "auth/code", body: ["email": email])
    }

    func verifyCode(email: String, code: String) async throws -> AccountSession {
        try await sessionCall("auth/verify", ["email": email, "code": code])
    }

    /// Always 202 `{"sent": true}`, whether or not the address has an account.
    func requestPasswordReset(email: String) async throws {
        _ = try await call("POST", "auth/reset", body: ["email": email])
    }

    /// Sets the new password and returns a session. Berth revokes every other session in the same step.
    func confirmPasswordReset(email: String, code: String, password: String) async throws -> AccountSession {
        try await sessionCall("auth/reset", ["email": email, "code": code, "password": password])
    }

    enum SignUpOutcome {
        case session(AccountSession)
        /// The app requires a verified email before a session; a sign in code went to the address.
        case verificationRequired
    }

    func signUp(email: String, password: String, name: String) async throws -> SignUpOutcome {
        let object = try await call("POST", "auth/signup", body: ["email": email, "password": password, "data": ["display_name": name]])
        if object["verification_required"] as? Bool == true { return .verificationRequired }
        return .session(try parseSession(object))
    }

    /// Before an unverified signup has a session: moves it to a new address and sends the code there.
    func moveUnverifiedSignUp(from current: String, to newEmail: String) async throws {
        _ = try await call("POST", "auth/email", body: ["email": newEmail, "current": current])
    }

    /// Without a code, emails a verification code to the signed-in user. With one, confirms it.
    @discardableResult
    func verifyEmail(code: String?, token: String) async throws -> AccountUser? {
        let object = try await call("POST", "auth/verify-email", body: code.map { ["code": $0] } ?? [:], token: token)
        return AccountUser(json: object["user"] as? [String: Any])
    }

    func me(token: String) async throws -> AccountUser {
        let object = try await call("GET", "auth/me", token: token)
        guard let user = AccountUser(json: object["user"] as? [String: Any]) else { throw AccountError.invalid }
        return user
    }

    func requestEmailChange(newEmail: String, token: String) async throws {
        _ = try await call("POST", "auth/email", body: ["email": newEmail], token: token)
    }

    func confirmEmailChange(newEmail: String, code: String, token: String) async throws -> AccountUser? {
        let object = try await call("POST", "auth/email/confirm", body: ["email": newEmail, "code": code], token: token)
        return AccountUser(json: object["user"] as? [String: Any])
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
        _ = try await call("POST", "auth/logout", body: everywhere ? ["all": true] : [:], token: token)
    }

    func sessions(token: String) async throws -> [AccountDevice] {
        let object = try await call("GET", "auth/sessions", token: token)
        return (object["sessions"] as? [[String: Any]] ?? []).compactMap { row in
            guard let id = row["id"] as? String else { return nil }
            return AccountDevice(id: id, userAgent: row["user_agent"] as? String, ip: row["ip"] as? String,
                                 signedInAt: Self.date(row["created_at"]), lastRefreshAt: Self.date(row["refreshed_at"]),
                                 isCurrent: row["current"] as? Bool ?? false)
        }
    }

    /// The session's access tokens stop working immediately.
    func revokeSession(id: String, token: String) async throws {
        _ = try await call("DELETE", "auth/sessions/\(id)", token: token)
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
        try parseSession(try await call("POST", path, body: body))
    }

    private func parseSession(_ object: [String: Any]) throws -> AccountSession {
        guard let access = object["access_token"] as? String, let refresh = object["refresh_token"] as? String,
              let user = AccountUser(json: object["user"] as? [String: Any]) else { throw AccountError.invalid }
        let expiresAt = (object["expires_at"] as? Double).map { Date(timeIntervalSince1970: $0) }
            ?? Date().addingTimeInterval((object["expires_in"] as? Double) ?? 3600)
        return AccountSession(user: user, accessToken: access, refreshToken: refresh, expiresAt: expiresAt)
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso = ISO8601DateFormatter()

    /// Berth sends Python isoformat: microseconds when present, none on a whole second.
    static func date(_ value: Any?) -> Date? {
        guard let text = value as? String else { return nil }
        if let date = isoFractional.date(from: text) ?? iso.date(from: text) { return date }
        // Six fractional digits trip ISO8601DateFormatter on some OS versions; trim to milliseconds.
        if let dot = text.firstIndex(of: "."), let zone = text[dot...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) {
            let fraction = text[text.index(after: dot)..<zone].prefix(3)
            return isoFractional.date(from: text[..<dot] + "." + fraction + text[zone...])
        }
        return nil
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
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
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
            let retryAfter = (http.value(forHTTPHeaderField: "Retry-After")).flatMap { Int($0) } ?? object["retry_after"] as? Int
            throw AccountError.server(status: http.statusCode, code: object["error"] as? String ?? "",
                                      message: object["message"] as? String ?? "Request failed (\(http.statusCode)).",
                                      retryAfter: retryAfter, reason: object["reason"] as? String, email: object["email"] as? String)
        }
        return object
    }
}
