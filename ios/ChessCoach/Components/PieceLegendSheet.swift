import SwiftUI

struct PieceLegendSheet: View {
    @Environment(\.dismiss) private var dismiss

    private var cards: [PieceGuideCard] {
        [
            .init(
                title: L10n.t(.guideSetupTitle),
                glyph: "♟️",
                summary: L10n.t(.guideSetupSummary),
                detail: L10n.t(.guideSetupDetail),
                diagram: .starting
            ),
            .init(
                title: L10n.t(.guideKingTitle),
                glyph: "♔",
                summary: L10n.t(.guideKingSummary),
                detail: L10n.t(.guideKingDetail),
                diagram: .king
            ),
            .init(
                title: L10n.t(.guideQueenTitle),
                glyph: "♕",
                summary: L10n.t(.guideQueenSummary),
                detail: L10n.t(.guideQueenDetail),
                diagram: .queen
            ),
            .init(
                title: L10n.t(.guideBishopTitle),
                glyph: "♗",
                summary: L10n.t(.guideBishopSummary),
                detail: L10n.t(.guideBishopDetail),
                diagram: .bishop
            ),
            .init(
                title: L10n.t(.guideKnightTitle),
                glyph: "♘",
                summary: L10n.t(.guideKnightSummary),
                detail: L10n.t(.guideKnightDetail),
                diagram: .knight
            ),
            .init(
                title: L10n.t(.guideRookTitle),
                glyph: "♖",
                summary: L10n.t(.guideRookSummary),
                detail: L10n.t(.guideRookDetail),
                diagram: .rook
            ),
            .init(
                title: L10n.t(.guidePawnMoveTitle),
                glyph: "♙",
                summary: L10n.t(.guidePawnMoveSummary),
                detail: L10n.t(.guidePawnMoveDetail),
                diagram: .pawnMove
            ),
            .init(
                title: L10n.t(.guidePawnAttackTitle),
                glyph: "♙",
                summary: L10n.t(.guidePawnAttackSummary),
                detail: L10n.t(.guidePawnAttackDetail),
                diagram: .pawnAttack
            )
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.t(.pieceGuideTitle))
                            .font(.title2.bold())
                        Text(L10n.t(.pieceGuideSubtitle))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(cards) { card in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Text(card.glyph)
                                    .font(.system(size: 34))
                                    .frame(width: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(card.title)
                                        .font(.headline)
                                    Text(card.summary)
                                        .font(.subheadline.weight(.semibold))
                                }
                            }

                            MovementDiagram(kind: card.diagram)
                                .frame(maxWidth: .infinity)
                                .frame(height: 168)

                            Text(card.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding()
            }
            .navigationTitle(L10n.t(.pieceGuide))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t(.done)) { dismiss() }
                }
            }
        }
    }
}

private struct PieceGuideCard: Identifiable {
    let id = UUID()
    let title: String
    let glyph: String
    let summary: String
    let detail: String
    let diagram: DiagramKind
}

private enum DiagramKind {
    case starting, king, queen, bishop, knight, rook, pawnMove, pawnAttack
}

private struct MovementDiagram: View {
    let kind: DiagramKind

    private let size = 5

