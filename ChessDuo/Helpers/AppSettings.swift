import SwiftUI
import UIKit
import Combine

/// All user preferences, persisted to UserDefaults. One shared instance is injected as an environment object.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    @Published var playerName: String { didSet { defaults.set(playerName, forKey: "player.name") } }
    @Published var language: AppLanguage { didSet { defaults.set(language.rawValue, forKey: "app.language"); languageTick += 1 } }
    /// Bumped whenever the language changes so views re-render their strings.
    @Published var languageTick = 0
    @Published var appearance: AppearanceMode {
        didSet {
            defaults.set(appearance.rawValue, forKey: "app.appearance")
            applyAppearanceToWindows()
        }
    }
    @Published var boardTheme: BoardTheme { didSet { defaults.set(boardTheme.rawValue, forKey: "board.theme") } }
    @Published var pieceStyle: PieceStyle { didSet { defaults.set(pieceStyle.rawValue, forKey: "board.pieces") } }
    @Published var customLightHex: String { didSet { defaults.set(customLightHex, forKey: "board.customLight") } }
    @Published var customDarkHex: String { didSet { defaults.set(customDarkHex, forKey: "board.customDark") } }
    @Published var prefers3D: Bool { didSet { defaults.set(prefers3D, forKey: "board.3d") } }
    @Published var cameraPreset: CameraPreset { didSet { defaults.set(cameraPreset.rawValue, forKey: "board.camera") } }
    @Published var showCoordinates: Bool { didSet { defaults.set(showCoordinates, forKey: "board.coords") } }
    @Published var showLegalMoves: Bool { didSet { defaults.set(showLegalMoves, forKey: "board.legal") } }
    @Published var highlightLastMove: Bool { didSet { defaults.set(highlightLastMove, forKey: "board.lastMove") } }
    @Published var highlightThreats: Bool { didSet { defaults.set(highlightThreats, forKey: "board.threats") } }
    @Published var confirmMoves: Bool { didSet { defaults.set(confirmMoves, forKey: "board.confirm") } }
    @Published var autoQueen: Bool { didSet { defaults.set(autoQueen, forKey: "board.autoQueen") } }
    @Published var animations: Bool { didSet { defaults.set(animations, forKey: "board.animations") } }
    @Published var hintsEnabled: Bool { didSet { defaults.set(hintsEnabled, forKey: "assist.hints") } }
    @Published var moveGuide: Bool { didSet { defaults.set(moveGuide, forKey: "assist.guide") } }
    @Published var coachCard: Bool { didSet { defaults.set(coachCard, forKey: "assist.coach") } }
    @Published var playForMe: Bool { didSet { defaults.set(playForMe, forKey: "assist.playForMe") } }
    @Published var assistLevel: EngineLevel { didSet { defaults.set(assistLevel.rawValue, forKey: "assist.level") } }
    @Published var sounds: Bool { didSet { defaults.set(sounds, forKey: "fx.sounds") } }
    @Published var haptics: Bool { didSet { defaults.set(haptics, forKey: "fx.haptics") } }
    @Published var clockWarning: Bool { didSet { defaults.set(clockWarning, forKey: "fx.clockWarning") } }
    @Published var turnNotifications: Bool { didSet { defaults.set(turnNotifications, forKey: "push.turn") } }
    @Published var computerLevel: EngineLevel { didSet { defaults.set(computerLevel.rawValue, forKey: "computer.level") } }
    @Published var hasOnboarded: Bool { didSet { defaults.set(hasOnboarded, forKey: "app.onboarded") } }
    @Published var localAutoFlip: Bool { didSet { defaults.set(localAutoFlip, forKey: "local.autoFlip") } }

    private init() {
        let d = UserDefaults.standard
        let bool: (String, Bool) -> Bool = { key, fallback in d.object(forKey: key) as? Bool ?? fallback }
        playerName = d.string(forKey: "player.name") ?? ""
        language = d.string(forKey: "app.language").flatMap(AppLanguage.init) ?? .system
        appearance = d.string(forKey: "app.appearance").flatMap(AppearanceMode.init) ?? .system
        boardTheme = d.string(forKey: "board.theme").flatMap(BoardTheme.init) ?? .walnut
        pieceStyle = d.string(forKey: "board.pieces").flatMap(PieceStyle.init) ?? .classic
        customLightHex = d.string(forKey: "board.customLight") ?? "#EDE3C7"
        customDarkHex = d.string(forKey: "board.customDark") ?? "#73915E"
        prefers3D = bool("board.3d", true)
        cameraPreset = d.string(forKey: "board.camera").flatMap(CameraPreset.init) ?? .mid
        showCoordinates = bool("board.coords", true)
        showLegalMoves = bool("board.legal", true)
        highlightLastMove = bool("board.lastMove", true)
        highlightThreats = bool("board.threats", false)
        confirmMoves = bool("board.confirm", false)
        autoQueen = bool("board.autoQueen", false)
        animations = bool("board.animations", true)
        hintsEnabled = bool("assist.hints", false)
        moveGuide = bool("assist.guide", false)
        coachCard = bool("assist.coach", true)
        playForMe = bool("assist.playForMe", false)
        assistLevel = EngineLevel(rawValue: d.integer(forKey: "assist.level")) ?? .club
        sounds = bool("fx.sounds", true)
        haptics = bool("fx.haptics", true)
        clockWarning = bool("fx.clockWarning", true)
        turnNotifications = bool("push.turn", true)
        computerLevel = EngineLevel(rawValue: d.integer(forKey: "computer.level")) ?? .casual
        hasOnboarded = bool("app.onboarded", false)
        localAutoFlip = bool("local.autoFlip", false)
    }

    /// When the synced settings last changed on this device. Not itself part of the blob.
    var syncedSettingsUpdatedAt: Date? {
        get { defaults.object(forKey: "sync.settingsUpdatedAt") as? Date }
        set { defaults.set(newValue, forKey: "sync.settingsUpdatedAt") }
    }

    var synced: SyncedSettings {
        SyncedSettings(
            playerName: playerName, language: language.rawValue, appearance: appearance.rawValue,
            boardTheme: boardTheme.rawValue, pieceStyle: pieceStyle.rawValue, customLightHex: customLightHex, customDarkHex: customDarkHex,
            prefers3D: prefers3D, cameraPreset: cameraPreset.rawValue, showCoordinates: showCoordinates, showLegalMoves: showLegalMoves,
            highlightLastMove: highlightLastMove, highlightThreats: highlightThreats, confirmMoves: confirmMoves, autoQueen: autoQueen,
            animations: animations, hintsEnabled: hintsEnabled, moveGuide: moveGuide, coachCard: coachCard, playForMe: playForMe,
            assistLevel: assistLevel.rawValue, sounds: sounds, haptics: haptics, clockWarning: clockWarning,
            turnNotifications: turnNotifications, computerLevel: computerLevel.rawValue, localAutoFlip: localAutoFlip
        )
    }

    /// Applies a synced blob. Unknown or missing values keep the current setting; unchanged values are
    /// not reassigned so the language re-render only happens when the language really changes.
    func apply(_ s: SyncedSettings) {
        func set<T: Equatable>(_ path: ReferenceWritableKeyPath<AppSettings, T>, _ value: T?) {
            if let value, self[keyPath: path] != value { self[keyPath: path] = value }
        }
        set(\.playerName, s.playerName.flatMap { $0.isEmpty ? nil : $0 })
        set(\.appearance, s.appearance.flatMap(AppearanceMode.init))
        set(\.boardTheme, s.boardTheme.flatMap(BoardTheme.init))
        set(\.pieceStyle, s.pieceStyle.flatMap(PieceStyle.init))
        set(\.customLightHex, s.customLightHex)
        set(\.customDarkHex, s.customDarkHex)
        set(\.prefers3D, s.prefers3D)
        set(\.cameraPreset, s.cameraPreset.flatMap(CameraPreset.init))
        set(\.showCoordinates, s.showCoordinates)
        set(\.showLegalMoves, s.showLegalMoves)
        set(\.highlightLastMove, s.highlightLastMove)
        set(\.highlightThreats, s.highlightThreats)
        set(\.confirmMoves, s.confirmMoves)
        set(\.autoQueen, s.autoQueen)
        set(\.animations, s.animations)
        set(\.hintsEnabled, s.hintsEnabled)
        set(\.moveGuide, s.moveGuide)
        set(\.coachCard, s.coachCard)
        set(\.playForMe, s.playForMe)
        set(\.assistLevel, s.assistLevel.flatMap(EngineLevel.init))
        set(\.sounds, s.sounds)
        set(\.haptics, s.haptics)
        set(\.clockWarning, s.clockWarning)
        set(\.turnNotifications, s.turnNotifications)
        set(\.computerLevel, s.computerLevel.flatMap(EngineLevel.init))
        set(\.localAutoFlip, s.localAutoFlip)
        set(\.language, s.language.flatMap(AppLanguage.init))
    }

    var lightSquare: Color { boardTheme == .custom ? (Color(hex: customLightHex) ?? BoardTheme.classic.light) : boardTheme.light }
    var darkSquare: Color { boardTheme == .custom ? (Color(hex: customDarkHex) ?? BoardTheme.classic.dark) : boardTheme.dark }

    var displayName: String {
        let trimmed = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L10n.t("game.you") : trimmed
    }

    /// SwiftUI's `.preferredColorScheme` only reaches views already in the tree it's attached
    /// to — a `.sheet` or `.fullScreenCover` (its own hosting controller) can silently fall back
    /// to the system appearance. Setting `overrideUserInterfaceStyle` directly on every window
    /// bypasses that and forces Light/Dark everywhere, including modals and system controls like
    /// the share sheet.
    func applyAppearanceToWindows() {
        let style: UIUserInterfaceStyle
        switch appearance {
        case .system: style = .unspecified
        case .light: style = .light
        case .dark: style = .dark
        }
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}

/// The preferences that follow an account to a new phone. Raw values and optionals so a blob written
/// by a newer or older version still decodes. Onboarding state and push tokens stay on the device.
struct SyncedSettings: Codable, Equatable {
    var playerName: String?
    var language: String?
    var appearance: String?
    var boardTheme: String?
    var pieceStyle: String?
    var customLightHex: String?
    var customDarkHex: String?
    var prefers3D: Bool?
    var cameraPreset: String?
    var showCoordinates: Bool?
    var showLegalMoves: Bool?
    var highlightLastMove: Bool?
    var highlightThreats: Bool?
    var confirmMoves: Bool?
    var autoQueen: Bool?
    var animations: Bool?
    var hintsEnabled: Bool?
    var moveGuide: Bool?
    var coachCard: Bool?
    var playForMe: Bool?
    var assistLevel: Int?
    var sounds: Bool?
    var haptics: Bool?
    var clockWarning: Bool?
    var turnNotifications: Bool?
    var computerLevel: Int?
    var localAutoFlip: Bool?
}
