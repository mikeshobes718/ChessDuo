import SwiftUI

enum DuoAccent {
    static let base = Color(red: 0.42, green: 0.31, blue: 0.95)
    static let glow = Color(red: 0.35, green: 0.75, blue: 0.85)

    static var gradient: LinearGradient {
        LinearGradient(
            colors: [base, glow],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var horizontalGradient: LinearGradient {
        LinearGradient(
            colors: [base, Color(red: 0.20, green: 0.55, blue: 0.90), glow],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

enum DuoGlass {
    static var hairline: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.55), Color.white.opacity(0.10)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var hairlineDark: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.22), Color.white.opacity(0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func hairlineStroke(scheme: ColorScheme) -> LinearGradient {
        scheme == .dark ? hairlineDark : hairline
    }
}

extension View {
    func duoCard(prominent: Bool = false, radius: CGFloat = 24) -> some View {
        modifier(DuoCardModifier(prominent: prominent, radius: radius))
    }

    func duoPrimaryButton() -> some View {
        modifier(DuoPrimaryButtonStyle())
    }

    func duoSecondaryButton() -> some View {
        modifier(DuoSecondaryButtonStyle())
    }
}

private struct DuoCardModifier: ViewModifier {
    let prominent: Bool
    let radius: CGFloat
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
                                        colors: [Color.white.opacity(0.26), Color.white.opacity(0)],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        }
                } else {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(Color.white.opacity(scheme == .dark ? 0.03 : 0.28))
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
                color: prominent ? DuoAccent.base.opacity(0.42) : Color.black.opacity(scheme == .dark ? 0.35 : 0.08),
                radius: prominent ? 22 : 14,
                y: prominent ? 12 : 6
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
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        isEnabled
                            ? DuoAccent.gradient
                            : LinearGradient(
                                colors: [DuoAccent.base.opacity(0.45), DuoAccent.glow.opacity(0.45)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.30), Color.white.opacity(0)],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.38), lineWidth: 0.8)
            }
            .shadow(color: DuoAccent.base.opacity(isEnabled ? 0.40 : 0.12), radius: 16, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct DuoSecondaryButtonStyle: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(DuoAccent.base.opacity(isEnabled ? 1 : 0.5))
            .background {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(Color.white.opacity(scheme == .dark ? 0.02 : 0.22))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(DuoGlass.hairlineStroke(scheme: scheme), lineWidth: 0.8)
            }
            .shadow(color: Color.black.opacity(scheme == .dark ? 0.28 : 0.05), radius: 10, y: 4)
            .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }
}

struct DuoChip: View {
    let text: String
    var tint: Color = DuoAccent.base

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.14), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.25), lineWidth: 0.6))
    }
}

struct DuoBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            Circle()
                .fill(DuoAccent.base.opacity(scheme == .dark ? 0.22 : 0.16))
                .frame(width: 340, height: 340)
                .blur(radius: 70)
                .offset(x: -140, y: -230)
            Circle()
                .fill(DuoAccent.glow.opacity(scheme == .dark ? 0.18 : 0.13))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 160, y: -190)
            Circle()
                .fill(Color(red: 0.95, green: 0.45, blue: 0.65).opacity(scheme == .dark ? 0.10 : 0.07))
                .frame(width: 260, height: 260)
                .blur(radius: 90)
                .offset(x: 120, y: 320)
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
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DuoSheetTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
}

extension Color {
    static let duoHero = DuoAccent.base
    static let duoHeroAlt = DuoAccent.glow
}
