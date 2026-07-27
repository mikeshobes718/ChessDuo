import SwiftUI

struct PastGamesView: View {
    @EnvironmentObject private var model: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var matches: [ArchivedMatch] = []
    @State private var selected: ArchivedMatch?

    var body: some View {
        NavigationStack {
            Group {
                if matches.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text(L10n.t(.pastGamesEmpty))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(matches) { match in
                        Button {
                            selected = match
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("\(match.whiteName) vs \(match.blackName)")
                                        .font(.headline)
                                    Spacer()
                                    Text(match.resultText)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)
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
                                    Text("\(match.whiteName) \(white)% · \(match.blackName) \(black)%")
                                        .font(.caption.weight(.semibold))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(L10n.t(.pastGames))
            .navigationBarTitleDisplayMode(.inline)
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
