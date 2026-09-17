import Foundation

enum GameMode: String, Codable, Hashable {
    case local, computer, online, puzzle, analysis

    var title: String {
        switch self {
        case .local: return L10n.t("home.passPlay")
        case .computer: return L10n.t("home.computer")
        case .online: return L10n.t("home.playOnline")
        case .puzzle: return L10n.t("home.puzzles")
        case .analysis: return L10n.t("home.analysis")
        }
    }
}

/// A saved game (finished or in progress) for history, resume and review.
struct GameRecord: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var mode: GameMode
    var whiteName: String
    var blackName: String
    var startFEN: String
    var moves: [MoveRecord]
    var result: GameResult?
    var startedAt: Date
    var endedAt: Date?
    var timeControl: TimeControl
    var computerLevel: EngineLevel?
    var humanColor: PieceColor?          // for computer games
    var roomCode: String?
    var whiteClock: TimeInterval?
    var blackClock: TimeInterval?
    var review: ReviewSummary?

    var isFinished: Bool { result != nil }
    var moveCount: Int { (moves.count + 1) / 2 }

    var pgn: String {
        game.pgn(white: whiteName, black: blackName, event: mode.title, date: startedAt)
    }

    /// Rebuilds a ChessGame from the record.
    var game: ChessGame {
        var g = ChessGame(fen: startFEN)
        for m in moves { g.play(m.move, assisted: m.assisted) }
        if let result, g.result == nil { g.setResult(result) }
        return g
    }

    var resultText: String {
        guard let result else { return L10n.t("history.inProgress") }
        return GameRecord.describe(result: result, white: whiteName, black: blackName)
    }

    static func describe(result: GameResult, white: String, black: String) -> String {
        let winnerName = result.winner == .white ? white : black
        let loserName = result.winner == .white ? black : white
        switch result.termination {
        case .checkmate: return "\(L10n.t("over.checkmate")) · \(L10n.t("over.winner", winnerName))"
        case .stalemate: return L10n.t("over.stalemate")
        case .insufficientMaterial: return L10n.t("over.insufficient")
        case .fiftyMoveRule: return L10n.t("over.fifty")
        case .threefoldRepetition: return L10n.t("over.repetition")
        case .resignation: return "\(L10n.t("over.resignation", loserName)) · \(L10n.t("over.winner", winnerName))"
        case .drawAgreed: return L10n.t("over.drawAgreed")
        case .timeout: return result.winner == nil ? L10n.t("over.draw") : "\(L10n.t("over.timeout", loserName)) · \(L10n.t("over.winner", winnerName))"
        case .abandoned: return L10n.t("over.abandoned")
        }
    }
}

enum MoveQuality: String, Codable, Hashable, CaseIterable {
    case book, best, good, inaccuracy, mistake, blunder

    var title: String { L10n.t("review.\(rawValue)") }
    var symbol: String {
        switch self {
        case .book: return "📖"
        case .best: return "★"
        case .good: return "✓"
        case .inaccuracy: return "?!"
        case .mistake: return "?"
        case .blunder: return "??"
        }
    }
}

struct MoveReview: Codable, Hashable, Identifiable {
    var id: Int { ply }
    var ply: Int
    var san: String
    var color: PieceColor
    var quality: MoveQuality
    var evalBefore: Int        // white-perspective centipawns before the move
    var evalAfter: Int
    var bestSan: String?
    var assisted: Bool
    var centipawnLoss: Int
}

struct PlayerReviewSummary: Codable, Hashable {
    var accuracy: Int
    var unaidedAccuracy: Int
    var best: Int
    var good: Int
    var inaccuracies: Int
    var mistakes: Int
    var blunders: Int
    var assisted: Int
}

struct ReviewSummary: Codable, Hashable {
    var white: PlayerReviewSummary
    var black: PlayerReviewSummary
    var moves: [MoveReview]
    var evals: [Int]          // white-perspective eval after each ply, index 0 = start
}

struct PlayerStats: Codable, Hashable {
    var games = 0
    var wins = 0
    var losses = 0
    var draws = 0
    var currentStreak = 0
    var bestStreak = 0
    var puzzlesSolved = 0
    var puzzleStreak = 0
    var puzzleRating = 800
    var computerWinsByLevel: [Int: Int] = [:]
    var solvedPuzzleIDs: Set<String> = []

    var winRate: Int { games == 0 ? 0 : Int((Double(wins) / Double(games) * 100).rounded()) }
}
