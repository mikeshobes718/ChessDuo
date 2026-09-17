import Foundation
import SwiftUI
import Combine

/// Shared board interaction state used by every board (2D and 3D) and every mode.
struct BoardInteraction: Equatable {
    var selected: Square?
    var legalTargets: Set<Square> = []
    var captureTargets: Set<Square> = []
    var lastMove: (Square, Square)?
    var checkSquare: Square?
    var hintMove: Move?
    var threatSquares: Set<Square> = []
    var coachSquares: Set<Square> = []
    var pendingConfirm: Move?
    var orientation: PieceColor = .white
    var interactive = true

    static func == (lhs: BoardInteraction, rhs: BoardInteraction) -> Bool {
        lhs.selected == rhs.selected && lhs.legalTargets == rhs.legalTargets && lhs.captureTargets == rhs.captureTargets
        && lhs.lastMove?.0 == rhs.lastMove?.0 && lhs.lastMove?.1 == rhs.lastMove?.1 && lhs.checkSquare == rhs.checkSquare
        && lhs.hintMove == rhs.hintMove && lhs.threatSquares == rhs.threatSquares && lhs.coachSquares == rhs.coachSquares
        && lhs.pendingConfirm == rhs.pendingConfirm && lhs.orientation == rhs.orientation && lhs.interactive == rhs.interactive
    }
}

struct PendingPromotion: Identifiable, Equatable {
    let id = UUID()
    let from: Square
    let to: Square
    let color: PieceColor
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var style: Style = .info
    enum Style { case info, success, warning, error }
}

/// Local game session: pass & play or vs computer. Owns the ChessGame, clock, engine and persistence.
@MainActor
final class GameSession: ObservableObject {
    enum Kind: Equatable { case local, computer(EngineLevel, human: PieceColor) }

    @Published private(set) var game: ChessGame
    @Published var interaction = BoardInteraction()
    @Published var pendingPromotion: PendingPromotion?
    @Published var toast: Toast?
    @Published private(set) var isEngineThinking = false
    @Published private(set) var coachText: String = L10n.t("coach.start")
    @Published private(set) var hintText: String?
    @Published private(set) var evalCentipawns: Int? = nil
    @Published var showGameOver = false
    @Published private(set) var review: ReviewSummary?
    @Published private(set) var reviewProgress: Double = 0
    @Published private(set) var isReviewing = false
    @Published var viewingPly: Int? = nil       // nil = live position
    @Published var boardFlipped = false
    @Published var use3D: Bool
    @Published var drawOfferPending = false

    let kind: Kind
    let clock: ChessClock
    let whiteName: String
    let blackName: String
    private(set) var recordID: UUID
    private let startedAt: Date
    private let engine = ChessEngine()
    private let settings = AppSettings.shared
    private let store = HistoryStore.shared
    private var toastTask: Task<Void, Never>?
    private var engineTask: Task<Void, Never>?
    private var evalTask: Task<Void, Never>?
    private var hintsUsedToday = 0
    private var outcomeRecorded = false

    var humanColor: PieceColor? {
        if case .computer(_, let human) = kind { return human }
        return nil
    }

    var engineLevel: EngineLevel? {
        if case .computer(let level, _) = kind { return level }
        return nil
    }

    var isComputerGame: Bool { engineLevel != nil }

    init(kind: Kind, whiteName: String, blackName: String, timeControl: TimeControl, fen: String = Position.startFEN) {
        self.kind = kind
        self.whiteName = whiteName
        self.blackName = blackName
        self.clock = ChessClock(control: timeControl)
        self.game = ChessGame(fen: fen)
        self.recordID = UUID()
        self.startedAt = Date()
        self.use3D = AppSettings.shared.prefers3D
        configure()
    }

    /// Resume from a saved record.
    init(record: GameRecord) {
        if record.mode == .computer, let level = record.computerLevel {
            kind = .computer(level, human: record.humanColor ?? .white)
        } else {
            kind = .local
        }
        whiteName = record.whiteName
        blackName = record.blackName
        clock = ChessClock(control: record.timeControl, white: record.whiteClock, black: record.blackClock)
        game = record.game
        recordID = record.id
        startedAt = record.startedAt
        use3D = AppSettings.shared.prefers3D
        review = record.review
        configure()
    }

