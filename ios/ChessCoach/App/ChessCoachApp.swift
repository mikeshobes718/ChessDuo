import SwiftUI
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Feedback.registerCategories()
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let info = notification.request.content.userInfo
        if let id = info["nudgeId"] as? String {
            NudgeController.markShownFromPush(id)
        }
        if UIApplication.shared.applicationState == .active {
            completionHandler([])
            return
        }
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        if let id = info["nudgeId"] as? String {
            NudgeController.markShownFromPush(id)
        }
        if let code = info["roomCode"] as? String, !code.isEmpty {
            Task { @MainActor in
                SharedGameModel.shared?.handleRoomLink(code)
            }
        }
        completionHandler()
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            SharedGameModel.shared?.handleDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Push is best-effort: the game still works fully over polling.
    }
}

@main
struct ChessCoachApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = GameViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    @AppStorage(AppLanguagePreference.storageKey) private var languagePreference =
        AppLanguagePreference.system.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme)
                .tint(DuoAccent.ink)
                // Rebuild UI when the in-app language changes.
                .id(languagePreference)
                .onOpenURL { url in
                    handle(url: url)
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        model.clearBadge()
                    }
                }
        }
    }

    private func handle(url: URL) {
        guard url.scheme?.lowercased() == "chessduo" else { return }
        if url.host?.lowercased() == "room" {
            let code = url.pathComponents.filter { $0 != "/" }.first ?? ""
            if !code.isEmpty {
                model.handleRoomLink(code)
            }
        }
    }
}
