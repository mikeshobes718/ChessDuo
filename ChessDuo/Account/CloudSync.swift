import Foundation
import Combine
import UIKit

extension Date {
    /// Whole seconds, so a timestamp survives the ISO 8601 round trip through files and the backup unchanged.
    static var syncNow: Date { Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970)) }
}

/// Pure merge rules, kept separate so they are easy to reason about.
enum SyncMerge {
    struct GamesResult {
        var records: [GameRecord]
        var tombstones: [UUID: Date]
        /// IDs whose local copy now matches the backup, with the timestamp that matches.
        var inSync: [UUID: Date]
        var inSyncTombstones: [UUID: Date]
    }

    struct RemoteGame {
        var id: UUID
        var record: GameRecord?
        var deletedAt: Date?
    }

    /// Finished beats unfinished; otherwise the newer change wins.
    static func pick(local: GameRecord, remote: GameRecord) -> GameRecord {
        if local.isFinished != remote.isFinished { return local.isFinished ? local : remote }
        return remote.lastChange > local.lastChange ? remote : local
    }

    static func games(local: [GameRecord], tombstones: [UUID: Date], remote: [RemoteGame]) -> GamesResult {
        var byID = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var tombs = tombstones
        var inSync: [UUID: Date] = [:]
        var inSyncTombs: [UUID: Date] = [:]
        for r in remote {
            if let deletedAt = r.deletedAt {
                if let l = byID[r.id], l.lastChange > deletedAt { continue }
                byID[r.id] = nil
                tombs[r.id] = max(tombs[r.id] ?? .distantPast, deletedAt)
                if tombs[r.id] == deletedAt { inSyncTombs[r.id] = deletedAt }
            } else if let rec = r.record {
                if let t = tombs[r.id] {
                    if t >= rec.lastChange { continue }
                    tombs[r.id] = nil
                    byID[r.id] = rec
                    inSync[r.id] = rec.lastChange
                } else if let l = byID[r.id] {
                    let winner = pick(local: l, remote: rec)
                    if winner.lastChange == rec.lastChange && winner.isFinished == rec.isFinished {
                        byID[r.id] = rec
                        inSync[r.id] = rec.lastChange
                    }
                } else {
                    byID[r.id] = rec
                    inSync[r.id] = rec.lastChange
                }
            }
        }
        return GamesResult(records: Array(byID.values), tombstones: tombs, inSync: inSync, inSyncTombstones: inSyncTombs)
    }

    /// First link of a device to an account: keep the best of both.
    static func firstLink(local: PlayerStats, remote: PlayerStats) -> PlayerStats {
        var s = PlayerStats()
        s.games = max(local.games, remote.games)
        s.wins = max(local.wins, remote.wins)
        s.losses = max(local.losses, remote.losses)
        s.draws = max(local.draws, remote.draws)
        s.currentStreak = max(local.currentStreak, remote.currentStreak)
        s.bestStreak = max(local.bestStreak, remote.bestStreak)
        s.puzzleStreak = max(local.puzzleStreak, remote.puzzleStreak)
        s.puzzleRating = max(local.puzzleRating, remote.puzzleRating)
        s.computerWinsByLevel = local.computerWinsByLevel.merging(remote.computerWinsByLevel, uniquingKeysWith: max)
        s.solvedPuzzleIDs = local.solvedPuzzleIDs.union(remote.solvedPuzzleIDs)
        s.puzzlesSolved = max(local.puzzlesSolved, remote.puzzlesSolved, s.solvedPuzzleIDs.count)
        s.updatedAt = .syncNow
        return s
    }

    static func recentRooms(local: [String], remote: [String]) -> [String] {
        var seen = Set<String>()
        return (local + remote).filter { seen.insert($0).inserted }.prefix(10).map { $0 }
    }
}

/// Backs up games, stats and settings for a signed-in user: pull, merge, push. Runs on launch, on
/// foreground, after sign in, and a few seconds after local changes. Signed out it does nothing.
@MainActor
final class CloudSync: ObservableObject {
    static let shared = CloudSync()

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSynced: Date?
    @Published private(set) var lastError: String?

