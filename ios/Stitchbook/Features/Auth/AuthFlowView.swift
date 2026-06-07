import SwiftUI

// PLACEHOLDER — replaced by the feat/ios-auth worktree.
// Build: welcome screen, Sign in with Apple button (AuthenticationServices),
// email register/login forms. On success call `session.apply(authResponse)`.
// Endpoints: POST /auth/apple, /auth/email/register, /auth/email/login (docs/API.md).
struct AuthFlowView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        ZStack {
            StitchTheme.Color.background.ignoresSafeArea()
            VStack(spacing: StitchTheme.Spacing.lg) {
                Text("🧶").font(.system(size: 72))
                Text("Welcome to Stitchbook")
                    .font(StitchTheme.Font.largeTitle)
                    .foregroundStyle(StitchTheme.Color.textPrimary)
                Text("Sign-in coming from the auth worktree")
                    .font(StitchTheme.Font.body)
                    .foregroundStyle(StitchTheme.Color.textSecondary)
            }
            .padding(StitchTheme.Spacing.xl)
        }
    }
}
