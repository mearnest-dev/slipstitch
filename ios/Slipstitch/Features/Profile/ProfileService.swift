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
