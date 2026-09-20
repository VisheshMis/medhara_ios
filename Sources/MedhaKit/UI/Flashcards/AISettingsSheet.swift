import SwiftUI
import AppKit

public enum AISettingsTab: String, CaseIterable, Identifiable {
    case flashcards = "Flashcards AI"
    case notes = "Notes AI"

    public var id: String { rawValue }
    public var icon: String {
        switch self {
        case .flashcards: return "graduationcap.fill"
        case .notes: return "text.badge.sparkles"
        }
    }
}

public struct AISettingsSheet: View {
    @ObservedObject public var settings: AISettings = AISettings.shared
    public let onDismiss: () -> Void

    @State private var selectedTab: AISettingsTab = .flashcards

    // Flashcards AI State
    @State private var inputKey: String = ""
    @State private var localEndpoint: String = "http://localhost:11434/v1"
    @State private var selectedProvider: AIProvider = .gemini
    @State private var selectedModel: String = "gemini-3.6-flash"
    @State private var isEnabled: Bool = true
    @State private var newCardsOnly: Bool = true
    @State private var isTestingKey: Bool = false
    @State private var testResult: (isValid: Bool, message: String)? = nil
    @State private var isKeyVisible: Bool = false
    @State private var discoveredLocalModels: [String] = []
    @State private var isDetectingModels: Bool = false

    // Notes AI State
    @State private var useFlashcardSettingsForNotes: Bool = true
    @State private var notesInputKey: String = ""
    @State private var notesLocalEndpoint: String = "http://localhost:11434/v1"
    @State private var notesSelectedProvider: AIProvider = .gemini
    @State private var notesSelectedModel: String = "gemini-3.6-flash"
    @State private var isTestingNotesKey: Bool = false
    @State private var notesTestResult: (isValid: Bool, message: String)? = nil
    @State private var isNotesKeyVisible: Bool = false
    @State private var discoveredNotesLocalModels: [String] = []
    @State private var isDetectingNotesModels: Bool = false

