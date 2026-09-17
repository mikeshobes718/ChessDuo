import SwiftUI

struct PuzzleView: View {
    @StateObject private var session = PuzzleSession(puzzle: PuzzleLibrary.daily())
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    StatTile(title: L10n.t("home.stats.puzzles"), value: "\(history.stats.puzzlesSolved)", icon: "puzzlepiece.fill", tint: Duo.sky)
                    StatTile(title: L10n.t("home.stats.streak"), value: "\(history.stats.puzzleStreak)", icon: "flame.fill", tint: Duo.rose)
                    StatTile(title: "Rating", value: "\(history.stats.puzzleRating)", icon: "chart.line.uptrend.xyaxis", tint: Duo.mint)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.isDaily ? L10n.t("puzzle.daily") : session.themeTitle).font(.headline)
                        Text("\(L10n.t("puzzle.toMove", L10n.colorName(session.solverColor))) · \(session.themeTitle) · \(session.puzzle.rating)").font(.caption).foregroundStyle(Duo.secondaryText(scheme))
                    }
                    Spacer()
                    Menu {
                        Button(L10n.t("puzzle.all")) { session.themeFilter = nil }
                        Button(L10n.t("puzzle.mateIn1")) { session.themeFilter = .mateInOne }
                        Button(L10n.t("puzzle.mateIn2")) { session.themeFilter = .mateInTwo }
                        Button(L10n.t("puzzle.winMaterial")) { session.themeFilter = .winMaterial }
                    } label: { Label(L10n.t("puzzle.theme"), systemImage: "line.3.horizontal.decrease.circle").font(.subheadline) }
                    Button { session.use3D.toggle() } label: { Text(session.use3D ? "2D" : "3D").font(.caption.weight(.bold)) }.buttonStyle(DuoIconButtonStyle(active: session.use3D)).accessibilityIdentifier("puzzle.3d")
                }
                .padding(.horizontal, 4)
                ChessBoardContainer(position: session.position, interaction: session.interaction, use3D: session.use3D, onTap: { session.tap($0) }, onDrop: { session.drop(from: $0, to: $1) })
                HStack(spacing: 8) {
                    Image(systemName: icon).foregroundStyle(color)
                    Text(session.message).font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .duoCard(padding: 12)
                .animation(.easeInOut, value: session.message)
                HStack(spacing: 10) {
                    if session.solved || session.showingSolution {
                        Button(L10n.t("puzzle.next")) { session.next() }.buttonStyle(DuoPrimaryButtonStyle(tint: Duo.mint))
                        Button(L10n.t("puzzle.retry")) { session.retry() }.buttonStyle(DuoSecondaryButtonStyle())
                    } else {
                        Button { session.hint() } label: { Label(L10n.t("game.hint"), systemImage: "lightbulb.fill") }.buttonStyle(DuoSecondaryButtonStyle())
                        Button { session.showSolution() } label: { Label(L10n.t("puzzle.showSolution"), systemImage: "eye.fill") }.buttonStyle(DuoSecondaryButtonStyle())
                        Button { session.next() } label: { Label(L10n.t("puzzle.random"), systemImage: "shuffle") }.buttonStyle(DuoSecondaryButtonStyle())
                    }
                }
                Text(L10n.t("puzzle.solvedCount", history.stats.solvedPuzzleIDs.count) + " / \(PuzzleLibrary.valid.count)").font(.caption).foregroundStyle(Duo.secondaryText(scheme))
            }
            .padding()
        }
        .duoBackground()
        .navigationTitle(L10n.t("puzzle.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $session.pendingPromotion) { p in PromotionSheet(color: p.color) { session.completePromotion($0) } }
    }

    private var icon: String {
        switch session.messageStyle {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        default: return "target"
        }
    }
    private var color: Color {
        switch session.messageStyle {
        case .success: return Duo.mint
        case .error: return Duo.danger
        default: return Duo.accent
        }
    }
}
