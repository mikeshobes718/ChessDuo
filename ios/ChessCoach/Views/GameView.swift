// Waiting room matched to Paired invite https://mobbin.com/screens/00e77caa-2489-411a-b392-51d307797c19
// Live board chrome matched to Duolingo Chess https://mobbin.com/screens/0c9656e8-e6f0-4372-bf78-6e0cbe3e3c9d
// Versus rail also follows theScore scoreboard https://mobbin.com/screens/d81ed8cb-a7fe-4990-89af-4515bb04dfef

import SwiftUI

struct GameView: View {
    @EnvironmentObject private var model: GameViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @AppStorage("boardTheme") private var boardThemeRaw = BoardTheme.classic.rawValue
    @AppStorage("customLightHex") private var customLightHex = "EDE3C7"
    @AppStorage("customDarkHex") private var customDarkHex = "73915E"
    @State private var showingResignConfirmation = false
    @State private var showingPlayForMeConfirmation = false
    @State private var showingDrawConfirmation = false
    @State private var showingUndoConfirmation = false
    @State private var showingSettings = false

    private var boardTheme: BoardTheme {
        BoardTheme(rawValue: boardThemeRaw) ?? .classic
    }

    private var customColors: BoardCustomColors {
        BoardCustomColors(
            light: Color(hexRGB: customLightHex) ?? BoardCustomColors.default.light,
            dark: Color(hexRGB: customDarkHex) ?? BoardCustomColors.default.dark
        )
    }

    private var isWaitingForPartner: Bool {
        model.game.status.lowercased() == "waiting"
    }

    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DuoBackground()

