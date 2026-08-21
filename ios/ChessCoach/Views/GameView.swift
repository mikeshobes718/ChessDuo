import SwiftUI

struct GameView: View {
    @EnvironmentObject private var model: GameViewModel
    @Environment(\.scenePhase) private var scenePhase
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
                    }
                    .accessibilityLabel(L10n.t(.settings))
                    if !isWaitingForPartner {
                        Button {
                            model.showLegend = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                        }
                        .accessibilityLabel(L10n.t(.pieceGuide))
                    }
                    ShareLink(item: model.shareRoomText()) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel(L10n.t(.shareRoom))
                    Button(L10n.t(.leave)) { model.leaveGame() }
                        .accessibilityHint(L10n.t(.leave))
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(model)
            }
            .overlay(alignment: .top) {
                if let toast = model.toastMessage {
                    Text(toast)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.primary.opacity(0.08)))
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: model.toastMessage)
            .overlay {
                if model.isSubmittingMove {
                    ZStack {
                        Color.black.opacity(0.14).ignoresSafeArea()
                        ProgressView(L10n.t(.sendingMove))
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                NavigationStack {
                    ZStack {
                        DuoBackground()
                        List(model.game.coachHistory.reversed()) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.source.uppercased())
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)
                                Text(item.text)
                            }
                            .padding(.vertical, 4)
                        }
                        .scrollContentBackground(.hidden)
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
                .presentationDetents([.height(320)])
            }
        }
    }

    private var waitingRoom: some View {
        VStack(spacing: 22) {
            if model.isReconnecting {
                reconnectBanner
            }

            Spacer(minLength: 8)

            VStack(spacing: 10) {
                Text(L10n.t(.roomCreated))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(L10n.t(.sendCodePartner))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Text(model.game.roomCode)
                .font(.system(size: 46, weight: .bold, design: .monospaced))
                .tracking(6)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .duoCard(radius: 26)
                .shadow(color: DuoAccent.base.opacity(0.22), radius: 22, y: 10)
                .padding(.horizontal, 24)
                .accessibilityLabel("Room code \(model.game.roomCode)")

            VStack(spacing: 12) {
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
            .padding(.horizontal, 24)

            VStack(spacing: 8) {
                ProgressView()
                Text(L10n.t(.waitingPartner))
                    .font(.headline)
                Text(L10n.t(.waitingPartnerDetail, model.game.roomCode))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .padding(.top, 10)

            Text(L10n.t(.assistsStayOff))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.top, 4)

            Button {
                showingSettings = true
            } label: {
                Label(L10n.t(.settings), systemImage: "gearshape")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DuoAccent.base)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private var activeGame: some View {
        VStack(spacing: 10) {
            if model.isReconnecting {
                reconnectBanner
            }

            Text(model.turnBanner)
                .font(.subheadline.weight(.bold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(DuoAccent.base.opacity(model.canMove ? 0.14 : 0.04))
                        }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(model.canMove ? DuoAccent.base.opacity(0.35) : Color.white.opacity(0.22), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
                .padding(.horizontal, 10)
                .padding(.top, 8)

            if model.drama.level != .calm, model.drama.headline != nil {
                dramaBanner
            }

            Text(model.game.goalText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)

            ScrollView {
                VStack(spacing: 14) {
                    gameHeader
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
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(10)
                    .duoCard(radius: 26)
                    .padding(.horizontal, 6)

                    metaRow
                    quizBlock
                    actionButtons
                }
                .padding(.horizontal, 10)
            }

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
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
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
                    .foregroundStyle(.yellow)
                Text(L10n.t(.moveGuide))
                    .font(.footnote.weight(.bold))
                Image(systemName: "chevron.up")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 0.7))
            .shadow(color: Color.black.opacity(0.12), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
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
        .padding(.horizontal, 12)
        .background(
            LinearGradient(
                colors: [dramaBannerColor(drama), dramaBannerColor(drama).opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .shadow(color: dramaBannerColor(drama).opacity(0.35), radius: 16, y: 8)
        .padding(.horizontal, 10)
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

    private var gameHeader: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                playerChip(
                    name: model.game.whiteName,
                    side: .white,
                    systemImage: "circle"
                )
                Spacer(minLength: 4)
                Text(model.game.roomCode)
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                    .textSelection(.enabled)
                Spacer(minLength: 4)
                playerChip(
                    name: model.game.blackName,
                    side: .black,
                    systemImage: "circle.fill"
                )
            }
            .font(.subheadline.weight(.semibold))

            HStack {
                Button {
                    model.copyRoomCode()
                } label: {
                    Label(L10n.t(.copyCode), systemImage: "doc.on.doc")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DuoAccent.base)
                }
                Spacer()
                Button {
                    model.boardFlipped.toggle()
                } label: {
                    Label(
                        model.boardFlipped ? L10n.t(.unflipBoard) : L10n.t(.flipBoard),
                        systemImage: "arrow.up.arrow.down"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DuoAccent.base)
                }
            }
        }
        .padding(12)
        .duoCard(radius: 18)
    }

    private func playerChip(name: String, side: PlayerColor, systemImage: String) -> some View {
        let focused = model.drama.focusSide == side && model.drama.level != .calm
        let isYou = model.session?.color == side
        return VStack(alignment: side == .white ? .leading : .trailing, spacing: 2) {
            HStack(spacing: 4) {
                if side == .black { Spacer(minLength: 0) }
                Label(name, systemImage: systemImage)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if side == .white { Spacer(minLength: 0) }
            }
            if focused {
                Text(isYou ? L10n.t(.dramaYouInTrouble) : L10n.t(.dramaInTrouble))
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.white)
            } else if isYou {
                Text(L10n.t(.youLabel))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            focused
                ? dramaBannerColor(model.drama).opacity(0.95)
                : Color(.systemBackground),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(focused ? Color.white.opacity(0.2) : Color.primary.opacity(0.06), lineWidth: 1)
        )
        .foregroundStyle(focused ? Color.white : Color.primary)
        .frame(maxWidth: 150)
    }

    private var capturedRow: some View {
        HStack {
            Text(L10n.t(.takenBy, model.game.whiteName, glyphs(model.game.captured.blackTaken)))
                .font(.caption)
            Spacer()
            Text(L10n.t(.takenBy, model.game.blackName, glyphs(model.game.captured.whiteTaken)))
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 2)
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
                    .foregroundStyle(.secondary)
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
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .duoCard(radius: 16)
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
                        .padding(12)
                        .duoCard(radius: 14)
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
                    .padding(12)
                    .duoCard(radius: 14)
                }
            }

            if let offer = model.game.undoOfferBy {
                if offer == session.color {
                    Text(L10n.t(.undoOfferedByYou))
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .duoCard(radius: 14)
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
                    .padding(12)
                    .duoCard(radius: 14)
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
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

            HStack(spacing: 12) {
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

            HStack(spacing: 12) {
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
        guard let symbols, !symbols.isEmpty else { return "—" }
        return symbols.compactMap { symbol in
            guard let character = symbol.first else { return nil }
            return ChessPiece(symbol: character).glyph
        }.joined(separator: " ")
    }
}

struct PromotionPickerSheet: View {
    let onChoose: (String) -> Void

    private let options: [(piece: String, glyph: Character, name: String)] = [
        ("q", "♛", "Queen"),
        ("r", "♜", "Rook"),
        ("b", "♝", "Bishop"),
        ("n", "♞", "Knight"),
    ]

    var body: some View {
        VStack(spacing: 18) {
            Text("Promote your pawn")
                .font(.headline)
            Text("Pick the piece your pawn becomes.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 14) {
                ForEach(options, id: \.piece) { option in
                    Button {
                        onChoose(option.piece)
                    } label: {
                        VStack(spacing: 6) {
                            Text(String(option.glyph))
                                .font(.system(size: 44))
                            Text(option.name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Promote to \(option.name)")
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }
}
