import Foundation

struct ReadwiseAPIService {
    private let baseURL = "https://readwise.io/api/v3/list/"
    private let maxRetries = 3

    /// Fetch the most recent document tagged with WatchSummary.
    /// Searches all locations since Readwise may auto-move documents.
    func fetchLatestWatchSummary() async throws -> ReadwiseDocument? {
        guard let token = TokenStorage.getToken() else {
            throw APIError.noToken
        }

        // Don't filter by location — Readwise may move docs from "new" to "later"
        // Request html_content so we get the full article body
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "withHtmlContent", value: "true"),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")

        // Retry with backoff on 429
        for attempt in 0..<maxRetries {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            if httpResponse.statusCode == 429 {
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    .flatMap { Double($0) } ?? Double(10 * (attempt + 1))
                try await Task.sleep(for: .seconds(retryAfter))
                continue
            }

            guard httpResponse.statusCode == 200 else {
                throw APIError.httpError(httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            let listResponse = try decoder.decode(ReadwiseListResponse.self, from: data)

            // Filter for WatchSummary tag and return the most recent
            let watchDocs = listResponse.results.filter { $0.isWatchSummary }
            return watchDocs.first
        }

        throw APIError.rateLimited
    }

    enum APIError: LocalizedError {
        case noToken
        case invalidResponse
        case httpError(Int)
        case rateLimited

        var errorDescription: String? {
            switch self {
            case .noToken:
                return "No API token configured."
            case .invalidResponse:
                return "Invalid response from server."
            case .httpError(let code):
                return "Server error (\(code))."
            case .rateLimited:
                return "Rate limited. Try again later."
            }
        }
    }
}
