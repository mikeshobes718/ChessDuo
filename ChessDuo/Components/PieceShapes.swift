import SwiftUI

/// Vector chess pieces drawn with paths in a 0...1 unit square (y grows downward).
struct PieceShape: Shape {
    let kind: PieceKind

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * w, y: rect.minY + y * h) }
        func base(_ top: CGFloat) {
            p.addRoundedRect(in: CGRect(x: rect.minX + 0.20 * w, y: rect.minY + top * h, width: 0.60 * w, height: (0.90 - top) * h), cornerSize: CGSize(width: 0.04 * w, height: 0.04 * h))
        }
        switch kind {
        case .pawn:
            p.addEllipse(in: CGRect(x: rect.minX + 0.36 * w, y: rect.minY + 0.14 * h, width: 0.28 * w, height: 0.28 * h))
            p.move(to: pt(0.38, 0.40)); p.addLine(to: pt(0.62, 0.40)); p.addLine(to: pt(0.66, 0.70)); p.addLine(to: pt(0.34, 0.70)); p.closeSubpath()
            p.addRoundedRect(in: CGRect(x: rect.minX + 0.26 * w, y: rect.minY + 0.70 * h, width: 0.48 * w, height: 0.16 * h), cornerSize: CGSize(width: 0.04 * w, height: 0.04 * h))
        case .rook:
            p.move(to: pt(0.24, 0.14)); p.addLine(to: pt(0.34, 0.14)); p.addLine(to: pt(0.34, 0.22)); p.addLine(to: pt(0.44, 0.22)); p.addLine(to: pt(0.44, 0.14))
            p.addLine(to: pt(0.56, 0.14)); p.addLine(to: pt(0.56, 0.22)); p.addLine(to: pt(0.66, 0.22)); p.addLine(to: pt(0.66, 0.14)); p.addLine(to: pt(0.76, 0.14))
            p.addLine(to: pt(0.76, 0.30)); p.addLine(to: pt(0.68, 0.36)); p.addLine(to: pt(0.68, 0.68)); p.addLine(to: pt(0.76, 0.74)); p.addLine(to: pt(0.76, 0.86))
            p.addLine(to: pt(0.24, 0.86)); p.addLine(to: pt(0.24, 0.74)); p.addLine(to: pt(0.32, 0.68)); p.addLine(to: pt(0.32, 0.36)); p.addLine(to: pt(0.24, 0.30)); p.closeSubpath()
        case .knight:
            p.move(to: pt(0.30, 0.86)); p.addLine(to: pt(0.78, 0.86)); p.addLine(to: pt(0.78, 0.76))
            p.addCurve(to: pt(0.60, 0.30), control1: pt(0.78, 0.55), control2: pt(0.74, 0.38))
            p.addLine(to: pt(0.62, 0.18)); p.addLine(to: pt(0.52, 0.26)); p.addLine(to: pt(0.44, 0.12)); p.addLine(to: pt(0.40, 0.26))
            p.addCurve(to: pt(0.18, 0.52), control1: pt(0.28, 0.30), control2: pt(0.20, 0.40))
            p.addLine(to: pt(0.24, 0.60)); p.addLine(to: pt(0.34, 0.54))
            p.addCurve(to: pt(0.30, 0.76), control1: pt(0.40, 0.60), control2: pt(0.34, 0.70))
            p.closeSubpath()
        case .bishop:
            p.addEllipse(in: CGRect(x: rect.minX + 0.44 * w, y: rect.minY + 0.08 * h, width: 0.12 * w, height: 0.12 * h))
            p.move(to: pt(0.50, 0.18))
            p.addCurve(to: pt(0.68, 0.50), control1: pt(0.70, 0.26), control2: pt(0.74, 0.40))
            p.addCurve(to: pt(0.50, 0.62), control1: pt(0.64, 0.58), control2: pt(0.58, 0.62))
            p.addCurve(to: pt(0.32, 0.50), control1: pt(0.42, 0.62), control2: pt(0.36, 0.58))
            p.addCurve(to: pt(0.50, 0.18), control1: pt(0.26, 0.40), control2: pt(0.30, 0.26))
            p.closeSubpath()
            p.move(to: pt(0.36, 0.64)); p.addLine(to: pt(0.64, 0.64)); p.addLine(to: pt(0.68, 0.74)); p.addLine(to: pt(0.32, 0.74)); p.closeSubpath()
            p.addRoundedRect(in: CGRect(x: rect.minX + 0.24 * w, y: rect.minY + 0.74 * h, width: 0.52 * w, height: 0.12 * h), cornerSize: CGSize(width: 0.03 * w, height: 0.03 * h))
        case .queen:
            for (i, x) in [0.16, 0.33, 0.50, 0.67, 0.84].enumerated() {
                let y: CGFloat = (i == 2) ? 0.08 : (i == 1 || i == 3 ? 0.14 : 0.22)
                p.addEllipse(in: CGRect(x: rect.minX + (x - 0.05) * w, y: rect.minY + (y - 0.05) * h, width: 0.10 * w, height: 0.10 * h))
            }
            p.move(to: pt(0.16, 0.24)); p.addLine(to: pt(0.30, 0.52)); p.addLine(to: pt(0.33, 0.16)); p.addLine(to: pt(0.44, 0.50)); p.addLine(to: pt(0.50, 0.10))
            p.addLine(to: pt(0.56, 0.50)); p.addLine(to: pt(0.67, 0.16)); p.addLine(to: pt(0.70, 0.52)); p.addLine(to: pt(0.84, 0.24)); p.addLine(to: pt(0.74, 0.62)); p.addLine(to: pt(0.26, 0.62)); p.closeSubpath()
            p.move(to: pt(0.28, 0.64)); p.addLine(to: pt(0.72, 0.64)); p.addLine(to: pt(0.76, 0.74)); p.addLine(to: pt(0.24, 0.74)); p.closeSubpath()
            p.addRoundedRect(in: CGRect(x: rect.minX + 0.20 * w, y: rect.minY + 0.74 * h, width: 0.60 * w, height: 0.12 * h), cornerSize: CGSize(width: 0.03 * w, height: 0.03 * h))
        case .king:
            p.addRect(CGRect(x: rect.minX + 0.46 * w, y: rect.minY + 0.04 * h, width: 0.08 * w, height: 0.20 * h))
            p.addRect(CGRect(x: rect.minX + 0.40 * w, y: rect.minY + 0.09 * h, width: 0.20 * w, height: 0.07 * h))
            p.move(to: pt(0.50, 0.26))
            p.addCurve(to: pt(0.76, 0.40), control1: pt(0.60, 0.22), control2: pt(0.78, 0.26))
            p.addCurve(to: pt(0.62, 0.62), control1: pt(0.76, 0.52), control2: pt(0.68, 0.58))
            p.addLine(to: pt(0.38, 0.62))
            p.addCurve(to: pt(0.24, 0.40), control1: pt(0.32, 0.58), control2: pt(0.24, 0.52))
            p.addCurve(to: pt(0.50, 0.26), control1: pt(0.22, 0.26), control2: pt(0.40, 0.22))
            p.closeSubpath()
            p.move(to: pt(0.34, 0.64)); p.addLine(to: pt(0.66, 0.64)); p.addLine(to: pt(0.70, 0.74)); p.addLine(to: pt(0.30, 0.74)); p.closeSubpath()
            p.addRoundedRect(in: CGRect(x: rect.minX + 0.22 * w, y: rect.minY + 0.74 * h, width: 0.56 * w, height: 0.12 * h), cornerSize: CGSize(width: 0.03 * w, height: 0.03 * h))
        }
        return p
    }
}

