import Foundation

/// Static evaluation: material + piece-square tables + a few positional terms.
/// Returns centipawns from White's point of view.
enum Evaluation {
    // Tables are written from White's perspective, rank 8 first (as usually printed), so we flip on lookup.
    private static let pawnTable: [Int] = [
         0,  0,  0,  0,  0,  0,  0,  0,
        50, 50, 50, 50, 50, 50, 50, 50,
        10, 10, 20, 30, 30, 20, 10, 10,
         5,  5, 10, 25, 25, 10,  5,  5,
         0,  0,  0, 20, 20,  0,  0,  0,
         5, -5,-10,  0,  0,-10, -5,  5,
         5, 10, 10,-20,-20, 10, 10,  5,
         0,  0,  0,  0,  0,  0,  0,  0
    ]
    private static let knightTable: [Int] = [
        -50,-40,-30,-30,-30,-30,-40,-50,
        -40,-20,  0,  0,  0,  0,-20,-40,
        -30,  0, 10, 15, 15, 10,  0,-30,
        -30,  5, 15, 20, 20, 15,  5,-30,
        -30,  0, 15, 20, 20, 15,  0,-30,
        -30,  5, 10, 15, 15, 10,  5,-30,
        -40,-20,  0,  5,  5,  0,-20,-40,
        -50,-40,-30,-30,-30,-30,-40,-50
    ]
    private static let bishopTable: [Int] = [
        -20,-10,-10,-10,-10,-10,-10,-20,
        -10,  0,  0,  0,  0,  0,  0,-10,
        -10,  0,  5, 10, 10,  5,  0,-10,
        -10,  5,  5, 10, 10,  5,  5,-10,
        -10,  0, 10, 10, 10, 10,  0,-10,
        -10, 10, 10, 10, 10, 10, 10,-10,
        -10,  5,  0,  0,  0,  0,  5,-10,
        -20,-10,-10,-10,-10,-10,-10,-20
    ]
    private static let rookTable: [Int] = [
          0,  0,  0,  0,  0,  0,  0,  0,
          5, 10, 10, 10, 10, 10, 10,  5,
         -5,  0,  0,  0,  0,  0,  0, -5,
         -5,  0,  0,  0,  0,  0,  0, -5,
         -5,  0,  0,  0,  0,  0,  0, -5,
         -5,  0,  0,  0,  0,  0,  0, -5,
         -5,  0,  0,  0,  0,  0,  0, -5,
          0,  0,  0,  5,  5,  0,  0,  0
    ]
    private static let queenTable: [Int] = [
        -20,-10,-10, -5, -5,-10,-10,-20,
        -10,  0,  0,  0,  0,  0,  0,-10,
        -10,  0,  5,  5,  5,  5,  0,-10,
         -5,  0,  5,  5,  5,  5,  0, -5,
          0,  0,  5,  5,  5,  5,  0, -5,
        -10,  5,  5,  5,  5,  5,  0,-10,
        -10,  0,  5,  0,  0,  0,  0,-10,
        -20,-10,-10, -5, -5,-10,-10,-20
    ]
    private static let kingMidTable: [Int] = [
        -30,-40,-40,-50,-50,-40,-40,-30,
        -30,-40,-40,-50,-50,-40,-40,-30,
        -30,-40,-40,-50,-50,-40,-40,-30,
        -30,-40,-40,-50,-50,-40,-40,-30,
        -20,-30,-30,-40,-40,-30,-30,-20,
        -10,-20,-20,-20,-20,-20,-20,-10,
         20, 20,  0,  0,  0,  0, 20, 20,
         20, 30, 10,  0,  0, 10, 30, 20
    ]
    private static let kingEndTable: [Int] = [
        -50,-40,-30,-20,-20,-30,-40,-50,
        -30,-20,-10,  0,  0,-10,-20,-30,
        -30,-10, 20, 30, 30, 20,-10,-30,
        -30,-10, 30, 40, 40, 30,-10,-30,
        -30,-10, 30, 40, 40, 30,-10,-30,
        -30,-10, 20, 30, 30, 20,-10,-30,
        -30,-30,  0,  0,  0,  0,-30,-30,
        -50,-30,-30,-30,-30,-30,-30,-50
    ]

    @inline(__always)
    private static func tableIndex(_ square: Int, white: Bool) -> Int {
        let rank = square >> 3, file = square & 7
        // Table row 0 is rank 8.
        return white ? (7 - rank) * 8 + file : rank * 8 + file
    }

    static func isEndgame(_ p: Position) -> Bool {
        var queens = 0, minorsAndRooks = 0
        for piece in p.board {
            guard let piece else { continue }
            switch piece.kind {
            case .queen: queens += 1
            case .rook, .bishop, .knight: minorsAndRooks += 1
            default: break
            }
        }
        return queens == 0 || minorsAndRooks <= 2
    }

    static func evaluate(_ p: Position) -> Int {
        var score = 0
        let endgame = isEndgame(p)
        var whiteBishops = 0, blackBishops = 0
        var pawnFilesWhite = [Int](repeating: 0, count: 8)
        var pawnFilesBlack = [Int](repeating: 0, count: 8)
        for i in 0..<64 {
            guard let piece = p.board[i] else { continue }
            let white = piece.color == .white
            let idx = tableIndex(i, white: white)
            var v = piece.kind.value
            switch piece.kind {
            case .pawn:
                v += pawnTable[idx]
                if white { pawnFilesWhite[i & 7] += 1 } else { pawnFilesBlack[i & 7] += 1 }
            case .knight: v += knightTable[idx]
            case .bishop:
                v += bishopTable[idx]
                if white { whiteBishops += 1 } else { blackBishops += 1 }
            case .rook: v += rookTable[idx]
            case .queen: v += queenTable[idx]
            case .king: v = (endgame ? kingEndTable[idx] : kingMidTable[idx])
            }
            score += white ? v : -v
        }
        if whiteBishops >= 2 { score += 30 }
        if blackBishops >= 2 { score -= 30 }
        // Doubled / isolated pawns.
        for f in 0..<8 {
            if pawnFilesWhite[f] > 1 { score -= 12 * (pawnFilesWhite[f] - 1) }
            if pawnFilesBlack[f] > 1 { score += 12 * (pawnFilesBlack[f] - 1) }
            let leftW = f > 0 ? pawnFilesWhite[f - 1] : 0, rightW = f < 7 ? pawnFilesWhite[f + 1] : 0
            let leftB = f > 0 ? pawnFilesBlack[f - 1] : 0, rightB = f < 7 ? pawnFilesBlack[f + 1] : 0
            if pawnFilesWhite[f] > 0 && leftW + rightW == 0 { score -= 10 }
            if pawnFilesBlack[f] > 0 && leftB + rightB == 0 { score += 10 }
        }
        return score
    }

    /// Evaluation from the side to move's perspective.
    static func evaluateRelative(_ p: Position) -> Int {
        let e = evaluate(p)
        return p.sideToMove == .white ? e : -e
    }
}
