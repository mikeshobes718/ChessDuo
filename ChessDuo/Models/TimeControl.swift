import Foundation
import Combine

struct TimeControl: Hashable, Codable, Identifiable {
    var minutes: Int
    var increment: Int
    var id: String { "\(minutes)+\(increment)" }

    static let none = TimeControl(minutes: 0, increment: 0)
    static let presets: [TimeControl] = [
        .none,
        TimeControl(minutes: 1, increment: 0),
        TimeControl(minutes: 2, increment: 1),
        TimeControl(minutes: 3, increment: 2),
        TimeControl(minutes: 5, increment: 0),
        TimeControl(minutes: 5, increment: 3),
        TimeControl(minutes: 10, increment: 0),
        TimeControl(minutes: 15, increment: 10),
        TimeControl(minutes: 30, increment: 0)
    ]

    var isUntimed: Bool { minutes <= 0 }

    var title: String {
        if isUntimed { return L10n.t("time.none") }
        return increment > 0 ? "\(minutes)+\(increment)" : "\(minutes) min"
    }

    var category: String {
        if isUntimed { return L10n.t("time.none") }
        let estimate = Double(minutes) + Double(increment) * 40 / 60
        switch estimate {
        case ..<3: return L10n.t("time.bullet")
        case ..<10: return L10n.t("time.blitz")
        case ..<30: return L10n.t("time.rapid")
        default: return L10n.t("time.classical")
        }
    }
}

/// A two-sided chess clock driven by a display-rate timer.
@MainActor
final class ChessClock: ObservableObject {
    @Published private(set) var whiteRemaining: TimeInterval
    @Published private(set) var blackRemaining: TimeInterval
    @Published private(set) var running: PieceColor?
    @Published private(set) var isPaused = false
    let control: TimeControl
    var onFlag: ((PieceColor) -> Void)?
    var onLowTime: ((PieceColor) -> Void)?

    private var timer: Timer?
    private var lastTick: Date?
    private var warned: Set<PieceColor> = []

    init(control: TimeControl, white: TimeInterval? = nil, black: TimeInterval? = nil) {
        self.control = control
        whiteRemaining = white ?? TimeInterval(control.minutes * 60)
        blackRemaining = black ?? TimeInterval(control.minutes * 60)
    }

    var isActive: Bool { !control.isUntimed }

    func remaining(_ color: PieceColor) -> TimeInterval { color == .white ? whiteRemaining : blackRemaining }

    func start(_ color: PieceColor) {
        guard isActive else { return }
        running = color
        isPaused = false
        lastTick = Date()
        startTimer()
    }

    /// Called after a move by `mover`: adds increment and switches sides.
    func switchTurn(from mover: PieceColor) {
        guard isActive, !isPaused else { return }
        tick()
        if mover == .white { whiteRemaining += TimeInterval(control.increment) } else { blackRemaining += TimeInterval(control.increment) }
        running = mover.opposite
        lastTick = Date()
        startTimer()
    }

    func pause() {
        guard isActive, running != nil else { return }
        tick()
        isPaused = true
        stopTimer()
    }

    func resume() {
        guard isActive, isPaused else { return }
        isPaused = false
        lastTick = Date()
        startTimer()
    }

    func stop() {
        tick()
        running = nil
        stopTimer()
    }

    func set(white: TimeInterval, black: TimeInterval) {
        whiteRemaining = white
        blackRemaining = black
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let running, let last = lastTick, !isPaused else { return }
        let now = Date()
        let delta = now.timeIntervalSince(last)
        lastTick = now
        if running == .white {
            whiteRemaining = max(0, whiteRemaining - delta)
        } else {
            blackRemaining = max(0, blackRemaining - delta)
        }
        let remaining = self.remaining(running)
        if remaining <= 20, !warned.contains(running), TimeInterval(control.minutes * 60) > 30 {
            warned.insert(running)
            onLowTime?(running)
        }
        if remaining <= 0 {
            let flagged = running
            self.running = nil
            stopTimer()
            onFlag?(flagged)
        }
    }

    static func format(_ interval: TimeInterval) -> String {
        let total = max(0, interval)
        if total < 10 {
            return String(format: "%.1f", total)
        }
        let minutes = Int(total) / 60
        let seconds = Int(total) % 60
        if minutes >= 60 {
            return String(format: "%d:%02d:%02d", minutes / 60, minutes % 60, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
