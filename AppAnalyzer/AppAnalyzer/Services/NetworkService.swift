import Foundation

/// Service for fetching app ratings and security data from the internet
/// Uses iTunes Search API for App Store data
final class NetworkService {

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = true
        // Security: Only allow HTTPS
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        self.session = URLSession(configuration: config)
    }

    /// Fetches app information from the iTunes Search API
    func lookupApp(bundleId: String) async throws -> AppStoreResult? {
        guard let encodedId = bundleId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        let urlString = "https://itunes.apple.com/lookup?bundleId=\(encodedId)"
        guard let url = URL(string: urlString) else { return nil }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        let result = try JSONDecoder().decode(iTunesSearchResponse.self, from: data)
        return result.results.first
    }

    /// Batch lookup for multiple apps
    func lookupApps(bundleIds: [String]) async -> [String: AppStoreResult] {
        var results: [String: AppStoreResult] = [:]

        await withTaskGroup(of: (String, AppStoreResult?).self) { group in
            for bundleId in bundleIds {
                group.addTask {
                    let result = try? await self.lookupApp(bundleId: bundleId)
                    return (bundleId, result)
                }
            }

            for await (bundleId, result) in group {
                if let result = result {
                    results[bundleId] = result
                }
            }
        }

        return results
    }
}

// MARK: - API Models

struct iTunesSearchResponse: Codable {
    let resultCount: Int
    let results: [AppStoreResult]
}

struct AppStoreResult: Codable {
    let trackName: String?
    let bundleId: String?
    let averageUserRating: Double?
    let userRatingCount: Int?
    let currentVersionReleaseDate: String?
    let fileSizeBytes: String?
    let sellerName: String?
    let primaryGenreName: String?
    let version: String?
    let minimumOsVersion: String?
}
