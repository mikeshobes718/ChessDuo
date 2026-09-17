import Foundation

extension Position {
    /// Standard Algebraic Notation for a legal move in this position.
    func san(for move: Move, legal: [Move]? = nil) -> String {
        guard let piece = board[move.from.index] else { return move.uci }
        let next = making(move)
        let suffix: String = {
            if next.isInCheck {
                return next.legalMoves().isEmpty ? "#" : "+"
            }
            return ""
        }()
        if move.isCastle {
            return (move.to.file == 6 ? "O-O" : "O-O-O") + suffix
        }
        let capture = isCapture(move)
        if piece.kind == .pawn {
            var s = capture ? "\(move.from.fileLetter)x\(move.to.name)" : move.to.name
            if let promo = move.promotion { s += "=\(promo.letter)" }
            return s + suffix
        }
        var s = piece.kind.letter
        // Disambiguation
        let all = legal ?? legalMoves()
        let rivals = all.filter { $0.to == move.to && $0.from != move.from && board[$0.from.index]?.kind == piece.kind }
        if !rivals.isEmpty {
            let sameFile = rivals.contains { $0.from.file == move.from.file }
            let sameRank = rivals.contains { $0.from.rank == move.from.rank }
            if !sameFile {
                s += move.from.fileLetter
            } else if !sameRank {
                s += "\(move.from.rank + 1)"
            } else {
                s += move.from.name
            }
        }
        if capture { s += "x" }
        s += move.to.name
        return s + suffix
    }

    /// Parses SAN ("Nf3", "exd5", "O-O", "e8=Q+") into a legal move.
    func move(fromSAN input: String) -> Move? {
        var s = input.trimmingCharacters(in: .whitespaces)
        s = s.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "!", with: "").replacingOccurrences(of: "?", with: "")
        let legal = legalMoves()
        if s == "O-O" || s == "0-0" { return legal.first { $0.isCastle && $0.to.file == 6 } }
        if s == "O-O-O" || s == "0-0-0" { return legal.first { $0.isCastle && $0.to.file == 2 } }
        // Try matching by generating SAN for each legal move (robust and simple).
        for m in legal where san(for: m, legal: legal).replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "#", with: "") == s {
            return m
        }
        // Also accept UCI.
        if s.count >= 4, let from = Square(name: String(s.prefix(2))), let to = Square(name: String(s.dropFirst(2).prefix(2))) {
            let promo: PieceKind? = s.count > 4 ? PieceKind(letter: s.last!) : nil
            return legal.first { $0.from == from && $0.to == to && $0.promotion == promo }
        }
        return nil
    }
}
