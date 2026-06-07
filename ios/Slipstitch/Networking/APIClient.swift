import Foundation

enum APIError: Error, LocalizedError {
    case http(status: Int, code: String, message: String)
    case decoding(Error)
    case transport(Error)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case let .http(_, _, message): return message
        case .decoding: return "Couldn't read the server response."
        case let .transport(err): return err.localizedDescription
        case .unauthorized: return "Please sign in again."
        }
    }
}

struct APIErrorBody: Decodable { struct E: Decodable { let code: String; let message: String }; let error: E }

enum HTTPMethod: String { case GET, POST, PATCH, DELETE }

/// Shared HTTP client. Injects the bearer token, decodes JSON (ISO-8601 dates),
/// and transparently refreshes the access token once on a 401.
final class APIClient {
    static let shared = APIClient()

    private let session = URLSession(configuration: .default)
    private let baseURL = AppConfig.apiBaseURL

    // Token accessors are wired up by SessionStore at launch.
    var accessToken: () -> String? = { Keychain.get("accessToken") }
    var refreshToken: () -> String? = { Keychain.get("refreshToken") }
    var onTokensRefreshed: (AuthTokens) -> Void = { _ in }
    var onAuthLost: () -> Void = {}

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            if let date = ISO8601DateFormatter.slipstitch.date(from: s) { return date }
            let plain = ISO8601DateFormatter()
            if let date = plain.date(from: s) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Bad date: \(s)"))
        }
        return d
    }()

    private static let encoder = JSONEncoder()

    func send<T: Decodable>(_ method: HTTPMethod, _ path: String,
                            query: [String: String] = [:],
                            body: Encodable? = nil,
                            authorized: Bool = true) async throws -> T {
        let data = try await raw(method, path, query: query, body: body, authorized: authorized)
        if T.self == EmptyResponse.self { return EmptyResponse() as! T }
        do { return try Self.decoder.decode(T.self, from: data) }
        catch { throw APIError.decoding(error) }
    }

    /// Discardable-result variant for endpoints returning 204.
    @discardableResult
    func sendVoid(_ method: HTTPMethod, _ path: String,
                  query: [String: String] = [:],
                  body: Encodable? = nil,
                  authorized: Bool = true) async throws -> Data {
        try await raw(method, path, query: query, body: body, authorized: authorized)
    }

    private func raw(_ method: HTTPMethod, _ path: String,
                     query: [String: String], body: Encodable?,
                     authorized: Bool, isRetry: Bool = false) async throws -> Data {
        var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) } }

        var req = URLRequest(url: comps.url!)
        req.httpMethod = method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if authorized, let token = accessToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try Self.encoder.encode(AnyEncodable(body))
        }

        let data: Data, response: URLResponse
        do { (data, response) = try await session.data(for: req) }
        catch { throw APIError.transport(error) }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport(URLError(.badServerResponse))
        }

        if http.statusCode == 401 && authorized && !isRetry {
            if await tryRefresh() {
                return try await raw(method, path, query: query, body: body, authorized: authorized, isRetry: true)
            }
            onAuthLost()
            throw APIError.unauthorized
        }

        guard (200..<300).contains(http.statusCode) else {
            if let parsed = try? Self.decoder.decode(APIErrorBody.self, from: data) {
                throw APIError.http(status: http.statusCode, code: parsed.error.code, message: parsed.error.message)
            }
            throw APIError.http(status: http.statusCode, code: "http_\(http.statusCode)",
                                message: "Request failed (\(http.statusCode))")
        }
        return data
    }

    private func tryRefresh() async -> Bool {
        guard let token = refreshToken() else { return false }
        struct Body: Encodable { let refreshToken: String }
        do {
            let tokens: AuthTokens = try await send(.POST, "/auth/refresh",
                                                    body: Body(refreshToken: token), authorized: false)
            onTokensRefreshed(tokens)
            return true
        } catch { return false }
    }
}

struct EmptyResponse: Decodable {}

/// Type-erased Encodable so we can pass any Encodable body.
struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void
    init(_ wrapped: Encodable) { encode = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encode(encoder) }
}

extension ISO8601DateFormatter {
    static let slipstitch: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
