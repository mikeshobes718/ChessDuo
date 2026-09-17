import Foundation

struct Puzzle: Identifiable, Hashable, Codable {
    enum Theme: String, Codable, CaseIterable {
        case mateInOne, mateInTwo, winMaterial, fork, pin, backRank, promotion
    }
    let id: String
    let fen: String
    /// Solution moves in UCI, alternating solver/opponent, starting with the solver.
    let solution: [String]
    let theme: Theme
    let rating: Int

    var sideToMove: PieceColor { Position(fen: fen)?.sideToMove ?? .white }
}

enum PuzzleLibrary {
    static let all: [Puzzle] = [
        Puzzle(id: "m1-001", fen: "r1q2br1/4n1pp/1pp2p2/1p2pP2/4P3/4B1Pk/bPPNQ2P/R4RK1 w - - 1 21", solution: ["e2h5"], theme: .mateInOne, rating: 537),
        Puzzle(id: "m1-002", fen: "2kr1b1r/ppp2p1p/5p2/4p3/1P1Pb1q1/4BP2/P6P/R2NR2K b - - 0 19", solution: ["e4f3"], theme: .mateInOne, rating: 574),
        Puzzle(id: "m1-003", fen: "8/8/1R3p1p/1B3K1k/1R6/5P2/P5P1/2B5 w - - 0 39", solution: ["b5e8"], theme: .mateInOne, rating: 611),
        Puzzle(id: "m1-004", fen: "6r1/p2k1K2/1pp1p3/1b1nq3/7Q/1P3P2/P7/8 b - - 3 32", solution: ["e5g7"], theme: .mateInOne, rating: 648),
        Puzzle(id: "m1-005", fen: "r2qkb1r/p1pppppp/b7/np1P2N1/4n2P/P4Q2/1PP2PP1/R1B1KB1R w KQkq - 7 11", solution: ["f3f7"], theme: .mateInOne, rating: 685),
        Puzzle(id: "m1-006", fen: "2qk4/1p2rp2/pN4r1/2R4p/3p1B2/QP3PPP/P2K1P2/8 w - - 1 29", solution: ["c5c8"], theme: .mateInOne, rating: 722),
        Puzzle(id: "m1-007", fen: "r3kb2/pp2pp2/7p/1N1R4/6p1/8/PPb2PPP/R5K1 w q - 0 20", solution: ["b5c7"], theme: .mateInOne, rating: 759),
        Puzzle(id: "m1-008", fen: "r2N1b1r/pp2kpp1/5n2/3p1b1p/P7/1qP1pP1P/1P2P1PR/2K2B2 b - - 1 18", solution: ["b3c2"], theme: .mateInOne, rating: 796),
        Puzzle(id: "m1-009", fen: "5Q2/1p5k/p6p/5p2/6Bp/N1P1B3/PP3PPP/R3K1R1 w Q - 0 29", solution: ["g4f5"], theme: .mateInOne, rating: 833),
        Puzzle(id: "m1-010", fen: "r2qk2r/ppp2ppp/8/4Pb2/1b6/2p4P/PPPQPPP1/2R1KB1R b Kkq - 1 15", solution: ["d8d2"], theme: .mateInOne, rating: 870),
        Puzzle(id: "m1-011", fen: "rnb1kbnr/p2p1p1p/1p6/3Np3/3p4/4B3/P1Q1PPPP/R3KBNR w KQkq - 0 9", solution: ["c2c8"], theme: .mateInOne, rating: 907),
        Puzzle(id: "m1-012", fen: "2b1kb1r/3pn1pp/4p3/1p6/5P2/4q1P1/1r4BP/3K2R1 b - - 1 27", solution: ["e3d2"], theme: .mateInOne, rating: 944),
        Puzzle(id: "m1-013", fen: "7k/pp3p1p/8/3Bp3/Pr6/4PP2/1P3bPK/6R1 b - - 2 37", solution: ["b4h4"], theme: .mateInOne, rating: 981),
        Puzzle(id: "m1-014", fen: "7k/2B5/6Q1/3P2P1/8/1P3b2/5P2/4K3 w - - 1 40", solution: ["c7e5"], theme: .mateInOne, rating: 518),
        Puzzle(id: "m1-015", fen: "R4b1r/5k1p/5n2/5p2/1p3p1p/5PN1/PP3KP1/R1Bq4 b - - 4 28", solution: ["h4g3"], theme: .mateInOne, rating: 555),
        Puzzle(id: "m1-016", fen: "4Q3/p1N4k/bp6/3p4/3p3P/1P4R1/2P1PPP1/2K2B2 w - - 4 31", solution: ["e8h5"], theme: .mateInOne, rating: 592),
        Puzzle(id: "m1-017", fen: "r1b4r/1pp1b1pk/p6p/4p3/PPp5/2B3P1/2PP1q1P/R2K4 b - - 1 33", solution: ["f2f1"], theme: .mateInOne, rating: 629),
        Puzzle(id: "m1-018", fen: "r1b1k2r/p1pp1ppp/1p1b3n/8/q7/2P1PPpP/PP2P1B1/R1BQ1K1R b kq - 0 13", solution: ["a4d1"], theme: .mateInOne, rating: 666),
        Puzzle(id: "m1-019", fen: "2Nb1Q2/1p5k/p7/4Bppp/3P4/P3RpP1/qP2PP1P/6K1 w - - 1 35", solution: ["f8g7"], theme: .mateInOne, rating: 703),
        Puzzle(id: "m1-020", fen: "2b1k1r1/2Q2R2/8/4p1P1/3PB1p1/2p3P1/P3P3/2K3N1 w - - 1 35", solution: ["c7e7"], theme: .mateInOne, rating: 740),
        Puzzle(id: "m1-021", fen: "r3r1k1/pp2bp2/8/1P2p3/3Pn1b1/3K4/q7/7R b - - 1 32", solution: ["a2e2"], theme: .mateInOne, rating: 777),
        Puzzle(id: "m1-022", fen: "2r3k1/6p1/1p3p1p/1p2P3/6R1/1P3q2/r1P2PRP/7K b - - 3 30", solution: ["a2a1"], theme: .mateInOne, rating: 814),
        Puzzle(id: "m1-023", fen: "2r4k/8/1p5p/1p2p3/4q2P/rP6/2P2PRR/7K b - - 9 37", solution: ["a3a1"], theme: .mateInOne, rating: 851),
        Puzzle(id: "m1-024", fen: "R1r2k2/8/5B1p/1N5Q/1p1P1P2/4P3/1PP5/6K1 w - - 4 34", solution: ["a8c8"], theme: .mateInOne, rating: 888),
        Puzzle(id: "m1-025", fen: "r1k2b1r/p1n2ppp/8/1p1pp3/4qnP1/P1Q5/1PPK1P2/1RB5 b - - 1 29", solution: ["e4e2"], theme: .mateInOne, rating: 925),
        Puzzle(id: "m1-026", fen: "3r1b1r/2pk1Np1/2n4N/p2p1p1p/3P4/4Q2B/PPP1PP1P/2KR3R w - - 0 23", solution: ["h3f5"], theme: .mateInOne, rating: 962),
        Puzzle(id: "m1-027", fen: "r1bq2n1/ppNp4/2n2pQ1/8/3N1k2/2P5/P3PPPP/1R2KB1R w K - 0 16", solution: ["g6f5"], theme: .mateInOne, rating: 999),
        Puzzle(id: "m1-028", fen: "r1b2nk1/pp3pp1/2p4p/1P6/4p3/7P/5PPR/1q1B1K2 b - - 7 27", solution: ["b1d1"], theme: .mateInOne, rating: 536),
        Puzzle(id: "m1-029", fen: "7r/2p3kp/1p1p4/p2B4/3p1Q2/3P4/PPP4P/3KR3 w - - 1 34", solution: ["e1g1"], theme: .mateInOne, rating: 573),
        Puzzle(id: "m1-030", fen: "3k4/5R2/Q3n3/6P1/P1P2P2/P1P2P2/8/5K2 w - - 1 35", solution: ["a6a8"], theme: .mateInOne, rating: 610),
        Puzzle(id: "m1-031", fen: "5b1r/5pp1/4pk1p/1B6/4p2P/4B3/1PP1NPP1/1q1Q1K1R b - - 1 25", solution: ["b1d1"], theme: .mateInOne, rating: 647),
        Puzzle(id: "m1-032", fen: "4kr2/rpp3p1/4qp1p/7K/P1p4P/1P6/3P1PPR/2n5 b - - 0 28", solution: ["e6f5"], theme: .mateInOne, rating: 684),
        Puzzle(id: "m1-033", fen: "7r/1k4pp/8/3p1p2/1b1P1BPP/1Pn1Pb2/2K1QP2/R7 w - f6 0 28", solution: ["e2a6"], theme: .mateInOne, rating: 721),
        Puzzle(id: "m1-034", fen: "r3kr2/pbp1b1p1/1p2Q1N1/3p3p/8/n3P3/1PP2PPP/R1B1KBR1 w Qq - 0 15", solution: ["e6e7"], theme: .mateInOne, rating: 758),
        Puzzle(id: "m1-035", fen: "4Q3/k1p1p2p/8/3b1p1p/2p2P2/8/PRP2P1P/5RK1 w - - 1 26", solution: ["e8a4"], theme: .mateInOne, rating: 795),
        Puzzle(id: "m1-036", fen: "1r2k2r/pPp2ppp/8/1N1b4/2pPPPP1/b6P/1PP2q2/R1B4K b k - 0 21", solution: ["d5e4"], theme: .mateInOne, rating: 832),
        Puzzle(id: "m1-037", fen: "2q1k2r/1r5p/6p1/4pPQ1/3p3P/1p3P2/1BP2P2/1RK1R3 b - - 0 31", solution: ["c8c2"], theme: .mateInOne, rating: 869),
        Puzzle(id: "m1-038", fen: "N1bnkb1r/pp1p1ppp/3Q4/1B2p3/P3P3/2P1P3/1P3PqP/R1B1K2R w KQ - 5 16", solution: ["a8c7"], theme: .mateInOne, rating: 906),
        Puzzle(id: "m1-039", fen: "rnbk2N1/p1p2Q1p/1p6/4p3/P6P/8/1PP1PPP1/2R1KB1R w K - 0 16", solution: ["f7e7"], theme: .mateInOne, rating: 943),
        Puzzle(id: "m1-040", fen: "1r2k2r/1pp2ppp/8/Bb1p4/p1PP2n1/8/PP3qPP/2RK2R1 b k - 1 18", solution: ["g4e3"], theme: .mateInOne, rating: 980),
        Puzzle(id: "m2-001", fen: "r1q2br1/4n1pp/1pp2p2/1p2pP2/4P2k/4B3/bPPNQ1PP/R4RK1 w - - 2 20", solution: ["g2g3", "h4h3", "e2h5"], theme: .mateInTwo, rating: 1053),
        Puzzle(id: "m2-002", fen: "r3qbr1/4n1pp/1pp2p2/1p2pP2/4P1k1/4B1P1/bPP3QP/RN3RK1 w - - 5 23", solution: ["h2h3", "g4h5", "g2f3"], theme: .mateInTwo, rating: 1106),
        Puzzle(id: "m2-003", fen: "2kr1b1r/ppp2p1p/5p2/4p3/1P1P2q1/3bB3/P4P1P/R2NR2K b - - 3 18", solution: ["d3e4", "f2f3", "e4f3"], theme: .mateInTwo, rating: 1159),
        Puzzle(id: "m2-004", fen: "8/7p/1R3p2/1B3p1k/1R3K2/5P2/P5P1/2B5 w - - 1 38", solution: ["f4f5", "h7h6", "b5e8"], theme: .mateInTwo, rating: 1212),
        Puzzle(id: "m2-005", fen: "4r2r/p1pk3p/1p2p1p1/1b2P3/4KQ2/1P3PP1/P1n4q/8 b - - 1 22", solution: ["h2e2", "f4e3", "e2e3"], theme: .mateInTwo, rating: 1265),
        Puzzle(id: "m2-006", fen: "4rQ2/p1pk3p/1p2p1p1/1b2P3/4K3/1P3PP1/P1n4q/8 b - - 0 23", solution: ["e8f8", "a2a3", "h2e2"], theme: .mateInTwo, rating: 1318),
        Puzzle(id: "m2-007", fen: "7r/p2k4/1pp1p1K1/1b1nq3/7Q/1P3P2/P7/8 b - - 1 31", solution: ["h8g8", "g6h6", "e5h8"], theme: .mateInTwo, rating: 1371),
        Puzzle(id: "m2-008", fen: "r4Q2/3k3p/1p2p3/p1ppP3/P7/2P3q1/6BP/RK3R2 w - - 3 32", solution: ["f1f7", "d7c6", "f8d6"], theme: .mateInTwo, rating: 1424),
        Puzzle(id: "m2-009", fen: "5Q2/3p4/8/3Pk3/1pp1P3/1P3K1p/R1P5/8 w - - 0 38", solution: ["f3e3", "h3h2", "f8e7"], theme: .mateInTwo, rating: 1477),
        Puzzle(id: "m2-010", fen: "R4Q2/3p4/8/3Pk3/1pp1P3/1P3K2/2P4p/8 w - - 0 39", solution: ["f3e3", "h2h1q", "a8e8"], theme: .mateInTwo, rating: 1530),
        Puzzle(id: "m2-011", fen: "5rk1/p1p1pp1p/2p2b1n/P4P1P/6p1/6P1/4bP1K/2r5 b - - 0 26", solution: ["e2f3", "a5a6", "c1h1"], theme: .mateInTwo, rating: 1583),
        Puzzle(id: "m2-012", fen: "r1b1kbr1/p1pp2pp/4pq1n/P7/1n5P/5PP1/RPpPN1B1/2BQK2R b Kq h3 0 14", solution: ["b4d3", "e1f1", "c2d1q"], theme: .mateInTwo, rating: 1036),
        Puzzle(id: "m2-013", fen: "1kr5/6N1/1pb5/4Pp2/1b3P2/3KB1P1/8/R7 b - - 0 35", solution: ["c6b5", "d3d4", "c8d8"], theme: .mateInTwo, rating: 1089),
        Puzzle(id: "m2-014", fen: "r4k1r/p2b2p1/8/q6p/p2P4/2P5/4PPPP/4KB1n b - - 0 25", solution: ["a5c3", "e1d1", "h1f2"], theme: .mateInTwo, rating: 1142),
        Puzzle(id: "m2-015", fen: "3k4/p1pB1r2/6p1/3P4/7p/r3p2P/4K3/8 b - - 8 36", solution: ["f7f2", "e2d1", "a3a1"], theme: .mateInTwo, rating: 1195),
        Puzzle(id: "m2-016", fen: "2rnk3/2pp1p1r/b7/1p2p2P/4n3/1PP5/P3K3/3R2q1 b - - 1 28", solution: ["g1f2", "e2d3", "e4c5"], theme: .mateInTwo, rating: 1248),
        Puzzle(id: "m2-017", fen: "4rk1r/5pRn/8/p1pp1N2/2P5/Q2P1p1P/R3B3/4K3 w - c6 0 28", solution: ["a3c5", "e8e7", "c5e7"], theme: .mateInTwo, rating: 1301),
        Puzzle(id: "m2-018", fen: "5r2/5p1k/5R2/4Q3/2p5/6NP/4p3/4K3 w - - 0 38", solution: ["e5g5", "c4c3", "f6h6"], theme: .mateInTwo, rating: 1354),
        Puzzle(id: "m2-019", fen: "2r5/5p1k/8/4QR2/4N3/2p4P/4p3/4K3 w - - 0 40", solution: ["f5h5", "h7g8", "e5h8"], theme: .mateInTwo, rating: 1407),
        Puzzle(id: "m2-020", fen: "R4b1r/3q1k1p/5n2/5p2/1p3p1p/5PN1/PP4P1/R1B2K2 b - - 2 27", solution: ["d7d1", "f1f2", "h4g3"], theme: .mateInTwo, rating: 1460),
        Puzzle(id: "m2-021", fen: "4Q3/p1N5/bp3k2/3pp3/3R3P/1P6/2P1PPP1/2K2B1R w - - 0 28", solution: ["d4g4", "d5d4", "e8f8"], theme: .mateInTwo, rating: 1513),
        Puzzle(id: "m2-022", fen: "4Q3/p1N3k1/bp6/3p4/3p3P/1P3R2/2P1PPP1/2K2B2 w - - 2 30", solution: ["f3g3", "g7h7", "e8h5"], theme: .mateInTwo, rating: 1566),
        Puzzle(id: "m2-023", fen: "r1b2b1r/1pp3p1/p3p1kp/5n2/P1p1q3/6P1/1PPP1P1P/R1BK3R b - - 1 25", solution: ["f5d4", "a1b1", "e4h1"], theme: .mateInTwo, rating: 1019),
        Puzzle(id: "m2-024", fen: "r1b2b1r/1pp3p1/p3p1kp/5n2/P1p5/5qP1/1PPPRP1P/R1BK4 b - - 5 27", solution: ["f5d4", "a1b1", "f3e2"], theme: .mateInTwo, rating: 1072),
        Puzzle(id: "m2-025", fen: "r1b4r/1pp1b1p1/p3p1kp/8/PPpn4/5qP1/1BPPRP1P/R2K4 b - - 2 29", solution: ["f3e2", "d1c1", "e2f1"], theme: .mateInTwo, rating: 1125),
        Puzzle(id: "m2-026", fen: "4k3/8/2p5/2q1pp2/1n6/PP6/1K6/8 b - - 0 38", solution: ["c5c2", "b2a1", "c2a2"], theme: .mateInTwo, rating: 1178),
        Puzzle(id: "m2-027", fen: "r1b1kbQ1/4n3/1p3pp1/p2p3p/3PR2P/2P2N2/PP3PP1/4R1K1 w - d6 0 22", solution: ["e4e7", "e8d8", "g8f8"], theme: .mateInTwo, rating: 1231),
        Puzzle(id: "m2-028", fen: "2Nb1r2/1p6/p6k/2Q1Bppp/3P4/P3RpP1/qP2PP1P/6K1 w - - 1 34", solution: ["c5f8", "h6h7", "f8g7"], theme: .mateInTwo, rating: 1284),
        Puzzle(id: "m2-029", fen: "2bk2r1/Q1p2R2/8/4p1P1/3PB1p1/2p3P1/P3P3/2K3N1 w - - 0 34", solution: ["a7c7", "d8e8", "c7e7"], theme: .mateInTwo, rating: 1337),
        Puzzle(id: "m2-030", fen: "r1b1kb1r/1ppp1ppp/p1n5/3Np3/5P1q/3P1N2/PPP1P1KP/R2n1B2 b kq - 1 11", solution: ["h4g4", "g2h1", "d1f2"], theme: .mateInTwo, rating: 1390),
        Puzzle(id: "wm-001", fen: "r1q2b1r/3bn1pp/1ppQ1pk1/1p2p3/4P3/4B3/PPPN1PPP/R4RK1 b - - 0 14", solution: ["e7d5", "d6d7", "c8d7"], theme: .winMaterial, rating: 841),
        Puzzle(id: "wm-002", fen: "4r3/p1pk3K/1p2p1pQ/1b1nq3/8/1P3P2/P7/8 b - - 0 29", solution: ["e8h8", "h7g6", "b5d3"], theme: .winMaterial, rating: 882),
        Puzzle(id: "wm-003", fen: "r1b1kb1r/np1ppppp/1q3n2/p1P5/8/4PN2/PPP1NPPP/R1BQKB1R w KQkq - 1 7", solution: ["c5b6", "a7c6", "e2d4"], theme: .winMaterial, rating: 923),
        Puzzle(id: "wm-004", fen: "3r4/6k1/1P3p1p/p5pP/2P1P3/1PK5/PR3rB1/7R w - - 2 37", solution: ["b2f2", "g5g4", "b6b7"], theme: .winMaterial, rating: 964),
        Puzzle(id: "wm-005", fen: "3r4/6k1/1P3p1p/p5pP/2P1P3/1PK4B/Pr6/1R6 b - - 1 38", solution: ["b2b1", "b6b7", "b1c1"], theme: .winMaterial, rating: 1005),
        Puzzle(id: "wm-006", fen: "3r4/1P3k2/5p1p/p5pP/2P1P3/1PK4B/r7/1R6 w - - 1 40", solution: ["h3c8", "f6f5", "b7b8q"], theme: .winMaterial, rating: 1046),
        Puzzle(id: "wm-007", fen: "rn1qkb1r/p1p1pppp/1p3n2/3p4/3P1N2/2N5/PPb1PPPP/R1BQKB1R w KQkq - 0 7", solution: ["d1c2", "c7c6", "c1e3"], theme: .winMaterial, rating: 1087),
        Puzzle(id: "wm-008", fen: "r2qk2r/2p2ppp/1p2p3/p1bpP3/P2B1P2/2N5/1P4BP/R1K4R b kq - 1 20", solution: ["c5d4", "c1b1", "d4c3"], theme: .winMaterial, rating: 1128),
        Puzzle(id: "wm-009", fen: "r6Q/4kp1p/1p2p3/p1ppP3/P4q2/2P5/6BP/RK4R1 w - c6 0 28", solution: ["h8a8", "f4h2", "a8b7"], theme: .winMaterial, rating: 1169),
        Puzzle(id: "wm-010", fen: "r1bk3r/pppp1ppp/5n2/8/7P/P1P2n2/2P1P2P/R1BQKB1R w KQ - 0 10", solution: ["e2f3", "d7d5", "c1g5"], theme: .winMaterial, rating: 1210),
        Puzzle(id: "wm-011", fen: "5k2/p4p1p/1p3p2/4r3/1P5P/P4r2/2P3KP/2R4R w - - 2 25", solution: ["g2f3", "f8e7", "f3f4"], theme: .winMaterial, rating: 1251),
        Puzzle(id: "wm-012", fen: "2b2k2/R1pp4/8/3P1P1p/1p6/4P3/1PP1N1Bq/2K5 b - - 2 26", solution: ["h2g2", "a7c7", "g2h1"], theme: .winMaterial, rating: 1292),
        Puzzle(id: "wm-013", fen: "2b2k2/R1pp4/8/3P1P1p/1p6/4P3/1PP1q3/3K4 w - - 0 28", solution: ["d1e2", "f8e7", "a7c7"], theme: .winMaterial, rating: 1333),
        Puzzle(id: "wm-014", fen: "r2qkbnr/1pp2ppp/p7/3pp3/8/NP3bPP/P1PPPP2/R1BQKB1R w KQkq - 0 10", solution: ["e2f3", "g8f6", "d2d4"], theme: .winMaterial, rating: 1374),
        Puzzle(id: "wm-015", fen: "3k4/1p2rp2/pN4r1/2p2q1p/3p1B2/QP3PPP/P2K1P2/2R5 w - - 6 28", solution: ["c1c5", "f5h3", "c5c8"], theme: .winMaterial, rating: 1415),
        Puzzle(id: "wm-016", fen: "8/2r2p2/p3nk1p/3p3p/3P4/4PKP1/1BP5/5b2 b - - 2 38", solution: ["c7c2", "e3e4", "d5e4"], theme: .winMaterial, rating: 1456),
        Puzzle(id: "wm-017", fen: "5rk1/p1p1ppbp/b1p4n/5P2/P5pP/6P1/2r2P2/RNB4K b - - 1 20", solution: ["c2c1", "h1h2", "g7a1"], theme: .winMaterial, rating: 1497),
        Puzzle(id: "wm-018", fen: "4kb1r/prpb1ppp/2p1p3/6q1/3P4/P3P2P/1PP1P1B1/RQ1K1R2 b k - 1 17", solution: ["g5g2", "d1d2", "g2h3"], theme: .winMaterial, rating: 838),
        Puzzle(id: "wm-019", fen: "1r2kb1r/p1pb1ppp/2p1p3/8/PP1P4/4P2P/2P1P3/R1QK1R1q b k - 0 20", solution: ["h1f1", "d1d2", "f1h3"], theme: .winMaterial, rating: 879),
        Puzzle(id: "wm-020", fen: "4brk1/2p2ppp/2p1p2Q/p7/PbPr3P/1K2P3/8/1R6 b - - 1 29", solution: ["d4d3", "b3c2", "d3c3"], theme: .winMaterial, rating: 920),
        Puzzle(id: "wm-021", fen: "r4r1k/p1p2p1p/1p3np1/6PP/4P1P1/P2P1K2/1p2B3/2R5 b - - 0 32", solution: ["b2c1q", "g5f6", "g6h5"], theme: .winMaterial, rating: 961),
        Puzzle(id: "wm-022", fen: "r3kbr1/pp1bpp1p/5n2/1B3PB1/2p3p1/2N5/PPP2PPP/R4RK1 b q - 1 14", solution: ["g8g5", "b5c4", "d7f5"], theme: .winMaterial, rating: 1002),
        Puzzle(id: "wm-023", fen: "r3kb2/pp2pp1p/5n2/1B4r1/6p1/2N5/PPb2PPP/R2R2K1 b q - 1 17", solution: ["g5b5", "c3b5", "c2d1"], theme: .winMaterial, rating: 1043),
        Puzzle(id: "wm-024", fen: "r1b2b1r/1p2k1pp/2p5/p2qPp2/4P3/P5P1/1PPN1P1n/R1BQKBR1 w Q a6 0 13", solution: ["e4d5", "c6d5", "f1d3"], theme: .winMaterial, rating: 1084),
        Puzzle(id: "wm-025", fen: "4r1k1/1p3rb1/p4p1p/3Q3B/7p/N1P1B3/PP3PPP/R3K1R1 w Q - 4 25", solution: ["d5f7", "g8h8", "f7e8"], theme: .winMaterial, rating: 1125),
        Puzzle(id: "wm-026", fen: "1rb1k2r/pppn1ppp/1q2p3/1P1p4/3P1bP1/P1N1B3/2PKP2P/RQ3B1R b k - 0 14", solution: ["b6d4", "d2c1", "f4e3"], theme: .winMaterial, rating: 1166),
        Puzzle(id: "wm-027", fen: "1rb1k2r/1ppn1ppp/p3p3/1P1p4/1q1P1BP1/P1N5/2PKP2P/2R2B1R b k - 1 17", solution: ["b4d4", "d2e1", "d4f4"], theme: .winMaterial, rating: 1207),
        Puzzle(id: "wm-028", fen: "1rQ1k2r/2pn1ppp/4p3/8/q3p1P1/8/2P1P2P/1R2KB1R b k - 0 23", solution: ["b8c8", "e1d1", "a4d4"], theme: .winMaterial, rating: 1248),
        Puzzle(id: "wm-029", fen: "3r2r1/1b3kpp/1q2p3/p2pN1R1/1BpP1P2/2P5/P1P1K2P/1R6 b - - 1 26", solution: ["f7e8", "e5c4", "b6a6"], theme: .winMaterial, rating: 1289),
        Puzzle(id: "wm-030", fen: "r2q1b1r/p1pb1kp1/8/7p/pB6/4R3/1PP1PPPP/3QKB1n b - - 3 17", solution: ["f8b4", "c2c3", "b4d6"], theme: .winMaterial, rating: 1330)
    ]

    /// Puzzles whose solution passes the engine's own legality check. Filters out any typo'd entries.
    static let valid: [Puzzle] = all.filter { validate($0) }

    static func validate(_ puzzle: Puzzle) -> Bool {
        guard var pos = Position(fen: puzzle.fen) else { return false }
        for uci in puzzle.solution {
            guard uci.count >= 4, let from = Square(name: String(uci.prefix(2))), let to = Square(name: String(uci.dropFirst(2).prefix(2))) else { return false }
            let promo: PieceKind? = uci.count > 4 ? PieceKind(letter: uci.last!) : nil
            guard let move = pos.legalMove(from: from, to: to, promotion: promo) else { return false }
            pos.apply(move)
        }
        // Mate puzzles must actually end in mate.
        if puzzle.theme == .mateInOne || puzzle.theme == .mateInTwo || puzzle.theme == .backRank {
            return pos.isInCheck && pos.legalMoves().isEmpty
        }
        return true
    }

    static func daily(for date: Date = Date()) -> Puzzle {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return valid[day % max(1, valid.count)]
    }
}
