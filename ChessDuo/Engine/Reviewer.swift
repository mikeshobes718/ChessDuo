import Foundation

/// Post-game analysis: evaluates each position and classifies moves.
enum Reviewer {
    static func classify(loss: Int, isBest: Bool, inBook: Bool) -> MoveQuality {
        if inBook { return .book }
        if isBest || loss <= 10 { return .best }
        if loss <= 50 { return .good }
        if loss <= 110 { return .inaccuracy }
        if loss <= 250 { return .mistake }
        return .blunder
    }

    /// Runs on a background actor; `progress` reports 0...1.
    static func review(record: GameRecord, engine: ChessEngine, depth: Int = 4, timePerMove: TimeInterval = 0.35, progress: (@Sendable (Double) -> Void)? = nil) async -> ReviewSummary {
        var game = ChessGame(fen: record.startFEN)
        var evals: [Int] = []
        var reviews: [MoveReview] = []
        let total = max(1, record.moves.count)

        // Eval of the starting position.
        var current = await engine.analyze(game.position, depth: depth, time: timePerMove)
        var currentWhite = whitePerspective(current.score, sideToMove: game.position.sideToMove)
        evals.append(currentWhite)

        for (index, record) in record.moves.enumerated() {
            let before = game.position
            let bestMove = current.bestMove
            let bestSan = bestMove.map { before.san(for: $0) }
            let inBook = OpeningBook.candidates(for: before).contains(record.san)
            let evalBefore = currentWhite

            guard game.play(record.move, assisted: record.assisted) != nil else { break }
            if game.isFinished, let result = game.result {
                // Terminal: mate is decisive; draws are 0.
                if result.termination == .checkmate {
                    currentWhite = result.winner == .white ? Search.mateScore : -Search.mateScore
                } else {
                    currentWhite = 0
                }
                current = SearchResult(bestMove: nil, score: 0, depth: 0, nodes: 0, principalVariation: [])
            } else {
                current = await engine.analyze(game.position, depth: depth, time: timePerMove)
                currentWhite = whitePerspective(current.score, sideToMove: game.position.sideToMove)
            }
            evals.append(currentWhite)

            // Loss from the mover's perspective, clamped to keep mates sane.
            let sign = record.color == .white ? 1 : -1
            let clampedBefore = max(-1500, min(1500, evalBefore * sign))
            let clampedAfter = max(-1500, min(1500, currentWhite * sign))
            let loss = max(0, clampedBefore - clampedAfter)
            let isBest = bestMove.map { $0 == record.move } ?? false
            let quality = classify(loss: loss, isBest: isBest, inBook: inBook)
            reviews.append(MoveReview(ply: record.ply, san: record.san, color: record.color, quality: quality, evalBefore: evalBefore, evalAfter: currentWhite, bestSan: bestSan, assisted: record.assisted, centipawnLoss: loss))
            progress?(Double(index + 1) / Double(total))
        }

        func summarize(_ color: PieceColor) -> PlayerReviewSummary {
            let mine = reviews.filter { $0.color == color }
            let unaided = mine.filter { !$0.assisted }
            return PlayerReviewSummary(
                accuracy: accuracy(mine),
                unaidedAccuracy: accuracy(unaided),
                best: mine.filter { $0.quality == .best || $0.quality == .book }.count,
                good: mine.filter { $0.quality == .good }.count,
                inaccuracies: mine.filter { $0.quality == .inaccuracy }.count,
                mistakes: mine.filter { $0.quality == .mistake }.count,
                blunders: mine.filter { $0.quality == .blunder }.count,
                assisted: mine.filter { $0.assisted }.count
            )
        }
        return ReviewSummary(white: summarize(.white), black: summarize(.black), moves: reviews, evals: evals)
    }

    private static func whitePerspective(_ score: Int, sideToMove: PieceColor) -> Int {
        sideToMove == .white ? score : -score
    }

    /// Accuracy in 0...100 from average centipawn loss (chess.com-like curve).
    static func accuracy(_ moves: [MoveReview]) -> Int {
        guard !moves.isEmpty else { return 100 }
        let acpl = Double(moves.reduce(0) { $0 + $1.centipawnLoss }) / Double(moves.count)
        let value = 103.17 * exp(-0.0106 * acpl) - 3.17
        return Int(max(0, min(100, value)).rounded())
    }
}

extension OpeningBook {
    static func candidates(for position: Position) -> [String] {
        table[position.repetitionKey] ?? []
    }
}
