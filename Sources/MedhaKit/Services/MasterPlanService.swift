import Foundation
import Combine

// MARK: - Depth & Rigor Archetypes
public enum MasterPlanDepthArchetype: String, CaseIterable, Identifiable, Codable, Sendable {
    case academicMonograph = "Academic Master Monograph"
    case pragmaticExamples = "Pragmatic Worked Examples & Tables"
    case technicalReference = "Comprehensive Technical Reference"

    public var id: String { rawValue }

    public var shortTitle: String {
        switch self {
        case .academicMonograph: return "Academic Monograph"
        case .pragmaticExamples: return "Examples & Tables"
        case .technicalReference: return "Technical Reference"
        }
    }

    public var systemIcon: String {
        switch self {
        case .academicMonograph: return "graduationcap.fill"
        case .pragmaticExamples: return "tablecells.badge.ellipsis"
        case .technicalReference: return "gearshape.2.fill"
        }
    }

    public var subtitle: String {
        switch self {
        case .academicMonograph:
            return "Axiomatic theoretical core, deep structural mechanics, comparative analysis & historical/etymological context."
        case .pragmaticExamples:
            return "Syntax & conjugation tables, real contextual sentences with gloss/translation, step-by-step problem walkthroughs."
        case .technicalReference:
            return "Formal system specifications, algorithmic models, concrete parameters, architecture breakdowns & pitfall matrices."
        }
    }

    public var promptDirective: String {
        switch self {
        case .academicMonograph:
            return "Adopt the depth of an exhaustive university monograph. Formulate precise theoretical definitions, etymological roots, comparative linguistic/system mechanisms, and rigorous edge cases."
        case .pragmaticExamples:
            return "Focus heavily on actionable, concrete examples with interlinear glosses, step-by-step walkthroughs, formatted tables, and side-by-side contrastive scenarios."
        case .technicalReference:
            return "Formulate formal technical specifications, architectural diagrams, memory/algorithmic layouts, exact syntax grammar rules, and critical failure modes."
        }
    }
}

// MARK: - Syllabus & Chapter Data Models
public struct MasterPlanChapter: Codable, Sendable, Identifiable, Equatable {
    public var id: UUID
    public var title: String
    public var subtitle: String
    public var focusQuestion: String
    public var searchTerms: [String]
    public var requiredArchetypes: [String]

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String = "",
        focusQuestion: String = "",
        searchTerms: [String] = [],
        requiredArchetypes: [String] = []
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.focusQuestion = focusQuestion
        self.searchTerms = searchTerms
        self.requiredArchetypes = requiredArchetypes
    }
}

public struct MasterPlanSyllabus: Codable, Sendable, Equatable {
    public var curriculumTitle: String
    public var overview: String
    public var archetype: MasterPlanDepthArchetype
    public var chapters: [MasterPlanChapter]
    public var authenticSources: [String]

    public init(
        curriculumTitle: String,
        overview: String,
        archetype: MasterPlanDepthArchetype = .academicMonograph,
        chapters: [MasterPlanChapter],
        authenticSources: [String] = []
    ) {
        self.curriculumTitle = curriculumTitle
        self.overview = overview
        self.archetype = archetype
        self.chapters = chapters
        self.authenticSources = authenticSources
    }
}

public struct MasterPlanChapterContent: Codable, Sendable {
    public var chapterTitle: String
    public var summary: String
    public var blocks: [HierarchicalBlockItem]

    public init(chapterTitle: String, summary: String, blocks: [HierarchicalBlockItem]) {
        self.chapterTitle = chapterTitle
        self.summary = summary
        self.blocks = blocks
    }
}

// MARK: - Live Progress States
public enum MasterPlanProgressState: Equatable, Sendable {
    case idle
    case formulatingSyllabus
    case previewSyllabus(MasterPlanSyllabus)
    case synthesizingChapter(index: Int, total: Int, chapterTitle: String, stage: String)
    case completed(totalChapters: Int)
    case cancelled(completedChapters: Int)
    case error(String)

    public var isRunning: Bool {
        switch self {
        case .formulatingSyllabus, .synthesizingChapter:
            return true
        default:
            return false
        }
    }

    public var isPreviewing: Bool {
        if case .previewSyllabus = self { return true }
        return false
    }

