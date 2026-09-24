import SwiftUI

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var router: AppRouter
    @State private var path = NavigationPath()
    @State private var activeLocal: GameSession?
    @State private var activeOnline: OnlineSession?
    @State private var showOnboarding = false
    @State private var onlineLobbyPresented = false
    @State private var lobbyPrefillCode: String?

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                onStartLocal: { session in activeLocal = session },
                onOpenOnline: { code in lobbyPrefillCode = code; onlineLobbyPresented = true }
            )
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .puzzles: PuzzleView()
                case .learn: LearnView()
                case .history: HistoryView(onResume: { record in activeLocal = GameSession(record: record) })
                case .analysis: AnalysisView()
                case .settings: SettingsView()
                case .computerSetup: ComputerSetupView { activeLocal = $0 }
                case .localSetup: LocalSetupView { activeLocal = $0 }
                }
            }
        }
        .fullScreenCover(item: $activeLocal) { session in
            LocalGameView(session: session) { activeLocal = nil }
                .environmentObject(settings)
        }
        .fullScreenCover(isPresented: $onlineLobbyPresented) {
            // One cover hosts the whole online flow: the lobby, then the game once a session exists.
            Group {
                if let session = activeOnline {
                    OnlineGameView(session: session) {
                        activeOnline = nil
                        onlineLobbyPresented = false
                    }
                } else {
                    OnlineLobbyView(prefillCode: lobbyPrefillCode) { session in
                        withAnimation { activeOnline = session }
                    } onClose: {
                        onlineLobbyPresented = false
                    }
                }
            }
            .environmentObject(settings)
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView { showOnboarding = false }
                .interactiveDismissDisabled()
        }
        .onAppear {
            // Reapply the saved Light/Dark/System preference to the actual window: SwiftUI's
            // preferredColorScheme (set below) is enough for the initial content, but a window
            // that already existed before this view appeared (e.g. after a hot relaunch) needs
            // this to pick up a Light/Dark override rather than staying on System.
            settings.applyAppearanceToWindows()
            #if DEBUG
            if let appearance = ProcessInfo.processInfo.environment["CHESSDUO_APPEARANCE"].flatMap(AppearanceMode.init) {
                settings.appearance = appearance
            }
            if let screen = ProcessInfo.processInfo.environment["CHESSDUO_SCREEN"] {
                settings.hasOnboarded = true
                settings.playerName = "Mike"
                switch screen {
                case "computer":
                    // Debug/UI-test entry point: force-enable assist controls so automated taps and
                    // screenshots can exercise Hint / Play for me / the coach card, even though real
                    // users get them off by default. 2D as well: the UI tests address squares by
                    // grid coordinates, which only map to the 2D board (3D is covered by
                    // CHESSDUO_SCREEN=computer3d and test3DCameraReset).
                    settings.hintsEnabled = true
                    settings.playForMe = true
                    settings.coachCard = true
                    settings.prefers3D = false
                    let s = GameSession(kind: .computer(.club, human: .white), whiteName: "Mike", blackName: "Computer · Club", timeControl: TimeControl(minutes: 30, increment: 0))
                    s.use3D = false
                    activeLocal = s
                case "computer3d":
                    let s = GameSession(kind: .computer(.club, human: .white), whiteName: "Mike", blackName: "Computer · Club", timeControl: .none)
                    s.use3D = true
                    activeLocal = s
                case "local":
                    settings.prefers3D = false
                    let s = GameSession(kind: .local, whiteName: "Mike", blackName: "Liana", timeControl: TimeControl(minutes: 5, increment: 3))
                    s.use3D = false
                    for san in ["e4", "e5", "Nf3", "Nc6", "Bb5", "a6", "Ba4", "Nf6", "O-O"] { s.debugPlay(san: san) }
                    activeLocal = s
                case "puzzles": path.append(HomeRoute.puzzles)
                case "learn": path.append(HomeRoute.learn)
                case "history": path.append(HomeRoute.history)
                case "analysis": path.append(HomeRoute.analysis)
                case "settings": path.append(HomeRoute.settings)
                case "computerSetup": path.append(HomeRoute.computerSetup)
                case "lobby": onlineLobbyPresented = true
                case "onboarding": showOnboarding = true
                default: break
                }
                return
            }
            #endif
            if !settings.hasOnboarded { showOnboarding = true }
            // Restore an in-progress online game.
            if let saved = OnlineSession.loadSaved(), activeOnline == nil {
                activeOnline = OnlineSession(info: saved, initial: nil)
                onlineLobbyPresented = true
            }
        }
        .onChange(of: router.pendingRoomCode) { _, code in
            guard let code else { return }
            router.pendingRoomCode = nil
            activeLocal = nil
            if let online = activeOnline, online.roomCode == code { return }
            activeOnline?.leave()
            activeOnline = nil
            lobbyPrefillCode = code
            onlineLobbyPresented = true
        }
        .onChange(of: router.openOnlineFromNotification) { _, flag in
            guard flag else { return }
            router.openOnlineFromNotification = false
            if activeOnline == nil, let saved = OnlineSession.loadSaved() {
                activeOnline = OnlineSession(info: saved, initial: nil)
                onlineLobbyPresented = true
            }
        }
    }
}

extension GameSession: Identifiable {}
extension OnlineSession: Identifiable {}

enum HomeRoute: Hashable {
    case puzzles, learn, history, analysis, settings, computerSetup, localSetup
}

struct OnboardingView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var account: AccountStore
    @State private var name = ""
    @State private var showSignIn = false
    let onDone: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("♔♚").font(.system(size: 72))
            Text(L10n.t("onboarding.title")).font(.largeTitle.weight(.heavy)).multilineTextAlignment(.center)
            Text(L10n.t("home.tagline")).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.t("onboarding.name")).font(.headline)
                TextField(L10n.t("lobby.namePlaceholder"), text: $name)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit(finish)
            }
            .padding(.horizontal)
            Picker(L10n.t("settings.language"), selection: $settings.language) {
                ForEach(AppLanguage.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            Spacer()
            VStack(spacing: 14) {
                Button(L10n.t("onboarding.go"), action: finish).buttonStyle(DuoPrimaryButtonStyle())
                Button(L10n.t("onboarding.signIn")) { showSignIn = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Duo.accentDeep)
                    .accessibilityIdentifier("onboarding.signIn")
            }
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
        .duoBackground()
        .onAppear { name = settings.playerName }
        .sheet(isPresented: $showSignIn) {
            SignInSheet(onSignedIn: {
                let typed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if settings.playerName.trimmingCharacters(in: .whitespaces).isEmpty { settings.playerName = typed.isEmpty ? "Player" : typed }
                settings.hasOnboarded = true
                onDone()
            })
            .environmentObject(account)
            .environmentObject(settings)
        }
    }
    private func finish() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.playerName = trimmed.isEmpty ? "Player" : trimmed
        settings.hasOnboarded = true
        Feedback.shared.play(.gameStart)
        onDone()
    }
}
