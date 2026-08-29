// Empty state matched to Apple Games Challenges https://mobbin.com/screens/0cfb504e-116d-4fbf-b0f3-b4c7ebf76aa9
// Match rows also follow Hinge Matches https://mobbin.com/screens/578eeee4-7fa6-4821-a55e-5d3bd53c93ef

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
                        VStack(alignment: .leading, spacing: 0) {
                            DuoEmptyState(
                                systemImage: "clock.arrow.circlepath",
                                title: L10n.t(.pastGamesEmpty),
                                detail: L10n.t(.pastGamesDetail)
                            )
                            Spacer()
                        }
                        .padding(.top, 28)
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(matches) { match in
                                    Button {
                                        selected = match
                                    } label: {
                                        VStack(alignment: .leading, spacing: 10) {
                                            HStack(alignment: .center, spacing: 12) {
                                                DuoIconCircle(systemImage: "crown.fill", size: 44)
                                                VStack(alignment: .leading, spacing: 3) {
                                                    Text("\(match.whiteName) vs \(match.blackName)")
                                                        .font(.headline)
                                                        .foregroundStyle(DuoAccent.ink)
                                                    Text(L10n.t(.roomPrefix, match.roomCode))
                                                        .font(.caption)
                                                        .foregroundStyle(DuoAccent.muted)
                                                }
                                                Spacer()
                                                DuoChip(text: match.resultText, tint: DuoAccent.base)
                                            }
                                            HStack {
                                                Text(match.endedAt, style: .date)
                                                Spacer()
                                                if let white = match.review.white?.accuracy,
                                                   let black = match.review.black?.accuracy {
                                                    Text("\(white)%  \(black)%")
                                                        .font(.caption.weight(.semibold))
                                                }
                                            }
                                            .font(.caption)
                                            .foregroundStyle(DuoAccent.muted)
                                        }
                                        .padding(16)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .duoCard()
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, DuoSpace.screen)
                            .padding(.vertical, 16)
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
                        .fontWeight(.semibold)
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
