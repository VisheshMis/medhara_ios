import Foundation

// MARK: - Study Subject Domain
public enum StudySubjectDomain: String, CaseIterable, Identifiable, Codable, Sendable {
    case all = "all"
    case biology = "biology"
    case history = "history"
    case language = "language"
    case stem = "stem"
    case philosophy = "philosophy"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .all: return "All Fields"
        case .biology: return "Biology & Medicine"
        case .history: return "History & Humanities"
        case .language: return "Language & Linguistics"
        case .stem: return "STEM & Physics"
        case .philosophy: return "Philosophy & Ideas"
        }
    }

    public var shortName: String {
        switch self {
        case .all: return "All"
        case .biology: return "Biology"
        case .history: return "History"
        case .language: return "Language"
        case .stem: return "STEM"
        case .philosophy: return "Philosophy"
        }
    }

    public var systemIcon: String {
        switch self {
        case .all: return "sparkles"
        case .biology: return "cross.case.fill"
        case .history: return "building.columns.fill"
        case .language: return "character.book.closed.fill"
        case .stem: return "atom"
        case .philosophy: return "brain.head.profile"
        }
    }

    public var defaultSources: [StudyGroundingSource] {
        switch self {
        case .all:
            return [.wikipedia, .openAlex, .pubMed, .arxiv, .openLibrary, .wiktionary]
        case .biology:
            return [.pubMed, .europePMC, .wikipedia]
        case .history:
            return [.openLibrary, .wikipedia]
        case .language:
            return [.wiktionary, .freeDictionary, .wikipedia]
        case .stem:
            return [.arxiv, .openAlex, .wikipedia]
        case .philosophy:
            return [.openAlex, .wikipedia]
        }
    }

    /// Smart heuristic to classify a note or query into a subject domain
    public static func detectDomain(title: String, content: String = "", folderPath: String = "") -> StudySubjectDomain {
        let combined = "\(title) \(content.prefix(350)) \(folderPath)".lowercased()
        let tokens = Set(combined.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty })

        func hasMatch(_ keywords: [String]) -> Bool {
            for kw in keywords {
                if kw.contains(" ") {
                    if combined.contains(kw) { return true }
                } else if kw.count <= 4 {
                    if tokens.contains(kw) { return true }
                } else {
                    if combined.contains(kw) { return true }
                }
            }
            return false
        }

        // Biology keywords
        let bioKeywords = [
            "biology", "medicine", "cell", "protein", "gene", "neuron", "anatomy", "dna", "rna",
            "enzyme", "receptor", "disease", "pathway", "cardio", "neuro", "immune", "antibody",
            "clinical", "organism", "pharmacology", "synapse", "cortex", "cancer", "metabolism",
            "crispr", "axon", "dendrite", "cardiovascular", "pathology", "physiology"
        ]
        if hasMatch(bioKeywords) {
            return .biology
        }

        // Language keywords
        let langKeywords = [
            "grammar", "vocabulary", "verb", "tense", "etymology", "linguistics", "french",
            "spanish", "german", "latin", "japanese", "chinese", "translation", "pronunciation",
            "phonetic", "conjugation", "idiom", "adjective", "noun", "syntax", "lexicon",
            "declension", "inflection", "semantics", "morpheme", "phoneme"
        ]
        if hasMatch(langKeywords) {
            return .language
        }

        // History keywords
        let histKeywords = [
            "history", "war", "battle", "century", "empire", "treaty", "dynasty", "revolution",
            "ancient", "medieval", "archaeology", "monarchy", "president", "civilization",
            "renaissance", "reign", "republic", "colony", "era", "treaty of", "napoleon",
            "roman empire", "byzantine", "crusade", "ottoman", "florence", "archaeological"
        ]
        if hasMatch(histKeywords) {
            return .history
        }

        // STEM keywords
        let stemKeywords = [
            "physics", "math", "calculus", "algebra", "algorithm", "quantum", "tensor", "matrix",
            "gravity", "thermodynamics", "differential", "computer science", "neural network",
            "machine learning", "astronomy", "relativity", "particle", "theorem", "geometry",
            "electromagnetism", "eigenvalue", "complexity", "cryptography", "transformer"
        ]
        if hasMatch(stemKeywords) {
            return .stem
        }

        // Philosophy keywords
        let philKeywords = [
            "philosophy", "ethics", "epistemology", "metaphysics", "logic", "morality",
            "existentialism", "ontology", "stoicism", "kant", "nietzsche", "utilitarianism",
            "dialectic", "dualism", "aristotle", "plato", "epistemic", "deontology", "phenomenology"
        ]
        if hasMatch(philKeywords) {
            return .philosophy
        }

        return .all
    }
}

