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
        case "lesson": return .blue
        default: return .orange
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.16))
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.yellow)
            }
            .frame(width: 38, height: 38)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(L10n.t(.moveGuide))
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    DuoChip(text: sourceLabel, tint: sourceColor)
                    if let onMinimize {
                        Button(action: onMinimize) {
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 26, height: 26)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.6))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Minimize Move Guide")
                    }
                }
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let onHistory {
                    Button(action: onHistory) {
                        Label(L10n.t(.coachHistory), systemImage: "clock.arrow.circlepath")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DuoAccent.base)
                    }
                }
            }
        }
        .padding(14)
        .duoCard(radius: 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Move Guide, \(sourceLabel). \(message)")
    }
}