    var body: some View {
        GeometryReader { proxy in
            let cell = min(proxy.size.width, proxy.size.height) / CGFloat(size)
            ZStack {
                ForEach(0..<size, id: \.self) { row in
                    ForEach(0..<size, id: \.self) { col in
                        let dark = (row + col).isMultiple(of: 2)
                        Rectangle()
                            .fill(dark ? Color(red: 0.45, green: 0.57, blue: 0.37) : Color(red: 0.93, green: 0.89, blue: 0.78))
                            .frame(width: cell, height: cell)
                            .position(
                                x: CGFloat(col) * cell + cell / 2,
                                y: CGFloat(row) * cell + cell / 2
                            )
                    }
                }

                ForEach(markers, id: \.id) { marker in
                    Group {
                        if marker.isPiece {
                            let isWhite = !"♚♛♜♝♞♟".contains(marker.glyph)
                            Text(marker.glyph)
                                .font(.system(size: cell * 0.62))
                                .foregroundStyle(isWhite ? PiecePalette.whiteFill : PiecePalette.blackFill)
                                .shadow(color: isWhite ? PiecePalette.whiteStroke : PiecePalette.blackStroke, radius: 0, x: 0.6, y: 0.6)
                        } else {
                            Circle()
                                .fill(Color.accentColor.opacity(marker.isAttack ? 0.85 : 0.55))
                                .frame(width: cell * (marker.isAttack ? 0.42 : 0.28), height: cell * (marker.isAttack ? 0.42 : 0.28))
                                .overlay {
                                    if marker.isAttack {
                                        Circle().stroke(Color.red.opacity(0.9), lineWidth: 2)
                                    }
                                }
                        }
                    }
                    .position(
                        x: CGFloat(marker.col) * cell + cell / 2,
                        y: CGFloat(marker.row) * cell + cell / 2
                    )
                }
            }
            .frame(width: cell * CGFloat(size), height: cell * CGFloat(size))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }

    private struct Marker: Identifiable {
        let id = UUID()
        let row: Int
        let col: Int
        let glyph: String
        let isPiece: Bool
        let isAttack: Bool
    }

    private var markers: [Marker] {
        let center = 2
        switch kind {
        case .starting:
            return [
                Marker(row: 0, col: 2, glyph: "♚", isPiece: true, isAttack: false),
                Marker(row: 1, col: 2, glyph: "♟", isPiece: true, isAttack: false),
                Marker(row: 3, col: 2, glyph: "♙", isPiece: true, isAttack: false),
                Marker(row: 4, col: 2, glyph: "♔", isPiece: true, isAttack: false)
            ]
        case .king:
            return kingLike(glyph: "♔", radius: 1, attackStyle: false)
        case .queen:
            return rays(glyph: "♕", diagonals: true, orthogonals: true)
        case .bishop:
            return rays(glyph: "♗", diagonals: true, orthogonals: false)
        case .rook:
            return rays(glyph: "♖", diagonals: false, orthogonals: true)
        case .knight:
            let offsets = [(-2, -1), (-2, 1), (-1, -2), (-1, 2), (1, -2), (1, 2), (2, -1), (2, 1)]
            var result = [Marker(row: center, col: center, glyph: "♘", isPiece: true, isAttack: false)]
            for (dr, dc) in offsets {
                let r = center + dr
                let c = center + dc
                if (0..<size).contains(r), (0..<size).contains(c) {
                    result.append(Marker(row: r, col: c, glyph: "", isPiece: false, isAttack: false))
                }
            }
            return result
        case .pawnMove:
            return [
                Marker(row: 3, col: 2, glyph: "♙", isPiece: true, isAttack: false),
                Marker(row: 2, col: 2, glyph: "", isPiece: false, isAttack: false),
                Marker(row: 1, col: 2, glyph: "", isPiece: false, isAttack: false)
            ]
        case .pawnAttack:
            return [
                Marker(row: 3, col: 2, glyph: "♙", isPiece: true, isAttack: false),
                Marker(row: 2, col: 1, glyph: "", isPiece: false, isAttack: true),
                Marker(row: 2, col: 3, glyph: "", isPiece: false, isAttack: true)
            ]
        }
    }

    private func kingLike(glyph: String, radius: Int, attackStyle: Bool) -> [Marker] {
        var result = [Marker(row: 2, col: 2, glyph: glyph, isPiece: true, isAttack: false)]
        for row in 0..<size {
            for col in 0..<size {
                let dr = abs(row - 2)
                let dc = abs(col - 2)
                if (row != 2 || col != 2), dr <= radius, dc <= radius {
                    result.append(Marker(row: row, col: col, glyph: "", isPiece: false, isAttack: attackStyle))
                }
            }
        }
        return result
    }

    private func rays(glyph: String, diagonals: Bool, orthogonals: Bool) -> [Marker] {
        var result = [Marker(row: 2, col: 2, glyph: glyph, isPiece: true, isAttack: false)]
        let directions: [(Int, Int)] = [
            (-1, 0), (1, 0), (0, -1), (0, 1),
            (-1, -1), (-1, 1), (1, -1), (1, 1)
        ]
        for (dr, dc) in directions {
            let isDiagonal = dr != 0 && dc != 0
            let isOrthogonal = dr == 0 || dc == 0
            if (isDiagonal && !diagonals) || (isOrthogonal && !orthogonals) { continue }
            var r = 2 + dr
            var c = 2 + dc
            while (0..<size).contains(r), (0..<size).contains(c) {
                result.append(Marker(row: r, col: c, glyph: "", isPiece: false, isAttack: false))
                r += dr
                c += dc
            }
        }
        return result
    }
}
