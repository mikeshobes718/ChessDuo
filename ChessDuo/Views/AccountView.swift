import SwiftUI

// MARK: - Sign in sheet

/// Optional sign in: Apple first, then Google, then email. A session whose email is not verified
/// yet lands on the verification step instead, and the sheet closes itself once fully signed in,
/// leaving the user on the screen they opened it from.
struct SignInSheet: View {
    @EnvironmentObject private var account: AccountStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    var onSignedIn: () -> Void = {}

    var body: some View {
        NavigationStack {
            if account.needsEmailVerification {
                VerifyEmailView()
            } else {
                providers
            }
        }
        .onAppear {
            // Already signed in: nothing to do here.
            if account.isSignedIn { dismiss() }
            account.clearFailure()
        }
        .onChange(of: account.isSignedIn) { _, signedIn in if signedIn { signedInDone() } }
    }

    private var providers: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.t("account.sheet.title")).font(.title2.weight(.bold))
                    Text(L10n.t("account.sheet.subtitle")).font(.subheadline).foregroundStyle(Duo.secondaryText(scheme))
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                VStack(spacing: 12) {
                    Button { Task { await account.signInWithApple() } } label: {
                        ProviderLabel(title: L10n.t("account.apple")) { Image(systemName: "apple.logo").font(.system(size: 19, weight: .medium)) }
                    }
                    .accessibilityIdentifier("account.apple")
                    if GoogleSignIn.isConfigured {
                        Button { Task { await account.signInWithGoogle() } } label: {
                            ProviderLabel(title: L10n.t("account.google")) { Image("GoogleG").resizable().frame(width: 18, height: 18) }
                        }
                        .accessibilityIdentifier("account.google")
                    }
                    NavigationLink {
                        EmailAuthView()
                    } label: {
                        ProviderLabel(title: L10n.t("account.email")) { Image(systemName: "envelope.fill").foregroundStyle(Duo.accent) }
                    }
                    .accessibilityIdentifier("account.email")
                }
                .buttonStyle(.plain)
                .disabled(account.isBusy)
                .padding(.horizontal, 24)
                .padding(.top, 24)

                if account.isBusy { ProgressView().frame(maxWidth: .infinity).padding(.top, 16) }
                AuthNotice(failure: account.failure).padding(.horizontal, 24).padding(.top, 12)

                Text(L10n.t("account.optional"))
                    .font(.footnote)
                    .foregroundStyle(Duo.secondaryText(scheme))
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                Link(L10n.t("account.privacy"), destination: URL(string: "https://mikeshobes718.github.io/ChessDuo/privacy.html")!)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.top, 6)
                    .padding(.bottom, 24)
            }
            .authFormWidth()
        }
        .ignoresSafeArea(edges: .top)
        .duoBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Duo.accent.opacity(0.55), Duo.plum.opacity(0.35), .clear], startPoint: .topLeading, endPoint: .bottom)
            HStack(spacing: 18) {
                Text("♔").font(.system(size: 64)).frame(width: 104, height: 104).background(Circle().fill(.white.opacity(scheme == .dark ? 0.12 : 0.7)))
                    .offset(y: -10)
                Text("♚").font(.system(size: 64)).frame(width: 104, height: 104).background(Circle().fill(Duo.accent.opacity(0.35)))
                    .offset(y: 22)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)).foregroundStyle(.primary).frame(width: 44, height: 44)
            }
            .accessibilityIdentifier("account.close")
            .accessibilityLabel(L10n.t("cancel"))
            .padding(.leading, 12)
            .padding(.top, 56)
        }
        .frame(height: 280)
    }

    private func signedInDone() {
        onSignedIn()
        dismiss()
    }
}

/// Outlined pill with a leading provider mark.
struct ProviderLabel<Icon: View>: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    @ViewBuilder var icon: Icon

    var body: some View {
        HStack(spacing: 14) {
            icon.frame(width: 24)
            Text(title).font(.body.weight(.medium))
            Spacer(minLength: 0)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 20)
        .frame(height: 54)
        .frame(maxWidth: .infinity)
        .background(Duo.card(scheme), in: Capsule())
        .overlay(Capsule().strokeBorder(Duo.cardStroke(scheme), lineWidth: 1))
        .contentShape(Capsule())
    }
}

// MARK: - Email

