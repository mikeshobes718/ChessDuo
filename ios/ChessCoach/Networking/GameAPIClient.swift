import Foundation

enum GameAPIError: LocalizedError {
    case invalidConfiguration
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return L10n.t(.apiConfigError)
        case .invalidResponse:
            return L10n.t(.apiWeirdReply)
        case .server(let message):
            if message.localizedCaseInsensitiveContains("compute resources")
                || message.localizedCaseInsensitiveContains("WORKER_RESOURCE_LIMIT") {
                return L10n.t(.serverBusy)
            }
            return message
        }
    }
}

struct GameAPIClient {
    static let clientVersion = "2.8.0"

    private let session: URLSession
    private let baseURL: URL

    init(session: URLSession = .shared) {
        self.session = session
        let configured = Bundle.main.object(forInfoDictionaryKey: "API_GAME_URL") as? String
        baseURL = URL(string: configured ?? "https://kcdlmmfzeksjqwdppjzy.supabase.co/functions/v1/game")!
    }

    func create(name: String) async throws -> GameResponse {
        try await send([
            "action": "create",
            "name": name,
            "playerName": name,
            "clientVersion": Self.clientVersion
        ])
    }

    func join(name: String, roomCode: String) async throws -> GameResponse {
        try await send([
            "action": "join",
            "name": name,
            "playerName": name,
            "roomCode": roomCode.uppercased(),
            "clientVersion": Self.clientVersion
        ])
    }

    func spectate(roomCode: String) async throws -> GameResponse {
        try await send([
            "action": "spectate",
            "roomCode": roomCode.uppercased(),
            "clientVersion": Self.clientVersion
        ])
    }

    func state(session: PlayerSession, sinceVersion: Int? = nil) async throws -> GameResponse {
        var payload = authenticatedPayload(action: "state", session: session)
        if let sinceVersion {
            payload["sinceVersion"] = sinceVersion
        }
        return try await send(payload)
    }

    func registerPush(apnsToken: String, session: PlayerSession) async throws {
        var payload = authenticatedPayload(action: "registerPush", session: session)
        payload["apnsToken"] = apnsToken
        _ = try await send(payload)
    }

    func move(
        from: String,
        to: String,
        promotion: String,
        version: Int,
        session: PlayerSession
    ) async throws -> GameResponse {
        var payload = authenticatedPayload(action: "move", session: session)
        payload["version"] = version
        payload["move"] = [
            "from": from,
            "to": to,
            "promotion": promotion
        ]
        return try await send(payload)
    }

    func hint(version: Int, session: PlayerSession) async throws -> GameResponse {
        var payload = authenticatedPayload(action: "hint", session: session)
        payload["version"] = version
        return try await send(payload)
    }

    func playForMe(
        version: Int,
        session: PlayerSession,
        difficulty: ComputerDifficulty
    ) async throws -> GameResponse {
        var payload = authenticatedPayload(action: "playForMe", session: session)
        payload["version"] = version
        payload["difficulty"] = difficulty.rawValue
        return try await send(payload)
    }

    func moveAssisted(
        from: String,
        to: String,
        promotion: String,
        version: Int,
        session: PlayerSession,
        difficulty: ComputerDifficulty
    ) async throws -> GameResponse {
        var payload = authenticatedPayload(action: "move", session: session)
        payload["version"] = version
        payload["assisted"] = true
        payload["difficulty"] = difficulty.rawValue
        payload["move"] = [
            "from": from,
            "to": to,
            "promotion": promotion
        ]
        return try await send(payload)
    }

    func resign(version: Int, session: PlayerSession) async throws -> GameResponse {
        var payload = authenticatedPayload(action: "resign", session: session)
        payload["version"] = version
        return try await send(payload)
    }

    func rematch(version: Int, session: PlayerSession) async throws -> GameResponse {
        var payload = authenticatedPayload(action: "rematch", session: session)
        payload["version"] = version
        return try await send(payload)
    }

