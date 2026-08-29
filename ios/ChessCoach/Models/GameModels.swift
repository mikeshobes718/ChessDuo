import Foundation

enum PlayerColor: String, Codable {
    case white
    case black
    case spectator

    var opponent: PlayerColor {
        switch self {
        case .white: return .black
        case .black: return .white
        case .spectator: return .spectator
        }
    }

    var displayName: String {
        switch self {
        case .white: return L10n.t(.whiteLabel)
        case .black: return L10n.t(.blackLabel)
        case .spectator: return L10n.t(.spectating)
        }
    }
}

struct PlayerSession: Codable, Equatable {
    let roomCode: String
    let playerToken: String
    let color: PlayerColor
    let playerName: String
}

struct LegalMove: Codable, Hashable {
    let from: String
    let to: String
    let promotion: String?
    let san: String?
    let isCapture: Bool?
    let isCheck: Bool?

    init(from: String, to: String, promotion: String? = nil, san: String? = nil, isCapture: Bool? = nil, isCheck: Bool? = nil) {
        self.from = from.lowercased()
        self.to = to.lowercased()
        self.promotion = promotion
        self.san = san
        self.isCapture = isCapture
        self.isCheck = isCheck
    }

    init?(uci: String) {
        let value = uci.lowercased()
        guard value.count >= 4 else { return nil }
        let index = value.index(value.startIndex, offsetBy: 2)
        from = String(value[..<index])
        let destinationEnd = value.index(index, offsetBy: 2)
        to = String(value[index..<destinationEnd])
        promotion = value.count > 4 ? String(value[destinationEnd...]) : nil
        san = nil
        isCapture = nil
        isCheck = nil
    }
}

struct LastMove: Codable, Equatable {
    var from: String?
    var to: String?
    var san: String?
    var captured: String?
    var by: String?
}

struct SuggestedHint: Codable, Equatable {
    var from: String?
    var to: String?
    var san: String?
}

struct QuizOption: Codable, Equatable, Identifiable {
    var square: String
    var label: String
    var id: String { square }
}

struct QuizPrompt: Codable, Equatable {
    var question: String?
    var options: [QuizOption]?
    var answerSquare: String?
}

struct CoachHistoryItem: Codable, Equatable, Identifiable {
    var text: String
    var source: String
    var at: String
    var id: String { "\(at)-\(text.prefix(24))" }
}

struct CapturedPieces: Codable, Equatable {
    var whiteTaken: [String]?
    var blackTaken: [String]?
}

struct MoveReviewEntry: Codable, Equatable, Identifiable {
    var from: String?
    var to: String?
    var san: String?
    var by: String?
    var assisted: Bool?
    var precision: Int?
    var label: String?

    var id: String { "\(by ?? "")-\(san ?? "")-\(from ?? "")-\(to ?? "")-\(precision ?? 0)" }
}

struct PlayerReview: Codable, Equatable {
    var name: String?
    var accuracy: Int?
    var unaidedAccuracy: Int?
    var moveCount: Int?
    var assistedCount: Int?
    var bestPrecision: Int?
    var lowestPrecision: Int?
}

struct MatchReview: Codable, Equatable {
    var white: PlayerReview?
    var black: PlayerReview?
    var moves: [MoveReviewEntry]?
}

struct GameState: Equatable {
    var roomCode = ""
    var fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    var turn: PlayerColor = .white
    var status = "waiting"
    var whiteName = "White"
    var blackName = "Black"
    var isCheck = false
    var result: String?
    var legalMoves: [LegalMove] = []
    var coachMessage = "Look for checks, captures, and threats before every move."
    var coachSource = "quick"
    var coachHistory: [CoachHistoryItem] = []
    var version = 0
    var moveCount = 0
    var lastMove: LastMove?
    var suggestedHint: SuggestedHint?
    var quiz: QuizPrompt?
    var threatenedSquares: [String] = []
    var captured = CapturedPieces()
    var hintsRemaining = 20
    var dailyHintLimit = 20
    var goalText = "Goal: put the other king in checkmate (attacked with no escape)."
    var apiVersion: String?
    var moveHistory: [MoveReviewEntry] = []
    var review: MatchReview?
    var drawOfferBy: PlayerColor?
    var undoOfferBy: PlayerColor?
    var lastNudge: NudgeEvent?
    var nudgeCooldownRemaining = 0
    var nudgeRemaining = 8

    var isFinished: Bool {
        result != nil || ["white_won", "black_won", "draw", "finished", "checkmate", "resigned"].contains(status.lowercased())
    }
}

struct GameResponse: Decodable {
    var roomCode: String?
    var playerToken: String?
    var color: PlayerColor?
    var fen: String?
    var turn: PlayerColor?
    var status: String?
    var whiteName: String?
    var blackName: String?
    var isCheck: Bool?
    var result: String?
    var message: String?
    var hint: String?
    var coachText: String?
    var coachSource: String?
    var coachHistory: [CoachHistoryItem]?
    var version: Int?
    var moveCount: Int?
    var legalMoves: [LegalMove]?
    var lastMove: LastMove?
    var suggestedHint: SuggestedHint?
    var quiz: QuizPrompt?
    var threatenedSquares: [String]?
    var captured: CapturedPieces?
    var hintsRemaining: Int?
    var dailyHintLimit: Int?
    var goalText: String?
    var apiVersion: String?
    var privateHint: Bool?
    var moveHistory: [MoveReviewEntry]?
    var review: MatchReview?
    var drawOfferBy: PlayerColor?
    var undoOfferBy: PlayerColor?
    var changed: Bool?
    var nudge: NudgeEvent?
    var nudgeCooldownRemaining: Int?
    var nudgeRemaining: Int?
    var delivered: String?

