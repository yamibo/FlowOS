import SwiftUI

@main
struct FlowOSiOSApp: App {
    @State private var coordinator = AppCoordinator()
    @State private var languageManager = LanguageManager.shared

    var body: some Scene {
        WindowGroup {
            MainTabView(coordinator: coordinator)
                .environment(\.locale, languageManager.currentLocale)
                .environment(\.languageVersion, languageManager.languageVersion)
        }
    }
}
