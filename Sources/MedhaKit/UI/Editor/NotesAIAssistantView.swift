import SwiftUI
import AppKit

public struct NotesAIAssistantView: View {
    @ObservedObject public var store: BlockStore
    @ObservedObject public var settings: AISettings = AISettings.shared

    @State private var selectedMode: NotesGenerationMode = .expandSubtopics
    @State private var selectedDestination: HierarchyDestination = .both
    @State private var customPrompt: String = ""
    @State private var activeStudySources: [StudyGroundingSource] = AISettings.shared.enabledStudySources

    @State private var isGenerating: Bool = false
    @State private var errorMessage: String? = nil

    @State private var generatedResult: HierarchicalGenerationResult? = nil
    @State private var isApprovalSheetPresented: Bool = false
    @State private var isSettingsSheetPresented: Bool = false

    public init(store: BlockStore) {
        self.store = store
    }

    private var currentNoteTitle: String {
        store.currentDoc?.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? store.currentDoc!.content
            : "Untitled Note"
    }

    private var currentNoteWordCount: Int {
        let text = store.blocks.map { $0.content }.joined(separator: " ")
        return text.split { $0.isWhitespace || $0.isNewline }.count
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.purple)

                Text("Notes AI Assistant")
                    .font(.system(size: 13, weight: .bold))

                Spacer()

