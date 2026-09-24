import Foundation
import SwiftUI

enum AccountProvider: String, Codable {
    case apple, google, email

    var title: String { L10n.t("account.provider.\(rawValue)") }
}

/// An auth error ready for the UI. `until` comes from the server's Retry-After, so the countdown is real.
struct AuthFailure: Equatable {
    var message: String
    var until: Date?
    var lockedOut = false
}

/// Optional account. Signed out, the app behaves exactly as before; signed in, CloudSync backs up
/// games, stats and settings. Tokens live in the Keychain on this device only.
///
/// Berth enforces rate limits and lockouts. Everything here (cooldowns, in-flight guards) is only
/// there so the UI is honest about them and a double tap never spends one of the 10 tries per email.
@MainActor
final class AccountStore: ObservableObject {
    static let shared = AccountStore()

    struct Stored: Codable {
        var session: AccountSession
        var provider: AccountProvider
    }

    @Published private(set) var stored: Stored?
    @Published private(set) var isBusy = false
    @Published var failure: AuthFailure?
    @Published private(set) var policy = PasswordPolicy()
    @Published private(set) var devices: [AccountDevice] = []
    @Published private(set) var devicesLoaded = false

    private let api = BerthAuthAPI()
    private let keychainKey = "session"
    private var refreshTask: Task<AccountSession, Error>?
    private let apple = AppleSignIn()
    private let google = GoogleSignIn()

    /// Signed in with full access. An account whose email is not verified yet has a session but no backup.
    var isSignedIn: Bool { stored != nil && !needsEmailVerification }
    var hasSession: Bool { stored != nil }
    var needsEmailVerification: Bool {
        guard let user = stored?.session.user else { return false }
        return user.realEmail != nil && !user.emailVerified
    }
    var userID: String? { isSignedIn ? stored?.session.user.id : nil }
    var email: String? { stored?.session.user.realEmail }
    var provider: AccountProvider? { stored?.provider }

    private init() {
        Keychain.wipeIfFreshInstall()
        #if DEBUG
        if ProcessInfo.processInfo.environment["CHESSDUO_SIGNED_OUT"] == "1" { Keychain.remove(keychainKey) }
        #endif
        if let data = Keychain.data(for: keychainKey), let decoded = try? JSONDecoder().decode(Stored.self, from: data) {
            stored = decoded
        }
    }

    // MARK: - Settings

    /// The app's password rule from Berth, so the meter matches what the server will accept.
    func loadPolicy() async {
        guard let policy = try? await api.settings() else { return }
        self.policy = policy
    }

    // MARK: - Sign in

    func signInWithApple() async -> Bool {
        await start(.apple) {
            let credential = try await self.apple.signIn()
            let session = try await self.api.apple(idToken: credential.idToken, nonce: credential.rawNonce, authorizationCode: credential.authorizationCode, name: credential.name)
            return (session, credential.name)
        }
    }

    func signInWithGoogle() async -> Bool {
        await start(.google) {
            let credential = try await self.google.signIn()
            let session = try await self.api.google(idToken: credential.idToken, nonce: credential.rawNonce, name: credential.name)
            return (session, credential.name)
        }
    }

    enum PasswordOutcome {
        case signedIn
        /// No session until the emailed code is confirmed. A code is on its way.
        case needsCode
        case failed
    }

    func logIn(email: String, password: String) async -> PasswordOutcome {
        guard begin() else { return .failed }
        defer { isBusy = false }
        do {
            try await finishSignIn(try await api.logIn(email: email, password: password), provider: .email, name: nil)
            return .signedIn
        } catch let error as AccountError {
            if case .emailNotVerified = error.kind {
                // The password was right. Send a sign in code, which also marks the email verified.
                do { try await api.requestCode(email: email) } catch let sendError { show(sendError) }
                return .needsCode
            }
            show(error)
            return .failed
        } catch {
            show(error)
            return .failed
        }
    }

    func signUp(email: String, password: String, name: String) async -> PasswordOutcome {
        guard begin() else { return .failed }
        defer { isBusy = false }
        do {
            switch try await api.signUp(email: email, password: password, name: name) {
            case .session(let session):
                try await finishSignIn(session, provider: .email, name: name)
                return .signedIn
            case .verificationRequired:
                return .needsCode
            }
        } catch {
            show(error)
            return .failed
        }
    }

