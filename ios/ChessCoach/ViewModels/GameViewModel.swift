import Combine
import Foundation
import UIKit

struct PendingPromotion: Identifiable {
    let id = UUID()
    let from: String
    let to: String
}

struct TurnAlert: Equatable {
    let title: String
    let detail: String?
}

@MainActor
final class GameViewModel: ObservableObject {
    @Published var playerName = ""
    @Published var roomCodeInput = ""
    @Published private(set) var session: PlayerSession?
    @Published private(set) var game = GameState()
    @Published private(set) var isLoading = false
    @Published private(set) var isSubmittingMove = false
    @Published private(set) var isReconnecting = false
    @Published var errorMessage: String?
    @Published var toastMessage: String?
    @Published var selectedSquare: String?
    @Published private(set) var coachMessage =
        "Look for checks, captures, and threats before every move."
    @Published var boardFlipped = false
    @Published var showLegend = false
    @Published var showCoachHistory = false
    @Published var quizFeedback: String?
    @Published private(set) var hintsEnabled: Bool = UserDefaults.standard.object(forKey: "hintsEnabled") as? Bool ?? false
    @Published private(set) var moveGuideEnabled: Bool = UserDefaults.standard.object(forKey: "moveGuideEnabled") as? Bool ?? false
    @Published private(set) var coachCollapsed: Bool = UserDefaults.standard.object(forKey: "coachCollapsed") as? Bool ?? false
    @Published private(set) var playForMeEnabled: Bool = UserDefaults.standard.object(forKey: "playForMeEnabled") as? Bool ?? false
    @Published private(set) var computerDifficulty: ComputerDifficulty = .stored
    @Published private(set) var privateSuggestedHint: SuggestedHint?
    @Published private(set) var privateHintMessage: String?
    @Published var showMatchReview = false
    @Published var pendingPromotion: PendingPromotion?
    @Published var turnAlert: TurnAlert?
    @Published private(set) var pendingPushToken: String?
    @Published var nudge = NudgeController()

    private let api: GameAPIClient
    private let store: SessionStore
    private var pollingTask: Task<Void, Never>?
    private var lastKnownVersion = -1
    private var lastKnownTurn: PlayerColor?
    private var toastTask: Task<Void, Never>?
    private var turnAlertTask: Task<Void, Never>?
    private var quizDismissTask: Task<Void, Never>?
    private var answeredQuizForVersion: Int?
    private var promotionContext: (from: String, to: String)?
    private var pendingDeepLinkCode: String?
#if DEBUG
    private var visualPreviewActive = false
#endif

    init(api: GameAPIClient = GameAPIClient(), store: SessionStore = SessionStore()) {
        self.api = api
        self.store = store
        session = store.load()
        SharedGameModel.shared = self
        if let session {
            playerName = session.playerName
            game.roomCode = session.roomCode
            startPolling()
        }
    }

    var legalDestinations: Set<String> {
        guard let selectedSquare else { return [] }
        return Set(game.legalMoves.filter { $0.from == selectedSquare }.map(\.to))
    }

    var boardOrientation: PlayerColor {
        if boardFlipped {
            return session?.color == .black ? .white : .black
        }
        return session?.color == .black ? .black : .white
    }

    var canMove: Bool {
        guard let session, session.color != .spectator else { return false }
        return game.turn == session.color && !game.isFinished && !isSubmittingMove
    }

    var turnBanner: String {
        if game.status.lowercased() == "waiting" {
            return L10n.t(.waitingPartner)
        }
        if game.isFinished {
            return game.result ?? L10n.t(.gameOver)
        }
        if game.isCheck {
            if game.turn == session?.color {
                return L10n.t(.inCheckYou)
            }
            return L10n.t(.inCheckThem, displayName(for: game.turn))
        }
        if let session, game.turn == session.color {
            return L10n.t(.yourTurn)
        }
        return L10n.t(.waitingForName, displayName(for: game.turn))
    }

    var selectedSquareLabel: String? {
        guard let selectedSquare else { return nil }
        return selectedSquare.uppercased()
    }

