import Foundation
import Combine

// MARK: - AI Provider
public enum AIProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    case gemini = "gemini"
    case openai = "openai"
    case local = "local"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .gemini: return "Google Gemini"
        case .openai: return "OpenAI"
        case .local: return "Local AI (Ollama / Self-Hosted)"
        }
    }

    public var defaultModel: String {
        switch self {
        case .gemini: return "gemini-3.6-flash"
        case .openai: return "gpt-4o-mini"
        case .local: return "qwen2.5:1.5b"
        }
    }

    public var availableModels: [String] {
        switch self {
        case .gemini:
            return ["gemini-3.6-flash", "gemini-2.5-flash", "gemini-1.5-flash"]
        case .openai:
            return ["gpt-4o-mini", "gpt-4o", "gpt-3.5-turbo"]
        case .local:
            return [
                "qwen2.5:1.5b",
                "deepseek-r1:1.5b",
                "llama3.2:1b",
                "llama3.2:3b",
                "deepseek-r1:7b",
                "qwen2.5:7b",
                "llama3.1:8b",
                "smollm2:1.7b",
                "mistral:7b"
            ]
        }
    }

    public var helpUrlString: String {
        switch self {
        case .gemini: return "https://aistudio.google.com/app/apikey"
        case .openai: return "https://platform.openai.com/api-keys"
        case .local: return "https://ollama.com"
        }
    }
}

// MARK: - AI Settings Manager
public final class AISettings: ObservableObject {
    public static let shared = AISettings()

    private let keyApiKey = "medha_ai_api_key"
    private let keyProvider = "medha_ai_provider"
    private let keyModel = "medha_ai_model"
    private let keySocraticEnabled = "medha_ai_socratic_enabled"
    private let keyNewCardsOnly = "medha_ai_new_cards_only"
    private let keyUseFlashcardSettingsForNotes = "medha_notes_ai_use_flashcard_settings"
    private let keyNotesApiKey = "medha_notes_ai_api_key"
    private let keyNotesProvider = "medha_notes_ai_provider"
    private let keyNotesModel = "medha_notes_ai_model"
    private let keyLocalEndpoint = "medha_ai_local_endpoint"
    private let keyNotesLocalEndpoint = "medha_notes_ai_local_endpoint"
    private let keyWikipediaGrounding = "medha_ai_wikipedia_grounding"
    private let keyStudySources = "medha_ai_study_sources"

