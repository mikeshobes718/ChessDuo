import Foundation
import SwiftUI

enum AccountProvider: String, Codable {
    case apple, google, email

    var title: String { L10n.t("account.provider.\(rawValue)") }
}

/// Optional account. Signed out, the app behaves exactly as before; signed in, CloudSync backs up
/// games, stats and settings. Tokens live in the Keychain on this device only.
@MainActor
final class AccountStore: ObservableObject {
    static let shared = AccountStore()

    struct Stored: Codable {
        var session: AccountSession
        var provider: AccountProvider
    }

    @Published private(set) var stored: Stored?
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?

    private let api = BerthAuthAPI()
    private let keychainKey = "session"
    private var refreshTask: Task<AccountSession, Error>?
    private let apple = AppleSignIn()
    private let google = GoogleSignIn()

    var isSignedIn: Bool { stored != nil }
    var userID: String? { stored?.session.user.id }
    var email: String? {
        guard let email = stored?.session.user.email, !email.hasSuffix("@users.invalid") else { return nil }
        return email
    }
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

    // MARK: - Sign in

    func signInWithApple() async -> Bool {
        await run(.apple) {
            let credential = try await self.apple.signIn()
            let session = try await self.api.apple(idToken: credential.idToken, nonce: credential.rawNonce, authorizationCode: credential.authorizationCode, name: credential.name)
            return (session, credential.name)
        }
    }

    func signInWithGoogle() async -> Bool {
        await run(.google) {
            let credential = try await self.google.signIn()
            let session = try await self.api.google(idToken: credential.idToken, nonce: credential.rawNonce, name: credential.name)
            return (session, credential.name)
        }
    }

    enum PendingFlow: Equatable {
        case verifySignUp(email: String)
        case resetPassword(email: String)
    }

    @Published private(set) var pendingFlow: PendingFlow?

    func clearPendingFlow() { pendingFlow = nil }

    func signUp(email: String, password: String, name: String) async -> Bool {
        isBusy = true; errorMessage = nil
        defer { isBusy = false }
        do {
            switch try await api.signUp(email: email, password: password, name: name) {
            case .session(let session):
                save(Stored(session: session, provider: .email))
                await CloudSync.shared.didSignIn(suggestedName: name)
                return true
            case .verificationRequired:
                pendingFlow = .verifySignUp(email: email)
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func requestPasswordReset(email: String) async -> Bool {
        isBusy = true; errorMessage = nil
        defer { isBusy = false }
        do {
            try await api.requestPasswordReset(email: email)
            pendingFlow = .resetPassword(email: email)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func confirmPasswordReset(email: String, code: String, password: String) async -> Bool {
        await run(.email) { (try await self.api.confirmPasswordReset(email: email, code: code, password: password), nil) }
    }

    func requestEmailChange(newEmail: String) async -> Bool {
        isBusy = true; errorMessage = nil
        defer { isBusy = false }
        do {
            let token = try await accessToken()
            try await api.requestEmailChange(newEmail: newEmail, token: token)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func confirmEmailChange(newEmail: String, code: String) async -> Bool {
        isBusy = true; errorMessage = nil
        defer { isBusy = false }
        do {
            let token = try await accessToken()
            try await api.confirmEmailChange(newEmail: newEmail, code: code, token: token)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func logIn(email: String, password: String) async -> Bool {
        await run(.email) { (try await self.api.logIn(email: email, password: password), nil) }
    }

    func requestCode(email: String) async -> Bool {
        isBusy = true; errorMessage = nil
        defer { isBusy = false }
        do { try await api.requestCode(email: email); return true } catch { errorMessage = error.localizedDescription; return false }
    }

    func verifyCode(email: String, code: String) async -> Bool {
        await run(.email) { (try await self.api.verifyCode(email: email, code: code), nil) }
    }

    private func run(_ provider: AccountProvider, _ work: @escaping () async throws -> (AccountSession, String?)) async -> Bool {
        isBusy = true; errorMessage = nil
        defer { isBusy = false }
        do {
            let (session, name) = try await work()
            save(Stored(session: session, provider: provider))
            await CloudSync.shared.didSignIn(suggestedName: name)
            return true
        } catch AccountError.cancelled {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Session

    /// A current access token, refreshing first when it is about to expire. Refreshes are single-flight
    /// because the server revokes the whole chain if an old refresh token is reused.
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
        isBusy = true; errorMessage = nil
        defer { isBusy = false }
        do {
            let token = try await accessToken()
            try await api.deleteAccount(token: token)
            clearLocal()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func save(_ value: Stored) {
        stored = value
        if let data = try? JSONEncoder().encode(value) { Keychain.set(data, for: keychainKey) }
    }

    private func clearLocal() {
        stored = nil
        Keychain.remove(keychainKey)
        CloudSync.shared.didSignOut()
    }
}
