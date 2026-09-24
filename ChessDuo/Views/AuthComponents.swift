import SwiftUI

// MARK: - Time

enum RelativeTime {
    /// "Just now" for anything in the last 90 seconds, or slightly in the future from clock skew, so a
    /// fresh timestamp never reads "in 0 seconds".
    static func label(for date: Date, now: Date = Date()) -> String {
        if date.timeIntervalSince(now) > -90 { return L10n.t("account.lastSynced.justNow") }
        return date.formatted(.relative(presentation: .named))
    }

    /// 0:42, 12:05, or 1:02:05 for the longest lockouts.
    static func countdown(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }

    static func remaining(until date: Date?, now: Date = Date()) -> Int {
        guard let date else { return 0 }
        return max(0, Int(date.timeIntervalSince(now).rounded(.up)))
    }
}

// MARK: - Messages

/// Shows an auth error. Rate limits and lockouts count down from the server's Retry-After, and a
/// lockout says plainly that it is a timed lock, not a wrong password.
struct AuthNotice: View {
    let failure: AuthFailure?
    var onReset: (() -> Void)?

    var body: some View {
        if let failure {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let left = RelativeTime.remaining(until: failure.until, now: context.date)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: failure.lockedOut ? "lock.fill" : (failure.until != nil ? "hourglass" : "exclamationmark.circle.fill"))
                        .foregroundStyle(Duo.danger)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(failure.message).font(.footnote.weight(.semibold))
                        if failure.until != nil {
                            Text(left > 0 ? L10n.t("account.error.retryIn", RelativeTime.countdown(left)) : L10n.t("account.error.retryNow"))
                                .font(.footnote.monospacedDigit())
                                .accessibilityIdentifier("auth.countdown")
                        }
                        if failure.lockedOut, let onReset {
                            Button(L10n.t("account.error.locked.reset"), action: onReset).font(.footnote.weight(.semibold))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Duo.danger)
                .padding(12)
                .background(Duo.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(failure.lockedOut ? "auth.lockedOut" : (failure.until != nil ? "auth.rateLimited" : "auth.error"))
            }
        }
    }
}

/// Primary button that shows progress in flight and stays disabled while a server countdown runs.
struct AuthSubmitButton: View {
    let title: String
    let busy: Bool
    var blockedUntil: Date?
    var enabled = true
    var id = "email.submit"
    let action: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = RelativeTime.remaining(until: blockedUntil, now: context.date)
            Button(action: action) {
                HStack(spacing: 8) {
                    if busy { ProgressView().tint(.white) }
                    Text(left > 0 ? L10n.t("account.error.retryIn", RelativeTime.countdown(left)) : title).monospacedDigit()
                }
            }
            .buttonStyle(DuoPrimaryButtonStyle())
            .disabled(busy || left > 0 || !enabled)
            .opacity(enabled || busy ? 1 : 0.6)
            .accessibilityIdentifier(id)
        }
    }
}

/// "Resend code", counting down first. The server allows one code a minute per address.
struct ResendButton: View {
    let availableAt: Date?
    let busy: Bool
    let action: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = RelativeTime.remaining(until: availableAt, now: context.date)
            Button(action: action) {
                Text(left > 0 ? L10n.t("account.code.wait", RelativeTime.countdown(left)) : L10n.t("account.code.resend")).monospacedDigit()
            }
            .font(.footnote.weight(.semibold))
            .disabled(left > 0 || busy)
            .accessibilityIdentifier("code.resend")
        }
    }
}

// MARK: - Fields

struct AuthTextField: View {
    @Environment(\.colorScheme) private var scheme
    let label: String
    @Binding var text: String
    var id: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline.weight(.semibold))
            TextField("", text: $text)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(Duo.card(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Duo.cardStroke(scheme), lineWidth: 1))
                .accessibilityLabel(label)
                .accessibilityIdentifier(id)
        }
    }
}

struct AuthPasswordField: View {
    @Environment(\.colorScheme) private var scheme
    let label: String
    @Binding var text: String
    var isNew: Bool
    var id: String
    @State private var visible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline.weight(.semibold))
            HStack {
                Group {
                    if visible { TextField("", text: $text) } else { SecureField("", text: $text) }
                }
                .textContentType(isNew ? .newPassword : .password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel(label)
                .accessibilityIdentifier(id)
                Button { visible.toggle() } label: {
                    Image(systemName: visible ? "eye.slash" : "eye").foregroundStyle(.secondary).frame(width: 32, height: 32)
                }
                .accessibilityLabel(visible ? L10n.t("account.password.hide") : L10n.t("account.password.show"))
                .accessibilityIdentifier(id + ".toggle")
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(Duo.card(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Duo.cardStroke(scheme), lineWidth: 1))
        }
    }
}

/// Live checklist of the server's password rule plus a strength bar, so what turns green is what Berth accepts.
struct PasswordRulesView: View {
    @Environment(\.colorScheme) private var scheme
    let policy: PasswordPolicy
    let password: String
    var confirm: String?

    private var strength: Int {
        guard policy.accepts(password) else { return password.isEmpty ? 0 : 1 }
        let classes = ["[a-z]", "[A-Z]", "\\d", "[^\\w\\s]|_"].filter { password.range(of: $0, options: .regularExpression) != nil }.count
        return password.count >= policy.minLength + 4 && classes >= 3 ? 3 : 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule().fill(index < strength ? color : Color.primary.opacity(0.1)).frame(height: 4)
                }
            }
            .accessibilityHidden(true)
            ForEach(policy.rules(for: password)) { rule in
                Label(rule.label, systemImage: rule.met ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(rule.met ? Duo.mint : Duo.secondaryText(scheme))
            }
            if let confirm, !confirm.isEmpty {
                let match = confirm == password
                Label(L10n.t(match ? "account.password.match" : "account.password.mismatch"), systemImage: match ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(match ? Duo.mint : Duo.danger)
            }
        }
        .font(.caption)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("password.rules")
    }

    private var color: Color { [Duo.danger, Duo.accent, Duo.mint][max(0, strength - 1)] }
}

// MARK: - Code

/// Six boxes over one hidden one-time-code field, so typing advances, delete goes back, and paste or
/// Mail/Messages autofill fill every box at once.
struct CodeBoxes: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var code: String
    var onComplete: (String) -> Void = { _ in }
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .foregroundStyle(.clear)
                .tint(.clear)
                .accessibilityLabel(L10n.t("account.code.field"))
                .accessibilityIdentifier("code.field")
                .onChange(of: code) { _, value in
                    let digits = String(value.filter(\.isNumber).prefix(6))
                    if digits != value { code = digits; return }
                    if digits.count == 6 { onComplete(digits) }
                }
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    let active = focused && index == min(code.count, 5)
                    Text(digit(at: index))
                        .font(.title2.monospacedDigit().weight(.semibold))
                        .frame(maxWidth: 52)
                        .frame(height: 56)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Duo.card(scheme)))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(active ? Duo.accent : Duo.cardStroke(scheme), lineWidth: active ? 2 : 1))
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .onAppear { focused = true }
    }

    private func digit(at index: Int) -> String {
        let digits = Array(code)
        return index < digits.count ? String(digits[index]) : " "
    }
}

/// Keeps auth forms a comfortable width on iPad and in landscape.
struct AuthFormWidth: ViewModifier {
    func body(content: Content) -> some View {
        content.frame(maxWidth: 480).frame(maxWidth: .infinity)
    }
}

extension View {
    func authFormWidth() -> some View { modifier(AuthFormWidth()) }
}