/// Password sign in, account creation, passwordless codes and password reset, one step at a time.
/// Success is picked up by SignInSheet watching `isSignedIn`.
struct EmailAuthView: View {
    @EnvironmentObject private var account: AccountStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var scheme

    enum Step: Equatable {
        case form
        /// A 6 digit sign in code: passwordless, or the confirmation for a new account (`signUp`).
        case code(email: String, signUp: Bool)
        /// A new account that has not confirmed its code yet, moving to a corrected address.
        case changeEmail(from: String)
        case resetRequest
        case resetConfirm(email: String)
    }

    enum Field: Hashable { case name, email, password, confirm }

    @State private var step: Step = .form
    @State private var creating = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirm = ""
    @State private var code = ""
    @State private var lastTriedCode = ""
    @State private var resendAt: Date?
    @State private var localError: String?
    /// Server countdowns per step, so a lock on sign in does not also block asking for a reset code.
    @State private var blocked: [String: Date] = [:]
    @FocusState private var focus: Field?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(headerTitle).font(.largeTitle.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                switch step {
                case .form: form
                case .code(let mail, let signUp): codeStep(mail, signUp: signUp)
                case .changeEmail: changeEmailStep
                case .resetRequest: resetRequestStep
                case .resetConfirm(let mail): resetConfirmStep(mail)
                }
            }
            .padding(24)
            .authFormWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        .duoBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .navigationBarBackButtonHidden(step != .form)
        .toolbar {
            if step != .form {
                ToolbarItem(placement: .topBarLeading) {
                    Button { go(.form) } label: { Image(systemName: "chevron.left").font(.body.weight(.semibold)) }
                        .accessibilityLabel(L10n.t("account.back"))
                        .accessibilityIdentifier("email.back")
                }
            }
        }
        .task { await account.loadPolicy() }
        .onAppear {
            account.clearFailure()
            if name.isEmpty, settings.playerName != "Player" { name = settings.playerName }
        }
        .onChange(of: creating) { _, _ in localError = nil; account.failure = nil }
        .onChange(of: account.failure) { _, failure in
            if let until = failure?.until { blocked[stepKey] = until }
        }
    }

    // MARK: Steps

    private var form: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("", selection: $creating) {
                Text(L10n.t("account.mode.signIn")).tag(false)
                Text(L10n.t("account.mode.create")).tag(true)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("email.mode")
            if creating {
                AuthTextField(label: L10n.t("account.field.name"), text: $name, id: "name.field")
                    .textContentType(.nickname).textInputAutocapitalization(.words)
                    .focused($focus, equals: .name).submitLabel(.next).onSubmit { focus = .email }
            }
            emailField.submitLabel(.next).onSubmit { focus = .password }
            AuthPasswordField(label: L10n.t("account.field.password"), text: $password, isNew: creating, id: "password.field")
                .focused($focus, equals: .password)
                .submitLabel(creating ? .next : .go)
                .onSubmit { if creating { focus = .confirm } else { submitForm() } }
            if creating {
                AuthPasswordField(label: L10n.t("account.field.passwordConfirm"), text: $passwordConfirm, isNew: true, id: "password.confirm")
                    .focused($focus, equals: .confirm).submitLabel(.go).onSubmit(submitForm)
                PasswordRulesView(policy: account.policy, password: password, confirm: passwordConfirm)
            }
            notice
            AuthSubmitButton(title: creating ? L10n.t("account.mode.create") : L10n.t("account.mode.signIn"),
                             busy: account.isBusy, blockedUntil: blocked[stepKey], action: submitForm)
                .padding(.top, 6)
            if !creating {
                VStack(spacing: 14) {
                    Button(L10n.t("account.code.instead")) { Task { await sendSignInCode() } }
                        .accessibilityIdentifier("email.codeInstead")
                    Button(L10n.t("account.forgot")) { go(.resetRequest) }
                        .accessibilityIdentifier("email.forgot")
                }
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity)
                .disabled(account.isBusy)
            }
        }
    }

    private func codeStep(_ mail: String, signUp: Bool) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L10n.t("account.code.sent", mail)).font(.subheadline).foregroundStyle(Duo.secondaryText(scheme))
            CodeBoxes(code: $code) { _ in submitCode(mail, signUp: signUp) }
            notice
            AuthSubmitButton(title: signUp ? L10n.t("account.verify.confirm") : L10n.t("account.code.verify"),
                             busy: account.isBusy, blockedUntil: blocked[stepKey], enabled: code.count == 6) { submitCode(mail, signUp: signUp) }
            HStack {
                ResendButton(availableAt: resendAt, busy: account.isBusy) { Task { await resend { await account.requestCode(email: mail) } } }
                Spacer()
                if signUp {
                    Button(L10n.t("account.verify.wrongEmail")) { email = mail; go(.changeEmail(from: mail)) }
                        .font(.footnote.weight(.semibold))
                        .accessibilityIdentifier("code.changeEmail")
                }
            }
            Text(L10n.t("account.code.expires")).font(.caption).foregroundStyle(Duo.secondaryText(scheme))
        }
    }

    private var changeEmailStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L10n.t("account.verify.changeEmail.note")).font(.subheadline).foregroundStyle(Duo.secondaryText(scheme))
            emailField.submitLabel(.send).onSubmit(submitChangeEmail)
            notice
            AuthSubmitButton(title: L10n.t("account.code.send"), busy: account.isBusy, blockedUntil: blocked[stepKey], action: submitChangeEmail)
        }
        .onAppear { focus = .email }
    }

    private var resetRequestStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L10n.t("account.reset.request.note")).font(.subheadline).foregroundStyle(Duo.secondaryText(scheme))
            emailField.submitLabel(.send).onSubmit(submitResetRequest)
            notice
            AuthSubmitButton(title: L10n.t("account.code.send"), busy: account.isBusy, blockedUntil: blocked[stepKey], action: submitResetRequest)
        }
        .onAppear { if email.isEmpty { focus = .email } }
    }

    private func resetConfirmStep(_ mail: String) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            // Same words whether or not the account exists.
            Text(L10n.t("account.reset.sent", mail)).font(.subheadline).foregroundStyle(Duo.secondaryText(scheme))
            CodeBoxes(code: $code) { _ in focus = .password }
            AuthPasswordField(label: L10n.t("account.field.newPassword"), text: $password, isNew: true, id: "password.field")
                .focused($focus, equals: .password).submitLabel(.next).onSubmit { focus = .confirm }
            AuthPasswordField(label: L10n.t("account.field.passwordConfirm"), text: $passwordConfirm, isNew: true, id: "password.confirm")
                .focused($focus, equals: .confirm).submitLabel(.go).onSubmit { submitReset(mail) }
            PasswordRulesView(policy: account.policy, password: password, confirm: passwordConfirm)
            notice
            AuthSubmitButton(title: L10n.t("account.reset.submit"), busy: account.isBusy, blockedUntil: blocked[stepKey]) { submitReset(mail) }
            ResendButton(availableAt: resendAt, busy: account.isBusy) { Task { await resend { await account.requestPasswordReset(email: mail) } } }
            Text(L10n.t("account.reset.othersSignedOut")).font(.caption).foregroundStyle(Duo.secondaryText(scheme))
        }
    }

    // MARK: Pieces

    private var emailField: some View {
        AuthTextField(label: L10n.t("account.field.email"), text: $email, id: "email.field")
            .keyboardType(.emailAddress).textContentType(.emailAddress)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .focused($focus, equals: .email)
    }

    @ViewBuilder private var notice: some View {
        if let localError {
            AuthNotice(failure: AuthFailure(message: localError))
        } else {
            AuthNotice(failure: account.failure, onReset: step == .form ? { go(.resetRequest) } : nil)
        }
    }

    private var headerTitle: String {
        switch step {
        case .form: return creating ? L10n.t("account.mode.create") : L10n.t("account.mode.signIn")
        case .code(_, let signUp): return signUp ? L10n.t("account.verify.title") : L10n.t("account.code.title")
        case .changeEmail: return L10n.t("account.changeEmail")
        case .resetRequest: return L10n.t("account.reset.request.title")
        case .resetConfirm: return L10n.t("account.reset.title")
        }
    }

    private var stepKey: String {
        switch step {
        case .form: return creating ? "signup" : "login"
        case .code: return "code"
        case .changeEmail: return "change"
        case .resetRequest, .resetConfirm: return "reset"
        }
    }

    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

    private var emailLooksValid: Bool {
        let parts = trimmedEmail.split(separator: "@")
        return parts.count == 2 && parts[1].contains(".") && !trimmedEmail.contains(" ")
    }

    // MARK: Actions

    private func go(_ next: Step) {
        localError = nil
        account.failure = nil
        code = ""
        lastTriedCode = ""
        if case .resetConfirm = next {} else if case .code = next {} else { resendAt = nil }
        withAnimation(.easeInOut(duration: 0.2)) { step = next }
    }

    private func submitForm() {
        guard !account.isBusy else { return }
        localError = nil
        guard emailLooksValid else { localError = L10n.t("account.error.email"); focus = .email; return }
        if creating {
            guard account.policy.accepts(password) else { localError = L10n.t("account.error.password"); focus = .password; return }
            guard password == passwordConfirm else { localError = L10n.t("account.password.mismatch"); focus = .confirm; return }
        } else {
            guard !password.isEmpty else { localError = L10n.t("account.error.password.empty"); focus = .password; return }
        }
        focus = nil
        let mail = trimmedEmail
        Task {
            let outcome: AccountStore.PasswordOutcome
            if creating {
                let display = name.trimmingCharacters(in: .whitespacesAndNewlines)
                outcome = await account.signUp(email: mail, password: password, name: display.isEmpty ? settings.playerName : display)
            } else {
                outcome = await account.logIn(email: mail, password: password)
            }
            if outcome == .needsCode {
                let failure = account.failure
                go(.code(email: mail, signUp: true))
                account.failure = failure
                resendAt = Date().addingTimeInterval(60)
            }
        }
    }

    private func sendSignInCode() async {
        localError = nil
        guard emailLooksValid else { localError = L10n.t("account.error.email"); focus = .email; return }
        let mail = trimmedEmail
        if await account.requestCode(email: mail) {
            go(.code(email: mail, signUp: false))
            resendAt = Date().addingTimeInterval(60)
        }
    }

    private func submitCode(_ mail: String, signUp: Bool) {
        // Autofill and the button can both fire for the same code; send it once.
        guard code.count == 6, code != lastTriedCode, !account.isBusy else { return }
        lastTriedCode = code
        let display = name.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { _ = await account.verifyCode(email: mail, code: code, name: signUp && creating && !display.isEmpty ? display : nil) }
    }

    private func submitChangeEmail() {
        guard !account.isBusy, case .changeEmail(let from) = step else { return }
        localError = nil
        guard emailLooksValid else { localError = L10n.t("account.error.email"); return }
        let mail = trimmedEmail
        guard mail != from else { go(.code(email: from, signUp: true)); return }
        Task {
            if await account.moveUnverifiedSignUp(from: from, to: mail) {
                go(.code(email: mail, signUp: true))
                resendAt = Date().addingTimeInterval(60)
            }
        }
    }

    private func submitResetRequest() {
        guard !account.isBusy else { return }
        localError = nil
        guard emailLooksValid else { localError = L10n.t("account.error.email"); return }
        let mail = trimmedEmail
        Task {
            if await account.requestPasswordReset(email: mail) {
                password = ""; passwordConfirm = ""
                go(.resetConfirm(email: mail))
                resendAt = Date().addingTimeInterval(60)
            }
        }
    }

    private func submitReset(_ mail: String) {
        guard !account.isBusy else { return }
        localError = nil
        guard code.count == 6 else { localError = L10n.t("account.error.code.length"); return }
        guard account.policy.accepts(password) else { localError = L10n.t("account.error.password"); focus = .password; return }
        guard password == passwordConfirm else { localError = L10n.t("account.password.mismatch"); focus = .confirm; return }
        focus = nil
        Task { _ = await account.confirmPasswordReset(email: mail, code: code, password: password) }
    }

    private func resend(_ send: () async -> Bool) async {
        localError = nil
        if await send() {
            code = ""; lastTriedCode = ""
            resendAt = Date().addingTimeInterval(60)
        } else if let until = account.failure?.until {
            resendAt = until
        }
    }
}

