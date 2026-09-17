import Foundation
import SwiftUI
import Combine

/// Free analysis board: set up positions, play both sides, and see the engine's evaluation.
@MainActor
final class AnalysisSession: ObservableObject {
    @Published private(set) var game: ChessGame
    @Published var interaction = BoardInteraction()
    @Published var pendingPromotion: PendingPromotion?
    @Published var isEditing = false
    @Published var editPiece: Piece? = Piece(.white, .pawn)   // nil = eraser
    @Published var engineOn = true
    @Published private(set) var evalWhite: Int? = nil
    @Published private(set) var bestLine: [String] = []
    @Published private(set) var depth = 0
    @Published private(set) var mateIn: Int? = nil
    @Published var toast: Toast?
    @Published var use3D = false
    @Published var viewingPly: Int? = nil
    @Published var flipped = false

    private let engine = ChessEngine()
    private var analysisTask: Task<Void, Never>?

    init(fen: String = Position.startFEN) {
        game = ChessGame(fen: fen)
        refreshInteraction()
        analyze()
    }

    init(record: GameRecord) {
        game = record.game
        refreshInteraction()
        analyze()
    }

    var position: Position { viewingPly.map { game.position(atPly: $0) } ?? game.position }
    var orientation: PieceColor { flipped ? .black : .white }

    func tap(_ square: Square) {
        if isEditing {
            var pos = game.position
            if let editPiece {
                if pos[square] == editPiece {
                    // Tapping the same piece removes it, except kings which must stay on the board.
                    if editPiece.kind != .king { pos[square] = nil }
                } else {
                    if pos[square]?.kind == .king { presentToast(L10n.t("analysis.invalidFEN"), style: .warning); return }
                    if editPiece.kind == .king, let old = pos.king(of: editPiece.color) { pos[old] = nil }
                    pos[square] = editPiece
                }
            } else {
                if pos[square]?.kind == .king { return }
                pos[square] = nil
            }
            pos.enPassant = nil
            replace(position: pos, keepIfInvalid: true)
            Feedback.shared.selectionChanged()
            return
        }
        if let ply = viewingPly {
            // Branch from the viewed position: keep moves up to this ply, drop the rest.
            var rebuilt = ChessGame(fen: game.startFEN)
            for m in game.history.prefix(ply) { rebuilt.play(m.move) }
            game = rebuilt
            viewingPly = nil
        }
        if let selected = interaction.selected {
            if selected == square { interaction.selected = nil; refreshInteraction(); return }
            let moves = game.position.legalMoves(from: selected).filter { $0.to == square }
            if !moves.isEmpty {
                if moves.contains(where: { $0.promotion != nil }) {
                    pendingPromotion = PendingPromotion(from: selected, to: square, color: game.sideToMove)
                } else {
                    play(moves[0])
                }
                return
            }
        }
        if let piece = game.position[square], piece.color == game.sideToMove {
            interaction.selected = square
            Feedback.shared.play(.select)
        } else {
            interaction.selected = nil
        }
        refreshInteraction()
    }

    func drop(from: Square, to: Square) {
        if isEditing {
            var pos = game.position
            pos[to] = pos[from]
            pos[from] = nil
            replace(position: pos, keepIfInvalid: true)
            return
        }
        let moves = game.position.legalMoves(from: from).filter { $0.to == to }
        guard let first = moves.first else { refreshInteraction(); return }
        if moves.contains(where: { $0.promotion != nil }) {
            pendingPromotion = PendingPromotion(from: from, to: to, color: game.sideToMove)
        } else {
            play(first)
        }
    }

    func completePromotion(_ kind: PieceKind) {
        guard let p = pendingPromotion else { return }
        pendingPromotion = nil
        if let move = game.position.legalMove(from: p.from, to: p.to, promotion: kind) { play(move) }
    }

    private func play(_ move: Move) {
        var g = game
        guard let record = g.play(move) else { return }
        game = g
        interaction.selected = nil
        Feedback.shared.play(record.captured != nil ? .capture : .move)
        refreshInteraction()
        analyze()
    }

    func undo() {
        var g = game
        _ = g.undo()
        game = g
        viewingPly = nil
        refreshInteraction()
        analyze()
    }

    func step(_ delta: Int) {
        let count = game.history.count
        let current = viewingPly ?? count
        let next = max(0, min(count, current + delta))
        viewingPly = next == count ? nil : next
        refreshInteraction()
        analyze()
    }

    func reset() { replace(position: Position(), keepIfInvalid: false) }

