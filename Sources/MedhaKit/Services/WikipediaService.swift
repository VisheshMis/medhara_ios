import Foundation

public struct WikipediaExtract: Codable, Sendable, Equatable {
    public let title: String
    public let extract: String
    public let urlString: String?
    public let description: String?

    public init(title: String, extract: String, urlString: String? = nil, description: String? = nil) {
        self.title = title
        self.extract = extract
        self.urlString = urlString
        self.description = description
    }
}

public actor WikipediaService {
    public static let shared = WikipediaService()

    private var cache: [String: WikipediaExtract] = [:]

    private init() {}

    /// Fetches a concise, encyclopedic factual summary from Wikipedia without requiring any API keys.
    public func fetchSummary(for query: String) async -> WikipediaExtract? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let cacheKey = trimmed.lowercased()
        if let cached = cache[cacheKey] {
            return cached
        }

        // Clean query: remove markdown heading syntax, quotes, and punctuation
        let sanitized = trimmed
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. First attempt: Direct REST summary API
        if let extract = await queryDirectSummary(title: sanitized) {
            cache[cacheKey] = extract
            return extract
        }

        // 2. Second attempt: OpenSearch API to find the most relevant canonical Wikipedia article title
        if let canonicalTitle = await searchCanonicalTitle(term: sanitized) {
            if let extract = await queryDirectSummary(title: canonicalTitle) {
                cache[cacheKey] = extract
                return extract
            }
        }

        return nil
    }

    private func queryDirectSummary(title: String) async -> WikipediaExtract? {
        guard let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(encoded)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 6.0
        request.setValue("Medha-PKM/1.0 (knowledge-assistant)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let extract = json["extract"] as? String,
                  !extract.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }

            let displayTitle = (json["title"] as? String) ?? title
            let description = json["description"] as? String
            var articleUrl: String? = nil
            if let contentUrls = json["content_urls"] as? [String: Any],
               let desktop = contentUrls["desktop"] as? [String: Any],
               let page = desktop["page"] as? String {
                articleUrl = page
            }

            return WikipediaExtract(
                title: displayTitle,
                extract: extract,
                urlString: articleUrl,
                description: description
            )
        } catch {
            return nil
        }
    }

    private func searchCanonicalTitle(term: String) async -> String? {
        guard let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://en.wikipedia.org/w/api.php?action=opensearch&search=\(encoded)&limit=1&namespace=0&format=json") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        request.setValue("Medha-PKM/1.0 (knowledge-assistant)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            // OpenSearch format is: [ searchTerm, [ title1, ... ], [ snippet1, ... ], [ url1, ... ] ]
            guard let array = try JSONSerialization.jsonObject(with: data) as? [Any],
                  array.count >= 2,
                  let titles = array[1] as? [String],
                  let firstTitle = titles.first,
                  !firstTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }

            return firstTitle
        } catch {
            return nil
        }
    }
}
