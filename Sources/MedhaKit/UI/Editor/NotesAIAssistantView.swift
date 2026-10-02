import SwiftUI
import AppKit

public struct NotesAIAssistantView: View {
    @ObservedObject public var store: BlockStore
    @ObservedObject public var settings: AISettings = AISettings.shared
    @ObservedObject public var masterPlan: MasterPlanService = MasterPlanService.shared
    @ObservedObject public var autoNote: AutoNotePipelineService = AutoNotePipelineService.shared

    @State private var selectedMode: NotesGenerationMode = .autoNotePipeline
    @State private var selectedDestination: HierarchyDestination = .both
    @State private var customPrompt: String = ""
    @State private var activeStudySources: [StudyGroundingSource] = AISettings.shared.enabledStudySources

    // Auto-Note Pipeline States
    @State private var clarificationInputText: String = ""
    @State private var customChildDraftTitle: String = ""
    @State private var customChildDraftScope: String = ""
    @State private var isAddNodeExpanded: Bool = false
    @State private var selectedParentForNewNode: String? = nil

    // Master Plan Topic Refinement
    @State private var selectedArchetype: MasterPlanDepthArchetype = .academicMonograph
    @State private var directionFocusPrompt: String = ""
    @State private var newChapterDraftTitle: String = ""

    // Domain & Research
    @State private var selectedSubjectDomain: StudySubjectDomain = .all
    @State private var detectedDomain: StudySubjectDomain = .all
    @State private var researchQuery: String = ""
    @State private var isSearchingResearch: Bool = false
    @State private var researchSnippets: [StudySnippet] = []
    @State private var isResearchDrawerExpanded: Bool = true
    @State private var isSourcesExpanded: Bool = false
    @State private var lastActionFeedback: String? = nil

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
            headerView
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    activeContextCard
                    modeSelectionSection

                    if selectedMode == .autoNotePipeline {
                        autoNotePipelineSection
                    } else if selectedMode == .deepMasterPlan {
                        if masterPlan.isRunning {
                            masterPlanProgressSection
                        } else if masterPlan.activeSyllabus != nil {
                            syllabusPreviewSection
                        } else {
                            deepMasterPlanConfigSection
                        }
                    } else if selectedMode == .custom {
                        customInstructionSection
                    }

                    if selectedMode != .deepMasterPlan && selectedMode != .autoNotePipeline {
                        destinationSection
                    }

                    sourcesAndResearchDisclosure

