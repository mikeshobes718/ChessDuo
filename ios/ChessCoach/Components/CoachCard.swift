import SwiftUI

struct CoachCard: View {
    let message: String
    let source: String
    var onHistory: (() -> Void)? = nil

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
            Image(systemName: "lightbulb.fill")
                .font(.title3)
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(L10n.t(.moveGuide))
                        .font(.headline)
                    Spacer()
                    Text(sourceLabel)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(sourceColor.opacity(0.18), in: Capsule())
                        .foregroundStyle(sourceColor)
                }
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let onHistory {
                    Button(L10n.t(.coachHistory), action: onHistory)
                        .font(.caption.weight(.semibold))
                }
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Move Guide, \(sourceLabel). \(message)")
    }
}
