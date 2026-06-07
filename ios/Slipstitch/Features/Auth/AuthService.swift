import Foundation

/// Thin wrapper around the three auth endpoints. Each call hits the API with
/// `authorized: false` (no bearer token yet) and returns the decoded
/// `AuthResponse`, which the caller hands to `SessionStore.apply(_:)`.
struct AuthService {
    let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    // MARK: Request bodies

    private struct EmailRegisterBody: Encodable {
        let email: String
        let password: String
        let username: String
        let displayName: String
    }

    private struct EmailLoginBody: Encodable {
        let email: String
        let password: String
    }

    private struct AppleBody: Encodable {
        let identityToken: String
        let nonce: String
        let fullName: String?
    }

    // MARK: Calls

    func register(email: String, password: String, username: String, displayName: String) async throws -> AuthResponse {
        try await client.send(
            .POST, "/auth/email/register",
            body: EmailRegisterBody(email: email, password: password, username: username, displayName: displayName),
            authorized: false
        )
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        try await client.send(
            .POST, "/auth/email/login",
            body: EmailLoginBody(email: email, password: password),
            authorized: false
        )
    }

    func apple(identityToken: String, nonce: String, fullName: String?) async throws -> AuthResponse {
        try await client.send(
            .POST, "/auth/apple",
            body: AppleBody(identityToken: identityToken, nonce: nonce, fullName: fullName),
            authorized: false
        )
    }
}

// MARK: - Validation helpers shared by the email forms

enum AuthValidation {
    /// Very light email sanity check: non-empty local + domain with a dot.
    static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let at = trimmed.firstIndex(of: "@"), at != trimmed.startIndex else { return false }
        let domain = trimmed[trimmed.index(after: at)...]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }
}