                    if let err = errorMessage {
                        errorSection(err)
                    }
                }
                .padding(14)
            }

            Divider()
            bottomStickyCTA
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
        .onAppear {
            updateDomainDetection()
        }
        .onChange(of: store.selectedDocId) { _, _ in
            updateDomainDetection()
        }
        .onChange(of: masterPlan.activeState) { _, newState in
            if case .completed = newState {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        store.isNotesAIAssistantPresented = false
                    }
                    masterPlan.resetToIdle()
                }
            }
        }
    }

    // MARK: - Subviews
    @ViewBuilder
    private var headerView: some View {
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
    }

    @ViewBuilder
    private func miniStep(number: String, label: String, active: Bool) -> some View {
        HStack(spacing: 4) {
            Text(number)
                .font(.system(size: 8.5, weight: .bold))
                .frame(width: 15, height: 15)
                .background(active ? Color.purple : Color.secondary.opacity(0.18))
                .foregroundColor(active ? .white : .secondary)
                .clipShape(Circle())
            Text(label)
                .font(.system(size: 10, weight: active ? .semibold : .regular))
                .foregroundColor(active ? .primary : .secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(active ? Color.purple.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }

    @ViewBuilder
    private var activeContextCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.purple)
                Text("CURRENT ROOT NOTE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("Downward Note")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(4)
            }

            Text(currentNoteTitle)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(2)

            HStack(spacing: 8) {
                Text("\(store.blocks.count) blocks • \(currentNoteWordCount) words")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: settings.activeNotesProvider == .local ? "cpu" : "cloud.fill")
                        .font(.system(size: 8.5))
                    Text(settings.activeNotesProvider == .local ? "Local" : settings.activeNotesProvider.displayName)
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(settings.activeNotesProvider == .local ? .green : .blue)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background((settings.activeNotesProvider == .local ? Color.green : Color.blue).opacity(0.1))
                .cornerRadius(4)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var modeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("PIPELINE MODE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)

                Spacer()

                Picker("", selection: $selectedMode) {
                    ForEach(NotesGenerationMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.systemIcon).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 190)
            }

            Text(selectedMode.description)
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var deepMasterPlanConfigSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.purple)
                Text("MASTER PLAN RIGOR & DEPTH")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
            }

            Picker("Archetype", selection: $selectedArchetype) {
                ForEach(MasterPlanDepthArchetype.allCases) { arch in
                    Label(arch.shortTitle, systemImage: arch.systemIcon).tag(arch)
                }
            }
            .pickerStyle(.menu)

            Text(selectedArchetype.subtitle)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                Text("TARGET FOCUS / DIRECTION (OPTIONAL)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)

                TextField("e.g. Focus on JLPT N4 particles, or LSM compaction algorithms", text: $directionFocusPrompt)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
            }
        }
        .padding(10)
        .background(Color.purple.opacity(0.06))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var syllabusPreviewSection: some View {
        if let syllabus = masterPlan.activeSyllabus {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "list.bullet.rectangle.portrait.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.purple)
                        Text("PROPOSED MASTER SYLLABUS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.purple)
                    }
                    Spacer()
                    Button("Reset / Re-fetch", action: { masterPlan.resetToIdle() })
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Text(syllabus.curriculumTitle)
                    .font(.system(size: 12, weight: .bold))

                if !syllabus.authenticSources.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                            .font(.system(size: 9))
                            .foregroundColor(.teal)
                        Text("Grounded in \(syllabus.authenticSources.count) Encyclopedic Topics")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.teal)
                    }
                }

                Text("Review and edit chapters below before deep synthesis starts:")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                VStack(spacing: 6) {
                    ForEach(Array(syllabus.chapters.enumerated()), id: \.element.id) { idx, chapter in
                        HStack(spacing: 6) {
                            Text("\(idx + 1)")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 18, height: 18)
                                .background(Color.purple.opacity(0.12))
                                .foregroundColor(.purple)
                                .cornerRadius(4)

                            TextField("Chapter Title", text: Binding(
                                get: { chapter.title },
                                set: { masterPlan.updateChapterTitle(at: idx, newTitle: $0) }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))

                            Button(action: { masterPlan.removeChapter(at: idx) }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Remove chapter")
                        }
                    }
                }

                HStack(spacing: 6) {
                    TextField("Add custom chapter topic...", text: $newChapterDraftTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                        .onSubmit {
                            if !newChapterDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                masterPlan.addChapter(title: newChapterDraftTitle)
                                newChapterDraftTitle = ""
                            }
                        }

                    Button(action: {
                        if !newChapterDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            masterPlan.addChapter(title: newChapterDraftTitle)
                            newChapterDraftTitle = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.purple)
                    }
                    .buttonStyle(.plain)
                    .disabled(newChapterDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(10)
            .background(Color.purple.opacity(0.06))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.purple.opacity(0.25), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var masterPlanProgressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text("MASTER PLAN SYNTHESIS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.purple)

                Spacer()

                Button("Stop & Keep", action: { masterPlan.cancel() })
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(.red)
            }

            Text(masterPlan.activeState.statusDescription)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)

            if let syllabus = masterPlan.activeSyllabus {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(syllabus.chapters.enumerated()), id: \.element.id) { idx, ch in
                        let isDone = idx < masterPlan.completedChaptersCount
                        let isCurrent = idx == masterPlan.completedChaptersCount && masterPlan.isRunning

                        HStack(spacing: 6) {
                            if isDone {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 11))
                            } else if isCurrent {
                                ProgressView()
                                    .controlSize(.mini)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary.opacity(0.5))
                                    .font(.system(size: 11))
                            }

                            Text("Ch. \(idx + 1): \(ch.title)")
                                .font(.system(size: 10, weight: isCurrent ? .bold : .regular))
                                .foregroundColor(isDone ? .primary : (isCurrent ? .purple : .secondary))
                                .lineLimit(1)

                            Spacer()
                        }
                    }
                }
                .padding(8)
                .background(Color(NSColor.textBackgroundColor).opacity(0.6))
                .cornerRadius(6)
            }
        }
        .padding(10)
        .background(Color.purple.opacity(0.08))
        .cornerRadius(8)
    }

    // MARK: - Auto-Note Pipeline Sections
    @ViewBuilder
    private var autoNotePipelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if autoNote.isRunning {
                autoNoteProgressSection
            } else if case .clarificationNeeded(let question) = autoNote.phase {
                autoNoteClarificationSection(question: question)
            } else if autoNote.phase.isApprovalPending {
                autoNoteApprovalSection
            } else if case .completed(let report) = autoNote.phase {
                autoNoteReportSection(report: report)
            } else if case .error(let msg) = autoNote.phase {
                autoNoteErrorSection(msg: msg)
            } else if case .cancelled = autoNote.phase, autoNote.tree.count > 0 {
                autoNoteCancelledSection
            } else {
                autoNoteConfigSection
            }
        }
    }

    @ViewBuilder
    private var autoNoteConfigSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                        .foregroundColor(.purple)
                        .font(.system(size: 11))
                    Text("Auto-Note Engine")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("Depth: \(autoNote.config.max_depth)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("•")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Max: \(autoNote.config.max_children)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            // Stepper pills
            HStack(spacing: 4) {
                miniStep(number: "1", label: "Plan", active: true)
                Image(systemName: "chevron.right")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.4))
                miniStep(number: "2", label: "Review", active: false)
                Image(systemName: "chevron.right")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.4))
                miniStep(number: "3", label: "Fill", active: false)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("FOCUS / DIRECTION (OPTIONAL)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)

                TextField("e.g. Focus on modern mechanisms, comparative tables and benchmarks", text: $directionFocusPrompt)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
            }
        }
        .padding(10)
        .background(Color.purple.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func autoNoteClarificationSection(question: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.orange)
                Text("AMBIGUOUS TOPIC CLARIFICATION")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.orange)
            }

            Text(question)
                .font(.system(size: 11))
                .foregroundColor(.primary)

            TextField("Specify intended meaning / context...", text: $clarificationInputText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))

            HStack {
                Button("Resume Grounding") {
                    let answer = clarificationInputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !answer.isEmpty, let doc = store.currentDoc else { return }
                    autoNote.startPipeline(
                        rootTitle: currentNoteTitle,
                        userContext: answer,
                        rootDocId: doc.id,
                        store: store
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.small)
                .disabled(clarificationInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
                Button("Cancel") { autoNote.reset() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.25), lineWidth: 1))
    }

    @ViewBuilder
    private var autoNoteApprovalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header & Grounding Summary
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.purple)
                        .font(.system(size: 11))
                    Text("PAUSE: REVIEW SKELETON")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.purple)
                }
                Spacer()
                Button("Reset / Re-plan", action: { autoNote.reset() })
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            if let g = autoNote.groundingRecord {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Root: \(g.root_title) — \(g.chosen_sense)")
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(2)

                    HStack(spacing: 4) {
                        if let qid = g.qid {
                            Text("QID: \(qid)")
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.teal.opacity(0.15))
                                .cornerRadius(3)
                        }
                        Text(g.domain.uppercased())
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.purple.opacity(0.12))
                            .cornerRadius(3)
                        Text(g.entity_type)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .background(Color(NSColor.textBackgroundColor).opacity(0.6))
                .cornerRadius(6)
            }

            // Step 1: Immediate Commit to Notes Tree
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "folder.badge.plus")
                        .foregroundColor(.purple)
                        .font(.system(size: 12, weight: .bold))
                    Text("Step 1: Commit Skeleton to Notes Tree")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.purple)
                    Spacer()
                }

                Text("Save all \(autoNote.tree.count) skeletal notes immediately into your sidebar notes tree. Then fill each note individually on-demand with one click inside that note.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Button(action: {
                    if let doc = store.currentDoc {
                        autoNote.commitTreeToStore(rootDocId: doc.id, store: store)
                        autoNote.reset()
                        store.isNotesAIAssistantPresented = false
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("Commit Skeleton to Notes Tree (\(autoNote.tree.count) notes)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.regular)
            }
            .padding(10)
            .background(Color.purple.opacity(0.08))
            .cornerRadius(8)

            // Review issues (if any)
            if !autoNote.tree.reviewIssues.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("\(autoNote.tree.reviewIssues.count) Structure Insights Flagged", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
                    ForEach(autoNote.tree.reviewIssues.prefix(2)) { issue in
                        Text("• \(issue.type.capitalized): \(issue.detail)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(6)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(6)
            }

            Text("Edit any node below. Edits lock locally. Only approved nodes enter fill queue:")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            // Node Tree List
            VStack(spacing: 6) {
                ForEach(autoNote.tree.nodes.values.sorted(by: { $0.reading_order < $1.reading_order })) { node in
                    autoNoteNodeRow(node: node)
                }
            }

            // Add Node expander
            if isAddNodeExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Child Note Title...", text: $customChildDraftTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                    TextField("Scope Note (what it covers)...", text: $customChildDraftScope)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))

                    HStack {
                        Button("Add") {
                            let cleanT = customChildDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            let cleanS = customChildDraftScope.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !cleanT.isEmpty {
                                autoNote.addNode(parentId: autoNote.tree.root?.id, title: cleanT, scopeNote: cleanS.isEmpty ? "Detailed coverage of \(cleanT)" : cleanS)
                                customChildDraftTitle = ""
                                customChildDraftScope = ""
                                isAddNodeExpanded = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(.purple)

                        Button("Cancel") { isAddNodeExpanded = false }
                            .buttonStyle(.plain)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                .cornerRadius(6)
            } else {
                Button(action: { isAddNodeExpanded = true }) {
                    Label("Add Child Note", systemImage: "plus.circle")
                        .font(.system(size: 10))
                        .foregroundColor(.purple)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color.purple.opacity(0.06))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple.opacity(0.25), lineWidth: 1))
    }

    @ViewBuilder
    private func autoNoteNodeRow(node: NoteNodeRecord) -> some View {
        let isApproved = (node.status == .approved)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                // Indent spacer
                if node.level > 0 {
                    Rectangle().fill(Color.purple.opacity(0.35)).frame(width: 2, height: 16)
                        .padding(.leading, CGFloat((node.level - 1) * 8))
                }

                Button(action: {
                    if isApproved {
                        var mutN = node
                        mutN.status = .proposed
                        autoNote.tree.nodes[node.id] = mutN
                    } else {
                        autoNote.approveNode(id: node.id)
                    }
                }) {
                    Image(systemName: isApproved ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isApproved ? .green : .secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)

                TextField("Title", text: Binding(
                    get: { node.title },
                    set: { autoNote.updateNodeTitle(id: node.id, newTitle: $0) }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, weight: node.level == 0 ? .semibold : .regular))

                if node.isFieldLocked("title") {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }

                Menu {
                    Button(action: {
                        Task {
                            if let doc = store.currentDoc {
                                autoNote.commitTreeToStore(rootDocId: doc.id, store: store)
                                if let targetDoc = store.documents.first(where: { $0.content.lowercased() == node.title.lowercased() }) {
                                    store.selectDocument(id: targetDoc.id)
                                    NotificationCenter.default.post(name: NSNotification.Name("TriggerFillNote"), object: targetDoc.id)
                                }
                            }
                        }
                    }) {
                        Label("Commit & Fill This Note (AI)", systemImage: "sparkles")
                    }
                    Divider()
                    Button(action: {
                        Task { await autoNote.regenerateBranch(branchRootId: node.id) }
                    }) {
                        Label("Regenerate Branch", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button(action: {
                        Task { await autoNote.goDeeper(nodeId: node.id) }
                    }) {
                        Label("Go Deeper", systemImage: "arrow.turn.right.down")
                    }
                    Divider()
                    Button(role: .destructive, action: { autoNote.deleteNode(id: node.id) }) {
                        Label("Delete Node", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 16)
            }

            // Scope note line
            HStack(spacing: 4) {
                if node.level > 0 {
                    Spacer().frame(width: CGFloat(node.level * 8) + 18)
                } else {
                    Spacer().frame(width: 18)
                }
                TextField("Scope note", text: Binding(
                    get: { node.scope_note },
                    set: { autoNote.updateNodeScope(id: node.id, newScope: $0) }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 9))
                .foregroundColor(.secondary)

                Picker("", selection: Binding(
                    get: { node.expected_depth },
                    set: { autoNote.updateNodeDepth(id: node.id, newDepth: $0) }
                )) {
                    Text("overview").tag("overview")
                    Text("working").tag("working")
                    Text("expert").tag("expert")
                }
                .pickerStyle(.menu)
                .font(.system(size: 8))
                .frame(width: 75)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(Color(NSColor.textBackgroundColor).opacity(0.3))
        .cornerRadius(6)
    }

    @ViewBuilder
    private var autoNoteProgressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text("AUTO-NOTE PIPELINE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.purple)

                Spacer()

                Button("Stop & Keep", action: { autoNote.cancel() })
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(.red)
            }

            Text(autoNote.phase.statusDescription)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)

            // Live node progress list
            VStack(alignment: .leading, spacing: 5) {
                ForEach(autoNote.tree.nodes.values.sorted(by: { $0.reading_order < $1.reading_order })) { node in
                    HStack(spacing: 6) {
                        switch node.status {
                        case .filled:
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.system(size: 11))
                        case .filling:
                            ProgressView().controlSize(.mini)
                        case .unverified:
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange).font(.system(size: 11))
                        case .needs_review:
                            Image(systemName: "flag.fill").foregroundColor(.yellow).font(.system(size: 11))
                        case .approved:
                            Image(systemName: "checkmark.circle").foregroundColor(.purple).font(.system(size: 11))
                        default:
                            Image(systemName: "circle").foregroundColor(.secondary.opacity(0.5)).font(.system(size: 11))
                        }

                        Text(node.title)
                            .font(.system(size: 10, weight: node.status == .filling ? .bold : .regular))
                            .foregroundColor(node.status == .filled ? .primary : (node.status == .filling ? .purple : .secondary))
                            .lineLimit(1)

                        Spacer()

                        Text(node.status.rawValue.capitalized)
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color(NSColor.textBackgroundColor).opacity(0.6))
            .cornerRadius(6)
        }
        .padding(10)
        .background(Color.purple.opacity(0.08))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func autoNoteReportSection(report: RunReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Auto-Notes Completed", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.green)
                Spacer()
                Button("Reset Pipeline", action: { autoNote.reset() })
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(report.nodes_filled)").font(.system(size: 16, weight: .bold)).foregroundColor(.green)
                    Text("Filled").font(.system(size: 9)).foregroundColor(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(report.unverified.count)").font(.system(size: 16, weight: .bold)).foregroundColor(report.unverified.isEmpty ? .secondary : .orange)
                    Text("Unverified").font(.system(size: 9)).foregroundColor(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(report.cache_hits)").font(.system(size: 16, weight: .bold)).foregroundColor(.teal)
                    Text("Cache Hits").font(.system(size: 9)).foregroundColor(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(report.user_edits)").font(.system(size: 16, weight: .bold)).foregroundColor(.purple)
                    Text("User Edits").font(.system(size: 9)).foregroundColor(.secondary)
                }
            }
            .padding(8)
            .background(Color(NSColor.textBackgroundColor).opacity(0.5))
            .cornerRadius(6)

            if !report.needs_attention.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("QA Gate Attention Items:")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
                    ForEach(report.needs_attention) { att in
                        Text("• [\(att.node_id)] \(att.reason)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.green.opacity(0.08))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.25), lineWidth: 1))
    }

    @ViewBuilder
    private func autoNoteErrorSection(msg: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 12))
                Text("PIPELINE PAUSED: ERROR")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.red)
                Spacer()
                Button("Reset", action: { autoNote.reset() })
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Text(msg)
                .font(.system(size: 11))
                .foregroundColor(.primary)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
                .cornerRadius(6)

            if autoNote.tree.count > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.purple)
                            .font(.system(size: 11))
                        Text("\(autoNote.tree.count) Skeleton Nodes Preserved")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                    }

                    Text("Your tree was preserved. You can commit what has been generated to your notes, retry filling, or resume reviewing.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Button(action: {
                            guard let doc = store.currentDoc else { return }
                            autoNote.commitTreeToStore(rootDocId: doc.id, store: store)
                            autoNote.reset()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.square.on.square")
                                Text("Commit Skeleton to Notes")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .controlSize(.small)

                        Button("Resume Review") {
                            autoNote.phase = .waitingUserApproval
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(8)
                .background(Color.purple.opacity(0.06))
                .cornerRadius(6)

                VStack(spacing: 6) {
                    ForEach(autoNote.tree.nodes.values.sorted(by: { $0.reading_order < $1.reading_order })) { node in
                        autoNoteNodeRow(node: node)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.red.opacity(0.04))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.2), lineWidth: 1))
    }

    @ViewBuilder
    private var autoNoteCancelledSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "stop.circle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 12))
                Text("PIPELINE CANCELLED")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.orange)
                Spacer()
                Button("Reset", action: { autoNote.reset() })
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            if autoNote.tree.count > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.purple)
                            .font(.system(size: 11))
                        Text("\(autoNote.tree.count) Skeleton Nodes Preserved")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                    }

                    Text("Partial notes and skeleton were saved:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Button(action: {
                            guard let doc = store.currentDoc else { return }
                            autoNote.commitTreeToStore(rootDocId: doc.id, store: store)
                            autoNote.reset()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.square.on.square")
                                Text("Commit Preserved Notes")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .controlSize(.small)

                        Button("Resume Review") {
                            autoNote.phase = .waitingUserApproval
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(8)
                .background(Color.purple.opacity(0.06))
                .cornerRadius(6)

                VStack(spacing: 6) {
                    ForEach(autoNote.tree.nodes.values.sorted(by: { $0.reading_order < $1.reading_order })) { node in
                        autoNoteNodeRow(node: node)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.04))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.2), lineWidth: 1))
    }

    @ViewBuilder
    private var customInstructionSection: some View {
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

    @ViewBuilder
    private var destinationSection: some View {
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
    }

    @ViewBuilder
    private var sourcesAndResearchDisclosure: some View {
        DisclosureGroup(isExpanded: $isSourcesExpanded) {
            VStack(alignment: .leading, spacing: 14) {
                subjectDomainSection
                Divider().opacity(0.5)
                activeSourcesSection
                Divider().opacity(0.5)
                researchDrawerSection
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "books.vertical.fill")
                    .foregroundColor(.purple)
                    .font(.system(size: 11))
                Text("Sources & Research")
                    .font(.system(size: 11, weight: .semibold))

                Spacer()

                HStack(spacing: 4) {
                    Text(selectedSubjectDomain.shortName)
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.purple.opacity(0.12))
                        .cornerRadius(4)
                        .foregroundColor(.purple)

                    Text("\(activeStudySources.count) APIs")
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(4)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var subjectDomainSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.purple)
                    Text("SUBJECT DOMAIN")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if detectedDomain != .all {
                    HStack(spacing: 3) {
                        Circle().fill(Color.green).frame(width: 5, height: 5)
                        Text("Auto: \(detectedDomain.shortName)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.green)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(StudySubjectDomain.allCases) { domain in
                        let isSelected = (selectedSubjectDomain == domain)
                        let isDetected = (detectedDomain == domain && domain != .all)

                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedSubjectDomain = domain
                                activeStudySources = domain.defaultSources
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: domain.systemIcon)
                                    .font(.system(size: 10))
                                Text(domain.shortName)
                                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                if isDetected {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 5, height: 5)
                                }
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected ? Color.purple.opacity(0.18) : Color(NSColor.textBackgroundColor).opacity(0.6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isSelected ? Color.purple : Color.secondary.opacity(0.15), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var activeSourcesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("ACTIVE OPEN APIS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(activeStudySources.count) active")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
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
                        HStack(spacing: 6) {
                            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                .font(.system(size: 11))
                                .foregroundColor(isSelected ? .purple : .secondary.opacity(0.6))

                            Image(systemName: source.systemIcon)
                                .font(.system(size: 9))
                                .foregroundColor(isSelected ? .primary : .secondary)

                            Text(source.shortName)
                                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? .primary : .secondary)
                                .lineLimit(1)

                            Spacer()
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(isSelected ? Color.purple.opacity(0.08) : Color(NSColor.textBackgroundColor).opacity(0.3))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var researchDrawerSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.purple)
                    Text("RESEARCH EXCERPTS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if !researchSnippets.isEmpty {
                    Text("\(researchSnippets.count) fetched")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 6) {
                TextField("Search subject sources...", text: $researchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(5)
                    .onSubmit { searchLiveResearch() }

                Button(action: searchLiveResearch) {
                    if isSearchingResearch {
                        ProgressView().controlSize(.mini)
                    } else {
                        Text("Fetch")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.purple)
                .disabled(isSearchingResearch || researchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let feedback = lastActionFeedback {
                Text(feedback)
                    .font(.system(size: 10))
                    .foregroundColor(.green)
                    .transition(.opacity)
            }

            if !researchSnippets.isEmpty {
                VStack(spacing: 8) {
                    ForEach(researchSnippets) { snippet in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) {
                                HStack(spacing: 3) {
                                    Image(systemName: snippet.source.systemIcon)
                                        .font(.system(size: 8))
                                    Text(snippet.source.shortName)
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.12))
                                .foregroundColor(.purple)
                                .cornerRadius(4)

                                Text(snippet.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .lineLimit(1)

                                Spacer()

                                if let urlStr = snippet.urlString, let url = URL(string: urlStr) {
                                    Link(destination: url) {
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            Text(snippet.summary)
                                .font(.system(size: 10))
                                .foregroundColor(.primary.opacity(0.85))
                                .lineLimit(3)

                            HStack(spacing: 8) {
                                Button(action: {
                                    insertSnippetAsQuote(snippet)
                                }) {
                                    Label("Insert Quote", systemImage: "quote.opening")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.purple)

                                Text("•").foregroundColor(.secondary).font(.system(size: 8))

                                Button(action: {
                                    insertSnippetCitation(snippet)
                                }) {
                                    Label("Cite", systemImage: "link")
                                        .font(.system(size: 9, weight: .medium))
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.accentColor)

                                Spacer()

                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(snippet.summary, forType: .string)
                                    lastActionFeedback = "Copied to clipboard!"
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Copy excerpt")
                            }
                            .padding(.top, 2)
                        }
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor).opacity(0.6))
                        .cornerRadius(6)
                    }
                }
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func errorSection(_ err: String) -> some View {
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

    @ViewBuilder
    private var bottomStickyCTA: some View {
        VStack(spacing: 8) {
            if selectedMode == .autoNotePipeline {
                if autoNote.isRunning {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(autoNote.phase.statusDescription)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Button("Stop & Keep", action: { autoNote.cancel() })
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(.red)
                    }
                } else if autoNote.phase.isApprovalPending {
                    let approvedCount = autoNote.tree.nodes.values.filter { $0.status == .approved }.count
                    VStack(spacing: 8) {
                        Button(action: {
                            if let doc = store.currentDoc {
                                autoNote.commitTreeToStore(rootDocId: doc.id, store: store)
                                autoNote.reset()
                                store.isNotesAIAssistantPresented = false
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.badge.plus")
                                Text("Commit Skeleton to Notes Tree (\(autoNote.tree.count))")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 3)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .controlSize(.regular)

                        HStack(spacing: 8) {
                            Button("Approve All") {
                                autoNote.approveAll()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button(action: {
                                if let doc = store.currentDoc {
                                    autoNote.startFillingApprovedNotes(rootDocId: doc.id, store: store)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                    Text("Fill All (\(approvedCount))")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(approvedCount == 0)
                        }
                    }
                } else if case .completed = autoNote.phase {
                    Button(action: { autoNote.reset() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("New Auto-Note Pipeline")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.regular)
                } else if case .error = autoNote.phase {
                    if autoNote.tree.count > 0 {
                        Button(action: {
                            if let doc = store.currentDoc {
                                autoNote.commitTreeToStore(rootDocId: doc.id, store: store)
                                autoNote.reset()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.doc.fill")
                                Text("Commit Preserved Skeleton (\(autoNote.tree.count))")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .controlSize(.regular)
                    } else {
                        Button(action: startAutoNotePipeline) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text("Retry Planning Skeleton")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .controlSize(.regular)
                    }
                } else if case .cancelled = autoNote.phase, autoNote.tree.count > 0 {
                    Button(action: {
                        if let doc = store.currentDoc {
                            autoNote.commitTreeToStore(rootDocId: doc.id, store: store)
                            autoNote.reset()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.doc.fill")
                            Text("Commit Preserved Notes (\(autoNote.tree.count))")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.regular)
                } else if case .clarificationNeeded = autoNote.phase {
                    EmptyView()
                } else {
                    Button(action: startAutoNotePipeline) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text("Ground & Plan Skeleton Tree")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.regular)
                    .disabled(!settings.hasNotesAPIKey || store.currentDoc == nil)
                }
            } else if selectedMode == .deepMasterPlan {
                if masterPlan.isRunning {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(masterPlan.activeState.statusDescription)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Button("Stop & Keep", action: { masterPlan.cancel() })
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(.red)
                    }
                } else if let syllabus = masterPlan.activeSyllabus {
                    Button(action: startSynthesizingApprovedPlan) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text("Synthesize \(syllabus.chapters.count) Approved Chapters")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.regular)
                    .disabled(syllabus.chapters.isEmpty)
                } else {
                    Button(action: formulateSyllabus) {
                        HStack(spacing: 6) {
                            if masterPlan.activeState == .formulatingSyllabus {
                                ProgressView().controlSize(.small)
                                Text("Architecting Syllabus...")
                                    .font(.system(size: 12, weight: .semibold))
                            } else {
                                Image(systemName: "list.bullet.clipboard.fill")
                                Text("Formulate Master Syllabus")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.regular)
                    .disabled(!settings.hasNotesAPIKey || store.currentDoc == nil)
                }
            } else {
                Button(action: generateHierarchy) {
                    HStack(spacing: 6) {
                        if isGenerating {
                            ProgressView().controlSize(.small)
                            Text("Architecting Hierarchy...")
                                .font(.system(size: 12, weight: .semibold))
                        } else {
                            Image(systemName: "sparkles")
                            Text("Generate Downward Notes")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.regular)
                .disabled(isGenerating || !settings.hasNotesAPIKey || store.currentDoc == nil)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Actions
    private func updateDomainDetection() {
        let contentText = store.blocks.map { $0.content }.joined(separator: " ")
        let det = StudySubjectDomain.detectDomain(title: currentNoteTitle, content: contentText)
        detectedDomain = det
        if selectedSubjectDomain == .all && det != .all {
            selectedSubjectDomain = det
            activeStudySources = det.defaultSources
        }
        if researchQuery.isEmpty && currentNoteTitle != "Untitled Note" {
            researchQuery = currentNoteTitle
        }
    }

    private func searchLiveResearch() {
        let q = researchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !activeStudySources.isEmpty else { return }
        isSearchingResearch = true
        lastActionFeedback = nil

        Task {
            let snippets = await StudyKnowledgeService.shared.fetchGroundedKnowledge(
                for: q,
                sources: activeStudySources,
                isCompactBudget: false
            )
            await MainActor.run {
                self.researchSnippets = snippets
                self.isSearchingResearch = false
                if snippets.isEmpty {
                    self.lastActionFeedback = "No excerpts found for '\(q)'"
                }
            }
        }
    }

    private func insertSnippetAsQuote(_ snippet: StudySnippet) {
        let cite = snippet.citation ?? snippet.title
        let quoteContent = "\(snippet.summary)\n— \(cite)\(snippet.urlString != nil ? " (\(snippet.urlString!))" : "")"
        store.createBlock(type: .quote, content: quoteContent)
        lastActionFeedback = "Quote inserted into note!"
    }

    private func insertSnippetCitation(_ snippet: StudySnippet) {
        let url = snippet.urlString ?? "https://en.wikipedia.org"
        let citationText = "Reference: [\(snippet.title)](\(url)) — \(snippet.citation ?? snippet.source.displayName)"
        store.createBlock(type: .paragraph, content: citationText)
        lastActionFeedback = "Citation inserted into note!"
    }

    private func startAutoNotePipeline() {
        errorMessage = nil
        let topic = currentNoteTitle
        let direction = directionFocusPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let currentDoc = store.currentDoc else {
            errorMessage = "Please select or create a note in the vault first."
            return
        }

        autoNote.startPipeline(
            rootTitle: topic,
            userContext: direction.isEmpty ? nil : direction,
            rootDocId: currentDoc.id,
            store: store
        )
    }

    private func formulateSyllabus() {
        errorMessage = nil
        let topic = currentNoteTitle
        let direction = directionFocusPrompt.trimmingCharacters(in: .whitespacesAndNewlines)

        masterPlan.formulateAndPreviewSyllabus(
            topic: topic,
            archetype: selectedArchetype,
            directionPrompt: direction.isEmpty ? nil : direction,
            domain: selectedSubjectDomain != .all ? selectedSubjectDomain : detectedDomain
        )
    }

    private func startSynthesizingApprovedPlan() {
        guard let currentDoc = store.currentDoc else { return }
        errorMessage = nil
        masterPlan.startSynthesizingApprovedPlan(
            rootDocId: currentDoc.id,
            domain: selectedSubjectDomain != .all ? selectedSubjectDomain : detectedDomain,
            activeSources: activeStudySources,
            store: store
        )
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
                    self.generatedResult = result
                    self.isGenerating = false
                    self.isApprovalSheetPresented = true
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isGenerating = false
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

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach($items) { $node in
                        HierarchicalNodeRowView(node: $node, level: 0)
                    }
                }
                .padding(20)
            }

            Divider()

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
        store.isNotesAIAssistantPresented = false
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

                Toggle("", isOn: $node.isSelected)
                    .toggleStyle(.checkbox)
                    .labelsHidden()

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

                Image(systemName: level == 0 ? "folder.fill" : "doc.text")
                    .font(.system(size: 12))
                    .foregroundColor(level == 0 ? .orange : .accentColor)

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
