import Foundation

/// Networking facade for the Profile feature. Thin async wrappers over
/// `APIClient` for the Users (`/me`, `/users/:id`) and Projects endpoints used
/// by the profile screens. Keeps view code free of path/DTO details.
@MainActor
struct ProfileService {

    /// Body for `PATCH /me`. Only non-nil fields are sent; `JSONEncoder` omits
    /// nils here because the backend treats absent keys as "leave unchanged".
    private struct UpdateProfileBody: Encodable {
        let displayName: String?
        let bio: String?
        let avatarPhotoId: String?
    }

    /// `GET /me` — the signed-in user (includes email).
    func me() async throws -> User {
        try await APIClient.shared.send(.GET, "/me")
    }

    /// `GET /users/:id` — public profile with project / follower / following counts.
    func publicUser(id: String) async throws -> PublicUser {
        try await APIClient.shared.send(.GET, "/users/\(id)")
    }

    /// `PATCH /me` — update editable profile fields. Pass only what changed.
    func updateProfile(displayName: String? = nil,
                       bio: String? = nil,
                       avatarPhotoId: String? = nil) async throws -> User {
        try await APIClient.shared.send(
            .PATCH, "/me",
            body: UpdateProfileBody(displayName: displayName, bio: bio, avatarPhotoId: avatarPhotoId)
        )
    }

    /// `PATCH /me` — account-level settings.
    func updateSettings(defaultCommentsEnabled: Bool? = nil,
                        notificationsEnabled: Bool? = nil) async throws -> User {
        struct Body: Encodable {
            let defaultCommentsEnabled: Bool?
            let notificationsEnabled: Bool?
        }
        return try await APIClient.shared.send(
            .PATCH, "/me",
            body: Body(defaultCommentsEnabled: defaultCommentsEnabled,
                       notificationsEnabled: notificationsEnabled)
        )
    }

    /// `DELETE /me` — permanently delete the signed-in account.
    func deleteAccount() async throws {
        try await APIClient.shared.sendVoid(.DELETE, "/me")
    }

    /// `GET /users/search?q=` — find people by username or display name.
    func searchUsers(q: String) async throws -> [PublicUser] {
        struct Envelope: Decodable { let items: [PublicUser] }
        let envelope: Envelope = try await APIClient.shared.send(
            .GET, "/users/search", query: ["q": q]
        )
        return envelope.items
    }

    /// `POST /users/:id/follow`
    func follow(userId: String) async throws {
        struct R: Decodable { let following: Bool }
        let _: R = try await APIClient.shared.send(.POST, "/users/\(userId)/follow")
    }

    /// `DELETE /users/:id/follow`
    func unfollow(userId: String) async throws {
        struct R: Decodable { let following: Bool }
        let _: R = try await APIClient.shared.send(.DELETE, "/users/\(userId)/follow")
    }

    /// `GET /users/:id/followers`
    func followers(of userId: String, cursor: String? = nil) async throws -> Page<PublicUser> {
        var query: [String: String] = [:]
        if let cursor { query["cursor"] = cursor }
        return try await APIClient.shared.send(.GET, "/users/\(userId)/followers", query: query)
    }

    /// `GET /users/:id/following`
    func following(of userId: String, cursor: String? = nil) async throws -> Page<PublicUser> {
        var query: [String: String] = [:]
        if let cursor { query["cursor"] = cursor }
        return try await APIClient.shared.send(.GET, "/users/\(userId)/following", query: query)
    }

    /// `GET /users/:id/projects` — the user's own projects, paginated.
    func projects(for userId: String, cursor: String? = nil) async throws -> Page<Project> {
        var query: [String: String] = [:]
        if let cursor { query["cursor"] = cursor }
        return try await APIClient.shared.send(.GET, "/users/\(userId)/projects", query: query)
    }

    /// Convenience for "my own projects" — resolves the signed-in user via `/me`
    /// would be wasteful, so callers pass their known id.
    func myProjects(userId: String, cursor: String? = nil) async throws -> Page<Project> {
        try await projects(for: userId, cursor: cursor)
    }
}