                Group {
                    if isWaitingForPartner {
                        waitingRoom
                    } else {
                        activeGame
                    }
                }
            }
            .navigationTitle(
                isWaitingForPartner
                    ? L10n.t(.yourRoom)
                    : L10n.t(.roomPrefix, model.game.roomCode)
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(DuoAccent.ink)
                    }
                    .accessibilityLabel(L10n.t(.settings))
                    if !isWaitingForPartner {
                        Button {
                            model.showLegend = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(DuoAccent.ink)
                        }
                        .accessibilityLabel(L10n.t(.pieceGuide))
                    }
                    ShareLink(item: model.shareRoomText()) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(DuoAccent.ink)
                    }
                    .accessibilityLabel(L10n.t(.shareRoom))
                    Button(L10n.t(.leave)) { model.leaveGame() }
                        .foregroundStyle(DuoAccent.ink)
                        .accessibilityHint(L10n.t(.leave))
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(model)
            }
            .overlay(alignment: .top) {
                if let toast = model.toastMessage {
                    DuoToastBanner(text: toast)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: model.toastMessage)
            .overlay(alignment: .top) {
                if let alert = model.turnAlert {
                    DuoTurnBanner(
                        title: alert.title,
                        detail: alert.detail,
                        onTap: { model.dismissTurnAlert() }
                    )
                    .padding(.horizontal, DuoSpace.screen)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: model.turnAlert)
            .overlay {
                if model.isSubmittingMove {
                    ZStack {
                        Color.black.opacity(0.14).ignoresSafeArea()
                        DuoLoadingCard(text: L10n.t(.sendingMove))
                    }
                }
            }
            .alert(L10n.t(.resignConfirmTitle), isPresented: $showingResignConfirmation) {
                Button(L10n.t(.cancel), role: .cancel) {}
                Button(L10n.t(.resign), role: .destructive) {
                    Task { await model.resign() }
                }
            } message: {
                Text(L10n.t(.resignConfirmMessage))
            }
            .alert(L10n.t(.playTurnConfirmTitle), isPresented: $showingPlayForMeConfirmation) {
                Button(L10n.t(.cancel), role: .cancel) {}
                Button(L10n.t(.playForMe)) {
                    Task { await model.playForMe() }
                }
            } message: {
                Text(L10n.t(.playTurnConfirmMessage))
            }
            .alert(L10n.t(.offerDrawConfirmTitle), isPresented: $showingDrawConfirmation) {
                Button(L10n.t(.cancel), role: .cancel) {}
                Button(L10n.t(.offerDraw)) {
                    Task { await model.offerDraw() }
                }
            } message: {
                Text(L10n.t(.offerDrawConfirmMessage))
            }
            .alert(L10n.t(.offerUndoConfirmTitle), isPresented: $showingUndoConfirmation) {
                Button(L10n.t(.cancel), role: .cancel) {}
                Button(L10n.t(.offerUndo)) {
                    Task { await model.offerUndo() }
                }
            } message: {
                Text(L10n.t(.offerUndoConfirmMessage))
            }
            .alert(
                L10n.t(.gameUpdate),
                isPresented: Binding(
                    get: {
                        model.errorMessage != nil &&
                        model.errorMessage != "Connection lost. Reconnecting…"
                    },
                    set: { if !$0 { model.clearError() } }
                )
            ) {
                Button(L10n.t(.ok)) { model.clearError() }
            } message: {
                Text(model.errorMessage ?? "")
            }
            .sheet(isPresented: $model.showLegend) {
                PieceLegendSheet()
            }
            .sheet(isPresented: $model.showCoachHistory) {
                CoachHistorySheet()
                    .environmentObject(model)
            }
            .sheet(isPresented: $model.showMatchReview) {
                if let review = model.game.review {
                    MatchReviewView(
                        resultText: {
                            let text = model.game.result?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            return text.isEmpty ? "Game over" : text
                        }(),
                        review: review,
                        onRematch: model.session?.color == .spectator
                            ? nil
                            : {
                                Task { await model.rematch() }
                            }
                    )
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    model.clearBadge()
                    model.startPolling()
                } else {
                    model.stopPolling()
                }
            }
            .sheet(item: $model.pendingPromotion) { promotion in
                PromotionPickerSheet { piece in
                    model.choosePromotion(piece)
                }
                .presentationDetents([.height(360)])
            }
        }
    }

    private var waitingRoom: some View {
        ScrollView {
            VStack(spacing: 22) {
                if model.isReconnecting {
                    reconnectBanner
                }

                VStack(spacing: 8) {
                    Text(L10n.t(.roomCreated))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(DuoAccent.ink)
                    Text(L10n.t(.sendCodePartner))
                        .font(.body)
                        .foregroundStyle(DuoAccent.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 14) {
                    Text(L10n.t(.roomCode))
                        .font(.headline)
                        .foregroundStyle(DuoAccent.ink)
                    HStack {
                        Text(L10n.t(.copyCode))
                            .font(.subheadline)
                            .foregroundStyle(DuoAccent.muted)
                        Spacer()
                        Button {
                            model.copyRoomCode()
                        } label: {
                            Label(L10n.t(.copyRoomCode), systemImage: "doc.on.doc")
                                .font(.caption.weight(.bold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(DuoAccent.ink)
                    }
                    DuoCodeBoxes(code: model.game.roomCode, boxCount: max(6, model.game.roomCode.count))

                    Button {
                        model.copyRoomCode()
                    } label: {
                        Label(L10n.t(.copyRoomCode), systemImage: "doc.on.doc.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .duoPrimaryButton()

                    ShareLink(item: model.shareRoomText()) {
                        Label(L10n.t(.shareToMessages), systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .duoSecondaryButton()
                }
                .padding(20)
                .duoTintedCard(wash: DuoAccent.lavenderWash)

                VStack(spacing: 8) {
                    ProgressView()
                    Text(L10n.t(.waitingPartner))
                        .font(.headline)
                    Text(L10n.t(.waitingPartnerDetail, model.game.roomCode))
                        .font(.footnote)
                        .foregroundStyle(DuoAccent.muted)
                        .multilineTextAlignment(.center)
                    NudgeActionLink(controller: model.nudge) {
                        Task { await model.sendNudge() }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .duoCard(radius: 18)

                Text(L10n.t(.assistsStayOff))
                    .font(.caption)
                    .foregroundStyle(DuoAccent.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Button {
                    showingSettings = true
                } label: {
                    Label(L10n.t(.settings), systemImage: "gearshape")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DuoAccent.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DuoSpace.screen)
            .padding(.bottom, 24)
            .duoReadableWidth()
        }
    }

    private var activeGame: some View {
        VStack(spacing: 8) {
            if model.isReconnecting {
                reconnectBanner
            }

            if !isLandscape {
                turnPill
                    .padding(.horizontal, DuoSpace.screen)
                    .padding(.top, 6)
            }

            if model.drama.level != .calm, model.drama.headline != nil {
                dramaBanner
            }

            if isLandscape {
                HStack(alignment: .top, spacing: 14) {
                    boardColumn
                    sideColumn
                        .frame(maxWidth: 340)
                }
                .padding(.horizontal, 12)
            } else {
                ScrollView {
                    boardColumn
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
                coachDock
            }
        }
    }

    private var boardColumn: some View {
        VStack(spacing: 12) {
            if isLandscape {
                turnPill
            }
            versusRail
            capturedRow

            ChessBoardView(
                fen: model.game.fen,
                orientation: model.boardOrientation,
                selectedSquare: model.selectedSquare,
                legalDestinations: model.legalDestinations,
                lastMove: model.game.lastMove,
                suggestedHint: model.boardSuggestedHint,
                threatenedSquares: Set(model.game.threatenedSquares),
                drama: model.drama,
                isEnabled: model.canMove,
                boardTheme: boardTheme,
                customColors: customColors,
                onSelect: model.select
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(8)
            .duoCard(radius: 22)

            Text(model.game.goalText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DuoAccent.muted)
                .multilineTextAlignment(.center)

            if !isLandscape {
                metaRow
                quizBlock
                actionButtons
            }
        }
    }

    private var sideColumn: some View {
        ScrollView {
            VStack(spacing: 12) {
                metaRow
                quizBlock
                actionButtons
                coachDock
            }
        }
    }

    private var turnPill: some View {
        VStack(spacing: 7) {
            Text(model.turnBanner)
                .font(.subheadline.weight(.bold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .padding(.horizontal, 14)
                .background {
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule(style: .continuous)
                                .fill(DuoAccent.base.opacity(model.canMove ? 0.14 : 0.04))
                        }
                }
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(model.canMove ? DuoAccent.base.opacity(0.34) : Color.white.opacity(0.22), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.07), radius: 8, y: 3)
            NudgeActionLink(controller: model.nudge) {
                Task { await model.sendNudge() }
            }
        }
    }

    @ViewBuilder
    private var coachDock: some View {
        if model.moveGuideEnabled {
            if model.coachCollapsed {
                collapsedCoachPill
            } else {
                CoachCard(
                    message: model.displayedCoachMessage,
                    source: model.privateHintMessage == nil ? model.game.coachSource : "ai",
                    onHistory: { model.showCoachHistory = true },
                    onMinimize: { model.setCoachCollapsed(true) }
                )
                .padding(.horizontal, isLandscape ? 0 : 12)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var collapsedCoachPill: some View {
        Button {
            model.setCoachCollapsed(false)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.footnote)
                    .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.18))
                Text(L10n.t(.moveGuide))
                    .font(.footnote.weight(.bold))
                Image(systemName: "chevron.up")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 0.7))
            .shadow(color: Color.black.opacity(0.10), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, isLandscape ? 0 : 12)
        .padding(.bottom, 8)
    }

    private var reconnectBanner: some View {
        Label(L10n.t(.connectionLost), systemImage: "wifi.exclamationmark")
            .font(.footnote.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.orange)
    }

    private var dramaBanner: some View {
        let drama = model.drama
        return VStack(spacing: 8) {
            if let chip = drama.subjectChip {
                Text(chip)
                    .font(.caption.weight(.heavy))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.22), in: Capsule())
            }
            Text(drama.headline ?? "")
                .font(.subheadline.weight(.bold))
            if let detail = drama.detail {
                Text(detail)
                    .font(.caption)
                    .opacity(0.95)
            }
            if drama.aboutYou == true, drama.level == .check || drama.level == .critical || drama.level == .pressure {
                Text(L10n.t(.dramaAboutYou))
                    .font(.caption2.weight(.semibold))
                    .opacity(0.9)
            } else if drama.aboutYou == false, let name = drama.focusName {
                Text(L10n.t(.dramaAboutThem, name))
                    .font(.caption2.weight(.semibold))
                    .opacity(0.9)
            }
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            LinearGradient(
                colors: [dramaBannerColor(drama), dramaBannerColor(drama).opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .shadow(color: dramaBannerColor(drama).opacity(0.32), radius: 14, y: 7)
        .padding(.horizontal, DuoSpace.screen)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: drama.level)
    }

    private func dramaBannerColor(_ drama: GameDrama) -> Color {
        if drama.aboutYou == false, drama.level == .check || drama.level == .critical || drama.level == .pressure {
            switch drama.level {
            case .pressure: return Color.orange.opacity(0.85)
            case .check: return Color(red: 0.85, green: 0.35, blue: 0.15)
            case .critical: return Color(red: 0.80, green: 0.25, blue: 0.20)
            default: break
            }
        }
        switch drama.level {
        case .pressure: return Color.orange.opacity(0.92)
        case .check: return Color.red.opacity(0.88)
        case .critical, .finishedLoss: return Color.red
        case .finishedWin: return Color(red: 0.20, green: 0.72, blue: 0.40)
        case .calm: return Color.gray
        }
    }

    private var versusRail: some View {
        HStack(spacing: 0) {
            playerChip(
                name: model.game.whiteName,
                side: .white,
                systemImage: "circle"
            )
            VStack(spacing: 4) {
                Text(model.game.roomCode)
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .textSelection(.enabled)
                HStack(spacing: 10) {
                    Button {
                        model.copyRoomCode()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .accessibilityLabel(L10n.t(.copyCode))
                    Button {
                        model.boardFlipped.toggle()
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .accessibilityLabel(model.boardFlipped ? L10n.t(.unflipBoard) : L10n.t(.flipBoard))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(DuoAccent.ink)
            }
            .frame(minWidth: 72)
            playerChip(
                name: model.game.blackName,
                side: .black,
                systemImage: "circle.fill"
            )
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.24), lineWidth: 0.7))
    }

    private func playerChip(name: String, side: PlayerColor, systemImage: String) -> some View {
        let focused = model.drama.focusSide == side && model.drama.level != .calm
        let isYou = model.session?.color == side
        let tint = side == .white ? DuoAccent.base : DuoAccent.rose
        return VStack(alignment: .center, spacing: 2) {
            Label(name, systemImage: systemImage)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .font(.subheadline.weight(.semibold))
            if focused {
                Text(isYou ? L10n.t(.dramaYouInTrouble) : L10n.t(.dramaInTrouble))
                    .font(.caption2.weight(.heavy))
            } else if isYou {
                Text(L10n.t(.youLabel))
                    .font(.caption2.weight(.semibold))
                    .opacity(0.8)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            focused
                ? dramaBannerColor(model.drama).opacity(0.95)
                : tint.opacity(0.12),
            in: Capsule(style: .continuous)
        )
        .foregroundStyle(focused ? Color.white : Color.primary)
    }

    private var capturedRow: some View {
        HStack {
            Text(L10n.t(.takenBy, model.game.whiteName, glyphs(model.game.captured.blackTaken)))
                .font(.caption)
            Spacer()
            Text(L10n.t(.takenBy, model.game.blackName, glyphs(model.game.captured.whiteTaken)))
                .font(.caption)
        }
        .foregroundStyle(DuoAccent.muted)
        .padding(.horizontal, 4)
    }

    private var metaRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let selected = model.selectedSquareLabel {
                Text(L10n.t(.selectedSquare, selected))
                    .font(.subheadline.weight(.semibold))
            }
            if let last = model.lastMoveLabel {
                Text(last)
                    .font(.subheadline)
                    .foregroundStyle(DuoAccent.muted)
            }
            if let session = model.session {
                Text(session.color == .spectator
                    ? L10n.t(.spectating)
                    : (session.color == .white ? L10n.t(.youPlayWhite) : L10n.t(.youPlayBlack)))
                    .font(.subheadline.weight(.medium))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var quizBlock: some View {
        if model.shouldShowQuiz,
           let quiz = model.game.quiz,
           let question = quiz.question,
           let options = quiz.options,
           !options.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(question)
                    .font(.subheadline.weight(.semibold))
                if model.quizFeedback == nil {
                    HStack(spacing: 10) {
                        ForEach(options) { option in
                            Button(option.label) {
                                model.answerQuiz(option)
                            }
                            .frame(maxWidth: .infinity)
                            .duoSecondaryButton()
                        }
                    }
                }
                if let feedback = model.quizFeedback {
                    Text(feedback)
                        .font(.caption)
                        .foregroundStyle(DuoAccent.muted)
                }
            }
            .padding(14)
            .duoCard(radius: 18)
        }
    }

    @ViewBuilder
    private var offerBanners: some View {
        if let session = model.session, session.color != .spectator, !model.game.isFinished {
            if let offer = model.game.drawOfferBy {
                if offer == session.color {
                    Text(L10n.t(.drawOfferedByYou))
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .duoCard(radius: 16)
                } else {
                    VStack(spacing: 10) {
                        Text(L10n.t(.drawOfferedByThem, offer == .white ? model.game.whiteName : model.game.blackName))
                            .font(.footnote.weight(.semibold))
                        HStack(spacing: 10) {
                            Button(L10n.t(.acceptDraw)) {
                                Task { await model.respondDraw(accept: true) }
                            }
                            .frame(maxWidth: .infinity)
                            .duoPrimaryButton()
                            Button(L10n.t(.declineDraw), role: .destructive) {
                                Task { await model.respondDraw(accept: false) }
                            }
                            .frame(maxWidth: .infinity)
                            .duoSecondaryButton()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .duoCard(radius: 16)
                }
            }

            if let offer = model.game.undoOfferBy {
                if offer == session.color {
                    Text(L10n.t(.undoOfferedByYou))
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .duoCard(radius: 16)
                } else {
                    VStack(spacing: 10) {
                        Text(L10n.t(.undoOfferedByThem, offer == .white ? model.game.whiteName : model.game.blackName))
                            .font(.footnote.weight(.semibold))
                        HStack(spacing: 10) {
                            Button(L10n.t(.acceptUndo)) {
                                Task { await model.respondUndo(accept: true) }
                            }
                            .frame(maxWidth: .infinity)
                            .duoPrimaryButton()
                            Button(L10n.t(.declineUndo), role: .destructive) {
                                Task { await model.respondUndo(accept: false) }
                            }
                            .frame(maxWidth: .infinity)
                            .duoSecondaryButton()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .duoCard(radius: 16)
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            offerBanners

            if model.playForMeEnabled {
                Button {
                    showingPlayForMeConfirmation = true
                } label: {
                    Label(L10n.t(.playTurnForMe, model.computerDifficulty.title), systemImage: "cpu")
                        .frame(maxWidth: .infinity)
                }
                .duoPrimaryButton()
                .disabled(
                    model.isLoading ||
                    model.isSubmittingMove ||
                    model.game.isFinished ||
                    !model.canMove ||
                    model.session?.color == .spectator
                )
            }

            HStack(spacing: 10) {
                if model.hintsEnabled {
                    Button {
                        Task { await model.requestHint() }
                    } label: {
                        Label(L10n.t(.hint), systemImage: "lightbulb")
                            .frame(maxWidth: .infinity)
                    }
                    .duoSecondaryButton()
                    .disabled(model.isLoading || model.game.isFinished || !model.canMove || model.session?.color == .spectator)
                }

                Button {
                    showingDrawConfirmation = true
                } label: {
                    Label(L10n.t(.offerDraw), systemImage: "equal.circle")
                        .frame(maxWidth: .infinity)
                }
                .duoSecondaryButton()
                .disabled(
                    model.isLoading ||
                    model.game.isFinished ||
                    model.session?.color == .spectator ||
                    model.game.drawOfferBy == model.session?.color
                )
            }

            HStack(spacing: 10) {
                Button {
                    showingUndoConfirmation = true
                } label: {
                    Label(L10n.t(.offerUndo), systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .duoSecondaryButton()
                .disabled(
                    model.isLoading ||
                    model.game.isFinished ||
                    model.game.moveCount < 1 ||
                    model.session?.color == .spectator ||
                    model.game.undoOfferBy == model.session?.color
                )

                Button(role: .destructive) {
                    showingResignConfirmation = true
                } label: {
                    Label(L10n.t(.resign), systemImage: "flag")
                        .frame(maxWidth: .infinity)
                }
                .duoSecondaryButton()
                .disabled(model.isLoading || model.game.isFinished || model.session?.color == .spectator)
            }

            if model.game.isFinished {
                if model.game.review != nil {
                    Button {
                        model.showMatchReview = true
                    } label: {
                        Label(L10n.t(.matchReview), systemImage: "chart.bar")
                            .frame(maxWidth: .infinity)
                    }
                    .duoSecondaryButton()
                }

                if model.session?.color != .spectator {
                    Button {
                        Task { await model.rematch() }
                    } label: {
                        Label(L10n.t(.rematch), systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .duoPrimaryButton()
                    .disabled(model.isLoading)
                }
            }
        }
    }

    private func glyphs(_ symbols: [String]?) -> String {
        guard let symbols, !symbols.isEmpty else { return "-" }
        return symbols.compactMap { symbol in
            guard let character = symbol.first else { return nil }
            return ChessPiece(symbol: character).glyph
        }.joined(separator: " ")
    }
}

// Promotion picker matched to F1 Select Chips https://mobbin.com/screens/db776c5c-67fd-4664-a3d1-d522cd23496e
struct PromotionPickerSheet: View {
    let onChoose: (String) -> Void

    private let options: [(piece: String, glyph: Character, name: String, wash: Color)] = [
        ("q", "♛", "Queen", DuoAccent.lavenderWash),
        ("r", "♜", "Rook", Color(red: 0.90, green: 0.93, blue: 0.98)),
        ("b", "♝", "Bishop", DuoAccent.coralWash),
        ("n", "♞", "Knight", Color(red: 0.90, green: 0.96, blue: 0.90)),
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text("Promote your pawn")
                .font(.title3.weight(.bold))
                .foregroundStyle(DuoAccent.ink)
            Text("Pick the piece your pawn becomes.")
                .font(.footnote)
                .foregroundStyle(DuoAccent.muted)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(options, id: \.piece) { option in
                    Button {
                        onChoose(option.piece)
                    } label: {
                        VStack(spacing: 8) {
                            Text(String(option.glyph))
                                .font(.system(size: 40))
                            Text(option.name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(DuoAccent.ink)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(option.wash, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Promote to \(option.name)")
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
    }
}

private struct CoachHistorySheet: View {
    @EnvironmentObject private var model: GameViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                DuoBackground()
                if model.game.coachHistory.isEmpty {
                    DuoEmptyState(
                        systemImage: "clock.arrow.circlepath",
                        title: L10n.t(.coachHistory),
                        detail: L10n.t(.moveGuideDetail)
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(model.game.coachHistory.reversed()) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.source.uppercased())
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(DuoAccent.ink)
                                        .tracking(0.8)
                                    Text(item.text)
                                        .font(.subheadline)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .duoCard(radius: 16)
                            }
                        }
                        .padding(DuoSpace.screen)
                    }
                }
            }
            .navigationTitle(L10n.t(.coachHistory))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t(.done)) { model.showCoachHistory = false }
                }
            }
        }
    }
}
