// Match review matched to Paired results https://mobbin.com/screens/bc0f0c0f-d7e6-4833-b143-b45032f3693f
// Stats grid also follows Quizlet results https://mobbin.com/screens/914f0481-4918-4b49-a99c-122998a9774d

import SwiftUI

struct MatchReviewView: View {
    @Environment(\.dismiss) private var dismiss
    let resultText: String
    let review: MatchReview
    var onRematch: (() -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
                DuoBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        hero
                        HStack(spacing: 12) {
                            accuracyCard(review.white, wash: DuoAccent.lavenderWash, tint: DuoAccent.base)
                            accuracyCard(review.black, wash: DuoAccent.coralWash, tint: DuoAccent.rose)
                        }
                        movesSection
                        if let onRematch {
                            Button {
                                dismiss()
                                onRematch()
                            } label: {
                                Label(L10n.t(.rematch), systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .duoPrimaryButton()
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, DuoSpace.screen)
                    .padding(.vertical, 18)
                    .duoReadableWidth()
                }
            }
            .navigationTitle(L10n.t(.matchReview))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t(.done)) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            Text(resultText)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(DuoAccent.gradient, in: Capsule())
            Text(L10n.t(.reviewExplainer))
                .font(.footnote)
                .foregroundStyle(DuoAccent.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .duoCard()
    }

    @ViewBuilder
    private var movesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DuoSectionHeader(title: L10n.t(.reviewMovePrecision))

            if let moves = review.moves, !moves.isEmpty {
                VStack(spacing: 10) {
                    ForEach(Array(moves.enumerated()), id: \.element.id) { index, move in
                        let precision = move.precision ?? 0
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .frame(width: 26, height: 26)
                                .background(Color(.systemBackground), in: Circle())
                                .overlay(Circle().stroke(Color.primary.opacity(0.06)))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(moveLine(move))
                                    .font(.subheadline.weight(.semibold))
                                Text(detailLine(move))
                                    .font(.caption)
                                    .foregroundStyle(DuoAccent.muted)
                            }
                            Spacer()
                            Text("\(precision)%")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(color(for: precision))
                        }
                        .padding(14)
                        .duoCard(radius: 16)
                    }
                }
            } else {
                Text(L10n.t(.reviewNoMoves))
                    .foregroundStyle(DuoAccent.muted)
                    .padding(14)
                    .duoCard()
            }
        }
    }

    @ViewBuilder
    private func accuracyCard(_ player: PlayerReview?, wash: Color, tint: Color) -> some View {
        let accuracy = player?.accuracy ?? 0
        VStack(spacing: 8) {
            Text(player?.name ?? "Player")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text("\(accuracy)%")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(color(for: accuracy))
            Text(L10n.t(.reviewAccuracy))
                .font(.caption)
                .foregroundStyle(DuoAccent.muted)
            if let unaided = player?.unaidedAccuracy, (player?.assistedCount ?? 0) > 0 {
                Text(L10n.t(.reviewUnaided, unaided))
                    .font(.caption2.weight(.semibold))
            }
            Text(L10n.t(.reviewMoves, player?.moveCount ?? 0))
                .font(.caption2)
                .foregroundStyle(DuoAccent.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .duoTintedCard(wash: wash, radius: 20)
        .overlay(alignment: .top) {
            Capsule()
                .fill(tint)
                .frame(width: 36, height: 4)
                .padding(.top, 8)
        }
    }

    private func moveLine(_ move: MoveReviewEntry) -> String {
        let who = (move.by ?? "").capitalized
        let path = "\((move.from ?? "").uppercased()) to \((move.to ?? "").uppercased())"
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
        if precision >= 70 { return DuoAccent.base }
        if precision >= 55 { return .orange }
        return .red
    }
}
