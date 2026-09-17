import Foundation

/// Deterministic Zobrist hashing for the transposition table.
enum Zobrist {
    private static var rng = SplitMix64(seed: 0x5EED_C0FFEE_1234)
    static let pieces: [[UInt64]] = (0..<12).map { _ in (0..<64).map { _ in rng.next() } }
    static let side: UInt64 = rng.next()
    static let castling: [UInt64] = (0..<16).map { _ in rng.next() }
    static let enPassantFile: [UInt64] = (0..<8).map { _ in rng.next() }

    static func hash(_ p: Position) -> UInt64 {
        var h: UInt64 = 0
        for i in 0..<64 {
            if let piece = p.board[i] {
                let idx = piece.kind.rawValue + (piece.color == .white ? 0 : 6)
                h ^= pieces[idx][i]
            }
        }
        if p.sideToMove == .black { h ^= side }
        h ^= castling[p.castling.rawValue & 15]
        if let ep = p.enPassant { h ^= enPassantFile[ep.file] }
        return h
    }
}

struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
