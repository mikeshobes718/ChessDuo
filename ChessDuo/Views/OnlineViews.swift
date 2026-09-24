import SwiftUI

struct OnlineLobbyView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var scheme
    var prefillCode: String?
    let onSession: (OnlineSession) -> Void
    let onClose: () -> Void

    @State private var name = ""
    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var recentCodes: [String] = UserDefaults.standard.stringArray(forKey: "online.recentCodes") ?? []
    @FocusState private var codeFocused: Bool
    private let api = OnlineAPI()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.t("lobby.yourName")).font(.headline)
                        TextField(L10n.t("lobby.namePlaceholder"), text: $name)
                            .textInputAutocapitalization(.words)
                            .padding(12)
                            .background(Duo.card(scheme), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Duo.cardStroke(scheme)))
                    }
                    .duoCard()

                    VStack(alignment: .leading, spacing: 10) {
                        Label(L10n.t("lobby.create"), systemImage: "plus.circle.fill").font(.headline)
                        Text(L10n.t("lobby.create.sub")).font(.subheadline).foregroundStyle(Duo.secondaryText(scheme))
                        Button { Task { await create() } } label: {
                            if isLoading { ProgressView().tint(.white) } else { Text(L10n.t("lobby.create")) }
                        }
                        .buttonStyle(DuoPrimaryButtonStyle())
                        .disabled(isLoading)
                    }
                    .duoCard()

                    VStack(alignment: .leading, spacing: 10) {
                        Label(L10n.t("lobby.join"), systemImage: "arrow.right.circle.fill").font(.headline)
                        TextField(L10n.t("lobby.code"), text: $code)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(.title2, design: .monospaced).weight(.bold))
                            .multilineTextAlignment(.center)
                            .focused($codeFocused)
                            .padding(12)
                            .background(Duo.card(scheme), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Duo.cardStroke(scheme)))
                            .onChange(of: code) { _, v in
                                let cleaned = String(v.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(8))
                                if cleaned != v { code = cleaned }
                            }
                        HStack(spacing: 10) {
                            Button(L10n.t("lobby.joinButton")) { Task { await join() } }.buttonStyle(DuoPrimaryButtonStyle(tint: Duo.teal)).disabled(isLoading)
                            Button(L10n.t("lobby.watchButton")) { Task { await spectate() } }.buttonStyle(DuoSecondaryButtonStyle()).disabled(isLoading)
                        }
                        if !recentCodes.isEmpty {
                            Text(L10n.t("lobby.recent")).font(.caption.weight(.semibold)).foregroundStyle(Duo.secondaryText(scheme))
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(recentCodes, id: \.self) { c in
                                        Button(c) { code = c }.font(.caption.monospaced().weight(.bold)).padding(.horizontal, 10).padding(.vertical, 6).background(Color.secondary.opacity(0.12), in: Capsule())
                                    }
                                }
                            }
                        }
                    }
                    .duoCard()

                    Text(L10n.t("lobby.watch.sub")).font(.caption).foregroundStyle(Duo.secondaryText(scheme))
                }
                .padding()
            }
            .duoBackground()
            .navigationTitle(L10n.t("lobby.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button { onClose() } label: { Image(systemName: "xmark") }.accessibilityIdentifier("lobby.close") } }
            .alert(L10n.t("error.title"), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button(L10n.t("ok")) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .onAppear {
                name = settings.playerName
                if let prefillCode { code = prefillCode; codeFocused = false }
            }
        }
    }

    private func validName() -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { errorMessage = L10n.t("lobby.needName"); return nil }
        settings.playerName = trimmed
        return trimmed
    }

    private func remember(_ code: String) {
        var list = recentCodes.filter { $0 != code }
        list.insert(code, at: 0)
        recentCodes = Array(list.prefix(5))
        UserDefaults.standard.set(recentCodes, forKey: "online.recentCodes")
        CloudSync.shared.localChange()
    }

    private func create() async {
        guard let n = validName() else { return }
        isLoading = true; defer { isLoading = false }
        do {
            let r = try await api.create(name: n)
            guard let room = r.roomCode, let token = r.playerToken else { errorMessage = L10n.t("error.network"); return }
            let role = OnlineRole(rawValue: r.color ?? "white") ?? .white
            let info = OnlineSessionInfo(roomCode: room, playerToken: token, role: role, playerName: n)
            remember(room)
            Feedback.shared.play(.gameStart)
            onSession(OnlineSession(info: info, initial: r))
        } catch { errorMessage = error.localizedDescription }
    }

    private func join() async {
        guard let n = validName() else { return }
        let c = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard !c.isEmpty else { errorMessage = L10n.t("lobby.needCode"); return }
        isLoading = true; defer { isLoading = false }
        do {
            let r = try await api.join(name: n, roomCode: c)
            guard let token = r.playerToken else { errorMessage = r.message ?? L10n.t("error.network"); return }
            let role = OnlineRole(rawValue: r.color ?? "black") ?? .black
            let info = OnlineSessionInfo(roomCode: r.roomCode ?? c, playerToken: token, role: role, playerName: n)
            remember(info.roomCode)
            Feedback.shared.play(.gameStart)
            onSession(OnlineSession(info: info, initial: r))
        } catch { errorMessage = error.localizedDescription }
    }

    private func spectate() async {
        let c = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard !c.isEmpty else { errorMessage = L10n.t("lobby.needCode"); return }
        isLoading = true; defer { isLoading = false }
        do {
            let r = try await api.spectate(roomCode: c)
            let info = OnlineSessionInfo(roomCode: r.roomCode ?? c, playerToken: "spectator", role: .spectator, playerName: name.isEmpty ? "Spectator" : name)
            remember(info.roomCode)
            onSession(OnlineSession(info: info, initial: r))
        } catch { errorMessage = error.localizedDescription }
    }
}

