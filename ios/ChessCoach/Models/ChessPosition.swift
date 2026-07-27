import Foundation

struct ChessPiece: Equatable {
    let symbol: Character

    var isWhite: Bool { symbol.isUppercase }

    var glyph: String {
        switch symbol {
        case "K": return "♔"
        case "Q": return "♕"
        case "R": return "♖"
        case "B": return "♗"
        case "N": return "♘"
        case "P": return "♙"
        case "k": return "♚"
        case "q": return "♛"
        case "r": return "♜"
        case "b": return "♝"
        case "n": return "♞"
        case "p": return "♟"
        default: return ""
        }
    }

    var accessibilityName: String {
        let color = isWhite ? "white" : "black"
        let name: String
        switch symbol.lowercased() {
        case "k": name = "king"
        case "q": name = "queen"
        case "r": name = "rook"
        case "b": name = "bishop"
        case "n": name = "knight"
        default: name = "pawn"
        }
        return "\(color) \(name)"
    }
}

struct ChessPosition {
    let pieces: [String: ChessPiece]

    init(fen: String) {
        let placement = fen.split(separator: " ").first.map(String.init) ?? ""
        let ranks = placement.split(separator: "/", omittingEmptySubsequences: false)
        var parsed: [String: ChessPiece] = [:]

        for (rankIndex, rank) in ranks.prefix(8).enumerated() {
            var fileIndex = 0
            for character in rank {
                if let emptyCount = character.wholeNumberValue {
                    fileIndex += emptyCount
                } else if fileIndex < 8 {
                    let file = String(UnicodeScalar(97 + fileIndex)!)
                    let square = "\(file)\(8 - rankIndex)"
                    parsed[square] = ChessPiece(symbol: character)
                    fileIndex += 1
                }
            }
        }
        pieces = parsed
    }
}
