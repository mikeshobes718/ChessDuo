import Foundation

enum EngineLevel: Int, Codable, CaseIterable, Identifiable {
    case beginner = 1, casual, club, strong, master
    var id: Int { rawValue }

    var depth: Int {
        switch self {
        case .beginner: return 1
        case .casual: return 2
        case .club: return 3
        case .strong: return 4
        case .master: return 6
        }
    }

    var timeBudget: TimeInterval {
        switch self {
        case .beginner: return 0.15
        case .casual: return 0.35
        case .club: return 0.8
        case .strong: return 1.6
        case .master: return 3.2
        }
    }

    /// Chance to deliberately pick a weaker move, to make lower levels beatable.
    var blunderChance: Double {
        switch self {
        case .beginner: return 0.45
        case .casual: return 0.22
        case .club: return 0.08
        case .strong: return 0.0
        case .master: return 0.0
        }
    }

    var approxElo: Int {
        switch self {
        case .beginner: return 500
        case .casual: return 900
        case .club: return 1300
        case .strong: return 1700
        case .master: return 2100
        }
    }
}

struct SearchResult {
    var bestMove: Move?
    var score: Int          // centipawns, side-to-move perspective
    var depth: Int
    var nodes: Int
    var principalVariation: [Move]
    var mateIn: Int? {
        let m = Search.mateScore
        if abs(score) > m - 1000 {
            let plies = m - abs(score)
            return (score > 0 ? 1 : -1) * ((plies + 1) / 2)
        }
        return nil
    }
}

/// Alpha-beta engine with iterative deepening, quiescence, MVV-LVA ordering, killers and a transposition table.
final class Search {
    static let mateScore = 100_000
    static let infinity = 1_000_000

    private struct TTEntry {
        enum Bound: UInt8 { case exact, lower, upper }
        var depth: Int
        var score: Int
        var bound: Bound
        var best: Move?
    }

    private var table: [UInt64: TTEntry] = [:]
    private var killers: [[Move?]] = Array(repeating: [nil, nil], count: 64)
    private var historyHeuristic: [Int] = Array(repeating: 0, count: 64 * 64)
    private var nodes = 0
    private var deadline: Date = .distantFuture
    private var aborted = false
    private var repetitionHashes: Set<UInt64> = []

    init() {
        table.reserveCapacity(200_000)
    }

    var isCancelled: (() -> Bool)?

    /// Runs an iterative deepening search up to `maxDepth` or until `time` elapses.
    func search(_ position: Position, maxDepth: Int, time: TimeInterval, previousPositions: [UInt64] = []) -> SearchResult {
        nodes = 0
        aborted = false
        deadline = Date().addingTimeInterval(time)
        repetitionHashes = Set(previousPositions)
        if table.count > 300_000 { table.removeAll(keepingCapacity: true) }
        for i in 0..<killers.count { killers[i] = [nil, nil] }
        for i in 0..<historyHeuristic.count { historyHeuristic[i] /= 2 }

        let root = position.legalMoves()
        guard !root.isEmpty else {
            let score = position.isInCheck ? -Search.mateScore : 0
            return SearchResult(bestMove: nil, score: score, depth: 0, nodes: 0, principalVariation: [])
        }
        if root.count == 1 {
            return SearchResult(bestMove: root[0], score: Evaluation.evaluateRelative(position), depth: 1, nodes: 1, principalVariation: root)
        }

        var best = SearchResult(bestMove: root[0], score: 0, depth: 0, nodes: 0, principalVariation: [])
        for depth in 1...max(1, maxDepth) {
            let score = alphaBeta(position, depth: depth, alpha: -Search.infinity, beta: Search.infinity, ply: 0)
            if aborted { break }
            let pv = extractPV(position, maxLength: depth)
            best = SearchResult(bestMove: pv.first ?? best.bestMove, score: score, depth: depth, nodes: nodes, principalVariation: pv)
            if abs(score) > Search.mateScore - 1000 { break }      // found a forced mate
            if Date() > deadline { break }
        }
        best.nodes = nodes
        return best
    }

    /// Scores every root move (used for review/coaching and for "top N" blunder selection).
    func scoreRootMoves(_ position: Position, depth: Int, time: TimeInterval) -> [(Move, Int)] {
        nodes = 0
        aborted = false
        deadline = Date().addingTimeInterval(time)
        var results: [(Move, Int)] = []
        for move in orderMoves(position, position.legalMoves(), ply: 0, ttMove: nil) {
            let next = position.making(move)
            let score = -alphaBeta(next, depth: depth - 1, alpha: -Search.infinity, beta: Search.infinity, ply: 1)
            results.append((move, score))
            if aborted { break }
        }
        return results.sorted { $0.1 > $1.1 }
    }

