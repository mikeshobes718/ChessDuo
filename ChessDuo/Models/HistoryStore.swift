import Foundation
import Combine

/// Persists games and stats as JSON in Application Support. Main-actor bound; writes are debounced.
@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var records: [GameRecord] = []
    @Published private(set) var stats = PlayerStats()

    private let folder: URL
    private var saveTask: Task<Void, Never>?

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        folder = base.appendingPathComponent("ChessDuo", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        load()
    }

    private var recordsURL: URL { folder.appendingPathComponent("games.json") }
    private var statsURL: URL { folder.appendingPathComponent("stats.json") }

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: recordsURL), let decoded = try? decoder.decode([GameRecord].self, from: data) {
            records = decoded.sorted { $0.startedAt > $1.startedAt }
        }
        if let data = try? Data(contentsOf: statsURL), let decoded = try? decoder.decode(PlayerStats.self, from: data) {
            stats = decoded
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshotRecords = records
        let snapshotStats = stats
        let recordsURL = recordsURL, statsURL = statsURL
        saveTask = Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(snapshotRecords) { try? data.write(to: recordsURL, options: .atomic) }
            if let data = try? encoder.encode(snapshotStats) { try? data.write(to: statsURL, options: .atomic) }
        }
    }

    // MARK: - Records

    func upsert(_ record: GameRecord) {
        if let idx = records.firstIndex(where: { $0.id == record.id }) {
            records[idx] = record
        } else {
            records.insert(record, at: 0)
        }
        records.sort { $0.startedAt > $1.startedAt }
        scheduleSave()
    }

    func delete(_ record: GameRecord) {
        records.removeAll { $0.id == record.id }
        scheduleSave()
    }

    func deleteAll() {
        records.removeAll()
        scheduleSave()
    }

    func record(id: UUID) -> GameRecord? { records.first { $0.id == id } }

    /// The most recent unfinished local or computer game, for "Resume".
    var resumable: GameRecord? {
        records.first { !$0.isFinished && ($0.mode == .local || $0.mode == .computer) && !$0.moves.isEmpty }
    }

    var unfinishedLocalGames: [GameRecord] {
        records.filter { !$0.isFinished && ($0.mode == .local || $0.mode == .computer) }
    }

    // MARK: - Stats

    /// Records the outcome from the perspective of the human `me` (nil for pass & play: counted as a game only).
    func recordOutcome(_ result: GameResult, me: PieceColor?, mode: GameMode, level: EngineLevel? = nil) {
        stats.games += 1
        guard let me else { scheduleSave(); return }
        if result.winner == me {
            stats.wins += 1
            stats.currentStreak += 1
            stats.bestStreak = max(stats.bestStreak, stats.currentStreak)
            if let level { stats.computerWinsByLevel[level.rawValue, default: 0] += 1 }
        } else if result.winner == nil {
            stats.draws += 1
        } else {
            stats.losses += 1
            stats.currentStreak = 0
        }
        scheduleSave()
    }

    func recordPuzzle(_ puzzle: Puzzle, solved: Bool, firstTry: Bool) {
        if solved {
            if !stats.solvedPuzzleIDs.contains(puzzle.id) {
                stats.puzzlesSolved += 1
                stats.solvedPuzzleIDs.insert(puzzle.id)
            }
            if firstTry {
                stats.puzzleStreak += 1
                stats.puzzleRating += max(4, (puzzle.rating - stats.puzzleRating) / 12 + 12)
            } else {
                stats.puzzleStreak = 0
            }
        } else {
            stats.puzzleStreak = 0
            stats.puzzleRating = max(400, stats.puzzleRating - 10)
        }
        scheduleSave()
    }

    func resetStats() {
        stats = PlayerStats()
        scheduleSave()
    }
}
