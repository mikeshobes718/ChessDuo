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
            Group {
                if isWaitingForPartner {
                    waitingRoom
                } else {
                    activeGame
                }
            }
            .navigationTitle(
                isWaitingForPartner
                    ? L10n.t(.yourRoom)
                    : L10n.t(.roomPrefix, model.game.roomCode)
            )
            .navigationBarTitleDisplayMode(.inline)
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
                        .background(.regularMaterial, in: Capsule())
                        .padding(.top, 8)
                }
            }
            .overlay {
                if model.isSubmittingMove {
                    ProgressView(L10n.t(.sendingMove))
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
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
                    List(model.game.coachHistory.reversed()) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.source.uppercased())
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                            Text(item.text)
                        }
                        .padding(.vertical, 4)
                    }
                    .navigationTitle(L10n.t(.coachHistory))
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
                    model.startPolling()
                } else {
                    model.stopPolling()
                }
            }
        }
    }

    private var waitingRoom: some View {
        VStack(spacing: 20) {
            if model.isReconnecting {
                reconnectBanner
            }

            Spacer(minLength: 12)

            VStack(spacing: 10) {
                Text(L10n.t(.roomCreated))
                    .font(.title2.bold())
                Text(L10n.t(.sendCodePartner))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Text(model.game.roomCode)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .tracking(4)
                .padding(.vertical, 8)
                .accessibilityLabel("Room code \(model.game.roomCode)")

            VStack(spacing: 12) {
                Button {
                    model.copyRoomCode()
                } label: {
                    Label(L10n.t(.copyRoomCode), systemImage: "doc.on.doc.fill")
                        .frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(.borderedProminent)

                ShareLink(item: model.shareRoomText()) {
                    Label(L10n.t(.shareToMessages), systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(.bordered)
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
            .padding(.top, 12)

            Text(L10n.t(.assistsStayOff))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.top, 8)

            Spacer()
        }
    }

    private var activeGame: some View {
        VStack(spacing: 10) {
            if model.isReconnecting {
                reconnectBanner
            }

            Text(model.turnBanner)
                .font(.headline.weight(.bold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    model.canMove ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .padding(.horizontal, 8)

            if model.drama.level != .calm, model.drama.headline != nil {
                dramaBanner
            }

            Text(model.game.goalText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)

            ScrollView {
                VStack(spacing: 12) {
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
                    .padding(.horizontal, 4)

                    metaRow
                    quizBlock
                    actionButtons
                }
                .padding(.horizontal, 8)
            }

            if model.moveGuideEnabled {
                CoachCard(
                    message: model.displayedCoachMessage,
                    source: model.privateHintMessage == nil ? model.game.coachSource : "ai",
                    onHistory: { model.showCoachHistory = true }
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
        }
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
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(dramaBannerColor(drama), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: drama.level)
    }

    private func dramaBannerColor(_ drama: GameDrama) -> Color {
        if drama.aboutYou == false, drama.level == .check || drama.level == .critical || drama.level == .pressure {
            // Partner is in trouble — warmer / less "you are dying" red.
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
        case .finishedWin: return Color.green.opacity(0.9)
        case .calm: return Color.gray
        }
    }

    private var gameHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
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
                }
                Spacer()
                Button {
                    model.boardFlipped.toggle()
                } label: {
                    Label(
                        model.boardFlipped ? L10n.t(.unflipBoard) : L10n.t(.flipBoard),
                        systemImage: "arrow.up.arrow.down"
                    )
                }
            }
            .font(.caption.weight(.semibold))
        }
        .padding(.top, 4)
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
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            focused
                ? dramaBannerColor(model.drama).opacity(0.95)
                : Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 10)
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
            VStack(alignment: .leading, spacing: 8) {
                Text(question)
                    .font(.subheadline.weight(.semibold))
                if model.quizFeedback == nil {
                    HStack {
                        ForEach(options) { option in
                            Button(option.label) {
                                model.answerQuiz(option)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                if let feedback = model.quizFeedback {
                    Text(feedback)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
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
                        .padding(10)
                        .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                } else {
                    VStack(spacing: 8) {
                        Text(L10n.t(.drawOfferedByThem, offer == .white ? model.game.whiteName : model.game.blackName))
                            .font(.footnote.weight(.semibold))
                        HStack {
                            Button(L10n.t(.acceptDraw)) {
                                Task { await model.respondDraw(accept: true) }
                            }
                            .buttonStyle(.borderedProminent)
                            Button(L10n.t(.declineDraw), role: .destructive) {
                                Task { await model.respondDraw(accept: false) }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
                }
            }

            if let offer = model.game.undoOfferBy {
                if offer == session.color {
                    Text(L10n.t(.undoOfferedByYou))
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                } else {
                    VStack(spacing: 8) {
                        Text(L10n.t(.undoOfferedByThem, offer == .white ? model.game.whiteName : model.game.blackName))
                            .font(.footnote.weight(.semibold))
                        HStack {
                            Button(L10n.t(.acceptUndo)) {
                                Task { await model.respondUndo(accept: true) }
                            }
                            .buttonStyle(.borderedProminent)
                            Button(L10n.t(.declineUndo), role: .destructive) {
                                Task { await model.respondUndo(accept: false) }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
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
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
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
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isLoading || model.game.isFinished || !model.canMove || model.session?.color == .spectator)
                }

                Button {
                    showingDrawConfirmation = true
                } label: {
                    Label(L10n.t(.offerDraw), systemImage: "equal.circle")
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.bordered)
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
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.bordered)
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
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.bordered)
                .disabled(model.isLoading || model.game.isFinished || model.session?.color == .spectator)
            }

            if model.game.isFinished {
                if model.game.review != nil {
                    Button {
                        model.showMatchReview = true
                    } label: {
                        Label(L10n.t(.matchReview), systemImage: "chart.bar")
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.bordered)
                }

                if model.session?.color != .spectator {
                    Button {
                        Task { await model.rematch() }
                    } label: {
                        Label(L10n.t(.rematch), systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
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
