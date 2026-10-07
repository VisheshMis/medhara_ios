import SwiftUI

public struct BlockEditorView: View {
    @ObservedObject public var store: BlockStore
    @State private var isIconPickerPresented: Bool = false
    @State private var isAddFlashcardPresented: Bool = false
    @State private var isFillingSingleNote: Bool = false
    @State private var singleNoteFillStage: String = ""
    @State private var singleNoteFillError: String? = nil
    @State private var selectedDepthForFill: String = "working"
    @FocusState private var isTitleFocused: Bool

    private let availableIcons = ["doc.text", "brain.head.profile", "lightbulb", "sparkles", "folder", "star", "bookmark", "tag", "checklist", "terminal", "cube"]

    public var body: some View {
        Group {
            if let doc = store.currentDoc {
                if doc.isInkDocument {
                    InkNoteEditorView(store: store, doc: doc)
                        .clipped()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                // Document Header
                                VStack(alignment: .leading, spacing: 8) {
                                    // Breadcrumbs & Header Actions
                                    breadcrumbsView(doc: doc)

                                // Document Title
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    TextField("Untitled Document", text: Binding(
                                        get: { doc.content },
                                        set: { store.renameDocument(docId: doc.id, newTitle: $0) }
                                    ))
                                    .focused($isTitleFocused)
                                    .font(.system(size: 28 * store.editorZoomLevel, weight: .bold, design: .serif))
                                    .foregroundColor(MedhaTheme.Colors.textPrimary)
                                    .textFieldStyle(.plain)
                                    .id("document-title-\(doc.id)")
                                    .onSubmit {
                                        if let first = store.blocks.first {
                                            isTitleFocused = false
                                            store.focusedBlockId = first.id
                                        } else {
                                            let newBlock = store.createBlock(type: .paragraph, content: "")
                                            isTitleFocused = false
                                            store.focusedBlockId = newBlock.id
                                        }
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    store.focusedBlockId = nil
                                    isTitleFocused = true
                                }

                                // Living Folder Command Hub Status Badges
                                livingFolderHubView(doc: doc)
                            }
                            .padding(.bottom, 6)

                            // Nested Subfolders & Documents in this Folder
                            subfoldersGalleryView(doc: doc)

                            // Interactive Skeletal Fill Card (2-step on-demand generation)
                            if isCurrentDocSkeletal || isFillingSingleNote {
                                skeletalFillCard(doc: doc)
                            }

                            Divider()

                            // Continuous Block Stream
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(store.blocks.enumerated()), id: \.element.id) { index, block in
                                    BlockRowView(
                                        store: store,
                                        block: block,
                                        isFirst: index == 0,
                                        isLast: index == store.blocks.count - 1
                                    )
                                    .id(block.id)
                                }
                            }

                            // Clickable bottom buffer to add new block
                            Color.clear
                                .frame(height: 40)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    store.createBlock(type: .paragraph, content: "")
                                }

                            // Flashcards Attached to this Folder / Note
                            flashcardsSectionView(doc: doc)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 40)
                        .padding(.top, 24)
                        .padding(.bottom, 48)
                    }
                    .overlay(alignment: .topTrailing) {
                        if let hudMsg = store.zoomHUDMessage {
                            Text(hudMsg)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(MedhaTheme.Colors.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(MedhaTheme.Colors.borderSubtle, lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                                .padding(.top, 16)
                                .padding(.trailing, 24)
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                    }
                    .onChange(of: store.focusedBlockId) { _, newId in
                        if let id = newId {
                            isTitleFocused = false
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                    .onChange(of: isTitleFocused) { _, focused in
                        if focused {
                            store.focusedBlockId = nil
                            withAnimation(.easeInOut(duration: 0.15)) {
                                proxy.scrollTo("document-title-\(doc.id)", anchor: .top)
                            }
                        }
                    }
                    .sheet(isPresented: $isAddFlashcardPresented) {
                        AddFlashcardSheet(
                            store: store,
                            isPresented: $isAddFlashcardPresented,
                            preselectedDeckId: Deck.notesDefaultId,
                            preselectedDocId: doc.id
                        )
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TriggerFillNote"))) { notif in
                        if let targetId = notif.object as? String, targetId == doc.id {
                            startSingleNoteFill(doc: doc)
                        }
                    }
                }
            }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("No Document Selected")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(MedhaTheme.Colors.textSecondary)
                    Text("Select a document from the tree, or press ⌘N to create a new page.")
                        .font(.system(size: 13))
                        .foregroundColor(MedhaTheme.Colors.textTertiary)
                    Button(action: {
                        store.createDocument(title: "Untitled Document")
                    }) {
                        Label("New Document", systemImage: "plus")
                    }
                    .medhaPrimaryButton()
                    .controlSize(.regular)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(MedhaTheme.Colors.bgBase)
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.command) {
                    let chars = event.charactersIgnoringModifiers ?? ""
                    if chars == "+" || chars == "=" || event.keyCode == 24 {
                        store.zoomIn()
                        return nil
                    } else if chars == "-" || event.keyCode == 27 {
                        store.zoomOut()
                        return nil
                    } else if chars == "0" || event.keyCode == 29 {
                        store.resetZoom()
                        return nil
                    }
                }
                return event
            }
        }
    }

    private func docWordCount() -> Int {
        var count = store.currentDoc?.content.components(separatedBy: .whitespacesAndNewlines).filter({ !$0.isEmpty }).count ?? 0
        for b in store.blocks {
            count += b.content.components(separatedBy: .whitespacesAndNewlines).filter({ !$0.isEmpty }).count
        }
        return count
    }

    private func docCharCount() -> Int {
        var count = store.currentDoc?.content.count ?? 0
        for b in store.blocks {
            count += b.content.count
        }
        return count
    }

    private func docReadingTimeMinutes() -> Int {
        let words = docWordCount()
        return max(1, Int(ceil(Double(words) / 200.0)))
    }

    private func breadcrumbsView(doc: Block) -> some View {
        let ancestry = store.getDocAncestry(for: doc.id)

        return HStack(spacing: 5) {
            if let nb = store.notebooks.first(where: { $0.id == doc.notebookId }) {
                Button(action: { store.selectNotebook(id: nb.id) }) {
                    HStack(spacing: 4) {
                        Image(systemName: nb.icon ?? "book.closed.fill")
                            .font(.system(size: 11))
                        Text(nb.name)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }

            ForEach(Array(ancestry.enumerated()), id: \.element.id) { index, ancestor in
                let isLast = index == ancestry.count - 1
                if isLast {
                    Text(ancestor.content.isEmpty ? "Untitled" : ancestor.content)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Button(action: { store.selectDocument(id: ancestor.id) }) {
                        Text(ancestor.content.isEmpty ? "Untitled" : ancestor.content)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }

            Spacer()

            // TimeKeeper Focus Session Pill
            TimeKeeperToolbarPill(
                timerManager: store.timerManager,
                onOpenStats: { store.isFocusStatsPresented = true },
                isCompact: true
            )

            // "+ Sub-note" quick button in editor header
            Button(action: {
                store.createDocument(notebookId: doc.notebookId, parentDocId: doc.id)
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                    Text("Sub-note")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(MedhaTheme.Colors.textSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(MedhaTheme.Colors.bgSurface)
                .clipShape(Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(MedhaTheme.Colors.borderHairline, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Create a sub-note nested under this document")

            // Word count, reading time & block count pill
            HStack(spacing: 6) {
                Text("\(docWordCount()) words")
                Text("•")
                Text("~\(docReadingTimeMinutes())m read")
                Text("•")
                Text("\(store.blocks.count) blocks")
            }
            .font(MedhaTheme.Typography.monoCounter)
            .foregroundColor(MedhaTheme.Colors.textTertiary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(MedhaTheme.Colors.bgSurface)
            .clipShape(Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(MedhaTheme.Colors.borderHairline, lineWidth: 1)
            )
            .help("\(docWordCount()) words · \(docCharCount()) characters · Estimated \(docReadingTimeMinutes()) min read")
        }
    }

    private func livingFolderHubView(doc: Block) -> some View {
        let children = store.getChildDocuments(for: doc.id)
        let cards = store.flashcardsForCurrentDoc
        let words = docWordCount()
        let estReadTime = max(1, Int(ceil(Double(words) / 200.0)))
        let hasPalaceAnchors = store.loci.contains(where: { locus in
            store.getFlashcards(for: locus.id).contains(where: { $0.docId == doc.id })
        })

        return HStack(spacing: 8) {
            // Subfolders count badge
            HStack(spacing: 4) {
                Image(systemName: children.isEmpty ? "folder" : "folder.fill")
                    .font(.system(size: 10))
                Text("\(children.count) Sub-notes")
            }
            .medhaChip(color: MedhaTheme.Colors.textSecondary, isMuted: true)

            // Flashcards count badge
            HStack(spacing: 4) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 10))
                Text("\(cards.count) Cards")
            }
            .medhaChip(color: MedhaTheme.Colors.notesAccent, isMuted: cards.isEmpty)

            // Reading estimate badge
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                Text("~\(estReadTime) min read")
            }
            .medhaChip(color: MedhaTheme.Colors.textSecondary, isMuted: true)

            // Memory Palace link badge if applicable
            if hasPalaceAnchors {
                HStack(spacing: 4) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 10))
                    Text("Palace Anchored")
                }
                .medhaChip(color: MedhaTheme.Colors.palaceAccent, isMuted: false)
            }

            Spacer()
        }
        .padding(.top, 2)
    }

    private func subfoldersGalleryView(doc: Block) -> some View {
        let children = store.getChildDocuments(for: doc.id)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Nested Subfolders & Documents (\(children.count))", systemImage: "folder")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    store.createDocument(notebookId: doc.notebookId, parentDocId: doc.id)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Add Subfolder / Document")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }

            if !children.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 240))], spacing: 8) {
                    ForEach(children) { child in
                        Button(action: {
                            store.selectDocument(id: child.id)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: store.getChildDocuments(for: child.id).isEmpty ? "doc.text" : "folder.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 12))

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(child.content.isEmpty ? "Untitled Note" : child.content)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)

                                    let subCount = store.getChildDocuments(for: child.id).count
                                    if subCount > 0 {
                                        Text("\(subCount) subfolders")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
        .cornerRadius(8)
    }

    private func flashcardsSectionView(doc: Block) -> some View {
        let cards = store.flashcardsForCurrentDoc

        return VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.top, 16)

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .foregroundColor(.accentColor)
                    Text("FLASHCARDS IN THIS FOLDER (\(cards.count))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Generate from Note button
                Button(action: {
                    generateFlashcardsFromNote(doc: doc)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Extract Cards from Note")
                    }
                    .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                // Add Card button
                Button(action: {
                    isAddFlashcardPresented = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add Card")
                    }
                    .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if cards.isEmpty {
                HStack {
                    Text("No flashcards attached to this folder yet. Extract from note content or add new cards.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                .cornerRadius(6)
            } else {
                let displayedCards = Array(cards.prefix(25))
                VStack(spacing: 6) {
                    ForEach(displayedCards) { card in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.front)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text(card.back)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Text(card.fsrsState.displayName)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.12))
                                .cornerRadius(4)

                            Button(action: {
                                store.deleteFlashcard(id: card.id)
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(6)
                    }

                    if cards.count > 25 {
                        HStack {
                            Text("Showing 25 of \(cards.count) cards attached to this document")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Open in Flashcards Hub") {
                                store.activeMainView = .flashcards
                            }
                            .font(.system(size: 11))
                            .buttonStyle(.link)
                        }
                        .padding(.top, 6)
                    }
                }
            }
        }
    }

    private func generateFlashcardsFromNote(doc: Block) {
        for block in store.blocks {
            if block.type == .callout && !block.content.isEmpty {
                store.createFlashcard(
                    docId: doc.id,
                    front: "Key Concept: \(doc.content)",
                    back: block.content,
                    sourceBlockId: block.id
                )
            } else if block.isHeading && !block.content.isEmpty {
                if let idx = store.blocks.firstIndex(where: { $0.id == block.id }), idx + 1 < store.blocks.count {
                    let next = store.blocks[idx + 1]
                    if next.type == .paragraph && !next.content.isEmpty {
                        store.createFlashcard(
                            docId: doc.id,
                            front: "What is \(block.content)?",
                            back: next.content,
                            sourceBlockId: next.id
                        )
                    }
                }
            }
        }
    }

    // MARK: - Skeletal Note Detection & On-Demand Fill
    private var skeletalMarkerBlock: Block? {
        store.blocks.first(where: {
            $0.content.contains("Skeletal Note") || $0.content.hasPrefix("🪄 Skeletal")
        })
    }

    private var isCurrentDocSkeletal: Bool {
        skeletalMarkerBlock != nil
    }

    private var extractedScopeNote: String {
        if let block = skeletalMarkerBlock {
            if let range = block.content.range(of: "Scope:") {
                let after = String(block.content[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !after.isEmpty { return after }
            }
            let cleaned = block.content.replacingOccurrences(of: "🪄 Skeletal Note", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty { return cleaned }
        }
        return "Comprehensive coverage, foundational mechanisms, and key principles"
    }

    @ViewBuilder
    private func skeletalFillCard(doc: Block) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.purple)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Skeletal Note • Ready to Fill Content")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Generate deep verified content, academic evidence, and backlinks on-demand.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Picker("Depth", selection: $selectedDepthForFill) {
                    Text("Overview").tag("overview")
                    Text("Working").tag("working")
                    Text("Expert").tag("expert")
                }
                .pickerStyle(.segmented)
                .frame(width: 210)
            }

            // Scope Preview
            HStack(alignment: .top, spacing: 6) {
                Text("Scope:")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(extractedScopeNote)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            .padding(8)
            .background(Color(NSColor.textBackgroundColor).opacity(0.6))
            .cornerRadius(6)

            if isFillingSingleNote {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(singleNoteFillStage.isEmpty ? "Synthesizing content..." : singleNoteFillStage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.purple)
                    Spacer()
                }
                .padding(8)
                .background(Color.purple.opacity(0.08))
                .cornerRadius(6)
            } else {
                HStack(spacing: 8) {
                    Button(action: {
                        startSingleNoteFill(doc: doc)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text("Generate Full Content & Citations (AI)")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.regular)

                    if let err = singleNoteFillError {
                        Text(err)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.purple.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.purple.opacity(0.25), lineWidth: 1)
        )
    }

    private func startSingleNoteFill(doc: Block) {
        guard !isFillingSingleNote else { return }
        isFillingSingleNote = true
        singleNoteFillError = nil
        singleNoteFillStage = "Routing APIs & Querying Evidence..."

        Task {
            do {
                try await AutoNotePipelineService.shared.fillSingleDocument(
                    docId: doc.id,
                    store: store,
                    customScope: extractedScopeNote,
                    customDepth: selectedDepthForFill,
                    onProgress: { stage in
                        Task { @MainActor in
                            self.singleNoteFillStage = stage
                        }
                    }
                )
                await MainActor.run {
                    self.isFillingSingleNote = false
                    self.singleNoteFillStage = ""
                }
            } catch {
                await MainActor.run {
                    self.isFillingSingleNote = false
                    self.singleNoteFillError = error.localizedDescription
                }
            }
        }
    }
}
