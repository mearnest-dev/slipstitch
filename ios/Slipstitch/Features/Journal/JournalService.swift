import Foundation
import SwiftUI

/// Networking for the Journal feature. All bodies are local Encodables so this
/// feature stays self-contained and never reaches into other worktrees.
struct JournalService {
    private let client = APIClient.shared

    // MARK: Request bodies

    struct ProjectInput: Encodable {
        var title: String?
        var description: String?
        var craftType: String?
        var yarn: String?
        var yarnWeight: String?
        var hookSize: String?
        var status: ProjectStatus?
        var isPublic: Bool?
        var commentsEnabled: Bool?
        var coverPhotoId: String?
    }

    struct ProgressLogInput: Encodable {
        var note: String?
        var photoId: String?
        var rowCount: Int?
        var hoursSpent: Double?
    }

    /// GET /projects/:id returns the Project fields with `logs`/`photos` alongside.
    struct ProjectDetailEnvelope: Decodable {
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
        let logs: [ProgressLog]?
        let photos: [Photo]?

        var asProject: Project {
            Project(id: id, owner: owner, title: title, description: description,
                    craftType: craftType, yarn: yarn, yarnWeight: yarnWeight,
                    hookSize: hookSize, status: status, isPublic: isPublic,
                    commentsEnabled: commentsEnabled, coverUrl: coverUrl,
                    likeCount: likeCount, liked: liked, logCount: logCount,
                    commentCount: commentCount, createdAt: createdAt, updatedAt: updatedAt)
        }
    }

    // MARK: Projects

    func myProjects(cursor: String? = nil) async throws -> Page<Project> {
        var query: [String: String] = [:]
        if let cursor { query["cursor"] = cursor }
        return try await client.send(.GET, "/projects", query: query)
    }

    func create(title: String, description: String?, craftType: String?,
                yarn: String?, yarnWeight: String?, hookSize: String?, status: ProjectStatus,
                isPublic: Bool, commentsEnabled: Bool? = nil,
                coverPhotoId: String? = nil) async throws -> Project {
        let body = ProjectInput(title: title, description: description, craftType: craftType,
                                yarn: yarn, yarnWeight: yarnWeight, hookSize: hookSize,
                                status: status, isPublic: isPublic,
                                commentsEnabled: commentsEnabled, coverPhotoId: coverPhotoId)
        return try await client.send(.POST, "/projects", body: body)
    }

    func get(id: String) async throws -> (project: Project, logs: [ProgressLog]) {
        let envelope: ProjectDetailEnvelope = try await client.send(.GET, "/projects/\(id)")
        return (envelope.asProject, envelope.logs ?? [])
    }

    func update(id: String, _ input: ProjectInput) async throws -> Project {
        try await client.send(.PATCH, "/projects/\(id)", body: input)
    }

    func updateStatus(id: String, status: ProjectStatus) async throws -> Project {
        try await update(id: id, ProjectInput(status: status))
    }

    func delete(id: String) async throws {
        try await client.sendVoid(.DELETE, "/projects/\(id)")
    }

    // MARK: Progress logs

    func logs(projectId: String, cursor: String? = nil) async throws -> Page<ProgressLog> {
        var query: [String: String] = [:]
        if let cursor { query["cursor"] = cursor }
        return try await client.send(.GET, "/projects/\(projectId)/logs", query: query)
    }

    func addLog(projectId: String, note: String?, rowCount: Int?,
                hoursSpent: Double?, photoId: String? = nil) async throws -> ProgressLog {
        let body = ProgressLogInput(note: note, photoId: photoId,
                                    rowCount: rowCount, hoursSpent: hoursSpent)
        return try await client.send(.POST, "/projects/\(projectId)/logs", body: body)
    }
}

/// Status -> pastel color mapping shared across journal screens.
extension ProjectStatus {
    var tagColor: Color {
        switch self {
        case .planning:   return StitchTheme.Color.sky
        case .inProgress: return StitchTheme.Color.butter
        case .finished:   return StitchTheme.Color.mint
        case .frogged:    return StitchTheme.Color.peach
        }
    }
}