    func offerDraw(version: Int, session: PlayerSession) async throws -> GameResponse {
        var payload = authenticatedPayload(action: "offerDraw", session: session)
        payload["version"] = version
        return try await send(payload)
    }

    func respondDraw(accept: Bool, version: Int, session: PlayerSession) async throws -> GameResponse {
        var payload = authenticatedPayload(action: "respondDraw", session: session)
        payload["version"] = version
        payload["accept"] = accept
        return try await send(payload)
    }

    func offerUndo(version: Int, session: PlayerSession) async throws -> GameResponse {
        var payload = authenticatedPayload(action: "offerUndo", session: session)
        payload["version"] = version
        return try await send(payload)
    }

    func respondUndo(accept: Bool, version: Int, session: PlayerSession) async throws -> GameResponse {
        var payload = authenticatedPayload(action: "respondUndo", session: session)
        payload["version"] = version
        payload["accept"] = accept
        return try await send(payload)
    }

    func listArchives(playerToken: String) async throws -> [ArchivedMatch] {
        let response = try await sendRaw([
            "action": "listArchives",
            "playerToken": playerToken,
            "token": playerToken,
            "clientVersion": Self.clientVersion
        ])
        guard let archives = response["archives"] as? [[String: Any]] else { return [] }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let formatterBasic = ISO8601DateFormatter()
        return archives.compactMap { row in
            guard let id = row["id"] as? String,
                  let roomCode = row["roomCode"] as? String,
                  let status = row["status"] as? String else { return nil }
            let reviewData = try? JSONSerialization.data(withJSONObject: row["review"] ?? [:])
            guard let reviewData,
                  let review = try? JSONDecoder().decode(MatchReview.self, from: reviewData) else {
                return nil
            }
            let endedRaw = row["endedAt"] as? String ?? ""
            let ended = formatter.date(from: endedRaw) ?? formatterBasic.date(from: endedRaw) ?? Date()
            return ArchivedMatch(
                id: id,
                roomCode: roomCode,
                whiteName: row["whiteName"] as? String ?? "White",
                blackName: row["blackName"] as? String ?? "Black",
                status: status,
                resultText: row["result"] as? String ?? status,
                moveCount: row["moveCount"] as? Int ?? 0,
                review: review,
                endedAt: ended,
                playerToken: playerToken
            )
        }
    }

    func version() async throws -> GameResponse {
        try await send(["action": "version", "clientVersion": Self.clientVersion])
    }

    private func sendRaw(_ payload: [String: Any]) async throws -> [String: Any] {
        var payload = payload
        payload["language"] = AppLanguage.resolved.apiCode
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GameAPIError.server("Couldn't load past games.")
        }
        let object = try JSONSerialization.jsonObject(with: data)
        return object as? [String: Any] ?? [:]
    }

    private func authenticatedPayload(
        action: String,
        session: PlayerSession
    ) -> [String: Any] {
        [
            "action": action,
            "roomCode": session.roomCode,
            "playerToken": session.playerToken,
            "token": session.playerToken,
            "color": session.color.rawValue,
            "clientVersion": Self.clientVersion
        ]
    }

    private func send(_ payload: [String: Any]) async throws -> GameResponse {
        var payload = payload
        payload["language"] = AppLanguage.resolved.apiCode
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw GameAPIError.invalidResponse
            }

            let decoded = try? JSONDecoder().decode(GameResponse.self, from: data)
            guard (200..<300).contains(http.statusCode) else {
                throw GameAPIError.server(
                    decoded?.message ?? "Couldn't complete that action. Try again in a moment."
                )
            }
            guard let decoded else {
                throw GameAPIError.invalidResponse
            }
            return decoded
        } catch let error as GameAPIError {
            throw error
        } catch {
            throw GameAPIError.server("Couldn't reach the game server. Check your connection and try again.")
        }
    }
}
