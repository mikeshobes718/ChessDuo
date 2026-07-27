import SwiftUI

@main
struct ChessCoachApp: App {
    @StateObject private var model = GameViewModel()
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    @AppStorage(AppLanguagePreference.storageKey) private var languagePreference =
        AppLanguagePreference.system.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme)
                // Rebuild UI when the in-app language changes.
                .id(languagePreference)
        }
    }
}
