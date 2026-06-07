import SwiftUI

/// Top-level shell. Shows auth flow when signed out, the main tab bar when signed in.
/// NOTE: The Auth, Feed, Collections, Journal, and Profile feature views referenced
/// here are built by their own parallel worktrees. Until those land, lightweight
/// placeholders in Features/Placeholders.swift keep the app compiling.
struct RootView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        Group {
            switch session.state {
            case .loading:
                StitchSplash()
            case .signedOut:
                AuthFlowView()
            case .signedIn:
                MainTabView()
            }
        }
        .task { await session.restore() }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            DiscoverView()
                .tabItem { Label("Discover", systemImage: "sparkles") }
            CollectionsView()
                .tabItem { Label("Collections", systemImage: "square.grid.2x2") }
            JournalView()
                .tabItem { Label("Journal", systemImage: "book.closed") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}

struct StitchSplash: View {
    var body: some View {
        ZStack {
            StitchTheme.Color.brandGradient.ignoresSafeArea()
            VStack(spacing: StitchTheme.Spacing.md) {
                Image("Glyph")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .foregroundStyle(.white)
                Text("Slipstitch")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
            }
        }
    }
}
