import SwiftUI

private enum LobbyStep: Equatable {
    case home
    case start
    case join
    case watch
}

struct LobbyView: View {
    @EnvironmentObject private var model: GameViewModel
    @State private var step: LobbyStep = .home
    @State private var showingSettings = false
    @State private var showingPastGames = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 22) {
                        header
                        content
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }

                if step == .home {
                    Text(L10n.t(.lobbyTipFaceTime))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                }
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
                if model.isLoading {
                    ZStack {
                        Color.black.opacity(0.12).ignoresSafeArea()
                        ProgressView(step == .start ? L10n.t(.creatingRoom) : L10n.t(.connecting))
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .alert(
                L10n.t(.couldntConnect),
                isPresented: Binding(
                    get: { model.errorMessage != nil },
                    set: { if !$0 { model.clearError() } }
                )
            ) {
                Button(L10n.t(.ok)) { model.clearError() }
            } message: {
                Text(model.errorMessage ?? "")
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if step != .home {
                        Button(L10n.t(.back)) {
                            step = .home
                            model.clearError()
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(L10n.t(.settings))
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(model)
            }
            .sheet(isPresented: $showingPastGames) {
                PastGamesView()
                    .environmentObject(model)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkerboard.rectangle")
                .font(.system(size: 52))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(L10n.t(.appName))
                .font(.largeTitle.bold())
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 28)
    }

    private var subtitle: String {
        switch step {
        case .home:
            return L10n.t(.lobbySubtitleHome)
        case .start:
            return L10n.t(.lobbySubtitleStart)
        case .join:
            return L10n.t(.lobbySubtitleJoin)
        case .watch:
            return L10n.t(.lobbySubtitleWatch)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .home:
            homeChoices
        case .start:
            startForm
        case .join:
            joinForm
        case .watch:
            watchForm
        }
    }

    private var homeChoices: some View {
        VStack(spacing: 14) {
            choiceCard(
                title: L10n.t(.startNewGame),
                detail: L10n.t(.startNewGameDetail),
                systemImage: "plus.circle.fill",
                prominent: true
            ) {
                step = .start
            }

            choiceCard(
                title: L10n.t(.iHaveCode),
                detail: L10n.t(.iHaveCodeDetail),
                systemImage: "person.2.fill",
                prominent: false
            ) {
                step = .join
            }

            choiceCard(
                title: L10n.t(.pastGames),
                detail: L10n.t(.pastGamesDetail),
                systemImage: "chart.bar.doc.horizontal",
                prominent: false
            ) {
                showingPastGames = true
            }

            Button {
                step = .watch
            } label: {
                Text(L10n.t(.watchGame))
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private var startForm: some View {
        formCard {
            stepLabel(L10n.t(.step1of2))
            Text(L10n.t(.whatsYourName))
                .font(.title3.bold())
            TextField(L10n.t(.yourName), text: $model.playerName)
                .textContentType(.name)
                .submitLabel(.go)
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 52)
            Text(L10n.t(.lobbySubtitleStart))
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button {
                Task { await model.createGame() }
            } label: {
                Label(L10n.t(.createRoom), systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isLoading || model.playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var joinForm: some View {
        formCard {
            stepLabel(L10n.t(.joinWithCode))
            Text(L10n.t(.whatsYourName))
                .font(.title3.bold())
            TextField(L10n.t(.yourName), text: $model.playerName)
                .textContentType(.name)
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 52)

            Text(L10n.t(.roomCode))
                .font(.title3.bold())
                .padding(.top, 6)
            TextField("AB12CD", text: $model.roomCodeInput)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 52)
                .onChange(of: model.roomCodeInput) { value in
                    let cleaned = value.uppercased().filter { $0.isLetter || $0.isNumber }
                    if cleaned != value { model.roomCodeInput = cleaned }
                }
            Text(L10n.t(.askPartnerCode))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                Task { await model.joinGame() }
            } label: {
                Label(L10n.t(.joinRoom), systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                model.isLoading ||
                model.playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                model.roomCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
    }

    private var watchForm: some View {
        formCard {
            stepLabel(L10n.t(.watchGame))
            Text(L10n.t(.roomCode))
                .font(.title3.bold())
            TextField("AB12CD", text: $model.roomCodeInput)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 52)
                .onChange(of: model.roomCodeInput) { value in
                    let cleaned = value.uppercased().filter { $0.isLetter || $0.isNumber }
                    if cleaned != value { model.roomCodeInput = cleaned }
                }
            Button {
                Task { await model.spectateGame() }
            } label: {
                Label(L10n.t(.watchRoom), systemImage: "eye.fill")
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isLoading || model.roomCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func choiceCard(
        title: String,
        detail: String,
        systemImage: String,
        prominent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.bold())
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(prominent ? Color.white.opacity(0.9) : Color.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                prominent ? Color.accentColor : Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 18)
            )
        }
        .buttonStyle(.plain)
    }

    private func formCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func stepLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
    }
}
