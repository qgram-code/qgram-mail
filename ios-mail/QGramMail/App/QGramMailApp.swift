import SwiftUI

@MainActor
@main
struct QGramMailApp: App {
    @StateObject private var store = MailStore()
    @StateObject private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(settings)
                .preferredColorScheme(.dark)
                .tint(settings.accent.base)
        }
    }
}
