import Foundation

struct ArchivedMatch: Codable, Identifiable, Equatable {
    var id: String
    var roomCode: String
    var whiteName: String
    var blackName: String
    var status: String
    var resultText: String
    var moveCount: Int
    var review: MatchReview
    var endedAt: Date
    var playerToken: String?

    static func fromFinishedGame(
        roomCode: String,
        whiteName: String,
        blackName: String,
        status: String,
        resultText: String,
        moveCount: Int,
        review: MatchReview,
        playerToken: String?
    ) -> ArchivedMatch {
        ArchivedMatch(
            id: "\(roomCode)-\(Int(Date().timeIntervalSince1970))",
            roomCode: roomCode,
            whiteName: whiteName,
            blackName: blackName,
            status: status,
            resultText: resultText,
            moveCount: moveCount,
            review: review,
            endedAt: Date(),
            playerToken: playerToken
        )
    }
}

enum MatchArchiveStore {
    private static let key = "chessDuo.matchArchives.v1"
    private static let maxItems = 40

    static func load() -> [ArchivedMatch] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([ArchivedMatch].self, from: data) else {
            return []
        }
        return items.sorted { $0.endedAt > $1.endedAt }
    }

    static var knownTokens: [String] {
        var tokens: [String] = []
        for match in load() {
            if let token = match.playerToken, !tokens.contains(token) {
                tokens.append(token)
            }
        }
        return tokens
    }

    static func save(_ match: ArchivedMatch) {
        var items = load()
        if items.contains(where: {
            $0.roomCode == match.roomCode
                && abs($0.endedAt.timeIntervalSince(match.endedAt)) < 2
                && $0.status == match.status
        }) {
            return
        }
        items.insert(match, at: 0)
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func mergeServer(_ remote: [ArchivedMatch]) {
        var byId = Dictionary(uniqueKeysWithValues: load().map { ($0.id, $0) })
        for item in remote {
            byId[item.id] = item
        }
        let merged = byId.values.sorted { $0.endedAt > $1.endedAt }
        if let data = try? JSONEncoder().encode(Array(merged.prefix(maxItems))) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static var latestPlayerToken: String? {
        load().compactMap(\.playerToken).first
    }
}
