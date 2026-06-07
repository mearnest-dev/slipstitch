import SwiftUI

// PLACEHOLDER — replaced by the feat/ios-journal worktree.
// Build: the user's crochet projects list (GET /projects), create project,
// project detail with a timeline of progress logs, add-progress-log sheet
// (note, photo, row count, hours), status changes. This is the journaling core.
struct JournalView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                Text("Journal — built by the journal worktree")
                    .font(StitchTheme.Font.body)
                    .foregroundStyle(StitchTheme.Color.textSecondary)
                    .padding()
            }
            .background(StitchTheme.Color.background)
            .navigationTitle("Journal")
        }
    }
}