    var lastMoveLabel: String? {
        guard let last = game.lastMove, let from = last.from, let to = last.to else { return nil }
        let who = (last.by == "white" ? game.whiteName : game.blackName)
        let sanSuffix = last.san.map { " (\($0))" } ?? ""
        return L10n.t(.playedMove, who, from.uppercased(), to.uppercased(), sanSuffix)
    }

    var drama: GameDrama {
        PositionDrama.evaluate(
            fen: game.fen,
            status: game.status,
            isCheck: game.isCheck,
            legalMoveCount: game.legalMoves.count,
            you: session?.color == .spectator ? nil : session?.color,
            whiteName: game.whiteName,
            blackName: game.blackName
        )
    }

    func createGame() async {
        let name = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            presentToast(L10n.t(.enterNameCreate))
            return
        }
        await performLobbyRequest {
            try await self.api.create(name: name)
        }
    }

    func joinGame() async {
        let name = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = roomCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !name.isEmpty, !code.isEmpty else {
            presentToast(L10n.t(.enterNameJoin))
            return
        }
        await performLobbyRequest {
            try await self.api.join(name: name, roomCode: code)
        }
    }

    func spectateGame() async {
        let code = roomCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else {
            presentToast(L10n.t(.enterCodeWatch))
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await api.spectate(roomCode: code)
            let newSession = PlayerSession(
                roomCode: code,
                playerToken: "spectator",
                color: .spectator,
                playerName: playerName.isEmpty ? "Spectator" : playerName
            )
            session = newSession
            store.save(newSession)
            merge(response)
            startPolling()
            registerForPushIfAvailable()
        } catch {
            show(error)
        }
    }

    func consumePendingDeepLink() -> String? {
        defer { pendingDeepLinkCode = nil }
        return pendingDeepLinkCode
    }

    func select(square: String) {
        guard canMove else {
            if session?.color != .spectator {
                presentToast(game.turn == session?.color ? L10n.t(.pickYourPiece) : L10n.t(.waitYourTurn))
            }
            return
        }

        if legalDestinations.contains(square), let selectedSquare {
            if isPromotionMove(from: selectedSquare, to: square) {
                promotionContext = (selectedSquare, square)
                pendingPromotion = PendingPromotion(from: selectedSquare, to: square)
                Feedback.lightTap()
            } else {
                Task { await submitMove(from: selectedSquare, to: square) }
            }
            return
        }

        let hasLegalMove = game.legalMoves.contains { $0.from == square }
        if hasLegalMove, let piece = ChessPosition(fen: game.fen).pieces[square] {
            selectedSquare = square
            if moveGuideEnabled {
                coachMessage = selectionHelp(for: piece, square: square)
            }
            Feedback.lightTap()
            return
        }

        if let selectedSquare {
            let piece = ChessPosition(fen: game.fen).pieces[selectedSquare]
            presentToast(L10n.t(
                .cantGoSquare,
                square.uppercased(),
                piece.map { illegalHelp(for: $0) } ?? L10n.t(.onlyHighlighted)
            ))
            Feedback.warning()
            return
        }

        selectedSquare = nil
        if let piece = ChessPosition(fen: game.fen).pieces[square], piece.isWhite != (session?.color == .white) {
            presentToast(L10n.t(.opponentPiece))
            Feedback.warning()
        } else {
            presentToast(L10n.t(.pieceCantMove))
            Feedback.warning()
        }
    }

    func requestHint() async {
        guard let session, session.color != .spectator else { return }
        guard hintsEnabled else {
            presentToast(L10n.t(.turnOnHints))
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await api.hint(version: game.version, session: session)
            merge(response)
            let text = response.coachText ?? response.hint ?? response.message
            privateHintMessage = text
            privateSuggestedHint = response.suggestedHint
            if moveGuideEnabled, let text {
                coachMessage = text
            } else if let text {
                presentToast(text)
            }
            Feedback.success()
        } catch {
            show(error)
        }
    }

    func playForMe() async {
        guard let session, session.color != .spectator else { return }
        guard playForMeEnabled else {
            presentToast(L10n.t(.turnOnPlayForMe))
            return
        }
        guard canMove else {
            presentToast(L10n.t(.waitYourTurn))
            return
        }
        isSubmittingMove = true
        errorMessage = nil
        defer { isSubmittingMove = false }

        // Never fail for the player: retry server playForMe, then fall back to any legal move.
        for attempt in 0..<4 {
            do {
                let response = try await api.playForMe(
                    version: game.version,
                    session: session,
                    difficulty: computerDifficulty
                )
                selectedSquare = nil
                merge(response)
                Feedback.moveSent()
                Feedback.clearBadge()
                dismissTurnAlert()
                if let last = response.lastMove, let from = last.from, let to = last.to {
                    let sanSuffix = last.san.map { " (\($0))" } ?? ""
                    presentToast(L10n.t(
                        .computerPlayedMove,
                        computerDifficulty.title,
                        from.uppercased(),
                        to.uppercased(),
                        sanSuffix
                    ))
                } else {
                    presentToast(L10n.t(.computerPlayed, computerDifficulty.title))
                }
                return
            } catch {
                if attempt == 0, let refreshed = try? await api.state(session: session) {
                    merge(refreshed)
                }
                // Prefer captures/checks over a random weak move when the server fails.
                var move = game.legalMoves.first { $0.isCapture == true }
                if move == nil {
                    move = game.legalMoves.first { $0.isCheck == true }
                }
                if move == nil {
                    let centers: Set<String> = ["d4", "e4", "d5", "e5", "c4", "f4", "c5", "f5"]
                    move = game.legalMoves.first { centers.contains($0.to) }
                }
                if move == nil {
                    move = game.legalMoves.first
                }
                if let move {
                    do {
                        let response = try await api.moveAssisted(
                            from: move.from,
                            to: move.to,
                            promotion: move.promotion ?? "q",
                            version: game.version,
                            session: session,
                            difficulty: computerDifficulty
                        )
                        selectedSquare = nil
                        merge(response)
                        Feedback.moveSent()
                        Feedback.clearBadge()
                        dismissTurnAlert()
                        presentToast(L10n.t(.computerFallback))
                        return
                    } catch {
                        try? await Task.sleep(nanoseconds: UInt64(150_000_000 * (attempt + 1)))
                        if let refreshed = try? await api.state(session: session) {
                            merge(refreshed)
                        }
                        continue
                    }
                }
                try? await Task.sleep(nanoseconds: UInt64(150_000_000 * (attempt + 1)))
                if let refreshed = try? await api.state(session: session) {
                    merge(refreshed)
                }
                if !canMove { return }
            }
        }
        // Last ditch: still try one legal assisted move without surfacing a scary alert.
        if canMove, let move = game.legalMoves.first {
            if let response = try? await api.moveAssisted(
                from: move.from,
                to: move.to,
                promotion: move.promotion ?? "q",
                version: game.version,
                session: session,
                difficulty: .easy
            ) {
                selectedSquare = nil
                merge(response)
                Feedback.success()
                presentToast(L10n.t(.computerFallback))
                return
            }
        }
        presentToast(L10n.t(.serverBusy))
        Feedback.warning()
    }

    func offerDraw() async {
        guard let session, session.color != .spectator else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            merge(try await api.offerDraw(version: game.version, session: session))
            presentToast(L10n.t(.drawOfferedByYou))
        } catch {
            show(error)
        }
    }

    func respondDraw(accept: Bool) async {
        guard let session, session.color != .spectator else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            merge(try await api.respondDraw(accept: accept, version: game.version, session: session))
            Feedback.success()
        } catch {
            show(error)
        }
    }

    func offerUndo() async {
        guard let session, session.color != .spectator else { return }
        guard game.moveCount > 0 else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            merge(try await api.offerUndo(version: game.version, session: session))
            presentToast(L10n.t(.undoOfferedByYou))
        } catch {
            show(error)
        }
    }

    func respondUndo(accept: Bool) async {
        guard let session, session.color != .spectator else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            merge(try await api.respondUndo(accept: accept, version: game.version, session: session))
            Feedback.success()
        } catch {
            show(error)
        }
    }

    func refreshPastGames() async -> [ArchivedMatch] {
        var local = MatchArchiveStore.load()
        let tokens = Array(Set([session?.playerToken, MatchArchiveStore.latestPlayerToken].compactMap { $0 } + MatchArchiveStore.knownTokens))
        for token in tokens {
            if let remote = try? await api.listArchives(playerToken: token), !remote.isEmpty {
                MatchArchiveStore.mergeServer(remote)
                local = MatchArchiveStore.load()
            }
        }
        return local
    }


    func sendNudge() async {
        guard let session, session.color != .spectator else { return }
        guard nudge.isEnabled, !nudge.isSending else { return }
        registerForPushIfAvailable()
        nudge.beginSend()
        defer { nudge.endSend() }
        do {
            let response = try await api.nudge(session: session)
            consumeNudge(from: response)
            let opponent = nudge.opponentName.isEmpty ? displayName(for: session.color.opponent) : nudge.opponentName
            presentToast(nudge.applySendResult(
                delivered: response.delivered,
                remaining: response.nudgeRemaining,
                cooldown: response.nudgeCooldownRemaining,
                opponent: opponent
            ))
        } catch {
            let text = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            nudge.applySendError(text, game: game, session: session)
            presentToast(text)
        }
    }

    func consumeNudge(from response: GameResponse) {
        if let event = response.nudge { game.lastNudge = event }
        if let cooldown = response.nudgeCooldownRemaining { game.nudgeCooldownRemaining = cooldown }
        if let remaining = response.nudgeRemaining { game.nudgeRemaining = remaining }
        nudge.sync(
            game: game,
            session: session,
            incoming: response.nudge,
            cooldown: response.nudgeCooldownRemaining,
            remaining: response.nudgeRemaining,
            presentToast: presentToast
        )
    }

    func resign() async {
        guard let session, session.color != .spectator else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            merge(try await api.resign(version: game.version, session: session))
        } catch {
            show(error)
        }
    }

    func rematch() async {
        guard let session, session.color != .spectator else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            merge(try await api.rematch(version: game.version, session: session))
            selectedSquare = nil
            quizFeedback = nil
            showMatchReview = false
            answeredQuizForVersion = nil
            quizDismissTask?.cancel()
            quizDismissTask = nil
            clearPrivateHint()
            Feedback.success()
        } catch {
            show(error)
        }
    }

    func answerQuiz(_ option: QuizOption) {
        guard let answer = game.quiz?.answerSquare?.lowercased() else { return }
        if option.square.lowercased() == answer {
            quizFeedback = "Nice! \(option.label) was the capturing square."
            Feedback.success()
        } else {
            quizFeedback = "Not quite. The capturing square was \(answer.uppercased())."
            Feedback.warning()
        }
        answeredQuizForVersion = game.version
        quizDismissTask?.cancel()
        quizDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            guard !Task.isCancelled else { return }
            guard answeredQuizForVersion == game.version else { return }
            game.quiz = nil
            quizFeedback = nil
        }
    }

    var shouldShowQuiz: Bool {
        guard moveGuideEnabled, game.quiz != nil else { return false }
        return answeredQuizForVersion != game.version || quizFeedback != nil
    }

    func refresh() async {
        guard let session else { return }
        do {
            if session.color == .spectator {
                merge(try await api.spectate(roomCode: session.roomCode))
            } else {
                let known = lastKnownVersion >= 0 ? lastKnownVersion : nil
                let response = try await api.state(session: session, sinceVersion: known)
                if response.changed == false {
                    lastKnownVersion = response.version ?? lastKnownVersion
                    consumeNudge(from: response)
                    return
                }
                merge(response)
            }
            isReconnecting = false
            if errorMessage == "Connection lost. Reconnecting…" {
                errorMessage = nil
            }
        } catch is CancellationError {
            return
        } catch {
            isReconnecting = true
            errorMessage = "Connection lost. Reconnecting…"
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func leaveGame() {
        pollingTask?.cancel()
        pollingTask = nil
        store.clear()
        session = nil
        game = GameState()
        selectedSquare = nil
        errorMessage = nil
        toastMessage = nil
        quizFeedback = nil
        showMatchReview = false
        roomCodeInput = ""
        clearPrivateHint()
        quizDismissTask?.cancel()
        quizDismissTask = nil
        answeredQuizForVersion = nil
        lastKnownVersion = -1
        lastKnownTurn = nil
        nudge.reset()
    }

    private func clearPrivateHint() {
        privateSuggestedHint = nil
        privateHintMessage = nil
        game.suggestedHint = nil
    }

    func startPolling() {
#if DEBUG
        if visualPreviewActive { return }
#endif
        guard session != nil, pollingTask == nil else { return }
        nudge.notePollingStarted()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                let finished = await self?.game.isFinished ?? false
                try? await Task.sleep(nanoseconds: finished ? 5_000_000_000 : 1_500_000_000)
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        nudge.notePollingStopped()
    }

    func shareRoomText() -> String {
        "Join my Chess Duo game! Room code: \(game.roomCode)\nchessduo://room/\(game.roomCode)"
    }

    func copyRoomCode() {
        UIPasteboard.general.string = game.roomCode
        presentToast(L10n.t(.codeCopied))
        Feedback.lightTap()
    }

    func setHintsEnabled(_ enabled: Bool) {
        hintsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "hintsEnabled")
        if !enabled {
            clearPrivateHint()
            presentToast(L10n.t(.hintsOff))
        } else {
            presentToast(L10n.t(.hintsOn))
        }
    }

    var boardSuggestedHint: SuggestedHint? {
        hintsEnabled ? privateSuggestedHint : nil
    }

    var displayedCoachMessage: String {
        if moveGuideEnabled, let privateHintMessage, !privateHintMessage.isEmpty {
            return privateHintMessage
        }
        return coachMessage
    }

    func setMoveGuideEnabled(_ enabled: Bool) {
        moveGuideEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "moveGuideEnabled")
        presentToast(enabled ? L10n.t(.moveGuideOn) : L10n.t(.moveGuideOff))
        if enabled {
            coachMessage = game.coachMessage
        }
    }

    func setCoachCollapsed(_ collapsed: Bool) {
        coachCollapsed = collapsed
        UserDefaults.standard.set(collapsed, forKey: "coachCollapsed")
    }

    func setPlayForMeEnabled(_ enabled: Bool) {
        playForMeEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "playForMeEnabled")
        presentToast(enabled ? L10n.t(.playForMeOn) : L10n.t(.playForMeOff))
    }

    func setComputerDifficulty(_ difficulty: ComputerDifficulty) {
        computerDifficulty = difficulty
        UserDefaults.standard.set(difficulty.rawValue, forKey: "computerDifficulty")
        presentToast(L10n.t(.computerSetTo, difficulty.title))
    }

    private func performLobbyRequest(
        _ request: @escaping () async throws -> GameResponse
    ) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await request()
            guard
                let roomCode = response.roomCode,
                let token = response.playerToken,
                let color = response.color
            else {
                throw GameAPIError.invalidResponse
            }
            let newSession = PlayerSession(
                roomCode: roomCode.uppercased(),
                playerToken: token,
                color: color,
                playerName: playerName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            session = newSession
            store.save(newSession)
            merge(response)
            startPolling()
            registerForPushIfAvailable()
        } catch {
            show(error)
        }
    }

    func handleDeviceToken(_ tokenData: Data) {
        let hex = tokenData.map { String(format: "%02x", $0) }.joined()
        pendingPushToken = hex
        registerForPushIfAvailable()
    }

    func registerForPushIfAvailable() {
        guard let session, session.color != .spectator else { return }
        Feedback.requestNotificationPermission()
        UIApplication.shared.registerForRemoteNotifications()
        guard let hex = pendingPushToken else { return }
        let sentToken = hex
        let sentSession = session
        Task { [weak self] in
            try? await self?.api.registerPush(
                apnsToken: sentToken,
                session: sentSession,
                turnAlerts: Feedback.turnNotificationsEnabled
            )
        }
    }

    func setTurnNotificationsEnabled(_ enabled: Bool) {
        if enabled {
            Feedback.requestNotificationPermission()
            UIApplication.shared.registerForRemoteNotifications()
        }
        guard let hex = pendingPushToken, let session, session.color != .spectator else { return }
        Task { [weak self] in
            try? await self?.api.registerPush(apnsToken: hex, session: session, turnAlerts: enabled)
        }
    }

    func clearBadge() {
        Feedback.clearBadge()
    }

    func handleRoomLink(_ code: String) {
        guard session == nil else { return }
        roomCodeInput = code.uppercased()
        pendingDeepLinkCode = code.uppercased()
    }

    private func isPromotionMove(from: String, to: String) -> Bool {
        let files = "abcdefgh"
        guard let fromFile = files.firstIndex(of: from.lowercased().first ?? " "),
              let toFile = files.firstIndex(of: to.lowercased().first ?? " "),
              let fromRank = Int(from.suffix(1)),
              let toRank = Int(to.suffix(1)),
              fromFile == toFile || abs(files.distance(from: fromFile, to: toFile)) == 1
        else { return false }
        let isWhiteMove = session?.color == .white
        let reachedLastRank = isWhiteMove ? toRank == 8 : toRank == 1
        let startedPenultimate = isWhiteMove ? fromRank == 7 : fromRank == 2
        guard reachedLastRank, startedPenultimate else { return false }
        return game.legalMoves.contains { move in
            move.from == from.lowercased() && move.to == to.lowercased() && move.promotion != nil
        }
    }

    func choosePromotion(_ piece: String) {
        guard let context = promotionContext else { return }
        promotionContext = nil
        pendingPromotion = nil
        Task { await submitMove(from: context.from, to: context.to, promotion: piece) }
    }

    func cancelPromotion() {
        promotionContext = nil
        pendingPromotion = nil
    }

    private func submitMove(from: String, to: String, promotion: String = "q") async {
        guard let session else { return }
        isSubmittingMove = true
        errorMessage = nil
        defer { isSubmittingMove = false }
        do {
            let response = try await api.move(
                from: from,
                to: to,
                promotion: promotion,
                version: game.version,
                session: session
            )
            selectedSquare = nil
            merge(response)
            Feedback.moveSent()
            Feedback.clearBadge()
            dismissTurnAlert()
        } catch {
            show(error)
            Feedback.warning()
        }
    }

    private func merge(_ response: GameResponse) {
        let previousVersion = game.version
        let previousTurn = game.turn
        let wasFinished = game.isFinished
        let isPrivateHint = response.privateHint == true
        consumeNudge(from: response)

        if let version = response.version, version == previousVersion, previousVersion >= 0,
           response.fen == nil, response.status == nil, response.coachText == nil,
           response.coachHistory == nil, response.legalMoves == nil, !isPrivateHint {
            lastKnownVersion = version
            return
        }

        if let roomCode = response.roomCode { game.roomCode = roomCode.uppercased() }
        // Colors can swap when the partner joins — keep this phone's seat in sync.
        if let color = response.color, let current = session, current.color != .spectator, color != current.color {
            let updated = PlayerSession(
                roomCode: current.roomCode,
                playerToken: current.playerToken,
                color: color,
                playerName: current.playerName
            )
            session = updated
            store.save(updated)
        }
        if let fen = response.fen {
            game.fen = fen
            let fields = fen.split(separator: " ")
            if fields.count > 1 {
                game.turn = fields[1] == "w" ? .white : .black
            }
        }
        if let turn = response.turn { game.turn = turn }
        if let status = response.status { game.status = status }
        if let whiteName = response.whiteName { game.whiteName = whiteName }
        if let blackName = response.blackName { game.blackName = blackName }
        if let isCheck = response.isCheck { game.isCheck = isCheck }
        if let result = response.result { game.result = result }
        if let legalMoves = response.legalMoves { game.legalMoves = legalMoves }
        if let version = response.version {
            if version != previousVersion {
                answeredQuizForVersion = nil
                quizFeedback = nil
                quizDismissTask?.cancel()
                quizDismissTask = nil
            }
            game.version = version
        }
        if let moveCount = response.moveCount { game.moveCount = moveCount }

        // Shared move commentary (what just happened) — never treat as the other player's private hint.
        if !isPrivateHint {
            if let coachText = response.coachText {
                game.coachMessage = coachText
                if moveGuideEnabled { coachMessage = coachText }
            }
            if let coachSource = response.coachSource { game.coachSource = coachSource }
            // Never take suggestedHint from shared polls — hints are private-only.
            game.suggestedHint = nil
        } else if let suggestedHint = response.suggestedHint {
            privateSuggestedHint = suggestedHint
        }

        if let coachHistory = response.coachHistory { game.coachHistory = coachHistory }
        if let lastMove = response.lastMove { game.lastMove = lastMove }
        if let quiz = response.quiz {
            if answeredQuizForVersion == game.version {
                // Keep the quiz hidden after this phone already answered it.
                if quizFeedback == nil {
                    game.quiz = nil
                }
            } else {
                game.quiz = quiz
            }
        } else if response.version != nil {
            game.quiz = nil
        }

        if game.version != previousVersion, previousVersion >= 0 {
            clearPrivateHint()
        }
        if let threatened = response.threatenedSquares { game.threatenedSquares = threatened }
        if let captured = response.captured { game.captured = captured }
        if let goalText = response.goalText { game.goalText = goalText }
        if let apiVersion = response.apiVersion { game.apiVersion = apiVersion }
        if let moveHistory = response.moveHistory { game.moveHistory = moveHistory }
        if let review = response.review {
            game.review = review
        } else if response.version != nil, response.review == nil, !game.isFinished {
            game.review = nil
        }
        if response.drawOfferBy != nil || response.version != nil {
            game.drawOfferBy = response.drawOfferBy
        }
        if response.undoOfferBy != nil || response.version != nil {
            game.undoOfferBy = response.undoOfferBy
        }

        if let selectedSquare,
           !game.legalMoves.contains(where: { $0.from == selectedSquare }) {
            self.selectedSquare = nil
        }

        let justFinished = !wasFinished && game.isFinished
        if previousVersion >= 0,
           game.version > previousVersion,
           let session,
           previousTurn == session.color,
           game.turn == session.color.opponent || game.isFinished {
            // own move already handled
        } else if previousVersion >= 0,
                  game.version > previousVersion,
                  let session,
                  game.turn == session.color,
                  previousTurn != session.color {
            let moverName = displayName(for: session.color.opponent)
            let detail = game.lastMove?.san.map { L10n.t(.playedSan, moverName, $0) }
            if game.isCheck {
                Feedback.check()
            } else {
                Feedback.yourTurn()
            }
            Feedback.setTurnBadge()
            if UIApplication.shared.applicationState != .active {
                Feedback.notifyYourTurn(roomCode: game.roomCode, moveLabel: detail)
            } else {
                presentTurnAlert(title: L10n.t(.yourMove), detail: detail)
            }
        } else if previousVersion >= 0,
                  game.version > previousVersion,
                  session?.color == .spectator {
            Feedback.softMoveLanded()
        }

        if justFinished {
            if let review = game.review {
                MatchArchiveStore.save(
                    .fromFinishedGame(
                        roomCode: game.roomCode,
                        whiteName: game.whiteName,
                        blackName: game.blackName,
                        status: game.status,
                        resultText: game.result ?? game.status,
                        moveCount: game.moveCount,
                        review: review,
                        playerToken: session?.playerToken
                    )
                )
                showMatchReview = true
            }
            let status = game.status.lowercased()
            let won = (status == "white_won" && session?.color == .white)
                || (status == "black_won" && session?.color == .black)
            if won {
                Feedback.gameWon()
            } else {
                Feedback.gameOverFlat()
            }
        }

        lastKnownVersion = game.version
        lastKnownTurn = game.turn
    }

    private func show(_ error: Error) {
        let text = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        errorMessage = text
        presentToast(text)
    }

    private func presentToast(_ text: String) {
        toastMessage = text
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled {
                toastMessage = nil
            }
        }
    }

    private func presentTurnAlert(title: String, detail: String? = nil) {
        turnAlertTask?.cancel()
        turnAlert = TurnAlert(title: title, detail: detail)
        turnAlertTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if !Task.isCancelled {
                turnAlert = nil
            }
        }
    }

    func dismissTurnAlert() {
        turnAlertTask?.cancel()
        turnAlert = nil
    }

    private func displayName(for color: PlayerColor) -> String {
        color == .white ? game.whiteName : game.blackName
    }

    private func selectionHelp(for piece: ChessPiece, square: String) -> String {
        "\(piece.accessibilityName.capitalized) on \(square.uppercased()). \(illegalHelp(for: piece)) Tap a highlighted square to move it."
    }

    private func illegalHelp(for piece: ChessPiece) -> String {
        switch piece.symbol.lowercased() {
        case "k": return L10n.t(.pieceHelpKing)
        case "q": return L10n.t(.pieceHelpQueen)
        case "r": return L10n.t(.pieceHelpRook)
        case "b": return L10n.t(.pieceHelpBishop)
        case "n": return L10n.t(.pieceHelpKnight)
        default: return L10n.t(.pieceHelpPawn)
        }
    }

