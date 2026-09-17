import SwiftUI

// MARK: - App-wide design tokens ("Duo" system): warm ink, cream paper, gold accent.

enum Duo {
    static let accent = Color(red: 0.86, green: 0.62, blue: 0.20)        // gold
    static let accentDeep = Color(red: 0.72, green: 0.48, blue: 0.10)
    static let ink = Color(red: 0.11, green: 0.12, blue: 0.17)
    static let plum = Color(red: 0.36, green: 0.22, blue: 0.42)
    static let rose = Color(red: 0.86, green: 0.36, blue: 0.44)
    static let teal = Color(red: 0.16, green: 0.58, blue: 0.56)
    static let mint = Color(red: 0.26, green: 0.72, blue: 0.52)
    static let danger = Color(red: 0.86, green: 0.27, blue: 0.27)
    static let sky = Color(red: 0.30, green: 0.56, blue: 0.86)

    static func background(_ scheme: ColorScheme) -> LinearGradient {
        if scheme == .dark {
            return LinearGradient(colors: [Color(red: 0.07, green: 0.08, blue: 0.13), Color(red: 0.12, green: 0.10, blue: 0.16)], startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(colors: [Color(red: 0.98, green: 0.96, blue: 0.92), Color(red: 0.95, green: 0.92, blue: 0.87)], startPoint: .top, endPoint: .bottom)
    }

    static func card(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.07) : Color.white.opacity(0.78)
    }

    static func cardStroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)
    }

    static func secondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.62) : Color.black.opacity(0.55)
    }
}

struct DuoCard: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Duo.card(scheme), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Duo.cardStroke(scheme), lineWidth: 1))
            .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.08), radius: 12, y: 6)
    }
}

extension View {
    func duoCard(padding: CGFloat = 16) -> some View { modifier(DuoCard(padding: padding)) }
    func duoBackground() -> some View { modifier(DuoBackground()) }
}

struct DuoBackground: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content.background(Duo.background(scheme).ignoresSafeArea())
    }
}

struct DuoPrimaryButtonStyle: ButtonStyle {
    var tint: Color = Duo.accent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(LinearGradient(colors: [tint, tint.opacity(0.82)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 1))
            .shadow(color: tint.opacity(0.35), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct DuoSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Duo.cardStroke(scheme), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct DuoIconButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    var active: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(active ? Color.white : Color.primary)
            .frame(width: 44, height: 44)
            .background(active ? Duo.accent : (scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.05)), in: Circle())
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Board themes

enum BoardTheme: String, CaseIterable, Identifiable, Codable {
    case classic, walnut, marble, ocean, forest, rose, slate, neon, colorblind, custom
    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return "Classic"
        case .walnut: return "Walnut"
        case .marble: return "Marble"
        case .ocean: return "Ocean"
        case .forest: return "Forest"
        case .rose: return "Rose"
        case .slate: return "Slate"
        case .neon: return "Neon"
        case .colorblind: return "High contrast"
        case .custom: return L10n.t("settings.customColors")
        }
    }

    var light: Color {
        switch self {
        case .classic: return Color(red: 0.93, green: 0.89, blue: 0.78)
        case .walnut: return Color(red: 0.91, green: 0.80, blue: 0.64)
        case .marble: return Color(red: 0.92, green: 0.92, blue: 0.90)
        case .ocean: return Color(red: 0.86, green: 0.91, blue: 0.96)
        case .forest: return Color(red: 0.90, green: 0.92, blue: 0.82)
        case .rose: return Color(red: 0.97, green: 0.90, blue: 0.90)
        case .slate: return Color(red: 0.82, green: 0.84, blue: 0.86)
        case .neon: return Color(red: 0.16, green: 0.17, blue: 0.24)
        case .colorblind: return Color(red: 0.95, green: 0.95, blue: 0.85)
        case .custom: return Color(red: 0.93, green: 0.89, blue: 0.78)
        }
    }

    var dark: Color {
        switch self {
        case .classic: return Color(red: 0.45, green: 0.57, blue: 0.37)
        case .walnut: return Color(red: 0.55, green: 0.35, blue: 0.22)
        case .marble: return Color(red: 0.50, green: 0.52, blue: 0.55)
        case .ocean: return Color(red: 0.35, green: 0.52, blue: 0.72)
        case .forest: return Color(red: 0.36, green: 0.49, blue: 0.32)
        case .rose: return Color(red: 0.72, green: 0.42, blue: 0.48)
        case .slate: return Color(red: 0.40, green: 0.45, blue: 0.50)
        case .neon: return Color(red: 0.30, green: 0.20, blue: 0.48)
        case .colorblind: return Color(red: 0.20, green: 0.35, blue: 0.65)
        case .custom: return Color(red: 0.45, green: 0.57, blue: 0.37)
        }
    }

    var frame: Color {
        switch self {
        case .walnut: return Color(red: 0.32, green: 0.20, blue: 0.12)
        case .marble, .slate: return Color(red: 0.25, green: 0.26, blue: 0.28)
        case .neon: return Color(red: 0.10, green: 0.10, blue: 0.16)
        case .rose: return Color(red: 0.40, green: 0.22, blue: 0.26)
        case .ocean: return Color(red: 0.16, green: 0.26, blue: 0.38)
        default: return Color(red: 0.30, green: 0.24, blue: 0.18)
        }
    }
}

enum PieceStyle: String, CaseIterable, Identifiable, Codable {
    case classic, modern, minimal
    var id: String { rawValue }
    var title: String { L10n.t("settings.pieces.\(rawValue)") }
}

enum AppearanceMode: String, CaseIterable, Identifiable, Codable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { L10n.t("settings.appearance.\(rawValue)") }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum CameraPreset: String, CaseIterable, Identifiable, Codable {
    case low, mid, high
    var id: String { rawValue }
    var title: String { L10n.t("settings.camera.\(rawValue)") }
    /// Elevation angle in degrees above the board.
    var elevation: Double {
        switch self {
        case .low: return 32
        case .mid: return 50
        case .high: return 78
        }
    }
}

extension Color {
    /// Hex like "#RRGGBB".
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }

    var hexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