// MARK: - Verify email (signed in, not verified yet)

/// The gate for a session whose email is not verified: no backup until the code is confirmed.
/// The address can still be corrected here, which verifies the new one in the same step.
struct VerifyEmailView: View {
    @EnvironmentObject private var account: AccountStore
    @Environment(\.colorScheme) private var scheme
    @State private var code = ""
    @State private var lastTriedCode = ""
    @State private var resendAt: Date?
    @State private var changing = false
    @State private var newEmail = ""
    @State private var newEmailSent: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(changing ? L10n.t("account.changeEmail") : L10n.t("account.verify.title")).font(.largeTitle.weight(.bold))
                if changing && newEmailSent == nil {
                    Text(L10n.t("account.verify.changeEmail.note")).font(.subheadline).foregroundStyle(Duo.secondaryText(scheme))
                    AuthTextField(label: L10n.t("account.field.email"), text: $newEmail, id: "email.field")
                        .keyboardType(.emailAddress).textContentType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .submitLabel(.send).onSubmit(sendNewEmail)
                    AuthNotice(failure: account.failure)
                    AuthSubmitButton(title: L10n.t("account.code.send"), busy: account.isBusy, blockedUntil: account.failure?.until, action: sendNewEmail)
                } else {
                    Text(L10n.t("account.verify.note", newEmailSent ?? account.email ?? "")).font(.subheadline).foregroundStyle(Duo.secondaryText(scheme))
                    CodeBoxes(code: $code) { _ in confirm() }
                    AuthNotice(failure: account.failure)
                    AuthSubmitButton(title: L10n.t("account.verify.confirm"), busy: account.isBusy, blockedUntil: account.failure?.until,
                                     enabled: code.count == 6, action: confirm)
                    HStack {
                        ResendButton(availableAt: resendAt, busy: account.isBusy) { Task { await resend() } }
                        Spacer()
                        Button(L10n.t("account.verify.wrongEmail")) { account.failure = nil; changing = true; newEmailSent = nil }
                            .font(.footnote.weight(.semibold))
                            .accessibilityIdentifier("verify.changeEmail")
                    }
                }
                Button(L10n.t("account.signOut")) { Task { await account.signOut() } }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Duo.secondaryText(scheme))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .accessibilityIdentifier("verify.signOut")
            }
            .padding(24)
            .authFormWidth()
        }
        .duoBackground()
        .navigationBarTitleDisplayMode(.inline)
        // Confirmed on another device while this screen was closed.
        .task { await account.refreshUser() }
    }

    private func confirm() {
        guard code.count == 6, code != lastTriedCode, !account.isBusy else { return }
        lastTriedCode = code
        let entered = code
        Task {
            if let target = newEmailSent {
                _ = await account.confirmEmailChange(newEmail: target, code: entered)
            } else {
                _ = await account.confirmEmailVerification(code: entered)
            }
        }
    }

    private func resend() async {
        let ok = if let target = newEmailSent { await account.requestEmailChange(newEmail: target) } else { await account.sendEmailVerification() }
        if ok {
            code = ""; lastTriedCode = ""
            resendAt = Date().addingTimeInterval(60)
        } else if let until = account.failure?.until {
            resendAt = until
        }
    }

    private func sendNewEmail() {
        let mail = newEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard mail.contains("@"), !account.isBusy else { return }
        Task {
            if await account.requestEmailChange(newEmail: mail) {
                newEmailSent = mail
                changing = false
                code = ""; lastTriedCode = ""
                resendAt = Date().addingTimeInterval(60)
            }
        }
    }
}