    private func configure() {
        clock.onFlag = { [weak self] color in
            guard let self else { return }
            var g = self.game
            g.timeout(color)
            self.game = g
            self.finishIfNeeded()
        }
        clock.onLowTime = { [weak self] _ in
            guard let self, self.settings.clockWarning else { return }
            Feedback.shared.play(.lowTime)
            self.presentToast(L10n.t("time.lowTime"), style: .warning)
        }
        if let human = humanColor {
            interaction.orientation = human
        }
        refreshInteraction()
        refreshCoach()
        if !game.isFinished {
            // The clock starts with the first move; a resumed game keeps ticking from where it was.
            if !game.history.isEmpty { clock.start(game.sideToMove) }
            if game.history.isEmpty { Feedback.shared.play(.gameStart) }
            maybeTriggerEngine()
        } else {
            showGameOver = true
        }
        persist()
    }

    // MARK: - Derived

    var displayedPosition: Position {
        if let viewingPly { return game.position(atPly: viewingPly) }
        return game.position
    }

    var isViewingHistory: Bool { viewingPly != nil && viewingPly! < game.history.count }

    var sideToMove: PieceColor { game.sideToMove }

    func name(for color: PieceColor) -> String { color == .white ? whiteName : blackName }

    var turnText: String {
        if game.isFinished { return L10n.t("game.gameOver") }
        if isEngineThinking { return L10n.t("game.thinking") }
        if game.isCheck {
            if let human = humanColor { return game.sideToMove == human ? L10n.t("game.checkYou") : L10n.t("game.checkThem", name(for: game.sideToMove)) }
            return L10n.t("game.check")
        }
        if let human = humanColor { return game.sideToMove == human ? L10n.t("game.yourTurn") : L10n.t("game.theirTurn", name(for: game.sideToMove)) }
        return game.sideToMove == .white ? L10n.t("game.whiteTurn") : L10n.t("game.blackTurn")
    }

    var canHumanMove: Bool {
        guard !game.isFinished, !isEngineThinking, !isViewingHistory else { return false }
        if let human = humanColor { return game.sideToMove == human }
        return true
    }

    var canUndo: Bool {
        guard !game.history.isEmpty, !isEngineThinking else { return false }
        // Taking back a move is fine after checkmate/stalemate, but not after a resignation, agreed draw or flag fall.
        if let result = game.result, [.resignation, .drawAgreed, .timeout, .abandoned].contains(result.termination) { return false }
        return true
    }

    var effectiveOrientation: PieceColor {
        var base: PieceColor = humanColor ?? .white
        if kind == .local && settings.localAutoFlip { base = game.sideToMove }
        return boardFlipped ? base.opposite : base
    }

    // MARK: - Interaction

    func tap(_ square: Square) {
        guard canHumanMove else {
            if isViewingHistory { viewingPly = nil; refreshInteraction(); return }
            if !game.isFinished && isEngineThinking { presentToast(L10n.t("game.thinking")) }
            else if !game.isFinished { presentToast(L10n.t("game.notYourTurn")) }
            return
        }
        let position = game.position
        if let pending = interaction.pendingConfirm {
            if pending.to == square {
                interaction.pendingConfirm = nil
                commit(from: pending.from, to: pending.to, promotion: pending.promotion)
                return
            }
            interaction.pendingConfirm = nil
        }
        if let selected = interaction.selected {
            if selected == square {
                interaction.selected = nil
                refreshInteraction()
                return
            }
            if interaction.legalTargets.contains(square) {
                let moves = game.legalMoves(from: selected).filter { $0.to == square }
                if moves.contains(where: { $0.promotion != nil }) {
                    if settings.autoQueen {
                        attemptMove(from: selected, to: square, promotion: .queen)
                    } else {
                        pendingPromotion = PendingPromotion(from: selected, to: square, color: game.sideToMove)
                    }
                } else {
                    attemptMove(from: selected, to: square, promotion: nil)
                }
                return
            }
        }
        if let piece = position[square], piece.color == game.sideToMove {
            interaction.selected = square
            Feedback.shared.play(.select)
            refreshInteraction()
        } else if interaction.selected == nil {
            presentToast(L10n.t("game.pickPiece"))
        } else {
            interaction.selected = nil
            refreshInteraction()
        }
    }