    private func extractPV(_ position: Position, maxLength: Int) -> [Move] {
        var pv: [Move] = []
        var pos = position
        var seen = Set<UInt64>()
        for _ in 0..<maxLength {
            let key = Zobrist.hash(pos)
            guard !seen.contains(key), let entry = table[key], let move = entry.best, pos.isLegal(move) else { break }
            seen.insert(key)
            pv.append(move)
            pos = pos.making(move)
        }
        return pv
    }

    private func checkTime() {
        if nodes & 2047 == 0 {
            if Date() > deadline || (isCancelled?() ?? false) { aborted = true }
        }
    }

    private func alphaBeta(_ position: Position, depth: Int, alpha alphaIn: Int, beta: Int, ply: Int) -> Int {
        nodes += 1
        checkTime()
        if aborted { return 0 }
        var alpha = alphaIn
        let key = Zobrist.hash(position)

        if ply > 0 {
            // Draw detection by repetition of a game position or fifty-move rule.
            if position.halfmoveClock >= 100 { return 0 }
            if position.halfmoveClock > 0, !repetitionHashes.isEmpty, repetitionHashes.contains(key) { return 0 }
            if position.hasInsufficientMaterial { return 0 }
            // Mate distance pruning.
            alpha = max(alpha, -Search.mateScore + ply)
            let betaCap = min(beta, Search.mateScore - ply)
            if alpha >= betaCap { return alpha }
        }

        if depth <= 0 {
            return quiescence(position, alpha: alpha, beta: beta, ply: ply)
        }

        var ttMove: Move?
        if let entry = table[key] {
            ttMove = entry.best
            if entry.depth >= depth && ply > 0 {
                switch entry.bound {
                case .exact: return entry.score
                case .lower: if entry.score >= beta { return entry.score }
                case .upper: if entry.score <= alpha { return entry.score }
                }
            }
        }

        let inCheck = position.isInCheck
        let moves = position.legalMoves()
        if moves.isEmpty {
            return inCheck ? -Search.mateScore + ply : 0
        }

        // Null-move pruning (not in check, not in an endgame with just pawns/kings).
        if depth >= 3 && !inCheck && ply > 0 && beta < Search.mateScore - 1000 && hasNonPawnMaterial(position) {
            var nullPos = position
            nullPos.sideToMove = position.sideToMove.opposite
            nullPos.enPassant = nil
            let r = depth > 6 ? 3 : 2
            let score = -alphaBeta(nullPos, depth: depth - 1 - r, alpha: -beta, beta: -beta + 1, ply: ply + 1)
            if aborted { return 0 }
            if score >= beta { return beta }
        }

        let ordered = orderMoves(position, moves, ply: ply, ttMove: ttMove)
        var bestScore = -Search.infinity
        var bestMove: Move?
        var bound = TTEntry.Bound.upper
        var searched = 0
        for move in ordered {
            let next = position.making(move)
            let isCapture = position.isCapture(move)
            let givesCheck = next.isInCheck
            var newDepth = depth - 1
            if givesCheck { newDepth += 1 }   // check extension
            var score: Int
            // Late move reductions for quiet moves.
            if searched >= 4 && depth >= 3 && !isCapture && !givesCheck && !inCheck && move.promotion == nil {
                score = -alphaBeta(next, depth: newDepth - 1, alpha: -alpha - 1, beta: -alpha, ply: ply + 1)
                if score > alpha && !aborted {
                    score = -alphaBeta(next, depth: newDepth, alpha: -beta, beta: -alpha, ply: ply + 1)
                }
            } else {
                score = -alphaBeta(next, depth: newDepth, alpha: -beta, beta: -alpha, ply: ply + 1)
            }
            searched += 1
            if aborted { return 0 }
            if score > bestScore {
                bestScore = score
                bestMove = move
            }
            if score > alpha {
                alpha = score
                bound = .exact
                if alpha >= beta {
                    bound = .lower
                    if !isCapture {
                        if killers[ply][0] != move {
                            killers[ply][1] = killers[ply][0]
                            killers[ply][0] = move
                        }
                        historyHeuristic[move.from.index * 64 + move.to.index] += depth * depth
                    }
                    break
                }
            }
        }
        table[key] = TTEntry(depth: depth, score: bestScore, bound: bound, best: bestMove)
        return bestScore
    }

    private func hasNonPawnMaterial(_ p: Position) -> Bool {
        for piece in p.board {
            if let piece, piece.color == p.sideToMove, piece.kind != .pawn, piece.kind != .king { return true }
        }
        return false
    }

