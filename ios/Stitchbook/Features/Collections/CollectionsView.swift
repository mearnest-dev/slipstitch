import SwiftUI

// PLACEHOLDER — replaced by the feat/ios-collections worktree.
// Build: grid of the user's collections (GET /collections), create/edit collection,
// collection detail showing saved projects + external pins, add/remove items.
struct CollectionsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                Text("Collections — built by the collections worktree")
                    .font(StitchTheme.Font.body)
                    .foregroundStyle(StitchTheme.Color.textSecondary)
                    .padding()
            }
            .background(StitchTheme.Color.background)
            .navigationTitle("Collections")
        }
    }
}
