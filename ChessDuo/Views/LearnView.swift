import SwiftUI

struct LearnView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var scheme
    @State private var selectedKind: PieceKind = .knight
    @State private var demoSquare = Square(name: "d4")!

    private var demoPosition: Position {
        var p = Position(fen: "8/8/8/8/8/8/8/8 w - - 0 1") ?? Position()
        for i in 0..<64 { p.board[i] = nil }
        p[demoSquare] = Piece(.white, selectedKind)
        // Kings needed for legal move gen; park them out of the way.
        if selectedKind != .king { p[Square(name: "h1")!] = Piece(.white, .king) }
        p[Square(name: "h8")!] = Piece(.black, .king)
        if selectedKind == .pawn { p[Square(file: min(7, demoSquare.file + 1), rank: min(7, demoSquare.rank + 1))] = Piece(.black, .pawn) }
        p.castling = []
        return p
    }

    private var demoInteraction: BoardInteraction {
        var i = BoardInteraction()
        i.selected = demoSquare
        let pos = demoPosition
        let moves = pos.legalMoves(from: demoSquare)
        i.legalTargets = Set(moves.map(\.to))
        i.captureTargets = Set(moves.filter { pos.isCapture($0) }.map(\.to))
        return i
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(L10n.t("learn.pieces")).font(.title3.weight(.bold))
                HStack(spacing: 8) {
                    ForEach([PieceKind.king, .queen, .rook, .bishop, .knight, .pawn], id: \.self) { kind in
                        Button {
                            selectedKind = kind
                            Feedback.shared.selectionChanged()
                        } label: {
                            PieceView(piece: Piece(.white, kind), style: settings.pieceStyle, size: 40)
                                .padding(6)
                                .background(selectedKind == kind ? Duo.accent.opacity(0.35) : Duo.card(scheme), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selectedKind == kind ? Duo.accent : Duo.cardStroke(scheme)))
                        }.buttonStyle(.plain).accessibilityIdentifier("learn.\(kind.letter)")
                    }
                }
                .frame(maxWidth: .infinity)
                BoardView2D(position: demoPosition, interaction: demoInteraction, showCoordinates: true, onTap: { sq in
                    if demoPosition[sq] == nil || sq == demoSquare { demoSquare = sq; Feedback.shared.play(.move) }
                })
                .padding(6).background(RoundedRectangle(cornerRadius: 12).fill(settings.boardTheme.frame))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("board")
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.pieceName(selectedKind)).font(.headline)
                    Text(L10n.t("learn.\(name(selectedKind)).desc")).font(.subheadline)
                    Text(L10n.t("learn.tapSquare")).font(.caption).foregroundStyle(Duo.secondaryText(scheme))
                }
                .duoCard()

                Text(L10n.t("learn.rules")).font(.title3.weight(.bold)).padding(.top, 6)
                ruleCard("learn.castling", "arrow.left.arrow.right", fen: "r3k2r/pppq1ppp/2npbn2/4p3/4P3/2NPBN2/PPPQ1PPP/R3K2R w KQkq - 0 1")
                ruleCard("learn.enPassant", "figure.walk", fen: "8/8/8/3pP3/8/8/8/4K2k w - d6 0 1")
                ruleCard("learn.promotion", "crown.fill", fen: "8/4P3/8/8/8/8/8/4K2k w - - 0 1")
                ruleCard("learn.check", "exclamationmark.triangle.fill", fen: "6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1")
                ruleCard("learn.draws", "equal.circle.fill", fen: "7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")

                Text(L10n.t("learn.tips")).font(.title3.weight(.bold)).padding(.top, 6)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(1...6, id: \.self) { i in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(i)").font(.caption.weight(.heavy)).frame(width: 22, height: 22).background(Duo.accent, in: Circle()).foregroundStyle(.white)
                            Text(L10n.t("learn.tip\(i)")).font(.subheadline)
                        }
                    }
                }
                .duoCard()
            }
            .padding()
        }
        .duoBackground()
        .navigationTitle(L10n.t("learn.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func name(_ kind: PieceKind) -> String {
        switch kind {
        case .king: return "king"
        case .queen: return "queen"
        case .rook: return "rook"
        case .bishop: return "bishop"
        case .knight: return "knight"
        case .pawn: return "pawn"
        }
    }

    private func ruleCard(_ key: String, _ icon: String, fen: String) -> some View {
        NavigationLink {
            AnalysisView(fen: fen)
        } label: {
            HStack(spacing: 12) {
                MiniBoard(fen: fen).frame(width: 76, height: 76)
                VStack(alignment: .leading, spacing: 4) {
                    Label(L10n.t(key), systemImage: icon).font(.headline)
                    Text(L10n.t(key + ".desc")).font(.caption).foregroundStyle(Duo.secondaryText(scheme)).lineLimit(4)
                    Text(L10n.t("learn.try")).font(.caption.weight(.bold)).foregroundStyle(Duo.accent)
                }
                Spacer(minLength: 0)
            }
            .duoCard(padding: 12)
        }
        .buttonStyle(.plain)
    }
}
