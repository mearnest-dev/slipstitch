import Foundation

/// Networking for the Collections feature. Wraps `APIClient` and maps the
/// Collections endpoints from docs/API.md to typed async methods.
struct CollectionsService {
    private let client = APIClient.shared

    // MARK: Request bodies

    private struct CreateBody: Encodable {
        let name: String
        let description: String?
        let isPublic: Bool
    }

    private struct UpdateBody: Encodable {
        let name: String?
        let description: String?
        let isPublic: Bool?
    }

    // MARK: Detail response (Collection + nested items)

    /// `GET /collections/:id` returns a Collection with a nested `items` array.
    /// Collection's own fields are flattened at the top level, so decode them
    /// alongside `items` here.
    struct CollectionDetail: Decodable {
        let collection: Collection
        let items: [CollectionItem]

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            collection = try container.decode(Collection.self)

            let keyed = try decoder.container(keyedBy: ItemsKey.self)
            items = try keyed.decodeIfPresent([CollectionItem].self, forKey: .items) ?? []
        }

        private enum ItemsKey: String, CodingKey { case items }
    }

    // MARK: Methods

    func list() async throws -> [Collection] {
        try await client.send(.GET, "/collections")
    }

    func create(name: String, description: String?, isPublic: Bool) async throws -> Collection {
        let body = CreateBody(
            name: name,
            description: (description?.isEmpty == false) ? description : nil,
            isPublic: isPublic
        )
        return try await client.send(.POST, "/collections", body: body)
    }

    func get(id: String) async throws -> CollectionDetail {
        try await client.send(.GET, "/collections/\(id)")
    }

    func update(id: String, name: String?, description: String?, isPublic: Bool?) async throws -> Collection {
        let body = UpdateBody(name: name, description: description, isPublic: isPublic)
        return try await client.send(.PATCH, "/collections/\(id)", body: body)
    }

    func delete(id: String) async throws {
        try await client.sendVoid(.DELETE, "/collections/\(id)")
    }

    func removeItem(collectionId: String, itemId: String) async throws {
        try await client.sendVoid(.DELETE, "/collections/\(collectionId)/items/\(itemId)")
    }
}