// MARK: - Account

struct AccountView: View {
    @EnvironmentObject private var account: AccountStore
    @EnvironmentObject private var cloud: CloudSync
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var history: HistoryStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var confirmSignOut = false
    @State private var confirmSignOutEverywhere = false
    @State private var showChangeEmail = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    AccountAvatar(name: settings.playerName, size: 52)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(settings.displayName).font(.headline)
                        Text(account.email ?? account.provider?.title ?? "")
                            .font(.subheadline).foregroundStyle(Duo.secondaryText(scheme)).lineLimit(1)
                            .accessibilityIdentifier("account.emailLabel")
                        if account.email != nil, let provider = account.provider {
                            Text(provider.title).font(.caption).foregroundStyle(Duo.secondaryText(scheme))
                        }
                    }
                    Spacer()
                }
                .duoCard(padding: 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("account.backup")).font(.subheadline.weight(.semibold)).foregroundStyle(Duo.secondaryText(scheme)).padding(.leading, 4)
                    VStack(spacing: 0) {
                        row(L10n.t("account.backup.games"), icon: "clock.arrow.circlepath", trailing: "\(history.records.count)")
                        Divider().padding(.leading, 48)
                        row(L10n.t("account.backup.stats"), icon: "chart.bar.fill", trailing: nil)
                        Divider().padding(.leading, 48)
                        row(L10n.t("account.backup.settings"), icon: "slider.horizontal.3", trailing: nil)
                        Divider().padding(.leading, 48)
                        HStack(spacing: 14) {
                            Image(systemName: "icloud").foregroundStyle(Duo.accent).frame(width: 22)
                            Text(L10n.t("account.lastSynced"))
                            Spacer()
                            if cloud.isSyncing {
                                ProgressView()
                            } else {
                                // Re-rendered each minute so "Just now" ages into "2 minutes ago".
                                TimelineView(.periodic(from: .now, by: 30)) { context in
                                    Text(cloud.lastSynced.map { RelativeTime.label(for: $0, now: context.date) } ?? L10n.t("account.never"))
                                        .foregroundStyle(Duo.secondaryText(scheme))
                                        .accessibilityIdentifier("account.lastSynced")
                                }
                            }
                        }
                        .padding(.horizontal, 16).frame(minHeight: 50)
                    }
                    .duoCard(padding: 0)
                    if let error = cloud.lastError {
                        Text(L10n.t("account.syncError") + " " + error).font(.caption).foregroundStyle(Duo.danger).padding(.leading, 4)
                    }
                    Button(L10n.t("account.syncNow")) { Task { await cloud.sync() } }
                        .buttonStyle(DuoSecondaryButtonStyle())
                        .disabled(cloud.isSyncing)
                        .accessibilityIdentifier("account.syncNow")
                        .padding(.top, 4)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("account.security")).font(.subheadline.weight(.semibold)).foregroundStyle(Duo.secondaryText(scheme)).padding(.leading, 4)
                    VStack(spacing: 0) {
                        NavigationLink { SessionsView() } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "iphone.gen3").foregroundStyle(Duo.accent).frame(width: 22)
                                Text(L10n.t("account.sessions")).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 16).frame(minHeight: 50)
                            .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("account.sessions")
                        if account.provider == .email {
                            Divider().padding(.leading, 48)
                            Button { showChangeEmail = true } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "envelope").foregroundStyle(Duo.accent).frame(width: 22)
                                    Text(L10n.t("account.changeEmail")).foregroundStyle(.primary)
                                    Spacer()
                                }
                                .padding(.horizontal, 16).frame(minHeight: 50)
                                .contentShape(Rectangle())
                            }
                            .accessibilityIdentifier("account.changeEmail")
                        }
                    }
                    .buttonStyle(.plain)
                    .duoCard(padding: 0)
                }

                VStack(spacing: 18) {
                    Button(L10n.t("account.signOut")) { confirmSignOut = true }
                        .font(.headline)
                        .foregroundStyle(Duo.accentDeep)
                        .accessibilityIdentifier("account.signOut")
                    Button(L10n.t("account.signOutEverywhere")) { confirmSignOutEverywhere = true }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Duo.secondaryText(scheme))
                        .accessibilityIdentifier("account.signOutEverywhere")
                    Button(L10n.t("account.delete")) { confirmDelete = true }
                        .font(.footnote)
                        .foregroundStyle(Duo.danger.opacity(0.85))
                        .accessibilityIdentifier("account.delete")
                    if account.isBusy { ProgressView() }
                    AuthNotice(failure: account.failure)
                }
                .disabled(account.isBusy)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
            }
            .padding(16)
            .authFormWidth()
        }
        .duoBackground()
        .navigationTitle(L10n.t("account.title"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(L10n.t("account.signOut.confirm"), isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button(L10n.t("account.signOut"), role: .destructive) { Task { await account.signOut(); dismiss() } }
            Button(L10n.t("cancel"), role: .cancel) {}
        } message: { Text(L10n.t("account.signOut.note")) }
        .confirmationDialog(L10n.t("account.signOutEverywhere.confirm"), isPresented: $confirmSignOutEverywhere, titleVisibility: .visible) {
            Button(L10n.t("account.signOutEverywhere"), role: .destructive) { Task { await account.signOut(everywhere: true); dismiss() } }
            Button(L10n.t("cancel"), role: .cancel) {}
        } message: { Text(L10n.t("account.signOutEverywhere.note")) }
        .sheet(isPresented: $showChangeEmail) { ChangeEmailSheet() }
        .alert(L10n.t("account.delete.confirm"), isPresented: $confirmDelete) {
            Button(L10n.t("cancel"), role: .cancel) {}
            Button(L10n.t("account.delete"), role: .destructive) { Task { if await account.deleteAccount() { dismiss() } } }
        } message: { Text(L10n.t("account.delete.message")) }
        .onAppear { account.clearFailure() }
        // Keeps the email label current if it changed on another device.
        .task { await account.refreshUser() }
        .onChange(of: account.hasSession) { _, has in if !has { dismiss() } }
    }

    private func row(_ title: String, icon: String, trailing: String?) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundStyle(Duo.accent).frame(width: 22)
            Text(title)
            Spacer()
            if let trailing { Text(trailing).font(.subheadline.monospacedDigit()).foregroundStyle(Duo.secondaryText(scheme)) }
            Image(systemName: "checkmark").font(.footnote.weight(.bold)).foregroundStyle(Duo.mint)
        }
        .padding(.horizontal, 16).frame(minHeight: 50)
    }
}

