import Foundation
import SwiftUI
import Combine

/// Online room session: talks to the game server, mirrors state into a local ChessGame for rendering,
/// and polls for updates. Legal moves come from the server when available, local engine otherwise.
@MainActor
final class OnlineSession: ObservableObject {
    @Published private(set) var info: OnlineSessionInfo
    @Published private(set) var fen: String = Position.startFEN
    @Published private(set) var position = Position()
    @Published private(set) var status: String = "waiting"
    @Published private(set) var whiteName = "White"
    @Published private(set) var blackName = "Black"
    @Published private(set) var turn: PieceColor = .white
    @Published private(set) var isCheck = false
    @Published private(set) var resultText: String?
    @Published private(set) var version = 0
    @Published private(set) var legalMoves: [Move] = []
    @Published private(set) var lastMove: OnlineLastMove?
    @Published private(set) var moveHistory: [OnlineMoveEntry] = []
    @Published private(set) var coachText: String = L10n.t("coach.start")
    @Published private(set) var coachHistory: [OnlineCoachItem] = []
    @Published private(set) var quiz: OnlineQuiz?
    @Published private(set) var hintsRemaining = 20
    @Published private(set) var drawOfferBy: PieceColor?
    @Published private(set) var undoOfferBy: PieceColor?
    @Published private(set) var isSubmitting = false
    @Published private(set) var isReconnecting = false
    @Published private(set) var nudgeCooldown = 0
    @Published private(set) var nudgeRemaining = 8
    @Published var interaction = BoardInteraction()
    @Published var pendingPromotion: PendingPromotion?
    @Published var toast: Toast?
    @Published var hintText: String?
    @Published var quizFeedback: String?
    @Published var showGameOver = false
    @Published var boardFlipped = false
    @Published var use3D: Bool
    @Published private(set) var localGame = ChessGame()
    @Published private(set) var review: ReviewSummary?
    @Published private(set) var isReviewing = false
    @Published var viewingPly: Int? = nil
    @Published private(set) var ended = false
    @Published private(set) var serverGameOver = false

    private let api = OnlineAPI()
    private let engine = ChessEngine()
    private let settings = AppSettings.shared
    private var pollTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var pollFailures = 0
    private var lastTurnSeen: PieceColor?
    private var lastNudgeAt: String?
    private var answeredQuizVersion: Int?
    private var recordedOutcome = false
    private var startedAt = Date()
    private var archivedRecordID = UUID()

    static let sessionKey = "online.session"

    var myColor: PieceColor? { info.role.pieceColor }
    var isSpectator: Bool { info.role == .spectator }
    var roomCode: String { info.roomCode }

    var isFinished: Bool {
        serverGameOver || resultText != nil || ["white_won", "black_won", "draw", "finished", "checkmate", "resigned", "timeout"].contains(status.lowercased())
    }

    var isWaiting: Bool { status.lowercased() == "waiting" }

    var canMove: Bool {
        guard let me = myColor, !isFinished, !isSubmitting, !isWaiting, viewingPly == nil else { return false }
        return turn == me
    }

    var opponentName: String {
        guard let me = myColor else { return "" }
        return me == .white ? blackName : whiteName
    }

    func name(for color: PieceColor) -> String { color == .white ? whiteName : blackName }

    var turnText: String {
        if isWaiting { return L10n.t("lobby.waiting") }
        if isFinished { return resultText ?? L10n.t("game.gameOver") }
        if isCheck {
            if turn == myColor { return L10n.t("game.checkYou") }
            return L10n.t("game.checkThem", name(for: turn))
        }
        if turn == myColor { return L10n.t("game.yourTurn") }
        return L10n.t("game.waiting", name(for: turn))
    }

    var effectiveOrientation: PieceColor {
        let base = myColor ?? .white
        return boardFlipped ? base.opposite : base
    }

    var inviteURL: URL { URL(string: "chessduo://room/\(info.roomCode)")! }

    var inviteText: String {
        "\(L10n.t("app.name")) · \(info.roomCode)\n\(inviteURL.absoluteString)"
    }

    init(info: OnlineSessionInfo, initial: OnlineResponse?) {
        self.info = info
        self.use3D = AppSettings.shared.prefers3D
        interaction.orientation = info.role.pieceColor ?? .white
        if let initial { merge(initial) }
        Self.save(info)
        startPolling()
        PushManager.shared.register(session: info)
    }