#if DEBUG
    func loadVisualPreview(_ kind: String) {
        visualPreviewActive = true
        stopPolling()
        switch kind {
        case "waiting":
            session = PlayerSession(roomCode: "AB12CD", playerToken: "preview", color: .white, playerName: "Mike")
            var next = GameState()
            next.roomCode = "AB12CD"
            next.status = "waiting"
            next.whiteName = "Mike"
            game = next
        case "playing":
            session = PlayerSession(roomCode: "AB12CD", playerToken: "preview", color: .white, playerName: "Mike")
            var next = GameState()
            next.roomCode = "AB12CD"
            next.status = "active"
            next.whiteName = "Mike"
            next.blackName = "Liana"
            next.turn = .white
            next.coachMessage = "Look for checks, captures, and threats before every move."
            next.coachSource = "ai"
            next.legalMoves = [
                LegalMove(from: "e2", to: "e4"),
                LegalMove(from: "e2", to: "e3"),
                LegalMove(from: "g1", to: "f3")
            ]
            game = next
            moveGuideEnabled = true
            coachCollapsed = false
            hintsEnabled = true
            playForMeEnabled = true
        case "promotion":
            loadVisualPreview("playing")
            pendingPromotion = PendingPromotion(from: "e7", to: "e8")
        case "turnalert":
            loadVisualPreview("playing")
            presentTurnAlert(title: L10n.t(.yourMove), detail: L10n.t(.playedSan, "Liana", "Nf3"))
            Feedback.yourTurn()
            Feedback.setTurnBadge()
            print("[preview] turn alert shown, yourTurn sound+haptic fired, badge set to 1")
        case "review":
            session = PlayerSession(roomCode: "AB12CD", playerToken: "preview", color: .white, playerName: "Mike")
            var next = GameState()
            next.roomCode = "AB12CD"
            next.status = "finished"
            next.result = "Mike wins"
            next.whiteName = "Mike"
            next.blackName = "Liana"
            next.review = MatchReview(
                white: PlayerReview(name: "Mike", accuracy: 88, unaidedAccuracy: 84, moveCount: 12, assistedCount: 1),
                black: PlayerReview(name: "Liana", accuracy: 74, unaidedAccuracy: 74, moveCount: 11, assistedCount: 0),
                moves: [
                    MoveReviewEntry(from: "e2", to: "e4", san: "e4", by: "white", assisted: false, precision: 92, label: "Played"),
                    MoveReviewEntry(from: "e7", to: "e5", san: "e5", by: "black", assisted: false, precision: 80, label: "Played")
                ]
            )
            game = next
            showMatchReview = true
        default:
            break
        }
    }
#endif
}
