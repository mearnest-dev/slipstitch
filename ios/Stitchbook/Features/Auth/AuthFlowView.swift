import SwiftUI
import AuthenticationServices
import CryptoKit

/// Welcome / entry screen for the auth flow. Offers Sign in with Apple,
/// email sign-up, and email log-in. On any successful auth call we hand the
/// `AuthResponse` to `session.apply(_:)`, which flips the app to the signed-in flow.
struct AuthFlowView: View {
    @EnvironmentObject var session: SessionStore

    private let service = AuthService()

    @State private var currentNonce: String?
    @State private var isAppleLoading = false
    @State private var appleError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                StitchTheme.Color.background.ignoresSafeArea()

                VStack(spacing: StitchTheme.Spacing.xl) {
                    Spacer()

                    VStack(spacing: StitchTheme.Spacing.md) {
                        Text("🧶").font(.system(size: 84))
                        Text("Stitchbook")
                            .font(StitchTheme.Font.largeTitle)
                            .foregroundStyle(StitchTheme.Color.textPrimary)
                        Text("Your cozy corner for tracking every stitch, skein, and finished make.")
                            .font(StitchTheme.Font.body)
                            .foregroundStyle(StitchTheme.Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, StitchTheme.Spacing.lg)
                    }

                    Spacer()

                    VStack(spacing: StitchTheme.Spacing.md) {
                        appleButton

                        if let appleError {
                            Text(appleError)
                                .font(StitchTheme.Font.caption)
                                .foregroundStyle(StitchTheme.Color.accent)
                                .multilineTextAlignment(.center)
                        }

                        NavigationLink {
                            EmailRegisterView()
                        } label: {
                            StitchPrimaryButton(title: "Sign up with email") {}
                                .allowsHitTesting(false)
                        }

                        NavigationLink {
                            EmailLoginView()
                        } label: {
                            Text("Already have an account? **Log in**")
                                .font(StitchTheme.Font.body)
                                .foregroundStyle(StitchTheme.Color.textSecondary)
                        }
                        .padding(.top, StitchTheme.Spacing.xs)
                    }
                    .padding(.horizontal, StitchTheme.Spacing.xl)
                    .padding(.bottom, StitchTheme.Spacing.xl)
                }
            }
            .navigationBarHidden(true)
        }
        .tint(StitchTheme.Color.accent)
    }

    private var appleButton: some View {
        ZStack {
            SignInWithAppleButton(.signIn) { request in
                let nonce = Self.randomNonceString()
                currentNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = Self.sha256(nonce)
            } onCompletion: { result in
                handleAppleCompletion(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 50)
            .clipShape(RoundedRectangle(cornerRadius: StitchTheme.Radius.md, style: .continuous))
            .disabled(isAppleLoading)
            .opacity(isAppleLoading ? 0.5 : 1)

            if isAppleLoading {
                ProgressView().tint(.white)
            }
        }
    }

    // MARK: - Apple sign-in handling

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        appleError = nil
        switch result {
        case let .success(authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let identityToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                appleError = "Couldn't read your Apple credentials. Please try again."
                return
            }

            let fullName = Self.formatName(credential.fullName)
            isAppleLoading = true
            Task {
                do {
                    let response = try await service.apple(identityToken: identityToken, nonce: nonce, fullName: fullName)
                    session.apply(response)
                } catch {
                    appleError = (error as? LocalizedError)?.errorDescription ?? "Sign in with Apple failed. Please try again."
                }
                isAppleLoading = false
            }

        case let .failure(error):
            // The user cancelling the sheet shouldn't surface as a scary error.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            appleError = error.localizedDescription
        }
    }

    private static func formatName(_ components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatted = PersonNameComponentsFormatter().string(from: components)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return formatted.isEmpty ? nil : formatted
    }

    // MARK: - Nonce helpers

    private static func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status != errSecSuccess { random = UInt8.random(in: 0...255) }
            if random < UInt8(charset.count) {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}

#Preview {
    AuthFlowView()
        .environmentObject(SessionStore())
}