    static func save(_ info: OnlineSessionInfo?) {
        let before = UserDefaults.standard.data(forKey: sessionKey)
        store(info)
        if UserDefaults.standard.data(forKey: sessionKey) != before { CloudSync.shared.activeRoomChanged() }
    }

    /// Writes the saved room without marking it as a local change (used when restoring from the backup).
    static func store(_ info: OnlineSessionInfo?) {
        if let info, let data = try? JSONEncoder().encode(info) {
            UserDefaults.standard.set(data, forKey: sessionKey)
        } else {
            UserDefaults.standard.removeObject(forKey: sessionKey)
        }
    }

    static func loadSaved() -> OnlineSessionInfo? {
        guard let data = UserDefaults.standard.data(forKey: sessionKey) else { return nil }
        return try? JSONDecoder().decode(OnlineSessionInfo.self, from: data)
    }

    // MARK: - Merging server state

    func merge(_ r: OnlineResponse) {
        if let f = r.fen, let p = Position(fen: f) { fen = f; position = p }
        if let t = r.turn { turn = t == "black" ? .black : .white } else { turn = position.sideToMove }
        if let s = r.status { status = s }
        if let w = r.whiteName { whiteName = w }
        if let b = r.blackName { blackName = b }
        if let c = r.isCheck { isCheck = c } else { isCheck = position.isInCheck }
        if let res = r.result { resultText = res }
        if let over = r.gameOver { serverGameOver = over }
        if let v = r.version { version = v }
        if let lm = r.legalMoves {
            legalMoves = lm.compactMap { entry in
                guard let from = Square(name: entry.from), let to = Square(name: entry.to) else { return nil }
                let promo = entry.promotion.flatMap { $0.first }.flatMap { PieceKind(letter: $0) }
                return position.legalMove(from: from, to: to, promotion: promo) ?? Move(from: from, to: to, promotion: promo)
            }
        }
        if legalMoves.isEmpty, canMoveIgnoringLegal { legalMoves = position.legalMoves() }
        if let lm = r.lastMove { lastMove = lm }
        if let mh = r.moveHistory { moveHistory = mh; rebuildLocalGame() }
        if let ct = r.coachText, !ct.isEmpty { coachText = ct }
        if let ch = r.coachHistory { coachHistory = ch }
        quiz = r.quiz
        if let h = r.hintsRemaining { hintsRemaining = h }
        drawOfferBy = r.drawOfferBy.flatMap { PieceColor(rawValue: $0) }
        undoOfferBy = r.undoOfferBy.flatMap { PieceColor(rawValue: $0) }
        if let n = r.nudgeCooldownRemaining { nudgeCooldown = n }
        if let n = r.nudgeRemaining { nudgeRemaining = n }
        if let nudge = r.nudge, let at = nudge.at, at != lastNudgeAt, nudge.by != myColor?.rawValue {
            lastNudgeAt = at
            Feedback.shared.play(.notify)
            presentToast(nudge.message ?? L10n.t("game.nudge.received", opponentName), style: .warning)
        }
        if let hint = r.suggestedHint, let from = hint.from, let to = hint.to, let f = Square(name: from), let t = Square(name: to) {
            interaction.hintMove = Move(from: f, to: t)
            hintText = L10n.t("game.hint.try", hint.san ?? "\(from)\(to)")
        }
        // Turn change feedback.
        if let me = myColor, !isWaiting, !isFinished {
            if lastTurnSeen != nil, lastTurnSeen != turn, turn == me {
                Feedback.shared.play(isCheck ? .check : .notify)
            }
            lastTurnSeen = turn
        }
        if isFinished && !ended {
            ended = true
            showGameOver = true
            finalizeOutcome()
        }
        if !isFinished { ended = false }
        refreshInteraction()
    }

    private var canMoveIgnoringLegal: Bool {
        guard let me = myColor, !isFinished, !isWaiting else { return false }
        return turn == me
    }

    private func rebuildLocalGame() {
        var g = ChessGame()
        for entry in moveHistory {
            guard let san = entry.san else { break }
            guard let move = g.position.move(fromSAN: san) else { break }
            g.play(move, assisted: entry.assisted ?? false)
        }
        localGame = g
    }

