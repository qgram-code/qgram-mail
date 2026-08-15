import SwiftUI

@MainActor
@main
struct QGramMailApp: App {
    @StateObject private var store = MailStore()
    @StateObject private var settings = SettingsStore()
    @StateObject private var session = Session()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(settings)
                .environmentObject(session)
                .preferredColorScheme(.dark)
                .tint(settings.accent.base)
        }
    }
}
