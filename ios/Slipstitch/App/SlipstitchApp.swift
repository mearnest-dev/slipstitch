import SwiftUI

@main
struct SlipstitchApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .tint(StitchTheme.Color.accent)
        }
    }
}