    /// Drag-and-drop support from the board.
    func drop(from: Square, to: Square) {
        guard canHumanMove else { return }
        let moves = game.legalMoves(from: from).filter { $0.to == to }
        guard !moves.isEmpty else { refreshInteraction(); return }
        if moves.contains(where: { $0.promotion != nil }) {
            if settings.autoQueen { attemptMove(from: from, to: to, promotion: .queen) }
            else { pendingPromotion = PendingPromotion(from: from, to: to, color: game.sideToMove) }
        } else {
            attemptMove(from: from, to: to, promotion: nil)
        }
    }

    func completePromotion(_ kind: PieceKind) {
        guard let p = pendingPromotion else { return }
        pendingPromotion = nil
        commit(from: p.from, to: p.to, promotion: kind)
    }

    private func attemptMove(from: Square, to: Square, promotion: PieceKind?) {
        if settings.confirmMoves {
            interaction.pendingConfirm = Move(from: from, to: to, promotion: promotion)
            presentToast(L10n.t("game.tapToConfirm"))
            return
        }
        commit(from: from, to: to, promotion: promotion)
    }

    private func commit(from: Square, to: Square, promotion: PieceKind?, assisted: Bool = false) {
        var g = game
        guard let record = g.play(from: from, to: to, promotion: promotion, assisted: assisted) else {
            presentToast(L10n.t("game.illegal"), style: .error)
            return
        }
        let mover = record.color
        game = g
        interaction.selected = nil
        interaction.pendingConfirm = nil
        hintText = nil
        viewingPly = nil
        playSound(for: record)
        if clock.running == nil && !clock.isPaused && game.history.count == 1 {
            clock.start(game.sideToMove)
        } else {
            clock.switchTurn(from: mover)
        }
        refreshInteraction()
        refreshCoach()
        persist()
        if game.isFinished {
            finishIfNeeded()
        } else {
            maybeTriggerEngine()
        }
    }

    private func playSound(for record: MoveRecord) {
        if record.isMate { Feedback.shared.play(.win); return }
        if record.isCheck { Feedback.shared.play(.check) }
        else if record.move.promotion != nil { Feedback.shared.play(.promote) }
        else if record.move.isCastle { Feedback.shared.play(.castle) }
        else if record.captured != nil { Feedback.shared.play(.capture) }
        else { Feedback.shared.play(.move) }
    }

    func refreshInteraction() {
        let position = game.position
        var next = interaction
        next.orientation = effectiveOrientation
        next.interactive = canHumanMove
        if let selected = interaction.selected, canHumanMove, position[selected]?.color == game.sideToMove {
            let moves = game.legalMoves(from: selected)
            next.legalTargets = settings.showLegalMoves ? Set(moves.map(\.to)) : []
            next.captureTargets = settings.showLegalMoves ? Set(moves.filter { position.isCapture($0) }.map(\.to)) : []
            // Keep the targets even if legal-move dots are hidden so taps still work.
            if !settings.showLegalMoves { next.legalTargets = Set(moves.map(\.to)) }
        } else {
            next.selected = nil
            next.legalTargets = []
            next.captureTargets = []
        }
        if let last = game.lastMove, settings.highlightLastMove, !isViewingHistory {
            next.lastMove = (last.move.from, last.move.to)
        } else if let viewingPly, viewingPly > 0, settings.highlightLastMove {
            let m = game.history[viewingPly - 1].move
            next.lastMove = (m.from, m.to)
        } else {
            next.lastMove = nil
        }
        next.checkSquare = displayedPosition.isInCheck ? displayedPosition.king(of: displayedPosition.sideToMove) : nil
        if settings.highlightThreats || settings.moveGuide, canHumanMove {
            next.threatSquares = Set(position.hangingPieces(of: game.sideToMove))
        } else {
            next.threatSquares = []
        }
        interaction = next
    }

    // MARK: - Engine

