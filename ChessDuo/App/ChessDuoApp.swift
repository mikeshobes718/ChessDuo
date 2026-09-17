import SwiftUI
import UserNotifications
import UIKit

@main
struct ChessDuoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings.shared
    @StateObject private var history = HistoryStore.shared
    @StateObject private var router = AppRouter.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(history)
                .environmentObject(router)
                .preferredColorScheme(settings.appearance.colorScheme)
                .tint(Duo.accent)
                .id(settings.languageTick)
                .onOpenURL { url in router.handle(url: url) }
        }
    }
}

/// Simple navigation router so deep links and notifications can drive the UI.
@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()
    @Published var pendingRoomCode: String?
    @Published var openOnlineFromNotification = false

    func handle(url: URL) {
        // chessduo://room/CODE  or chessduo://join?code=CODE
        guard url.scheme?.lowercased() == "chessduo" else { return }
        var code: String?
        if url.host?.lowercased() == "room" { code = url.pathComponents.dropFirst().first }
        if code == nil, let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
            code = items.first { $0.name.lowercased() == "code" }?.value
        }
        if let code, !code.isEmpty {
            pendingRoomCode = code.uppercased()
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in PushManager.shared.didReceive(token: token) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Push is optional; nothing to do.
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await MainActor.run { AppRouter.shared.openOnlineFromNotification = true }
    }
}

/// Handles APNs registration and forwards the token to the game server for the active room.
@MainActor
final class PushManager: ObservableObject {
    static let shared = PushManager()
    @Published private(set) var token: String?
    @Published private(set) var authorization: UNAuthorizationStatus = .notDetermined
    private var pendingSession: OnlineSessionInfo?
    private let api = OnlineAPI()

    func refreshStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in self.authorization = settings.authorizationStatus }
        }
    }

    func register(session: OnlineSessionInfo) {
        pendingSession = session
        guard AppSettings.shared.turnNotifications else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            Task { @MainActor in
                self.refreshStatus()
                guard granted else { return }
                UIApplication.shared.registerForRemoteNotifications()
                if let token = self.token { self.send(token: token) }
            }
        }
    }

    func didReceive(token: String) {
        self.token = token
        send(token: token)
    }

    func updatePreference() {
        guard let token, let session = pendingSession else { return }
        Task { try? await api.registerPush(session, token: token, turnAlerts: AppSettings.shared.turnNotifications) }
    }

    private func send(token: String) {
        guard let session = pendingSession, session.role != .spectator else { return }
        Task { try? await api.registerPush(session, token: token, turnAlerts: AppSettings.shared.turnNotifications) }
    }
}
