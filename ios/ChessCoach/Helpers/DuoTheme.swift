import SwiftUI
import UIKit

enum DuoAccent {
    static let base = Color(red: 0.36, green: 0.18, blue: 0.55)
    static let glow = Color(red: 0.78, green: 0.38, blue: 0.48)
    static let rose = Color(red: 0.86, green: 0.42, blue: 0.48)
    static let cream = Color(red: 0.99, green: 0.97, blue: 0.94)
    static let lavenderWash = Color(red: 0.93, green: 0.89, blue: 0.98)
    static let coralWash = Color(red: 0.98, green: 0.90, blue: 0.90)
    // Cream in dark, deep ink in light. Use this (not base) on glass, toolbars, and secondary buttons.
    // Matched to Apple Games invite https://mobbin.com/screens/f5527923-67ad-4b8a-8060-42af8acd9901
    static let ink = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.96, green: 0.94, blue: 0.98, alpha: 1)
            : UIColor(red: 0.14, green: 0.10, blue: 0.20, alpha: 1)
    })

    static let muted = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.80, green: 0.76, blue: 0.84, alpha: 1)
            : UIColor.secondaryLabel
    })

    static var gradient: LinearGradient {
        LinearGradient(
            colors: [base, Color(red: 0.48, green: 0.24, blue: 0.68)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var horizontalGradient: LinearGradient {
        LinearGradient(
            colors: [base, Color(red: 0.52, green: 0.28, blue: 0.70), glow],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

enum DuoSpace {
    static let screen: CGFloat = 20
    static let card: CGFloat = 16
    static let stack: CGFloat = 14
    static let row: CGFloat = 12
    static let tight: CGFloat = 8
}

enum DuoRadius {
    static let sheet: CGFloat = 28
    static let card: CGFloat = 22
    static let tile: CGFloat = 16
    static let field: CGFloat = 14
    static let pill: CGFloat = 28
}

enum DuoGlass {
    static var hairline: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.62), Color.white.opacity(0.12)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var hairlineDark: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.24), Color.white.opacity(0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func hairlineStroke(scheme: ColorScheme) -> LinearGradient {
        scheme == .dark ? hairlineDark : hairline
    }
}

extension View {
    func duoCard(prominent: Bool = false, radius: CGFloat = DuoRadius.card) -> some View {
        modifier(DuoCardModifier(prominent: prominent, radius: radius, wash: nil))
    }

    func duoTintedCard(wash: Color, radius: CGFloat = DuoRadius.card) -> some View {
        modifier(DuoCardModifier(prominent: false, radius: radius, wash: wash))
    }

    func duoPrimaryButton() -> some View {
        modifier(DuoPrimaryButtonStyle())
    }

    func duoSecondaryButton() -> some View {
        modifier(DuoSecondaryButtonStyle())
    }

    func duoReadableWidth(_ width: CGFloat = 560) -> some View {
        frame(maxWidth: width)
            .frame(maxWidth: .infinity)
    }
}

private struct DuoCardModifier: ViewModifier {
    let prominent: Bool
    let radius: CGFloat
    let wash: Color?
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background {
                if prominent {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(DuoAccent.gradient)
                        .overlay {
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.24), Color.white.opacity(0)],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        }
                } else if let wash {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(wash.opacity(scheme == .dark ? 0.28 : 1))
                        .overlay {
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(.ultraThinMaterial.opacity(scheme == .dark ? 0.55 : 0.18))
                        }
                } else {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(DuoAccent.cream.opacity(scheme == .dark ? 0.04 : 0.55))
                        }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        prominent ? DuoGlass.hairline : DuoGlass.hairlineStroke(scheme: scheme),
                        lineWidth: 0.8
                    )
            }
            .shadow(
                color: prominent
                    ? DuoAccent.base.opacity(0.36)
                    : Color.black.opacity(scheme == .dark ? 0.32 : 0.07),
                radius: prominent ? 20 : 12,
                y: prominent ? 10 : 5
            )
    }
}

