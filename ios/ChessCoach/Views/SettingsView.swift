// Settings matched to Hinge settings https://mobbin.com/screens/fd70e2d2-81d3-4808-8d4b-efc87e0e6662
// Card grouping also follows Bumble settings https://mobbin.com/screens/fe8df009-b4b9-4349-9e8b-dc8ec89974e5

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: GameViewModel
    @Environment(\.dismiss) private var dismiss

    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    @AppStorage("boardTheme") private var boardTheme = BoardTheme.classic.rawValue
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("soundsEnabled") private var soundsEnabled = true
    @AppStorage(AppLanguagePreference.storageKey) private var languagePreference =
        AppLanguagePreference.system.rawValue
    @State private var showingBoardColors = false
    @State private var showingPieceGuide = false

    var body: some View {
        NavigationStack {
            ZStack {
                DuoBackground()

                Form {
                    Section {
                        Picker(selection: $languagePreference) {
                            ForEach(AppLanguagePreference.allCases) { option in
                                Text(option.title).tag(option.rawValue)
                            }
                        } label: {
                            settingLabel(
                                title: L10n.t(.languageSection),
                                detail: (AppLanguagePreference(rawValue: languagePreference) ?? .system).detail
                            )
                        }
                    } header: {
                        Text(L10n.t(.languageSection).uppercased())
                    } footer: {
                        Text(L10n.t(.languageFooter))
                    }

                    Section {
                        Toggle(isOn: Binding(
                            get: { model.moveGuideEnabled },
                            set: { model.setMoveGuideEnabled($0) }
                        )) {
                            settingLabel(
                                title: L10n.t(.moveGuide),
                                detail: L10n.t(.moveGuideDetail)
                            )
                        }

                        Toggle(isOn: Binding(
                            get: { model.hintsEnabled },
                            set: { model.setHintsEnabled($0) }
                        )) {
                            settingLabel(
                                title: L10n.t(.hints),
                                detail: L10n.t(.hintsDetail)
                            )
                        }

                        Toggle(isOn: Binding(
                            get: { model.playForMeEnabled },
                            set: { model.setPlayForMeEnabled($0) }
                        )) {
                            settingLabel(
                                title: L10n.t(.playForMe),
                                detail: L10n.t(.playForMeDetail)
                            )
                        }

                        if model.playForMeEnabled {
                            Picker(
                                selection: Binding(
                                    get: { model.computerDifficulty },
                                    set: { model.setComputerDifficulty($0) }
                                )
                            ) {
                                ForEach(ComputerDifficulty.allCases) { level in
                                    Text(level.title).tag(level)
                                }
                            } label: {
                                settingLabel(
                                    title: L10n.t(.computerDifficulty),
                                    detail: model.computerDifficulty.detail
                                )
                            }
                            .pickerStyle(.segmented)
                        }
                    } header: {
                        Text(L10n.t(.assists).uppercased())
                    } footer: {
                        Text(L10n.t(.assistsFooter))
                    }

                    Section {
                        Picker(L10n.t(.appAppearance), selection: $appearanceMode) {
                            ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                                Text(mode.title).tag(mode.rawValue)
                            }
                        }

                        Picker(L10n.t(.boardTheme), selection: $boardTheme) {
                            ForEach(BoardTheme.allCases) { theme in
                                Text(theme.title).tag(theme.rawValue)
                            }
                        }

                        Button(L10n.t(.customizeBoardColors)) {
                            boardTheme = BoardTheme.custom.rawValue
                            showingBoardColors = true
                        }
                    } header: {
                        Text(L10n.t(.lookAndBoard).uppercased())
                    }

                    Section {
                        Toggle(L10n.t(.haptics), isOn: $hapticsEnabled)
                        Toggle(L10n.t(.sounds), isOn: $soundsEnabled)
                    } header: {
                        Text(L10n.t(.feedback).uppercased())
                    }

                    Section {
                        Button(L10n.t(.pieceGuide)) {
                            showingPieceGuide = true
                        }
                    } header: {
                        Text(L10n.t(.help).uppercased())
                    }

                    Section {
                        LabeledContent(L10n.t(.appName), value: "Chess Duo")
                        LabeledContent(L10n.t(.versionLabel), value: GameAPIClient.clientVersion)
                    } header: {
                        Text(L10n.t(.about).uppercased())
                    }
                }
                .scrollContentBackground(.hidden)
                .tint(DuoAccent.base)
            }
            .navigationTitle(L10n.t(.settings))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t(.done)) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingBoardColors) {
                BoardColorSettingsSheet()
            }
            .sheet(isPresented: $showingPieceGuide) {
                PieceLegendSheet()
            }
#if DEBUG
            .onAppear {
                let args = ProcessInfo.processInfo.arguments
                if args.contains("-previewGuide") { showingPieceGuide = true }
                if args.contains("-previewBoardColors") { showingBoardColors = true }
            }
#endif
        }
    }

    private func settingLabel(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.body.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}
