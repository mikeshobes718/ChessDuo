import SwiftUI

enum BoardTheme: String, CaseIterable, Identifiable {
    case classic
    case walnut
    case ice
    case slate
    case colorblind
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return L10n.t(.themeClassic)
        case .walnut: return L10n.t(.themeWalnut)
        case .ice: return L10n.t(.themeIce)
        case .slate: return L10n.t(.themeSlate)
        case .colorblind: return L10n.t(.themeColorblind)
        case .custom: return L10n.t(.themeCustom)
        }
    }

    func lightSquare(custom: BoardCustomColors) -> Color {
        switch self {
        case .classic: return Color(red: 0.93, green: 0.89, blue: 0.78)
        case .walnut: return Color(red: 0.91, green: 0.80, blue: 0.64)
        case .ice: return Color(red: 0.86, green: 0.91, blue: 0.96)
        case .slate: return Color(red: 0.82, green: 0.84, blue: 0.86)
        case .colorblind: return Color(red: 0.82, green: 0.86, blue: 0.95)
        case .custom: return custom.light
        }
    }

    func darkSquare(custom: BoardCustomColors) -> Color {
        switch self {
        case .classic: return Color(red: 0.45, green: 0.57, blue: 0.37)
        case .walnut: return Color(red: 0.55, green: 0.35, blue: 0.22)
        case .ice: return Color(red: 0.35, green: 0.52, blue: 0.72)
        case .slate: return Color(red: 0.40, green: 0.45, blue: 0.50)
        case .colorblind: return Color(red: 0.35, green: 0.45, blue: 0.70)
        case .custom: return custom.dark
        }
    }
}

struct BoardCustomColors: Equatable {
    var light: Color
    var dark: Color

    static let `default` = BoardCustomColors(
        light: Color(red: 0.93, green: 0.89, blue: 0.78),
        dark: Color(red: 0.45, green: 0.57, blue: 0.37)
    )
}

enum PiecePalette {
    static let whiteFill = Color(red: 0.97, green: 0.97, blue: 0.95)
    static let whiteStroke = Color(red: 0.10, green: 0.10, blue: 0.10)
    static let blackFill = Color(red: 0.12, green: 0.12, blue: 0.12)
    static let blackStroke = Color(red: 0.92, green: 0.92, blue: 0.90)

    static let lastMove = Color.yellow.opacity(0.38)
    static let hint = Color.cyan.opacity(0.38)
    static let threat = Color.red.opacity(0.24)
    static let selected = Color.accentColor.opacity(0.34)
    static let legal = Color.accentColor
    static let checkPulse = Color.red.opacity(0.55)
    static let winPulse = Color(red: 0.20, green: 0.72, blue: 0.40).opacity(0.45)
    static let pressureGlow = Color.orange.opacity(0.28)
}

struct PieceGlyphView: View {
    let piece: ChessPiece
    let size: CGFloat

    var body: some View {
        let fill = piece.isWhite ? PiecePalette.whiteFill : PiecePalette.blackFill
        let stroke = piece.isWhite ? PiecePalette.whiteStroke : PiecePalette.blackStroke
        ZStack {
            Text(piece.glyph)
                .font(.system(size: size * 0.74))
                .foregroundStyle(stroke)
                .offset(x: 0.8, y: 0.8)
            Text(piece.glyph)
                .font(.system(size: size * 0.74))
                .foregroundStyle(stroke)
                .offset(x: -0.6, y: 0)
            Text(piece.glyph)
                .font(.system(size: size * 0.74))
                .foregroundStyle(stroke)
                .offset(x: 0, y: -0.6)
            Text(piece.glyph)
                .font(.system(size: size * 0.74))
                .foregroundStyle(fill)
        }
        .minimumScaleFactor(0.7)
        .accessibilityHidden(true)
    }
}
