import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var history: HistoryStore
    @Environment(\.colorScheme) private var scheme
    let onStartLocal: (GameSession) -> Void
    let onOpenOnline: (String?) -> Void

    private var daily: Puzzle { PuzzleLibrary.daily() }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                stats
                if let resumable = history.resumable {
                    Button {
                        onStartLocal(GameSession(record: resumable))
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(Duo.mint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.t("home.resume")).font(.headline)
                                Text("\(resumable.whiteName) \(L10n.t("history.vs")) \(resumable.blackName) · \(L10n.t("over.moves", resumable.moveCount))").font(.caption).foregroundStyle(Duo.secondaryText(scheme))
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                        .duoCard(padding: 14)
                    }
                    .buttonStyle(.plain)
                }
                modeCard(title: L10n.t("home.playOnline"), subtitle: L10n.t("home.playOnline.sub"), icon: "antenna.radiowaves.left.and.right", tint: Duo.accent) { onOpenOnline(nil) }
                HStack(spacing: 12) {
                    NavigationLink(value: HomeRoute.localSetup) {
                        smallCard(title: L10n.t("home.passPlay"), subtitle: L10n.t("home.passPlay.sub"), icon: "person.2.fill", tint: Duo.teal)
                    }.buttonStyle(.plain)
                    NavigationLink(value: HomeRoute.computerSetup) {
                        smallCard(title: L10n.t("home.computer"), subtitle: L10n.t("home.computer.sub"), icon: "cpu.fill", tint: Duo.plum)
                    }.buttonStyle(.plain)
                }
                NavigationLink(value: HomeRoute.puzzles) {
                    HStack(spacing: 14) {
                        MiniBoard(fen: daily.fen, orientation: daily.sideToMove).frame(width: 84, height: 84)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.t("home.dailyPuzzle")).font(.headline)
                            Text(L10n.t("puzzle.toMove", L10n.colorName(daily.sideToMove))).font(.subheadline).foregroundStyle(Duo.secondaryText(scheme))
                            Text(history.stats.solvedPuzzleIDs.contains(daily.id) ? "✓ \(L10n.t("puzzle.solved"))" : L10n.t("puzzle.find")).font(.caption.weight(.semibold)).foregroundStyle(history.stats.solvedPuzzleIDs.contains(daily.id) ? Duo.mint : Duo.accent)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                    .duoCard(padding: 12)
                }.buttonStyle(.plain)
                HStack(spacing: 12) {
                    NavigationLink(value: HomeRoute.learn) { smallCard(title: L10n.t("home.learn"), subtitle: L10n.t("home.learn.sub"), icon: "book.fill", tint: Duo.sky) }.buttonStyle(.plain)
                    NavigationLink(value: HomeRoute.analysis) { smallCard(title: L10n.t("home.analysis"), subtitle: L10n.t("home.analysis.sub"), icon: "magnifyingglass", tint: Duo.rose) }.buttonStyle(.plain)
                }
                NavigationLink(value: HomeRoute.history) {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath").font(.title2).foregroundStyle(Duo.accentDeep).frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t("home.history")).font(.headline)
                            Text(L10n.t("home.history.sub")).font(.caption).foregroundStyle(Duo.secondaryText(scheme))
                        }
                        Spacer()
                        Text("\(history.records.count)").font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                    .duoCard(padding: 14)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .duoBackground()
        .navigationTitle(L10n.t("app.name"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: HomeRoute.settings) { Image(systemName: "gearshape.fill") }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.t("home.welcome", settings.displayName)).font(.title2.weight(.bold))
            Text(L10n.t("home.tagline")).font(.subheadline).foregroundStyle(Duo.secondaryText(scheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var stats: some View {
        HStack(spacing: 10) {
            StatTile(title: L10n.t("home.stats.games"), value: "\(history.stats.games)", icon: "square.grid.2x2.fill")
            StatTile(title: L10n.t("home.stats.wins"), value: "\(history.stats.wins)", icon: "checkmark.circle.fill", tint: Duo.mint)
            StatTile(title: L10n.t("home.stats.streak"), value: "\(history.stats.currentStreak)", icon: "flame.fill", tint: Duo.rose)
            StatTile(title: L10n.t("home.stats.puzzles"), value: "\(history.stats.puzzlesSolved)", icon: "puzzlepiece.fill", tint: Duo.sky)
        }
    }

    private func modeCard(title: String, subtitle: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title).foregroundStyle(.white).frame(width: 54, height: 54).background(LinearGradient(colors: [tint, tint.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.title3.weight(.bold))
                    Text(subtitle).font(.subheadline).foregroundStyle(Duo.secondaryText(scheme))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .duoCard(padding: 14)
        }
        .buttonStyle(.plain)
    }

    private func smallCard(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.title2).foregroundStyle(.white).frame(width: 44, height: 44).background(LinearGradient(colors: [tint, tint.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(title).font(.headline).lineLimit(2).minimumScaleFactor(0.8)
            Text(subtitle).font(.caption).foregroundStyle(Duo.secondaryText(scheme)).lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .duoCard(padding: 14)
    }
}

/// Non-interactive tiny board preview.
struct MiniBoard: View {
    let fen: String
    var orientation: PieceColor = .white
    @EnvironmentObject private var settings: AppSettings
    var body: some View {
        let position = Position(fen: fen) ?? Position()
        var interaction = BoardInteraction()
        let _ = { interaction.orientation = orientation; interaction.interactive = false }()
        BoardView2D(position: position, interaction: interaction, showCoordinates: false, onTap: { _ in })
            .allowsHitTesting(false)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct LocalSetupView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var white = ""
    @State private var black = ""
    @State private var time: TimeControl = .none
    let onStart: (GameSession) -> Void

    var body: some View {
        Form {
            Section {
                TextField(L10n.t("local.white"), text: $white).textInputAutocapitalization(.words)
                TextField(L10n.t("local.black"), text: $black).textInputAutocapitalization(.words)
            }
            Section(L10n.t("computer.time")) { TimeControlPicker(selection: $time) }
            Section {
                Toggle(L10n.t("local.autoFlip"), isOn: $settings.localAutoFlip)
                Toggle(L10n.t("settings.view3D"), isOn: $settings.prefers3D)
            }
            Section {
                Button(L10n.t("local.start")) {
                    let w = white.trimmingCharacters(in: .whitespaces), b = black.trimmingCharacters(in: .whitespaces)
                    let session = GameSession(kind: .local, whiteName: w.isEmpty ? L10n.t("game.player1") : w, blackName: b.isEmpty ? L10n.t("game.player2") : b, timeControl: time)
                    onStart(session)
                }
                .buttonStyle(DuoPrimaryButtonStyle())
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .scrollContentBackground(.hidden)
        .duoBackground()
        .navigationTitle(L10n.t("local.title"))
        .onAppear { if white.isEmpty { white = settings.playerName } }
    }
}

struct ComputerSetupView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var colorChoice = 0   // 0 white, 1 random, 2 black
    @State private var time: TimeControl = .none
    let onStart: (GameSession) -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Form {
            Section(L10n.t("computer.level")) {
                ForEach(EngineLevel.allCases) { level in
                    Button {
                        settings.computerLevel = level
                        Feedback.shared.selectionChanged()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.t("computer.level\(level.rawValue)")).font(.headline).foregroundStyle(.primary)
                                Text(L10n.t("computer.level\(level.rawValue).sub")).font(.caption).foregroundStyle(Duo.secondaryText(scheme))
                            }
                            Spacer()
                            Text(L10n.t("computer.elo", level.approxElo)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Image(systemName: settings.computerLevel == level ? "checkmark.circle.fill" : "circle").foregroundStyle(settings.computerLevel == level ? Duo.accent : .secondary)
                        }
                    }
                }
            }
            Section(L10n.t("computer.playAs")) {
                Picker(L10n.t("computer.playAs"), selection: $colorChoice) {
                    Text("♔ \(L10n.t("game.white"))").tag(0)
                    Text(L10n.t("computer.random")).tag(1)
                    Text("♚ \(L10n.t("game.black"))").tag(2)
                }.pickerStyle(.segmented)
            }
            Section(L10n.t("computer.time")) { TimeControlPicker(selection: $time) }
            Section { Toggle(L10n.t("settings.view3D"), isOn: $settings.prefers3D) }
            Section {
                Button(L10n.t("computer.start")) {
                    let human: PieceColor = colorChoice == 0 ? .white : (colorChoice == 2 ? .black : (Bool.random() ? .white : .black))
                    let me = settings.displayName
                    let cpu = "\(L10n.t("game.computer")) · \(L10n.t("computer.level\(settings.computerLevel.rawValue)"))"
                    onStart(GameSession(kind: .computer(settings.computerLevel, human: human), whiteName: human == .white ? me : cpu, blackName: human == .white ? cpu : me, timeControl: time))
                }
                .buttonStyle(DuoPrimaryButtonStyle())
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .scrollContentBackground(.hidden)
        .duoBackground()
        .navigationTitle(L10n.t("computer.title"))
    }
}

struct TimeControlPicker: View {
    @Binding var selection: TimeControl
    @State private var customMinutes = 10
    @State private var customIncrement = 5
    @State private var custom = false
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TimeControl.presets) { tc in
                    Button {
                        selection = tc; custom = false
                        Feedback.shared.selectionChanged()
                    } label: {
                        VStack(spacing: 2) {
                            Text(tc.title).font(.subheadline.weight(.bold))
                            Text(tc.category).font(.system(size: 9, weight: .semibold)).opacity(0.7)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(selection == tc && !custom ? Duo.accent : Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(selection == tc && !custom ? .white : .primary)
                    }.buttonStyle(.plain)
                }
                Button {
                    custom = true; selection = TimeControl(minutes: customMinutes, increment: customIncrement)
                } label: {
                    Text(L10n.t("time.custom")).font(.subheadline.weight(.bold)).padding(.horizontal, 12).padding(.vertical, 12)
                        .background(custom ? Duo.accent : Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(custom ? .white : .primary)
                }.buttonStyle(.plain)
            }
            .padding(.vertical, 2)
        }
        if custom {
            Stepper("\(L10n.t("time.minutes")): \(customMinutes)", value: $customMinutes, in: 1...180).onChange(of: customMinutes) { _, v in selection = TimeControl(minutes: v, increment: customIncrement) }
            Stepper("\(L10n.t("time.increment")): \(customIncrement)", value: $customIncrement, in: 0...60).onChange(of: customIncrement) { _, v in selection = TimeControl(minutes: customMinutes, increment: v) }
        }
    }
}
