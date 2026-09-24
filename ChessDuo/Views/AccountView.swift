import SwiftUI

// MARK: - Sign in sheet

/// Optional sign in: Apple first, then Google, then email.
struct SignInSheet: View {
    @EnvironmentObject private var account: AccountStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    var onSignedIn: () -> Void = {}

    var body: some View {
        NavigationStack {
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
                        Button { Task { await finish(account.signInWithApple()) } } label: {
                            ProviderLabel(title: L10n.t("account.apple")) { Image(systemName: "apple.logo").font(.system(size: 19, weight: .medium)) }
                        }
                        .accessibilityIdentifier("account.apple")
                        if GoogleSignIn.isConfigured {
                            Button { Task { await finish(account.signInWithGoogle()) } } label: {
                                ProviderLabel(title: L10n.t("account.google")) { Image("GoogleG").resizable().frame(width: 18, height: 18) }
                            }
                            .accessibilityIdentifier("account.google")
                        }
                        NavigationLink {
                            EmailAuthView { signedIn() }
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
                    if let error = account.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(Duo.danger).padding(.horizontal, 24).padding(.top, 12)
                    }

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
            }
            .ignoresSafeArea(edges: .top)
            .duoBackground()
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear { account.errorMessage = nil }
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
            .padding(.leading, 12)
            .padding(.top, 56)
        }
        .frame(height: 280)
    }

    private func finish(_ ok: Bool) async { if ok { signedIn() } }

    private func signedIn() {
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

struct EmailAuthView: View {
    @EnvironmentObject private var account: AccountStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var scheme
    @State private var creating = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var codeSent = false
    @State private var code = ""
    @State private var passwordConfirm = ""
    @State private var showPassword = false
    @State private var resetFlow = false
    @State private var resendCooldown = 0
    @State private var localError: String?
    let onSignedIn: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(headerTitle)
                    .font(.largeTitle.weight(.bold))
                if codeSent {
                    Text(L10n.t("account.code.sent", trimmedEmail)).font(.subheadline).foregroundStyle(Duo.secondaryText(scheme))
                    CodeBoxes(code: $code)
                    if resetFlow {
                        passwordField
                        field(L10n.t("account.field.passwordConfirm"), text: $passwordConfirm, id: "password.confirm", secure: true)
                    }
                    if resendCooldown > 0 {
                        Text(L10n.t("account.code.wait", "\(resendCooldown)")).font(.caption).foregroundStyle(Duo.secondaryText(scheme))
                    } else {
                        Button(L10n.t("account.code.resend")) { Task { await resendCode() } }
                            .font(.footnote.weight(.semibold))
                    }
                } else {
                    Picker("", selection: $creating) {
                        Text(L10n.t("account.mode.signIn")).tag(false)
                        Text(L10n.t("account.mode.create")).tag(true)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("email.mode")
                    if creating {
                        field(L10n.t("account.field.name"), text: $name, id: "name.field").textContentType(.nickname).textInputAutocapitalization(.words)
                    }
                    field(L10n.t("account.field.email"), text: $email, id: "email.field")
                        .keyboardType(.emailAddress).textContentType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    passwordField
                    if creating {
                        field(L10n.t("account.field.passwordConfirm"), text: $passwordConfirm, id: "password.confirm", secure: true)
                        if !password.isEmpty { Text(passwordStrength).font(.caption).foregroundStyle(Duo.secondaryText(scheme)) }
                    }
                }

                if let message = localError ?? account.errorMessage {
                    Text(message).font(.footnote).foregroundStyle(Duo.danger)
                }

                Button {
                    Task { await submit() }
                } label: {
                    HStack(spacing: 8) {
                        if account.isBusy { ProgressView().tint(.white) }
                        Text(codeSent ? L10n.t("account.code.verify") : (creating ? L10n.t("account.mode.create") : L10n.t("account.mode.signIn")))
                    }
                }
                .buttonStyle(DuoPrimaryButtonStyle())
                .disabled(account.isBusy)
                .accessibilityIdentifier("email.submit")
                .padding(.top, 6)

                if !creating && !codeSent {
                    Button(L10n.t("account.forgot")) { Task { await startReset() } }
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .disabled(account.isBusy)
                }
            }
            .padding(24)
        }
        .duoBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear {
            account.errorMessage = nil
            if name.isEmpty, settings.playerName != "Player" { name = settings.playerName }
        }
        .onChange(of: creating) { _, _ in localError = nil; account.errorMessage = nil }
        .onChange(of: account.pendingFlow) { _, flow in
            guard let flow else { return }
            switch flow {
            case .verifySignUp(let mail):
                email = mail; resetFlow = false; codeSent = true
            case .resetPassword(let mail):
                email = mail; resetFlow = true; codeSent = true
            }
            account.clearPendingFlow()
            startCooldown()
        }
    }

    private var headerTitle: String {
        if codeSent { return resetFlow ? L10n.t("account.reset.title") : L10n.t("account.verify.title") }
        return creating ? L10n.t("account.mode.create") : L10n.t("account.mode.signIn")
    }

    private var passwordStrength: String {
        let hasLetter = password.range(of: "[A-Za-z]", options: .regularExpression) != nil
        let hasDigit = password.range(of: "\\d", options: .regularExpression) != nil
        if password.count >= 12 && hasLetter && hasDigit { return L10n.t("account.password.strong") }
        if password.count >= 8 && hasLetter && hasDigit { return L10n.t("account.password.medium") }
        return L10n.t("account.password.weak")
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.t("account.field.password")).font(.subheadline.weight(.semibold))
            HStack {
                Group {
                    if showPassword {
                        TextField("", text: $password).textContentType(creating ? .newPassword : .password)
                    } else {
                        SecureField("", text: $password).textContentType(creating ? .newPassword : .password)
                    }
                }
                Button(showPassword ? L10n.t("account.password.hide") : L10n.t("account.password.show")) { showPassword.toggle() }
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(Duo.card(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Duo.cardStroke(scheme), lineWidth: 1))
            .accessibilityIdentifier("password.field")
            if creating { Text(L10n.t("account.password.hint")).font(.caption).foregroundStyle(Duo.secondaryText(scheme)) }
        }
    }

    private func field(_ label: String, text: Binding<String>, id: String, secure: Bool = false, hint: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline.weight(.semibold))
            Group {
                if secure { SecureField("", text: text).textContentType(creating ? .newPassword : .password) } else { TextField("", text: text) }
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(Duo.card(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Duo.cardStroke(scheme), lineWidth: 1))
            .accessibilityIdentifier(id)
            if let hint { Text(hint).font(.caption).foregroundStyle(Duo.secondaryText(scheme)) }
        }
    }

    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

    private func submit() async {
        localError = nil
        if codeSent {
            let digits = code.filter(\.isNumber)
            guard digits.count == 6 else { localError = L10n.t("account.error.code"); return }
            if resetFlow {
                guard password.count >= 8, password == passwordConfirm else { localError = L10n.t("account.error.fields"); return }
                if await account.confirmPasswordReset(email: trimmedEmail, code: digits, password: password) { onSignedIn() }
            } else if await account.verifyCode(email: trimmedEmail, code: digits) { onSignedIn() }
            return
        }
        guard trimmedEmail.contains("@"), password.count >= 8 else { localError = L10n.t("account.error.fields"); return }
        if creating, password != passwordConfirm { localError = L10n.t("account.error.fields"); return }
        let ok: Bool
        if creating {
            let display = name.trimmingCharacters(in: .whitespacesAndNewlines)
            ok = await account.signUp(email: trimmedEmail, password: password, name: display.isEmpty ? settings.playerName : display)
        } else {
            ok = await account.logIn(email: trimmedEmail, password: password)
        }
        if ok { onSignedIn() }
    }

    private func startReset() async {
        localError = nil
        guard trimmedEmail.contains("@") else { localError = L10n.t("account.error.fields"); return }
        if await account.requestPasswordReset(email: trimmedEmail) {
            resetFlow = true
            codeSent = true
            startCooldown()
        }
    }

    private func resendCode() async {
        guard resendCooldown == 0 else { return }
        if resetFlow {
            _ = await account.requestPasswordReset(email: trimmedEmail)
        } else {
            _ = await account.requestCode(email: trimmedEmail)
        }
        startCooldown()
    }

    private func startCooldown() {
        resendCooldown = 60
        Task {
            while resendCooldown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                resendCooldown -= 1
            }
        }
    }
}

