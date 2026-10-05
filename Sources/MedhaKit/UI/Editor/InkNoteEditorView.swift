import SwiftUI
import AppKit

public struct InkNoteEditorView: View {
    @ObservedObject public var store: BlockStore
    public let doc: Block

    // Per-page strokes dictionary: [pageIndex: [InkStroke]]
    @State private var pagesStrokes: [Int: [InkStroke]] = [:]
    @State private var zoomScale: CGFloat = 1.0
    @State private var isExporting: Bool = false
    @State private var exportMessage: String? = nil

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

                // Title bar with Ink Note badge, export, & page info
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

                        // Bottom Add Page Button
                        Button(action: {
                            store.addInkPage()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 14))
                                Text("Add Next Page")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
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
            // Page Header with Page Number, Template, and Delete
            HStack {
                Text("Page \(index + 1)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)

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

            // Sheet Paper Canvas
            InkCanvasRepresentable(
                docId: doc.id,
                pageIndex: page.pageIndex,
                templateType: page.templateType,
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