struct OnlineGameView: View {
    @ObservedObject var session: OnlineSession
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    let onClose: () -> Void

    @State private var showResign = false
    @State private var showLeave = false
    @State private var showDraw = false
    @State private var showUndo = false
    @State private var showPlayForMe = false
    @State private var showReview = false
    @State private var showCoachHistory = false
    @State private var showSettings = false
    @State private var shareItems: [Any]? = nil

    private var top: PieceColor { session.effectiveOrientation.opposite }
    private var bottom: PieceColor { session.effectiveOrientation }

    var body: some View {
        NavigationStack {
            Group {
                if session.isWaiting { waitingRoom } else { gameLayout }
            }
            .duoBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { showLeave = true } label: { Image(systemName: "xmark") }.accessibilityIdentifier("game.close") }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text(session.turnText).font(.subheadline.weight(.bold)).lineLimit(1)
                        HStack(spacing: 4) {
                            Text(session.roomCode).font(.caption2.monospaced().weight(.bold))
                            if session.isReconnecting { Image(systemName: "wifi.exclamationmark").font(.caption2).foregroundStyle(Duo.danger) }
                            if session.isSpectator { Text("· \(L10n.t("lobby.spectating"))").font(.caption2) }
                        }.foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { session.use3D.toggle() } label: { Label(session.use3D ? L10n.t("game.view2D") : L10n.t("game.view3D"), systemImage: "cube") }
                        Button { session.flip() } label: { Label(L10n.t("game.flip"), systemImage: "arrow.up.arrow.down") }
                        Button { shareItems = [session.inviteText] } label: { Label(L10n.t("lobby.share"), systemImage: "square.and.arrow.up") }
                        Button { UIPasteboard.general.string = session.roomCode; session.presentToast(L10n.t("lobby.copied"), style: .success) } label: { Label(L10n.t("lobby.copyCode"), systemImage: "doc.on.doc") }
                        Divider()
                        Button { session.refreshNow() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                        Button { showCoachHistory = true } label: { Label(L10n.t("game.coach"), systemImage: "graduationcap") }
                        Button { UIPasteboard.general.string = session.position.fen; session.presentToast(L10n.t("game.copied"), style: .success) } label: { Label(L10n.t("game.copyFEN"), systemImage: "doc.on.doc") }
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
            }
            .alert(L10n.t("game.draw.confirm"), isPresented: $showDraw) {
                Button(L10n.t("cancel"), role: .cancel) {}
                Button(L10n.t("game.draw")) { session.offerDraw() }
            }
            .alert(L10n.t("game.undo.request"), isPresented: $showUndo) {
                Button(L10n.t("cancel"), role: .cancel) {}
                Button(L10n.t("game.undo.request")) { session.offerUndo() }
            }
            .alert(L10n.t("game.playForMe.confirm"), isPresented: $showPlayForMe) {
                Button(L10n.t("cancel"), role: .cancel) {}
                Button(L10n.t("game.playForMe")) { session.playForMe() }
            } message: { Text(L10n.t("game.playForMe.msg")) }
            .sheet(item: $session.pendingPromotion) { p in PromotionSheet(color: p.color) { session.completePromotion($0) } }
            .sheet(isPresented: $session.showGameOver) {
                if let result = session.localGame.result {
                    GameOverSheet(result: result, whiteName: session.whiteName, blackName: session.blackName, me: session.myColor, moveCount: session.localGame.history.count, review: session.review, isReviewing: session.isReviewing, reviewProgress: 0,
                                  onRematch: session.isSpectator ? nil : { session.rematch() },
                                  onReview: { session.showGameOver = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showReview = true } },
                                  onShare: { session.showGameOver = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shareItems = [session.pgn()] } },
                                  onClose: { session.showGameOver = false })
                }
            }
            .sheet(isPresented: $showReview) {
                if let review = session.review {
                    ReviewView(record: GameRecord(mode: .online, whiteName: session.whiteName, blackName: session.blackName, startFEN: Position.startFEN, moves: session.localGame.history, result: session.localGame.result, startedAt: Date(), endedAt: Date(), timeControl: .none, humanColor: session.myColor, roomCode: session.roomCode), review: review)
                }
            }
            .sheet(isPresented: $showCoachHistory) { coachHistorySheet }
            .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) { if let items = shareItems { ShareSheet(items: items) } }
            .sheet(isPresented: $showSettings) { NavigationStack { SettingsView() } }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { session.resumeUpdates(); session.refreshNow() } else if phase == .background { session.pauseUpdates() }
            }
            .onChange(of: settings.moveGuide) { _, _ in session.refreshInteraction() }
            .onChange(of: settings.highlightThreats) { _, _ in session.refreshInteraction() }
        }
        .overlay(alignment: .top) {
            if let toast = session.toast { ToastView(toast: toast).padding(.top, 60).transition(.move(edge: .top).combined(with: .opacity)) }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: session.toast)
    }

    private var waitingRoom: some View {
        VStack(spacing: 22) {
            Spacer()
            ProgressView().controlSize(.large)
            Text(L10n.t("lobby.waiting")).font(.title3.weight(.bold))
            Text(session.roomCode).font(.system(size: 44, weight: .heavy, design: .monospaced)).tracking(6).padding(.horizontal, 24).padding(.vertical, 14).background(Duo.card(scheme), in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Duo.accent, lineWidth: 2))
            Text(L10n.t("lobby.waitingHint")).font(.subheadline).foregroundStyle(Duo.secondaryText(scheme)).multilineTextAlignment(.center).padding(.horizontal, 32)
            HStack(spacing: 12) {
                Button { shareItems = [session.inviteText] } label: { Label(L10n.t("lobby.share"), systemImage: "square.and.arrow.up") }.buttonStyle(DuoPrimaryButtonStyle())
                Button { UIPasteboard.general.string = session.roomCode; session.presentToast(L10n.t("lobby.copied"), style: .success) } label: { Label(L10n.t("lobby.copyCode"), systemImage: "doc.on.doc") }.buttonStyle(DuoSecondaryButtonStyle())
            }
            .padding(.horizontal, 24)
            Spacer()
            MiniBoard(fen: Position.startFEN).frame(width: 160, height: 160).opacity(0.7)
            Spacer()
            Button(L10n.t("lobby.leave"), role: .destructive) { session.leave(); onClose() }.padding(.bottom, 16)
        }
    }

    private var gameLayout: some View {
        VStack(spacing: 10) {
            playerBar(top)
            ChessBoardContainer(position: session.displayedPosition, interaction: session.interaction, use3D: session.use3D, onTap: { session.tap($0) }, onDrop: { session.drop(from: $0, to: $1) })
                .padding(.horizontal, 6)
                .overlay(alignment: .bottom) {
                    if session.viewingPly != nil {
                        Text("\(L10n.t("review.replay")) · \(session.viewingPly ?? 0)/\(session.localGame.history.count)").font(.caption.weight(.bold)).padding(.horizontal, 10).padding(.vertical, 5).background(.ultraThinMaterial, in: Capsule()).padding(8)
                    }
                }
            playerBar(bottom)
            MoveStrip(moves: session.localGame.history, viewingPly: session.viewingPly) { session.jump(toPly: $0) }.duoCard(padding: 4).padding(.horizontal, 12)
            if settings.coachCard {
                CoachCardView(text: session.coachText, hint: session.hintText) { showCoachHistory = true }.padding(.horizontal, 12)
            }
            if let quiz = session.quiz, let options = quiz.options, !options.isEmpty, session.canMove, !session.quizAnswered {
                VStack(spacing: 8) {
                    Text(quiz.question ?? "").font(.caption.weight(.semibold))
                    HStack {
                        ForEach(options) { opt in Button(opt.label) { session.answerQuiz(opt) }.buttonStyle(DuoSecondaryButtonStyle()) }
                    }
                }.duoCard(padding: 10).padding(.horizontal, 12)
            }
            if let feedback = session.quizFeedback { Text(feedback).font(.caption.weight(.bold)).foregroundStyle(Duo.mint) }
            if let by = session.drawOfferBy, by != session.myColor, !session.isSpectator {
                OfferBanner(text: L10n.t("game.draw.offered", session.name(for: by)), acceptTitle: L10n.t("game.draw.accept"), declineTitle: L10n.t("game.draw.decline"), onAccept: { session.respondDraw(accept: true) }, onDecline: { session.respondDraw(accept: false) }).padding(.horizontal, 12)
            }
            if let by = session.undoOfferBy, by != session.myColor, !session.isSpectator {
                OfferBanner(text: L10n.t("game.undo.offered", session.name(for: by)), acceptTitle: L10n.t("game.undo.accept"), declineTitle: L10n.t("game.undo.decline"), onAccept: { session.respondUndo(accept: true) }, onDecline: { session.respondUndo(accept: false) }).padding(.horizontal, 12)
            }
            Spacer(minLength: 0)
            if !session.isSpectator { actionBar.padding(.horizontal, 12).padding(.bottom, 8) }
        }
        .padding(.top, 6)
    }

    private func playerBar(_ color: PieceColor) -> some View {
        let captured = session.localGame.captured
        let diff = captured.materialDiff * (color == .white ? 1 : -1)
        return PlayerBar(name: session.name(for: color), color: color, captured: color == .white ? captured.byWhite : captured.byBlack, materialDiff: diff, isTurn: session.turn == color && !session.isFinished, isThinking: session.isSubmitting && session.turn == color)
            .padding(.horizontal, 12)
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            actionButton("arrow.uturn.backward", L10n.t("game.undo"), enabled: !session.isFinished && !session.localGame.history.isEmpty && session.undoOfferBy == nil) { showUndo = true }
            if settings.hintsEnabled { actionButton("lightbulb.fill", L10n.t("game.hint"), enabled: session.canMove) { session.requestHint() } }
            if settings.playForMe { actionButton("cpu", L10n.t("game.playForMe"), enabled: session.canMove) { showPlayForMe = true } }
            actionButton("equal.circle", L10n.t("game.draw"), enabled: !session.isFinished && session.drawOfferBy == nil) { showDraw = true }
            if !session.canMove && !session.isFinished {
                actionButton("hand.wave.fill", L10n.t("game.nudge"), enabled: session.nudgeCooldown == 0) { session.nudge() }
            }
            if session.isFinished {
                actionButton("arrow.counterclockwise", L10n.t("game.rematch"), enabled: true, tint: Duo.mint) { session.rematch() }
            } else {
                actionButton("flag.fill", L10n.t("game.resign"), enabled: true, tint: Duo.danger) { showResign = true }
            }
            HStack(spacing: 2) {
                Button { session.step(-1) } label: { Image(systemName: "chevron.left") }.buttonStyle(DuoIconButtonStyle()).disabled(session.localGame.history.isEmpty)
                Button { session.step(1) } label: { Image(systemName: "chevron.right") }.buttonStyle(DuoIconButtonStyle()).disabled(session.viewingPly == nil)
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

    private var coachHistorySheet: some View {
        NavigationStack {
            List {
                if session.coachHistory.isEmpty { Text(session.coachText) }
                ForEach(session.coachHistory.reversed()) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.text)
                        Text(item.source.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(L10n.t("game.coach"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(L10n.t("close")) { showCoachHistory = false } } }
        }
    }
}
