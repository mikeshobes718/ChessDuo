import Foundation
import SwiftUI
import Combine

@MainActor
final class PuzzleSession: ObservableObject {
    @Published private(set) var puzzle: Puzzle
    @Published private(set) var position: Position
    @Published var interaction = BoardInteraction()
    @Published private(set) var stepIndex = 0
    @Published private(set) var solved = false
    @Published private(set) var failedOnce = false
    @Published private(set) var message: String
    @Published private(set) var messageStyle: Toast.Style = .info
    @Published private(set) var showingSolution = false
    @Published var pendingPromotion: PendingPromotion?
    @Published var use3D: Bool = false
    @Published var themeFilter: Puzzle.Theme? = nil

    private let store = HistoryStore.shared
    private var recorded = false

    var solverColor: PieceColor { puzzle.sideToMove }
    var isDaily: Bool { puzzle.id == PuzzleLibrary.daily().id }

    init(puzzle: Puzzle) {
        self.puzzle = puzzle
        self.position = Position(fen: puzzle.fen) ?? Position()
        self.message = L10n.t("puzzle.find")
        interaction.orientation = puzzle.sideToMove
        refreshInteraction()
    }

    func load(_ puzzle: Puzzle) {
        self.puzzle = puzzle
        position = Position(fen: puzzle.fen) ?? Position()
        stepIndex = 0
        solved = false
        failedOnce = false
        showingSolution = false
        recorded = false
        message = L10n.t("puzzle.find")
        messageStyle = .info
        interaction = BoardInteraction()
        interaction.orientation = puzzle.sideToMove
        refreshInteraction()
    }

    func next() {
        let pool = (themeFilter.map { t in PuzzleLibrary.valid.filter { $0.theme == t } } ?? PuzzleLibrary.valid)
        let unsolved = pool.filter { !store.stats.solvedPuzzleIDs.contains($0.id) && $0.id != puzzle.id }
        let candidates = unsolved.isEmpty ? pool.filter { $0.id != puzzle.id } : unsolved
        if let p = candidates.randomElement() { load(p) }
    }

    func retry() { load(puzzle) }

    var expectedMove: Move? {
        guard stepIndex < puzzle.solution.count else { return nil }
        let uci = puzzle.solution[stepIndex]
        guard let from = Square(name: String(uci.prefix(2))), let to = Square(name: String(uci.dropFirst(2).prefix(2))) else { return nil }
        let promo: PieceKind? = uci.count > 4 ? PieceKind(letter: uci.last!) : nil
        return position.legalMove(from: from, to: to, promotion: promo)
    }

    var themeTitle: String {
        switch puzzle.theme {
        case .mateInOne, .backRank: return L10n.t("puzzle.mateIn1")
        case .mateInTwo: return L10n.t("puzzle.mateIn2")
        default: return L10n.t("puzzle.winMaterial")
        }
    }

    func tap(_ square: Square) {
        guard !solved, !showingSolution else { return }
        if let selected = interaction.selected {
            if selected == square { interaction.selected = nil; refreshInteraction(); return }
            if interaction.legalTargets.contains(square) {
                let moves = position.legalMoves(from: selected).filter { $0.to == square }
                if moves.contains(where: { $0.promotion != nil }) {
                    pendingPromotion = PendingPromotion(from: selected, to: square, color: position.sideToMove)
                } else {
                    attempt(moves[0])
                }
                return
            }
        }
        if let piece = position[square], piece.color == position.sideToMove {
            interaction.selected = square
            Feedback.shared.play(.select)
        } else {
            interaction.selected = nil
        }
        refreshInteraction()
    }

    func drop(from: Square, to: Square) {
        guard !solved else { return }
        let moves = position.legalMoves(from: from).filter { $0.to == to }
        guard let first = moves.first else { refreshInteraction(); return }
        if moves.contains(where: { $0.promotion != nil }) {
            pendingPromotion = PendingPromotion(from: from, to: to, color: position.sideToMove)
        } else {
            attempt(first)
        }
    }

    func completePromotion(_ kind: PieceKind) {
        guard let p = pendingPromotion else { return }
        pendingPromotion = nil
        if let move = position.legalMove(from: p.from, to: p.to, promotion: kind) { attempt(move) }
    }

    private func attempt(_ move: Move) {
        interaction.selected = nil
        guard let expected = expectedMove else { return }
        let isMateAnyway: Bool = {
            let n = position.making(move)
            return n.isInCheck && n.legalMoves().isEmpty
        }()
        if move == expected || (isMateAnyway && stepIndex == puzzle.solution.count - 1) {
            apply(move)
            stepIndex += 1
            if stepIndex >= puzzle.solution.count {
                complete()
            } else {
                message = L10n.t("puzzle.keepGoing")
                messageStyle = .success
                Feedback.shared.play(.move)
                // Opponent reply.
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 450_000_000)
                    await MainActor.run { self?.playOpponentReply() }
                }
            }
        } else {
            failedOnce = true
            message = L10n.t("puzzle.wrong")
            messageStyle = .error
            Feedback.shared.play(.error)
            // Show the wrong move briefly then revert.
            let before = position
            apply(move)
            refreshInteraction()
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 600_000_000)
                await MainActor.run {
                    guard let self else { return }
                    self.position = before
                    self.interaction.lastMove = nil
                    self.refreshInteraction()
                }
            }
            return
        }
        refreshInteraction()
    }

    private func playOpponentReply() {
        guard stepIndex < puzzle.solution.count, let reply = expectedMove else { return }
        apply(reply)
        stepIndex += 1
        Feedback.shared.play(position.isInCheck ? .check : .move)
        refreshInteraction()
    }

    private func apply(_ move: Move) {
        position.apply(move)
        interaction.lastMove = (move.from, move.to)
    }

    private func complete() {
        solved = true
        message = L10n.t("puzzle.solved")
        messageStyle = .success
        Feedback.shared.play(.puzzleSolved)
        if !recorded {
            recorded = true
            store.recordPuzzle(puzzle, solved: true, firstTry: !failedOnce)
        }
    }

    func showSolution() {
        guard !solved else { return }
        showingSolution = true
        if !recorded { recorded = true; store.recordPuzzle(puzzle, solved: false, firstTry: false) }
        Task { [weak self] in
            guard let self else { return }
            while let move = await MainActor.run(body: { self.expectedMove }) {
                await MainActor.run {
                    self.apply(move)
                    self.stepIndex += 1
                    Feedback.shared.play(.move)
                    self.refreshInteraction()
                }
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
            await MainActor.run {
                self.message = L10n.t("puzzle.solved")
                self.messageStyle = .info
            }
        }
    }

    func hint() {
        guard let expected = expectedMove else { return }
        interaction.hintMove = Move(from: expected.from, to: expected.from)
        failedOnce = true
        refreshInteraction()
    }

    func refreshInteraction() {
        var next = interaction
        next.orientation = solverColor
        next.interactive = !solved && !showingSolution
        if let selected = interaction.selected, position[selected]?.color == position.sideToMove {
            let moves = position.legalMoves(from: selected)
            next.legalTargets = Set(moves.map(\.to))
            next.captureTargets = Set(moves.filter { position.isCapture($0) }.map(\.to))
        } else {
            next.selected = nil
            next.legalTargets = []
            next.captureTargets = []
        }
        next.checkSquare = position.isInCheck ? position.king(of: position.sideToMove) : nil
        interaction = next
    }
}
