import Foundation

enum AppConfig {
    /// API base URL. Override at launch with the STITCHBOOK_API_BASE env var
    /// (set in the scheme) to point at a Railway deploy instead of localhost.
    static var apiBaseURL: URL {
        if let raw = ProcessInfo.processInfo.environment["STITCHBOOK_API_BASE"],
           let url = URL(string: raw) {
            return url
        }
        #if targetEnvironment(simulator)
        return URL(string: "http://localhost:3000/api/v1")!
        #else
        return URL(string: "https://api.stitchbook.app/api/v1")!
        #endif
    }
}