    private func quiescence(_ position: Position, alpha alphaIn: Int, beta: Int, ply: Int) -> Int {
        nodes += 1
        checkTime()
        if aborted { return 0 }
        var alpha = alphaIn
        let stand = Evaluation.evaluateRelative(position)
        if stand >= beta { return beta }
        if stand > alpha { alpha = stand }
        if ply > 40 { return stand }
        let captures = position.legalCaptures()
        let ordered = captures.sorted { mvvLva(position, $0) > mvvLva(position, $1) }
        for move in ordered {
            // Delta pruning: skip captures that can't possibly raise alpha.
            if let victim = position.capturedPiece(by: move), stand + victim.kind.value + 200 < alpha, move.promotion == nil { continue }
            let next = position.making(move)
            let score = -quiescence(next, alpha: -beta, beta: -alpha, ply: ply + 1)
            if aborted { return 0 }
            if score >= beta { return beta }
            if score > alpha { alpha = score }
        }
        return alpha
    }

    @inline(__always)
    private func mvvLva(_ position: Position, _ move: Move) -> Int {
        let victim = position.capturedPiece(by: move)?.kind.value ?? 0
        let attacker = position[move.from]?.kind.value ?? 0
        let promo = move.promotion?.value ?? 0
        return victim * 10 - attacker / 10 + promo
    }

    private func orderMoves(_ position: Position, _ moves: [Move], ply: Int, ttMove: Move?) -> [Move] {
        let k0 = killers[min(ply, 63)][0], k1 = killers[min(ply, 63)][1]
        return moves.map { move -> (Move, Int) in
            var score = 0
            if let ttMove, ttMove == move { score = 1_000_000 }
            else if position.isCapture(move) { score = 100_000 + mvvLva(position, move) }
            else if move.promotion != nil { score = 90_000 }
            else if k0 == move { score = 80_000 }
            else if k1 == move { score = 70_000 }
            else { score = historyHeuristic[move.from.index * 64 + move.to.index] }
            return (move, score)
        }
        .sorted { $0.1 > $1.1 }
        .map { $0.0 }
    }
}

/// Thread-safe cancellation flag shared between the UI and a running search.
final class CancelToken: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false
    var isCancelled: Bool {
        get { lock.lock(); defer { lock.unlock() }; return flag }
        set { lock.lock(); flag = newValue; lock.unlock() }
    }
}

/// High-level engine facade with difficulty handling. Runs off the main thread.
actor ChessEngine {
    private let search = Search()
    private let token = CancelToken()

    init() {}

    nonisolated func cancel() { token.isCancelled = true }

    private func prepare() {
        token.isCancelled = false
        let token = self.token
        search.isCancelled = { token.isCancelled }
    }

    /// Picks a move for the given level. Includes deliberate imperfection for lower levels.
    func chooseMove(for position: Position, level: EngineLevel, previousPositions: [UInt64] = [], allowBook: Bool = true) -> Move? {
        prepare()
        if allowBook, level.rawValue >= 2, let book = OpeningBook.move(for: position) {
            return book
        }
        let legal = position.legalMoves()
        guard !legal.isEmpty else { return nil }

        if level.blunderChance > 0, Double.random(in: 0..<1) < level.blunderChance {
            // Score every root move shallowly and pick something plausible but not best.
            let scored = search.scoreRootMoves(position, depth: max(1, level.depth), time: level.timeBudget)
            guard scored.count > 1 else { return scored.first?.0 ?? legal.randomElement() }
            let bestScore = scored[0].1
            // Never walk into a forced mate deliberately; keep moves within a band below best.
            let band = level == .beginner ? 350 : 150
            let candidates = scored.dropFirst().filter { bestScore - $0.1 <= band && $0.1 > -Search.mateScore + 1000 }
            if let pick = candidates.randomElement() { return pick.0 }
            return scored[0].0
        }

        let result = search.search(position, maxDepth: level.depth, time: level.timeBudget, previousPositions: previousPositions)
        return result.bestMove ?? legal.randomElement()
    }

    /// Full-strength analysis for hints, eval bar and review.
    func analyze(_ position: Position, depth: Int = 5, time: TimeInterval = 1.2, previousPositions: [UInt64] = []) -> SearchResult {
        prepare()
        return search.search(position, maxDepth: depth, time: time, previousPositions: previousPositions)
    }

    func bestMoves(_ position: Position, depth: Int = 3, time: TimeInterval = 0.6) -> [(Move, Int)] {
        prepare()
        return search.scoreRootMoves(position, depth: depth, time: time)
    }
}
