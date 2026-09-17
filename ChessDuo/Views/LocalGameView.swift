import SwiftUI

/// Game screen for pass & play and computer games.
struct LocalGameView: View {
    @ObservedObject var session: GameSession
    @ObservedObject private var clock: ChessClock
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    let onClose: () -> Void

    @State private var showResign = false
    @State private var showLeave = false
    @State private var showDrawConfirm = false
    @State private var showPlayForMe = false
    @State private var showReview = false
    @State private var shareItems: [Any]? = nil
    @State private var showSettings = false
    @State private var showEval = false

    init(session: GameSession, onClose: @escaping () -> Void) {
        self.session = session
        self.clock = session.clock
        self.onClose = onClose
    }

    private var top: PieceColor { session.effectiveOrientation.opposite }
    private var bottom: PieceColor { session.effectiveOrientation }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let landscape = geo.size.width > geo.size.height
                Group {
                    if landscape { landscapeLayout } else { portraitLayout }
                }
            }
            .duoBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showLeave = true } label: { Image(systemName: "xmark") }.accessibilityIdentifier("game.close")
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text(session.turnText).font(.subheadline.weight(.bold))
                        if let level = session.engineLevel { Text(L10n.t("computer.level\(level.rawValue)")).font(.caption2).foregroundStyle(.secondary) }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { session.use3D.toggle() } label: { Label(session.use3D ? L10n.t("game.view2D") : L10n.t("game.view3D"), systemImage: "cube") }
                        Button { session.flip() } label: { Label(L10n.t("game.flip"), systemImage: "arrow.up.arrow.down") }
                        Button { showEval.toggle(); if showEval { session.refreshEval() } } label: { Label(L10n.t("game.eval"), systemImage: "chart.bar.fill") }
                        if clock.isActive && !session.game.isFinished {
                            Button { session.togglePause() } label: { Label(clock.isPaused ? L10n.t("game.resumeClock") : L10n.t("game.pause"), systemImage: clock.isPaused ? "play.fill" : "pause.fill") }
                        }
                        Divider()
                        Button { UIPasteboard.general.string = session.game.position.fen; session.presentToast(L10n.t("game.copied"), style: .success) } label: { Label(L10n.t("game.copyFEN"), systemImage: "doc.on.doc") }
                        Button { shareItems = [session.pgn()] } label: { Label(L10n.t("game.sharePGN"), systemImage: "square.and.arrow.up") }
                        Divider()
                        Button { showSettings = true } label: { Label(L10n.t("settings.title"), systemImage: "gearshape") }
                    } label: { Image(systemName: "ellipsis.circle") }.accessibilityIdentifier("game.menu")
                }
            }
            .alert(L10n.t("game.resign.confirm"), isPresented: $showResign) {
                Button(L10n.t("cancel"), role: .cancel) {}
                Button(L10n.t("game.resign"), role: .destructive) { session.resign() }
            } message: { Text(L10n.t("game.resign.msg")) }
            .alert(L10n.t("game.leave.confirm"), isPresented: $showLeave) {
                Button(L10n.t("cancel"), role: .cancel) {}
                Button(L10n.t("game.leave"), role: .destructive) { session.leave(); onClose() }
            } message: { Text(L10n.t("game.leave.msg")) }
            .alert(L10n.t("game.draw.confirm"), isPresented: $showDrawConfirm) {
                Button(L10n.t("cancel"), role: .cancel) {}
                Button(L10n.t("game.draw")) { session.offerDraw() }
            }
            .alert(L10n.t("game.playForMe.confirm"), isPresented: $showPlayForMe) {
                Button(L10n.t("cancel"), role: .cancel) {}
                Button(L10n.t("game.playForMe")) { session.playForMe() }
            } message: { Text(L10n.t("game.playForMe.msg")) }
            .sheet(item: $session.pendingPromotion) { p in
                PromotionSheet(color: p.color) { session.completePromotion($0) }
            }
            .sheet(isPresented: $session.showGameOver) {
                if let result = session.game.result {
                    GameOverSheet(result: result, whiteName: session.whiteName, blackName: session.blackName, me: session.humanColor, moveCount: session.game.history.count, review: session.review, isReviewing: session.isReviewing, reviewProgress: session.reviewProgress,
                                  rematchTitle: session.isComputerGame ? L10n.t("game.rematch") : L10n.t("game.newGame"),
                                  onRematch: { session.showGameOver = false; startRematch() },
                                  onReview: { session.showGameOver = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showReview = true } },
                                  onShare: { session.showGameOver = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shareItems = [session.pgn()] } },
                                  onClose: { session.showGameOver = false })
                }
            }
            .sheet(isPresented: $showReview) {
                if let review = session.review { ReviewView(record: session.makeRecord(), review: review) }
            }
            .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) {
                if let items = shareItems { ShareSheet(items: items) }
            }
            .sheet(isPresented: $showSettings) { NavigationStack { SettingsView() } }
            .onChange(of: settings.showLegalMoves) { _, _ in session.refreshInteraction() }
            .onChange(of: settings.highlightLastMove) { _, _ in session.refreshInteraction() }
            .onChange(of: settings.highlightThreats) { _, _ in session.refreshInteraction() }
            .onChange(of: settings.moveGuide) { _, _ in session.refreshInteraction() }
            .onChange(of: settings.localAutoFlip) { _, _ in session.refreshInteraction() }
            .onChange(of: session.game.history.count) { _, _ in if showEval { session.refreshEval() } }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { session.persist(); if clock.isActive && !session.game.isFinished { clock.pause() } }
            }
        }
        .overlay(alignment: .top) {
            if let toast = session.toast {
                ToastView(toast: toast).padding(.top, 60).transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: session.toast)
        .fullScreenCover(item: $replacement) { next in
            LocalGameView(session: next) { replacement = nil; onClose() }
                .environmentObject(settings)
        }
    }

    private func startRematch() {
        let next = session.newGame()
        // Replace the session in place by presenting a new one via the parent: simplest is to reuse this view with a new object.
        replacement = next
    }
    @State private var replacement: GameSession? = nil

    private var portraitLayout: some View {
        ZStack {
            VStack(spacing: 10) {
                playerBar(top)
                HStack(spacing: 8) {
                    if showEval { EvalBar(evalWhite: session.evalCentipawns, orientation: bottom) }
                    board
                }
                .padding(.horizontal, 6)
                playerBar(bottom)
                MoveStrip(moves: session.game.history, viewingPly: session.viewingPly) { session.jump(toPly: $0) }
                    .duoCard(padding: 4)
                    .padding(.horizontal, 12)
                if settings.coachCard {
                    CoachCardView(text: session.coachText, hint: session.hintText).padding(.horizontal, 12)
                }
                if session.drawOfferPending {
                    OfferBanner(text: L10n.t("game.draw.offered", session.name(for: session.sideToMove)), acceptTitle: L10n.t("game.draw.accept"), declineTitle: L10n.t("game.draw.decline"), onAccept: { session.respondDraw(accept: true) }, onDecline: { session.respondDraw(accept: false) }).padding(.horizontal, 12)
                }
                Spacer(minLength: 0)
                actionBar.padding(.horizontal, 12).padding(.bottom, 8)
            }
            .padding(.top, 6)
            if clock.isPaused && !session.game.isFinished {
                pausedOverlay
            }
        }
    }

    private var landscapeLayout: some View {
        HStack(spacing: 12) {
            board.padding(.leading, 8)
            VStack(spacing: 10) {
                playerBar(top)
                playerBar(bottom)
                if settings.coachCard { CoachCardView(text: session.coachText, hint: session.hintText) }
                MoveStrip(moves: session.game.history, viewingPly: session.viewingPly) { session.jump(toPly: $0) }.duoCard(padding: 4)
                Spacer()
                actionBar
            }
            .padding(.trailing, 12)
        }
        .padding(.vertical, 8)
    }

    private var board: some View {
        ChessBoardContainer(position: session.displayedPosition, interaction: session.interaction, use3D: session.use3D, onTap: { session.tap($0) }, onDrop: { session.drop(from: $0, to: $1) })
            .overlay(alignment: .bottom) {
                if session.isViewingHistory {
                    Text("\(L10n.t("review.replay")) · \(session.viewingPly ?? 0)/\(session.game.history.count)")
                        .font(.caption.weight(.bold)).padding(.horizontal, 10).padding(.vertical, 5).background(.ultraThinMaterial, in: Capsule()).padding(8)
                }
            }
    }

    private func playerBar(_ color: PieceColor) -> some View {
        let captured = session.game.captured
        let diff = captured.materialDiff * (color == .white ? 1 : -1)
        return PlayerBar(
            name: session.name(for: color),
            color: color,
            captured: color == .white ? captured.byWhite : captured.byBlack,
            materialDiff: diff,
            clock: clock.isActive ? clock.remaining(color) : nil,
            clockRunning: clock.running == color && !clock.isPaused,
            isTurn: session.sideToMove == color && !session.game.isFinished,
            isThinking: session.isEngineThinking && session.sideToMove == color,
            subtitle: session.engineLevel != nil && session.humanColor != color ? L10n.t("computer.elo", session.engineLevel!.approxElo) : nil
        )
        .padding(.horizontal, 12)
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            actionButton("arrow.uturn.backward", L10n.t("game.undo"), enabled: session.canUndo) { session.undo() }
            if settings.hintsEnabled {
                actionButton("lightbulb.fill", L10n.t("game.hint"), enabled: session.canHumanMove) { session.requestHint() }
            }
            if settings.playForMe {
                actionButton("cpu", L10n.t("game.playForMe"), enabled: session.canHumanMove) { showPlayForMe = true }
            }
            if session.game.canClaimDraw && !session.game.isFinished {
                actionButton("equal.circle", L10n.t("game.draw.claim"), enabled: true) { session.claimDraw() }
            } else {
                actionButton("equal.circle", L10n.t("game.draw"), enabled: !session.game.isFinished && !session.drawOfferPending) { showDrawConfirm = true }
            }
            actionButton("flag.fill", L10n.t("game.resign"), enabled: !session.game.isFinished, tint: Duo.danger) { showResign = true }
            if session.game.isFinished {
                actionButton("arrow.counterclockwise", L10n.t("game.rematch"), enabled: true, tint: Duo.mint) { startRematch() }
            }
            HStack(spacing: 2) {
                Button { session.step(-1) } label: { Image(systemName: "chevron.left") }.buttonStyle(DuoIconButtonStyle()).disabled(session.game.history.isEmpty).accessibilityIdentifier("nav.back")
                Button { session.step(1) } label: { Image(systemName: "chevron.right") }.buttonStyle(DuoIconButtonStyle()).disabled(!session.isViewingHistory).accessibilityIdentifier("nav.forward")
            }
        }
    }

    private func actionButton(_ icon: String, _ title: String, enabled: Bool, tint: Color = .primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold))
                Text(title).font(.system(size: 9, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(enabled ? tint : Color.secondary.opacity(0.5))
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Duo.card(scheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Duo.cardStroke(scheme), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityIdentifier("action.\(icon)")
    }

    private var pausedOverlay: some View {
        VStack(spacing: 14) {
            Image(systemName: "pause.circle.fill").font(.system(size: 54)).foregroundStyle(Duo.accent)
            Text(L10n.t("game.paused")).font(.title2.weight(.bold))
            Button(L10n.t("game.resumeClock")) { session.togglePause() }.buttonStyle(DuoPrimaryButtonStyle()).frame(width: 200)
        }
        .padding(30)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(radius: 20)
    }
}
