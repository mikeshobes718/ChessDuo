import SwiftUI

struct GameOverSheet: View {
    let result: GameResult
    let whiteName: String
    let blackName: String
    let me: PieceColor?
    let moveCount: Int
    let review: ReviewSummary?
    let isReviewing: Bool
    let reviewProgress: Double
    var rematchTitle: String = L10n.t("game.rematch")
    var onRematch: (() -> Void)?
    var onReview: () -> Void
    var onShare: () -> Void
    var onClose: () -> Void
    @Environment(\.colorScheme) private var scheme

    private var headline: String {
        if let me {
            if result.winner == me { return L10n.t("over.youWin") }
            if result.winner == nil { return L10n.t("over.draw") }
            return L10n.t("over.youLose")
        }
        if let w = result.winner { return L10n.t("over.winner", w == .white ? whiteName : blackName) }
        return L10n.t("over.draw")
    }

    private var emoji: String {
        if let me {
            if result.winner == me { return "🏆" }
            if result.winner == nil { return "🤝" }
            return "😔"
        }
        return result.winner == nil ? "🤝" : "🏆"
    }

    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(Color.secondary.opacity(0.4)).frame(width: 40, height: 5).padding(.top, 8)
            Text(emoji).font(.system(size: 56))
            Text(headline).font(.largeTitle.weight(.heavy))
            Text(GameRecord.describe(result: result, white: whiteName, black: blackName)).font(.subheadline).foregroundStyle(Duo.secondaryText(scheme)).multilineTextAlignment(.center)
            Text(L10n.t("over.moves", moveCount)).font(.caption).foregroundStyle(Duo.secondaryText(scheme))

            if let review {
                HStack(spacing: 12) {
                    accuracyTile(name: whiteName, summary: review.white, color: .white)
                    accuracyTile(name: blackName, summary: review.black, color: .black)
                }
                .padding(.horizontal)
            } else if isReviewing {
                VStack(spacing: 6) {
                    ProgressView(value: reviewProgress).tint(Duo.accent)
                    Text(L10n.t("over.analyzing")).font(.caption).foregroundStyle(Duo.secondaryText(scheme))
                }
                .padding(.horizontal, 32)
            }