    private func maybeTriggerEngine() {
        guard case .computer(let level, let human) = kind, !game.isFinished, game.sideToMove != human else { return }
        engineTask?.cancel()
        isEngineThinking = true
        interaction.interactive = false
        let position = game.position
        let previous = game.history.compactMap { Position(fen: $0.fenAfter).map(Zobrist.hash) }
        let minimumDelay: UInt64 = level == .beginner ? 350_000_000 : 550_000_000
        engineTask = Task { [weak self] in
            guard let self else { return }
            let started = Date()
            let move = await self.engine.chooseMove(for: position, level: level, previousPositions: previous)
            let elapsed = Date().timeIntervalSince(started)
            if elapsed < Double(minimumDelay) / 1e9 {
                try? await Task.sleep(nanoseconds: minimumDelay - UInt64(elapsed * 1e9))
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.isEngineThinking = false
                guard let move, self.game.position == position else { self.refreshInteraction(); return }
                self.commit(from: move.from, to: move.to, promotion: move.promotion)
            }
        }
    }

    func requestHint() {
        guard canHumanMove else { return }
        guard hintsUsedToday < 30 else { presentToast(L10n.t("game.hint.none")); return }
        hintsUsedToday += 1
        let position = game.position
        Task { [weak self] in
            guard let self else { return }
            let result = await self.engine.analyze(position, depth: 5, time: 1.0)
            await MainActor.run {
                guard let best = result.bestMove, self.game.position == position else { self.presentToast(L10n.t("game.hint.none")); return }
                self.interaction.hintMove = best
                self.hintText = L10n.t("game.hint.try", position.san(for: best))
                Feedback.shared.play(.notify)
            }
        }
    }

    func playForMe() {
        guard canHumanMove else { return }
        let position = game.position
        isEngineThinking = true
        Task { [weak self] in
            guard let self else { return }
            let move = await self.engine.chooseMove(for: position, level: self.settings.assistLevel, allowBook: true)
            await MainActor.run {
                self.isEngineThinking = false
                guard let move, self.game.position == position else { return }
                self.commit(from: move.from, to: move.to, promotion: move.promotion, assisted: true)
            }
        }
    }

