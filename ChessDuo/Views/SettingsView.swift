import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var account: AccountStore
    @Environment(\.colorScheme) private var scheme
    @State private var showSignIn = false
    @State private var showResetStats = false
    @State private var showClearHistory = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var customLight: Color = .white
    @State private var customDark: Color = .gray

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }

    var body: some View {
        Form {
            Section(L10n.t("account.section")) {
                if account.isSignedIn {
                    NavigationLink { AccountView() } label: {
                        HStack(spacing: 12) {
                            AccountAvatar(name: settings.playerName, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(settings.displayName).font(.headline)
                                Text(account.email ?? account.provider?.title ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                    .accessibilityIdentifier("settings.account")
                } else if account.needsEmailVerification {
                    // Signed in but not verified: no backup until the email is confirmed.
                    Button { showSignIn = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.badge").font(.title2).foregroundStyle(Duo.accent).frame(width: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.t("account.verify.title")).font(.headline).foregroundStyle(.primary)
                                Text(account.email ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                    .accessibilityIdentifier("account.verify")
                } else {
                    Button { showSignIn = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.badge.plus").font(.title2).foregroundStyle(Duo.accent).frame(width: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.t("account.signIn")).font(.headline).foregroundStyle(.primary)
                                Text(L10n.t("account.signIn.sub")).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .accessibilityIdentifier("account.signIn")
                }
            }

            Section(L10n.t("settings.profile")) {
                TextField(L10n.t("settings.name"), text: $settings.playerName).textInputAutocapitalization(.words)
                Picker(L10n.t("settings.language"), selection: $settings.language) { ForEach(AppLanguage.allCases) { Text($0.title).tag($0) } }
                Picker(L10n.t("settings.appearance"), selection: $settings.appearance) { ForEach(AppearanceMode.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
            }

            Section(L10n.t("settings.board")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("settings.preview")).font(.caption).foregroundStyle(.secondary)
                    MiniBoard(fen: "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3").frame(height: 180).frame(maxWidth: .infinity)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(BoardTheme.allCases) { theme in
                            Button {
                                settings.boardTheme = theme
                                Feedback.shared.selectionChanged()
                            } label: {
                                VStack(spacing: 5) {
                                    ThemeSwatch(light: theme == .custom ? settings.lightSquare : theme.light, dark: theme == .custom ? settings.darkSquare : theme.dark)
                                        .frame(width: 52, height: 52)
                                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(settings.boardTheme == theme ? Duo.accent : .clear, lineWidth: 3))
                                    Text(theme.title).font(.caption2.weight(.semibold)).lineLimit(1)
                                }
                            }.buttonStyle(.plain)
                        }
                    }.padding(.vertical, 4)
                }
                if settings.boardTheme == .custom {
                    ColorPicker(L10n.t("settings.lightSquares"), selection: $customLight, supportsOpacity: false).onChange(of: customLight) { _, c in settings.customLightHex = c.hexString }
                    ColorPicker(L10n.t("settings.darkSquares"), selection: $customDark, supportsOpacity: false).onChange(of: customDark) { _, c in settings.customDarkHex = c.hexString }
                }
                Picker(L10n.t("settings.pieceStyle"), selection: $settings.pieceStyle) { ForEach(PieceStyle.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                HStack(spacing: 14) {
                    ForEach([PieceKind.king, .queen, .rook, .bishop, .knight, .pawn], id: \.self) { k in
                        VStack(spacing: 2) {
                            PieceView(piece: Piece(.white, k), style: settings.pieceStyle, size: 30)
                            PieceView(piece: Piece(.black, k), style: settings.pieceStyle, size: 30)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(settings.darkSquare.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                Toggle(isOn: $settings.prefers3D) { VStack(alignment: .leading) { Text(L10n.t("settings.view3D")); Text(L10n.t("settings.view3D.sub")).font(.caption).foregroundStyle(.secondary) } }
                Picker(L10n.t("settings.camera"), selection: $settings.cameraPreset) { ForEach(CameraPreset.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                Toggle(L10n.t("settings.coordinates"), isOn: $settings.showCoordinates)
                Toggle(L10n.t("settings.legalMoves"), isOn: $settings.showLegalMoves)
                Toggle(L10n.t("settings.lastMove"), isOn: $settings.highlightLastMove)
                Toggle(L10n.t("settings.threats"), isOn: $settings.highlightThreats)
                Toggle(isOn: $settings.confirmMoves) { VStack(alignment: .leading) { Text(L10n.t("settings.confirmMove")); Text(L10n.t("settings.confirmMove.sub")).font(.caption).foregroundStyle(.secondary) } }
                Toggle(L10n.t("settings.autoQueen"), isOn: $settings.autoQueen)
                Toggle(L10n.t("settings.animations"), isOn: $settings.animations)
            }

            Section(L10n.t("settings.assist")) {
                Toggle(L10n.t("settings.hints"), isOn: $settings.hintsEnabled)
                Toggle(isOn: $settings.moveGuide) { VStack(alignment: .leading) { Text(L10n.t("settings.moveGuide")); Text(L10n.t("settings.moveGuide.sub")).font(.caption).foregroundStyle(.secondary) } }
                Toggle(L10n.t("settings.coachCard"), isOn: $settings.coachCard)
                Toggle(isOn: $settings.playForMe) { VStack(alignment: .leading) { Text(L10n.t("settings.playForMe")); Text(L10n.t("settings.playForMe.sub")).font(.caption).foregroundStyle(.secondary) } }
                Picker(L10n.t("settings.engineLevel"), selection: $settings.assistLevel) { ForEach(EngineLevel.allCases) { Text(L10n.t("computer.level\($0.rawValue)")).tag($0) } }
            }

            Section(L10n.t("settings.feedback")) {
                Toggle(L10n.t("settings.sounds"), isOn: $settings.sounds).onChange(of: settings.sounds) { _, on in if on { Feedback.shared.play(.move) } }
                Toggle(L10n.t("settings.haptics"), isOn: $settings.haptics).onChange(of: settings.haptics) { _, on in if on { Feedback.shared.impact(.medium) } }
                Toggle(L10n.t("settings.clockWarning"), isOn: $settings.clockWarning)
                Toggle(isOn: $settings.turnNotifications) { VStack(alignment: .leading) { Text(L10n.t("settings.notifications")); Text(L10n.t("settings.notifications.sub")).font(.caption).foregroundStyle(.secondary) } }
                    .onChange(of: settings.turnNotifications) { _, on in
                        if on { UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in refreshNotificationStatus() } }
                        PushManager.shared.updatePreference()
                    }
                if notificationStatus == .denied && settings.turnNotifications {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.t("settings.notifications.denied")).font(.caption).foregroundStyle(Duo.danger)
                        Button(L10n.t("settings.openSettings")) { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }.font(.caption.weight(.semibold))
                    }
                }
            }

            Section(L10n.t("settings.data")) {
                NavigationLink(L10n.t("settings.pieceGuide")) { LearnView() }
                Button(L10n.t("settings.resetStats"), role: .destructive) { showResetStats = true }
                Button(L10n.t("settings.clearHistory"), role: .destructive) { showClearHistory = true }
            }

            Section(L10n.t("settings.about")) {
                LabeledContent(L10n.t("settings.version"), value: version)
                LabeledContent("Engine", value: "Duo Engine · αβ + TT")
                LabeledContent(L10n.t("home.puzzles"), value: "\(PuzzleLibrary.valid.count)")
            }
        }
        .scrollContentBackground(.hidden)
        .duoBackground()
        .navigationTitle(L10n.t("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSignIn) { SignInSheet().environmentObject(account).environmentObject(settings) }
        .alert(L10n.t("settings.resetStats.confirm"), isPresented: $showResetStats) {
            Button(L10n.t("cancel"), role: .cancel) {}
            Button(L10n.t("settings.reset"), role: .destructive) { history.resetStats() }
        }
        .alert(L10n.t("settings.clearHistory.confirm"), isPresented: $showClearHistory) {
            Button(L10n.t("cancel"), role: .cancel) {}
            Button(L10n.t("delete"), role: .destructive) { history.deleteAll() }
        }
        .onAppear {
            customLight = Color(hex: settings.customLightHex) ?? .white
            customDark = Color(hex: settings.customDarkHex) ?? .gray
            refreshNotificationStatus()
        }
    }

    private func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            DispatchQueue.main.async { notificationStatus = s.authorizationStatus }
        }
    }
}

struct ThemeSwatch: View {
    let light: Color
    let dark: Color
    var body: some View {
        GeometryReader { geo in
            let c = geo.size.width / 2
            ZStack(alignment: .topLeading) {
                Rectangle().fill(light)
                Rectangle().fill(dark).frame(width: c, height: c).offset(x: c, y: 0)
                Rectangle().fill(dark).frame(width: c, height: c).offset(x: 0, y: c)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
