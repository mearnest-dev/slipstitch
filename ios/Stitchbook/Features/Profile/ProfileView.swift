import SwiftUI

// PLACEHOLDER — replaced by the feat/ios-profile worktree.
// Build: current user's profile (avatar, bio, project grid), edit profile (PATCH /me),
// photo upload flow (PhotosPicker -> POST /media/upload-url -> PUT to R2 ->
// POST /media/:id/complete), follower/following counts, sign out.
struct ProfileView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: StitchTheme.Spacing.md) {
                    Text(session.currentUser?.displayName ?? "Profile")
                        .font(StitchTheme.Font.title)
                        .foregroundStyle(StitchTheme.Color.textPrimary)
                    Button("Sign out") { session.signOut() }
                        .foregroundStyle(StitchTheme.Color.accent)
                }
                .padding()
            }
            .background(StitchTheme.Color.background)
            .navigationTitle("Profile")
        }
    }
}