// MARK: - Study Grounding Source
public enum StudyGroundingSource: String, CaseIterable, Identifiable, Codable, Sendable {
    case wikipedia = "wikipedia"
    case openAlex = "openalex"
    case europePMC = "europepmc"
    case pubMed = "pubmed"
    case arxiv = "arxiv"
    case openLibrary = "openlibrary"
    case wiktionary = "wiktionary"
    case freeDictionary = "freedictionary"

    public var id: String { rawValue }

    public var domain: StudySubjectDomain {
        switch self {
        case .wikipedia: return .all
        case .openAlex: return .stem
        case .europePMC: return .biology
        case .pubMed: return .biology
        case .arxiv: return .stem
        case .openLibrary: return .history
        case .wiktionary: return .language
        case .freeDictionary: return .language
        }
    }

    public var displayName: String {
        switch self {
        case .wikipedia: return "Wikipedia"
        case .openAlex: return "OpenAlex Academic"
        case .europePMC: return "Europe PMC"
        case .pubMed: return "PubMed (NCBI)"
        case .arxiv: return "arXiv Preprints"
        case .openLibrary: return "Open Library / Archive"
        case .wiktionary: return "Wiktionary"
        case .freeDictionary: return "Dictionary & Phonetics"
        }
    }

    public var shortName: String {
        switch self {
        case .wikipedia: return "Wiki"
        case .openAlex: return "OpenAlex"
        case .europePMC: return "BioMed"
        case .pubMed: return "PubMed"
        case .arxiv: return "arXiv"
        case .openLibrary: return "Archives"
        case .wiktionary: return "Etymology"
        case .freeDictionary: return "Lexicon"
        }
    }

    public var subtitle: String {
        switch self {
        case .wikipedia: return "General encyclopedic overview & concepts"
        case .openAlex: return "250M+ scholarly research papers across all disciplines"
        case .europePMC: return "Biomedical & clinical open-access research"
        case .pubMed: return "Official NIH peer-reviewed biomedical literature & trials"
        case .arxiv: return "Physics, Math, Computer Science & Quantitative STEM papers"
        case .openLibrary: return "Historical books, primary sources & academic catalog"
        case .wiktionary: return "Precise academic terminology, roots & etymology"
        case .freeDictionary: return "Phonetic pronunciations, parts of speech & definitions"
        }
    }

    public var systemIcon: String {
        switch self {
        case .wikipedia: return "globe"
        case .openAlex: return "graduationcap.fill"
        case .europePMC: return "cross.case.fill"
        case .pubMed: return "stethoscope"
        case .arxiv: return "atom"
        case .openLibrary: return "building.columns.fill"
        case .wiktionary: return "character.book.closed.fill"
        case .freeDictionary: return "text.book.closed.fill"
        }
    }
}