    private struct State: Codable {
        var userID: String
        var linked = false
        var gameCursor: String?
        var pushed: [UUID: Date] = [:]
        var pushedTombstones: [UUID: Date] = [:]
        var pushedSettingsAt: Date?
        var pushedStatsAt: Date?
        var pushedRoomAt: Date?
        var pushedRecent: [String]?
        var lastSynced: Date?
    }

    private struct Stamped<T: Codable>: Codable {
        var updatedAt: Date
        var value: T?
    }

    static let activeRoomStampKey = "sync.activeRoomUpdatedAt"
    static let recentRoomsKey = "online.recentCodes"

    private let api = BerthAuthAPI()
    private var state: State?
    private var debounce: Task<Void, Never>?
    private var pending = false
    private var suggestedName: String?
    private var settingsSnapshot: SyncedSettings?
    private var settingsWatcher: AnyCancellable?
    private var applyingRemote = false

    private var stateURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("ChessDuo/sync-state.json")
    }

    private static let encoder: JSONEncoder = { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e }()
    private static let decoder: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }()

    private init() {
        if let data = try? Data(contentsOf: stateURL), let decoded = try? Self.decoder.decode(State.self, from: data) {
            state = decoded
            lastSynced = decoded.lastSynced
        }
    }

    /// Call once at launch. Stamps the settings blob whenever a synced preference actually changes.
    func start() {
        settingsSnapshot = AppSettings.shared.synced
        settingsWatcher = AppSettings.shared.objectWillChange
            .debounce(for: .milliseconds(600), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.settingsMayHaveChanged() }
        syncSoon(delay: 0)
    }

    private func settingsMayHaveChanged() {
        let now = AppSettings.shared.synced
        guard now != settingsSnapshot else { return }
        settingsSnapshot = now
        guard !applyingRemote else { return }
        AppSettings.shared.syncedSettingsUpdatedAt = .syncNow
        localChange()
    }

    // MARK: - Triggers

    func localChange() { syncSoon(delay: 4) }

    func activeRoomChanged() {
        UserDefaults.standard.set(Date.syncNow, forKey: Self.activeRoomStampKey)
        localChange()
    }

    func syncSoon(delay: TimeInterval) {
        guard AccountStore.shared.isSignedIn else { return }
        debounce?.cancel()
        debounce = Task { [weak self] in
            if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            guard !Task.isCancelled else { return }
            await self?.sync()
        }
    }

    /// Pushes pending changes before the app is suspended.
    func flushInBackground() {
        guard AccountStore.shared.isSignedIn else { return }
        debounce?.cancel()
        let app = UIApplication.shared
        var task: UIBackgroundTaskIdentifier = .invalid
        task = app.beginBackgroundTask { app.endBackgroundTask(task) }
        Task {
            await sync()
            app.endBackgroundTask(task)
        }
    }

    func didSignIn(suggestedName: String?) async {
        self.suggestedName = suggestedName
        if state?.userID != AccountStore.shared.userID { state = nil }
        await sync()
    }

    func didSignOut() {
        debounce?.cancel()
        state = nil
        lastSynced = nil
        lastError = nil
        try? FileManager.default.removeItem(at: stateURL)
    }

    // MARK: - Sync

    func sync() async {
        guard let userID = AccountStore.shared.userID else { return }
        if isSyncing { pending = true; return }
        isSyncing = true
        defer {
            isSyncing = false
            if pending { pending = false; syncSoon(delay: 1) }
        }
        var s = (state?.userID == userID ? state : nil) ?? State(userID: userID)
        do {
            try await withAuthRetry { token in try await self.run(&s, token: token) }
            s.linked = true
            s.lastSynced = Date()
            lastSynced = s.lastSynced
            lastError = nil
            suggestedName = nil
            if AccountStore.shared.userID == userID { save(s) }
        } catch {
            if AccountStore.shared.userID == userID { save(s) }
            lastError = error.localizedDescription
        }
    }

    private func withAuthRetry(_ body: (String) async throws -> Void) async throws {
        do {
            try await body(try await AccountStore.shared.accessToken())
        } catch let error as AccountError where error.isUnauthorized {
            AccountStore.shared.expireAccessToken()
            try await body(try await AccountStore.shared.accessToken())
        }
    }

    private func run(_ s: inout State, token: String) async throws {
        let history = HistoryStore.shared
        let settings = AppSettings.shared
        let firstLink = !s.linked

        // Pull.
        let profileRow = try await api.rows("profiles", query: [URLQueryItem(name: "limit", value: "1")], token: token).rows.first
        var remoteGames: [SyncMerge.RemoteGame] = []
        var cursor: String?
        var maxUpdated = s.gameCursor
        repeat {
            var query = [URLQueryItem(name: "order", value: "updated_at.asc"), URLQueryItem(name: "limit", value: "200")]
            if let since = s.gameCursor { query.append(URLQueryItem(name: "updated_at", value: "gt.\(since)")) }
            if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
            let page = try await api.rows("game_records", query: query, token: token)
            for row in page.rows {
                if let updated = row["updated_at"] as? String { maxUpdated = updated }
                if let game = Self.remoteGame(row) { remoteGames.append(game) }
            }
            cursor = page.next
        } while cursor != nil

        // Merge games.
        let merged = SyncMerge.games(local: history.records, tombstones: history.tombstones, remote: remoteGames)
        for (id, at) in merged.inSync { s.pushed[id] = at }
        for (id, at) in merged.inSyncTombstones { s.pushedTombstones[id] = at }
        var tombstones = merged.tombstones
        let cutoff = Date().addingTimeInterval(-60 * 86_400)
        for (id, at) in tombstones where at < cutoff && s.pushedTombstones[id] == at {
            tombstones[id] = nil
            s.pushedTombstones[id] = nil
        }

        // Merge stats.
        let remoteStats: Stamped<PlayerStats>? = Self.decode(profileRow?["stats"])
        var stats = history.stats
        if let remoteStats, let value = remoteStats.value {
            if firstLink {
                stats = SyncMerge.firstLink(local: stats, remote: value)
            } else if remoteStats.updatedAt > (stats.updatedAt ?? .distantPast) {
                stats = value
                stats.updatedAt = remoteStats.updatedAt
                s.pushedStatsAt = remoteStats.updatedAt
            }
        }
        if stats.updatedAt == nil { stats.updatedAt = .syncNow }
        history.applySynced(records: merged.records, tombstones: tombstones, stats: stats)

        // Merge settings. On a device's first link the backup wins, so a new phone restores it.
        let remoteSettings: Stamped<SyncedSettings>? = Self.decode(profileRow?["settings"])
        if let remoteSettings, let value = remoteSettings.value,
           firstLink || remoteSettings.updatedAt > (settings.syncedSettingsUpdatedAt ?? .distantPast) {
            applyingRemote = true
            settings.apply(value)
            settingsSnapshot = settings.synced
            applyingRemote = false
            settings.syncedSettingsUpdatedAt = remoteSettings.updatedAt
            s.pushedSettingsAt = remoteSettings.updatedAt
        } else if firstLink, let name = suggestedName?.trimmingCharacters(in: .whitespaces), !name.isEmpty,
                  ["", "Player"].contains(settings.playerName.trimmingCharacters(in: .whitespaces)) {
            settings.playerName = name
            settingsSnapshot = settings.synced
            settings.syncedSettingsUpdatedAt = .syncNow
        }
        if settings.syncedSettingsUpdatedAt == nil { settings.syncedSettingsUpdatedAt = .syncNow }

        // Merge the active online room, so a new phone can rejoin it. A cleared room elsewhere does not
        // end a game that is still open here.
        let defaults = UserDefaults.standard
        let remoteRoom: Stamped<OnlineSessionInfo>? = Self.decode(profileRow?["active_room"])
        var roomAt = defaults.object(forKey: Self.activeRoomStampKey) as? Date
        if let remoteRoom, remoteRoom.updatedAt > (roomAt ?? .distantPast) {
            if let info = remoteRoom.value, OnlineSession.loadSaved()?.roomCode != info.roomCode {
                OnlineSession.store(info)
                AppRouter.shared.openOnlineFromNotification = true
            }
            roomAt = remoteRoom.updatedAt
            defaults.set(roomAt, forKey: Self.activeRoomStampKey)
            s.pushedRoomAt = roomAt
        }

        // Merge recent room codes.
        let remoteRecent = (profileRow?["recent_rooms"] as? [String: Any])?["codes"] as? [String] ?? []
        let recent = SyncMerge.recentRooms(local: defaults.stringArray(forKey: Self.recentRoomsKey) ?? [], remote: remoteRecent)
        defaults.set(recent, forKey: Self.recentRoomsKey)

        // Push games.
        let dirtyGames = history.records.filter { s.pushed[$0.id] != $0.lastChange }
        let dirtyTombs = history.tombstones.filter { s.pushedTombstones[$0.key] != $0.value }
        var rows: [(UUID, Date, Bool, [String: Any])] = dirtyGames.compactMap { r in Self.row(for: r).map { (r.id, r.lastChange, false, $0) } }
        rows += dirtyTombs.map { id, at in (id, at, true, Self.tombstoneRow(id: id, deletedAt: at)) }
        for chunk in stride(from: 0, to: rows.count, by: 25).map({ Array(rows[$0..<min($0 + 25, rows.count)]) }) {
            try await api.upsert("game_records", onConflict: "id", rows: chunk.map(\.3), token: token)
            for (id, at, isTomb, _) in chunk {
                if isTomb { s.pushedTombstones[id] = at } else { s.pushed[id] = at }
            }
        }
        s.gameCursor = maxUpdated

        // Push the profile when anything in it is newer than the backup.
        let statsAt = history.stats.updatedAt
        let settingsAt = settings.syncedSettingsUpdatedAt
        let needsProfile = profileRow == nil || firstLink || s.pushedStatsAt != statsAt || s.pushedSettingsAt != settingsAt
            || s.pushedRoomAt != roomAt || recent != remoteRecent
        if needsProfile {
            var profile: [String: Any] = [
                "display_name": settings.playerName,
                "settings": Self.object(Stamped(updatedAt: settingsAt ?? .syncNow, value: settings.synced)) ?? NSNull(),
                "stats": Self.object(Stamped(updatedAt: statsAt ?? .syncNow, value: history.stats)) ?? NSNull(),
                "recent_rooms": ["codes": recent],
            ]
            if let roomAt { profile["active_room"] = Self.object(Stamped(updatedAt: roomAt, value: OnlineSession.loadSaved())) ?? NSNull() }
            try await api.upsert("profiles", onConflict: "owner_id", rows: [profile], token: token)
            s.pushedStatsAt = statsAt
            s.pushedSettingsAt = settingsAt
            s.pushedRoomAt = roomAt
        }
    }

    // MARK: - Encoding

    private func save(_ s: State) {
        state = s
        if let data = try? Self.encoder.encode(s) { try? data.write(to: stateURL, options: .atomic) }
    }

    private static func object<T: Encodable>(_ value: T) -> Any? {
        guard let data = try? encoder.encode(value) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    private static func decode<T: Decodable>(_ any: Any?) -> T? {
        guard let any, !(any is NSNull), JSONSerialization.isValidJSONObject(any),
              let data = try? JSONSerialization.data(withJSONObject: any) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private static let isoFormatter = ISO8601DateFormatter()
    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func date(_ any: Any?) -> Date? {
        guard let s = any as? String else { return nil }
        return isoFormatter.date(from: s) ?? isoFractional.date(from: s)
    }

    private static func remoteGame(_ row: [String: Any]) -> SyncMerge.RemoteGame? {
        guard let idString = row["id"] as? String, let id = UUID(uuidString: idString) else { return nil }
        if let deletedAt = date(row["deleted_at"]) { return .init(id: id, record: nil, deletedAt: deletedAt) }
        guard var record: GameRecord = decode(row["data"]) else { return nil }
        record.id = id
        return .init(id: id, record: record, deletedAt: nil)
    }

    private static func row(for record: GameRecord) -> [String: Any]? {
        guard let data = object(record) else { return nil }
        var row: [String: Any] = [
            "id": record.id.uuidString.lowercased(),
            "mode": record.mode.rawValue,
            "started_at": isoFormatter.string(from: record.startedAt),
            "is_finished": record.isFinished,
            "data": data,
            "deleted_at": NSNull(),
        ]
        row["ended_at"] = record.endedAt.map { isoFormatter.string(from: $0) } ?? NSNull()
        return row
    }

    private static func tombstoneRow(id: UUID, deletedAt: Date) -> [String: Any] {
        ["id": id.uuidString.lowercased(), "mode": "deleted", "started_at": isoFormatter.string(from: deletedAt),
         "is_finished": true, "data": NSNull(), "ended_at": NSNull(), "deleted_at": isoFormatter.string(from: deletedAt)]
    }
}
