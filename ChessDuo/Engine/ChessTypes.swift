import Foundation

// MARK: - Core chess value types. Pure Swift, no UI dependencies.

enum PieceColor: String, Codable, CaseIterable, Hashable {
    case white
    case black

    var opposite: PieceColor { self == .white ? .black : .white }
    var fenChar: String { self == .white ? "w" : "b" }
    var pawnDirection: Int { self == .white ? 8 : -8 }
    var backRank: Int { self == .white ? 0 : 7 }
    var promotionRank: Int { self == .white ? 7 : 0 }
}

enum PieceKind: Int, Codable, CaseIterable, Hashable {
    case pawn = 0, knight, bishop, rook, queen, king

    var letter: String {
        switch self {
        case .pawn: return "P"
        case .knight: return "N"
        case .bishop: return "B"
        case .rook: return "R"
        case .queen: return "Q"
        case .king: return "K"
        }
    }

    /// Material value in centipawns.
    var value: Int {
        switch self {
        case .pawn: return 100
        case .knight: return 320
        case .bishop: return 330
        case .rook: return 500
        case .queen: return 900
        case .king: return 20000
        }
    }

    var unicodeWhite: String {
        switch self {
        case .pawn: return "♙"
        case .knight: return "♘"
        case .bishop: return "♗"
        case .rook: return "♖"
        case .queen: return "♕"
        case .king: return "♔"
        }
    }

    var unicodeBlack: String {
        switch self {
        case .pawn: return "♟"
        case .knight: return "♞"
        case .bishop: return "♝"
        case .rook: return "♜"
        case .queen: return "♛"
        case .king: return "♚"
        }
    }

    init?(letter: Character) {
        switch letter.uppercased() {
        case "P": self = .pawn
        case "N": self = .knight
        case "B": self = .bishop
        case "R": self = .rook
        case "Q": self = .queen
        case "K": self = .king
        default: return nil
        }
    }
}

struct Piece: Hashable, Codable {
    var color: PieceColor
    var kind: PieceKind

    var fenChar: String { color == .white ? kind.letter : kind.letter.lowercased() }
    var unicode: String { color == .white ? kind.unicodeWhite : kind.unicodeBlack }

    init(_ color: PieceColor, _ kind: PieceKind) {
        self.color = color
        self.kind = kind
    }

    init?(fenChar: Character) {
        guard let kind = PieceKind(letter: fenChar) else { return nil }
        self.kind = kind
        self.color = fenChar.isUppercase ? .white : .black
    }
}

/// 0 = a1, 7 = h1, 56 = a8, 63 = h8.
struct Square: Hashable, Codable, Comparable, CustomStringConvertible {
    let index: Int

    init(_ index: Int) { self.index = index }
    init(file: Int, rank: Int) { self.index = rank * 8 + file }

    init?(name: String) {
        let chars = Array(name.lowercased())
        guard chars.count == 2,
              let f = "abcdefgh".firstIndex(of: chars[0]),
              let r = "12345678".firstIndex(of: chars[1]) else { return nil }
        let file = "abcdefgh".distance(from: "abcdefgh".startIndex, to: f)
        let rank = "12345678".distance(from: "12345678".startIndex, to: r)
        self.init(file: file, rank: rank)
    }

    var file: Int { index & 7 }
    var rank: Int { index >> 3 }
    var isLight: Bool { (file + rank) % 2 == 1 }
    var fileLetter: String { String("abcdefgh"[ "abcdefgh".index("abcdefgh".startIndex, offsetBy: file) ]) }
    var name: String { "\(fileLetter)\(rank + 1)" }
    var description: String { name }

    static func < (lhs: Square, rhs: Square) -> Bool { lhs.index < rhs.index }
    static let all: [Square] = (0..<64).map(Square.init)
}

struct CastlingRights: OptionSet, Hashable, Codable {
    let rawValue: Int
    static let whiteKing = CastlingRights(rawValue: 1)
    static let whiteQueen = CastlingRights(rawValue: 2)
    static let blackKing = CastlingRights(rawValue: 4)
    static let blackQueen = CastlingRights(rawValue: 8)
    static let all: CastlingRights = [.whiteKing, .whiteQueen, .blackKing, .blackQueen]

    var fen: String {
        var s = ""
        if contains(.whiteKing) { s += "K" }
        if contains(.whiteQueen) { s += "Q" }
        if contains(.blackKing) { s += "k" }
        if contains(.blackQueen) { s += "q" }
        return s.isEmpty ? "-" : s
    }
}

struct Move: Hashable, Codable, CustomStringConvertible {
    var from: Square
    var to: Square
    var promotion: PieceKind?
    var isEnPassant: Bool = false
    var isCastle: Bool = false
    var isDoublePawnPush: Bool = false

    var uci: String {
        var s = from.name + to.name
        if let promotion { s += promotion.letter.lowercased() }
        return s
    }

    var description: String { uci }

    init(from: Square, to: Square, promotion: PieceKind? = nil, isEnPassant: Bool = false, isCastle: Bool = false, isDoublePawnPush: Bool = false) {
        self.from = from
        self.to = to
        self.promotion = promotion
        self.isEnPassant = isEnPassant
        self.isCastle = isCastle
        self.isDoublePawnPush = isDoublePawnPush
    }

    /// Two moves are the "same" for user intent purposes when squares and promotion match.
    func matches(from: Square, to: Square, promotion: PieceKind?) -> Bool {
        self.from == from && self.to == to && self.promotion == promotion
    }
}

enum GameTermination: String, Codable, Hashable {
    case checkmate
    case stalemate
    case insufficientMaterial
    case fiftyMoveRule
    case threefoldRepetition
    case resignation
    case drawAgreed
    case timeout
    case abandoned
}

struct GameResult: Hashable, Codable {
    var winner: PieceColor?     // nil = draw
    var termination: GameTermination

    var isDraw: Bool { winner == nil }
    var pgnResult: String {
        switch winner {
        case .white?: return "1-0"
        case .black?: return "0-1"
        case nil: return "1/2-1/2"
        }
    }
}

/// A move together with everything needed to describe and undo it.
struct MoveRecord: Hashable, Codable, Identifiable {
    var id: Int { ply }
    var ply: Int                // 1-based
    var move: Move
    var san: String
    var piece: Piece
    var captured: Piece?
    var fenAfter: String
    var isCheck: Bool
    var isMate: Bool
    var color: PieceColor
    /// Engine evaluation (centipawns, from the mover's point of view) filled in by the reviewer.
    var evalBefore: Int?
    var evalAfter: Int?
    var assisted: Bool = false
    var timestamp: Date = Date()

    var moveNumber: Int { (ply + 1) / 2 }
}
