import Foundation

/// An immutable-by-convention chess position with full move generation.
/// Uses a simple 64-square mailbox; fast enough for a phone engine at the depths we search.
struct Position: Hashable {
    static let startFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    var board: [Piece?]
    var sideToMove: PieceColor
    var castling: CastlingRights
    var enPassant: Square?
    var halfmoveClock: Int
    var fullmoveNumber: Int

    init() {
        self.init(fen: Position.startFEN)!
    }

    init?(fen: String) {
        let parts = fen.split(separator: " ").map(String.init)
        guard parts.count >= 1 else { return nil }
        var squares = [Piece?](repeating: nil, count: 64)
        let ranks = parts[0].split(separator: "/", omittingEmptySubsequences: false)
        guard ranks.count == 8 else { return nil }
        for (i, rankStr) in ranks.enumerated() {
            let rank = 7 - i
            var file = 0
            for ch in rankStr {
                if let digit = ch.wholeNumberValue {
                    file += digit
                } else if let piece = Piece(fenChar: ch) {
                    guard file < 8 else { return nil }
                    squares[rank * 8 + file] = piece
                    file += 1
                } else {
                    return nil
                }
            }
            guard file == 8 else { return nil }
        }
        board = squares
        sideToMove = (parts.count > 1 && parts[1] == "b") ? .black : .white
        var rights = CastlingRights()
        if parts.count > 2 {
            for ch in parts[2] {
                switch ch {
                case "K": rights.insert(.whiteKing)
                case "Q": rights.insert(.whiteQueen)
                case "k": rights.insert(.blackKing)
                case "q": rights.insert(.blackQueen)
                default: break
                }
            }
        }
        castling = rights
        enPassant = parts.count > 3 && parts[3] != "-" ? Square(name: parts[3]) : nil
        halfmoveClock = parts.count > 4 ? Int(parts[4]) ?? 0 : 0
        fullmoveNumber = parts.count > 5 ? Int(parts[5]) ?? 1 : 1
        // Validate: both kings must exist.
        guard king(of: .white) != nil, king(of: .black) != nil else { return nil }
    }

    var fen: String {
        var rows: [String] = []
        for rank in stride(from: 7, through: 0, by: -1) {
            var row = ""
            var empty = 0
            for file in 0..<8 {
                if let piece = board[rank * 8 + file] {
                    if empty > 0 { row += "\(empty)"; empty = 0 }
                    row += piece.fenChar
                } else {
                    empty += 1
                }
            }
            if empty > 0 { row += "\(empty)" }
            rows.append(row)
        }
        let ep = enPassant?.name ?? "-"
        return "\(rows.joined(separator: "/")) \(sideToMove.fenChar) \(castling.fen) \(ep) \(halfmoveClock) \(fullmoveNumber)"
    }

    /// Placement + side + castling + en passant; what matters for repetition.
    var repetitionKey: String {
        let parts = fen.split(separator: " ")
        return parts.prefix(4).joined(separator: " ")
    }

    subscript(_ square: Square) -> Piece? {
        get { board[square.index] }
        set { board[square.index] = newValue }
    }

    func piece(at name: String) -> Piece? {
        guard let sq = Square(name: name) else { return nil }
        return board[sq.index]
    }

    func king(of color: PieceColor) -> Square? {
        for i in 0..<64 {
            if let p = board[i], p.kind == .king, p.color == color { return Square(i) }
        }
        return nil
    }

    func squares(of color: PieceColor) -> [Square] {
        var result: [Square] = []
        result.reserveCapacity(16)
        for i in 0..<64 where board[i]?.color == color { result.append(Square(i)) }
        return result
    }

    var materialCount: Int {
        board.compactMap { $0 }.filter { $0.kind != .king }.count
    }

    // MARK: - Attack detection

