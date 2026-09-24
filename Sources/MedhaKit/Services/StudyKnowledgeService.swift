import Foundation

// MARK: - Study Grounding Source
public enum StudyGroundingSource: String, CaseIterable, Identifiable, Codable, Sendable {
    case wikipedia = "wikipedia"
    case openAlex = "openalex"
    case europePMC = "europepmc"
    case wiktionary = "wiktionary"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .wikipedia: return "Wikipedia"
        case .openAlex: return "OpenAlex Academic"
        case .europePMC: return "Europe PMC"
        case .wiktionary: return "Wiktionary"
        }
    }

    public var shortName: String {
        switch self {
        case .wikipedia: return "Wiki"
        case .openAlex: return "Papers"
        case .europePMC: return "BioMed"
        case .wiktionary: return "Definitions"
        }
    }

    public var subtitle: String {
        switch self {
        case .wikipedia: return "General encyclopedic overview & concepts"
        case .openAlex: return "250M+ scholarly research papers (STEM, CS, Math)"
        case .europePMC: return "Biomedical, clinical, and life sciences research"
        case .wiktionary: return "Precise academic terminology & etymology"
        }
    }

    public var systemIcon: String {
        switch self {
        case .wikipedia: return "globe"
        case .openAlex: return "graduationcap.fill"
        case .europePMC: return "cross.case.fill"
        case .wiktionary: return "character.book.closed.fill"
        }
    }
}

// MARK: - Study Snippet
public struct StudySnippet: Codable, Sendable, Equatable {
    public let source: StudyGroundingSource
    public let title: String
    public let summary: String
    public let urlString: String?
    public let citation: String?

    public init(
        source: StudyGroundingSource,
        title: String,
        summary: String,
        urlString: String? = nil,
        citation: String? = nil
    ) {
        self.source = source
        self.title = title
        self.summary = summary
        self.urlString = urlString
        self.citation = citation
    }
}

