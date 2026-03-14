import Foundation

struct ReadwiseListResponse: Codable {
    let results: [ReadwiseDocument]
    let nextPageCursor: String?
}

struct ReadwiseDocument: Codable, Identifiable {
    let id: String
    let title: String?
    let summary: String?
    let htmlContent: String?
    let tags: [String: TagInfo]
    let publishedDate: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case summary
        case htmlContent = "html_content"
        case tags
        case publishedDate = "published_date"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        htmlContent = try container.decodeIfPresent(String.self, forKey: .htmlContent)
        tags = try container.decodeIfPresent([String: TagInfo].self, forKey: .tags) ?? [:]
        publishedDate = try container.decodeIfPresent(String.self, forKey: .publishedDate)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }

    /// Extract readable text: prefer html_content (full body), fall back to summary.
    var plainTextContent: String {
        if let html = htmlContent, !html.isEmpty {
            return Self.stripHTML(html)
        }
        return (summary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parse the creation/published date for display.
    /// Prefer created_at (has full timestamp) over published_date (date-only from Readwise).
    var publishedAt: Date? {
        guard let dateStr = createdAt ?? publishedDate else { return nil }
        // Try ISO 8601 with timezone + fractional seconds
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFormatter.date(from: dateStr) { return d }
        // ISO 8601 with timezone, no fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let d = isoFormatter.date(from: dateStr) { return d }
        // Local datetime without timezone (Python's datetime.now().isoformat())
        // e.g. "2026-03-14T01:23:45.123456" or "2026-03-14T01:23:45"
        // Truncate microseconds — DateFormatter only handles up to 3 fractional digits
        let normalized: String
        if let dotRange = dateStr.range(of: ".", range: dateStr.index(dateStr.startIndex, offsetBy: 10)..<dateStr.endIndex) {
            // Has fractional seconds — keep only 3 digits
            let afterDot = dateStr[dotRange.upperBound...]
            let digits = afterDot.prefix(3)
            normalized = String(dateStr[..<dotRange.upperBound]) + digits
        } else {
            normalized = dateStr
        }
        let localFormatter = DateFormatter()
        localFormatter.locale = Locale(identifier: "en_US_POSIX")
        localFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        if let d = localFormatter.date(from: normalized) { return d }
        localFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let d = localFormatter.date(from: normalized) { return d }
        // Date-only fallback (e.g. "2026-03-13")
        localFormatter.dateFormat = "yyyy-MM-dd"
        return localFormatter.date(from: normalized)
    }

    /// Check if this document has the WatchSummary tag.
    /// Readwise lowercases dictionary keys, so we check case-insensitively.
    var isWatchSummary: Bool {
        tags.keys.contains { $0.lowercased() == "watchsummary" }
    }

    /// Strip HTML tags and decode entities to plain text.
    private static func stripHTML(_ html: String) -> String {
        // Use NSAttributedString for robust HTML → plain text conversion
        if let data = html.data(using: .utf8),
           let attributed = try? NSAttributedString(
               data: data,
               options: [
                   .documentType: NSAttributedString.DocumentType.html,
                   .characterEncoding: String.Encoding.utf8.rawValue,
               ],
               documentAttributes: nil
           ) {
            return attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Fallback: simple regex strip
        var text = html
        // Convert <br> and <p> to newlines
        text = text.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</p>", with: "\n", options: .caseInsensitive)
        // Strip remaining tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // Decode common entities
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        // Collapse multiple newlines
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct TagInfo: Codable {
    let name: String
}