    // Global Features
    @State private var isWikipediaGroundingEnabled: Bool = true

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: selectedTab == .flashcards ? "graduationcap.fill" : "text.badge.sparkles")
                        .font(.system(size: 18))
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Medha AI Configuration")
                        .font(.system(size: 16, weight: .bold))
                    Text(selectedTab == .flashcards
                         ? "Configure Cloud API key or Local AI (< 4 GB RAM) for Socratic recall"
                         : "Configure downward hierarchical note generation and summarization")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Tab Selector
            Picker("Settings Tab", selection: $selectedTab) {
                ForEach(AISettingsTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if selectedTab == .flashcards {
                        flashcardsAISettingsView
                    } else {
                        notesAISettingsView
                    }

                    // Wikipedia Grounding Section (Shared across both modes)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("FACTUAL KNOWLEDGE GROUNDING")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        Toggle(isOn: $isWikipediaGroundingEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("Free Wikipedia Knowledge Grounding")
                                        .font(.system(size: 13, weight: .medium))
                                    Text("FREE")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Color.green.opacity(0.15))
                                        .foregroundColor(.green)
                                        .cornerRadius(4)
                                }
                                Text("Queries Wikipedia's open REST API for verified factual context without any API key. Drastically boosts 1B–3B Local AI models.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                Button("Cancel", action: onDismiss)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save Settings") {
                    saveSettings()
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 580, height: 680)
        .onAppear {
            // Load Flashcards AI settings
            inputKey = settings.apiKey
            localEndpoint = settings.localEndpoint
            selectedProvider = settings.provider
            selectedModel = settings.model
            isEnabled = settings.isSocraticEnabled
            newCardsOnly = settings.newCardsOnly

            // Load Notes AI settings
            useFlashcardSettingsForNotes = settings.useFlashcardSettingsForNotes
            notesInputKey = settings.notesApiKey
            notesLocalEndpoint = settings.notesLocalEndpoint
            notesSelectedProvider = settings.notesProvider
            notesSelectedModel = settings.notesModel

            // Global settings
            isWikipediaGroundingEnabled = settings.isWikipediaGroundingEnabled

            if selectedProvider == .local {
                Task {
                    await detectLocalModels()
                }
            }
            if notesSelectedProvider == .local {
                Task {
                    await detectNotesLocalModels()
                }
            }
        }
    }

    // MARK: - Flashcards AI Tab
    @ViewBuilder
    private var flashcardsAISettingsView: some View {
        // Feature Toggles Section
        VStack(alignment: .leading, spacing: 12) {
            Text("ACTIVE RECALL PREFERENCES")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            Toggle(isOn: $isEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Socratic AI Written Recall")
                        .font(.system(size: 13, weight: .medium))
                    Text("Prompts for written recall and provides multi-turn Socratic counter-questions")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)

            Toggle(isOn: $newCardsOnly) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("First-Time Cards Only (reps == 0)")
                        .font(.system(size: 13, weight: .medium))
                    Text("Only prompts written answers when learning new cards for the first time")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)
            .disabled(!isEnabled)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)

        // Provider & API Key Section
        VStack(alignment: .leading, spacing: 14) {
            Text("FLASHCARDS AI ENGINE & PROVIDER")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            // Provider Picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Provider")
                    .font(.system(size: 12, weight: .semibold))
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(AIProvider.allCases) { prov in
                        Text(prov.displayName).tag(prov)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedProvider) { _, newProv in
                    selectedModel = newProv.defaultModel
                    testResult = nil
                    if newProv == .local {
                        Task {
                            await detectLocalModels()
                        }
                    }
                }
            }

            // Model Picker
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(selectedProvider == .local ? "Model (Runs Locally)" : "Model")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    if selectedProvider == .local {
                        Button(action: {
                            Task {
                                await detectLocalModels()
                            }
                        }) {
                            HStack(spacing: 3) {
                                if isDetectingModels {
                                    ProgressView()
                                        .controlSize(.mini)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                                Text(isDetectingModels ? "Detecting..." : "Detect Local Models")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.borderless)
                        .disabled(isDetectingModels)
                    }
                }

                let allAvailable = (selectedProvider == .local && !discoveredLocalModels.isEmpty)
                    ? (discoveredLocalModels + selectedProvider.availableModels.filter { !discoveredLocalModels.contains($0) })
                    : selectedProvider.availableModels

                Picker("Model", selection: $selectedModel) {
                    ForEach(allAvailable, id: \.self) { mod in
                        Text(mod).tag(mod)
                    }
                }
                .pickerStyle(.menu)
            }

            if selectedProvider == .local {
                // Local AI Endpoint Input
                VStack(alignment: .leading, spacing: 6) {
                    Text("Local Server Endpoint")
                        .font(.system(size: 12, weight: .semibold))
                    TextField("http://localhost:11434/v1", text: $localEndpoint)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .onChange(of: localEndpoint) { _, _ in
                            testResult = nil
                            Task {
                                await detectLocalModels()
                            }
                        }

                    Text("💡 Compatible with Ollama, LM Studio, or local servers. Run: `ollama run qwen2.5:1.5b`")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            } else {
                // Cloud API Key Input
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("API Key")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        if let url = URL(string: selectedProvider.helpUrlString) {
                            Link(destination: url) {
                                HStack(spacing: 3) {
                                    Text(selectedProvider == .gemini ? "Get Free Gemini Key" : "Get OpenAI Key")
                                    Image(systemName: "arrow.up.right")
                                }
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        if isKeyVisible {
                            TextField("Paste API key here...", text: $inputKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                        } else {
                            SecureField("Paste API key here...", text: $inputKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                        }

                        Button(action: { isKeyVisible.toggle() }) {
                            Image(systemName: isKeyVisible ? "eye.slash" : "eye")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .help(isKeyVisible ? "Hide key" : "Show key")
                    }

                    if selectedProvider == .gemini {
                        Text("💡 Google Gemini offers a generous free tier with zero setup cost.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Test Connection Button & Status
            HStack(spacing: 12) {
                Button(action: testConnection) {
                    HStack(spacing: 6) {
                        if isTestingKey {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: selectedProvider == .local ? "desktopcomputer" : "bolt.fill")
                        }
                        Text(isTestingKey ? "Testing..." : (selectedProvider == .local ? "Test Local Server" : "Test Connection"))
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled((selectedProvider != .local && inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || isTestingKey)

                if let res = testResult {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: res.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(res.isValid ? .green : .red)
                            .padding(.top, 1)
                        Text(res.message)
                            .font(.system(size: 11))
                            .foregroundColor(res.isValid ? .green : .red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)

        // How it works note
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "graduationcap.fill")
                    .foregroundColor(.purple)
                Text("How Socratic Recall Works")
                    .font(.system(size: 12, weight: .bold))
            }

            Text("1. When reviewing a card, type your explanation from memory.\n2. The AI evaluates your understanding (grounded with Wikipedia facts).\n3. If your explanation is incomplete or has a gap, the AI asks a Socratic counter-question.\n4. Once spot-on, the answer unlocks and you rate your recall with FSRS.\n5. You can skip or reveal the answer directly at any time.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineSpacing(3)
        }
        .padding(14)
        .background(Color.purple.opacity(0.06))
        .cornerRadius(8)
    }

    // MARK: - Notes AI Tab
    @ViewBuilder
    private var notesAISettingsView: some View {
        // Shared Settings Toggle
        VStack(alignment: .leading, spacing: 12) {
            Text("NOTES AI CONFIGURATION")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            Toggle(isOn: $useFlashcardSettingsForNotes) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use Flashcards AI Settings (Shared)")
                        .font(.system(size: 13, weight: .medium))
                    Text("Automatically use the same engine, model, and key/endpoint configured for Flashcards")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)

        if useFlashcardSettingsForNotes {
            // Shared info card
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.purple)
                    Text("Inheriting Engine from Flashcards AI")
                        .font(.system(size: 13, weight: .semibold))
                }

                Divider()

                HStack {
                    Text("Provider:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(selectedProvider.displayName)
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                    Text("Model:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(selectedModel)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }

                if selectedProvider == .local {
                    HStack {
                        Text("Endpoint:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(localEndpoint)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.purple)
                    }
                } else {
                    HStack {
                        Text("Key:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        let trimmed = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        Text(trimmed.count > 8 ? "\(trimmed.prefix(4))••••\(trimmed.suffix(4))" : (trimmed.isEmpty ? "Not configured yet" : "••••••••"))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(trimmed.isEmpty ? .orange : .primary)
                    }

                    if inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("⚠️ Flashcards AI does not have an API key set yet. Switch to Flashcards AI tab to enter your key or toggle off shared settings.")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                            .padding(.top, 4)
                    }
                }
            }
            .padding(16)
            .background(Color.purple.opacity(0.06))
            .cornerRadius(10)
        } else {
            // Independent Provider & Settings
            VStack(alignment: .leading, spacing: 14) {
                Text("INDEPENDENT NOTES AI ENGINE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)

                // Provider Picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Provider")
                        .font(.system(size: 12, weight: .semibold))
                    Picker("Provider", selection: $notesSelectedProvider) {
                        ForEach(AIProvider.allCases) { prov in
                            Text(prov.displayName).tag(prov)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: notesSelectedProvider) { _, newProv in
                        notesSelectedModel = newProv.defaultModel
                        notesTestResult = nil
                        if newProv == .local {
                            Task {
                                await detectNotesLocalModels()
                            }
                        }
                    }
                }

                // Model Picker
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(notesSelectedProvider == .local ? "Model (Runs Locally)" : "Model")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        if notesSelectedProvider == .local {
                            Button(action: {
                                Task {
                                    await detectNotesLocalModels()
                                }
                            }) {
                                HStack(spacing: 3) {
                                    if isDetectingNotesModels {
                                        ProgressView()
                                            .controlSize(.mini)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    Text(isDetectingNotesModels ? "Detecting..." : "Detect Local Models")
                                }
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.borderless)
                            .disabled(isDetectingNotesModels)
                        }
                    }

                    let allNotesAvailable = (notesSelectedProvider == .local && !discoveredNotesLocalModels.isEmpty)
                        ? (discoveredNotesLocalModels + notesSelectedProvider.availableModels.filter { !discoveredNotesLocalModels.contains($0) })
                        : notesSelectedProvider.availableModels

                    Picker("Model", selection: $notesSelectedModel) {
                        ForEach(allNotesAvailable, id: \.self) { mod in
                            Text(mod).tag(mod)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if notesSelectedProvider == .local {
                    // Independent Local AI Endpoint Input
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Local Server Endpoint")
                            .font(.system(size: 12, weight: .semibold))
                        TextField("http://localhost:11434/v1", text: $notesLocalEndpoint)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                            .onChange(of: notesLocalEndpoint) { _, _ in
                                notesTestResult = nil
                                Task {
                                    await detectNotesLocalModels()
                                }
                            }

                        Text("💡 E.g. Ollama (`localhost:11434`) or LM Studio. Run: `ollama run qwen2.5:1.5b`")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                } else {
                    // API Key Input
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("API Key")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            if let url = URL(string: notesSelectedProvider.helpUrlString) {
                                Link(destination: url) {
                                    HStack(spacing: 3) {
                                        Text(notesSelectedProvider == .gemini ? "Get Free Gemini Key" : "Get OpenAI Key")
                                        Image(systemName: "arrow.up.right")
                                    }
                                    .font(.system(size: 11))
                                    .foregroundColor(.accentColor)
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            if isNotesKeyVisible {
                                TextField("Paste Notes AI API key here...", text: $notesInputKey)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12, design: .monospaced))
                            } else {
                                SecureField("Paste Notes AI API key here...", text: $notesInputKey)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12, design: .monospaced))
                            }

                            Button(action: { isNotesKeyVisible.toggle() }) {
                                Image(systemName: isNotesKeyVisible ? "eye.slash" : "eye")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                            .help(isNotesKeyVisible ? "Hide key" : "Show key")
                        }
                    }
                }

                // Test Key Button & Status
                HStack(spacing: 12) {
                    Button(action: testNotesConnection) {
                        HStack(spacing: 6) {
                            if isTestingNotesKey {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: notesSelectedProvider == .local ? "desktopcomputer" : "bolt.fill")
                            }
                            Text(isTestingNotesKey ? "Testing..." : (notesSelectedProvider == .local ? "Test Local Server" : "Test Connection"))
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled((notesSelectedProvider != .local && notesInputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || isTestingNotesKey)

                    if let res = notesTestResult {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: res.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(res.isValid ? .green : .red)
                                .padding(.top, 1)
                            Text(res.message)
                                .font(.system(size: 11))
                                .foregroundColor(res.isValid ? .green : .red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }

        // Downward Hierarchy Guarantees card
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.turn.right.down")
                    .foregroundColor(.purple)
                Text("Downward Hierarchy Principle")
                    .font(.system(size: 12, weight: .bold))
            }

            Text("• **Strict Downward Growth**: Notes AI only creates child subtopics under the active document. It never mutates parent documents, ancestor folders, or sibling notes.\n• **Preview & Approval**: You can inspect every generated branch, customize titles, and uncheck subtopics before committing changes to your knowledge graph.\n• **Flexible Destination**: Choose whether to generate modular child documents in your document tree, nested block outlines directly into the active note, or both simultaneously.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineSpacing(3)
        }
        .padding(14)
        .background(Color.purple.opacity(0.06))
        .cornerRadius(8)
    }

    private func detectLocalModels() async {
        guard selectedProvider == .local else { return }
        await MainActor.run { isDetectingModels = true }
        let models = await AISocraticService.shared.fetchLocalModels(endpoint: localEndpoint)
        await MainActor.run {
            isDetectingModels = false
            discoveredLocalModels = models
            if !models.isEmpty && (!models.contains(selectedModel) || selectedModel == AIProvider.local.defaultModel) {
                if let first = models.first {
                    selectedModel = first
                }
            }
        }
    }

    private func detectNotesLocalModels() async {
        guard notesSelectedProvider == .local else { return }
        await MainActor.run { isDetectingNotesModels = true }
        let models = await AISocraticService.shared.fetchLocalModels(endpoint: notesLocalEndpoint)
        await MainActor.run {
            isDetectingNotesModels = false
            discoveredNotesLocalModels = models
            if !models.isEmpty && (!models.contains(notesSelectedModel) || notesSelectedModel == AIProvider.local.defaultModel) {
                if let first = models.first {
                    notesSelectedModel = first
                }
            }
        }
    }

    private func testConnection() {
        isTestingKey = true
        testResult = nil

        let keyToTest = selectedProvider == .local ? localEndpoint : inputKey

        Task {
            let res = await AISocraticService.shared.validateAPIKey(
                key: keyToTest,
                provider: selectedProvider,
                model: selectedModel
            )
            await MainActor.run {
                isTestingKey = false
                testResult = res
            }
            if selectedProvider == .local {
                await detectLocalModels()
            }
        }
    }

    private func testNotesConnection() {
        isTestingNotesKey = true
        notesTestResult = nil

        let keyToTest = notesSelectedProvider == .local ? notesLocalEndpoint : notesInputKey

        Task {
            let res = await AISocraticService.shared.validateAPIKey(
                key: keyToTest,
                provider: notesSelectedProvider,
                model: notesSelectedModel
            )
            await MainActor.run {
                isTestingNotesKey = false
                notesTestResult = res
            }
            if notesSelectedProvider == .local {
                await detectNotesLocalModels()
            }
        }
    }

    private func saveSettings() {
        settings.apiKey = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.localEndpoint = localEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.provider = selectedProvider
        settings.model = selectedModel
        settings.isSocraticEnabled = isEnabled
        settings.newCardsOnly = newCardsOnly

        settings.useFlashcardSettingsForNotes = useFlashcardSettingsForNotes
        settings.notesApiKey = notesInputKey.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.notesLocalEndpoint = notesLocalEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.notesProvider = notesSelectedProvider
        settings.notesModel = notesSelectedModel

        settings.isWikipediaGroundingEnabled = isWikipediaGroundingEnabled
    }
}


