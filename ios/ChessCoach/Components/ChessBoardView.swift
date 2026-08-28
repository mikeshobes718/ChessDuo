// Board chrome matched to Duolingo Chess https://mobbin.com/screens/0c9656e8-e6f0-4372-bf78-6e0cbe3e3c9d

import SwiftUI

struct ChessBoardView: View {
    let fen: String
    let orientation: PlayerColor
    let selectedSquare: String?
    let legalDestinations: Set<String>
    let lastMove: LastMove?
    let suggestedHint: SuggestedHint?
    let threatenedSquares: Set<String>
    let drama: GameDrama
    let isEnabled: Bool
    let boardTheme: BoardTheme
    let customColors: BoardCustomColors
    let onSelect: (String) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var previousPieces: [String: ChessPiece] = [:]
    @State private var animatingPiece: (piece: ChessPiece, from: String, to: String)?
    @State private var shakeOffset: CGFloat = 0
    @State private var pulse = false
    @State private var lastDramaLevel: DramaLevel = .calm
    @State private var parsedFen: String = ""
    @State private var parsedPosition = ChessPosition(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

    private var position: ChessPosition {
        if fen != parsedFen {
            parsedFen = fen
            parsedPosition = ChessPosition(fen: fen)
        }
        return parsedPosition
    }

    // RepeatForever animations keep burning CPU while backgrounded; only run them in the foreground.
    private var animationsActive: Bool { scenePhase == .active }

    private var files: [Character] {
        orientation == .black ? Array("hgfedcba") : Array("abcdefgh")
    }

    private var ranks: [Int] {
        orientation == .black ? Array(1...8) : Array((1...8).reversed())
    }

    private var squares: [String] {
        ranks.flatMap { rank in files.map { "\($0)\(rank)" } }
    }

    var body: some View {
        GeometryReader { proxy in
            let label: CGFloat = 20
            let boardSize = min(proxy.size.width - label * 2, proxy.size.height - label * 2)
            let squareSize = max(boardSize / 8, 34)

            VStack(spacing: 0) {
                fileLabels(squareSize: squareSize, labelHeight: label)
                    .padding(.leading, label)

                HStack(spacing: 0) {
                    rankLabels(squareSize: squareSize, labelWidth: label)

                    ZStack {
                        boardGrid(position: position, squareSize: squareSize)
                        if let animatingPiece {
                            PieceGlyphView(piece: animatingPiece.piece, size: squareSize)
                                .position(center(of: animatingPiece.to, squareSize: squareSize))
                                .animation(.easeInOut(duration: 0.28), value: animatingPiece.to)
                        }

                        if drama.isAlarming || drama.level == .finishedWin {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(dramaBorderColor, lineWidth: drama.level >= .critical ? 4 : 2.5)
                                .opacity(pulse || !animationsActive ? 0.95 : 0.35)
                                .animation(
                                    animationsActive
                                        ? .easeInOut(duration: drama.level >= .critical ? 0.45 : 0.7).repeatForever(autoreverses: true)
                                        : .easeInOut(duration: 0.3),
                                    value: pulse
                                )
                        }
                    }
                    .frame(width: squareSize * 8, height: squareSize * 8)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    }
                    .offset(x: shakeOffset)
                    .onChange(of: fen) { newFen in
                        animateIfNeeded(newFen: newFen)
                    }
                    .onChange(of: drama.level) { level in
                        handleDramaChange(level)
                    }
                    .onChange(of: scenePhase) { _ in
                        // Re-evaluate pulse state when moving between foreground and background.
                        pulse = animationsActive && (drama.showsBoardPulse || drama.level == .pressure)
                    }
                    .onAppear {
                        pulse = animationsActive && (drama.showsBoardPulse || drama.level == .pressure)
                        lastDramaLevel = drama.level
                    }

                    rankLabels(squareSize: squareSize, labelWidth: label)
                }

                fileLabels(squareSize: squareSize, labelHeight: label)
                    .padding(.leading, label)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                previousPieces = position.pieces
            }
        }
        .aspectRatio(1.08, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chessboard, \(orientation.displayName) side, files a through h, ranks 1 through 8")
    }

    private func fileLabels(squareSize: CGFloat, labelHeight: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(files, id: \.self) { file in
                Text(String(file))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: squareSize, height: labelHeight)
            }
        }
    }

    private func rankLabels(squareSize: CGFloat, labelWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(ranks, id: \.self) { rank in
                Text("\(rank)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: labelWidth, height: squareSize)
            }
        }
    }

    private func boardGrid(position: ChessPosition, squareSize: CGFloat) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(squareSize), spacing: 0), count: 8),
            spacing: 0
        ) {
            ForEach(Array(squares.enumerated()), id: \.element) { index, square in
                let piece = position.pieces[square]
                let destination = legalDestinations.contains(square)
                Button {
                    onSelect(square)
                } label: {
                    ZStack {
                        squareColor(index)
                        if lastMove?.from == square || lastMove?.to == square {
                            PiecePalette.lastMove
                        }
                        if suggestedHint?.from == square || suggestedHint?.to == square {
                            PiecePalette.hint
                        }
                        if threatenedSquares.contains(square) {
                            PiecePalette.threat
                        }
                        if selectedSquare == square {
                            PiecePalette.selected
                        }
                        if drama.kingSquare == square, drama.showsBoardPulse || drama.level == .pressure {
                            dramaKingOverlay
                                .opacity(pulse || !animationsActive ? 0.9 : 0.35)
                                .animation(
                                    animationsActive
                                        ? .easeInOut(duration: drama.level >= .critical ? 0.4 : 0.75).repeatForever(autoreverses: true)
                                        : .easeInOut(duration: 0.3),
                                    value: pulse
                                )
                        }
                        if destination {
                            Circle()
                                .fill(PiecePalette.legal.opacity(piece == nil ? 0.75 : 0.28))
                                .frame(
                                    width: piece == nil ? squareSize * 0.28 : squareSize * 0.82,
                                    height: piece == nil ? squareSize * 0.28 : squareSize * 0.82
                                )
                                .overlay {
                                    if piece != nil {
                                        Circle()
                                            .stroke(PiecePalette.legal, lineWidth: 3)
                                    }
                                }
                        }
                        if let piece, animatingPiece?.to != square {
                            PieceGlyphView(piece: piece, size: squareSize)
                        }

                        // Tiny coordinate watermark in corner of each square for tip matching
                        Text(square)
                            .font(.system(size: max(8, squareSize * 0.16), weight: .bold, design: .rounded))
                            .foregroundStyle(Color.primary.opacity(0.28))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(2)
                    }
                    .frame(width: squareSize, height: squareSize)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
                .accessibilityLabel(accessibilityLabel(
                    square: square,
                    piece: piece,
                    isDestination: destination
                ))
            }
        }
    }

    private func center(of square: String, squareSize: CGFloat) -> CGPoint {
        guard square.count >= 2,
              let fileChar = square.first,
              let rank = Int(String(square.last!)),
              let fileIndex = files.firstIndex(of: fileChar),
              let rankIndex = ranks.firstIndex(of: rank)
        else { return .zero }
        return CGPoint(
            x: CGFloat(fileIndex) * squareSize + squareSize / 2,
            y: CGFloat(rankIndex) * squareSize + squareSize / 2
        )
    }

    private func animateIfNeeded(newFen: String) {
        let next = ChessPosition(fen: newFen).pieces
        defer {
            previousPieces = next
            parsedFen = newFen
            parsedPosition = ChessPosition(fen: newFen)
        }
        guard let lastMove, let from = lastMove.from, let to = lastMove.to else { return }
        guard let piece = next[to] ?? previousPieces[from] else { return }
        animatingPiece = (piece, from, to)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            animatingPiece = nil
        }
    }

    private func squareColor(_ index: Int) -> Color {
        let row = index / 8
        let column = index % 8
        return (row + column).isMultiple(of: 2)
            ? boardTheme.lightSquare(custom: customColors)
            : boardTheme.darkSquare(custom: customColors)
    }

    private var dramaKingOverlay: Color {
        switch drama.level {
        case .finishedWin: return PiecePalette.winPulse
        case .pressure: return PiecePalette.pressureGlow
        default: return PiecePalette.checkPulse
        }
    }

    private var dramaBorderColor: Color {
        switch drama.level {
        case .finishedWin: return Color.green
        case .pressure: return Color.orange
        case .critical, .finishedLoss: return Color.red
        default: return Color.red.opacity(0.85)
        }
    }

    private func handleDramaChange(_ level: DramaLevel) {
        pulse = animationsActive && (level == .pressure || level.showsBoardPulseEquivalent)
        if level.showsBoardShakeEquivalent, level != lastDramaLevel {
            shakeBoard()
            if level >= .check {
                Feedback.warning()
            }
        }
        lastDramaLevel = level
    }

    private func shakeBoard() {
        let sequence: [CGFloat] = [0, -10, 10, -8, 8, -4, 4, 0]
        for (index, value) in sequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.04) {
                withAnimation(.linear(duration: 0.04)) {
                    shakeOffset = value
                }
            }
        }
    }

    private func accessibilityLabel(
        square: String,
        piece: ChessPiece?,
        isDestination: Bool
    ) -> String {
        let contents = piece?.accessibilityName ?? "empty"
        return "\(square), \(contents)" + (isDestination ? ", legal destination" : "")
    }
}

private extension DramaLevel {
    var showsBoardPulseEquivalent: Bool {
        switch self {
        case .check, .critical, .finishedLoss, .finishedWin, .pressure: return true
        case .calm: return false
        }
    }

    var showsBoardShakeEquivalent: Bool {
        switch self {
        case .check, .critical, .finishedLoss: return true
        default: return false
        }
    }
}
