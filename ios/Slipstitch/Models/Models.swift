import Foundation

// Codable DTOs mirroring docs/API.md. Shared by all feature worktrees.

enum ProjectStatus: String, Codable, CaseIterable, Identifiable {
    case planning, inProgress, finished, frogged
    var id: String { rawValue }
    var label: String {
        switch self {
        case .planning: return "Planning"
        case .inProgress: return "In progress"
        case .finished: return "Finished"
        case .frogged: return "Frogged"
        }
    }
}

struct User: Codable, Identifiable, Hashable {
    let id: String
    let username: String
    let displayName: String
    let email: String?
    let bio: String?
    let avatarUrl: String?
    /// Account-level default for `Project.commentsEnabled` on new projects.
    let defaultCommentsEnabled: Bool?
    let notificationsEnabled: Bool?
    /// Onboarding survey: what the user wants to see in their feed.
    let interests: [String]?
    /// False until the signup survey is completed or skipped.
    let onboardingCompleted: Bool?
    /// Profile links (Instagram, Ravelry, website…), max 5 URLs.
    let socialLinks: [String]?
    /// Whether the Activity tab is shown to other users.
    let activityVisible: Bool?
    let createdAt: Date?
}

struct PublicUser: Codable, Identifiable, Hashable {
    let id: String
    let username: String
    let displayName: String
    let bio: String?
    let avatarUrl: String?
    let socialLinks: [String]?
    let activityVisible: Bool?
    let projectCount: Int?
    let followerCount: Int?
    let followingCount: Int?
    let isFollowing: Bool?
}

struct Project: Codable, Identifiable, Hashable {
    let id: String
    let owner: PublicUser
    let title: String
    let description: String?
    let craftType: String?
    let yarn: String?
    let yarnWeight: String?
    let hookSize: String?
    let status: ProjectStatus
    let isPublic: Bool
    let commentsEnabled: Bool?
    let coverUrl: String?
    let likeCount: Int
    let liked: Bool
    let logCount: Int
    let commentCount: Int?
    let createdAt: Date
    let updatedAt: Date
}

struct Comment: Codable, Identifiable, Hashable {
    let id: String
    let projectId: String
    let parentId: String?
    let author: PublicUser
    let body: String
    let likeCount: Int
    let liked: Bool
    /// Present on top-level comments (one level of threading).
    let replies: [Comment]?
    let createdAt: Date
}

/// One event in a user's public activity feed.
struct ActivityItem: Codable, Identifiable, Hashable {
    struct ProjectCard: Codable, Hashable {
        let id: String
        let title: String
        let coverUrl: String?
    }
    struct UserCard: Codable, Hashable {
        let id: String
        let username: String
        let displayName: String
        let avatarUrl: String?
    }

    let type: String // project | progress | comment | like | follow
    let createdAt: Date
    let project: ProjectCard?
    let user: UserCard?
    let body: String?

    // The API doesn't assign event ids; synthesize a stable one.
    var id: String { "\(type)-\(createdAt.timeIntervalSince1970)-\(project?.id ?? user?.id ?? "")" }
}

/// The standard CYC yarn weight categories, offered as picker options.
/// Stored server-side as a plain string so custom values stay possible.
enum YarnWeight {
    static let options = [
        "Lace (0)", "Super Fine (1)", "Fine (2)", "Light (3)",
        "Medium (4)", "Bulky (5)", "Super Bulky (6)", "Jumbo (7)",
    ]
}

struct ProgressLog: Codable, Identifiable, Hashable {
    let id: String
    let projectId: String
    let note: String?
    let photo: Photo?
    let rowCount: Int?
    let hoursSpent: Double?
    let createdAt: Date
}

struct Photo: Codable, Identifiable, Hashable {
    let id: String
    let url: String
    let width: Int?
    let height: Int?
    let blurhash: String?
    let createdAt: Date?
}

struct Collection: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let isPublic: Bool
    let coverUrl: String?
    let itemCount: Int
    let createdAt: Date
}

struct ExternalPin: Codable, Identifiable, Hashable {
    let id: String
    let source: String
    let sourceUrl: String
    let imageUrl: String
    let title: String?
    let createdAt: Date?
}

/// Compact owner embedded in collection-item projects.
struct CompactOwner: Codable, Hashable {
    let id: String
    let username: String
    let displayName: String
}

/// Lightweight project shape embedded in collection items (the API returns a
/// compact projection here, not the full Project DTO).
struct CollectionItemProject: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let coverUrl: String?
    let owner: CompactOwner
    let status: ProjectStatus
    let likeCount: Int
    let createdAt: Date
}

struct CollectionItem: Codable, Identifiable, Hashable {
    let id: String
    let kind: String // "project" | "pin"
    let project: CollectionItemProject?
    let pin: ExternalPin?
    let createdAt: Date
}

struct SearchResult: Codable, Identifiable, Hashable {
    var id: String { project?.id ?? pin?.id ?? UUID().uuidString }
    let kind: String // "project" | "pin"
    let project: Project?
    let pin: ExternalPin?
}

// Paginated envelope
struct Page<T: Codable & Hashable>: Codable, Hashable {
    let items: [T]
    let nextCursor: String?
}

// Auth
struct AuthTokens: Codable {
    let accessToken: String
    let refreshToken: String
    let accessTokenExpiresAt: Date
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let accessTokenExpiresAt: Date
    let user: User
}
