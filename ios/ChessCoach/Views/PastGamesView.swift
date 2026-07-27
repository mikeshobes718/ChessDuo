import SwiftUI

struct PastGamesView: View {
    @EnvironmentObject private var model: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var matches: [ArchivedMatch] = []
    @State private var selected: ArchivedMatch?

    var body: some View {
        NavigationStack {
            ZStack {
                DuoBackground()

                Group {
                    if matches.isEmpty {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(DuoAccent.base.opacity(0.12))
                                    .frame(width: 78, height: 78)
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundStyle(DuoAccent.base)
                            }
                            Text(L10n.t(.pastGamesEmpty))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(matches) { match in
                                    Button {
                                        selected = match
                                    } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text("\(match.whiteName) vs \(match.blackName)")
                                                    .font(.headline)
                                                Spacer()
                                                DuoChip(text: match.resultText, tint: DuoAccent.base)
                                            }
                                            HStack {
                                                Text(L10n.t(.roomPrefix, match.roomCode))
                                                Spacer()
                                                Text(match.endedAt, style: .date)
                                            }
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            if let white = match.review.white?.accuracy,
                                               let black = match.review.black?.accuracy {
                                                HStack(spacing: 8) {
                                                    DuoChip(text: "\(match.whiteName) \(white)%", tint: .green)
                                                    DuoChip(text: "\(match.blackName) \(black)%", tint: .blue)
                                                }
                                            }
                                        }
                                        .padding(14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .duoCard()
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                    }
                }
            }
            .navigationTitle(L10n.t(.pastGames))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t(.done)) { dismiss() }
                }
            }
            .task {
                matches = await model.refreshPastGames()
            }
            .refreshable {
                matches = await model.refreshPastGames()
            }
            .sheet(item: $selected) { match in
                MatchReviewView(
                    resultText: match.resultText,
                    review: match.review
                )
            }
        }
    }
}