    public var statusDescription: String {
        switch self {
        case .idle:
            return "Ready to formulate Master Plan"
        case .formulatingSyllabus:
            return "Architecting master curriculum syllabus from encyclopedic sources..."
        case .previewSyllabus(let syllabus):
            return "Review Master Syllabus: \(syllabus.chapters.count) chapters proposed"
        case .synthesizingChapter(let idx, let total, let title, let stage):
            return "Chapter \(idx)/\(total): \(title) (\(stage))"
        case .completed(let count):
            return "Master Plan Complete: \(count) chapters synthesized"
        case .cancelled(let count):
            return "Synthesis stopped (\(count) chapters preserved)"
        case .error(let msg):
            return "Error: \(msg)"
        }
    }
}

// MARK: - Master Plan Service
@MainActor
public final class MasterPlanService: ObservableObject {
    public static let shared = MasterPlanService()

    @Published public var activeState: MasterPlanProgressState = .idle
    @Published public var activeSyllabus: MasterPlanSyllabus? = nil
    @Published public var completedChaptersCount: Int = 0
    @Published public var totalChaptersCount: Int = 0
    @Published public var currentChapterTitle: String = ""
    @Published public var currentStageMessage: String = ""
    @Published public var isRunning: Bool = false

    private var activeTask: Task<Void, Never>? = nil

    private init() {}

    // MARK: - Cancellation & Reset
    public func cancel() {
        activeTask?.cancel()
        activeTask = nil
        let completed = completedChaptersCount
        activeState = .cancelled(completedChapters: completed)
        isRunning = false
    }

    public func resetToIdle() {
        activeTask?.cancel()
        activeTask = nil
        activeState = .idle
        activeSyllabus = nil
        completedChaptersCount = 0
        totalChaptersCount = 0
        isRunning = false
    }

    // MARK: - Step 1: Formulate & Preview Syllabus
    public func formulateAndPreviewSyllabus(
        topic: String,
        archetype: MasterPlanDepthArchetype,
        directionPrompt: String?,
        domain: StudySubjectDomain
    ) {
        guard !isRunning else { return }
        isRunning = true
        activeState = .formulatingSyllabus
        currentStageMessage = "Fetching real-world curriculum taxonomy from Wikipedia..."

        activeTask = Task {
            do {
                let syllabus = try await self.formulateSyllabus(
                    topic: topic,
                    archetype: archetype,
                    directionPrompt: directionPrompt,
                    domain: domain
                )

                if Task.isCancelled {
                    self.activeState = .idle
                    self.isRunning = false
                    return
                }

                self.activeSyllabus = syllabus
                self.totalChaptersCount = syllabus.chapters.count
                self.activeState = .previewSyllabus(syllabus)
                self.isRunning = false
            } catch {
                if Task.isCancelled {
                    self.activeState = .idle
                } else {
                    self.activeState = .error(error.localizedDescription)
                }
                self.isRunning = false
            }
        }
    }

    // MARK: - Step 2: Synthesize Approved Syllabus
    public func startSynthesizingApprovedPlan(
        rootDocId: String,
        domain: StudySubjectDomain,
        activeSources: [StudyGroundingSource],
        store: BlockStore
    ) {
        guard let syllabus = activeSyllabus, !syllabus.chapters.isEmpty, !isRunning else { return }
        isRunning = true
        completedChaptersCount = 0
        totalChaptersCount = syllabus.chapters.count

        activeTask = Task {
            do {
                // 1. Commit Master Curriculum Syllabus Index into Root Note
                store.commitMasterSyllabusIndex(
                    rootDocId: rootDocId,
                    curriculumTitle: syllabus.curriculumTitle,
                    overview: syllabus.overview,
                    chapterTitles: syllabus.chapters.map { $0.title }
                )

                // 2. Sequentially Synthesize Each Chapter
                var priorSummaries: [String] = []

                for (idx, chapter) in syllabus.chapters.enumerated() {
                    if Task.isCancelled {
                        self.activeState = .cancelled(completedChapters: self.completedChaptersCount)
                        self.isRunning = false
                        return
                    }

                    let chapterNum = idx + 1
                    self.currentChapterTitle = chapter.title
                    self.activeState = .synthesizingChapter(
                        index: chapterNum,
                        total: syllabus.chapters.count,
                        chapterTitle: chapter.title,
                        stage: "Gathering academic research..."
                    )

                    // Grounding Fetch
                    let queryTerms = !chapter.searchTerms.isEmpty ? chapter.searchTerms.joined(separator: " ") : chapter.title
                    let snippets = await StudyKnowledgeService.shared.fetchGroundedKnowledge(
                        for: queryTerms,
                        sources: activeSources,
                        isCompactBudget: false
                    )

                    if Task.isCancelled {
                        self.activeState = .cancelled(completedChapters: self.completedChaptersCount)
                        self.isRunning = false
                        return
                    }

                    self.activeState = .synthesizingChapter(
                        index: chapterNum,
                        total: syllabus.chapters.count,
                        chapterTitle: chapter.title,
                        stage: "Synthesizing deep study content..."
                    )

                    let chapterContent = try await self.synthesizeChapter(
                        chapter: chapter,
                        syllabus: syllabus,
                        priorSummaries: priorSummaries,
                        snippets: snippets,
                        archetype: syllabus.archetype,
                        domain: domain
                    )

                    if Task.isCancelled {
                        self.activeState = .cancelled(completedChapters: self.completedChaptersCount)
                        self.isRunning = false
                        return
                    }

                    // Incremental Live Commit to SQLite (strictly prevents duplicate notes)
                    store.commitSingleMasterPlanChapter(
                        rootDocId: rootDocId,
                        chapterTitle: chapter.title,
                        summary: chapterContent.summary,
                        blocks: chapterContent.blocks,
                        sortOrder: idx
                    )

                    self.completedChaptersCount = chapterNum
                    priorSummaries.append("\(chapter.title): \(chapterContent.summary)")
                }

                self.activeState = .completed(totalChapters: syllabus.chapters.count)
                self.isRunning = false

            } catch {
                if Task.isCancelled {
                    self.activeState = .cancelled(completedChapters: self.completedChaptersCount)
                } else {
                    self.activeState = .error(error.localizedDescription)
                }
                self.isRunning = false
            }
        }
    }