            VStack(spacing: 10) {
                if let onRematch {
                    Button(rematchTitle, action: onRematch).buttonStyle(DuoPrimaryButtonStyle())
                }
                HStack(spacing: 10) {
                    Button { onReview() } label: { Label(L10n.t("game.review"), systemImage: "chart.line.uptrend.xyaxis") }.buttonStyle(DuoSecondaryButtonStyle()).disabled(moveCount == 0)
                    Button { onShare() } label: { Label(L10n.t("game.share"), systemImage: "square.and.arrow.up") }.buttonStyle(DuoSecondaryButtonStyle())
                }
                Button(L10n.t("over.done"), action: onClose).buttonStyle(DuoSecondaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .duoBackground()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    private func accuracyTile(name: String, summary: PlayerReviewSummary, color: PieceColor) -> some View {
        VStack(spacing: 4) {
            Text(name).font(.caption.weight(.semibold)).lineLimit(1)
            Text("\(summary.accuracy)%").font(.title.weight(.heavy).monospacedDigit()).foregroundStyle(accuracyColor(summary.accuracy))
            Text(L10n.t("over.accuracy")).font(.caption2).foregroundStyle(Duo.secondaryText(scheme))
            HStack(spacing: 6) {
                Label("\(summary.best)", systemImage: "star.fill").foregroundStyle(Duo.mint)
                Label("\(summary.mistakes)", systemImage: "questionmark").foregroundStyle(.orange)
                Label("\(summary.blunders)", systemImage: "exclamationmark.2").foregroundStyle(Duo.danger)
            }
            .font(.caption2.weight(.bold))
            if summary.assisted > 0 {
                Text("\(L10n.t("review.unaided")) \(summary.unaidedAccuracy)%").font(.caption2).foregroundStyle(Duo.secondaryText(scheme))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Duo.card(scheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Duo.cardStroke(scheme), lineWidth: 1))
    }

    static func accuracyColor(_ v: Int) -> Color {
        switch v {
        case 85...: return Duo.mint
        case 65..<85: return Duo.accent
        default: return Duo.danger
        }
    }
    private func accuracyColor(_ v: Int) -> Color { Self.accuracyColor(v) }
}

/// Full match review: eval graph, move list with quality tags, tap to see position.
struct ReviewView: View {
    let record: GameRecord
    let review: ReviewSummary
    @State private var viewingPly: Int
    @State private var use3D = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings

    init(record: GameRecord, review: ReviewSummary) {
        self.record = record
        self.review = review
        _viewingPly = State(initialValue: record.moves.count)
    }

    private var game: ChessGame { record.game }
    private var position: Position { game.position(atPly: viewingPly) }

    private var interaction: BoardInteraction {
        var i = BoardInteraction()
        i.orientation = record.humanColor ?? .white
        i.interactive = false
        if viewingPly > 0, viewingPly <= record.moves.count {
            let m = record.moves[viewingPly - 1].move
            i.lastMove = (m.from, m.to)
        }
        i.checkSquare = position.isInCheck ? position.king(of: position.sideToMove) : nil
        return i
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        summary(record.whiteName, review.white)
                        summary(record.blackName, review.black)
                    }
                    EvalGraph(evals: review.evals, selected: viewingPly) { viewingPly = $0 }
                        .frame(height: 90)
                        .duoCard(padding: 8)
                    HStack(alignment: .top, spacing: 8) {
                        EvalBar(evalWhite: viewingPly < review.evals.count ? review.evals[viewingPly] : nil, orientation: record.humanColor ?? .white).frame(height: 300)
                        ChessBoardContainer(position: position, interaction: interaction, use3D: use3D, onTap: { _ in })
                    }
                    if viewingPly > 0, viewingPly <= review.moves.count {
                        let m = review.moves[viewingPly - 1]
                        HStack(spacing: 10) {
                            Text(m.san).font(.title3.weight(.bold).monospaced())
                            Text(m.quality.title).font(.subheadline.weight(.semibold)).foregroundStyle(MoveStrip.color(for: m.quality))
                            if m.assisted { Label(L10n.t("game.assisted"), systemImage: "cpu").font(.caption) }
                            Spacer()
                            if let best = m.bestSan, m.quality != .best, m.quality != .book {
                                Text(L10n.t("game.bestMove", best)).font(.caption.weight(.semibold)).foregroundStyle(Duo.mint)
                            }
                        }
                        .duoCard(padding: 12)
                    }
                    HStack(spacing: 12) {
                        Button { viewingPly = 0 } label: { Image(systemName: "backward.end.fill") }.buttonStyle(DuoIconButtonStyle()).accessibilityIdentifier("review.start")
                        Button { viewingPly = max(0, viewingPly - 1) } label: { Image(systemName: "chevron.left") }.buttonStyle(DuoIconButtonStyle())
                        Button { viewingPly = min(record.moves.count, viewingPly + 1) } label: { Image(systemName: "chevron.right") }.buttonStyle(DuoIconButtonStyle())
                        Button { viewingPly = record.moves.count } label: { Image(systemName: "forward.end.fill") }.buttonStyle(DuoIconButtonStyle()).accessibilityIdentifier("review.end")
                        Button { use3D.toggle() } label: { Text(use3D ? "2D" : "3D").font(.caption.weight(.bold)) }.buttonStyle(DuoIconButtonStyle(active: use3D))
                    }
                    MoveStrip(moves: record.moves, viewingPly: viewingPly, qualities: Dictionary(uniqueKeysWithValues: review.moves.map { ($0.ply, $0.quality) })) { viewingPly = $0 }
                        .duoCard(padding: 6)
                    Text(L10n.t("review.tapMove")).font(.caption).foregroundStyle(Duo.secondaryText(scheme))
                }
                .padding()
            }
            .duoBackground()
            .navigationTitle(L10n.t("review.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(L10n.t("close")) { dismiss() } } }
        }
    }

    private func summary(_ name: String, _ s: PlayerReviewSummary) -> some View {
        VStack(spacing: 4) {
            Text(name).font(.caption.weight(.semibold)).lineLimit(1)
            Text("\(s.accuracy)%").font(.title2.weight(.heavy).monospacedDigit()).foregroundStyle(GameOverSheet.accuracyColor(s.accuracy))
            HStack(spacing: 8) {
                tag("\(s.best)", MoveStrip.color(for: .best), "review.best")
                tag("\(s.inaccuracies)", MoveStrip.color(for: .inaccuracy), "review.inaccuracy")
                tag("\(s.mistakes)", MoveStrip.color(for: .mistake), "review.mistake")
                tag("\(s.blunders)", MoveStrip.color(for: .blunder), "review.blunder")
            }
        }
        .frame(maxWidth: .infinity)
        .duoCard(padding: 10)
    }

    private func tag(_ v: String, _ c: Color, _ key: String) -> some View {
        VStack(spacing: 0) {
            Text(v).font(.caption.weight(.bold)).foregroundStyle(c)
            Text(L10n.t(key)).font(.system(size: 8)).foregroundStyle(Duo.secondaryText(scheme)).lineLimit(1).minimumScaleFactor(0.6)
        }
    }
}

struct EvalGraph: View {
    let evals: [Int]
    let selected: Int
    let onSelect: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let n = max(1, evals.count - 1)
            let y: (Int) -> CGFloat = { e in
                let clamped = max(-800, min(800, abs(e) > Search.mateScore - 1000 ? (e > 0 ? 800 : -800) : e))
                return h / 2 - CGFloat(clamped) / 800 * (h / 2)
            }
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h / 2)); p.addLine(to: CGPoint(x: w, y: h / 2))
                }.stroke(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                Path { p in
                    guard !evals.isEmpty else { return }
                    p.move(to: CGPoint(x: 0, y: h))
                    for (i, e) in evals.enumerated() { p.addLine(to: CGPoint(x: CGFloat(i) / CGFloat(n) * w, y: y(e))) }
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.closeSubpath()
                }.fill(Color(red: 0.95, green: 0.94, blue: 0.90))
                Path { p in
                    guard !evals.isEmpty else { return }
                    p.move(to: CGPoint(x: 0, y: 0))
                    for (i, e) in evals.enumerated() { p.addLine(to: CGPoint(x: CGFloat(i) / CGFloat(n) * w, y: y(e))) }
                    p.addLine(to: CGPoint(x: w, y: 0))
                    p.closeSubpath()
                }.fill(Color(red: 0.18, green: 0.17, blue: 0.20))
                Rectangle().fill(Duo.accent).frame(width: 2).position(x: CGFloat(selected) / CGFloat(n) * w, y: h / 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                let idx = Int((v.location.x / w * CGFloat(n)).rounded())
                onSelect(max(0, min(evals.count - 1, idx)))
            })
        }
    }
}
