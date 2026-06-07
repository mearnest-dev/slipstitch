import SwiftUI

/// Email log-in form. POSTs to `/auth/email/login` and applies the session.
struct EmailLoginView: View {
    @EnvironmentObject var session: SessionStore

    private let service = AuthService()

    @State private var email = ""
    @State private var password = ""

    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        AuthValidation.isValidEmail(email) && !password.isEmpty
    }

    var body: some View {
        ZStack {
            StitchTheme.Color.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: StitchTheme.Spacing.lg) {
                    VStack(spacing: StitchTheme.Spacing.xs) {
                        Text("Welcome back")
                            .font(StitchTheme.Font.title)
                            .foregroundStyle(StitchTheme.Color.textPrimary)
                        Text("Pick up where you left off.")
                            .font(StitchTheme.Font.body)
                            .foregroundStyle(StitchTheme.Color.textSecondary)
                    }
                    .padding(.top, StitchTheme.Spacing.lg)

                    StitchCard {
                        VStack(spacing: StitchTheme.Spacing.md) {
                            AuthField(title: "Email", text: $email,
                                      keyboard: .emailAddress, textContentType: .emailAddress,
                                      autocapitalize: false)
                            AuthField(title: "Password", text: $password,
                                      isSecure: true, textContentType: .password)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(StitchTheme.Font.caption)
                            .foregroundStyle(StitchTheme.Color.accent)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    StitchPrimaryButton(title: "Log in", isLoading: isLoading) {
                        submit()
                    }
                    .opacity(isValid ? 1 : 0.5)
                    .disabled(!isValid || isLoading)
                }
                .padding(StitchTheme.Spacing.lg)
            }
        }
        .navigationTitle("Log in")
        .navigationBarTitleDisplayMode(.inline)
        .tint(StitchTheme.Color.accent)
    }

    private func submit() {
        guard isValid else { return }
        errorMessage = nil
        isLoading = true
        Task {
            do {
                let response = try await service.login(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
                session.apply(response)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? "Couldn't log you in. Please try again."
            }
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack { EmailLoginView() }
        .environmentObject(SessionStore())
}