    private func finalizeOutcome() {
        guard !recordedOutcome else { return }
        recordedOutcome = true
        let result: GameResult = {
            let s = status.lowercased()
            let text = (resultText ?? "").lowercased()
            let winner: PieceColor? = s == "white_won" || text.contains("white") && text.contains("win") ? .white
                : (s == "black_won" || text.contains("black") && text.contains("win") ? .black : nil)
            let termination: GameTermination = text.contains("resign") || s == "resigned" ? .resignation
                : (text.contains("mate") || s == "checkmate" ? .checkmate
                : (text.contains("stalemate") ? .stalemate : (winner == nil ? .drawAgreed : .checkmate)))
            if let auto = localGame.result { return auto }
            return GameResult(winner: winner, termination: termination)
        }()
        if !isSpectator {
            HistoryStore.shared.recordOutcome(result, me: myColor, mode: .online)
            if let me = myColor { Feedback.shared.play(result.winner == me ? .win : (result.winner == nil ? .draw : .lose)) }
        }
        var g = localGame
        if g.result == nil { g.setResult(result) }
        localGame = g
        let record = GameRecord(id: archivedRecordID, mode: .online, whiteName: whiteName, blackName: blackName, startFEN: Position.startFEN, moves: g.history, result: result, startedAt: startedAt, endedAt: Date(), timeControl: .none, computerLevel: nil, humanColor: myColor, roomCode: info.roomCode, whiteClock: nil, blackClock: nil, review: nil)
        if !g.history.isEmpty { HistoryStore.shared.upsert(record) }
        runReview()
    }

    func runReview() {
        guard review == nil, !isReviewing, !localGame.history.isEmpty else { return }
        isReviewing = true
        let record = GameRecord(id: archivedRecordID, mode: .online, whiteName: whiteName, blackName: blackName, startFEN: Position.startFEN, moves: localGame.history, result: localGame.result, startedAt: startedAt, endedAt: Date(), timeControl: .none, computerLevel: nil, humanColor: myColor, roomCode: info.roomCode, whiteClock: nil, blackClock: nil, review: nil)
        Task { [weak self] in
            guard let self else { return }
            let summary = await Reviewer.review(record: record, engine: self.engine)
            await MainActor.run {
                self.review = summary
                self.isReviewing = false
                var updated = record
                updated.review = summary
                if !updated.moves.isEmpty { HistoryStore.shared.upsert(updated) }
            }
        }
    }

    // MARK: - Polling

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.poll()
                let interval: UInt64 = await MainActor.run {
                    if self.isFinished { return 6_000_000_000 }
                    if self.isWaiting { return 2_500_000_000 }
                    return self.canMove ? 4_000_000_000 : 1_800_000_000
                }
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    func poll() async {
        do {
            let response = try await api.state(info, sinceVersion: version)
            pollFailures = 0
            if isReconnecting { isReconnecting = false; presentToast(L10n.t("game.reconnected"), style: .success) }
            if response.changed == false { return }
            merge(response)
        } catch {
            pollFailures += 1
            if pollFailures >= 3 { isReconnecting = true }
        }
    }

    func refreshNow() { Task { await poll() } }

    // MARK: - Interaction

    var displayedPosition: Position {
        if let viewingPly { return localGame.position(atPly: viewingPly) }
        return position
    }

    func tap(_ square: Square) {
        if viewingPly != nil { viewingPly = nil; refreshInteraction(); return }
        guard canMove else {
            if !isSpectator && !isFinished && !isWaiting { presentToast(turn == myColor ? L10n.t("game.pickPiece") : L10n.t("game.notYourTurn")) }
            return
        }
        if let pending = interaction.pendingConfirm {
            interaction.pendingConfirm = nil
            if pending.to == square { submit(pending); return }
        }
        if let selected = interaction.selected {
            if selected == square { interaction.selected = nil; refreshInteraction(); return }
            let candidates = legalMoves.filter { $0.from == selected && $0.to == square }
            if !candidates.isEmpty {
                if candidates.contains(where: { $0.promotion != nil }) {
                    if settings.autoQueen { attempt(Move(from: selected, to: square, promotion: .queen)) }
                    else { pendingPromotion = PendingPromotion(from: selected, to: square, color: turn) }
                } else {
                    attempt(candidates[0])
                }
                return
            }
        }
        if let piece = position[square], piece.color == myColor {
            interaction.selected = square
            Feedback.shared.play(.select)
        } else {
            interaction.selected = nil
        }
        refreshInteraction()
    }