/// Change a verified account's email: a code goes to the new address, confirming it switches over.
struct ChangeEmailSheet: View {
    @EnvironmentObject private var account: AccountStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var newEmail = ""
    @State private var sentTo: String?
    @State private var code = ""
    @State private var lastTriedCode = ""
    @State private var resendAt: Date?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let sentTo {
                        Text(L10n.t("account.code.sent", sentTo)).font(.subheadline).foregroundStyle(Duo.secondaryText(scheme))
                        CodeBoxes(code: $code) { _ in confirm() }
                        AuthNotice(failure: account.failure)
                        AuthSubmitButton(title: L10n.t("account.verify.confirm"), busy: account.isBusy, blockedUntil: account.failure?.until,
                                         enabled: code.count == 6, action: confirm)
                        ResendButton(availableAt: resendAt, busy: account.isBusy) { send(sentTo) }
                    } else {
                        AuthTextField(label: L10n.t("account.field.newEmail"), text: $newEmail, id: "email.field")
                            .keyboardType(.emailAddress).textContentType(.emailAddress)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .submitLabel(.send).onSubmit { send(trimmed) }
                        AuthNotice(failure: account.failure)
                        AuthSubmitButton(title: L10n.t("account.code.send"), busy: account.isBusy, blockedUntil: account.failure?.until,
                                         enabled: trimmed.contains("@")) { send(trimmed) }
                    }
                }
                .padding(24)
                .authFormWidth()
            }
            .duoBackground()
            .navigationTitle(L10n.t("account.changeEmail"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.t("cancel")) { dismiss() } }
            }
        }
        .onAppear { account.clearFailure() }
    }

    private var trimmed: String { newEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

    private func send(_ mail: String) {
        guard mail.contains("@"), !account.isBusy else { return }
        Task {
            if await account.requestEmailChange(newEmail: mail) {
                sentTo = mail
                code = ""; lastTriedCode = ""
                resendAt = Date().addingTimeInterval(60)
            } else if let until = account.failure?.until {
                resendAt = until
            }
        }
    }

    private func confirm() {
        guard let sentTo, code.count == 6, code != lastTriedCode, !account.isBusy else { return }
        lastTriedCode = code
        let entered = code
        Task { if await account.confirmEmailChange(newEmail: sentTo, code: entered) { dismiss() } }
    }
}

struct AccountAvatar: View {
    let name: String
    var size: CGFloat = 40

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2).compactMap(\.first)
        return parts.isEmpty ? "♔" : String(parts).uppercased()
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [Duo.accent, Duo.accentDeep], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
    }
}

// MARK: - Home card

struct BackupCard: View {
    @Environment(\.colorScheme) private var scheme
    let onSignIn: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "icloud.and.arrow.up.fill").font(.title2).foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(LinearGradient(colors: [Duo.sky, Duo.sky.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("home.backup.title")).font(.headline)
                Text(L10n.t("home.backup.sub")).font(.caption).foregroundStyle(Duo.secondaryText(scheme))
                Button(L10n.t("home.backup.action"), action: onSignIn)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Duo.accentDeep)
                    .padding(.top, 4)
                    .accessibilityIdentifier("home.backup.signIn")
            }
            Spacer(minLength: 0)
            Button(action: onDismiss) { Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(.secondary).frame(width: 28, height: 28) }
                .accessibilityIdentifier("home.backup.dismiss")
        }
        .duoCard(padding: 14)
        .accessibilityIdentifier("home.backupCard")
    }
}
