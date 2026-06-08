import Foundation

enum AppConfig {
    /// API base URL. Defaults to the live production API. For local backend work,
    /// set SLIPSTITCH_API_BASE=http://localhost:3000/api/v1 in the run scheme.
    static var apiBaseURL: URL {
        if let raw = ProcessInfo.processInfo.environment["SLIPSTITCH_API_BASE"],
           let url = URL(string: raw) {
            return url
        }
        return URL(string: "https://api.slipstitch.app/api/v1")!
    }
}
