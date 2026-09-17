import Foundation

/// Rule-based coaching that runs instantly on device. Text keys are localized by the caller.
enum Coach {
    struct Advice: Equatable {
        var text: String
        var highlight: [Square] = []
        var suggested: Move?
    }

    /// Advice for the side to move in `position`, given the last move played (if any).
    static func advise(position: Position, lastMove: MoveRecord?, mover: PieceColor, lastMoveQuality: MoveQuality? = nil) -> Advice {
        let legal = position.legalMoves()
        if legal.isEmpty { return Advice(text: "") }

        if position.isInCheck {
            return Advice(text: L10n.t("coach.check"), highlight: position.king(of: mover).map { [$0] } ?? [])
        }

        // Mate in one available?
        if let mate = legal.first(where: { let n = position.making($0); return n.isInCheck && n.legalMoves().isEmpty }) {
            return Advice(text: L10n.t("coach.mateThreat"), highlight: [mate.from, mate.to], suggested: mate)
        }

        if let quality = lastMoveQuality, let lastMove, lastMove.color == mover.opposite {
            _ = quality // opponent's move quality isn't surfaced to the mover.
        }

        // Hanging pieces of ours.
        let hanging = position.hangingPieces(of: mover)
        if let worst = hanging.max(by: { (position[$0]?.kind.value ?? 0) < (position[$1]?.kind.value ?? 0) }), let piece = position[worst] {
            return Advice(text: L10n.t("coach.hanging", L10n.pieceName(piece.kind).lowercased(), worst.name.uppercased()), highlight: [worst])
        }

        // Free captures for us.
        let captures = legal.filter { position.isCapture($0) }
        let freeCapture = captures.filter { move in
            guard let victim = position.capturedPiece(by: move) else { return false }
            let after = position.making(move)
            let defended = after.isAttacked(move.to, by: mover.opposite)
            let attacker = position[move.from]?.kind.value ?? 0
            return !defended || victim.kind.value > attacker
        }.max { (position.capturedPiece(by: $0)?.kind.value ?? 0) < (position.capturedPiece(by: $1)?.kind.value ?? 0) }
        if let freeCapture, let victim = position.capturedPiece(by: freeCapture) {
            return Advice(text: L10n.t("coach.canCapture", L10n.pieceName(victim.kind).lowercased(), freeCapture.to.name.uppercased()), highlight: [freeCapture.from, freeCapture.to], suggested: freeCapture)
        }

        // Opponent threatens one of our pieces (attacked more than defended is complex; use attacked & higher value than cheapest attacker).
        if let lastMove, lastMove.color == mover.opposite {
            let threatened = position.threatenedPieces(of: mover).filter { sq in
                guard let p = position[sq], p.kind.value >= 300 else { return false }
                let defended = position.isAttacked(sq, by: mover)
                return !defended || cheapestAttacker(position, of: sq, by: mover.opposite) < p.kind.value
            }
            if let target = threatened.max(by: { (position[$0]?.kind.value ?? 0) < (position[$1]?.kind.value ?? 0) }), let piece = position[target] {
                return Advice(text: L10n.t("coach.opponentThreat", L10n.pieceName(lastMove.piece.kind).lowercased(), L10n.pieceName(piece.kind).lowercased()), highlight: [target, lastMove.move.to])
            }
        }

        // Promotion available.
        if let promo = legal.first(where: { $0.promotion == .queen }) {
            return Advice(text: L10n.t("coach.promote"), highlight: [promo.from, promo.to], suggested: promo)
        }

        // Castling available (and king still central).
        if let castle = legal.first(where: { $0.isCastle }) {
            return Advice(text: L10n.t("coach.castle"), highlight: [castle.from, castle.to], suggested: castle)
        }

        // Development in the opening.
        if position.fullmoveNumber <= 10 {
            let backRank = mover.backRank
            let undeveloped = [1, 2, 5, 6].map { Square(file: $0, rank: backRank) }.filter { sq in
                guard let p = position[sq] else { return false }
                return p.color == mover && (p.kind == .knight || p.kind == .bishop)
            }
            if !undeveloped.isEmpty {
                return Advice(text: L10n.t("coach.develop"), highlight: undeveloped)
            }
        }

        let eval = Evaluation.evaluate(position) * (mover == .white ? 1 : -1)
        if Evaluation.isEndgame(position) {
            return Advice(text: L10n.t("coach.endgame"))
        }
        if eval > 250 { return Advice(text: L10n.t("coach.material.up")) }
        if eval < -250 { return Advice(text: L10n.t("coach.material.down")) }
        if position.fullmoveNumber <= 1 { return Advice(text: L10n.t("coach.start")) }
        return Advice(text: L10n.t("coach.quiet"))
    }

    private static func cheapestAttacker(_ p: Position, of square: Square, by color: PieceColor) -> Int {
        var cheapest = Int.max
        var probe = p
        probe.sideToMove = color
        for move in probe.pseudoLegalMoves(capturesOnly: true) where move.to == square {
            cheapest = min(cheapest, probe[move.from]?.kind.value ?? Int.max)
        }
        return cheapest
    }
}
