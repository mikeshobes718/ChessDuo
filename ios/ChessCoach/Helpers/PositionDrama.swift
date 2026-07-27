import Foundation

enum DramaLevel: Int, Comparable {
    case calm = 0
    case pressure = 1
    case check = 2
    case critical = 3
    case finishedLoss = 4
    case finishedWin = 5

    static func < (lhs: DramaLevel, rhs: DramaLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct GameDrama: Equatable {
    var level: DramaLevel = .calm
    var focusSide: PlayerColor?
    var kingSquare: String?
    var headline: String?
    var detail: String?
    var focusName: String?
    var aboutYou: Bool?
    var sideLabel: String?

    static let calm = GameDrama()

    var showsBoardPulse: Bool {
        switch level {
        case .check, .critical, .finishedLoss, .finishedWin: return true
        default: return false
        }
    }

    var showsBoardShake: Bool {
        level == .check || level == .critical || level == .finishedLoss
    }

    var isAlarming: Bool {
        level == .pressure || level == .check || level == .critical || level == .finishedLoss
    }

    var subjectChip: String? {
        guard let focusName else { return nil }
        let who = aboutYou == true ? L10n.t(.youLabel).uppercased() : focusName
        if let sideLabel {
            return "\(who) · \(sideLabel)"
        }
        return who
    }
}

enum PositionDrama {
    private static let values: [Character: Int] = [
        "p": 1, "n": 3, "b": 3, "r": 5, "q": 9,
        "P": 1, "N": 3, "B": 3, "R": 5, "Q": 9
    ]

    static func evaluate(
        fen: String,
        status: String,
        isCheck: Bool,
        legalMoveCount: Int,
        you: PlayerColor?,
        whiteName: String,
        blackName: String
    ) -> GameDrama {
        let position = ChessPosition(fen: fen)
        let turn: PlayerColor = {
            let parts = fen.split(separator: " ")
            return (parts.count > 1 && parts[1] == "b") ? .black : .white
        }()

        if ["white_won", "black_won", "draw"].contains(status.lowercased()) {
            return finishedDrama(
                status: status,
                you: you,
                whiteName: whiteName,
                blackName: blackName,
                position: position
            )
        }

        let material = materialScore(fen: fen)

        if isCheck {
            let aboutYou = you.map { $0 == turn }
            let focusName = name(for: turn, whiteName: whiteName, blackName: blackName)
            let critical = legalMoveCount > 0 && legalMoveCount <= 2
            let plural = legalMoveCount == 1 ? L10n.t(.pluralEmpty) : L10n.t(.pluralS)
            let headline: String
            let detail: String
            if critical {
                headline = aboutYou == true
                    ? L10n.t(.dramaCriticalYou)
                    : L10n.t(.dramaCriticalThem, focusName)
                detail = aboutYou == true
                    ? L10n.t(.dramaCriticalDetailYou, legalMoveCount, plural)
                    : L10n.t(.dramaCriticalDetailThem, focusName, legalMoveCount, plural)
            } else {
                headline = aboutYou == true
                    ? L10n.t(.dramaCheckYou)
                    : L10n.t(.dramaCheckThem, focusName)
                detail = aboutYou == true
                    ? L10n.t(.dramaCheckDetailYou)
                    : L10n.t(.dramaCheckDetailThem, focusName)
            }
            return GameDrama(
                level: critical ? .critical : .check,
                focusSide: turn,
                kingSquare: position.squareOfKing(isWhite: turn == .white),
                headline: headline,
                detail: detail,
                focusName: focusName,
                aboutYou: aboutYou,
                sideLabel: turn.displayName
            )
        }

        let whiteBehind = material <= -5
        let blackBehind = material >= 5
        if whiteBehind || blackBehind {
            let focus: PlayerColor = whiteBehind ? .white : .black
            let aboutYou = you.map { $0 == focus }
            let focusName = name(for: focus, whiteName: whiteName, blackName: blackName)
            let deficit = abs(material)
            let otherName = name(for: focus.opponent, whiteName: whiteName, blackName: blackName)
            let detail: String
            if aboutYou == true {
                detail = L10n.t(.dramaPressureDetailYou, deficit, otherName)
            } else if aboutYou == false {
                detail = L10n.t(.dramaPressureDetailThem, focusName, deficit)
            } else {
                detail = L10n.t(.dramaPressureDetailNeutral, focusName, deficit)
            }
            return GameDrama(
                level: .pressure,
                focusSide: focus,
                kingSquare: position.squareOfKing(isWhite: focus == .white),
                headline: aboutYou == true
                    ? L10n.t(.dramaPressureYou)
                    : L10n.t(.dramaPressureThem, focusName),
                detail: detail,
                focusName: focusName,
                aboutYou: aboutYou,
                sideLabel: focus.displayName
            )
        }

        return .calm
    }

    private static func finishedDrama(
        status: String,
        you: PlayerColor?,
        whiteName: String,
        blackName: String,
        position: ChessPosition
    ) -> GameDrama {
        let lowered = status.lowercased()
        if lowered == "draw" {
            return GameDrama(
                level: .calm,
                focusSide: nil,
                kingSquare: nil,
                headline: nil,
                detail: nil,
                focusName: nil,
                aboutYou: nil,
                sideLabel: nil
            )
        }
        let whiteWon = lowered == "white_won"
        let winner: PlayerColor = whiteWon ? .white : .black
        let loser = winner.opponent
        let winnerName = name(for: winner, whiteName: whiteName, blackName: blackName)
        let loserName = name(for: loser, whiteName: whiteName, blackName: blackName)
        let youWon = you == winner
        let youLost = you == loser
        let headline: String
        if youWon {
            headline = L10n.t(.dramaYouWon, winnerName)
        } else if youLost {
            headline = L10n.t(.dramaYouLost, winnerName)
        } else {
            headline = L10n.t(.dramaTheyWon, winnerName)
        }
        return GameDrama(
            level: youWon ? .finishedWin : .finishedLoss,
            focusSide: youWon ? winner : loser,
            kingSquare: position.squareOfKing(isWhite: (youWon ? winner : loser) == .white),
            headline: headline,
            detail: youWon
                ? L10n.t(.dramaWinDetail, loserName)
                : L10n.t(.dramaLossDetail, loserName),
            focusName: youWon ? winnerName : loserName,
            aboutYou: youWon ? true : (youLost ? true : false),
            sideLabel: (youWon ? winner : loser).displayName
        )
    }

    private static func name(for side: PlayerColor, whiteName: String, blackName: String) -> String {
        side == .white ? whiteName : blackName
    }

    private static func materialScore(fen: String) -> Int {
        let placement = fen.split(separator: " ").first.map(String.init) ?? ""
        var score = 0
        for ch in placement where ch.isLetter {
            let value = values[ch] ?? 0
            score += ch.isUppercase ? value : -value
        }
        return score
    }
}

extension ChessPosition {
    func squareOfKing(isWhite: Bool) -> String? {
        let target: Character = isWhite ? "K" : "k"
        return pieces.first(where: { $0.value.symbol == target })?.key
    }
}
