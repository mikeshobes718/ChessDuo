import Foundation

enum OnlineRole: String, Codable {
    case white, black, spectator

    var pieceColor: PieceColor? {
        switch self {
        case .white: return .white
        case .black: return .black
        case .spectator: return nil
        }
    }
}

struct OnlineSessionInfo: Codable, Equatable {
    var roomCode: String
    var playerToken: String
    var role: OnlineRole
    var playerName: String
}

struct OnlineLegalMove: Decodable, Hashable {
    var from: String
    var to: String
    var promotion: String?
    var san: String?
}

struct OnlineLastMove: Decodable, Equatable {
    var from: String?
    var to: String?
    var san: String?
    var captured: String?
    var by: String?
}

struct OnlineCoachItem: Decodable, Equatable, Identifiable {
    var text: String
    var source: String
    var at: String
    var id: String { at + text.prefix(16) }
}

struct OnlineQuizOption: Decodable, Equatable, Identifiable {
    var square: String
    var label: String
    var id: String { square }
}

struct OnlineQuiz: Decodable, Equatable {
    var question: String?
    var options: [OnlineQuizOption]?
    var answerSquare: String?
}

struct OnlineMoveEntry: Decodable, Equatable {
    var from: String?
    var to: String?
    var san: String?
    var by: String?
    var assisted: Bool?
}

struct OnlineNudge: Decodable, Equatable {
    var by: String?
    var at: String?
    var message: String?
}

/// Tolerant decoder for the game edge function; any field may be missing.
struct OnlineResponse: Decodable {
    var roomCode: String?
    var playerToken: String?
    var color: String?
    var fen: String?
    var turn: String?
    var status: String?
    var whiteName: String?
    var blackName: String?
    var isCheck: Bool?
    var result: String?
    var message: String?
    var hint: String?
    var coachText: String?
    var coachSource: String?
    var coachHistory: [OnlineCoachItem]?
    var version: Int?
    var moveCount: Int?
    var legalMoves: [OnlineLegalMove]?
    var lastMove: OnlineLastMove?
    var suggestedHint: OnlineLastMove?
    var quiz: OnlineQuiz?
    var threatenedSquares: [String]?
    var hintsRemaining: Int?
    var dailyHintLimit: Int?
    var apiVersion: String?
    var privateHint: Bool?
    var moveHistory: [OnlineMoveEntry]?
    var drawOfferBy: String?
    var undoOfferBy: String?
    var changed: Bool?
    var nudge: OnlineNudge?
    var nudgeCooldownRemaining: Int?
    var nudgeRemaining: Int?
    var error: String?
    var gameOver: Bool?

    private enum CodingKeys: String, CodingKey {
        case roomCode, room, code, playerToken, token, color, playerColor, fen, turn, status
        case whiteName, blackName, isCheck, check, result, message, error, hint, coachText, coachSource, coachHistory
        case version, moveCount, legalMoves, lastMove, suggestedHint, quiz, threatenedSquares, hintsRemaining, dailyHintLimit
        case apiVersion, privateHint, moveHistory, drawOfferBy, undoOfferBy, changed, nudge, nudgeCooldownRemaining, nudgeRemaining, game, names, gameOver
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let nested = try? c.decode(OnlineResponse.self, forKey: .game) { self = nested }
        func str(_ keys: [CodingKeys]) -> String? {
            for k in keys { if let v = try? c.decode(String.self, forKey: k) { return v } }
            return nil
        }
        roomCode = str([.roomCode, .room, .code]) ?? roomCode
        playerToken = str([.playerToken, .token]) ?? playerToken
        color = str([.color, .playerColor])?.lowercased() ?? color
        fen = str([.fen]) ?? fen
        turn = str([.turn])?.lowercased() ?? turn
        status = str([.status]) ?? status
        whiteName = str([.whiteName]) ?? whiteName
        blackName = str([.blackName]) ?? blackName
        if let names = try? c.decode([String: String?].self, forKey: .names) {
            if let w = names["white"] ?? nil { whiteName = w }
            if let b = names["black"] ?? nil { blackName = b }
        }
        isCheck = (try? c.decode(Bool.self, forKey: .isCheck)) ?? (try? c.decode(Bool.self, forKey: .check)) ?? isCheck
        result = str([.result]) ?? result
        message = str([.message]) ?? message
        error = str([.error]) ?? error
        gameOver = (try? c.decode(Bool.self, forKey: .gameOver)) ?? gameOver
        hint = str([.hint]) ?? hint
        coachText = str([.coachText]) ?? coachText
        coachSource = str([.coachSource]) ?? coachSource
        coachHistory = (try? c.decode([OnlineCoachItem].self, forKey: .coachHistory)) ?? coachHistory
        version = (try? c.decode(Int.self, forKey: .version)) ?? version
        moveCount = (try? c.decode(Int.self, forKey: .moveCount)) ?? moveCount
        legalMoves = (try? c.decode([OnlineLegalMove].self, forKey: .legalMoves)) ?? legalMoves
        lastMove = (try? c.decode(OnlineLastMove.self, forKey: .lastMove)) ?? lastMove
        suggestedHint = (try? c.decode(OnlineLastMove.self, forKey: .suggestedHint)) ?? suggestedHint
        quiz = (try? c.decode(OnlineQuiz.self, forKey: .quiz)) ?? quiz
        threatenedSquares = (try? c.decode([String].self, forKey: .threatenedSquares)) ?? threatenedSquares
        hintsRemaining = (try? c.decode(Int.self, forKey: .hintsRemaining)) ?? hintsRemaining
        dailyHintLimit = (try? c.decode(Int.self, forKey: .dailyHintLimit)) ?? dailyHintLimit
        apiVersion = str([.apiVersion]) ?? apiVersion
        privateHint = (try? c.decode(Bool.self, forKey: .privateHint)) ?? privateHint
        moveHistory = (try? c.decode([OnlineMoveEntry].self, forKey: .moveHistory)) ?? moveHistory
        if c.contains(.drawOfferBy) { drawOfferBy = str([.drawOfferBy]) }
        if c.contains(.undoOfferBy) { undoOfferBy = str([.undoOfferBy]) }
        changed = (try? c.decode(Bool.self, forKey: .changed)) ?? changed
        nudge = (try? c.decode(OnlineNudge.self, forKey: .nudge)) ?? nudge
        nudgeCooldownRemaining = (try? c.decode(Int.self, forKey: .nudgeCooldownRemaining)) ?? nudgeCooldownRemaining
        nudgeRemaining = (try? c.decode(Int.self, forKey: .nudgeRemaining)) ?? nudgeRemaining
    }
}

struct OnlineArchive: Identifiable, Hashable {
    var id: String
    var roomCode: String
    var whiteName: String
    var blackName: String
    var status: String
    var resultText: String
    var moveCount: Int
    var endedAt: Date
    var sans: [String]
}
