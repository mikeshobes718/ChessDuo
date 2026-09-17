import Foundation

/// A full game: positions, move history, result detection, undo.
struct ChessGame: Hashable {
    private(set) var position: Position
    private(set) var history: [MoveRecord] = []
    private(set) var startFEN: String
    private(set) var result: GameResult?
    private var repetitionCounts: [String: Int] = [:]
    private var positionStack: [Position] = []

    init(fen: String = Position.startFEN) {
        let start = Position(fen: fen) ?? Position()
        position = start
        startFEN = start.fen
        repetitionCounts[start.repetitionKey] = 1
        refreshAutomaticResult()
    }

    var isFinished: Bool { result != nil }
    var sideToMove: PieceColor { position.sideToMove }
    var ply: Int { history.count }
    var lastMove: MoveRecord? { history.last }
    var isCheck: Bool { position.isInCheck }

    var legalMoves: [Move] {
        isFinished ? [] : position.legalMoves()
    }

    func legalMoves(from square: Square) -> [Move] {
        legalMoves.filter { $0.from == square }
    }

    var repetitionCount: Int { repetitionCounts[position.repetitionKey] ?? 1 }

    var canClaimDraw: Bool {
        position.halfmoveClock >= 100 || repetitionCount >= 3
    }

    /// Plays a move if legal. Returns the record or nil.
    @discardableResult
    mutating func play(_ move: Move, assisted: Bool = false) -> MoveRecord? {
        guard !isFinished else { return nil }
        let legal = position.legalMoves()
        guard let actual = legal.first(where: { $0.from == move.from && $0.to == move.to && $0.promotion == move.promotion }) else { return nil }
        let piece = position[actual.from]!
        let captured = position.capturedPiece(by: actual)
        let san = position.san(for: actual, legal: legal)
        positionStack.append(position)
        let mover = position.sideToMove
        position.apply(actual)
        let check = position.isInCheck
        let mate = check && position.legalMoves().isEmpty
        let record = MoveRecord(
            ply: history.count + 1,
            move: actual,
            san: san,
            piece: piece,
            captured: captured,
            fenAfter: position.fen,
            isCheck: check,
            isMate: mate,
            color: mover,
            assisted: assisted
        )
        history.append(record)
        repetitionCounts[position.repetitionKey, default: 0] += 1
        refreshAutomaticResult()
        return record
    }

    @discardableResult
    mutating func play(from: Square, to: Square, promotion: PieceKind? = nil, assisted: Bool = false) -> MoveRecord? {
        play(Move(from: from, to: to, promotion: promotion), assisted: assisted)
    }

    @discardableResult
    mutating func play(san: String) -> MoveRecord? {
        guard let move = position.move(fromSAN: san) else { return nil }
        return play(move)
    }

    /// Undo the last ply. Also clears any automatic result.
    @discardableResult
    mutating func undo() -> MoveRecord? {
        guard let last = history.popLast(), let previous = positionStack.popLast() else { return nil }
        repetitionCounts[position.repetitionKey, default: 1] -= 1
        position = previous
        result = nil
        refreshAutomaticResult()
        return last
    }

    mutating func resign(_ color: PieceColor) {
        guard !isFinished else { return }
        result = GameResult(winner: color.opposite, termination: .resignation)
    }

    mutating func agreeDraw() {
        guard !isFinished else { return }
        result = GameResult(winner: nil, termination: .drawAgreed)
    }

    mutating func timeout(_ color: PieceColor) {
        guard !isFinished else { return }
        // A player who runs out of time loses unless the opponent cannot possibly mate.
        let opponentHasMaterial = !position.squares(of: color.opposite).allSatisfy { position[$0]?.kind == .king }
        result = GameResult(winner: opponentHasMaterial ? color.opposite : nil, termination: .timeout)
    }

    mutating func claimDraw() {
        guard !isFinished, canClaimDraw else { return }
        result = GameResult(winner: nil, termination: position.halfmoveClock >= 100 ? .fiftyMoveRule : .threefoldRepetition)
    }

    mutating func setResult(_ newResult: GameResult?) {
        result = newResult
    }

