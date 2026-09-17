import AVFoundation
import UIKit

/// Haptics and synthesized sounds. No audio assets: tones are generated on the fly with AVAudioEngine.
@MainActor
final class Feedback {
    static let shared = Feedback()

    enum Sound { case move, capture, check, castle, promote, gameStart, win, lose, draw, tick, lowTime, notify, error, select, puzzleSolved }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var format: AVAudioFormat!
    private var ready = false
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    private init() {
        setupAudio()
    }

    private func setupAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            return
        }
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.9
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.ready = false }
        }
        startEngineIfNeeded()
    }

    private func startEngineIfNeeded() {
        guard !engine.isRunning else { ready = true; return }
        do {
            try engine.start()
            if !player.isPlaying { player.play() }
            ready = true
        } catch {
            ready = false
        }
    }

    // MARK: - Public API

    func play(_ sound: Sound) {
        if AppSettings.shared.sounds { playTone(for: sound) }
        if AppSettings.shared.haptics { haptic(for: sound) }
    }

    func selectionChanged() {
        guard AppSettings.shared.haptics else { return }
        selection.selectionChanged()
    }

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard AppSettings.shared.haptics else { return }
        switch style {
        case .light: light.impactOccurred()
        case .medium: medium.impactOccurred()
        case .heavy: heavy.impactOccurred()
        case .rigid: rigid.impactOccurred()
        default: light.impactOccurred()
        }
    }

    private func haptic(for sound: Sound) {
        switch sound {
        case .move: light.impactOccurred()
        case .select: selection.selectionChanged()
        case .capture: medium.impactOccurred()
        case .castle: rigid.impactOccurred()
        case .promote: heavy.impactOccurred()
        case .check: notification.notificationOccurred(.warning)
        case .gameStart: medium.impactOccurred()
        case .win, .puzzleSolved: notification.notificationOccurred(.success)
        case .lose, .error: notification.notificationOccurred(.error)
        case .draw: notification.notificationOccurred(.warning)
        case .tick: light.impactOccurred(intensity: 0.5)
        case .lowTime: heavy.impactOccurred()
        case .notify: notification.notificationOccurred(.success)
        }
    }

    // MARK: - Synthesis

    private struct Note { var freq: Double; var duration: Double; var volume: Double = 0.5; var attack: Double = 0.004; var kind: Wave = .sine }
    private enum Wave { case sine, triangle, noise, pluck }

    private func notes(for sound: Sound) -> [Note] {
        switch sound {
        case .move: return [Note(freq: 220, duration: 0.07, volume: 0.55, kind: .pluck)]
        case .select: return [Note(freq: 660, duration: 0.03, volume: 0.18)]
        case .capture: return [Note(freq: 150, duration: 0.05, volume: 0.6, kind: .noise), Note(freq: 196, duration: 0.09, volume: 0.5, kind: .pluck)]
        case .castle: return [Note(freq: 220, duration: 0.06, volume: 0.45, kind: .pluck), Note(freq: 294, duration: 0.08, volume: 0.45, kind: .pluck)]
        case .promote: return [Note(freq: 523, duration: 0.08, volume: 0.4), Note(freq: 659, duration: 0.08, volume: 0.4), Note(freq: 784, duration: 0.14, volume: 0.45)]
        case .check: return [Note(freq: 880, duration: 0.09, volume: 0.35, kind: .triangle), Note(freq: 740, duration: 0.14, volume: 0.35, kind: .triangle)]
        case .gameStart: return [Note(freq: 392, duration: 0.09, volume: 0.35), Note(freq: 523, duration: 0.09, volume: 0.35), Note(freq: 659, duration: 0.16, volume: 0.4)]
        case .win: return [Note(freq: 523, duration: 0.11, volume: 0.4), Note(freq: 659, duration: 0.11, volume: 0.4), Note(freq: 784, duration: 0.11, volume: 0.4), Note(freq: 1047, duration: 0.3, volume: 0.45)]
        case .lose: return [Note(freq: 392, duration: 0.16, volume: 0.35, kind: .triangle), Note(freq: 330, duration: 0.16, volume: 0.35, kind: .triangle), Note(freq: 262, duration: 0.3, volume: 0.35, kind: .triangle)]
        case .draw: return [Note(freq: 440, duration: 0.14, volume: 0.35), Note(freq: 440, duration: 0.2, volume: 0.3)]
        case .tick: return [Note(freq: 1200, duration: 0.02, volume: 0.15)]
        case .lowTime: return [Note(freq: 988, duration: 0.06, volume: 0.35, kind: .triangle), Note(freq: 988, duration: 0.06, volume: 0.0), Note(freq: 988, duration: 0.06, volume: 0.35, kind: .triangle)]
        case .notify: return [Note(freq: 784, duration: 0.08, volume: 0.35), Note(freq: 1047, duration: 0.16, volume: 0.4)]
        case .error: return [Note(freq: 180, duration: 0.12, volume: 0.35, kind: .triangle)]
        case .puzzleSolved: return [Note(freq: 659, duration: 0.09, volume: 0.4), Note(freq: 880, duration: 0.09, volume: 0.4), Note(freq: 1319, duration: 0.24, volume: 0.45)]
        }
    }

    private func playTone(for sound: Sound) {
        startEngineIfNeeded()
        guard ready else { return }
        let key = "\(sound)"
        let buffer: AVAudioPCMBuffer
        if let cached = buffers[key] {
            buffer = cached
        } else {
            guard let made = render(notes(for: sound)) else { return }
            buffers[key] = made
            buffer = made
        }
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    private func render(_ notes: [Note]) -> AVAudioPCMBuffer? {
        let rate = format.sampleRate
        let total = notes.reduce(0.0) { $0 + $1.duration } + 0.05
        let frames = AVAudioFrameCount(total * rate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        guard let data = buffer.floatChannelData?[0] else { return nil }
        for i in 0..<Int(frames) { data[i] = 0 }
        var offset = 0
        var seed: UInt32 = 12345
        for note in notes {
            let n = Int(note.duration * rate)
            var pluckBuffer: [Float] = []
            if note.kind == .pluck {
                let period = max(2, Int(rate / note.freq))
                pluckBuffer = (0..<period).map { _ in seed = seed &* 1_664_525 &+ 1_013_904_223; return Float(Double(seed) / Double(UInt32.max) * 2 - 1) }
            }
            for i in 0..<n {
                let t = Double(i) / rate
                let env: Double = {
                    let a = min(1, t / note.attack)
                    let release = note.duration * 0.55
                    let r = t > note.duration - release ? max(0, (note.duration - t) / release) : 1
                    return a * r
                }()
                var sample: Double
                switch note.kind {
                case .sine: sample = sin(2 * .pi * note.freq * t)
                case .triangle:
                    let phase = (note.freq * t).truncatingRemainder(dividingBy: 1)
                    sample = 4 * abs(phase - 0.5) - 1
                case .noise:
                    seed = seed &* 1_664_525 &+ 1_013_904_223
                    sample = Double(seed) / Double(UInt32.max) * 2 - 1
                case .pluck:
                    // Karplus-Strong string.
                    let idx = i % pluckBuffer.count
                    let next = (i + 1) % pluckBuffer.count
                    let v = pluckBuffer[idx]
                    pluckBuffer[idx] = 0.5 * (pluckBuffer[idx] + pluckBuffer[next]) * 0.996
                    sample = Double(v)
                }
                let index = offset + i
                if index < Int(frames) { data[index] += Float(sample * env * note.volume) }
            }
            offset += n
        }
        return buffer
    }
}
