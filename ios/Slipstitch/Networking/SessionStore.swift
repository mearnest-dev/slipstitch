import Foundation

/// App-wide auth/session state. Owns token persistence and the current user.
/// The Auth worktree calls `apply(_:)` after a successful login/registration,
/// and `signOut()` to clear. RootView observes `state` to switch flows.
@MainActor
final class SessionStore: ObservableObject {
    enum State { case loading, signedOut, signedIn }

    @Published private(set) var state: State = .loading
    @Published private(set) var currentUser: User?

    init() {
        let client = APIClient.shared
        client.onTokensRefreshed = { [weak self] tokens in
            Keychain.set(tokens.accessToken, for: "accessToken")
            Keychain.set(tokens.refreshToken, for: "refreshToken")
            _ = self
        }
        client.onAuthLost = { [weak self] in
            Task { @MainActor in self?.signOut() }
        }
    }

    /// Restore session on launch: if we have tokens, fetch /me to confirm.
    func restore() async {
        guard Keychain.get("accessToken") != nil else {
            state = .signedOut
            return
        }
        do {
            let me: User = try await APIClient.shared.send(.GET, "/me")
            currentUser = me
            state = .signedIn
        } catch {
            signOut()
        }
    }

    /// Called by the Auth flow after register/login/apple.
    func apply(_ response: AuthResponse) {
        Keychain.set(response.accessToken, for: "accessToken")
        Keychain.set(response.refreshToken, for: "refreshToken")
        currentUser = response.user
        state = .signedIn
    }

    func updateUser(_ user: User) { currentUser = user }

    func signOut() {
        Keychain.delete("accessToken")
        Keychain.delete("refreshToken")
        currentUser = nil
        state = .signedOut
    }
}
