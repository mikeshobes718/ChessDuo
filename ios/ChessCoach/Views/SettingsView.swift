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
                        Text(L10n.t(.languageSection))
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
                        Text(L10n.t(.assists))
                    } footer: {
                        Text(L10n.t(.assistsFooter))
                    }

                    Section(L10n.t(.lookAndBoard)) {
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
                    }

                    Section(L10n.t(.feedback)) {
                        Toggle(L10n.t(.haptics), isOn: $hapticsEnabled)
                        Toggle(L10n.t(.sounds), isOn: $soundsEnabled)
                    }

                    Section(L10n.t(.help)) {
                        Button(L10n.t(.pieceGuide)) {
                            showingPieceGuide = true
                        }
                    }

                    Section(L10n.t(.about)) {
                        LabeledContent(L10n.t(.appName), value: "Chess Duo")
                        LabeledContent(L10n.t(.versionLabel), value: GameAPIClient.clientVersion)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(L10n.t(.settings))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t(.done)) { dismiss() }
                }
            }
            .sheet(isPresented: $showingBoardColors) {
                BoardColorSettingsSheet()
            }
            .sheet(isPresented: $showingPieceGuide) {
                PieceLegendSheet()
            }
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
        .padding(.vertical, 2)
    }
}
