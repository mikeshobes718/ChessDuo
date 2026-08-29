import AudioToolbox
import UIKit
import UserNotifications

// In-app turn banner matched to the Messages notification card https://mobbin.com/screens/17797b0e-f928-41e5-9ce9-d31c4f009941
// Lock screen grouping matched to FotMob per-match threads https://mobbin.com/screens/fbef6a0e-13dc-42d0-b690-b4577310cccc
enum Feedback {
    // Short system earcons, no bundled assets. Each game state sounds different on purpose.
    private enum Sound {
        static let yourTurn: SystemSoundID = 1003      // Received message ding
        static let moveSent: SystemSoundID = 1004      // Sent message swoosh
        static let check: SystemSoundID = 1020         // Anticipate, sharper two-tone
        static let gameWon: SystemSoundID = 1025       // Bloom, ascending chime
        static let gameOverFlat: SystemSoundID = 1054  // Tock, neutral end
        static let hint: SystemSoundID = 1057          // Tink
        static let warning: SystemSoundID = 1053       // Low error tap
        static let softMove: SystemSoundID = 1103      // Quiet pop for watched games
        static let nudge: SystemSoundID = 1007         // SMS received, gentle
    }

    static let turnCategory = "TURN"
    static let nudgeCategory = "NUDGE"

    private static var hapticsEnabled: Bool {
        UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
    }

    private static var soundsEnabled: Bool {
        UserDefaults.standard.object(forKey: "soundsEnabled") as? Bool ?? true
    }

    static var turnNotificationsEnabled: Bool {
        UserDefaults.standard.object(forKey: "turnNotificationsEnabled") as? Bool ?? true
    }

    private static func play(_ sound: SystemSoundID) {
        guard soundsEnabled else { return }
        AudioServicesPlaySystemSound(sound)
    }

    static func lightTap() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func moveSent() {
        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        play(Sound.moveSent)
    }

    static func yourTurn() {
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        play(Sound.yourTurn)
    }

    static func check() {
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        play(Sound.check)
    }

    static func gameWon() {
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        play(Sound.gameWon)
    }

    static func gameOverFlat() {
        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        play(Sound.gameOverFlat)
    }

    static func softMoveLanded() {
        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
        play(Sound.softMove)
    }

    static func opponentMoved() {
        softMoveLanded()
    }

    static func nudgeReceived() {
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        play(Sound.nudge)
    }

    static func success() {
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        play(Sound.hint)
    }

    static func warning() {
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        play(Sound.warning)
    }

    static func setTurnBadge() {
        UNUserNotificationCenter.current().setBadgeCount(1)
    }

    static func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }

    static func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func registerCategories() {
        let turn = UNNotificationCategory(identifier: turnCategory, actions: [], intentIdentifiers: [])
        let nudge = UNNotificationCategory(identifier: nudgeCategory, actions: [], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([turn, nudge])
    }

    // Local fallback for the APNs turn push, fired when a poll lands while the app is backgrounded.
    static func notifyYourTurn(roomCode: String, moveLabel: String? = nil) {
        guard turnNotificationsEnabled else { return }
        requestNotificationPermission()
        let content = UNMutableNotificationContent()
        content.title = L10n.t(.yourMove)
        content.body = moveLabel ?? L10n.t(.yourTurnNotifBody)
        content.sound = .default
        content.categoryIdentifier = turnCategory
        content.threadIdentifier = roomCode
        content.userInfo = ["roomCode": roomCode, "url": "chessduo://room/\(roomCode)"]
        let request = UNNotificationRequest(
            identifier: "your-turn-\(roomCode)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
