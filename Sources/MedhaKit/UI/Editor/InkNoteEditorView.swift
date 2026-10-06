import SwiftUI
import AppKit

public struct InkNoteEditorView: View {
    @ObservedObject public var store: BlockStore
    public let doc: Block

    // Per-page strokes dictionary: [pageIndex: [InkStroke]]
    @State private var pagesStrokes: [Int: [InkStroke]] = [:]
    @State private var zoomScale: CGFloat = 1.0
    @State private var isHandToolActive: Bool = false
    @State private var viewportNSView: InkCanvasViewportNSView? = nil

    // PDF Import Trimming State
    @State private var isShowingPDFImportSheet: Bool = false
    @State private var pendingImportPDFURL: URL? = nil
    @State private var pendingImportTotalPages: Int = 0

    public init(store: BlockStore, doc: Block) {
        self.store = store
        self.doc = doc
    }

    private var ancestryBreadcrumbsView: some View {
        let ancestry = store.getDocAncestry(for: doc.id)
        return Group {
            if ancestry.count > 1 {
                HStack(spacing: 4) {
                    ForEach(Array(ancestry.dropLast().enumerated()), id: \.element.id) { index, ancestor in
                        Button(action: {
                            store.selectDocument(id: ancestor.id)
                        }) {
                            Text(ancestor.content.isEmpty ? "Untitled Note" : ancestor.content)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)

                        Text("/")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Note Header - Hidden completely in Full Screen Focus Mode
            if !store.isInkFocusMode {
                VStack(alignment: .leading, spacing: 8) {
                    ancestryBreadcrumbsView

                    // Title bar with Ink Note badge, mode badge, zoom, import/export
                    HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "pencil.tip")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)

                    TextField("Untitled Handwritten Note", text: Binding(
                        get: { doc.content },
                        set: { store.renameDocument(docId: doc.id, newTitle: $0) }
                    ))
                    .font(.system(size: 22, weight: .bold))
                    .textFieldStyle(.plain)

                    // Canvas Mode Badge
                    HStack(spacing: 5) {
                        Image(systemName: doc.resolvedCanvasMode.systemIcon)
                            .font(.system(size: 10))
                        Text(doc.resolvedCanvasMode.badgeLabel)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12))
                    .foregroundColor(.orange)
                    .cornerRadius(6)

                    Spacer()

                    // Zoom Controls & Hand Tool
                    HStack(spacing: 4) {
                        // Hand Tool Toggle
                        Button(action: { isHandToolActive.toggle() }) {
                            Image(systemName: isHandToolActive ? "hand.raised.fill" : "hand.raised")
                                .font(.system(size: 11))
                                .foregroundColor(isHandToolActive ? .accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Hand Tool (Spacebar + Drag to Pan)")

                        Divider()
                            .frame(height: 12)

                        // Zoom Out
                        Button(action: { viewportNSView?.zoomOut() }) {
                            Image(systemName: "minus.magnifyingglass")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .help("Zoom Out (⌘-)")

                        // Zoom Percentage Dropdown Menu
                        Menu {
                            Button("100% Actual Size (⌘0)") { viewportNSView?.zoomToActualSize() }
                            Button("Fit to Width (⌘9)") { viewportNSView?.zoomToFitWidth() }
                            Button("Fit to All Content") { viewportNSView?.zoomToFitContent() }
                            Divider()
                            ForEach([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 5.0], id: \.self) { preset in
                                Button("\(Int(round(preset * 100)))%") {
                                    viewportNSView?.zoomTo(scale: CGFloat(preset))
                                }
                            }
                        } label: {
                            Text("\(Int(round(zoomScale * 100)))%")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .frame(width: 40)
                        }
                        .menuStyle(.borderlessButton)
                        .help("Zoom Presets")

                        // Zoom In
                        Button(action: { viewportNSView?.zoomIn() }) {
                            Image(systemName: "plus.magnifyingglass")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .help("Zoom In (⌘+)")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)

                    // Import PDF Button
                    Button(action: promptImportPDF) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 11))
                            Text("Import PDF...")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Import and trim PDF pages into this note")

                    // Export Menu Button
                    Menu {
                        Button(action: exportPDF) {
                            Label("Export as Vector PDF...", systemImage: "doc.richtext")
                        }
                        Button(action: exportPNG) {
                            Label("Export as PNG Image...", systemImage: "photo")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 11))
                            Text("Export")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                    // Focus Mode (Zen Mode) Button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.isInkFocusMode.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 11))
                            Text("Focus")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Full Screen Focus Mode (Esc to Exit)")

                    // Page Count Badge or Continuous Badge
                    HStack(spacing: 6) {
                        Image(systemName: doc.resolvedCanvasMode == .a4Pages ? "doc.on.doc" : "infinity")
                            .font(.system(size: 11))
                        Text(pageStatusLabel)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()
            }

            // Main Interactive Multi-Page / Infinite Canvas Viewport
            ZStack(alignment: .top) {
                InkCanvasViewportRepresentable(
                    docId: doc.id,
                    canvasMode: doc.resolvedCanvasMode,
                    templateType: store.activeInkTemplate,
                    pdfPath: store.inkPages.first?.pdfPath,
                    pdfPageIndex: store.inkPages.first?.pdfPageIndex,
                    pagesStrokes: pagesStrokes,
                    totalPagesCount: max(1, store.inkPages.count),
                    activeTool: store.activeInkTool,
                    activeColorHex: store.activeInkColorHex,
                    activeWidth: store.activeInkWidth,
                    zoomScale: $zoomScale,
                    isHandToolActive: $isHandToolActive,
                    viewportRef: $viewportNSView,
                    onStrokesChanged: { pageIndex, strokes in
                        recordStrokeHistory(pageIndex: pageIndex, newStrokes: strokes)
                    },
                    onAddPage: {
                        store.addInkPage()
                    },
                    onDeletePage: { pageIndex in
                        store.deleteInkPage(pageIndex: pageIndex)
                    },
                    onPerformUndo: performUndo,
                    onPerformRedo: performRedo,
                    onExitFocusMode: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.isInkFocusMode = false
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                // Floating Dynamic Ink Toolbar - Writing tools only in focus mode!
                InkToolbarView(
                    store: store,
                    onUndo: performUndo,
                    onRedo: performRedo,
                    canUndo: !store.inkUndoStack.isEmpty,
                    canRedo: !store.inkRedoStack.isEmpty
                )
                .padding(.top, store.isInkFocusMode ? 20 : 16)

                // Exit Focus Mode button floating at top trailing corner in Focus Mode
                if store.isInkFocusMode {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                store.isInkFocusMode = false
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Exit Focus (Esc)")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 20)
                        .padding(.trailing, 24)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .sheet(isPresented: $isShowingPDFImportSheet) {
            if let url = pendingImportPDFURL {
                PDFImportTrimSheet(
                    sourceURL: url,
                    totalPages: pendingImportTotalPages,
                    onImport: { startPage, endPage in
                        store.importTrimmedPDFPages(from: url, startPage: startPage, endPage: endPage)
                        isShowingPDFImportSheet = false
                    },
                    onCancel: {
                        isShowingPDFImportSheet = false
                    }
                )
            }
        }
        .onAppear {
            loadPagesData()
        }
        .onChange(of: doc.id) { _, _ in
            loadPagesData()
        }
        .onChange(of: store.inkPages.count) { _, _ in
            loadPagesData()
        }
    }

    private var pageStatusLabel: String {
        switch doc.resolvedCanvasMode {
        case .a4Pages:
            let count = max(1, store.inkPages.count)
            return "\(count) Page\(count > 1 ? "s" : "")"
        case .infiniteVertical:
            return "Infinite Vertical"
        case .infinite2D:
            return "Infinite 2D"
        }
    }

    // MARK: - PDF Import Prompt
    private func promptImportPDF() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.pdf]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Choose PDF to Import"

        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                let total = InkPDFImporterService.pageCount(for: url)
                if total > 0 {
                    self.pendingImportPDFURL = url
                    self.pendingImportTotalPages = total
                    self.isShowingPDFImportSheet = true
                }
            }
        }
    }

    // MARK: - Persistence & History Handling
    private func loadPagesData() {
        var dict: [Int: [InkStroke]] = [:]
        for page in store.inkPages {
            let payload = InkPagePayload.deserialize(from: page.strokesData)
            dict[page.pageIndex] = payload.strokes
        }
        self.pagesStrokes = dict
        store.inkUndoStack.removeAll()
        store.inkRedoStack.removeAll()
    }

    private func recordStrokeHistory(pageIndex: Int, newStrokes: [InkStroke]) {
        let oldStrokes = pagesStrokes[pageIndex] ?? []
        store.inkUndoStack.append(oldStrokes)
        if store.inkUndoStack.count > 50 {
            store.inkUndoStack.removeFirst()
        }
        store.inkRedoStack.removeAll()

        pagesStrokes[pageIndex] = newStrokes
        store.saveInkPageStrokes(pageIndex: pageIndex, strokes: newStrokes)
    }

    private func performUndo() {
        guard let prev = store.inkUndoStack.popLast() else { return }
        let targetIndex = 0
        let current = pagesStrokes[targetIndex] ?? []
        store.inkRedoStack.append(current)
        pagesStrokes[targetIndex] = prev
        store.saveInkPageStrokes(pageIndex: targetIndex, strokes: prev)
    }

    private func performRedo() {
        guard let next = store.inkRedoStack.popLast() else { return }
        let targetIndex = 0
        let current = pagesStrokes[targetIndex] ?? []
        store.inkUndoStack.append(current)
        pagesStrokes[targetIndex] = next
        store.saveInkPageStrokes(pageIndex: targetIndex, strokes: next)
    }

    // MARK: - Export Logic
    private func exportPDF() {
        guard let pdfData = InkExportService.exportDocumentToVectorPDF(
            title: doc.content,
            pages: store.inkPages,
            canvasMode: doc.resolvedCanvasMode
        ) else {
            return
        }
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        let cleanName = doc.content.isEmpty ? "Untitled Note" : doc.content
        savePanel.nameFieldStringValue = "\(cleanName).pdf"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? pdfData.write(to: url)
            }
        }
    }

    private func exportPNG() {
        guard let pngData = InkExportService.exportDocumentToPNG(
            pages: store.inkPages,
            canvasMode: doc.resolvedCanvasMode
        ) else {
            return
        }
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        let cleanName = doc.content.isEmpty ? "Untitled Note" : doc.content
        savePanel.nameFieldStringValue = "\(cleanName).png"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? pngData.write(to: url)
            }
        }
    }
}
