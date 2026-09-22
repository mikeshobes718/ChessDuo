import Foundation

enum OnlineError: LocalizedError {
    case network
    case server(String)
    case invalid

    var errorDescription: String? {
        switch self {
        case .network: return L10n.t("error.network")
        case .invalid: return L10n.t("error.network")
        case .server(let message):
            if message.localizedCaseInsensitiveContains("not found") { return L10n.t("error.roomNotFound") }
            return message
        }
    }
}

/// Client for the Chess Duo game function on Berth. Stateless; the session carries auth.
/// The publishable key only lets the app call the function; the tables stay server-only.
struct OnlineAPI {
    static let clientVersion = "3.0.0"
    private let baseURL: URL
    private let publishableKey: String?
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
        let configured = Bundle.main.object(forInfoDictionaryKey: "API_GAME_URL") as? String
        baseURL = URL(string: configured ?? "https://api.atberth.com/v1/apps/chessduo/functions/game")!
        publishableKey = Bundle.main.object(forInfoDictionaryKey: "API_PUBLISHABLE_KEY") as? String
    }

    func create(name: String) async throws -> OnlineResponse {
        try await send(["action": "create", "name": name, "playerName": name])
    }

    func join(name: String, roomCode: String) async throws -> OnlineResponse {
        try await send(["action": "join", "name": name, "playerName": name, "roomCode": roomCode.uppercased()])
    }

    func spectate(roomCode: String) async throws -> OnlineResponse {
        try await send(["action": "spectate", "roomCode": roomCode.uppercased()], timeout: 10)
    }

    func state(_ s: OnlineSessionInfo, sinceVersion: Int? = nil) async throws -> OnlineResponse {
        var p = auth("state", s)
        if let sinceVersion { p["sinceVersion"] = sinceVersion }
        return try await send(p, timeout: 10)
    }

    func move(_ s: OnlineSessionInfo, from: String, to: String, promotion: String?, version: Int, assisted: Bool = false, level: EngineLevel? = nil) async throws -> OnlineResponse {
        var p = auth("move", s)
        p["version"] = version
        p["move"] = ["from": from, "to": to, "promotion": promotion ?? ""]
        if assisted {
            p["assisted"] = true
            p["difficulty"] = difficultyName(level ?? .club)
        }
        return try await send(p)
    }

    func hint(_ s: OnlineSessionInfo, version: Int) async throws -> OnlineResponse {
        var p = auth("hint", s); p["version"] = version
        return try await send(p)
    }

    func resign(_ s: OnlineSessionInfo, version: Int) async throws -> OnlineResponse {
        var p = auth("resign", s); p["version"] = version
        return try await send(p)
    }

    func rematch(_ s: OnlineSessionInfo, version: Int) async throws -> OnlineResponse {
        var p = auth("rematch", s); p["version"] = version
        return try await send(p)
    }

    func offerDraw(_ s: OnlineSessionInfo, version: Int) async throws -> OnlineResponse {
        var p = auth("offerDraw", s); p["version"] = version
        return try await send(p)
    }

    func respondDraw(_ s: OnlineSessionInfo, accept: Bool, version: Int) async throws -> OnlineResponse {
        var p = auth("respondDraw", s); p["version"] = version; p["accept"] = accept
        return try await send(p)
    }

    func offerUndo(_ s: OnlineSessionInfo, version: Int) async throws -> OnlineResponse {
        var p = auth("offerUndo", s); p["version"] = version
        return try await send(p)
    }

    func respondUndo(_ s: OnlineSessionInfo, accept: Bool, version: Int) async throws -> OnlineResponse {
        var p = auth("respondUndo", s); p["version"] = version; p["accept"] = accept
        return try await send(p)
    }

    func nudge(_ s: OnlineSessionInfo) async throws -> OnlineResponse {
        try await send(auth("nudge", s))
    }

    func registerPush(_ s: OnlineSessionInfo, token: String, turnAlerts: Bool) async throws {
        var p = auth("registerPush", s)
        p["apnsToken"] = token
        p["turnAlerts"] = turnAlerts
        _ = try await send(p)
    }

    func listArchives(playerToken: String) async throws -> [OnlineArchive] {
        let raw = try await sendRaw(["action": "listArchives", "playerToken": playerToken, "token": playerToken])
        guard let archives = raw["archives"] as? [[String: Any]] else { return [] }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoBasic = ISO8601DateFormatter()
        return archives.compactMap { row in
            guard let id = row["id"] as? String, let roomCode = row["roomCode"] as? String else { return nil }
            let endedRaw = row["endedAt"] as? String ?? ""
            let review = row["review"] as? [String: Any]
            let moves = (review?["moves"] as? [[String: Any]])?.compactMap { $0["san"] as? String } ?? []
            return OnlineArchive(
                id: id,
                roomCode: roomCode,
                whiteName: row["whiteName"] as? String ?? "White",
                blackName: row["blackName"] as? String ?? "Black",
                status: row["status"] as? String ?? "",
                resultText: row["result"] as? String ?? (row["status"] as? String ?? ""),
                moveCount: row["moveCount"] as? Int ?? moves.count,
                endedAt: iso.date(from: endedRaw) ?? isoBasic.date(from: endedRaw) ?? Date(),
                sans: moves
            )
        }
    }

    // MARK: - Internals

    private func difficultyName(_ level: EngineLevel) -> String {
        switch level {
        case .beginner, .casual: return "easy"
        case .club: return "medium"
        case .strong, .master: return "hard"
        }
    }

    private func auth(_ action: String, _ s: OnlineSessionInfo) -> [String: Any] {
        ["action": action, "roomCode": s.roomCode, "playerToken": s.playerToken, "token": s.playerToken, "color": s.role.rawValue]
    }

    private func request(_ payload: [String: Any], timeout: TimeInterval) throws -> URLRequest {
        var payload = payload
        payload["clientVersion"] = Self.clientVersion
        payload["language"] = AppLanguage.resolved.apiCode
        var req = URLRequest(url: baseURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let publishableKey, !publishableKey.isEmpty {
            req.setValue(publishableKey, forHTTPHeaderField: "apikey")
        }
        req.timeoutInterval = timeout
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return req
    }

    private func sendRaw(_ payload: [String: Any], timeout: TimeInterval = 20) async throws -> [String: Any] {
        let req = try request(payload, timeout: timeout)
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw OnlineError.invalid }
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            guard (200..<300).contains(http.statusCode) else {
                throw OnlineError.server((object["message"] as? String) ?? (object["error"] as? String) ?? "Request failed (\(http.statusCode)).")
            }
            return object
        } catch let e as OnlineError {
            throw e
        } catch {
            throw OnlineError.network
        }
    }

    private func send(_ payload: [String: Any], timeout: TimeInterval = 20) async throws -> OnlineResponse {
        let req = try request(payload, timeout: timeout)
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw OnlineError.invalid }
            let decoded = try? JSONDecoder().decode(OnlineResponse.self, from: data)
            guard (200..<300).contains(http.statusCode) else {
                throw OnlineError.server(decoded?.message ?? decoded?.error ?? "Request failed (\(http.statusCode)).")
            }
            guard let decoded else { throw OnlineError.invalid }
            return decoded
        } catch let e as OnlineError {
            throw e
        } catch {
            throw OnlineError.network
        }
    }
}