struct CodeBoxes: View {
    @Binding var code: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { index in
                let digit = digit(at: index)
                Text(digit)
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .frame(width: 44, height: 52)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))
            }
        }
        .overlay {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .opacity(0.01)
                .onChange(of: code) { _, value in
                    let digits = String(value.filter(\.isNumber).prefix(6))
                    if digits != value { code = digits }
                }
        }
        .onAppear { focused = true }
        .accessibilityIdentifier("code.field")
    }

    private func digit(at index: Int) -> String {
        let digits = Array(code.filter(\.isNumber))
        guard index < digits.count else { return " " }
        return String(digits[index])
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
    @State private var newEmail = ""
    @State private var emailCode = ""
    @State private var emailCodeSent = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    AccountAvatar(name: settings.playerName, size: 52)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(settings.displayName).font(.headline)
                        if let email = account.email { Text(email).font(.subheadline).foregroundStyle(Duo.secondaryText(scheme)).lineLimit(1) }
                        if let provider = account.provider { Text(provider.title).font(.caption).foregroundStyle(Duo.secondaryText(scheme)) }
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
                                Text(cloud.lastSynced.map { $0.formatted(.relative(presentation: .named)) } ?? L10n.t("account.never"))
                                    .foregroundStyle(Duo.secondaryText(scheme))
                                    .accessibilityIdentifier("account.lastSynced")
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

                VStack(spacing: 18) {
                    if account.provider == .email {
                        Button(L10n.t("account.changeEmail")) { showChangeEmail = true }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Duo.accentDeep)
                    }
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
                    if let error = account.errorMessage { Text(error).font(.footnote).foregroundStyle(Duo.danger) }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 28)
            }
            .padding(16)
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
        .sheet(isPresented: $showChangeEmail) {
            NavigationStack {
                Form {
                    Section {
                        TextField(L10n.t("account.field.email"), text: $newEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if emailCodeSent {
                            TextField(L10n.t("account.code.field"), text: $emailCode)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                        }
                    }
                    if let error = account.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(Duo.danger)
                    }
                }
                .navigationTitle(L10n.t("account.changeEmail"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(L10n.t("cancel")) { showChangeEmail = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(emailCodeSent ? L10n.t("account.code.verify") : L10n.t("account.code.send")) {
                            Task {
                                let trimmed = newEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                guard trimmed.contains("@") else { return }
                                if emailCodeSent {
                                    let digits = emailCode.filter(\.isNumber)
                                    guard digits.count == 6 else { return }
                                    if await account.confirmEmailChange(newEmail: trimmed, code: digits) { showChangeEmail = false }
                                } else if await account.requestEmailChange(newEmail: trimmed) {
                                    emailCodeSent = true
                                }
                            }
                        }
                    }
                }
            }
        }
        .alert(L10n.t("account.delete.confirm"), isPresented: $confirmDelete) {
            Button(L10n.t("cancel"), role: .cancel) {}
            Button(L10n.t("account.delete"), role: .destructive) { Task { if await account.deleteAccount() { dismiss() } } }
        } message: { Text(L10n.t("account.delete.message")) }
        .onAppear { account.errorMessage = nil }
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
