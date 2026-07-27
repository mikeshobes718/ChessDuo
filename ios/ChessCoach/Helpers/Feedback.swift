import AudioToolbox
import UIKit
import UserNotifications

enum Feedback {
    private static var hapticsEnabled: Bool {
        UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
    }

    private static var soundsEnabled: Bool {
        UserDefaults.standard.object(forKey: "soundsEnabled") as? Bool ?? true
    }

    static func lightTap() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        if soundsEnabled {
            AudioServicesPlaySystemSound(1057)
        }
    }

    static func warning() {
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        if soundsEnabled {
            AudioServicesPlaySystemSound(1053)
        }
    }

    static func opponentMoved() {
        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        if soundsEnabled {
            AudioServicesPlaySystemSound(1103)
        }
    }

    static func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func notifyYourTurn(roomCode: String) {
        let content = UNMutableNotificationContent()
        content.title = "Chess Duo"
        content.body = "It's your turn in room \(roomCode)."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "your-turn-\(roomCode)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
