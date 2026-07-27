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
            ZStack {
                DuoBackground()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 26) {
                            header
                            content
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 28)
                    }

                    if step == .home {
                        Text(L10n.t(.lobbyTipFaceTime))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 14)
                    }
                }
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
                if model.isLoading {
                    ZStack {
                        Color.black.opacity(0.18).ignoresSafeArea()
                        ProgressView(step == .start ? L10n.t(.creatingRoom) : L10n.t(.connecting))
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                        Button {
                            step = .home
                            model.clearError()
                        } label: {
                            Label(L10n.t(.back), systemImage: "chevron.left")
                                .font(.body.weight(.semibold))
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 40, height: 40)
                            .background(.regularMaterial, in: Circle())
                    }
                    .accessibilityLabel(L10n.t(.settings))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
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
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(DuoAccent.gradient)
                    .frame(width: 86, height: 86)
                    .shadow(color: DuoAccent.base.opacity(0.4), radius: 22, y: 12)
                Image(systemName: "crown.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 30)

            Text(L10n.t(.appName))
                .font(.system(size: 34, weight: .bold, design: .rounded))

            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
    }

    private var subtitle: String {
        switch step {
        case .home: return L10n.t(.lobbySubtitleHome)
        case .start: return L10n.t(.lobbySubtitleStart)
        case .join: return L10n.t(.lobbySubtitleJoin)
        case .watch: return L10n.t(.lobbySubtitleWatch)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .home: homeChoices
        case .start: startForm
        case .join: joinForm
        case .watch: watchForm
        }
    }

    private var homeChoices: some View {
        VStack(spacing: 14) {
            choiceCard(
                title: L10n.t(.startNewGame),
                detail: L10n.t(.startNewGameDetail),
                systemImage: "plus.circle.fill",
                prominent: true
            ) { step = .start }

            choiceCard(
                title: L10n.t(.iHaveCode),
                detail: L10n.t(.iHaveCodeDetail),
                systemImage: "person.2.fill",
                prominent: false
            ) { step = .join }

            choiceCard(
                title: L10n.t(.pastGames),
                detail: L10n.t(.pastGamesDetail),
                systemImage: "clock.arrow.circlepath",
                prominent: false
            ) { showingPastGames = true }

            Button {
                step = .watch
            } label: {
                Label(L10n.t(.watchGame), systemImage: "eye")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
    }

    private var startForm: some View {
        DuoFormCard {
            stepLabel(L10n.t(.step1of2))
            Text(L10n.t(.whatsYourName))
                .font(.title3.bold())
            DuoTextField(placeholder: L10n.t(.yourName), text: $model.playerName, contentType: .name)
            Text(L10n.t(.lobbySubtitleStart))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                Task { await model.createGame() }
            } label: {
                Label(L10n.t(.createRoom), systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .duoPrimaryButton()
            .disabled(model.isLoading || model.playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var joinForm: some View {
        DuoFormCard {
            stepLabel(L10n.t(.joinWithCode))
            Text(L10n.t(.whatsYourName))
                .font(.title3.bold())
            DuoTextField(placeholder: L10n.t(.yourName), text: $model.playerName, contentType: .name)

            Text(L10n.t(.roomCode))
                .font(.title3.bold())
                .padding(.top, 6)
            DuoTextField(placeholder: "AB12CD", text: $model.roomCodeInput, uppercase: true, mono: true)
            Text(L10n.t(.askPartnerCode))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                Task { await model.joinGame() }
            } label: {
                Label(L10n.t(.joinRoom), systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .duoPrimaryButton()
            .disabled(
                model.isLoading ||
                model.playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                model.roomCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
    }

    private var watchForm: some View {
        DuoFormCard {
            stepLabel(L10n.t(.watchGame))
            Text(L10n.t(.roomCode))
                .font(.title3.bold())
            DuoTextField(placeholder: "AB12CD", text: $model.roomCodeInput, uppercase: true, mono: true)

            Button {
                Task { await model.spectateGame() }
            } label: {
                Label(L10n.t(.watchRoom), systemImage: "eye.fill")
                    .frame(maxWidth: .infinity)
            }
            .duoPrimaryButton()
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
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    if prominent {
                        Circle()
                            .fill(Color.white.opacity(0.22))
                    } else {
                        Circle()
                            .fill(DuoAccent.base.opacity(0.12))
                    }
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(prominent ? Color.white : DuoAccent.base)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(prominent ? Color.white.opacity(0.92) : Color.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.body.weight(.bold))
                    .foregroundStyle(prominent ? Color.white.opacity(0.9) : Color.secondary.opacity(0.7))
            }
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .duoCard(prominent: prominent)
        .buttonStyle(.plain)
    }

    private func stepLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(DuoAccent.base)
            .tracking(1.2)
    }
}

private struct DuoFormCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .duoCard()
    }
}

private struct DuoTextField: View {
    let placeholder: String
    @Binding var text: String
    var contentType: UITextContentType? = nil
    var uppercase = false
    var mono = false

    var body: some View {
        TextField(placeholder, text: $text)
            .textContentType(contentType)
            .submitLabel(.go)
            .textInputAutocapitalization(uppercase ? .characters : .words)
            .autocorrectionDisabled()
            .font(mono ? .system(.title3, design: .monospaced).weight(.semibold) : .body.weight(.medium))
            .padding(.horizontal, 14)
            .frame(minHeight: 54)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .onChange(of: text) { value in
                guard uppercase else { return }
                let cleaned = value.uppercased().filter { $0.isLetter || $0.isNumber }
                if cleaned != value { text = cleaned }
            }
    }
}
