import Foundation
import Combine

// MARK: - AI Provider
public enum AIProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    case gemini = "gemini"
    case openai = "openai"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .gemini: return "Google Gemini"
        case .openai: return "OpenAI"
        }
    }

    public var defaultModel: String {
        switch self {
        case .gemini: return "gemini-2.5-flash"
        case .openai: return "gpt-4o-mini"
        }
    }

    public var availableModels: [String] {
        switch self {
        case .gemini:
            return ["gemini-2.5-flash", "gemini-1.5-flash", "gemini-1.5-pro"]
        case .openai:
            return ["gpt-4o-mini", "gpt-4o", "gpt-3.5-turbo"]
        }
    }

    public var helpUrlString: String {
        switch self {
        case .gemini: return "https://aistudio.google.com/app/apikey"
        case .openai: return "https://platform.openai.com/api-keys"
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

    public init() {
        let savedKey = UserDefaults.standard.string(forKey: keyApiKey) ?? ""
        let savedProviderRaw = UserDefaults.standard.string(forKey: keyProvider) ?? AIProvider.gemini.rawValue
        let prov = AIProvider(rawValue: savedProviderRaw) ?? .gemini
        let savedModel = UserDefaults.standard.string(forKey: keyModel) ?? prov.defaultModel
        let isEnabled = UserDefaults.standard.object(forKey: keySocraticEnabled) != nil
            ? UserDefaults.standard.bool(forKey: keySocraticEnabled)
            : true
        let newOnly = UserDefaults.standard.object(forKey: keyNewCardsOnly) != nil
            ? UserDefaults.standard.bool(forKey: keyNewCardsOnly)
            : true

        self.apiKey = savedKey
        self.provider = prov
        self.model = savedModel
        self.isSocraticEnabled = isEnabled
        self.newCardsOnly = newOnly
    }

    public var hasAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var maskedKey: String {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
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

        switch settings.provider {
        case .gemini:
            return try await evaluateWithGemini(
                apiKey: settings.apiKey,
                model: settings.model,
                question: question,
                targetAnswer: targetAnswer,
                hint: hint,
                userAnswer: userAnswer,
                dialogueHistory: dialogueHistory
            )
        case .openai:
            return try await evaluateWithOpenAI(
                apiKey: settings.apiKey,
                model: settings.model,
                question: question,
                targetAnswer: targetAnswer,
                hint: hint,
                userAnswer: userAnswer,
                dialogueHistory: dialogueHistory
            )
        }
    }

    /// Validates the given API key with a test ping
    public func validateAPIKey(
        key: String,
        provider: AIProvider,
        model: String
    ) async -> (isValid: Bool, message: String) {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            return (false, "API key cannot be empty.")
        }

        do {
            switch provider {
            case .gemini:
                let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(cleanKey)"
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
                    return (true, "Key verified successfully!")
                } else {
                    let bodyString = String(data: data, encoding: .utf8) ?? ""
                    return (false, "Gemini error (\(httpResponse.statusCode)): \(bodyString.prefix(120))")
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
            }
        } catch {
            return (false, error.localizedDescription)
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
            throw ServiceError.invalidResponse("Gemini API Error: \(errText)")
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

    // MARK: - Private API Implementation (OpenAI)
    private func evaluateWithOpenAI(
        apiKey: String,
        model: String,
        question: String,
        targetAnswer: String,
        hint: String?,
        userAnswer: String,
        dialogueHistory: [AISocraticTurn]
    ) async throws -> AISocraticEvaluation {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw ServiceError.invalidResponse("Invalid OpenAI URL")
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

        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "response_format": ["type": "json_object"],
            "temperature": 0.3
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse("No HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            let errText = String(data: data, encoding: .utf8) ?? "Status \(httpResponse.statusCode)"
            throw ServiceError.invalidResponse("OpenAI API Error: \(errText)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let rawText = message["content"] as? String else {
            throw ServiceError.parsingError("Malformed OpenAI JSON payload structure.")
        }

        return try parseEvaluationJSON(rawText: rawText)
    }

    /// Parses raw JSON text into an AISocraticEvaluation object
    public func parseEvaluationJSON(rawText: String) throws -> AISocraticEvaluation {
        // Strip markdown code fences if LLM wrapped it in ```json ... ```
        var clean = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("```json") {
            clean = String(clean.dropFirst(7))
        } else if clean.hasPrefix("```") {
            clean = String(clean.dropFirst(3))
        }
        if clean.hasSuffix("```") {
            clean = String(clean.dropLast(3))
        }
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)

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
}