    private enum CodingKeys: String, CodingKey {
        case roomCode, room, code, playerToken, token, color, playerColor
        case fen, turn, status, whiteName, blackName, whitePlayer, blackPlayer
        case isCheck, check, result, message, error, hint, coachText, coachSource
        case coachHistory, version, moveCount, legalMoves, moves, game, names
        case lastMove, suggestedHint, quiz, threatenedSquares, captured
        case hintsRemaining, dailyHintLimit, goalText, apiVersion, privateHint
        case moveHistory, review, drawOfferBy, undoOfferBy, changed
        case nudge, nudgeCooldownRemaining, nudgeRemaining, delivered
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let nested = try? container.decode(GameResponse.self, forKey: .game) {
            self = nested
        }
        roomCode = Self.string(container, [.roomCode, .room, .code]) ?? roomCode
        playerToken = Self.string(container, [.playerToken, .token]) ?? playerToken
        if let value = Self.string(container, [.color, .playerColor]) {
            color = PlayerColor(rawValue: value.lowercased())
        }
        fen = Self.string(container, [.fen]) ?? fen
        if let value = Self.string(container, [.turn]) {
            turn = PlayerColor(rawValue: value.lowercased())
        }
        status = Self.string(container, [.status]) ?? status
        whiteName = Self.string(container, [.whiteName, .whitePlayer]) ?? whiteName
        blackName = Self.string(container, [.blackName, .blackPlayer]) ?? blackName
        if let names = try? container.decode([String: String?].self, forKey: .names) {
            whiteName = names["white"] ?? whiteName
            blackName = names["black"] ?? blackName
        }
        isCheck = Self.bool(container, [.isCheck, .check]) ?? isCheck
        result = Self.string(container, [.result]) ?? result
        message = Self.string(container, [.message, .error]) ?? message
        hint = Self.string(container, [.hint]) ?? hint
        coachText = Self.string(container, [.coachText]) ?? coachText
        coachSource = Self.string(container, [.coachSource]) ?? coachSource
        coachHistory = (try? container.decode([CoachHistoryItem].self, forKey: .coachHistory)) ?? coachHistory
        version = try? container.decode(Int.self, forKey: .version)
        moveCount = try? container.decode(Int.self, forKey: .moveCount)
        legalMoves = Self.moves(container) ?? legalMoves
        lastMove = try? container.decode(LastMove.self, forKey: .lastMove)
        suggestedHint = try? container.decode(SuggestedHint.self, forKey: .suggestedHint)
        quiz = try? container.decode(QuizPrompt.self, forKey: .quiz)
        threatenedSquares = (try? container.decode([String].self, forKey: .threatenedSquares)) ?? threatenedSquares
        captured = (try? container.decode(CapturedPieces.self, forKey: .captured)) ?? captured
        hintsRemaining = try? container.decode(Int.self, forKey: .hintsRemaining)
        dailyHintLimit = try? container.decode(Int.self, forKey: .dailyHintLimit)
        goalText = Self.string(container, [.goalText]) ?? goalText
        apiVersion = Self.string(container, [.apiVersion]) ?? apiVersion
        privateHint = Self.bool(container, [.privateHint]) ?? privateHint
        moveHistory = (try? container.decode([MoveReviewEntry].self, forKey: .moveHistory)) ?? moveHistory
        review = (try? container.decode(MatchReview.self, forKey: .review)) ?? review
        if let value = Self.string(container, [.drawOfferBy]) {
            drawOfferBy = PlayerColor(rawValue: value.lowercased())
        } else if container.contains(.drawOfferBy), (try? container.decodeNil(forKey: .drawOfferBy)) == true {
            drawOfferBy = nil
        }
        if let value = Self.string(container, [.undoOfferBy]) {
            undoOfferBy = PlayerColor(rawValue: value.lowercased())
        } else if container.contains(.undoOfferBy), (try? container.decodeNil(forKey: .undoOfferBy)) == true {
            undoOfferBy = nil
        }
        changed = try? container.decode(Bool.self, forKey: .changed)
        nudge = try? container.decode(NudgeEvent.self, forKey: .nudge)
        nudgeCooldownRemaining = try? container.decode(Int.self, forKey: .nudgeCooldownRemaining)
        nudgeRemaining = try? container.decode(Int.self, forKey: .nudgeRemaining)
        delivered = Self.string(container, [.delivered])
    }

    private static func string(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ keys: [CodingKeys]
    ) -> String? {
        for key in keys {
            if let value = try? container.decode(String.self, forKey: key) {
                return value
            }
        }
        return nil
    }

    private static func bool(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ keys: [CodingKeys]
    ) -> Bool? {
        for key in keys {
            if let value = try? container.decode(Bool.self, forKey: key) {
                return value
            }
        }
        return nil
    }

    private static func moves(
        _ container: KeyedDecodingContainer<CodingKeys>
    ) -> [LegalMove]? {
        for key in [CodingKeys.legalMoves, .moves] {
            if let values = try? container.decode([LegalMove].self, forKey: key) {
                return values
            }
            if let values = try? container.decode([String].self, forKey: key) {
                return values.compactMap(LegalMove.init(uci:))
            }
            if let values = try? container.decode([String: [String]].self, forKey: key) {
                return values.flatMap { from, destinations in
                    destinations.map { LegalMove(from: from, to: $0) }
                }
            }
        }
        return nil
    }
}
