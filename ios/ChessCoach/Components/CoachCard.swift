// Move Guide matched to Duolingo Chess coach https://mobbin.com/screens/82e91d14-d239-4007-afc3-57dc0be96bde
// Speech-bubble grouping also follows Equinox Concierge https://mobbin.com/screens/55b4f1e2-4c64-41f8-8274-e4ffa2cc8f6c

import SwiftUI

struct CoachCard: View {
    let message: String
    let source: String
    var onHistory: (() -> Void)? = nil
    var onMinimize: (() -> Void)? = nil

    private var sourceLabel: String {
        switch source.lowercased() {
        case "ai": return L10n.t(.coachAI)
        case "lesson": return L10n.t(.coachLesson)
        default: return L10n.t(.coachQuick)
        }
    }

    private var sourceColor: Color {
        switch source.lowercased() {
        case "ai": return .green
        case "lesson": return DuoAccent.base
        default: return Color(red: 0.95, green: 0.62, blue: 0.18)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DuoAccent.base)
                Text(L10n.t(.moveGuide).uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DuoAccent.base)
                    .tracking(0.8)
                Spacer()
                DuoChip(text: sourceLabel, tint: sourceColor)
                if let onMinimize {
                    Button(action: onMinimize) {
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Minimize Move Guide")
                }
            }

            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(DuoAccent.lavenderWash)
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DuoAccent.base)
                }
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.systemBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            }

            if let onHistory {
                Button(action: onHistory) {
                    Label(L10n.t(.coachHistory), systemImage: "clock.arrow.circlepath")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DuoAccent.base)
                }
            }
        }
        .padding(16)
        .duoCard(radius: 22)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Move Guide, \(sourceLabel). \(message)")
    }
}