    func refreshEval() {
        evalTask?.cancel()
        let position = displayedPosition
        evalTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.engine.analyze(position, depth: 4, time: 0.5)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                let white = position.sideToMove == .white ? result.score : -result.score
                self.evalCentipawns = white
            }
        }
    }

    // MARK: - Game controls

    func undo() {
        guard canUndo else { return }
        engineTask?.cancel()
        isEngineThinking = false
        var g = game
        _ = g.undo()
        // Against the computer, take back the engine's reply too so it's the human's turn again.
        if let human = humanColor, g.sideToMove != human, !g.history.isEmpty { _ = g.undo() }
        game = g
        showGameOver = false
        outcomeRecorded = false
        interaction.selected = nil
        hintText = nil
        viewingPly = nil
        Feedback.shared.impact(.rigid)
        refreshInteraction()
        refreshCoach()
        if !game.isFinished { clock.start(game.sideToMove) }
        persist()
        // If it's now the computer's turn (e.g. we undid the only human move in a game where computer is white), let it play.
        maybeTriggerEngine()
    }

    func resign(_ color: PieceColor? = nil) {
        let resigning = color ?? humanColor ?? game.sideToMove
        var g = game
        g.resign(resigning)
        game = g
        finishIfNeeded()
    }

    func offerDraw() {
        if isComputerGame {
            // The computer accepts when it's not clearly ahead.
            let evalForComputer = Evaluation.evaluate(game.position) * (humanColor == .white ? -1 : 1)
            if evalForComputer < 150 || game.canClaimDraw {
                var g = game; g.agreeDraw(); game = g; finishIfNeeded()
            } else {
                presentToast(L10n.t("game.draw.declined"), style: .warning)
            }
        } else {
            drawOfferPending = true
        }
    }

    func respondDraw(accept: Bool) {
        drawOfferPending = false
        if accept { var g = game; g.agreeDraw(); game = g; finishIfNeeded() }
        else { presentToast(L10n.t("game.draw.declined")) }
    }

    func claimDraw() {
        var g = game
        g.claimDraw()
        game = g
        finishIfNeeded()
    }

    func togglePause() {
        if clock.isPaused { clock.resume() } else { clock.pause() }
    }

    func flip() {
        boardFlipped.toggle()
        refreshInteraction()
    }

    func step(_ delta: Int) {
        let current = viewingPly ?? game.history.count
        let next = max(0, min(game.history.count, current + delta))
        viewingPly = next == game.history.count ? nil : next
        interaction.selected = nil
        Feedback.shared.selectionChanged()
        refreshInteraction()
    }

    func jump(toPly ply: Int) {
        viewingPly = ply >= game.history.count ? nil : max(0, ply)
        interaction.selected = nil
        refreshInteraction()
    }

    func newGame(sameSettings: Bool = true) -> GameSession {
        var newKind = kind
        if case .computer(let level, let human) = kind {
            // Swap colours on rematch, like a real rematch.
            newKind = .computer(level, human: human.opposite)
        }
        let swap = isComputerGame
        return GameSession(kind: newKind, whiteName: swap ? blackName : whiteName, blackName: swap ? whiteName : blackName, timeControl: clock.control)
    }

    private func finishIfNeeded() {
        guard game.isFinished, let result = game.result else { return }
        engineTask?.cancel()
        isEngineThinking = false
        clock.stop()
        interaction.selected = nil
        refreshInteraction()
        if !outcomeRecorded {
            outcomeRecorded = true
            store.recordOutcome(result, me: humanColor, mode: isComputerGame ? .computer : .local, level: engineLevel)
            if let human = humanColor {
                Feedback.shared.play(result.winner == human ? .win : (result.winner == nil ? .draw : .lose))
            } else {
                Feedback.shared.play(result.winner == nil ? .draw : .win)
            }
        }
        persist()
        showGameOver = true
        runReview()
    }

    func runReview() {
        guard review == nil, !isReviewing, !game.history.isEmpty else { return }
        isReviewing = true
        reviewProgress = 0
        let record = makeRecord()
        Task { [weak self] in
            guard let self else { return }
            let summary = await Reviewer.review(record: record, engine: self.engine, progress: { p in
                Task { @MainActor [weak self] in self?.reviewProgress = p }
            })
            await MainActor.run {
                self.review = summary
                self.isReviewing = false
                self.persist()
            }
        }
    }

    // MARK: - Coach & toasts

    private func refreshCoach() {
        guard settings.coachCard else { return }
        if game.isFinished, let result = game.result {
            coachText = GameRecord.describe(result: result, white: whiteName, black: blackName)
            return
        }
        let advice = Coach.advise(position: game.position, lastMove: game.lastMove, mover: game.sideToMove)
        coachText = advice.text.isEmpty ? L10n.t("coach.start") : advice.text
        interaction.coachSquares = settings.moveGuide ? Set(advice.highlight) : []
    }

    func presentToast(_ text: String, style: Toast.Style = .info) {
        toastTask?.cancel()
        toast = Toast(text: text, style: style)
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.toast = nil }
        }
    }

    // MARK: - Persistence

    func makeRecord() -> GameRecord {
        GameRecord(
            id: recordID,
            mode: isComputerGame ? .computer : .local,
            whiteName: whiteName,
            blackName: blackName,
            startFEN: game.startFEN,
            moves: game.history,
            result: game.result,
            startedAt: startedAt,
            endedAt: game.isFinished ? Date() : nil,
            timeControl: clock.control,
            computerLevel: engineLevel,
            humanColor: humanColor,
            roomCode: nil,
            whiteClock: clock.isActive ? clock.whiteRemaining : nil,
            blackClock: clock.isActive ? clock.blackRemaining : nil,
            review: review
        )
    }

    func persist() {
        // Don't clutter history with untouched games.
        guard !game.history.isEmpty || game.isFinished else { return }
        store.upsert(makeRecord())
    }

    #if DEBUG
    func debugPlay(san: String) {
        guard let move = game.position.move(fromSAN: san) else { return }
        var g = game
        g.play(move)
        game = g
        refreshInteraction()
        refreshCoach()
    }
    #endif

    func pgn() -> String { game.pgn(white: whiteName, black: blackName, event: isComputerGame ? L10n.t("home.computer") : L10n.t("home.passPlay"), date: startedAt) }

    func leave() {
        engineTask?.cancel()
        engine.cancel()
        clock.pause()
        persist()
    }

    deinit {
        engineTask?.cancel()
    }
}