    // MARK: - Syllabus Preview Mutation Helpers
    public func updateChapterTitle(at index: Int, newTitle: String) {
        guard var syl = activeSyllabus, index < syl.chapters.count else { return }
        syl.chapters[index].title = newTitle
        activeSyllabus = syl
        activeState = .previewSyllabus(syl)
    }

    public func removeChapter(at index: Int) {
        guard var syl = activeSyllabus, index < syl.chapters.count else { return }
        syl.chapters.remove(at: index)
        activeSyllabus = syl
        totalChaptersCount = syl.chapters.count
        activeState = .previewSyllabus(syl)
    }

    public func addChapter(title: String) {
        guard var syl = activeSyllabus else { return }
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let newCh = MasterPlanChapter(
            title: clean,
            subtitle: "User-specified study module",
            focusQuestion: "What are the core concepts and mechanics of \(clean)?",
            searchTerms: [clean],
            requiredArchetypes: ["Foundations", "Rules", "Examples", "Pitfalls"]
        )
        syl.chapters.append(newCh)
        activeSyllabus = syl
        totalChaptersCount = syl.chapters.count
        activeState = .previewSyllabus(syl)
    }

    // MARK: - Syllabus Formulation (Grounded in Wikipedia Outlines)
    public func formulateSyllabus(
        topic: String,
        archetype: MasterPlanDepthArchetype,
        directionPrompt: String?,
        domain: StudySubjectDomain
    ) async throws -> MasterPlanSyllabus {
        let settings = AISettings.shared
        guard settings.hasNotesAPIKey else {
            throw AISocraticService.ServiceError.missingAPIKey
        }

        // 1. Fetch real-world curated section outline from Wikipedia
        let realWorldSections = await WikipediaService.shared.fetchSectionOutline(for: topic)

        var taxonomyPromptContext = ""
        if !realWorldSections.isEmpty {
            taxonomyPromptContext = """
            AUTHENTIC REAL-WORLD CURRICULUM SECTIONS (Retrieved from Encyclopedic & Academic Outlines):
            \(realWorldSections.prefix(16).map { "• \($0)" }.joined(separator: "\n"))

            CRITICAL DIRECTIVE:
            You MUST map and group these authentic topics into 4 to 6 non-overlapping chapters.
            NEVER name chapters with generic meta-placeholders like "Core Axioms", "Concrete Mechanics", "Real-World Contextual Cases", or "Edge Cases".
            Every single chapter title MUST use the actual real-world subject terminology (e.g. for Japanese grammar: "Word Order & Head-Final Topology", "Topic-Prominence & The Wa/Ga Particle System", "Verb Inflectional Morphology & Conjugations", "Politeness & Sociolinguistic Registers")!
            """
        }

        let systemInstruction = """
        You are a World-Class Academic Curriculum Architect and Professor in \(domain.displayName).
        Your mission is to construct an exhaustive, non-overlapping Master Syllabus for: "\(topic)".

        ARCHETYPE DIRECTIVE:
        \(archetype.promptDirective)

        \(taxonomyPromptContext)

        PEDAGOGICAL REQUIREMENTS:
        1. Break the topic down into 4 to 6 distinct, mutually exclusive chapters.
        2. Ensure strict logical progression from conceptual foundations to complex mechanics and nuanced edge cases.
        3. ZERO OVERLAP: No chapter may re-state or duplicate the material of another chapter.
        4. Focus on deep pedagogical rigor, NOT introductory fluff.

        You MUST respond in valid JSON conforming to this exact schema:
        {
          "curriculumTitle": "Rigorous Master Title",
          "overview": "Exhaustive executive summary of the entire field/topic (2 paragraphs)",
          "chapters": [
            {
              "title": "Precise Non-Overlapping Subject Title (NO generic meta-labels)",
              "subtitle": "Specific thematic focus",
              "focusQuestion": "The central academic question this chapter resolves",
              "searchTerms": ["search term 1", "search term 2"],
              "requiredArchetypes": ["Foundations", "Rules & Tables", "Examples", "Pitfalls"]
            }
          ]
        }
        """

        var userPrompt = "Generate the Master Syllabus for topic: \"\(topic)\".\n"
        if let dir = directionPrompt, !dir.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            userPrompt += "Target Focus / Direction: \(dir)\n"
        }
        userPrompt += "Subject Domain: \(domain.displayName)\n"
        userPrompt += "Depth Archetype: \(archetype.rawValue)\n"