                Button(action: { isSettingsSheetPresented = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Notes AI Settings")

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.isNotesAIAssistantPresented = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close AI Assistant")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Active Note Context Card
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "doc.text")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                            Text("ACTIVE ROOT DOCUMENT")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            HStack(spacing: 3) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 9))
                                Text("Downward Only")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundColor(.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(4)
                        }

                        Text(currentNoteTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(2)

                        HStack(spacing: 12) {
                            Text("\(store.blocks.count) blocks")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("\(currentNoteWordCount) words")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        // Engine & Knowledge Badges
                        HStack(spacing: 6) {
                            HStack(spacing: 3) {
                                Image(systemName: settings.activeNotesProvider == .local ? "cpu" : "cloud.fill")
                                    .font(.system(size: 9))
                                Text(settings.activeNotesProvider == .local ? "Local AI (\(settings.activeNotesModel))" : settings.activeNotesProvider.displayName)
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundColor(settings.activeNotesProvider == .local ? .green : .blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background((settings.activeNotesProvider == .local ? Color.green : Color.blue).opacity(0.1))
                            .cornerRadius(4)

                            if !activeStudySources.isEmpty {
                                HStack(spacing: 3) {
                                    Image(systemName: "books.vertical.fill")
                                        .font(.system(size: 9))
                                    Text("\(activeStudySources.count) Grounded Source\(activeStudySources.count == 1 ? "" : "s")")
                                        .font(.system(size: 9, weight: .medium))
                                }
                                .foregroundColor(.teal)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.teal.opacity(0.1))
                                .cornerRadius(4)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                    // Generation Mode Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GENERATION MODE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        Picker("Mode", selection: $selectedMode) {
                            ForEach(NotesGenerationMode.allCases) { mode in
                                Text(mode.shortTitle).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        HStack(alignment: .top, spacing: 4) {
                            Text(selectedMode.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                            Text("—")
                                .foregroundColor(.secondary)
                            Text(selectedMode.description)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // Custom Instruction input
                    if selectedMode == .custom {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CUSTOM INSTRUCTION")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)

                            TextEditor(text: $customPrompt)
                                .font(.system(size: 12))
                                .frame(height: 70)
                                .padding(4)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }

                    // Target Output Destination Picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TARGET DESTINATION")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        Picker("", selection: $selectedDestination) {
                            ForEach(HierarchyDestination.allCases) { dest in
                                Text("\(dest.systemIcon == "folder.badge.plus" ? "📁 " : (dest.systemIcon == "list.bullet.indent" ? "📝 " : "📑 "))\(dest.rawValue)")
                                    .tag(dest)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(selectedDestination.description)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    // Study Grounding Sources Selection
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "books.vertical.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.purple)
                                Text("STUDY KNOWLEDGE SOURCES")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(activeStudySources.count) active")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                        }

                        // Quick Presets Bar
                        HStack(spacing: 4) {
                            Button("All") {
                                activeStudySources = StudyGroundingSource.allCases
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.purple)

                            Text("•").foregroundColor(.secondary).font(.system(size: 9))

                            Button("STEM") {
                                activeStudySources = [.wikipedia, .openAlex]
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.purple)

                            Text("•").foregroundColor(.secondary).font(.system(size: 9))

                            Button("BioMed") {
                                activeStudySources = [.wikipedia, .europePMC]
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.purple)

                            Text("•").foregroundColor(.secondary).font(.system(size: 9))

                            Button("None") {
                                activeStudySources = []
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        }

                        // Source toggle cards
                        VStack(spacing: 5) {
                            ForEach(StudyGroundingSource.allCases) { source in
                                let isSelected = activeStudySources.contains(source)
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        if let idx = activeStudySources.firstIndex(of: source) {
                                            activeStudySources.remove(at: idx)
                                        } else {
                                            activeStudySources.append(source)
                                        }
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 12))
                                            .foregroundColor(isSelected ? .purple : .secondary.opacity(0.6))

                                        Image(systemName: source.systemIcon)
                                            .font(.system(size: 11))
                                            .foregroundColor(isSelected ? .primary : .secondary)
                                            .frame(width: 14)

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(source.displayName)
                                                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                                                .foregroundColor(isSelected ? .primary : .secondary)

                                            Text(source.subtitle)
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }

                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isSelected ? Color.purple.opacity(0.08) : Color(NSColor.textBackgroundColor).opacity(0.4))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(isSelected ? Color.purple.opacity(0.3) : Color.secondary.opacity(0.12), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                    // API Key Status Alert if missing
                    if !settings.hasNotesAPIKey {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("API Key Required")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            Text("Configure your Gemini or OpenAI API key to generate downward notes.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)

                            Button("Open AI Settings") {
                                isSettingsSheetPresented = true
                            }
                            .font(.system(size: 11, weight: .medium))
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }

                    // Error Message
                    if let err = errorMessage {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.octagon.fill")
                                    .foregroundColor(.red)
                                Text("Generation Error")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.red)
                            }
                            Text(err)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .padding(10)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(8)
                    }

                    // Generate Button
                    Button(action: generateHierarchy) {
                        HStack(spacing: 6) {
                            if isGenerating {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Architecting Hierarchy...")
                            } else {
                                Image(systemName: "sparkles")
                                Text("Generate Downward Notes")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(isGenerating || !settings.hasNotesAPIKey || store.currentDoc == nil)

                    // Explanation Card
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                                .font(.system(size: 11))
                            Text("About Downward Hierarchy")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                        }

                        Text("Every generated branch is strictly parented under this note. You can preview, edit titles, and select which nodes to keep before committing.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(8)
                }
                .padding(14)
            }
        }
        .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $isApprovalSheetPresented) {
            if let res = generatedResult, let currentDoc = store.currentDoc {
                HierarchicalApprovalSheet(
                    store: store,
                    initialResult: res,
                    rootDoc: currentDoc,
                    initialDestination: selectedDestination,
                    onDismiss: { isApprovalSheetPresented = false }
                )
            }
        }
        .sheet(isPresented: $isSettingsSheetPresented) {
            AISettingsSheet(onDismiss: { isSettingsSheetPresented = false })
        }
    }

    private func generateHierarchy() {
        guard let currentDoc = store.currentDoc else { return }
        isGenerating = true
        errorMessage = nil

        let title = currentDoc.content
        let content = store.blocks.map { block -> String in
            let prefix = block.type == .bulletList ? "- " : (block.type == .heading1 ? "# " : (block.type == .heading2 ? "## " : ""))
            return "\(prefix)\(block.content)"
        }.joined(separator: "\n")

        Task {
            do {
                let result = try await AISocraticService.shared.generateDownwardHierarchy(
                    currentNoteTitle: title,
                    currentNoteContent: content,
                    mode: selectedMode,
                    customInstruction: customPrompt.isEmpty ? nil : customPrompt,
                    selectedSources: activeStudySources
                )

                await MainActor.run {
                    self.isGenerating = false
                    self.generatedResult = result
                    self.isApprovalSheetPresented = true
                }
            } catch {
                await MainActor.run {
                    self.isGenerating = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Hierarchical Approval Sheet
public struct HierarchicalApprovalSheet: View {
    @ObservedObject public var store: BlockStore
    public let rootDoc: Block
    public let onDismiss: () -> Void

    @State private var items: [HierarchicalNode]
    @State private var overview: String
    @State private var destination: HierarchyDestination

    public init(
        store: BlockStore,
        initialResult: HierarchicalGenerationResult,
        rootDoc: Block,
        initialDestination: HierarchyDestination,
        onDismiss: @escaping () -> Void
    ) {
        self.store = store
        self.rootDoc = rootDoc
        self.onDismiss = onDismiss
        _items = State(initialValue: initialResult.items)
        _overview = State(initialValue: initialResult.overview)
        _destination = State(initialValue: initialDestination)
    }

    private var totalSelectedCount: Int {
        func countNodes(_ nodes: [HierarchicalNode]) -> Int {
            nodes.reduce(0) { acc, node in
                acc + (node.isSelected ? 1 : 0) + countNodes(node.children)
            }
        }
        return countNodes(items)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Review Downward Note Hierarchy")
                        .font(.system(size: 16, weight: .bold))
                    Text("Root Note: \(rootDoc.content) (Strict Downward Addition)")
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

            // Overview & Destination Control Bar
            VStack(alignment: .leading, spacing: 10) {
                if !overview.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                            .font(.system(size: 12))
                        Text(overview)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.06))
                    .cornerRadius(8)
                }

                HStack {
                    HStack(spacing: 6) {
                        Text("Destination:")
                            .font(.system(size: 12, weight: .semibold))
                        Picker("Destination", selection: $destination) {
                            ForEach(HierarchyDestination.allCases) { dest in
                                Text(dest.rawValue).tag(dest)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Spacer()

                    Button("Select All") {
                        setAllNodesSelection(to: true)
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)

                    Text("•").foregroundColor(.secondary)

                    Button("Deselect All") {
                        setAllNodesSelection(to: false)
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))

            Divider()

            // Tree Preview
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach($items) { $node in
                        HierarchicalNodeRowView(node: $node, level: 0)
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

                Text("\(totalSelectedCount) subtopics selected")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Button(action: commitChanges) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.square.on.square")
                        Text("Commit (\(totalSelectedCount)) to Notes")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(totalSelectedCount == 0)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 640, height: 600)
    }

    private func setAllNodesSelection(to selected: Bool) {
        func setSelection(_ nodes: inout [HierarchicalNode]) {
            for i in 0..<nodes.count {
                nodes[i].isSelected = selected
                setSelection(&nodes[i].children)
            }
        }
        setSelection(&items)
    }

    private func commitChanges() {
        let result = HierarchicalGenerationResult(
            rootTitle: rootDoc.content,
            overview: overview,
            items: items
        )
        store.commitHierarchicalNotes(rootDocId: rootDoc.id, result: result, destination: destination)
        onDismiss()
    }
}

// MARK: - Node Row View
public struct HierarchicalNodeRowView: View {
    @Binding public var node: HierarchicalNode
    public let level: Int

    @State private var isExpanded: Bool = true

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // Indentation
                if level > 0 {
                    HStack(spacing: 4) {
                        ForEach(0..<level, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 1.5, height: 22)
                                .padding(.horizontal, 6)
                        }
                    }
                }

                // Checkbox
                Toggle("", isOn: $node.isSelected)
                    .toggleStyle(.checkbox)
                    .labelsHidden()

                // Disclosure toggle if has children
                if !node.children.isEmpty {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .frame(width: 14)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 14)
                }

                // Node Type Icon
                Image(systemName: level == 0 ? "folder.fill" : "doc.text")
                    .font(.system(size: 12))
                    .foregroundColor(level == 0 ? .orange : .accentColor)

                // Editable Title
                TextField("Subtopic Title", text: $node.title)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, weight: .semibold))

                if !node.blocks.isEmpty {
                    Text("\(node.blocks.count) blocks")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            // Summary preview
            if !node.summary.isEmpty && node.isSelected {
                HStack(spacing: 6) {
                    if level > 0 {
                        Spacer().frame(width: CGFloat(level) * 16 + 28)
                    } else {
                        Spacer().frame(width: 44)
                    }
                    Text(node.summary)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            // Children recursion
            if isExpanded && !node.children.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach($node.children) { $child in
                        HierarchicalNodeRowView(node: $child, level: level + 1)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}
