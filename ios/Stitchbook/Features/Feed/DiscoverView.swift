import SwiftUI

// PLACEHOLDER — replaced by the feat/ios-feed worktree.
// Build: Pinterest-style masonry discovery grid (GET /feed), search bar with
// source toggle internal/external/both (GET /search), project detail navigation,
// like + save-to-collection actions.
struct DiscoverView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                Text("Discover feed — built by the feed worktree")
                    .font(StitchTheme.Font.body)
                    .foregroundStyle(StitchTheme.Color.textSecondary)
                    .padding()
            }
            .background(StitchTheme.Color.background)
            .navigationTitle("Discover")
        }
    }
}
