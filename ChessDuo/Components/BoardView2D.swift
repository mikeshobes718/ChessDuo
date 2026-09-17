import SwiftUI

/// The 2D chess board. Purely presentational: it receives a position + interaction state and reports taps/drops.
struct BoardView2D: View {
    let position: Position
    let interaction: BoardInteraction
    var showCoordinates: Bool = true
    var onTap: (Square) -> Void
    var onDrop: ((Square, Square) -> Void)? = nil

    @EnvironmentObject private var settings: AppSettings
    @State private var dragging: (square: Square, offset: CGSize)? = nil
    @State private var tracked: [TrackedPiece] = []

    struct TrackedPiece: Identifiable, Equatable {
        let id: UUID
        var square: Square
        var piece: Piece
    }

    /// Carries piece identities across positions so moves animate as slides rather than fades.
    static func reconcile(_ previous: [TrackedPiece], _ position: Position) -> [TrackedPiece] {
        var bySquare = Dictionary(uniqueKeysWithValues: previous.map { ($0.square, $0) })
        var result: [TrackedPiece] = []
        var added: [(Square, Piece)] = []
        for sq in Square.all {
            guard let piece = position[sq] else { continue }
            if let existing = bySquare[sq], existing.piece == piece {
                result.append(existing)
                bySquare.removeValue(forKey: sq)
            } else {
                added.append((sq, piece))
            }
        }
        var removed = Array(bySquare.values)
        for (sq, piece) in added {
            if let idx = removed.firstIndex(where: { $0.piece == piece }) {
                var moved = removed.remove(at: idx)
                moved.square = sq
                result.append(moved)
            } else if piece.kind != .pawn, let idx = removed.firstIndex(where: { $0.piece.color == piece.color && $0.piece.kind == .pawn }) {
                // Promotion: the pawn becomes the new piece.
                var promoted = removed.remove(at: idx)
                promoted.square = sq
                promoted.piece = piece
                result.append(promoted)
            } else {
                result.append(TrackedPiece(id: UUID(), square: sq, piece: piece))
            }
        }
        return result.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    private var orientation: PieceColor { interaction.orientation }

    private func square(atCol col: Int, row: Int) -> Square {
        // row 0 is the top of the screen.
        let file = orientation == .white ? col : 7 - col
        let rank = orientation == .white ? 7 - row : row
        return Square(file: file, rank: rank)
    }

    private func point(for square: Square, cell: CGFloat) -> CGPoint {
        let col = orientation == .white ? square.file : 7 - square.file
        let row = orientation == .white ? 7 - square.rank : square.rank
        return CGPoint(x: (CGFloat(col) + 0.5) * cell, y: (CGFloat(row) + 0.5) * cell)
    }

    private func square(at location: CGPoint, cell: CGFloat) -> Square? {
        let col = Int(location.x / cell), row = Int(location.y / cell)
        guard (0..<8).contains(col), (0..<8).contains(row) else { return nil }
        return square(atCol: col, row: row)
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / 8
            ZStack(alignment: .topLeading) {
                squares(cell: cell)
                highlights(cell: cell)
                if showCoordinates { coordinates(cell: cell) }
                pieces(cell: cell)
                arrows(cell: cell)
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .contentShape(Rectangle())
            .gesture(dragGesture(cell: cell))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear { tracked = Self.reconcile([], position) }
        .onChange(of: position) { _, newValue in
            if settings.animations {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { tracked = Self.reconcile(tracked, newValue) }
            } else {
                tracked = Self.reconcile(tracked, newValue)
            }
        }
    }

    private func squares(cell: CGFloat) -> some View {
        Canvas { context, _ in
            for row in 0..<8 {
                for col in 0..<8 {
                    let sq = square(atCol: col, row: row)
                    let rect = CGRect(x: CGFloat(col) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                    context.fill(Path(rect), with: .color(sq.isLight ? settings.lightSquare : settings.darkSquare))
                }
            }
        }
    }

    @ViewBuilder
    private func highlights(cell: CGFloat) -> some View {
        if let last = interaction.lastMove {
            ForEach([last.0, last.1], id: \.index) { sq in
                Rectangle().fill(Color.yellow.opacity(0.42)).frame(width: cell, height: cell).position(point(for: sq, cell: cell))
            }
        }
        if let check = interaction.checkSquare {
            RadialGradient(colors: [Color.red.opacity(0.85), Color.red.opacity(0.0)], center: .center, startRadius: cell * 0.1, endRadius: cell * 0.6)
                .frame(width: cell, height: cell).position(point(for: check, cell: cell))
        }
        ForEach(Array(interaction.threatSquares), id: \.index) { sq in
            Rectangle().strokeBorder(Duo.danger.opacity(0.85), lineWidth: 3).frame(width: cell, height: cell).position(point(for: sq, cell: cell))
        }
        ForEach(Array(interaction.coachSquares), id: \.index) { sq in
            Rectangle().fill(Duo.sky.opacity(0.28)).frame(width: cell, height: cell).position(point(for: sq, cell: cell))
        }
        if let sel = interaction.selected {
            Rectangle().fill(Duo.accent.opacity(0.55)).frame(width: cell, height: cell).position(point(for: sel, cell: cell))
        }
        if let pending = interaction.pendingConfirm {
            Rectangle().strokeBorder(Duo.mint, lineWidth: 4).frame(width: cell, height: cell).position(point(for: pending.to, cell: cell))
        }
        if settings.showLegalMoves {
            ForEach(Array(interaction.legalTargets), id: \.index) { sq in
                if interaction.captureTargets.contains(sq) {
                    Circle().strokeBorder(Color.black.opacity(0.28), lineWidth: cell * 0.09).frame(width: cell * 0.92, height: cell * 0.92).position(point(for: sq, cell: cell))
                } else {
                    Circle().fill(Color.black.opacity(0.22)).frame(width: cell * 0.30, height: cell * 0.30).position(point(for: sq, cell: cell))
                }
            }
        }
    }

    private func coordinates(cell: CGFloat) -> some View {
        Canvas { context, _ in
            for i in 0..<8 {
                let rankSq = square(atCol: 0, row: i)
                let fileSq = square(atCol: i, row: 7)
                let rankText = Text("\(rankSq.rank + 1)").font(.system(size: cell * 0.19, weight: .bold)).foregroundColor(rankSq.isLight ? settings.darkSquare : settings.lightSquare)
                context.draw(rankText, at: CGPoint(x: cell * 0.14, y: CGFloat(i) * cell + cell * 0.16))
                let fileText = Text(fileSq.fileLetter).font(.system(size: cell * 0.19, weight: .bold)).foregroundColor(fileSq.isLight ? settings.darkSquare : settings.lightSquare)
                context.draw(fileText, at: CGPoint(x: CGFloat(i) * cell + cell * 0.86, y: 7 * cell + cell * 0.84))
            }
        }
        .allowsHitTesting(false)
    }

    private func pieces(cell: CGFloat) -> some View {
        ForEach(tracked) { t in
            let isDragging = dragging?.square == t.square
            PieceView(piece: t.piece, style: settings.pieceStyle, size: cell * 0.96)
                .scaleEffect(isDragging ? 1.25 : 1)
                .offset(isDragging ? dragging!.offset : .zero)
                .position(point(for: t.square, cell: cell))
                .zIndex(isDragging ? 10 : 1)
                .transition(.opacity.combined(with: .scale(scale: 0.6)))
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func arrows(cell: CGFloat) -> some View {
        if let hint = interaction.hintMove, hint.from != hint.to {
            ArrowShape(from: point(for: hint.from, cell: cell), to: point(for: hint.to, cell: cell), headSize: cell * 0.36, width: cell * 0.16)
                .fill(Duo.mint.opacity(0.85))
                .allowsHitTesting(false)
        } else if let hint = interaction.hintMove {
            Circle().strokeBorder(Duo.mint, lineWidth: 4).frame(width: cell * 0.95, height: cell * 0.95).position(point(for: hint.from, cell: cell)).allowsHitTesting(false)
        }
    }

    private func dragGesture(cell: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard interaction.interactive else { return }
                if dragging == nil {
                    guard let start = square(at: value.startLocation, cell: cell), let piece = position[start], piece.color == position.sideToMove else { return }
                    if abs(value.translation.width) + abs(value.translation.height) > 6 {
                        dragging = (start, value.translation)
                        onTap(start)   // select the piece so legal targets show
                    }
                } else {
                    dragging?.offset = value.translation
                }
            }
            .onEnded { value in
                if let drag = dragging {
                    dragging = nil
                    if let target = square(at: value.location, cell: cell), target != drag.square {
                        onDrop?(drag.square, target)
                    }
                } else if let sq = square(at: value.location, cell: cell) {
                    onTap(sq)
                }
            }
    }
}

struct ArrowShape: Shape {
    var from: CGPoint
    var to: CGPoint
    var headSize: CGFloat
    var width: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let dx = to.x - from.x, dy = to.y - from.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 1 else { return p }
        let ux = dx / length, uy = dy / length
        let px = -uy, py = ux
        let shaftEnd = CGPoint(x: to.x - ux * headSize, y: to.y - uy * headSize)
        let start = CGPoint(x: from.x + ux * headSize * 0.6, y: from.y + uy * headSize * 0.6)
        p.move(to: CGPoint(x: start.x + px * width / 2, y: start.y + py * width / 2))
        p.addLine(to: CGPoint(x: shaftEnd.x + px * width / 2, y: shaftEnd.y + py * width / 2))
        p.addLine(to: CGPoint(x: shaftEnd.x + px * headSize * 0.6, y: shaftEnd.y + py * headSize * 0.6))
        p.addLine(to: to)
        p.addLine(to: CGPoint(x: shaftEnd.x - px * headSize * 0.6, y: shaftEnd.y - py * headSize * 0.6))
        p.addLine(to: CGPoint(x: shaftEnd.x - px * width / 2, y: shaftEnd.y - py * width / 2))
        p.addLine(to: CGPoint(x: start.x - px * width / 2, y: start.y - py * width / 2))
        p.closeSubpath()
        return p
    }
}