    @Published public var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: keyApiKey) }
    }

    @Published public var provider: AIProvider {
        didSet { UserDefaults.standard.set(provider.rawValue, forKey: keyProvider) }
    }

    @Published public var model: String {
        didSet { UserDefaults.standard.set(model, forKey: keyModel) }
    }

    @Published public var isSocraticEnabled: Bool {
        didSet { UserDefaults.standard.set(isSocraticEnabled, forKey: keySocraticEnabled) }
    }

    @Published public var newCardsOnly: Bool {
        didSet { UserDefaults.standard.set(newCardsOnly, forKey: keyNewCardsOnly) }
    }

    // Local AI Endpoints
    @Published public var localEndpoint: String {
        didSet { UserDefaults.standard.set(localEndpoint, forKey: keyLocalEndpoint) }
    }

    @Published public var notesLocalEndpoint: String {
        didSet { UserDefaults.standard.set(notesLocalEndpoint, forKey: keyNotesLocalEndpoint) }
    }

    // Free Online Wikipedia Grounding (Legacy toggle)
    @Published public var isWikipediaGroundingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isWikipediaGroundingEnabled, forKey: keyWikipediaGrounding)
            if isWikipediaGroundingEnabled && !enabledStudySources.contains(.wikipedia) {
                enabledStudySources.append(.wikipedia)
            } else if !isWikipediaGroundingEnabled && enabledStudySources.contains(.wikipedia) {
                enabledStudySources.removeAll { $0 == .wikipedia }
            }
        }
    }

    // Hybrid Free Study Grounding Sources (Wikipedia, OpenAlex, Europe PMC, Wiktionary)
    @Published public var enabledStudySources: [StudyGroundingSource] {
        didSet {
            let rawList = enabledStudySources.map { $0.rawValue }
            UserDefaults.standard.set(rawList, forKey: keyStudySources)
            let containsWiki = enabledStudySources.contains(.wikipedia)
            if isWikipediaGroundingEnabled != containsWiki {
                UserDefaults.standard.set(containsWiki, forKey: keyWikipediaGrounding)
            }
        }
    }

    // Notes AI Settings
    @Published public var useFlashcardSettingsForNotes: Bool {
        didSet { UserDefaults.standard.set(useFlashcardSettingsForNotes, forKey: keyUseFlashcardSettingsForNotes) }
    }

    @Published public var notesApiKey: String {
        didSet { UserDefaults.standard.set(notesApiKey, forKey: keyNotesApiKey) }
    }

    @Published public var notesProvider: AIProvider {
        didSet { UserDefaults.standard.set(notesProvider.rawValue, forKey: keyNotesProvider) }
    }

    @Published public var notesModel: String {
        didSet { UserDefaults.standard.set(notesModel, forKey: keyNotesModel) }
    }

    public init() {
        let savedKey = UserDefaults.standard.string(forKey: keyApiKey) ?? ""
        let savedProviderRaw = UserDefaults.standard.string(forKey: keyProvider) ?? AIProvider.gemini.rawValue
        let prov = AIProvider(rawValue: savedProviderRaw) ?? .gemini
        var savedModel = UserDefaults.standard.string(forKey: keyModel) ?? prov.defaultModel
        if savedModel == "gemini-2.5-flash" || savedModel.isEmpty {
            savedModel = "gemini-3.6-flash"
            UserDefaults.standard.set("gemini-3.6-flash", forKey: keyModel)
        }
        let isEnabled = UserDefaults.standard.object(forKey: keySocraticEnabled) != nil
            ? UserDefaults.standard.bool(forKey: keySocraticEnabled)
            : true
        let newOnly = UserDefaults.standard.object(forKey: keyNewCardsOnly) != nil
            ? UserDefaults.standard.bool(forKey: keyNewCardsOnly)
            : true

        let savedLocalEp = UserDefaults.standard.string(forKey: keyLocalEndpoint) ?? "http://localhost:11434/v1"
        let savedNotesLocalEp = UserDefaults.standard.string(forKey: keyNotesLocalEndpoint) ?? "http://localhost:11434/v1"
        let wikiGrounding = UserDefaults.standard.object(forKey: keyWikipediaGrounding) != nil
            ? UserDefaults.standard.bool(forKey: keyWikipediaGrounding)
            : true

        let defaultRawSources = [StudyGroundingSource.wikipedia.rawValue, StudyGroundingSource.openAlex.rawValue]
        let savedSourcesRaw = UserDefaults.standard.stringArray(forKey: keyStudySources) ?? defaultRawSources
        var loadedSources = savedSourcesRaw.compactMap { StudyGroundingSource(rawValue: $0) }
        if loadedSources.isEmpty && wikiGrounding {
            loadedSources = [.wikipedia]
        }

        let useSharedForNotes = UserDefaults.standard.object(forKey: keyUseFlashcardSettingsForNotes) != nil
            ? UserDefaults.standard.bool(forKey: keyUseFlashcardSettingsForNotes)
            : true
        let savedNotesKey = UserDefaults.standard.string(forKey: keyNotesApiKey) ?? ""
        let savedNotesProvRaw = UserDefaults.standard.string(forKey: keyNotesProvider) ?? AIProvider.gemini.rawValue
        let notesProv = AIProvider(rawValue: savedNotesProvRaw) ?? .gemini
        var savedNotesModel = UserDefaults.standard.string(forKey: keyNotesModel) ?? notesProv.defaultModel
        if savedNotesModel == "gemini-2.5-flash" || savedNotesModel.isEmpty {
            savedNotesModel = "gemini-3.6-flash"
        }

        self.apiKey = savedKey
        self.provider = prov
        self.model = savedModel
        self.isSocraticEnabled = isEnabled
        self.newCardsOnly = newOnly

        self.localEndpoint = savedLocalEp
        self.notesLocalEndpoint = savedNotesLocalEp
        self.isWikipediaGroundingEnabled = wikiGrounding
        self.enabledStudySources = loadedSources

        self.useFlashcardSettingsForNotes = useSharedForNotes
        self.notesApiKey = savedNotesKey
        self.notesProvider = notesProv
        self.notesModel = savedNotesModel
    }

    public func isStudySourceEnabled(_ source: StudyGroundingSource) -> Bool {
        enabledStudySources.contains(source)
    }

    public func toggleStudySource(_ source: StudyGroundingSource) {
        if let idx = enabledStudySources.firstIndex(of: source) {
            enabledStudySources.remove(at: idx)
        } else {
            enabledStudySources.append(source)
        }
    }

    public func isCompactContextModel(model: String) -> Bool {
        let lower = model.lowercased()
        return lower.contains("1b") || lower.contains("1.5b") || lower.contains("2b") || lower.contains("3b")
    }

    public var hasAPIKey: Bool {
        if provider == .local {
            return true // Local AI runs locally without a required cloud key
        }
        return !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var maskedKey: String {
        if provider == .local {
            return "No key needed (Local AI)"
        }
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else {
            return trimmed.isEmpty ? "No key configured" : "••••••••"
        }
        let prefix = trimmed.prefix(4)
        let suffix = trimmed.suffix(4)
        return "\(prefix)••••\(suffix)"
    }

    // Active Notes AI resolution
    public var activeNotesApiKey: String {
        useFlashcardSettingsForNotes ? apiKey : notesApiKey
    }

    public var activeNotesProvider: AIProvider {
        useFlashcardSettingsForNotes ? provider : notesProvider
    }

    public var activeNotesModel: String {
        useFlashcardSettingsForNotes ? model : notesModel
    }

    public var activeLocalEndpoint: String {
        let ep = useFlashcardSettingsForNotes ? localEndpoint : notesLocalEndpoint
        let trimmed = ep.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "http://localhost:11434/v1" : trimmed
    }

    public var hasNotesAPIKey: Bool {
        if activeNotesProvider == .local {
            return true // Local AI runs locally without a required cloud key
        }
        return !activeNotesApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var maskedNotesKey: String {
        if activeNotesProvider == .local {
            return "No key needed (Local AI)"
        }
        let trimmed = activeNotesApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else {
            return trimmed.isEmpty ? "No key configured" : "••••••••"
        }
        let prefix = trimmed.prefix(4)
        let suffix = trimmed.suffix(4)
        return "\(prefix)••••\(suffix)"
    }
}

// MARK: - Evaluation Models
public struct AISocraticEvaluation: Codable, Sendable, Equatable {
    public var isSpotOn: Bool
    public var status: String              // "spot_on" | "probing"
    public var feedback: String            // Constructive feedback / praise
    public var counterQuestion: String?    // Socratic guiding question if not spot-on
    public var suggestedRating: Int?       // 1 (Again), 2 (Hard), 3 (Good), 4 (Easy)

    public init(
        isSpotOn: Bool,
        status: String,
        feedback: String,
        counterQuestion: String? = nil,
        suggestedRating: Int? = nil
    ) {
        self.isSpotOn = isSpotOn
        self.status = status
        self.feedback = feedback
        self.counterQuestion = counterQuestion
        self.suggestedRating = suggestedRating
    }
}

public struct AISocraticTurn: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var roundNumber: Int
    public var userAnswer: String
    public var feedback: String
    public var counterQuestion: String?
    public var isSpotOn: Bool
    public var timestamp: Date

    public init(
        id: UUID = UUID(),
        roundNumber: Int,
        userAnswer: String,
        feedback: String,
        counterQuestion: String? = nil,
        isSpotOn: Bool,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.roundNumber = roundNumber
        self.userAnswer = userAnswer
        self.feedback = feedback
        self.counterQuestion = counterQuestion
        self.isSpotOn = isSpotOn
        self.timestamp = timestamp
    }
}

