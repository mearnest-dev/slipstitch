import Foundation

// MARK: - Local DTOs for endpoints not covered by a shared model

/// Response shape for POST/DELETE /projects/:id/like.
struct LikeResponse: Codable, Hashable {
    let liked: Bool
    let likeCount: Int
}

/// Search source toggle.
enum SearchSource: String, CaseIterable, Identifiable {
    case internalSource = "internal"
    case external
    case both

    var id: String { rawValue }
    var label: String {
        switch self {
        case .internalSource: return "Internal"
        case .external: return "External"
        case .both: return "Both"
        }
    }
}

/// Networking facade for the Discover feature. Thin wrapper over APIClient.
struct FeedService {
    static let shared = FeedService()

    private let client = APIClient.shared

    // MARK: Feed

    /// The default Discover feed now returns mixed results (internal projects +
    /// external Ravelry pins), same shape as search.
    func fetchFeed(cursor: String?) async throws -> Page<SearchResult> {
        var query: [String: String] = [:]
        if let cursor { query["cursor"] = cursor }
        return try await client.send(.GET, "/feed", query: query)
    }

    // MARK: Search

    func search(q: String, source: SearchSource, cursor: String?) async throws -> Page<SearchResult> {
        var query: [String: String] = ["q": q, "source": source.rawValue]
        if let cursor { query["cursor"] = cursor }
        return try await client.send(.GET, "/search", query: query)
    }

    // MARK: Likes

    @discardableResult
    func like(projectId: String) async throws -> LikeResponse {
        try await client.send(.POST, "/projects/\(projectId)/like")
    }

    @discardableResult
    func unlike(projectId: String) async throws -> LikeResponse {
        try await client.send(.DELETE, "/projects/\(projectId)/like")
    }

    // MARK: Collections

    func myCollections() async throws -> [Collection] {
        try await client.send(.GET, "/collections")
    }

    func createCollection(name: String) async throws -> Collection {
        struct Body: Encodable { let name: String; let isPublic: Bool }
        return try await client.send(.POST, "/collections", body: Body(name: name, isPublic: false))
    }

    @discardableResult
    func addToCollection(collectionId: String, target: CollectionTarget) async throws -> CollectionItem {
        switch target {
        case let .project(id):
            struct Body: Encodable { let projectId: String }
            return try await client.send(.POST, "/collections/\(collectionId)/items", body: Body(projectId: id))
        case let .pin(id):
            struct Body: Encodable { let externalPinId: String }
            return try await client.send(.POST, "/collections/\(collectionId)/items", body: Body(externalPinId: id))
        }
    }
}

/// What's being saved into a collection — an internal project or an external pin.
enum CollectionTarget: Identifiable, Hashable {
    case project(String)
    case pin(String)

    var id: String {
        switch self {
        case let .project(i): return "project-\(i)"
        case let .pin(i): return "pin-\(i)"
        }
    }
}
