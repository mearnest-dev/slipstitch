import SwiftUI

/// Email sign-up form. Validates the fields locally, then POSTs to
/// `/auth/email/register` and applies the returned session.
struct EmailRegisterView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    private let service = AuthService()

    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var displayName = ""

    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        AuthValidation.isValidEmail(email)
            && password.count >= 6
            && !username.trimmingCharacters(in: .whitespaces).isEmpty
            && !displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            StitchTheme.Color.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: StitchTheme.Spacing.lg) {
                    VStack(spacing: StitchTheme.Spacing.xs) {
                        Text("Create your account")
                            .font(StitchTheme.Font.title)
                            .foregroundStyle(StitchTheme.Color.textPrimary)
                        Text("Welcome to the yarn stash.")
                            .font(StitchTheme.Font.body)
                            .foregroundStyle(StitchTheme.Color.textSecondary)
                    }
                    .padding(.top, StitchTheme.Spacing.lg)

                    StitchCard {
                        VStack(spacing: StitchTheme.Spacing.md) {
                            AuthField(title: "Display name", text: $displayName,
                                      textContentType: .name)
                            AuthField(title: "Username", text: $username,
                                      textContentType: .username, autocapitalize: false)
                            AuthField(title: "Email", text: $email,
                                      keyboard: .emailAddress, textContentType: .emailAddress,
                                      autocapitalize: false)
                            AuthField(title: "Password", text: $password,
                                      isSecure: true, textContentType: .newPassword,
                                      footnote: "At least 6 characters.")
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(StitchTheme.Font.caption)
                            .foregroundStyle(StitchTheme.Color.accent)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    StitchPrimaryButton(title: "Sign up", isLoading: isLoading) {
                        submit()
                    }
                    .opacity(isValid ? 1 : 0.5)
                    .disabled(!isValid || isLoading)
                }
                .padding(StitchTheme.Spacing.lg)
            }
        }
        .navigationTitle("Sign up")
        .navigationBarTitleDisplayMode(.inline)
        .tint(StitchTheme.Color.accent)
    }

    private func submit() {
        guard isValid else { return }
        errorMessage = nil
        isLoading = true
        Task {
            do {
                let response = try await service.register(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password,
                    username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                    displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                session.apply(response)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? "Something went wrong. Please try again."
            }
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack { EmailRegisterView() }
        .environmentObject(SessionStore())
}