    /// Passwordless sign in, and the resend for a signup waiting on its code.
    func requestCode(email: String) async -> Bool {
        await attempt { try await self.api.requestCode(email: email) }
    }

    func verifyCode(email: String, code: String, name: String? = nil) async -> Bool {
        guard begin() else { return false }
        defer { isBusy = false }
        do {
            try await finishSignIn(try await api.verifyCode(email: email, code: code), provider: .email, name: name)
            return true
        } catch {
            show(error)
            return false
        }
    }

    /// A signup that has not confirmed its code yet can move to a corrected address.
    func moveUnverifiedSignUp(from current: String, to newEmail: String) async -> Bool {
        await attempt { try await self.api.moveUnverifiedSignUp(from: current, to: newEmail) }
    }

    /// Step one of forgot password. The reply is the same whether or not the account exists.
    func requestPasswordReset(email: String) async -> Bool {
        await attempt { try await self.api.requestPasswordReset(email: email) }
    }

    /// Step two: sets the new password and signs in. Berth revokes every other session in the same call.
    func confirmPasswordReset(email: String, code: String, password: String) async -> Bool {
        guard begin() else { return false }
        defer { isBusy = false }
        do {
            try await finishSignIn(try await api.confirmPasswordReset(email: email, code: code, password: password), provider: .email, name: nil)
            return true
        } catch {
            show(error)
            return false
        }
    }

    // MARK: - Email verification (signed in, not verified yet)

    func sendEmailVerification() async -> Bool {
        await attempt { _ = try await self.authorized { try await self.api.verifyEmail(code: nil, token: $0) } }
    }

    func confirmEmailVerification(code: String) async -> Bool {
        guard begin() else { return false }
        defer { isBusy = false }
        do {
            let user = try await authorized { try await self.api.verifyEmail(code: code, token: $0) }
            // Access tokens carry the old claim, so refresh to get one that says verified.
            if let user { update(user) }
            expireAccessToken()
            _ = try? await accessToken()
            if isSignedIn { await CloudSync.shared.didSignIn(suggestedName: nil) }
            return isSignedIn
        } catch {
            show(error)
            return false
        }
    }

    func requestEmailChange(newEmail: String) async -> Bool {
        await attempt { try await self.authorized { try await self.api.requestEmailChange(newEmail: newEmail, token: $0) } }
    }

    func confirmEmailChange(newEmail: String, code: String) async -> Bool {
        guard begin() else { return false }
        defer { isBusy = false }
        do {
            let user = try await authorized { try await self.api.confirmEmailChange(newEmail: newEmail, code: code, token: $0) }
            let wasGated = needsEmailVerification
            update(user ?? stored.map { var u = $0.session.user; u.email = newEmail; u.emailVerified = true; return u })
            expireAccessToken()
            _ = try? await accessToken()
            if wasGated && isSignedIn { await CloudSync.shared.didSignIn(suggestedName: nil) }
            return true
        } catch {
            show(error)
            return false
        }
    }

    /// Picks up changes made elsewhere, like an email confirmed on another device.
    func refreshUser() async {
        guard hasSession, let user = try? await authorized({ try await self.api.me(token: $0) }) else { return }
        let wasGated = needsEmailVerification
        update(user)
        if wasGated && isSignedIn { await CloudSync.shared.didSignIn(suggestedName: nil) }
    }

    // MARK: - Devices

    func loadDevices() async {
        do {
            devices = try await authorized { try await self.api.sessions(token: $0) }
            devicesLoaded = true
        } catch {
            show(error)
        }
    }

    /// Signs one device out. Its access tokens stop working at once.
    func revoke(_ device: AccountDevice) async {
        guard begin() else { return }
        defer { isBusy = false }
        do {
            try await authorized { try await self.api.revokeSession(id: device.id, token: $0) }
            if device.isCurrent { clearLocal(); return }
            devices.removeAll { $0.id == device.id }
        } catch {
            show(error)
        }
    }

    // MARK: - Session

