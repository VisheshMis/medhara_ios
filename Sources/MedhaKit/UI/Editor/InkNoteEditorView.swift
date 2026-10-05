import SwiftUI
import AppKit

public struct InkNoteEditorView: View {
    @ObservedObject public var store: BlockStore
    public let doc: Block

    // Per-page strokes dictionary: [pageIndex: [InkStroke]]
    @State private var pagesStrokes: [Int: [InkStroke]] = [:]
    @State private var zoomScale: CGFloat = 1.0

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
            // Note Header
            VStack(alignment: .leading, spacing: 8) {
                ancestryBreadcrumbsView

                // Title bar with Ink Note badge, import/export, & page info
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "pencil.tip")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)

                    TextField("Untitled Handwritten Note", text: Binding(
                        get: { doc.content },
                        set: { store.renameDocument(docId: doc.id, newTitle: $0) }
                    ))
                    .font(.system(size: 24, weight: .bold))
                    .textFieldStyle(.plain)

                    Spacer()

                    // Zoom Controls
                    HStack(spacing: 4) {
                        Button(action: { zoomScale = max(0.5, zoomScale - 0.1) }) {
                            Image(systemName: "minus.magnifyingglass")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .help("Zoom Out")

                        Text("\(Int(round(zoomScale * 100)))%")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .frame(width: 38)
                            .onTapGesture { zoomScale = 1.0 }
                            .help("Click to reset to 100%")

                        Button(action: { zoomScale = min(2.0, zoomScale + 0.1) }) {
                            Image(systemName: "plus.magnifyingglass")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .help("Zoom In")
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
                            Label("Export Current Page as PNG...", systemImage: "photo")
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
                    .buttonStyle(.plain)

                    // Page Count Badge
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                        Text("\(max(1, store.inkPages.count)) Page\(store.inkPages.count > 1 ? "s" : "")")
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

            // Main Interactive Multi-Page Canvas Area
            ZStack(alignment: .top) {
                // Background desk area
                Color(NSColor.windowBackgroundColor)
                    .ignoresSafeArea()

                // Continuous Vertical Scrollable Pages
                ScrollView([.vertical, .horizontal], showsIndicators: true) {
                    VStack(spacing: 36) {
                        ForEach(Array(store.inkPages.enumerated()), id: \.element.id) { index, page in
                            pageCard(index: index, page: page)
                        }

                        // Bottom Actions: Add Page or Import PDF
                        HStack(spacing: 16) {
                            Button(action: {
                                store.addInkPage()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 13))
                                    Text("Add Next Blank Page")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)

                            Button(action: promptImportPDF) {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.badge.plus")
                                        .font(.system(size: 13))
                                    Text("Import PDF Pages")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.bottom, 48)
                    }
                    .scaleEffect(zoomScale)
                    .padding(.vertical, 32)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                }

                // Floating Dynamic Ink Toolbar
                InkToolbarView(
                    store: store,
                    onUndo: performUndo,
                    onRedo: performRedo,
                    canUndo: !store.inkUndoStack.isEmpty,
                    canRedo: !store.inkRedoStack.isEmpty
                )
                .padding(.top, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: - Individual Page Card View
    private func pageCard(index: Int, page: InkDocumentPage) -> some View {
        VStack(alignment: .center, spacing: 8) {
            // Page Header with Page Number, PDF Info badge, Template, and Delete
            HStack(spacing: 8) {
                Text("Page \(index + 1)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)

                if page.pdfPath != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 9))
                        Text("PDF Page \(page.pdfPageIndex ?? 1)")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundColor(.accentColor)
                    .cornerRadius(4)
                }

                Spacer()

                // Per-page Template Selector
                Menu {
                    ForEach(InkTemplateType.allCases, id: \.rawValue) { tmpl in
                        Button(action: {
                            store.setInkTemplate(template: tmpl, forPageIndex: page.pageIndex)
                        }) {
                            Label(tmpl.displayName, systemImage: tmpl.systemIcon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: page.templateType.systemIcon)
                            .font(.system(size: 10))
                        Text(page.templateType.displayName)
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                if store.inkPages.count > 1 {
                    Button(action: {
                        store.deleteInkPage(pageIndex: page.pageIndex)
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Delete Page")
                }
            }
            .frame(width: 794)

            // Sheet Paper Canvas (with PDF background under vector ink)
            InkCanvasRepresentable(
                docId: doc.id,
                pageIndex: page.pageIndex,
                templateType: page.templateType,
                pdfPath: page.pdfPath,
                pdfPageIndex: page.pdfPageIndex,
                strokes: pagesStrokes[page.pageIndex] ?? [],
                activeTool: store.activeInkTool,
                activeColorHex: store.activeInkColorHex,
                activeWidth: store.activeInkWidth,
                onStrokesChanged: { newStrokes in
                    recordStrokeHistory(pageIndex: page.pageIndex, newStrokes: newStrokes)
                }
            )
            .frame(width: 794, height: 1123) // Standard A4 Aspect Ratio
            .background(Color.white)
            .cornerRadius(4)
            .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
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
        guard let pdfData = InkExportService.exportToVectorPDF(title: doc.content, pages: store.inkPages) else {
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
        guard let firstPage = store.inkPages.first,
              let pngData = InkExportService.exportToPNG(page: firstPage) else {
            return
        }
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        let cleanName = doc.content.isEmpty ? "Untitled Note" : doc.content
        savePanel.nameFieldStringValue = "\(cleanName)-Page1.png"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? pngData.write(to: url)
            }
        }
    }
}
