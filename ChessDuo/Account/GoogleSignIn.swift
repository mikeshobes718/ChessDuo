import AuthenticationServices
import CryptoKit
import UIKit

struct GoogleCredential {
    var idToken: String
    var rawNonce: String
    var name: String?
}

/// Google sign in without the SDK: authorization code flow with PKCE in ASWebAuthenticationSession,
/// using the iOS OAuth client (no client secret) and its reversed client ID as the redirect scheme.
@MainActor
final class GoogleSignIn: NSObject, ASWebAuthenticationPresentationContextProviding {
    static var clientID: String? {
        let id = (Bundle.main.object(forInfoDictionaryKey: "GOOGLE_IOS_CLIENT_ID") as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        return id.hasSuffix(".apps.googleusercontent.com") ? id : nil
    }

    static var isConfigured: Bool { clientID != nil }

    private var authSession: ASWebAuthenticationSession?

    func signIn() async throws -> GoogleCredential {
        guard let clientID = Self.clientID else { throw AccountError.invalid }
        let scheme = "com.googleusercontent.apps." + clientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
        let redirect = "\(scheme):/oauth2redirect"
        let verifier = Nonce.random(length: 64)
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URL
        let nonce = Nonce.random()
        let state = Nonce.random(length: 24)

        var auth = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        auth.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirect),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid email profile"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "nonce", value: nonce),
            .init(name: "state", value: state),
            .init(name: "prompt", value: "select_account"),
        ]

        let callback: URL = try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(url: auth.url!, callbackURLScheme: scheme) { url, error in
                if let url { cont.resume(returning: url); return }
                let cancelled = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
                cont.resume(throwing: cancelled ? AccountError.cancelled : (error ?? AccountError.invalid))
            }
            session.presentationContextProvider = self
            authSession = session
            session.start()
        }
        authSession = nil

        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard items.first(where: { $0.name == "state" })?.value == state,
              let code = items.first(where: { $0.name == "code" })?.value else {
            throw items.contains(where: { $0.name == "error" }) ? AccountError.cancelled : AccountError.invalid
        }

        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "code", value: code),
            .init(name: "code_verifier", value: verifier),
            .init(name: "redirect_uri", value: redirect),
            .init(name: "grant_type", value: "authorization_code"),
        ]
        req.httpBody = form.percentEncodedQuery?.data(using: .utf8)
        let data: Data
        do { (data, _) = try await URLSession.shared.data(for: req) } catch { throw AccountError.network }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idToken = object["id_token"] as? String else { throw AccountError.invalid }
        return GoogleCredential(idToken: idToken, rawNonce: nonce, name: Self.name(from: idToken))
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated { UIApplication.shared.keyWindowForPresentation }
    }

    /// Reads the display name from the ID token payload. The server verifies the token; this is only for the UI.
    private static func name(from idToken: String) -> String? {
        let parts = idToken.split(separator: ".")
        guard parts.count == 3, let data = Data(base64URL: String(parts[1])),
              let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return (claims["given_name"] as? String) ?? (claims["name"] as? String)
    }
}

extension Data {
    var base64URL: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    init?(base64URL: String) {
        var s = base64URL.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        self.init(base64Encoded: s)
    }
}