    func clearBoard() {
        var pos = Position()
        for i in 0..<64 { pos.board[i] = nil }
        pos[Square(name: "e1")!] = Piece(.white, .king)
        pos[Square(name: "e8")!] = Piece(.black, .king)
        pos.castling = []
        replace(position: pos, keepIfInvalid: true)
    }

    func setSideToMove(_ color: PieceColor) {
        var pos = game.position
        pos.sideToMove = color
        pos.enPassant = nil
        replace(position: pos, keepIfInvalid: true)
    }

    func loadFEN(_ fen: String) -> Bool {
        guard let pos = Position(fen: fen.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
        replace(position: pos, keepIfInvalid: false)
        return true
    }

    func loadPGN(_ pgn: String) -> Bool {
        guard let g = ChessGame.fromPGN(pgn) else { return false }
        game = g
        viewingPly = nil
        refreshInteraction()
        analyze()
        return true
    }

    private func replace(position: Position, keepIfInvalid: Bool) {
        // Positions must have exactly one king each to be playable.
        let whiteKings = position.board.filter { $0 == Piece(.white, .king) }.count
        let blackKings = position.board.filter { $0 == Piece(.black, .king) }.count
        var pos = position
        var castling = CastlingRights()
        if pos[Square(name: "e1")!] == Piece(.white, .king) {
            if pos[Square(name: "h1")!] == Piece(.white, .rook) { castling.insert(.whiteKing) }
            if pos[Square(name: "a1")!] == Piece(.white, .rook) { castling.insert(.whiteQueen) }
        }
        if pos[Square(name: "e8")!] == Piece(.black, .king) {
            if pos[Square(name: "h8")!] == Piece(.black, .rook) { castling.insert(.blackKing) }
            if pos[Square(name: "a8")!] == Piece(.black, .rook) { castling.insert(.blackQueen) }
        }
        pos.castling = castling
        pos.halfmoveClock = 0
        if whiteKings == 1 && blackKings == 1 {
            // A side that is not to move may not be in check; flip the turn if needed so the position stays legal.
            if pos.isInCheck(pos.sideToMove.opposite) { pos.sideToMove = pos.sideToMove.opposite }
            game = ChessGame(fen: pos.fen)
        } else if !keepIfInvalid {
            return
        }
        viewingPly = nil
        interaction.selected = nil
        refreshInteraction()
        analyze()
    }

    var fen: String { game.position.fen }
    var pgn: String { game.pgn(white: L10n.t("game.white"), black: L10n.t("game.black"), event: L10n.t("analysis.title")) }

    func refreshInteraction() {
        let pos = position
        var next = interaction
        next.orientation = orientation
        next.interactive = true
        if let selected = interaction.selected, pos[selected]?.color == pos.sideToMove, !isEditing {
            let moves = pos.legalMoves(from: selected)
            next.legalTargets = Set(moves.map(\.to))
            next.captureTargets = Set(moves.filter { pos.isCapture($0) }.map(\.to))
        } else {
            next.selected = nil
            next.legalTargets = []
            next.captureTargets = []
        }
        if let viewingPly, viewingPly > 0 {
            let m = game.history[viewingPly - 1].move
            next.lastMove = (m.from, m.to)
        } else if let last = game.lastMove, viewingPly == nil {
            next.lastMove = (last.move.from, last.move.to)
        } else {
            next.lastMove = nil
        }
        next.checkSquare = pos.isInCheck ? pos.king(of: pos.sideToMove) : nil
        next.hintMove = nil
        interaction = next
    }

    func analyze() {
        analysisTask?.cancel()
        engine.cancel()
        guard engineOn else { evalWhite = nil; bestLine = []; return }
        let pos = position
        if pos.legalMoves().isEmpty {
            evalWhite = pos.isInCheck ? (pos.sideToMove == .white ? -Search.mateScore : Search.mateScore) : 0
            bestLine = []
            mateIn = nil
            return
        }
        analysisTask = Task { [weak self] in
            guard let self else { return }
            for d in [3, 5, 7] {
                let result = await self.engine.analyze(pos, depth: d, time: d == 7 ? 2.5 : 0.6)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard self.position == pos else { return }
                    self.evalWhite = pos.sideToMove == .white ? result.score : -result.score
                    self.depth = result.depth
                    self.mateIn = result.mateIn
                    var p = pos
                    var sans: [String] = []
                    for m in result.principalVariation { sans.append(p.san(for: m)); p = p.making(m) }
                    self.bestLine = sans
                    if let best = result.bestMove { self.interaction.hintMove = best }
                }
            }
        }
    }

    func presentToast(_ text: String, style: Toast.Style = .info) {
        toast = Toast(text: text, style: style)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            await MainActor.run { self?.toast = nil }
        }
    }
}