    /// A current access token, refreshing first when it is about to expire. One refresh at a time in
    /// this process, so we never spend the server's 10 second reuse grace on our own duplicates; a
    /// refresh token reused later than that revokes the whole chain.
    func accessToken() async throws -> String {
        guard let current = stored else { throw AccountError.server(status: 401, code: "unauthorized", message: "Signed out.") }
        if current.session.expiresAt.timeIntervalSinceNow > 60 { return current.session.accessToken }
        if let refreshTask { return try await refreshTask.value.accessToken }
        let task = Task { try await api.refresh(current.session.refreshToken) }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            let session = try await task.value
            if stored != nil { save(Stored(session: session, provider: current.provider)) }
            return session.accessToken
        } catch let error as AccountError where error.isUnauthorized {
            clearLocal()
            throw error
        }
    }

    /// Makes the next `accessToken()` refresh, after the server rejected a token that looked current.
    func expireAccessToken() {
        guard var value = stored else { return }
        value.session.expiresAt = .distantPast
        save(value)
    }

    func signOut(everywhere: Bool = false) async {
        if let token = try? await accessToken() { try? await api.logOut(token: token, everywhere: everywhere) }
        clearLocal()
    }

    func deleteAccount() async -> Bool {
        guard begin() else { return false }
        defer { isBusy = false }
        do {
            try await authorized { try await self.api.deleteAccount(token: $0) }
            clearLocal()
            return true
        } catch {
            show(error)
            return false
        }
    }

    func clearFailure() {
        // A running countdown stays: the server will still turn the next try away.
        if let until = failure?.until, until > Date() { return }
        failure = nil
    }

    // MARK: - Internals

    /// False when a request is already in flight, so a double tap never sends a second one. Screens
    /// also disable their submit while a server countdown runs; other actions (like asking for a reset
    /// code while locked out) stay available.
    private func begin() -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        failure = nil
        return true
    }

    private func attempt(_ work: () async throws -> Void) async -> Bool {
        guard begin() else { return false }
        defer { isBusy = false }
        do {
            try await work()
            return true
        } catch {
            show(error)
            return false
        }
    }

    private func start(_ provider: AccountProvider, _ work: @escaping () async throws -> (AccountSession, String?)) async -> Bool {
        guard begin() else { return false }
        defer { isBusy = false }
        do {
            let (session, name) = try await work()
            try await finishSignIn(session, provider: provider, name: name)
            return true
        } catch AccountError.cancelled {
            return false
        } catch {
            show(error)
            return false
        }
    }

    private func finishSignIn(_ session: AccountSession, provider: AccountProvider, name: String?) async throws {
        save(Stored(session: session, provider: provider))
        devices = []
        devicesLoaded = false
        if isSignedIn {
            await CloudSync.shared.didSignIn(suggestedName: name)
        } else if needsEmailVerification {
            // Signed in but gated: send the verification code right away.
            try? await api.verifyEmail(code: nil, token: session.accessToken)
        }
    }

    /// Runs a signed-in call, refreshing once if the server says the access token is stale.
    private func authorized<T>(_ body: (String) async throws -> T) async throws -> T {
        do {
            return try await body(try await accessToken())
        } catch let error as AccountError where error.isUnauthorized && stored != nil {
            expireAccessToken()
            return try await body(try await accessToken())
        }
    }

    private func show(_ error: Error) {
        guard let error = error as? AccountError else {
            failure = AuthFailure(message: error.localizedDescription)
            return
        }
        switch error.kind {
        case .rateLimited(let seconds):
            failure = AuthFailure(message: L10n.t("account.error.slowDown"), until: Date().addingTimeInterval(TimeInterval(seconds)))
        case .lockedOut(let seconds):
            failure = AuthFailure(message: L10n.t("account.error.locked"), until: Date().addingTimeInterval(TimeInterval(seconds)), lockedOut: true)
        default:
            if let message = error.errorDescription { failure = AuthFailure(message: message) }
        }
    }

    private func update(_ user: AccountUser?) {
        guard let user, var value = stored, value.session.user.id == user.id else { return }
        value.session.user = user
        save(value)
    }

    private func save(_ value: Stored) {
        stored = value
        if let data = try? JSONEncoder().encode(value) { Keychain.set(data, for: keychainKey) }
    }

    private func clearLocal() {
        stored = nil
        devices = []
        devicesLoaded = false
        Keychain.remove(keychainKey)
        CloudSync.shared.didSignOut()
    }
}
