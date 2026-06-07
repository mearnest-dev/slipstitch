import SwiftUI

@main
struct StitchbookApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .tint(StitchTheme.Color.accent)
        }
    }
}
