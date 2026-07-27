import SwiftUI

struct MatchReviewView: View {
    @Environment(\.dismiss) private var dismiss
    let resultText: String
    let review: MatchReview
    var onRematch: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text(L10n.t(.reviewTitle))
                            .font(.title2.bold())
                        Text(resultText)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text(L10n.t(.reviewExplainer))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    HStack(spacing: 12) {
                        accuracyCard(review.white)
                        accuracyCard(review.black)
                    }

                    if let moves = review.moves, !moves.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.t(.reviewMovePrecision))
                                .font(.headline)
                            ForEach(Array(moves.enumerated()), id: \.element.id) { index, move in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1).")
                                        .font(.subheadline.weight(.bold))
                                        .frame(width: 28, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(moveLine(move))
                                            .font(.subheadline.weight(.semibold))
                                        Text(detailLine(move))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(move.precision ?? 0)%")
                                        .font(.headline.monospacedDigit())
                                        .foregroundStyle(color(for: move.precision ?? 0))
                                }
                                .padding(10)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    } else {
                        Text(L10n.t(.reviewNoMoves))
                            .foregroundStyle(.secondary)
                    }

                    if let onRematch {
                        Button {
                            dismiss()
                            onRematch()
                        } label: {
                            Label(L10n.t(.rematch), systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle(L10n.t(.matchReview))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t(.done)) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func accuracyCard(_ player: PlayerReview?) -> some View {
        let accuracy = player?.accuracy ?? 0
        VStack(spacing: 8) {
            Text(player?.name ?? "Player")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text("\(accuracy)%")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(color(for: accuracy))
            Text(L10n.t(.reviewAccuracy))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let unaided = player?.unaidedAccuracy, (player?.assistedCount ?? 0) > 0 {
                Text(L10n.t(.reviewUnaided, unaided))
                    .font(.caption2.weight(.semibold))
            }
            Text(L10n.t(.reviewMoves, player?.moveCount ?? 0))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func moveLine(_ move: MoveReviewEntry) -> String {
        let who = (move.by ?? "").capitalized
        let path = "\((move.from ?? "").uppercased()) → \((move.to ?? "").uppercased())"
        let san = move.san.map { " (\($0))" } ?? ""
        return "\(who) \(path)\(san)"
    }

    private func detailLine(_ move: MoveReviewEntry) -> String {
        var parts = [move.label ?? "Played"]
        if move.assisted == true {
            parts.append(L10n.t(.reviewComputerHelped))
        }
        return parts.joined(separator: " · ")
    }

    private func color(for precision: Int) -> Color {
        if precision >= 85 { return .green }
        if precision >= 70 { return .blue }
        if precision >= 55 { return .orange }
        return .red
    }
}