// MARK: - Socratic AI Evaluation Service
public final class AISocraticService: Sendable {
    public static let shared = AISocraticService()

    private init() {}

    public enum ServiceError: LocalizedError {
        case missingAPIKey
        case invalidResponse(String)
        case networkError(String)
        case parsingError(String)

        public var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "API key is missing. Please configure your API key in AI Settings."
            case .invalidResponse(let msg):
                return "AI response error: \(msg)"
            case .networkError(let msg):
                return "Network connection error: \(msg)"
            case .parsingError(let msg):
                return "Failed to parse AI evaluation: \(msg)"
            }
        }
    }

    /// System instructions enforcing strict Socratic tutoring and JSON output
    public static let socraticSystemPrompt = """
    You are an encouraging, expert pedagogical Socratic Tutor inside the Medha PKM & Spaced Repetition platform.
    Your mission is to guide the student to deep conceptual understanding through active recall.

    You will be provided:
    1. The Flashcard Question (Front)
    2. The Target Expected Answer (Back)
    3. Optional Hint
    4. Prior Dialogue History (if any)
    5. The Student's Current Written Response

    Evaluation Rules:
    - If the student's answer accurately captures the core principles and concepts of the target answer, celebrate their insight:
      * Set isSpotOn = true
      * Set status = "spot_on"
      * Set counterQuestion = null
      * In feedback, provide concise praise explaining why their understanding is spot-on.
      * Set suggestedRating = 3 or 4.
    - If the student's answer is partially correct, vague, missing a critical piece, or reveals a misconception:
      * Set isSpotOn = false
      * Set status = "probing"
      * In feedback, acknowledge the positive parts of what they wrote, and gently pinpoint what is missing without giving away the complete target answer.
      * In counterQuestion, formulate ONE clear, thought-provoking Socratic question that prompts the student to think about the missing concept.
      * Set suggestedRating = 2.
    - If the student writes that they have no idea or a blank attempt:
      * Set isSpotOn = false
      * Set status = "probing"
      * In feedback, give an encouraging gentle hint.
      * In counterQuestion, ask a simplified guiding question.
      * Set suggestedRating = 1.
    - If this is dialogue round 3 or greater, be generous: synthesize their answers, affirm what they learned, mark isSpotOn = true, and reveal how it connects.

    You MUST respond in strict, valid JSON conforming to this exact schema:
    {
      "isSpotOn": boolean,
      "status": "spot_on" or "probing",
      "feedback": "string",
      "counterQuestion": "string or null",
      "suggestedRating": 1 or 2 or 3 or 4
    }
    """

    /// Evaluates a written answer using the configured AI provider
    public func evaluateAnswer(
        question: String,
        targetAnswer: String,
        hint: String? = nil,
        userAnswer: String,
        dialogueHistory: [AISocraticTurn] = []
    ) async throws -> AISocraticEvaluation {
        let settings = AISettings.shared
        guard settings.hasAPIKey else {
            throw ServiceError.missingAPIKey
        }

        var effectiveTargetAnswer = targetAnswer
        let isCompact = settings.isCompactContextModel(model: settings.model)
        let activeSources = !settings.enabledStudySources.isEmpty
            ? settings.enabledStudySources
            : (settings.isWikipediaGroundingEnabled ? [.wikipedia] : [])

        if !activeSources.isEmpty {
            let snippets = await StudyKnowledgeService.shared.fetchGroundedKnowledge(
                for: question,
                sources: activeSources,
                isCompactBudget: isCompact
            )
            for snippet in snippets {
                effectiveTargetAnswer += "\n[\(snippet.source.displayName) Verified Knowledge: \(snippet.summary)]"
            }
        }

        switch settings.provider {
        case .gemini:
            return try await evaluateWithGemini(
                apiKey: settings.apiKey,
                model: settings.model,
                question: question,
                targetAnswer: effectiveTargetAnswer,
                hint: hint,
                userAnswer: userAnswer,
                dialogueHistory: dialogueHistory
            )
        case .openai:
            return try await evaluateWithOpenAI(
                apiKey: settings.apiKey,
                model: settings.model,
                question: question,
                targetAnswer: effectiveTargetAnswer,
                hint: hint,
                userAnswer: userAnswer,
                dialogueHistory: dialogueHistory
            )
        case .local:
            return try await evaluateWithOpenAI(
                apiKey: "ollama",
                model: settings.model,
                question: question,
                targetAnswer: effectiveTargetAnswer,
                hint: hint,
                userAnswer: userAnswer,
                dialogueHistory: dialogueHistory,
                customEndpoint: settings.activeLocalEndpoint
            )
        }
    }

    /// Discovers available chat models from an OpenAI-compatible local endpoint (e.g. LM Studio, Ollama, etc.)
    public func fetchLocalModels(endpoint: String) async -> [String] {
        let base = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { return [] }
        let normalizedBase = base.hasPrefix("http") ? base : "http://\(base)"
        let trimmedBase = normalizedBase.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmedBase)/models") else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataList = json["data"] as? [[String: Any]] else {
            return []
        }

        return dataList.compactMap { item -> String? in
            guard let id = item["id"] as? String, !id.contains("embed") else { return nil }
            return id
        }
    }

    /// Validates the given API key or local endpoint with a test ping
    public func validateAPIKey(
        key: String,
        provider: AIProvider,
        model: String
    ) async -> (isValid: Bool, message: String) {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if provider != .local && cleanKey.isEmpty {
            return (false, "API key cannot be empty.")
        }

        do {
            switch provider {
            case .gemini:
                let targetModel = (model == "gemini-2.5-flash") ? "gemini-3.6-flash" : model
                let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(targetModel):generateContent?key=\(cleanKey)"
                guard let url = URL(string: urlString) else {
                    return (false, "Invalid endpoint URL.")
                }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")

                let payload: [String: Any] = [
                    "contents": [
                        [
                            "role": "user",
                            "parts": [["text": "Ping. Reply with JSON {\"status\":\"ok\"}"]]
                        ]
                    ],
                    "generationConfig": [
                        "response_mime_type": "application/json"
                    ]
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    return (false, "Invalid HTTP response.")
                }

                if httpResponse.statusCode == 200 {
                    return (true, "Key verified successfully with \(targetModel)!")
                } else {
                    let bodyString = String(data: data, encoding: .utf8) ?? ""
                    if bodyString.contains("gemini-3.6-flash") && targetModel != "gemini-3.6-flash" {
                        return await validateAPIKey(key: cleanKey, provider: provider, model: "gemini-3.6-flash")
                    }
                    var cleanMsg = "Status \(httpResponse.statusCode)"
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorObj = json["error"] as? [String: Any],
                       let msg = errorObj["message"] as? String {
                        cleanMsg = msg
                    } else {
                        cleanMsg = String(bodyString.prefix(120))
                    }
                    return (false, "Gemini error: \(cleanMsg)")
                }

            case .openai:
                guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
                    return (false, "Invalid OpenAI endpoint URL.")
                }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.addValue("Bearer \(cleanKey)", forHTTPHeaderField: "Authorization")

                let payload: [String: Any] = [
                    "model": model,
                    "messages": [
                        ["role": "user", "content": "Ping. Reply with JSON {\"status\":\"ok\"}"]
                    ],
                    "response_format": ["type": "json_object"],
                    "max_tokens": 10
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    return (false, "Invalid HTTP response.")
                }

                if httpResponse.statusCode == 200 {
                    return (true, "Key verified successfully!")
                } else {
                    let bodyString = String(data: data, encoding: .utf8) ?? ""
                    return (false, "OpenAI error (\(httpResponse.statusCode)): \(bodyString.prefix(120))")
                }

            case .local:
                let base = cleanKey.isEmpty ? AISettings.shared.activeLocalEndpoint : cleanKey
                let normalizedBase = base.hasPrefix("http") ? base : "http://\(base)"
                let trimmedBase = normalizedBase.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

                // 1. Check if server is reachable and inspect available models
                var effectiveModel = model
                var discoveredChatModels: [String] = []
                if let modelsUrl = URL(string: "\(trimmedBase)/models") {
                    var mReq = URLRequest(url: modelsUrl)
                    mReq.timeoutInterval = 3.0
                    if let (mData, mResp) = try? await URLSession.shared.data(for: mReq),
                       let mHttp = mResp as? HTTPURLResponse, mHttp.statusCode == 200,
                       let mJson = try? JSONSerialization.jsonObject(with: mData) as? [String: Any],
                       let dataList = mJson["data"] as? [[String: Any]] {
                        discoveredChatModels = dataList.compactMap { item -> String? in
                            guard let id = item["id"] as? String, !id.contains("embed") else { return nil }
                            return id
                        }
                    }
                }

                // If user's model isn't in discovered list and discovered models exist, auto-select the first one
                if !discoveredChatModels.isEmpty && (!discoveredChatModels.contains(model) || model.isEmpty) {
                    effectiveModel = discoveredChatModels.first ?? model
                }

                let urlString = "\(trimmedBase)/chat/completions"
                guard let url = URL(string: urlString) else {
                    return (false, "Invalid Local AI endpoint URL.")
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.timeoutInterval = 10.0
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")

                let payload: [String: Any] = [
                    "model": effectiveModel,
                    "messages": [
                        ["role": "user", "content": "Ping. Reply with {\"status\":\"ok\"}"]
                    ],
                    "temperature": 0.1,
                    "max_tokens": 10
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    return (false, "No response from Local AI.")
                }

                if httpResponse.statusCode == 200 {
                    return (true, "Local AI connected successfully! (Model: \(effectiveModel))")
                } else {
                    var cleanMsg = "Status \(httpResponse.statusCode)"
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let errorObj = json["error"] as? [String: Any],
                           let msg = errorObj["message"] as? String {
                            cleanMsg = msg
                        } else if let msg = json["message"] as? String {
                            cleanMsg = msg
                        }
                    } else {
                        let errBody = String(data: data, encoding: .utf8) ?? ""
                        if !errBody.isEmpty {
                            cleanMsg = String(errBody.prefix(120))
                        }
                    }
                    if cleanMsg.contains("No models loaded") {
                        cleanMsg = "LM Studio is running, but no model is loaded. Please select and load a model at the top of LM Studio."
                    }
                    return (false, "Local AI error (\(httpResponse.statusCode)): \(cleanMsg)")
                }
            }
        } catch {
            if provider == .local {
                let base = cleanKey.isEmpty ? AISettings.shared.activeLocalEndpoint : cleanKey
                return (false, "Could not connect to Local AI at \(base). Ensure LM Studio or Ollama server is running.")
            }
            return (false, "Network error: \(error.localizedDescription)")
        }
    }

    // MARK: - Private API Implementation (Gemini)
    private func evaluateWithGemini(
        apiKey: String,
        model: String,
        question: String,
        targetAnswer: String,
        hint: String?,
        userAnswer: String,
        dialogueHistory: [AISocraticTurn]
    ) async throws -> AISocraticEvaluation {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))"
        guard let url = URL(string: urlString) else {
            throw ServiceError.invalidResponse("Invalid Gemini URL")
        }

        var promptBuilder = "### FLASHCARD CONTEXT\n"
        promptBuilder += "- Question: \(question)\n"
        promptBuilder += "- Target Answer: \(targetAnswer)\n"
        if let h = hint, !h.isEmpty {
            promptBuilder += "- Hint: \(h)\n"
        }

        if !dialogueHistory.isEmpty {
            promptBuilder += "\n### PRIOR SOCRATIC DIALOGUE ROUNDS\n"
            for turn in dialogueHistory {
                promptBuilder += "Round \(turn.roundNumber):\n"
                promptBuilder += "Student said: \"\(turn.userAnswer)\"\n"
                promptBuilder += "AI Feedback: \"\(turn.feedback)\"\n"
                if let cq = turn.counterQuestion {
                    promptBuilder += "AI Counter-Question: \"\(cq)\"\n"
                }
            }
        }

        promptBuilder += "\n### CURRENT STUDENT RESPONSE (Round \(dialogueHistory.count + 1))\n"
        promptBuilder += "\"\(userAnswer)\"\n\n"
        promptBuilder += "Evaluate the student's answer against the target answer and respond with the required JSON."

        let requestBody: [String: Any] = [
            "system_instruction": [
                "parts": [
                    ["text": Self.socraticSystemPrompt]
                ]
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": promptBuilder]
                    ]
                ]
            ],
            "generationConfig": [
                "response_mime_type": "application/json",
                "temperature": 0.3
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse("No HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            let errText = String(data: data, encoding: .utf8) ?? "Status \(httpResponse.statusCode)"

            // Auto-recovery: If gemini-2.5-flash was rejected/deprecated or 404, automatically migrate to gemini-3.6-flash and retry!
            if model != "gemini-3.6-flash" && (httpResponse.statusCode == 404 || errText.contains("gemini-3.6-flash") || errText.contains("NOT_FOUND") || errText.contains("no longer available")) {
                await MainActor.run {
                    AISettings.shared.model = "gemini-3.6-flash"
                }
                return try await evaluateWithGemini(
                    apiKey: apiKey,
                    model: "gemini-3.6-flash",
                    question: question,
                    targetAnswer: targetAnswer,
                    hint: hint,
                    userAnswer: userAnswer,
                    dialogueHistory: dialogueHistory
                )
            }

            // Clean, human-friendly error extraction
            var cleanMessage = "Status \(httpResponse.statusCode)"
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorObj = json["error"] as? [String: Any],
               let msg = errorObj["message"] as? String {
                cleanMessage = msg
            } else {
                cleanMessage = errText
            }
            throw ServiceError.invalidResponse("Gemini API Error: \(cleanMessage)")
        }

        return try parseGeminiResponse(data: data)
    }

    private func parseGeminiResponse(data: Data) throws -> AISocraticEvaluation {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let rawText = firstPart["text"] as? String else {
            throw ServiceError.parsingError("Malformed Gemini JSON payload structure.")
        }

        return try parseEvaluationJSON(rawText: rawText)
    }

    // MARK: - Error Message Helpers
    private func extractCleanErrorMessage(from data: Data, fallback: String) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let errorObj = json["error"] as? [String: Any],
               let msg = errorObj["message"] as? String {
                return msg
            } else if let errorStr = json["error"] as? String {
                return errorStr
            } else if let msg = json["message"] as? String {
                return msg
            }
        }
        return fallback
    }

    // MARK: - Private API Implementation (OpenAI & Local)
    private func evaluateWithOpenAI(
        apiKey: String,
        model: String,
        question: String,
        targetAnswer: String,
        hint: String?,
        userAnswer: String,
        dialogueHistory: [AISocraticTurn],
        customEndpoint: String? = nil
    ) async throws -> AISocraticEvaluation {
        let isLocal = (customEndpoint != nil)
        let endpointUrlString = isLocal
            ? "\(customEndpoint!.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/chat/completions"
            : "https://api.openai.com/v1/chat/completions"

        guard let url = URL(string: endpointUrlString) else {
            throw ServiceError.invalidResponse("Invalid \(isLocal ? "Local AI" : "OpenAI") URL")
        }

        var messages: [[String: String]] = [
            ["role": "system", "content": Self.socraticSystemPrompt]
        ]

        var promptBuilder = "### FLASHCARD CONTEXT\n"
        promptBuilder += "- Question: \(question)\n"
        promptBuilder += "- Target Answer: \(targetAnswer)\n"
        if let h = hint, !h.isEmpty {
            promptBuilder += "- Hint: \(h)\n"
        }

        if !dialogueHistory.isEmpty {
            promptBuilder += "\n### PRIOR SOCRATIC DIALOGUE ROUNDS\n"
            for turn in dialogueHistory {
                promptBuilder += "Round \(turn.roundNumber):\n"
                promptBuilder += "Student: \"\(turn.userAnswer)\"\n"
                promptBuilder += "AI Feedback: \"\(turn.feedback)\"\n"
                if let cq = turn.counterQuestion {
                    promptBuilder += "AI Counter-Question: \"\(cq)\"\n"
                }
            }
        }

        promptBuilder += "\n### CURRENT STUDENT RESPONSE (Round \(dialogueHistory.count + 1))\n"
        promptBuilder += "\"\(userAnswer)\"\n\n"
        promptBuilder += "Evaluate the student's answer against the target answer and respond with the required JSON."

        messages.append(["role": "user", "content": promptBuilder])

        var requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.3
        ]

        // Local servers (LM Studio, Ollama, etc.) often reject `json_object` or require `json_schema`/`text`.
        // Only pass json_object if talking to official OpenAI API.
        if !isLocal {
            requestBody["response_format"] = ["type": "json_object"]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanKey.isEmpty && cleanKey != "ollama" {
            request.addValue("Bearer \(cleanKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        var (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse("No HTTP response")
        }

        if httpResponse.statusCode != 200 {
            let errText = String(data: data, encoding: .utf8) ?? "Status \(httpResponse.statusCode)"
            let providerName = isLocal ? "Local AI Error" : "OpenAI API Error"

            // If the server rejected response_format, auto-retry once without it
            if errText.contains("response_format") && requestBody["response_format"] != nil {
                requestBody.removeValue(forKey: "response_format")
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                if let (fallbackData, fallbackResponse) = try? await URLSession.shared.data(for: request),
                   let fbHttp = fallbackResponse as? HTTPURLResponse, fbHttp.statusCode == 200 {
                    data = fallbackData
                } else {
                    let cleanMsg = extractCleanErrorMessage(from: data, fallback: errText)
                    throw ServiceError.invalidResponse("\(providerName): \(cleanMsg)")
                }
            } else {
                let cleanMsg = extractCleanErrorMessage(from: data, fallback: errText)
                throw ServiceError.invalidResponse("\(providerName): \(cleanMsg)")
            }
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let rawText = message["content"] as? String else {
            throw ServiceError.parsingError("Malformed \(isLocal ? "Local AI" : "OpenAI") JSON payload structure.")
        }

        return try parseEvaluationJSON(rawText: rawText)
    }

    /// Robustly sanitizes raw LLM output by removing reasoning blocks (<think>...</think>),
    /// stripping markdown code fences, and isolating the innermost JSON payload.
    public static func sanitizeLLMJSONOutput(_ rawText: String) -> String {
        var clean = rawText
        // 1. Strip reasoning blocks from models like DeepSeek-R1, QwQ, etc. (<think> ... </think>)
        clean = clean.replacingOccurrences(
            of: "<think>[\\s\\S]*?</think>",
            with: "",
            options: .regularExpression
        )
        // If unclosed <think> tag at start
        if let thinkStart = clean.range(of: "<think>") {
            clean = String(clean[..<thinkStart.lowerBound])
        }

        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)

        // 2. Strip markdown code fences (```json ... ``` or ``` ... ```)
        if clean.hasPrefix("```json") {
            clean = String(clean.dropFirst(7))
        } else if clean.hasPrefix("```") {
            clean = String(clean.dropFirst(3))
        }
        if clean.hasSuffix("```") {
            clean = String(clean.dropLast(3))
        }
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)

        // 3. Fallback: If there is leading/trailing conversational text outside the first { and last }, isolate it
        if let firstBrace = clean.firstIndex(of: "{"),
           let lastBrace = clean.lastIndex(of: "}"),
           firstBrace <= lastBrace {
            clean = String(clean[firstBrace...lastBrace])
        }

        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parses raw JSON text into an AISocraticEvaluation object
    public func parseEvaluationJSON(rawText: String) throws -> AISocraticEvaluation {
        let clean = Self.sanitizeLLMJSONOutput(rawText)

        guard let data = clean.data(using: .utf8) else {
            throw ServiceError.parsingError("Could not convert text to data.")
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(AISocraticEvaluation.self, from: data)
        } catch {
            // Fallback dictionary extraction
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let isSpotOn = (dict["isSpotOn"] as? Bool) ?? ((dict["status"] as? String) == "spot_on")
                let status = (dict["status"] as? String) ?? (isSpotOn ? "spot_on" : "probing")
                let feedback = (dict["feedback"] as? String) ?? "Good effort."
                let counterQuestion = dict["counterQuestion"] as? String
                let suggestedRating = dict["suggestedRating"] as? Int

                return AISocraticEvaluation(
                    isSpotOn: isSpotOn,
                    status: status,
                    feedback: feedback,
                    counterQuestion: counterQuestion,
                    suggestedRating: suggestedRating
                )
            }
            throw ServiceError.parsingError("Decoding error: \(error.localizedDescription)")
        }
    }

    // MARK: - Downward Hierarchical Notes Generation
    public static let hierarchicalSystemPrompt = """
    You are an expert knowledge architect and structured note-taking assistant inside the Medha PKM system.
    Your mission is to analyze the user's current note and generate a structured DOWNWARD hierarchy of subtopics and sub-subtopics.

    CRITICAL CONSTRAINTS:
    1. The generated tree MUST only expand DOWNWARD starting from the current note as the root. Never attempt to reparent, modify, or create siblings above or outside this note.
    2. Each subtopic should be clear, concise, and logically organized into branches.
    3. Provide clean formatted blocks (headings, bullet points, paragraphs, or tasks) for each node. Do NOT generate callout blocks.
    4. Sub-nodes can have further children (sub-subtopics) when depth permits.

    You MUST respond in strict, valid JSON conforming to this exact schema:
    {
      "rootTitle": "string (the current note title)",
      "overview": "string (brief overview of the generated structure)",
      "items": [
        {
          "title": "string (subtopic title)",
          "summary": "string (concise 1-2 sentence overview of this sub-note)",
          "blocks": [
            {
              "typeString": "heading2",
              "content": "string"
            },
            {
              "typeString": "paragraph",
              "content": "string"
            },
            {
              "typeString": "bulletList",
              "content": "string"
            }
          ],
          "children": [
            {
              "title": "string (sub-subtopic title)",
              "summary": "string",
              "blocks": [
                {
                  "typeString": "paragraph",
                  "content": "string"
                }
              ],
              "children": []
            }
          ]
        }
      ]
    }
    """

    public func generateDownwardHierarchy(
        currentNoteTitle: String,
        currentNoteContent: String,
        mode: NotesGenerationMode,
        customInstruction: String? = nil,
        selectedSources: [StudyGroundingSource]? = nil
    ) async throws -> HierarchicalGenerationResult {
        let settings = AISettings.shared
        guard settings.hasNotesAPIKey else {
            throw ServiceError.missingAPIKey
        }

        let apiKey = settings.activeNotesApiKey
        let provider = settings.activeNotesProvider
        let model = settings.activeNotesModel
        let isCompact = settings.isCompactContextModel(model: model)

        var promptBuilder = "### ACTIVE CURRENT NOTE (ROOT OF NEW HIERARCHY)\n"
        promptBuilder += "- Current Title: \(currentNoteTitle)\n"
        if !currentNoteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let maxBody = isCompact ? 1500 : 4000
            promptBuilder += "- Current Note Body & Blocks:\n\(currentNoteContent.prefix(maxBody))\n"
        } else {
            promptBuilder += "- Current Note Body: (Empty note, please expand from title)\n"
        }

        promptBuilder += "\n### TASK & INSTRUCTION\n"
        switch mode {
        case .expandSubtopics:
            promptBuilder += "Action: Expand this note into structured subtopics and sub-subtopics.\n"
            if let custom = customInstruction, !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                promptBuilder += "Focus Area: \(custom)\n"
            }
        case .summarizeAndSplit:
            promptBuilder += "Action: Analyze the current note's content and split it into a downward tree of modular sub-topic notes.\n"
        case .custom:
            promptBuilder += "Action: \(customInstruction ?? "Create structured hierarchical sub-notes downwards from this note.")\n"
        }

        // Hybrid Free Study Grounding
        let activeSources: [StudyGroundingSource]
        if let explicit = selectedSources {
            activeSources = explicit
        } else if !settings.enabledStudySources.isEmpty {
            activeSources = settings.enabledStudySources
        } else if settings.isWikipediaGroundingEnabled {
            activeSources = [.wikipedia]
        } else {
            activeSources = []
        }

        if !activeSources.isEmpty {
            let snippets = await StudyKnowledgeService.shared.fetchGroundedKnowledge(
                for: currentNoteTitle,
                sources: activeSources,
                isCompactBudget: isCompact
            )
            if !snippets.isEmpty {
                promptBuilder += "\n### FACTUAL STUDY GROUNDING (VERIFIED KNOWLEDGE)\n"
                for snippet in snippets {
                    promptBuilder += "[\(snippet.source.displayName)] \(snippet.title)\n"
                    promptBuilder += "- Summary: \(snippet.summary)\n"
                    if let citation = snippet.citation {
                        promptBuilder += "- Citation: \(citation)\n"
                    }
                    if let link = snippet.urlString {
                        promptBuilder += "- Reference Link: \(link)\n"
                    }
                    promptBuilder += "\n"
                }
            }
        }

        promptBuilder += "\nRemember: Generate a strictly downward hierarchy rooting from this note. Return valid JSON matching the schema."

        switch provider {
        case .gemini:
            return try await generateHierarchyWithGemini(
                apiKey: apiKey,
                model: model,
                prompt: promptBuilder,
                fallbackTitle: currentNoteTitle
            )
        case .openai:
            return try await generateHierarchyWithOpenAI(
                apiKey: apiKey,
                model: model,
                prompt: promptBuilder,
                fallbackTitle: currentNoteTitle
            )
        case .local:
            return try await generateHierarchyWithOpenAI(
                apiKey: "ollama",
                model: model,
                prompt: promptBuilder,
                fallbackTitle: currentNoteTitle,
                customEndpoint: settings.activeLocalEndpoint
            )
        }
    }

    private func generateHierarchyWithGemini(
        apiKey: String,
        model: String,
        prompt: String,
        fallbackTitle: String
    ) async throws -> HierarchicalGenerationResult {
        let targetModel = (model == "gemini-2.5-flash") ? "gemini-3.6-flash" : model
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(targetModel):generateContent?key=\(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))"
        guard let url = URL(string: urlString) else {
            throw ServiceError.invalidResponse("Invalid Gemini URL")
        }

        let requestBody: [String: Any] = [
            "system_instruction": [
                "parts": [
                    ["text": Self.hierarchicalSystemPrompt]
                ]
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "response_mime_type": "application/json",
                "temperature": 0.4
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse("No HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            let errText = String(data: data, encoding: .utf8) ?? "Status \(httpResponse.statusCode)"
            var cleanMsg = "Status \(httpResponse.statusCode)"
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorObj = json["error"] as? [String: Any],
               let msg = errorObj["message"] as? String {
                cleanMsg = msg
            } else {
                cleanMsg = errText
            }
            throw ServiceError.invalidResponse("Gemini API Error: \(cleanMsg)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let rawText = firstPart["text"] as? String else {
            throw ServiceError.parsingError("Malformed Gemini JSON response")
        }

        return try parseHierarchicalJSON(rawText: rawText, fallbackTitle: fallbackTitle)
    }

    private func generateHierarchyWithOpenAI(
        apiKey: String,
        model: String,
        prompt: String,
        fallbackTitle: String,
        customEndpoint: String? = nil
    ) async throws -> HierarchicalGenerationResult {
        let isLocal = (customEndpoint != nil)
        let endpointUrlString = isLocal
            ? "\(customEndpoint!.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/chat/completions"
            : "https://api.openai.com/v1/chat/completions"

        guard let url = URL(string: endpointUrlString) else {
            throw ServiceError.invalidResponse("Invalid \(isLocal ? "Local AI" : "OpenAI") URL")
        }

        let messages: [[String: String]] = [
            ["role": "system", "content": Self.hierarchicalSystemPrompt],
            ["role": "user", "content": prompt]
        ]

        var requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.4
        ]

        // Local servers (LM Studio, Ollama, etc.) often reject `json_object` or require `json_schema`/`text`.
        // Only pass json_object if talking to official OpenAI API.
        if !isLocal {
            requestBody["response_format"] = ["type": "json_object"]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanKey.isEmpty && cleanKey != "ollama" {
            request.addValue("Bearer \(cleanKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        var (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse("No HTTP response")
        }

        if httpResponse.statusCode != 200 {
            let errText = String(data: data, encoding: .utf8) ?? "Status \(httpResponse.statusCode)"
            let providerName = isLocal ? "Local AI Error" : "OpenAI API Error"

            // If the server rejected response_format, auto-retry once without it
            if errText.contains("response_format") && requestBody["response_format"] != nil {
                requestBody.removeValue(forKey: "response_format")
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                if let (fallbackData, fallbackResponse) = try? await URLSession.shared.data(for: request),
                   let fbHttp = fallbackResponse as? HTTPURLResponse, fbHttp.statusCode == 200 {
                    data = fallbackData
                } else {
                    let cleanMsg = extractCleanErrorMessage(from: data, fallback: errText)
                    throw ServiceError.invalidResponse("\(providerName): \(cleanMsg)")
                }
            } else {
                let cleanMsg = extractCleanErrorMessage(from: data, fallback: errText)
                throw ServiceError.invalidResponse("\(providerName): \(cleanMsg)")
            }
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let rawText = message["content"] as? String else {
            throw ServiceError.parsingError("Malformed \(isLocal ? "Local AI" : "OpenAI") JSON payload structure.")
        }

        return try parseHierarchicalJSON(rawText: rawText, fallbackTitle: fallbackTitle)
    }

    public func parseHierarchicalJSON(rawText: String, fallbackTitle: String = "Current Note") throws -> HierarchicalGenerationResult {
        let clean = Self.sanitizeLLMJSONOutput(rawText)

        guard let data = clean.data(using: .utf8) else {
            throw ServiceError.parsingError("Could not convert text to data.")
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(HierarchicalGenerationResult.self, from: data)
        } catch {
            // Fallback dictionary decoding
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let rootTitle = (dict["rootTitle"] as? String) ?? fallbackTitle
                let overview = (dict["overview"] as? String) ?? "Generated Hierarchy"
                let rawItems = (dict["items"] as? [[String: Any]]) ?? []
                let items = parseRawNodes(rawItems)
                return HierarchicalGenerationResult(rootTitle: rootTitle, overview: overview, items: items)
            }
            throw ServiceError.parsingError("Failed to decode hierarchical JSON: \(error.localizedDescription)")
        }
    }

    private func parseRawNodes(_ rawNodes: [[String: Any]]) -> [HierarchicalNode] {
        return rawNodes.map { nodeDict in
            let title = (nodeDict["title"] as? String) ?? "Untitled Subtopic"
            let summary = (nodeDict["summary"] as? String) ?? ""
            let rawBlocks = (nodeDict["blocks"] as? [[String: Any]]) ?? []
            let blocks = rawBlocks.map { bDict in
                let t = (bDict["typeString"] as? String) ?? "paragraph"
                let c = (bDict["content"] as? String) ?? ""
                return HierarchicalBlockItem(typeString: t, content: c)
            }
            let rawChildren = (nodeDict["children"] as? [[String: Any]]) ?? []
            let children = parseRawNodes(rawChildren)

            return HierarchicalNode(
                title: title,
                summary: summary,
                blocks: blocks,
                children: children
            )
        }
    }
}

// MARK: - Generation Modes
public enum NotesGenerationMode: String, CaseIterable, Identifiable, Sendable {
    case expandSubtopics = "Expand Subtopics"
    case summarizeAndSplit = "Summarize & Split"
    case custom = "Custom Instruction"

    public var id: String { rawValue }

    public var shortTitle: String {
        switch self {
        case .expandSubtopics: return "Expand"
        case .summarizeAndSplit: return "Split"
        case .custom: return "Custom"
        }
    }

    public var systemIcon: String {
        switch self {
        case .expandSubtopics: return "arrow.turn.right.down"
        case .summarizeAndSplit: return "scissors"
        case .custom: return "text.badge.sparkles"
        }
    }

    public var description: String {
        switch self {
        case .expandSubtopics:
            return "Break down this note into structured downward subtopics and sub-subtopics."
        case .summarizeAndSplit:
            return "Analyze the long text in this note and split it into modular child sub-notes."
        case .custom:
            return "Provide a custom instruction to direct the downward hierarchy generation."
        }
    }
}

// MARK: - Hierarchical Data Models
public struct HierarchicalBlockItem: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var typeString: String
    public var content: String

    public init(id: UUID = UUID(), typeString: String, content: String) {
        self.id = id
        self.typeString = typeString
        var c = content
        if typeString == "bulletList" || typeString == "bullet" {
            if c.hasPrefix("* ") || c.hasPrefix("- ") || c.hasPrefix("• ") {
                c = String(c.dropFirst(2))
            }
        } else if typeString == "taskList" || typeString == "task" {
            if c.hasPrefix("- [ ] ") || c.hasPrefix("[ ] ") {
                if let range = c.range(of: "] ") {
                    c = String(c[range.upperBound...])
                }
            }
        }
        self.content = c
    }

    public var blockType: BlockType {
        switch typeString {
        case "heading1": return .heading1
        case "heading2": return .heading2
        case "heading3": return .heading3
        case "bulletList": return .bulletList
        case "taskList": return .taskList
        case "codeBlock": return .codeBlock
        case "quote": return .quote
        case "callout": return .callout
        default: return .paragraph
        }
    }
}

public struct HierarchicalNode: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var title: String
    public var summary: String
    public var blocks: [HierarchicalBlockItem]
    public var children: [HierarchicalNode]
    public var isSelected: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        summary: String = "",
        blocks: [HierarchicalBlockItem] = [],
        children: [HierarchicalNode] = [],
        isSelected: Bool = true
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.blocks = blocks
        self.children = children
        self.isSelected = isSelected
    }

    enum CodingKeys: String, CodingKey {
        case title
        case summary
        case blocks
        case children
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        self.blocks = try container.decodeIfPresent([HierarchicalBlockItem].self, forKey: .blocks) ?? []
        self.children = try container.decodeIfPresent([HierarchicalNode].self, forKey: .children) ?? []
        self.isSelected = true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(summary, forKey: .summary)
        try container.encode(blocks, forKey: .blocks)
        try container.encode(children, forKey: .children)
    }

    public var totalNodeCount: Int {
        1 + children.reduce(0) { $0 + $1.totalNodeCount }
    }
}

public struct HierarchicalGenerationResult: Codable, Sendable, Equatable {
    public var rootTitle: String
    public var overview: String
    public var items: [HierarchicalNode]

    public init(rootTitle: String, overview: String, items: [HierarchicalNode]) {
        self.rootTitle = rootTitle
        self.overview = overview
        self.items = items
    }
}

public enum HierarchyDestination: String, CaseIterable, Identifiable, Sendable {
    case treeSubNotes = "Tree Sub-Notes"
    case documentBlocks = "Document Blocks"
    case both = "Both (Tree & Blocks)"

    public var id: String { rawValue }

    public var systemIcon: String {
        switch self {
        case .treeSubNotes: return "folder.badge.plus"
        case .documentBlocks: return "text.badge.plus"
        case .both: return "square.stack.3d.down.right"
        }
    }

    public var description: String {
        switch self {
        case .treeSubNotes: return "Create modular child documents in the left tree hierarchy"
        case .documentBlocks: return "Insert outline headings and blocks directly into active document"
        case .both: return "Create both child documents in the tree and insert outline blocks here"
        }
    }
}