    private mutating func refreshAutomaticResult() {
        let moves = position.legalMoves()
        if moves.isEmpty {
            if position.isInCheck {
                result = GameResult(winner: position.sideToMove.opposite, termination: .checkmate)
            } else {
                result = GameResult(winner: nil, termination: .stalemate)
            }
            return
        }
        if position.hasInsufficientMaterial {
            result = GameResult(winner: nil, termination: .insufficientMaterial)
            return
        }
        if position.halfmoveClock >= 150 {
            result = GameResult(winner: nil, termination: .fiftyMoveRule)
            return
        }
        if repetitionCount >= 5 {
            result = GameResult(winner: nil, termination: .threefoldRepetition)
        }
    }

    // MARK: - Derived info

    struct CapturedSummary: Hashable {
        var byWhite: [PieceKind] = []   // black pieces white has taken
        var byBlack: [PieceKind] = []
        var materialDiff: Int {          // positive = white ahead
            byWhite.reduce(0) { $0 + $1.value } - byBlack.reduce(0) { $0 + $1.value }
        }
    }

    var captured: CapturedSummary {
        var s = CapturedSummary()
        for record in history {
            guard let c = record.captured else { continue }
            if record.color == .white { s.byWhite.append(c.kind) } else { s.byBlack.append(c.kind) }
        }
        let order: [PieceKind] = [.queen, .rook, .bishop, .knight, .pawn]
        s.byWhite.sort { order.firstIndex(of: $0)! < order.firstIndex(of: $1)! }
        s.byBlack.sort { order.firstIndex(of: $0)! < order.firstIndex(of: $1)! }
        return s
    }

    /// Position after a given ply (0 = start).
    func position(atPly ply: Int) -> Position {
        if ply <= 0 { return Position(fen: startFEN) ?? Position() }
        if ply >= history.count { return position }
        return Position(fen: history[ply - 1].fenAfter) ?? position
    }

    var pgnMoveText: String {
        var text = ""
        for record in history {
            if record.color == .white {
                text += "\(record.moveNumber). "
            } else if record.ply == 1 {
                text += "\(record.moveNumber)... "
            }
            text += record.san + " "
        }
        text += result?.pgnResult ?? "*"
        return text
    }

    func pgn(white: String, black: String, event: String = "Chess Duo", date: Date = Date()) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy.MM.dd"
        var tags = [
            "[Event \"\(event)\"]",
            "[Site \"Chess Duo iOS\"]",
            "[Date \"\(df.string(from: date))\"]",
            "[White \"\(white)\"]",
            "[Black \"\(black)\"]",
            "[Result \"\(result?.pgnResult ?? "*")\"]"
        ]
        if startFEN != Position.startFEN {
            tags.append("[SetUp \"1\"]")
            tags.append("[FEN \"\(startFEN)\"]")
        }
        if let termination = result?.termination {
            tags.append("[Termination \"\(termination.rawValue)\"]")
        }
        return tags.joined(separator: "\n") + "\n\n" + pgnMoveText + "\n"
    }

    /// Parses a PGN move list (tags ignored except FEN) into a game.
    static func fromPGN(_ pgn: String) -> ChessGame? {
        var fen = Position.startFEN
        var body = ""
        for line in pgn.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("[") {
                if t.hasPrefix("[FEN"), let start = t.firstIndex(of: "\""), let end = t.lastIndex(of: "\""), start < end {
                    fen = String(t[t.index(after: start)..<end])
                }
            } else {
                body += " " + t
            }
        }
        // Strip comments and variations.
        var cleaned = ""
        var depth = 0
        var inComment = false
        for ch in body {
            if ch == "{" { inComment = true; continue }
            if ch == "}" { inComment = false; continue }
            if inComment { continue }
            if ch == "(" { depth += 1; continue }
            if ch == ")" { depth -= 1; continue }
            if depth > 0 { continue }
            cleaned.append(ch)
        }
        var game = ChessGame(fen: fen)
        for tokenSub in cleaned.split(whereSeparator: { $0 == " " || $0 == "\n" }) {
            var token = String(tokenSub)
            if token.contains(".") {
                guard let idx = token.lastIndex(of: ".") else { continue }
                token = String(token[token.index(after: idx)...])
                if token.isEmpty { continue }
            }
            if ["1-0", "0-1", "1/2-1/2", "*"].contains(token) { break }
            if token.hasPrefix("$") { continue }
            guard game.play(san: token) != nil else { return game.history.isEmpty ? nil : game }
        }
        return game
    }
}
