import Foundation
import UIKit

struct NudgeEvent: Codable, Equatable {
    var id: String?
    var fromName: String?
    var fromColor: String?
    var createdAt: String?
}

@MainActor
final class NudgeController: ObservableObject {
    static let cooldownSeconds = 90
    static let maxPerGame = 8

    @Published private(set) var isVisible = false
    @Published private(set) var isEnabled = false
    @Published private(set) var isSending = false
    @Published private(set) var cooldownRemaining = 0
    @Published private(set) var remainingCount = NudgeController.maxPerGame
    @Published private(set) var opponentName = ""
    @Published private(set) var titleText = ""
    @Published private(set) var detailText: String?

    private static var shownNudgeIds = Set<String>()
    private var canPlayIncoming = false
    private var cooldownTask: Task<Void, Never>?
    private var enableIncomingTask: Task<Void, Never>?
    private var lastGame: GameState?
    private var lastSession: PlayerSession?

    func reset() {
        isVisible = false
        isEnabled = false
        isSending = false
        cooldownRemaining = 0
        remainingCount = Self.maxPerGame
        opponentName = ""
        titleText = ""
        detailText = nil
        canPlayIncoming = false
        lastGame = nil
        lastSession = nil
        cooldownTask?.cancel()
        cooldownTask = nil
        enableIncomingTask?.cancel()
        Self.shownNudgeIds.removeAll()
    }

    func notePollingStarted() {
        canPlayIncoming = false
        enableIncomingTask?.cancel()
        enableIncomingTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.canPlayIncoming = true
        }
    }

    func notePollingStopped() {
        canPlayIncoming = false
        enableIncomingTask?.cancel()
    }

    static func markShownFromPush(_ id: String) {
        guard !id.isEmpty else { return }
        shownNudgeIds.insert(id)
    }

    func sync(
        game: GameState,
        session: PlayerSession?,
        incoming: NudgeEvent?,
        cooldown: Int?,
        remaining: Int?,
        presentToast: (String) -> Void
    ) {
        lastGame = game
        lastSession = session
        if let remaining {
            remainingCount = max(0, remaining)
        }
        if let cooldown {
            cooldownRemaining = max(0, cooldown)
            if cooldownRemaining > 0 {
                startCooldownTicker()
            } else {
                cooldownTask?.cancel()
                cooldownTask = nil
            }
        }
        refreshPresentation(game: game, session: session)
        consumeIncoming(incoming, presentToast: presentToast)
    }

    func consumeIncoming(_ incoming: NudgeEvent?, presentToast: (String) -> Void) {
        guard let incoming, let id = incoming.id, !id.isEmpty else { return }
        if Self.shownNudgeIds.contains(id) { return }
        Self.shownNudgeIds.insert(id)
        let name = incoming.fromName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let toast = name.isEmpty
            ? L10n.t(.nudgeYourMove)
            : L10n.t(.nudgeReceived, name)
        if canPlayIncoming, UIApplication.shared.applicationState == .active {
            Feedback.nudgeReceived()
            presentToast(toast)
        }
    }

    func applySendResult(delivered: String?, remaining: Int?, cooldown: Int?, opponent: String) -> String {
        if let remaining { remainingCount = max(0, remaining) }
        cooldownRemaining = max(0, cooldown ?? Self.cooldownSeconds)
        if cooldownRemaining > 0 { startCooldownTicker() }
        if let game = lastGame {
            refreshPresentation(game: game, session: lastSession)
        }
        if delivered == "no_push" {
            return L10n.t(.nudgeNoPush)
        }
        return L10n.t(.nudgeSent, opponent)
    }

    func applySendError(_ message: String, game: GameState, session: PlayerSession?) {
        if message.localizedCaseInsensitiveContains("enough") {
            remainingCount = 0
        }
        refreshPresentation(game: game, session: session)
    }

    func beginSend() { isSending = true }
    func endSend() { isSending = false }

    private func refreshPresentation(game: GameState, session: PlayerSession?) {
        guard let session, session.color != .spectator, !game.isFinished else {
            isVisible = false
            isEnabled = false
            titleText = ""
            detailText = nil
            return
        }

        let waiting = game.status.lowercased() == "waiting"
        let theirTurn = game.status.lowercased() == "active" && game.turn != session.color
        guard waiting || theirTurn else {
            isVisible = false
            isEnabled = false
            titleText = ""
            detailText = nil
            return
        }

        isVisible = true
        opponentName = waiting
            ? ""
            : (session.color == .white ? game.blackName : game.whiteName)
        let name = opponentName.trimmingCharacters(in: .whitespacesAndNewlines)
        if remainingCount <= 0 {
            isEnabled = false
            titleText = L10n.t(.nudgeCapReached)
            detailText = nil
            return
        }
        if cooldownRemaining > 0 {
            isEnabled = false
            titleText = L10n.t(.nudgeCooldown, formatCooldown(cooldownRemaining))
            detailText = nil
            return
        }
        isEnabled = !isSending
        titleText = name.isEmpty ? L10n.t(.nudgeThem) : L10n.t(.nudgeName, name)
        detailText = nil
    }

    private func startCooldownTicker() {
        if cooldownTask != nil { return }
        cooldownTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, !Task.isCancelled else { return }
                if self.cooldownRemaining <= 1 {
                    self.cooldownRemaining = 0
                    self.cooldownTask = nil
                    if let game = self.lastGame {
                        self.refreshPresentation(game: game, session: self.lastSession)
                    }
                    return
                }
                self.cooldownRemaining -= 1
                if let game = self.lastGame {
                    self.refreshPresentation(game: game, session: self.lastSession)
                }
            }
        }
    }

    private func formatCooldown(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remain = seconds % 60
        return String(format: "%d:%02d", minutes, remain)
    }
}