        let rawResponse = try await executeLLMCall(
            systemInstruction: systemInstruction,
            userPrompt: userPrompt
        )

        return parseSyllabusJSON(
            rawText: rawResponse,
            fallbackTopic: topic,
            archetype: archetype,
            curatedSections: realWorldSections
        )
    }

    // MARK: - Chapter Deep Synthesis
    public func synthesizeChapter(
        chapter: MasterPlanChapter,
        syllabus: MasterPlanSyllabus,
        priorSummaries: [String],
        snippets: [StudySnippet],
        archetype: MasterPlanDepthArchetype,
        domain: StudySubjectDomain
    ) async throws -> MasterPlanChapterContent {
        let systemInstruction = """
        You are an elite academic scholar, textbook author, and researcher in \(domain.displayName).
        You are writing an exhaustive, graduate-level study chapter titled: "\(chapter.title)".

        CURRICULUM: "\(syllabus.curriculumTitle)"
        FOCUS QUESTION: "\(chapter.focusQuestion)"
        ARCHETYPE: "\(archetype.rawValue)"

        CRITICAL ANTI-REPETITION CONSTRAINTS:
        1. DO NOT repeat definitions, basic terminology, or examples covered in prior chapters.
        2. DO NOT output the chapter title as a block (the system already creates the note title).
        3. Never write vague fluff (e.g. "Japanese words are made up of morphemes..."). Every single section must contain high-density, concrete facts, explicit rules, detailed syntax tables, authentic examples, and edge-case exceptions.

        MANDATORY SECTIONS TO GENERATE:
        - Section 1: Conceptual Core & Theoretical Axioms (heading2 + paragraphs)
        - Section 2: Formal Mechanics, Syntax Rules & Comparative Matrix (heading2 + markdown table / bulletList)
        - Section 3: Concrete Pragmatic Case Studies / Authenticated Examples (heading2 + codeBlock/quote/paragraphs with gloss, translation, or step-by-step derivation)
        - Section 4: Edge Cases, Contrastive Nuances & Frequent Traps (heading2 + bulletList)

        FORMAT REQUIREMENTS:
        Respond in valid JSON:
        {
          "chapterTitle": "\(chapter.title)",
          "summary": "Precise 1-2 sentence executive synopsis of what this chapter proves/teaches.",
          "blocks": [
            { "typeString": "heading2", "content": "1. Conceptual Foundations & Axioms" },
            { "typeString": "paragraph", "content": "Detailed scholarly exposition..." },
            { "typeString": "heading2", "content": "2. Structural Mechanics & Syntax Rules" },
            { "typeString": "paragraph", "content": "| Feature | Rule | Context | Example |\\n| --- | --- | --- | --- |\\n| ..." },
            { "typeString": "heading2", "content": "3. Pragmatic Contextual Cases & Contrastive Analysis" },
            { "typeString": "paragraph", "content": "Authentic example with gloss and translation..." },
            { "typeString": "heading2", "content": "4. Edge Cases, Ellipsis & Frequent Traps" },
            { "typeString": "bulletList", "content": "- Trap 1: ..." }
          ]
        }
        Supported block typeStrings: heading2, heading3, paragraph, bulletList, codeBlock, quote.
        """

        var userPrompt = "Write the comprehensive academic chapter for: \"\(chapter.title)\"\n"
        userPrompt += "Subtitle / Focus: \(chapter.subtitle)\n"
        userPrompt += "Focus Question: \(chapter.focusQuestion)\n\n"

        if !priorSummaries.isEmpty {
            userPrompt += "### PRIOR COMPLETED CHAPTERS (DO NOT REPEAT ANY OF THIS MATERIAL):\n"
            for ps in priorSummaries {
                userPrompt += "- \(ps)\n"
            }
            userPrompt += "\n"
        }

        if !snippets.isEmpty {
            userPrompt += "### FACTUAL ACADEMIC RESEARCH (Ground your synthesis in these verified sources):\n"
            for snip in snippets {
                userPrompt += "[\(snip.source.displayName)] \(snip.title)\n"
                userPrompt += "Summary: \(snip.summary)\n"
                if let cit = snip.citation { userPrompt += "Citation: \(cit)\n" }
                userPrompt += "\n"
            }
        }

        let rawResponse: String
        do {
            rawResponse = try await executeLLMCall(
                systemInstruction: systemInstruction,
                userPrompt: userPrompt
            )
        } catch {
            print("MasterPlanService: LLM generation error for '\(chapter.title)': \(error). Using academic fallback structure.")
            return MasterPlanChapterContent(
                chapterTitle: chapter.title,
                summary: "Essential analysis covering foundational principles of \(chapter.title).",
                blocks: synthesizeFallbackBlocks(for: chapter.title)
            )
        }

        return parseChapterContent(rawText: rawResponse, chapterTitle: chapter.title)
    }

    // MARK: - LLM Caller
    private func executeLLMCall(systemInstruction: String, userPrompt: String) async throws -> String {
        let settings = AISettings.shared
        let provider = settings.activeNotesProvider
        let apiKey = settings.activeNotesApiKey
        let model = settings.activeNotesModel

        do {
            return try await performLLMCall(
                provider: provider,
                apiKey: apiKey,
                model: model,
                systemInstruction: systemInstruction,
                userPrompt: userPrompt,
                endpoint: settings.activeLocalEndpoint
            )
        } catch {
            // Retry once on failure after a brief pause (for transient network or model loading)
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return try await performLLMCall(
                provider: provider,
                apiKey: apiKey,
                model: model,
                systemInstruction: systemInstruction,
                userPrompt: userPrompt,
                endpoint: settings.activeLocalEndpoint
            )
        }
    }

    private func performLLMCall(
        provider: AIProvider,
        apiKey: String,
        model: String,
        systemInstruction: String,
        userPrompt: String,
        endpoint: String
    ) async throws -> String {
        switch provider {
        case .groq:
            let effModel = (model.contains("llama-3.3-70b") || model.isEmpty) ? "qwen/qwen3.8-27b" : model
            return try await callOpenAI(
                apiKey: apiKey,
                model: effModel,
                systemInstruction: systemInstruction,
                userPrompt: userPrompt,
                customEndpoint: "https://api.groq.com/openai/v1"
            )
        case .gemini:
            return try await callGemini(apiKey: apiKey, model: model, systemInstruction: systemInstruction, userPrompt: userPrompt)
        case .openai:
            return try await callOpenAI(apiKey: apiKey, model: model, systemInstruction: systemInstruction, userPrompt: userPrompt)
        case .local:
            return try await callOpenAI(
                apiKey: "ollama",
                model: model,
                systemInstruction: systemInstruction,
                userPrompt: userPrompt,
                customEndpoint: endpoint
            )
        }
    }

    private func callGemini(apiKey: String, model: String, systemInstruction: String, userPrompt: String) async throws -> String {
        let targetModel = (model == "gemini-2.5-flash") ? "gemini-3.6-flash" : model
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(targetModel):generateContent?key=\(cleanKey)"
        guard let url = URL(string: urlString) else {
            throw AISocraticService.ServiceError.invalidResponse("Invalid Gemini URL")
        }

        let requestBody: [String: Any] = [
            "system_instruction": [
                "parts": [["text": systemInstruction]]
            ],
            "contents": [
                ["role": "user", "parts": [["text": userPrompt]]]
            ],
            "generationConfig": [
                "response_mime_type": "application/json",
                "temperature": 0.3
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 180
        sessionConfig.timeoutIntervalForResource = 300
        let session = URLSession(configuration: sessionConfig)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AISocraticService.ServiceError.invalidResponse("No HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            let errText = String(data: data, encoding: .utf8) ?? "Status \(httpResponse.statusCode)"
            throw AISocraticService.ServiceError.invalidResponse("Gemini API Error: \(errText)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let rawText = firstPart["text"] as? String else {
            throw AISocraticService.ServiceError.parsingError("Malformed Gemini JSON response")
        }

        return rawText
    }

    private func callOpenAI(
        apiKey: String,
        model: String,
        systemInstruction: String,
        userPrompt: String,
        customEndpoint: String? = nil
    ) async throws -> String {
        let isLocal = (customEndpoint != nil)
        let endpointUrlString = isLocal
            ? "\(customEndpoint!.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/chat/completions"
            : "https://api.openai.com/v1/chat/completions"

        guard let url = URL(string: endpointUrlString) else {
            throw AISocraticService.ServiceError.invalidResponse("Invalid \(isLocal ? "Local AI" : "OpenAI") URL")
        }

        let messages: [[String: String]] = [
            ["role": "system", "content": systemInstruction],
            ["role": "user", "content": userPrompt]
        ]

        var requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.3
        ]

        if !isLocal {
            requestBody["response_format"] = ["type": "json_object"]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanKey.isEmpty && cleanKey != "ollama" {
            request.addValue("Bearer \(cleanKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 180
        sessionConfig.timeoutIntervalForResource = 300
        let session = URLSession(configuration: sessionConfig)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AISocraticService.ServiceError.invalidResponse("No HTTP response")
        }

        if httpResponse.statusCode != 200 {
            let errText = String(data: data, encoding: .utf8) ?? "Status \(httpResponse.statusCode)"
            let providerName = isLocal ? "Local AI" : "OpenAI"
            throw AISocraticService.ServiceError.invalidResponse("\(providerName) Error: \(errText)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let rawText = message["content"] as? String else {
            throw AISocraticService.ServiceError.parsingError("Malformed OpenAI JSON payload structure.")
        }

        return rawText
    }

    // MARK: - Parsing Helpers
    public func parseSyllabusJSON(
        rawText: String,
        fallbackTopic: String,
        archetype: MasterPlanDepthArchetype,
        curatedSections: [String] = []
    ) -> MasterPlanSyllabus {
        let clean = AISocraticService.sanitizeLLMJSONOutput(rawText)

        if let data = clean.data(using: .utf8),
           let syllabus = try? JSONDecoder().decode(MasterPlanSyllabus.self, from: data),
           isValidCurriculum(syllabus: syllabus) {
            return syllabus
        }

        // Resilient dictionary parsing
        if let data = clean.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let curriculumTitle = (dict["curriculumTitle"] as? String) ?? fallbackTopic
            let overview = (dict["overview"] as? String) ?? "Comprehensive study syllabus for \(fallbackTopic)."
            let rawChapters = (dict["chapters"] as? [[String: Any]]) ?? []

            var chapters: [MasterPlanChapter] = []
            for (idx, chDict) in rawChapters.enumerated() {
                let title = (chDict["title"] as? String) ?? "Chapter \(idx + 1)"
                let sub = (chDict["subtitle"] as? String) ?? ""
                let fq = (chDict["focusQuestion"] as? String) ?? ""
                let st = (chDict["searchTerms"] as? [String]) ?? [title]
                let req = (chDict["requiredArchetypes"] as? [String]) ?? []

                chapters.append(MasterPlanChapter(
                    title: title,
                    subtitle: sub,
                    focusQuestion: fq,
                    searchTerms: st,
                    requiredArchetypes: req
                ))
            }

            let candidateSyllabus = MasterPlanSyllabus(
                curriculumTitle: curriculumTitle,
                overview: overview,
                archetype: archetype,
                chapters: chapters,
                authenticSources: curatedSections
            )

            if isValidCurriculum(syllabus: candidateSyllabus) {
                return candidateSyllabus
            }
        }

        // Guaranteed Grounded Fallback: Construct Syllabus directly from curated Wikipedia sections!
        return buildFallbackSyllabusFromSections(
            topic: fallbackTopic,
            sections: curatedSections,
            archetype: archetype
        )
    }

    private func isValidCurriculum(syllabus: MasterPlanSyllabus) -> Bool {
        guard !syllabus.chapters.isEmpty else { return false }
        let genericMetaNames = ["core axioms", "concrete mechanics", "real-world contextual cases", "edge cases"]
        // Check if the model lazily copied our system prompt's section names as chapter names
        let genericCount = syllabus.chapters.filter { ch in
            genericMetaNames.contains(where: { ch.title.lowercased().contains($0) })
        }.count

        return genericCount < (syllabus.chapters.count / 2)
    }

    private func buildFallbackSyllabusFromSections(
        topic: String,
        sections: [String],
        archetype: MasterPlanDepthArchetype
    ) -> MasterPlanSyllabus {
        let cleanSections = sections.filter { s in
            let lower = s.lowercased()
            return !lower.contains("history") && !lower.contains("external") && !lower.contains("see also")
        }

        let chapterNames: [String]
        if !cleanSections.isEmpty {
            // Pick up to 5 representative sections
            let count = min(cleanSections.count, 5)
            chapterNames = Array(cleanSections.prefix(count))
        } else {
            chapterNames = [
                "Foundational Principles & Syntax Topology",
                "Core Structural Mechanics & Classification",
                "Contextual Applications & Pragmatic Scenarios",
                "Nuanced Exceptions, Pitfalls & Advanced Rules"
            ]
        }

        let chapters = chapterNames.enumerated().map { idx, name in
            MasterPlanChapter(
                title: name,
                subtitle: "Rigorous study module for \(topic)",
                focusQuestion: "What are the essential axioms, rules, and edge cases of \(name)?",
                searchTerms: ["\(topic) \(name)"],
                requiredArchetypes: ["Foundations", "Rules & Tables", "Examples", "Pitfalls"]
            )
        }

        return MasterPlanSyllabus(
            curriculumTitle: "\(topic): Comprehensive Academic Curriculum",
            overview: "An encyclopedically grounded syllabus for mastering \(topic), derived from academic taxonomies and curated encyclopedic sections.",
            archetype: archetype,
            chapters: chapters,
            authenticSources: sections
        )
    }

    public func parseChapterContent(rawText: String, chapterTitle: String) -> MasterPlanChapterContent {
        let clean = AISocraticService.sanitizeLLMJSONOutput(rawText)

        // 1. Try standard JSONSerialization
        if let data = clean.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let summary = (dict["summary"] as? String) ?? ""
            let rawBlocks = (dict["blocks"] as? [[String: Any]]) ?? []

            var blocks: [HierarchicalBlockItem] = []
            for bDict in rawBlocks {
                let typeStr = (bDict["typeString"] as? String) ?? "paragraph"
                let content = (bDict["content"] as? String) ?? ""
                if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    blocks.append(HierarchicalBlockItem(typeString: typeStr, content: content))
                }
            }

            if !blocks.isEmpty {
                let cleanSummary = summary.hasPrefix("{") ? "Overview covering \(chapterTitle)." : summary
                return MasterPlanChapterContent(chapterTitle: chapterTitle, summary: cleanSummary, blocks: blocks)
            }
        }

        // 2. Resilient Regex extraction for malformed or truncated JSON from local models (e.g. qwen2.5:1.5b)
        let extractedBlocks = extractBlocksFromMalformedJSON(rawText: rawText)
        if !extractedBlocks.isEmpty {
            let summary = extractSummaryFromMalformedJSON(rawText: rawText) ?? "Comprehensive study material covering \(chapterTitle)."
            return MasterPlanChapterContent(chapterTitle: chapterTitle, summary: summary, blocks: extractedBlocks)
        }

        // 3. Fallback to Markdown parser (strictly guarding against raw JSON dumps)
        return parseMarkdownToChapterContent(rawText: rawText, chapterTitle: chapterTitle)
    }

    private func extractBlocksFromMalformedJSON(rawText: String) -> [HierarchicalBlockItem] {
        var blocks: [HierarchicalBlockItem] = []
        // Pattern 1: "typeString": "...", "content": "..."
        let pattern1 = #""(?:typeString|type)"\s*:\s*"([^"]+)"\s*,\s*"content"\s*:\s*"((?:[^"\\]|\\.)*)""#
        // Pattern 2: "content": "...", "typeString": "..."
        let pattern2 = #""content"\s*:\s*"((?:[^"\\]|\\.)*)"\s*,\s*"(?:typeString|type)"\s*:\s*"([^"]+)""#

        if let regex = try? NSRegularExpression(pattern: pattern1, options: []) {
            let nsStr = rawText as NSString
            let matches = regex.matches(in: rawText, options: [], range: NSRange(location: 0, length: nsStr.length))
            for m in matches where m.numberOfRanges >= 3 {
                let typeStr = nsStr.substring(with: m.range(at: 1))
                let content = nsStr.substring(with: m.range(at: 2))
                    .replacingOccurrences(of: "\\\"", with: "\"")
                    .replacingOccurrences(of: "\\n", with: "\n")
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    blocks.append(HierarchicalBlockItem(typeString: typeStr, content: trimmed))
                }
            }
        }

        if blocks.isEmpty, let regex = try? NSRegularExpression(pattern: pattern2, options: []) {
            let nsStr = rawText as NSString
            let matches = regex.matches(in: rawText, options: [], range: NSRange(location: 0, length: nsStr.length))
            for m in matches where m.numberOfRanges >= 3 {
                let content = nsStr.substring(with: m.range(at: 1))
                    .replacingOccurrences(of: "\\\"", with: "\"")
                    .replacingOccurrences(of: "\\n", with: "\n")
                let typeStr = nsStr.substring(with: m.range(at: 2))
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    blocks.append(HierarchicalBlockItem(typeString: typeStr, content: trimmed))
                }
            }
        }

        return blocks
    }

    private func extractSummaryFromMalformedJSON(rawText: String) -> String? {
        let pattern = #""summary"\s*:\s*"((?:[^"\\]|\\.)*)""#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: rawText, options: [], range: NSRange(location: 0, length: (rawText as NSString).length)),
           match.numberOfRanges >= 2 {
            let sum = (rawText as NSString).substring(with: match.range(at: 1))
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\n", with: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !sum.isEmpty && !sum.hasPrefix("{") && !sum.contains("\"chapterTitle\"") {
                return sum
            }
        }
        return nil
    }

    public func synthesizeFallbackBlocks(for chapterTitle: String) -> [HierarchicalBlockItem] {
        return [
            HierarchicalBlockItem(typeString: "heading2", content: "1. Foundational Axioms & Definitions"),
            HierarchicalBlockItem(typeString: "paragraph", content: "Core structural taxonomy, essential axioms, and formal mechanics of \(chapterTitle)."),
            HierarchicalBlockItem(typeString: "heading2", content: "2. Systematic Rules & Mechanics"),
            HierarchicalBlockItem(typeString: "paragraph", content: "Systematic principles, execution rules, and comparative classifications governing \(chapterTitle)."),
            HierarchicalBlockItem(typeString: "heading2", content: "3. Concrete Scenarios & Key Edge Cases"),
            HierarchicalBlockItem(typeString: "paragraph", content: "Pragmatic contextual applications, boundary conditions, and common misconceptions.")
        ]
    }

    private func parseMarkdownToChapterContent(rawText: String, chapterTitle: String) -> MasterPlanChapterContent {
        var blocks: [HierarchicalBlockItem] = []
        var summary = ""
        let lines = rawText.components(separatedBy: .newlines)

        var currentParagraph = ""
        func flushParagraph() {
            let trimmed = currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                // Strictly guard: never commit raw JSON syntax into paragraphs or summary
                if !trimmed.hasPrefix("{") && !trimmed.hasPrefix("{\"") && !trimmed.contains("\"chapterTitle\"") && !trimmed.contains("\"blocks\"") {
                    blocks.append(HierarchicalBlockItem(typeString: "paragraph", content: trimmed))
                    if summary.isEmpty && trimmed.count > 20 {
                        summary = trimmed
                    }
                }
            }
            currentParagraph = ""
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                flushParagraph()
                continue
            }

            // Skip lines that look like raw JSON boundaries
            if trimmed.hasPrefix("{") || trimmed.hasPrefix("}") || trimmed.hasPrefix("]") || trimmed.contains("\"blocks\":") {
                continue
            }

            if trimmed.hasPrefix("### ") {
                flushParagraph()
                blocks.append(HierarchicalBlockItem(typeString: "heading3", content: String(trimmed.dropFirst(4))))
            } else if trimmed.hasPrefix("## ") {
                flushParagraph()
                blocks.append(HierarchicalBlockItem(typeString: "heading2", content: String(trimmed.dropFirst(3))))
            } else if trimmed.hasPrefix("# ") {
                flushParagraph()
                let h1Text = String(trimmed.dropFirst(2))
                if h1Text.lowercased() != chapterTitle.lowercased() {
                    blocks.append(HierarchicalBlockItem(typeString: "heading2", content: h1Text))
                }
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
                flushParagraph()
                blocks.append(HierarchicalBlockItem(typeString: "bulletList", content: trimmed))
            } else if trimmed.hasPrefix("> ") {
                flushParagraph()
                let qText = String(trimmed.dropFirst(2))
                if !qText.hasPrefix("{") && !qText.contains("\"chapterTitle\"") {
                    blocks.append(HierarchicalBlockItem(typeString: "quote", content: qText))
                }
            } else {
                if currentParagraph.isEmpty {
                    currentParagraph = trimmed
                } else {
                    currentParagraph += " " + trimmed
                }
            }
        }
        flushParagraph()

        if summary.isEmpty || summary.hasPrefix("{") || summary.contains("\"chapterTitle\"") {
            summary = "Scholarly study material covering \(chapterTitle)."
        }

        if blocks.isEmpty {
            blocks = synthesizeFallbackBlocks(for: chapterTitle)
        }

        return MasterPlanChapterContent(chapterTitle: chapterTitle, summary: summary, blocks: blocks)
    }
}
