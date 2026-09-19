import SwiftUI
import AppKit

public struct AISettingsSheet: View {
    @ObservedObject public var settings: AISettings = AISettings.shared
    public let onDismiss: () -> Void

    @State private var inputKey: String = ""
    @State private var selectedProvider: AIProvider = .gemini
    @State private var selectedModel: String = "gemini-2.5-flash"
    @State private var isEnabled: Bool = true
    @State private var newCardsOnly: Bool = true

    @State private var isTestingKey: Bool = false
    @State private var testResult: (isValid: Bool, message: String)? = nil
    @State private var isKeyVisible: Bool = false

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
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Socratic Tutor Settings")
                        .font(.system(size: 16, weight: .bold))
                    Text("Configure your personal API key for written active recall & Socratic evaluations")
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

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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
                        Text("AI PROVIDER & API KEY")
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
        .frame(width: 540, height: 600)
        .onAppear {
            inputKey = settings.apiKey
            selectedProvider = settings.provider
            selectedModel = settings.model
            isEnabled = settings.isSocraticEnabled
            newCardsOnly = settings.newCardsOnly
        }
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

    private func saveSettings() {
        settings.apiKey = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.provider = selectedProvider
        settings.model = selectedModel
        settings.isSocraticEnabled = isEnabled
        settings.newCardsOnly = newCardsOnly
    }
}