    func drop(from: Square, to: Square) {
        guard canMove else { return }
        let candidates = legalMoves.filter { $0.from == from && $0.to == to }
        guard !candidates.isEmpty else { refreshInteraction(); return }
        if candidates.contains(where: { $0.promotion != nil }) {
            if settings.autoQueen { attempt(Move(from: from, to: to, promotion: .queen)) }
            else { pendingPromotion = PendingPromotion(from: from, to: to, color: turn) }
        } else {
            attempt(candidates[0])
        }
    }

    func completePromotion(_ kind: PieceKind) {
        guard let p = pendingPromotion else { return }
        pendingPromotion = nil
        submit(Move(from: p.from, to: p.to, promotion: kind))
    }

    private func attempt(_ move: Move) {
        if settings.confirmMoves {
            interaction.pendingConfirm = move
            presentToast(L10n.t("game.tapToConfirm"))
            return
        }
        submit(move)
    }

    private func submit(_ move: Move, assisted: Bool = false) {
        guard !isSubmitting else { return }
        isSubmitting = true
        interaction.selected = nil
        interaction.hintMove = nil
        hintText = nil
        // Optimistic local update for instant feedback.
        let before = position
        if let actual = before.legalMove(from: move.from, to: move.to, promotion: move.promotion) {
            let captured = before.isCapture(actual)
            position = before.making(actual)
            turn = position.sideToMove
            isCheck = position.isInCheck
            legalMoves = []
            if position.isInCheck { Feedback.shared.play(.check) }
            else if actual.promotion != nil { Feedback.shared.play(.promote) }
            else if actual.isCastle { Feedback.shared.play(.castle) }
            else if captured { Feedback.shared.play(.capture) }
            else { Feedback.shared.play(.move) }
            interaction.lastMove = (actual.from, actual.to)
        }
        refreshInteraction()
        Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await self.api.move(self.info, from: move.from.name, to: move.to.name, promotion: move.promotion?.letter.lowercased(), version: self.version, assisted: assisted, level: self.settings.assistLevel)
                await MainActor.run {
                    self.isSubmitting = false
                    self.merge(response)
                }
            } catch {
                await MainActor.run {
                    self.isSubmitting = false
                    self.position = before
                    self.turn = before.sideToMove
                    self.isCheck = before.isInCheck
                    self.legalMoves = before.legalMoves()
                    self.refreshInteraction()
                    self.presentToast(error.localizedDescription, style: .error)
                    Feedback.shared.play(.error)
                }
                await self.poll()
            }
        }
    }

    func refreshInteraction() {
        var next = interaction
        next.orientation = effectiveOrientation
        next.interactive = canMove
        if let selected = interaction.selected, canMove {
            let mine = legalMoves.filter { $0.from == selected }
            next.legalTargets = Set(mine.map(\.to))
            next.captureTargets = settings.showLegalMoves ? Set(mine.filter { position.isCapture($0) }.map(\.to)) : []
        } else {
            next.selected = nil
            next.legalTargets = []
            next.captureTargets = []
        }
        if let viewingPly, viewingPly > 0, viewingPly <= localGame.history.count {
            let m = localGame.history[viewingPly - 1].move
            next.lastMove = (m.from, m.to)
        } else if let lm = lastMove, let f = lm.from, let t = lm.to, let from = Square(name: f), let to = Square(name: t), settings.highlightLastMove {
            next.lastMove = (from, to)
        } else {
            next.lastMove = nil
        }
        let shown = displayedPosition
        next.checkSquare = shown.isInCheck ? shown.king(of: shown.sideToMove) : nil
        if (settings.highlightThreats || settings.moveGuide), canMove, let me = myColor {
            next.threatSquares = Set(position.hangingPieces(of: me))
        } else {
            next.threatSquares = []
        }
        if settings.moveGuide, canMove, let me = myColor {
            let advice = Coach.advise(position: position, lastMove: localGame.lastMove, mover: me)
            next.coachSquares = Set(advice.highlight)
        } else {
            next.coachSquares = []
        }
        interaction = next
    }

    // MARK: - Actions

    func requestHint() {
        guard canMove, settings.hintsEnabled else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await self.api.hint(self.info, version: self.version)
                await MainActor.run {
                    if let hint = response.hint, response.suggestedHint == nil { self.hintText = hint }
                    self.merge(response)
                    if let h = response.hintsRemaining { self.presentToast(L10n.t("game.hint.left", h)) }
                }
            } catch {
                // Fall back to the on-device engine.
                let position = await MainActor.run { self.position }
                let result = await self.engine.analyze(position, depth: 5, time: 1.0)
                await MainActor.run {
                    guard let best = result.bestMove, self.position == position else { return }
                    self.interaction.hintMove = best
                    self.hintText = L10n.t("game.hint.try", position.san(for: best))
                }
            }
        }
    }

    func playForMe() {
        guard canMove else { return }
        let position = self.position
        isSubmitting = true
        Task { [weak self] in
            guard let self else { return }
            let move = await self.engine.chooseMove(for: position, level: self.settings.assistLevel)
            await MainActor.run {
                self.isSubmitting = false
                guard let move, self.position == position else { return }
                self.submit(move, assisted: true)
            }
        }
    }

    func answerQuiz(_ option: OnlineQuizOption) {
        guard let quiz else { return }
        answeredQuizVersion = version
        if option.square.lowercased() == quiz.answerSquare?.lowercased() {
            quizFeedback = L10n.t("puzzle.correct")
            Feedback.shared.play(.puzzleSolved)
        } else {
            quizFeedback = L10n.t("puzzle.wrong")
            Feedback.shared.play(.error)
        }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run { self?.quizFeedback = nil }
        }
    }

    var quizAnswered: Bool { answeredQuizVersion == version }

    private func perform(_ work: @escaping () async throws -> OnlineResponse, success: String? = nil) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await work()
                await MainActor.run {
                    self.merge(response)
                    if let success { self.presentToast(success, style: .success) }
                }
            } catch {
                await MainActor.run {
                    self.presentToast(error.localizedDescription, style: .error)
                    Feedback.shared.play(.error)
                }
            }
        }
    }

    func resign() { perform { try await self.api.resign(self.info, version: self.version) } }
    func offerDraw() { perform({ try await self.api.offerDraw(self.info, version: self.version) }, success: L10n.t("game.draw")) }
    func respondDraw(accept: Bool) { perform { try await self.api.respondDraw(self.info, accept: accept, version: self.version) } }
    func offerUndo() { perform({ try await self.api.offerUndo(self.info, version: self.version) }, success: L10n.t("game.undo.request")) }
    func respondUndo(accept: Bool) { perform { try await self.api.respondUndo(self.info, accept: accept, version: self.version) } }
    func rematch() {
        recordedOutcome = false
        review = nil
        archivedRecordID = UUID()
        startedAt = Date()
        showGameOver = false
        perform { try await self.api.rematch(self.info, version: self.version) }
    }
    func nudge() {
        guard nudgeCooldown == 0 else { return }
        perform({ try await self.api.nudge(self.info) }, success: L10n.t("game.nudge.sent"))
    }

    func flip() { boardFlipped.toggle(); refreshInteraction() }

    func step(_ delta: Int) {
        let count = localGame.history.count
        let current = viewingPly ?? count
        let next = max(0, min(count, current + delta))
        viewingPly = next == count ? nil : next
        Feedback.shared.selectionChanged()
        refreshInteraction()
    }

    func jump(toPly ply: Int) {
        viewingPly = ply >= localGame.history.count ? nil : max(0, ply)
        refreshInteraction()
    }

    func pgn() -> String { localGame.pgn(white: whiteName, black: blackName, event: "Chess Duo Online · \(info.roomCode)", date: startedAt) }

    func presentToast(_ text: String, style: Toast.Style = .info) {
        toastTask?.cancel()
        toast = Toast(text: text, style: style)
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.toast = nil }
        }
    }

    func leave() {
        pollTask?.cancel()
        pollTask = nil
        Self.save(nil)
    }

    func pauseUpdates() { pollTask?.cancel(); pollTask = nil }
    func resumeUpdates() { if pollTask == nil { startPolling() } }

    deinit {
        pollTask?.cancel()
    }
}