// MARK: - Study Knowledge Service Actor
public actor StudyKnowledgeService {
    public static let shared = StudyKnowledgeService()

    private var snippetCache: [String: StudySnippet] = [:]

    private init() {}

    // MARK: - Multi-source Aggregator
    /// Concurrently queries all requested study sources and returns verified knowledge snippets.
    public func fetchGroundedKnowledge(
        for query: String,
        sources: [StudyGroundingSource],
        isCompactBudget: Bool = false
    ) async -> [StudySnippet] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !sources.isEmpty else { return [] }

        return await withTaskGroup(of: StudySnippet?.self) { group in
            for source in sources {
                group.addTask {
                    await self.fetchSnippet(for: trimmed, source: source, isCompactBudget: isCompactBudget)
                }
            }

            var results: [StudySnippet] = []
            for await snippet in group {
                if let s = snippet {
                    results.append(s)
                }
            }

            // Maintain stable order matching the input sources
            return sources.compactMap { source in
                results.first { $0.source == source }
            }
        }
    }

    // MARK: - Single Source Router
    public func fetchSnippet(
        for query: String,
        source: StudyGroundingSource,
        isCompactBudget: Bool = false
    ) async -> StudySnippet? {
        let cacheKey = "\(source.rawValue):\(query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))"
        if let cached = snippetCache[cacheKey] {
            return cached
        }

        let snippet: StudySnippet?
        switch source {
        case .wikipedia:
            snippet = await fetchWikipediaSnippet(for: query, isCompactBudget: isCompactBudget)
        case .openAlex:
            snippet = await fetchOpenAlexSnippet(for: query, isCompactBudget: isCompactBudget)
        case .europePMC:
            snippet = await fetchEuropePMCSnippet(for: query, isCompactBudget: isCompactBudget)
        case .wiktionary:
            snippet = await fetchWiktionarySnippet(for: query, isCompactBudget: isCompactBudget)
        }

        if let s = snippet {
            snippetCache[cacheKey] = s
        }
        return snippet
    }

    // MARK: - 1. Wikipedia Fetcher
    private func fetchWikipediaSnippet(for query: String, isCompactBudget: Bool) async -> StudySnippet? {
        guard let extract = await WikipediaService.shared.fetchSummary(for: query) else {
            return nil
        }

        let budget = isCompactBudget ? 500 : 1200
        let cleanText = String(extract.extract.prefix(budget))

        return StudySnippet(
            source: .wikipedia,
            title: extract.title,
            summary: cleanText,
            urlString: extract.urlString,
            citation: "Wikipedia (The Free Encyclopedia)"
        )
    }

    // MARK: - 2. OpenAlex Academic Papers Fetcher (with CrossRef Fallback)
    private func fetchOpenAlexSnippet(for query: String, isCompactBudget: Bool) async -> StudySnippet? {
        if let direct = await queryOpenAlexDirect(for: query, isCompactBudget: isCompactBudget) {
            return direct
        }
        return await queryCrossRefDirect(for: query, isCompactBudget: isCompactBudget)
    }

    private func queryOpenAlexDirect(for query: String, isCompactBudget: Bool) async -> StudySnippet? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.openalex.org/works?search=\(encoded)&per_page=1") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 6.0
        request.setValue("Medha-PKM/1.0 (academic-assistant; mailto:support@medha.app)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let firstWork = results.first else {
                return nil
            }

            let title = (firstWork["title"] as? String) ?? query
            let doi = firstWork["doi"] as? String
            let pubYear = firstWork["publication_year"] as? Int
            var authorsStr: String? = nil

            if let authorships = firstWork["authorships"] as? [[String: Any]], !authorships.isEmpty {
                let names = authorships.prefix(2).compactMap { item -> String? in
                    if let author = item["author"] as? [String: Any] {
                        return author["display_name"] as? String
                    }
                    return nil
                }
                if !names.isEmpty {
                    authorsStr = names.joined(separator: ", ") + (authorships.count > 2 ? " et al." : "")
                }
            }

            var textContent: String = ""
            if let invertedIndex = firstWork["abstract_inverted_index"] as? [String: [Int]],
               let reconstructed = Self.reconstructInvertedIndex(invertedIndex) {
                textContent = reconstructed
            } else if let concepts = firstWork["concepts"] as? [[String: Any]], !concepts.isEmpty {
                let conceptNames = concepts.prefix(4).compactMap { $0["display_name"] as? String }
                textContent = "Core Research Concepts: " + conceptNames.joined(separator: ", ")
            }

            guard !textContent.isEmpty else { return nil }

            let budget = isCompactBudget ? 500 : 1200
            let trimmedContent = String(textContent.prefix(budget))

            var citationParts: [String] = []
            if let a = authorsStr { citationParts.append(a) }
            if let y = pubYear { citationParts.append("(\(y))") }
            if let d = doi { citationParts.append(d) }

            return StudySnippet(
                source: .openAlex,
                title: title,
                summary: trimmedContent,
                urlString: doi,
                citation: citationParts.isEmpty ? "OpenAlex Academic Literature" : citationParts.joined(separator: " ")
            )
        } catch {
            return nil
        }
    }

    private func queryCrossRefDirect(for query: String, isCompactBudget: Bool) async -> StudySnippet? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.crossref.org/works?query=\(encoded)&rows=1") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        request.setValue("Medha-PKM/1.0 (academic-assistant; mailto:support@medha.app)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let message = json["message"] as? [String: Any],
                  let items = message["items"] as? [[String: Any]],
                  let first = items.first else {
                return nil
            }

            let titleArray = first["title"] as? [String]
            let title = titleArray?.first ?? query
            let doi = first["DOI"] as? String
            let container = (first["container-title"] as? [String])?.first

            var summaryText = ""
            if let rawAbstract = first["abstract"] as? String, !rawAbstract.isEmpty {
                summaryText = Self.stripHTML(rawAbstract)
            } else {
                summaryText = "Scholarly Publication: \(title)" + (container != nil ? " published in \(container!)." : ".")
            }

            let budget = isCompactBudget ? 500 : 1200
            let trimmed = String(summaryText.prefix(budget))

            return StudySnippet(
                source: .openAlex,
                title: title,
                summary: trimmed,
                urlString: doi != nil ? "https://doi.org/\(doi!)" : nil,
                citation: container != nil ? "CrossRef Academic (\(container!))" : "CrossRef Academic Literature"
            )
        } catch {
            return nil
        }
    }

    // MARK: - 3. Europe PMC Biomedical Literature Fetcher
    private func fetchEuropePMCSnippet(for query: String, isCompactBudget: Bool) async -> StudySnippet? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=\(encoded)&resultType=core&format=json&pageSize=1") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 6.0
        request.setValue("Medha-PKM/1.0 (biomedical-assistant)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let resultList = json["resultList"] as? [String: Any],
                  let results = resultList["result"] as? [[String: Any]],
                  let firstArticle = results.first else {
                return nil
            }

            let title = (firstArticle["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? query
            guard let rawAbstract = firstArticle["abstractText"] as? String,
                  !rawAbstract.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }

            let cleanAbstract = Self.stripHTML(rawAbstract)
            let budget = isCompactBudget ? 500 : 1200
            let trimmedAbstract = String(cleanAbstract.prefix(budget))

            let authors = firstArticle["authorString"] as? String
            let journal = firstArticle["journalTitle"] as? String
            let year = firstArticle["pubYear"] as? String
            let doi = firstArticle["doi"] as? String

            var articleUrl: String? = nil
            if let d = doi {
                articleUrl = "https://doi.org/\(d)"
            }

            var citeParts: [String] = []
            if let a = authors { citeParts.append(a) }
            if let j = journal { citeParts.append(j) }
            if let y = year { citeParts.append("(\(y))") }

            return StudySnippet(
                source: .europePMC,
                title: title,
                summary: trimmedAbstract,
                urlString: articleUrl,
                citation: citeParts.isEmpty ? "Europe PMC Life Sciences" : citeParts.joined(separator: " • ")
            )
        } catch {
            return nil
        }
    }

    // MARK: - 4. Wiktionary Definitions Fetcher
    private func fetchWiktionarySnippet(for query: String, isCompactBudget: Bool) async -> StudySnippet? {
        // Wiktionary lookup is best for single terms or short phrases
        let sanitized = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: .whitespaces)
            .first ?? query

        guard let encoded = sanitized.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://en.wiktionary.org/api/rest_v1/page/definition/\(encoded)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        request.setValue("Medha-PKM/1.0 (dictionary-assistant)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let enEntries = json["en"] as? [[String: Any]],
                  let firstEntry = enEntries.first,
                  let definitions = firstEntry["definitions"] as? [[String: Any]] else {
                return nil
            }

            let pos = (firstEntry["partOfSpeech"] as? String) ?? "Definition"

            // Gather up to 3 clean definitions
            let defTexts = definitions.prefix(3).compactMap { dict -> String? in
                if let def = dict["definition"] as? String {
                    let clean = Self.stripHTML(def)
                    return clean.isEmpty ? nil : "• " + clean
                }
                return nil
            }

            guard !defTexts.isEmpty else { return nil }

            let combined = defTexts.joined(separator: "\n")
            let budget = isCompactBudget ? 400 : 800
            let trimmed = String(combined.prefix(budget))

            return StudySnippet(
                source: .wiktionary,
                title: "\(sanitized.capitalized) (\(pos))",
                summary: trimmed,
                urlString: "https://en.wiktionary.org/wiki/\(encoded)",
                citation: "Wiktionary (Free Academic Lexicon)"
            )
        } catch {
            return nil
        }
    }

    // MARK: - Utility Helpers
    public static func reconstructInvertedIndex(_ index: [String: [Int]]) -> String? {
        var positionMap: [Int: String] = [:]
        for (word, positions) in index {
            for pos in positions {
                positionMap[pos] = word
            }
        }
        guard !positionMap.isEmpty else { return nil }
        let sortedKeys = positionMap.keys.sorted()
        let words = sortedKeys.compactMap { positionMap[$0] }
        return words.joined(separator: " ")
    }

    public static func stripHTML(_ input: String) -> String {
        input
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
