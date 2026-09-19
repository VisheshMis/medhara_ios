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
    @State private var selectedProvider: AIProvider = .gemini
    @State private var selectedModel: String = "gemini-3.6-flash"
    @State private var isEnabled: Bool = true
    @State private var newCardsOnly: Bool = true
    @State private var isTestingKey: Bool = false
    @State private var testResult: (isValid: Bool, message: String)? = nil
    @State private var isKeyVisible: Bool = false

    // Notes AI State
    @State private var useFlashcardSettingsForNotes: Bool = true
    @State private var notesInputKey: String = ""
    @State private var notesSelectedProvider: AIProvider = .gemini
    @State private var notesSelectedModel: String = "gemini-3.6-flash"
    @State private var isTestingNotesKey: Bool = false
    @State private var notesTestResult: (isValid: Bool, message: String)? = nil
    @State private var isNotesKeyVisible: Bool = false

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
                         ? "Configure personal API key for Socratic active recall"
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
        .frame(width: 560, height: 640)
        .onAppear {
            // Load Flashcards AI settings
            inputKey = settings.apiKey
            selectedProvider = settings.provider
            selectedModel = settings.model
            isEnabled = settings.isSocraticEnabled
            newCardsOnly = settings.newCardsOnly

            // Load Notes AI settings
            useFlashcardSettingsForNotes = settings.useFlashcardSettingsForNotes
            notesInputKey = settings.notesApiKey
            notesSelectedProvider = settings.notesProvider
            notesSelectedModel = settings.notesModel
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
            Text("FLASHCARDS AI PROVIDER & API KEY")
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
                }
            }

            // Model Picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Model")
                    .font(.system(size: 12, weight: .semibold))
                Picker("Model", selection: $selectedModel) {
                    ForEach(selectedProvider.availableModels, id: \.self) { mod in
                        Text(mod).tag(mod)
                    }
                }
                .pickerStyle(.menu)
            }

            // API Key Input
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

            // Test Key Button & Status
            HStack(spacing: 12) {
                Button(action: testConnection) {
                    HStack(spacing: 6) {
                        if isTestingKey {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "bolt.fill")
                        }
                        Text(isTestingKey ? "Testing..." : "Test Connection")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTestingKey)

                if let res = testResult {
                    HStack(spacing: 4) {
                        Image(systemName: res.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(res.isValid ? .green : .red)
                        Text(res.message)
                            .font(.system(size: 11))
                            .foregroundColor(res.isValid ? .green : .red)
                            .lineLimit(1)
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

            Text("1. When reviewing a card, type your explanation from memory.\n2. The AI evaluates your understanding.\n3. If your explanation is incomplete or has a gap, the AI asks a Socratic counter-question to guide you.\n4. Once your understanding is spot-on, the card answer unlocks and you can rate your recall with FSRS.\n5. You can skip or reveal the answer directly at any time.")
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
                    Text("Use Flashcards AI Settings (Shared Key)")
                        .font(.system(size: 13, weight: .medium))
                    Text("Automatically use the same provider, model, and API key configured for Flashcards")
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
                    Text("Inheriting Settings from Flashcards AI")
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
                    Text("⚠️ Flashcards AI does not have an API key set yet. Switch to the Flashcards AI tab to enter your key or toggle off shared settings to use an independent key.")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                }
            }
            .padding(16)
            .background(Color.purple.opacity(0.06))
            .cornerRadius(10)
        } else {
            // Independent Provider & API Key
            VStack(alignment: .leading, spacing: 14) {
                Text("INDEPENDENT NOTES AI PROVIDER & API KEY")
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
                    }
                }

                // Model Picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Model")
                        .font(.system(size: 12, weight: .semibold))
                    Picker("Model", selection: $notesSelectedModel) {
                        ForEach(notesSelectedProvider.availableModels, id: \.self) { mod in
                            Text(mod).tag(mod)
                        }
                    }
                    .pickerStyle(.menu)
                }

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

                // Test Key Button & Status
                HStack(spacing: 12) {
                    Button(action: testNotesConnection) {
                        HStack(spacing: 6) {
                            if isTestingNotesKey {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "bolt.fill")
                            }
                            Text(isTestingNotesKey ? "Testing..." : "Test Connection")
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(notesInputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTestingNotesKey)

                    if let res = notesTestResult {
                        HStack(spacing: 4) {
                            Image(systemName: res.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(res.isValid ? .green : .red)
                            Text(res.message)
                                .font(.system(size: 11))
                                .foregroundColor(res.isValid ? .green : .red)
                                .lineLimit(1)
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

    private func testConnection() {
        isTestingKey = true
        testResult = nil

        Task {
            let res = await AISocraticService.shared.validateAPIKey(
                key: inputKey,
                provider: selectedProvider,
                model: selectedModel
            )
            await MainActor.run {
                isTestingKey = false
                testResult = res
            }
        }
    }

    private func testNotesConnection() {
        isTestingNotesKey = true
        notesTestResult = nil

        Task {
            let res = await AISocraticService.shared.validateAPIKey(
                key: notesInputKey,
                provider: notesSelectedProvider,
                model: notesSelectedModel
            )
            await MainActor.run {
                isTestingNotesKey = false
                notesTestResult = res
            }
        }
    }

    private func saveSettings() {
        settings.apiKey = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.provider = selectedProvider
        settings.model = selectedModel
        settings.isSocraticEnabled = isEnabled
        settings.newCardsOnly = newCardsOnly

        settings.useFlashcardSettingsForNotes = useFlashcardSettingsForNotes
        settings.notesApiKey = notesInputKey.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.notesProvider = notesSelectedProvider
        settings.notesModel = notesSelectedModel
    }
}