// MARK: - Study Snippet
public struct StudySnippet: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(source.rawValue):\(title)" }
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
        case .pubMed:
            snippet = await fetchPubMedSnippet(for: query, isCompactBudget: isCompactBudget)
        case .arxiv:
            snippet = await fetchArXivSnippet(for: query, isCompactBudget: isCompactBudget)
        case .openLibrary:
            snippet = await fetchOpenLibrarySnippet(for: query, isCompactBudget: isCompactBudget)
        case .wiktionary:
            snippet = await fetchWiktionarySnippet(for: query, isCompactBudget: isCompactBudget)
        case .freeDictionary:
            snippet = await fetchFreeDictionarySnippet(for: query, isCompactBudget: isCompactBudget)
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

    // MARK: - 2. OpenAlex Academic Papers Fetcher
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

    // MARK: - 4. PubMed / NCBI Fetcher
    private func fetchPubMedSnippet(for query: String, isCompactBudget: Bool) async -> StudySnippet? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let searchUrl = URL(string: "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term=\(encoded)&retmode=json&retmax=1") else {
            return nil
        }

        var searchReq = URLRequest(url: searchUrl)
        searchReq.timeoutInterval = 6.0
        searchReq.setValue("Medha-PKM/1.0 (pubmed-assistant)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: searchReq)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let searchResult = json["esearchresult"] as? [String: Any],
                  let idList = searchResult["idlist"] as? [String],
                  let pmid = idList.first else {
                return nil
            }

            // Step 2: Fetch summary metadata for this PMID
            guard let summaryUrl = URL(string: "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=pubmed&id=\(pmid)&retmode=json") else {
                return nil
            }

            var sumReq = URLRequest(url: summaryUrl)
            sumReq.timeoutInterval = 6.0
            sumReq.setValue("Medha-PKM/1.0 (pubmed-assistant)", forHTTPHeaderField: "User-Agent")

            let (sumData, sumResp) = try await URLSession.shared.data(for: sumReq)
            guard let sumHttp = sumResp as? HTTPURLResponse, sumHttp.statusCode == 200 else {
                return nil
            }

            guard let sumJson = try JSONSerialization.jsonObject(with: sumData) as? [String: Any],
                  let resDict = sumJson["result"] as? [String: Any],
                  let doc = resDict[pmid] as? [String: Any] else {
                return nil
            }

            let title = Self.stripHTML(doc["title"] as? String ?? query)
            let source = doc["source"] as? String ?? "PubMed"
            let pubdate = doc["pubdate"] as? String ?? ""

            var authorStr: String? = nil
            if let authors = doc["authors"] as? [[String: Any]], !authors.isEmpty {
                let names = authors.prefix(2).compactMap { $0["name"] as? String }
                if !names.isEmpty {
                    authorStr = names.joined(separator: ", ") + (authors.count > 2 ? " et al." : "")
                }
            }

            var summaryText = "Peer-Reviewed Medical Literature: \(title)"
            if let a = authorStr { summaryText += " by \(a)" }
            if !pubdate.isEmpty { summaryText += " (\(pubdate))" }
            summaryText += " published in \(source)."

            let budget = isCompactBudget ? 500 : 1200
            let trimmed = String(summaryText.prefix(budget))

            return StudySnippet(
                source: .pubMed,
                title: title,
                summary: trimmed,
                urlString: "https://pubmed.ncbi.nlm.nih.gov/\(pmid)/",
                citation: "PubMed (NIH National Library of Medicine) PMID: \(pmid)"
            )
        } catch {
            return nil
        }
    }

    // MARK: - 5. arXiv Preprints Fetcher
    private func fetchArXivSnippet(for query: String, isCompactBudget: Bool) async -> StudySnippet? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://export.arxiv.org/api/query?search_query=all:\(encoded)&start=0&max_results=1") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 6.0
        request.setValue("Medha-PKM/1.0 (arxiv-assistant)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            guard let xmlString = String(data: data, encoding: .utf8),
                  let entryRange = xmlString.range(of: "<entry>") else {
                return nil
            }

            let entryXml = String(xmlString[entryRange.lowerBound...])

            let title = Self.extractXMLTag(from: entryXml, tag: "title") ?? query
            let summary = Self.extractXMLTag(from: entryXml, tag: "summary") ?? ""
            let idUrl = Self.extractXMLTag(from: entryXml, tag: "id")
            let published = Self.extractXMLTag(from: entryXml, tag: "published")

            guard !summary.isEmpty else { return nil }

            let cleanSummary = summary.replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let budget = isCompactBudget ? 500 : 1200
            let trimmed = String(cleanSummary.prefix(budget))

            let yearStr = published != nil ? String(published!.prefix(4)) : nil
            let citeStr = yearStr != nil ? "arXiv e-Print Archive (\(yearStr!))" : "arXiv e-Print Archive"

            return StudySnippet(
                source: .arxiv,
                title: title.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines),
                summary: trimmed,
                urlString: idUrl,
                citation: citeStr
            )
        } catch {
            return nil
        }
    }

    // MARK: - 6. Open Library / Archive Fetcher
    private func fetchOpenLibrarySnippet(for query: String, isCompactBudget: Bool) async -> StudySnippet? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://openlibrary.org/search.json?q=\(encoded)&limit=1") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 6.0
        request.setValue("Medha-PKM/1.0 (openlibrary-assistant)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let docs = json["docs"] as? [[String: Any]],
                  let firstDoc = docs.first else {
                return nil
            }

            let title = firstDoc["title"] as? String ?? query
            let authors = (firstDoc["author_name"] as? [String])?.prefix(2).joined(separator: ", ")
            let year = firstDoc["first_publish_year"] as? Int
            let subjects = (firstDoc["subject"] as? [String])?.prefix(4).joined(separator: ", ")
            let key = firstDoc["key"] as? String

            var summaryText = "Historical & Literary Record: \(title)"
            if let a = authors { summaryText += " by \(a)" }
            if let y = year { summaryText += " (first published \(y))" }
            if let s = subjects { summaryText += ". Key Subjects: \(s)." }

            let budget = isCompactBudget ? 500 : 1200
            let trimmed = String(summaryText.prefix(budget))

            let bookUrl = key != nil ? "https://openlibrary.org\(key!)" : nil

            return StudySnippet(
                source: .openLibrary,
                title: title,
                summary: trimmed,
                urlString: bookUrl,
                citation: "Open Library & Internet Archive"
            )
        } catch {
            return nil
        }
    }

    // MARK: - 7. Wiktionary Definitions Fetcher
    private func fetchWiktionarySnippet(for query: String, isCompactBudget: Bool) async -> StudySnippet? {
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

    // MARK: - 8. Free Dictionary & Phonetics Fetcher
    private func fetchFreeDictionarySnippet(for query: String, isCompactBudget: Bool) async -> StudySnippet? {
        let sanitized = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: .whitespaces)
            .first ?? query

        guard let encoded = sanitized.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(encoded)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        request.setValue("Medha-PKM/1.0 (lexicon-assistant)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let firstEntry = json.first else {
                return nil
            }

            let word = firstEntry["word"] as? String ?? sanitized
            let phonetic = firstEntry["phonetic"] as? String ?? ""

            var defLines: [String] = []
            if let meanings = firstEntry["meanings"] as? [[String: Any]] {
                for m in meanings.prefix(2) {
                    let pos = m["partOfSpeech"] as? String ?? ""
                    if let defs = m["definitions"] as? [[String: Any]], let firstDef = defs.first {
                        let defText = firstDef["definition"] as? String ?? ""
                        if !defText.isEmpty {
                            defLines.append("• [\(pos)] \(defText)")
                        }
                    }
                }
            }

            guard !defLines.isEmpty else { return nil }

            let header = phonetic.isEmpty ? word.capitalized : "\(word.capitalized) \(phonetic)"
            let combined = defLines.joined(separator: "\n")
            let budget = isCompactBudget ? 400 : 800
            let trimmed = String(combined.prefix(budget))

            return StudySnippet(
                source: .freeDictionary,
                title: header,
                summary: trimmed,
                urlString: "https://en.wiktionary.org/wiki/\(encoded)",
                citation: "Dictionary & Phonetic Lexicon"
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

    public static func extractXMLTag(from xml: String, tag: String) -> String? {
        guard let start = xml.range(of: "<\(tag)>"),
              let end = xml.range(of: "</\(tag)>", range: start.upperBound..<xml.endIndex) else {
            return nil
        }
        return String(xml[start.upperBound..<end.lowerBound])
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
