import Foundation

enum ComputerDifficulty: String, CaseIterable, Identifiable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: return L10n.t(.difficultyEasy)
        case .medium: return L10n.t(.difficultyMedium)
        case .hard: return L10n.t(.difficultyHard)
        }
    }

    var detail: String {
        switch self {
        case .easy: return L10n.t(.difficultyEasyDetail)
        case .medium: return L10n.t(.difficultyMediumDetail)
        case .hard: return L10n.t(.difficultyHardDetail)
        }
    }

    static var stored: ComputerDifficulty {
        let raw = UserDefaults.standard.string(forKey: "computerDifficulty") ?? ComputerDifficulty.medium.rawValue
        return ComputerDifficulty(rawValue: raw) ?? .medium
    }
}