private struct DuoPrimaryButtonStyle: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(.white)
            .background {
                Capsule(style: .continuous)
                    .fill(
                        isEnabled
                            ? DuoAccent.gradient
                            : LinearGradient(
                                colors: [DuoAccent.base.opacity(0.40), DuoAccent.base.opacity(0.28)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.26), Color.white.opacity(0)],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.34), lineWidth: 0.8)
            }
            .shadow(color: DuoAccent.base.opacity(isEnabled ? 0.34 : 0.10), radius: 14, y: 7)
            .contentShape(Capsule(style: .continuous))
    }
}

private struct DuoSecondaryButtonStyle: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(DuoAccent.ink.opacity(isEnabled ? 1 : 0.45))
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(scheme == .dark ? 0.12 : 0.46))
                    }
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(DuoGlass.hairlineStroke(scheme: scheme), lineWidth: 0.8)
            }
            .shadow(color: Color.black.opacity(scheme == .dark ? 0.24 : 0.04), radius: 8, y: 3)
            .contentShape(Capsule(style: .continuous))
    }
}

struct DuoChip: View {
    let text: String
    var tint: Color = DuoAccent.base

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(DuoAccent.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.18), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.28), lineWidth: 0.6))
    }
}

struct DuoBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            (scheme == .dark
                ? Color(red: 0.10, green: 0.08, blue: 0.14)
                : DuoAccent.cream)
                .ignoresSafeArea()
            Circle()
                .fill(DuoAccent.base.opacity(scheme == .dark ? 0.34 : 0.16))
                .frame(width: 360, height: 360)
                .blur(radius: 78)
                .offset(x: -150, y: -240)
            Circle()
                .fill(DuoAccent.rose.opacity(scheme == .dark ? 0.18 : 0.12))
                .frame(width: 300, height: 300)
                .blur(radius: 86)
                .offset(x: 170, y: -170)
            Circle()
                .fill(DuoAccent.lavenderWash.opacity(scheme == .dark ? 0.12 : 0.55))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: 40, y: 340)
        }
    }
}

struct DuoSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(DuoAccent.ink)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(DuoAccent.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DuoSheetTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(DuoAccent.ink)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(DuoAccent.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DuoSpace.screen)
        .padding(.top, 10)
    }
}

struct DuoIconCircle: View {
    let systemImage: String
    var size: CGFloat = 46
    var prominent = false

    var body: some View {
        ZStack {
            Circle()
                .fill(prominent ? Color.white.opacity(0.22) : DuoAccent.base.opacity(0.16))
            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(prominent ? Color.white : DuoAccent.ink)
        }
        .frame(width: size, height: size)
    }
}

struct DuoEmptyState: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(DuoAccent.base.opacity(0.16))
                    .frame(width: 72, height: 72)
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(DuoAccent.ink)
            }
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(DuoAccent.ink)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(DuoAccent.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DuoSpace.screen)
    }
}

struct DuoCodeBoxes: View {
    let code: String
    var boxCount: Int = 6

    private var characters: [String] {
        let cleaned = Array(code.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(boxCount))
        return (0..<boxCount).map { index in
            index < cleaned.count ? String(cleaned[index]) : ""
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(characters.enumerated()), id: \.offset) { _, glyph in
                Text(glyph.isEmpty ? " " : glyph)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(DuoAccent.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            }
        }
        .accessibilityLabel("Room code \(code)")
    }
}

struct DuoToastBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.thinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.primary.opacity(0.08)))
    }
}

struct DuoLoadingCard: View {
    let text: String

    var body: some View {
        ProgressView(text)
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DuoRadius.tile, style: .continuous))
    }
}

extension Color {
    static let duoHero = DuoAccent.base
    static let duoHeroAlt = DuoAccent.glow
}
