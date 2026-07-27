import Foundation

enum AppLanguagePreference: String, CaseIterable, Identifiable {
    case system
    case english
    case portuguese
    case spanish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return L10n.t(.languageSystem)
        case .english: return "English"
        case .portuguese: return "Português"
        case .spanish: return "Español"
        }
    }

    var detail: String {
        switch self {
        case .system:
            return L10n.t(.languageSystemDetail, AppLanguage.phoneLanguageLabel)
        case .english: return "English"
        case .portuguese: return "Português (Brasil)"
        case .spanish: return "Español"
        }
    }

    static var stored: AppLanguagePreference {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey) ?? Self.system.rawValue
        // Older builds used Romanian — treat that as phone default.
        if raw == "romanian" { return .system }
        return AppLanguagePreference(rawValue: raw) ?? .system
    }

    static let storageKey = "appLanguagePreference"

    func resolve() -> AppLanguage {
        switch self {
        case .english: return .english
        case .portuguese: return .portuguese
        case .spanish: return .spanish
        case .system: return AppLanguage.fromPhone()
        }
    }
}

enum AppLanguage: String {
    case english = "en"
    case portuguese = "pt"
    case spanish = "es"

    static var resolved: AppLanguage {
        AppLanguagePreference.stored.resolve()
    }

    static var phoneLanguageLabel: String {
        let tag = Locale.preferredLanguages.first ?? "en"
        let code = String(tag.prefix(2)).lowercased()
        return Locale.current.localizedString(forLanguageCode: code)?.capitalized ?? code.uppercased()
    }

    /// Maps the phone's preferred languages to one we support.
    static func fromPhone() -> AppLanguage {
        for tag in Locale.preferredLanguages {
            let lower = tag.lowercased()
            if lower.hasPrefix("es") { return .spanish }
            if lower.hasPrefix("pt") { return .portuguese }
            if lower.hasPrefix("en") { return .english }
        }
        return .english
    }

    var apiCode: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .portuguese: return "Português"
        case .spanish: return "Español"
        }
    }
}