    private static let knightOffsets: [(Int, Int)] = [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)]
    private static let kingOffsets: [(Int, Int)] = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]
    private static let bishopDirs: [(Int, Int)] = [(1, 1), (1, -1), (-1, 1), (-1, -1)]
    private static let rookDirs: [(Int, Int)] = [(1, 0), (-1, 0), (0, 1), (0, -1)]

    func isAttacked(_ square: Square, by attacker: PieceColor) -> Bool {
        let f = square.file, r = square.rank
        // Pawns
        let pawnRank = attacker == .white ? r - 1 : r + 1
        if pawnRank >= 0 && pawnRank < 8 {
            for df in [-1, 1] {
                let pf = f + df
                if pf >= 0 && pf < 8, let p = board[pawnRank * 8 + pf], p.color == attacker, p.kind == .pawn { return true }
            }
        }
        // Knights
        for (df, dr) in Position.knightOffsets {
            let nf = f + df, nr = r + dr
            if nf >= 0 && nf < 8 && nr >= 0 && nr < 8, let p = board[nr * 8 + nf], p.color == attacker, p.kind == .knight { return true }
        }
        // King
        for (df, dr) in Position.kingOffsets {
            let nf = f + df, nr = r + dr
            if nf >= 0 && nf < 8 && nr >= 0 && nr < 8, let p = board[nr * 8 + nf], p.color == attacker, p.kind == .king { return true }
        }
        // Sliders
        for (df, dr) in Position.bishopDirs {
            var nf = f + df, nr = r + dr
            while nf >= 0 && nf < 8 && nr >= 0 && nr < 8 {
                if let p = board[nr * 8 + nf] {
                    if p.color == attacker && (p.kind == .bishop || p.kind == .queen) { return true }
                    break
                }
                nf += df; nr += dr
            }
        }
        for (df, dr) in Position.rookDirs {
            var nf = f + df, nr = r + dr
            while nf >= 0 && nf < 8 && nr >= 0 && nr < 8 {
                if let p = board[nr * 8 + nf] {
                    if p.color == attacker && (p.kind == .rook || p.kind == .queen) { return true }
                    break
                }
                nf += df; nr += dr
            }
        }
        return false
    }

    /// All squares attacked by `color` (used for the move guide / threat overlay).
    func attackedSquares(by color: PieceColor) -> Set<Square> {
        var result = Set<Square>()
        for sq in Square.all where isAttacked(sq, by: color) { result.insert(sq) }
        return result
    }

    var isInCheck: Bool {
        guard let k = king(of: sideToMove) else { return false }
        return isAttacked(k, by: sideToMove.opposite)
    }

    func isInCheck(_ color: PieceColor) -> Bool {
        guard let k = king(of: color) else { return false }
        return isAttacked(k, by: color.opposite)
    }

    // MARK: - Move generation

    func pseudoLegalMoves(capturesOnly: Bool = false) -> [Move] {
        var moves: [Move] = []
        moves.reserveCapacity(48)
        let us = sideToMove
        let them = us.opposite
        for i in 0..<64 {
            guard let piece = board[i], piece.color == us else { continue }
            let from = Square(i)
            let f = from.file, r = from.rank
            switch piece.kind {
            case .pawn:
                let dir = us == .white ? 1 : -1
                let startRank = us == .white ? 1 : 6
                let promoRank = us.promotionRank
                let oneR = r + dir
                if oneR >= 0 && oneR < 8 {
                    let oneSq = Square(file: f, rank: oneR)
                    if !capturesOnly || oneR == promoRank {
                        if board[oneSq.index] == nil {
                            appendPawnMove(&moves, from: from, to: oneSq, promoRank: promoRank)
                            if r == startRank && !capturesOnly {
                                let twoSq = Square(file: f, rank: r + 2 * dir)
                                if board[twoSq.index] == nil {
                                    moves.append(Move(from: from, to: twoSq, isDoublePawnPush: true))
                                }
                            }
                        }
                    }
                    for df in [-1, 1] {
                        let cf = f + df
                        guard cf >= 0 && cf < 8 else { continue }
                        let capSq = Square(file: cf, rank: oneR)
                        if let target = board[capSq.index], target.color == them {
                            appendPawnMove(&moves, from: from, to: capSq, promoRank: promoRank)
                        } else if let ep = enPassant, ep == capSq {
                            moves.append(Move(from: from, to: capSq, isEnPassant: true))
                        }
                    }
                }
            case .knight:
                for (df, dr) in Position.knightOffsets {
                    let nf = f + df, nr = r + dr
                    guard nf >= 0 && nf < 8 && nr >= 0 && nr < 8 else { continue }
                    let to = Square(file: nf, rank: nr)
                    if let t = board[to.index] {
                        if t.color == them { moves.append(Move(from: from, to: to)) }
                    } else if !capturesOnly {
                        moves.append(Move(from: from, to: to))
                    }
                }
            case .bishop:
                slide(&moves, from: from, dirs: Position.bishopDirs, them: them, capturesOnly: capturesOnly)
            case .rook:
                slide(&moves, from: from, dirs: Position.rookDirs, them: them, capturesOnly: capturesOnly)
            case .queen:
                slide(&moves, from: from, dirs: Position.bishopDirs + Position.rookDirs, them: them, capturesOnly: capturesOnly)
            case .king:
                for (df, dr) in Position.kingOffsets {
                    let nf = f + df, nr = r + dr
                    guard nf >= 0 && nf < 8 && nr >= 0 && nr < 8 else { continue }
                    let to = Square(file: nf, rank: nr)
                    if let t = board[to.index] {
                        if t.color == them { moves.append(Move(from: from, to: to)) }
                    } else if !capturesOnly {
                        moves.append(Move(from: from, to: to))
                    }
                }
                if !capturesOnly {
                    generateCastling(&moves, from: from)
                }
            }
        }
        return moves
    }

    private func appendPawnMove(_ moves: inout [Move], from: Square, to: Square, promoRank: Int) {
        if to.rank == promoRank {
            for kind in [PieceKind.queen, .rook, .bishop, .knight] {
                moves.append(Move(from: from, to: to, promotion: kind))
            }
        } else {
            moves.append(Move(from: from, to: to))
        }
    }

    private func slide(_ moves: inout [Move], from: Square, dirs: [(Int, Int)], them: PieceColor, capturesOnly: Bool) {
        let f = from.file, r = from.rank
        for (df, dr) in dirs {
            var nf = f + df, nr = r + dr
            while nf >= 0 && nf < 8 && nr >= 0 && nr < 8 {
                let to = Square(file: nf, rank: nr)
                if let t = board[to.index] {
                    if t.color == them { moves.append(Move(from: from, to: to)) }
                    break
                }
                if !capturesOnly { moves.append(Move(from: from, to: to)) }
                nf += df; nr += dr
            }
        }
    }

    private func generateCastling(_ moves: inout [Move], from: Square) {
        let us = sideToMove
        let them = us.opposite
        let rank = us.backRank
        guard from == Square(file: 4, rank: rank) else { return }
        guard !isAttacked(from, by: them) else { return }
        let kingSide: CastlingRights = us == .white ? .whiteKing : .blackKing
        let queenSide: CastlingRights = us == .white ? .whiteQueen : .blackQueen
        if castling.contains(kingSide) {
            let f1 = Square(file: 5, rank: rank), g1 = Square(file: 6, rank: rank), h1 = Square(file: 7, rank: rank)
            if board[f1.index] == nil && board[g1.index] == nil,
               let rook = board[h1.index], rook.kind == .rook, rook.color == us,
               !isAttacked(f1, by: them), !isAttacked(g1, by: them) {
                moves.append(Move(from: from, to: g1, isCastle: true))
            }
        }
        if castling.contains(queenSide) {
            let d1 = Square(file: 3, rank: rank), c1 = Square(file: 2, rank: rank), b1 = Square(file: 1, rank: rank), a1 = Square(file: 0, rank: rank)
            if board[d1.index] == nil && board[c1.index] == nil && board[b1.index] == nil,
               let rook = board[a1.index], rook.kind == .rook, rook.color == us,
               !isAttacked(d1, by: them), !isAttacked(c1, by: them) {
                moves.append(Move(from: from, to: c1, isCastle: true))
            }
        }
    }

    func legalMoves() -> [Move] {
        let us = sideToMove
        return pseudoLegalMoves().filter { move in
            let next = making(move)
            return !next.isInCheck(us)
        }
    }

    func legalCaptures() -> [Move] {
        let us = sideToMove
        return pseudoLegalMoves(capturesOnly: true).filter { move in
            let next = making(move)
            return !next.isInCheck(us)
        }
    }

    func legalMoves(from square: Square) -> [Move] {
        legalMoves().filter { $0.from == square }
    }

    func isLegal(_ move: Move) -> Bool {
        legalMoves().contains(move)
    }

    /// Finds the legal move matching from/to (+promotion), filling in flags like castle/en passant.
    func legalMove(from: Square, to: Square, promotion: PieceKind? = nil) -> Move? {
        legalMoves().first { $0.from == from && $0.to == to && $0.promotion == promotion }
    }

    func isCapture(_ move: Move) -> Bool {
        move.isEnPassant || board[move.to.index] != nil
    }

    func capturedPiece(by move: Move) -> Piece? {
        if move.isEnPassant { return Piece(sideToMove.opposite, .pawn) }
        return board[move.to.index]
    }

    // MARK: - Making moves

    func making(_ move: Move) -> Position {
        var next = self
        next.apply(move)
        return next
    }

    mutating func apply(_ move: Move) {
        guard let piece = board[move.from.index] else { return }
        let us = piece.color
        let captured = board[move.to.index]
        var resetClock = piece.kind == .pawn || captured != nil

        board[move.to.index] = piece
        board[move.from.index] = nil

        if move.isEnPassant {
            let capSq = Square(file: move.to.file, rank: move.from.rank)
            board[capSq.index] = nil
            resetClock = true
        }
        if let promo = move.promotion {
            board[move.to.index] = Piece(us, promo)
        }
        if move.isCastle {
            let rank = us.backRank
            if move.to.file == 6 {
                board[Square(file: 5, rank: rank).index] = board[Square(file: 7, rank: rank).index]
                board[Square(file: 7, rank: rank).index] = nil
            } else {
                board[Square(file: 3, rank: rank).index] = board[Square(file: 0, rank: rank).index]
                board[Square(file: 0, rank: rank).index] = nil
            }
        }

        // Castling rights
        if piece.kind == .king {
            castling.remove(us == .white ? [.whiteKing, .whiteQueen] : [.blackKing, .blackQueen])
        }
        let a1 = 0, h1 = 7, a8 = 56, h8 = 63
        for sq in [move.from.index, move.to.index] {
            switch sq {
            case a1: castling.remove(.whiteQueen)
            case h1: castling.remove(.whiteKing)
            case a8: castling.remove(.blackQueen)
            case h8: castling.remove(.blackKing)
            default: break
            }
        }

        enPassant = move.isDoublePawnPush ? Square(file: move.from.file, rank: (move.from.rank + move.to.rank) / 2) : nil
        halfmoveClock = resetClock ? 0 : halfmoveClock + 1
        if us == .black { fullmoveNumber += 1 }
        sideToMove = us.opposite
    }

    // MARK: - Status helpers

    var hasInsufficientMaterial: Bool {
        var minors: [(PieceColor, PieceKind, Bool)] = []
        for i in 0..<64 {
            guard let p = board[i] else { continue }
            switch p.kind {
            case .king: continue
            case .pawn, .rook, .queen: return false
            case .knight, .bishop: minors.append((p.color, p.kind, Square(i).isLight))
            }
        }
        if minors.isEmpty { return true }
        if minors.count == 1 { return true }
        // Only bishops all on the same colour complex is dead.
        if minors.allSatisfy({ $0.1 == .bishop }) {
            let colors = Set(minors.map { $0.2 })
            return colors.count == 1
        }
        return false
    }

    /// Squares of `color`'s pieces currently attacked by the opponent (for the threat overlay).
    func threatenedPieces(of color: PieceColor) -> [Square] {
        squares(of: color).filter { sq in
            board[sq.index]?.kind != .king && isAttacked(sq, by: color.opposite)
        }
    }

    /// Squares of `color`'s pieces attacked and not defended (hanging pieces).
    func hangingPieces(of color: PieceColor) -> [Square] {
        squares(of: color).filter { sq in
            guard let p = board[sq.index], p.kind != .king else { return false }
            return isAttacked(sq, by: color.opposite) && !isAttacked(sq, by: color)
        }
    }
}