/// A rendered piece in the chosen style.
struct PieceView: View {
    let piece: Piece
    var style: PieceStyle = .classic
    var size: CGFloat

    var body: some View {
        Group {
            switch style {
            case .classic:
                ZStack {
                    Text(piece.kind.unicodeBlack)
                        .font(.system(size: size * 0.86))
                        .foregroundStyle(piece.color == .white ? Color(red: 0.99, green: 0.98, blue: 0.95) : Color(red: 0.11, green: 0.10, blue: 0.12))
                        .shadow(color: piece.color == .white ? Color.black.opacity(0.75) : Color.white.opacity(0.35), radius: size * 0.025, x: 0, y: 0)
                        .shadow(color: .black.opacity(0.35), radius: size * 0.03, x: 0, y: size * 0.03)
                }
            case .modern:
                ZStack {
                    PieceShape(kind: piece.kind)
                        .fill(piece.color == .white ? Color(red: 0.97, green: 0.96, blue: 0.93) : Color(red: 0.16, green: 0.15, blue: 0.18))
                        .shadow(color: .black.opacity(0.3), radius: size * 0.03, y: size * 0.03)
                    PieceShape(kind: piece.kind)
                        .stroke(piece.color == .white ? Color(red: 0.25, green: 0.22, blue: 0.20) : Color(red: 0.85, green: 0.82, blue: 0.78).opacity(0.7), lineWidth: max(1, size * 0.03))
                }
            case .minimal:
                PieceShape(kind: piece.kind)
                    .fill(piece.color == .white ? Color.white : Color.black)
                    .overlay(PieceShape(kind: piece.kind).stroke(piece.color == .white ? Color.black.opacity(0.7) : Color.white.opacity(0.35), lineWidth: max(1, size * 0.025)))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(L10n.colorName(piece.color)) \(L10n.pieceName(piece.kind))")
    }
}
