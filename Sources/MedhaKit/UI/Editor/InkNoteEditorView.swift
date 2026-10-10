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

    private var computedPagePDFInfos: [Int: (path: String, pageIndex: Int)] {
        Dictionary(uniqueKeysWithValues: store.inkPages.compactMap { page in
            if let path = page.pdfPath, let pIdx = page.pdfPageIndex {
                return (page.pageIndex, (path: path, pageIndex: pIdx))
            }
            return nil
        })
    }

    private var computedSpatialPDFLayouts: [Int: (canvasX: Double, canvasY: Double, customWidth: Double?, customHeight: Double?, cropRect: CGRect?)] {
        Dictionary(uniqueKeysWithValues: store.inkPages.map { page in
            var parsedCrop: CGRect? = nil
            if let cropData = page.cropRectData,
               let data = cropData.data(using: .utf8),
               let arr = try? JSONDecoder().decode([Double].self, from: data),
               arr.count == 4 {
                parsedCrop = CGRect(x: arr[0], y: arr[1], width: arr[2], height: arr[3])
            }
            return (page.pageIndex, (
                canvasX: page.canvasX ?? 0.0,
                canvasY: page.canvasY ?? (Double(page.pageIndex) * Double(InkCanvasViewportNSView.standardPageHeight + InkCanvasViewportNSView.pageGap)),
                customWidth: page.customWidth,
                customHeight: page.customHeight,
                cropRect: parsedCrop
            ))
        })
    }

    // PDF Import Trimming State
    @State private var isShowingPDFImportSheet: Bool = false
    @State private var pendingImportPDFURL: URL? = nil
    @State private var pendingImportTotalPages: Int = 0
    // Unified Infinite Canvas State
    @State private var isConnectorToolActive: Bool = false
    @State private var connectorRoutingMode: ConnectorRoutingType = .orthogonal

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

    private var noteHeaderView: some View {
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

                // TimeKeeper Focus Session Pill
                TimeKeeperToolbarPill(
                    timerManager: store.timerManager,
                    onOpenStats: { store.isFocusStatsPresented = true },
                    isCompact: true
                )

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
                        ForEach([0.05, 0.1, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 5.0, 10.0], id: \.self) { preset in
                            Button("\(Int(round(preset * 100)))%") {
                                 viewportNSView?.zoomTo(scale: CGFloat(preset))
                            }
                        }
                    } label: {
                        Text("\(Int(round(zoomScale * 100)))%")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .frame(width: 44)
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
    }

    private var viewportAreaView: some View {
        InkCanvasViewportRepresentable(
            docId: doc.id,
            canvasMode: doc.resolvedCanvasMode,
            templateType: store.activeInkTemplate,
            pdfPath: store.inkPages.first?.pdfPath,
            pdfPageIndex: store.inkPages.first?.pdfPageIndex,
            pagePDFInfos: computedPagePDFInfos,
            pagesStrokes: pagesStrokes,
            totalPagesCount: max(1, store.inkPages.count),
            canvasNoteCards: store.canvasNoteCards,
            spatialPDFLayouts: computedSpatialPDFLayouts,
            canvasItems: store.canvasItems,
            canvasConnectors: store.canvasConnectors,
            activeTool: store.activeInkTool,
            activeColorHex: store.activeInkColorHex,
            activeWidth: store.activeInkWidth,
            activePattern: store.activeStrokePattern,
            isRulerActive: store.isRulerActive,
            rulerAngle: store.rulerAngle,
            isShapeSnappingEnabled: store.isShapeSnappingEnabled,
            isConnectorToolActive: isConnectorToolActive,
            connectorRoutingMode: connectorRoutingMode,
            zoomScale: $zoomScale,
            isHandToolActive: $isHandToolActive,
            viewportRef: $viewportNSView,
            noteSummaryProvider: { noteDocId in
                store.fetchNoteCardSummary(noteDocId: noteDocId)
            },
            onAddNoteCard: { noteDocId, x, y in
                store.addCanvasNoteCard(canvasDocId: doc.id, noteDocId: noteDocId, x: x, y: y)
            },
            onUpdateNoteCardPosition: { cardId, x, y in
                store.updateCanvasNoteCardPosition(id: cardId, x: x, y: y)
            },
            onDeleteNoteCard: { cardId in
                store.deleteCanvasNoteCard(id: cardId)
            },
            onAddCanvasItem: { item in
                store.addCanvasItem(item)
            },
            onUpdateCanvasItemPosition: { itemId, x, y in
                store.updateCanvasItemPosition(id: itemId, x: x, y: y)
            },
            onUpdateCanvasItemSize: { itemId, w, h in
                store.updateCanvasItemSize(id: itemId, width: w, height: h)
            },
            onDeleteCanvasItem: { itemId in
                store.deleteCanvasItem(id: itemId)
            },
            onAddCanvasConnector: { sourceId, sourcePort, targetId, targetPort, routing, label in
                store.addCanvasConnector(
                    canvasDocId: doc.id,
                    fromItemId: sourceId,
                    fromPort: sourcePort,
                    toItemId: targetId,
                    toPort: targetPort,
                    routingType: routing,
                    label: label
                )
            },
            onUpdateCanvasConnectorLabel: { connectorId, label in
                store.updateCanvasConnectorLabel(id: connectorId, label: label)
            },
            onDeleteCanvasConnector: { connectorId in
                store.deleteCanvasConnector(id: connectorId)
            },
            onSelectReferencedNote: { noteDocId in
                store.selectDocument(id: noteDocId)
            },
            onUpdatePDFPageLayout: { pageIndex, x, y, w, h in
                if let targetPage = store.inkPages.first(where: { $0.pageIndex == pageIndex }) {
                    store.updateInkPageSpatialLayout(pageId: targetPage.id, canvasX: x, canvasY: y, customWidth: w, customHeight: h)
                }
            },
            onUpdatePDFPageCrop: { pageIndex, cropRect in
                if let targetPage = store.inkPages.first(where: { $0.pageIndex == pageIndex }) {
                    store.updateInkPageCrop(pageId: targetPage.id, cropRect: cropRect)
                }
            },
            onDeletePDFPage: { pageIndex in
                if let targetPage = store.inkPages.first(where: { $0.pageIndex == pageIndex }) {
                    store.deleteInkPage(pageId: targetPage.id)
                }
            },
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
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Note Header - Hidden completely in Full Screen Focus Mode
            if !store.isInkFocusMode {
                noteHeaderView
                Divider()
            }

            // Main Interactive Multi-Page / Infinite Canvas Viewport
            ZStack(alignment: .top) {
                viewportAreaView

                // Floating Dynamic Ink Toolbar - Writing tools only in focus mode!
                InkToolbarView(
                    store: store,
                    onUndo: performUndo,
                    onRedo: performRedo,
                    canUndo: !store.inkUndoStack.isEmpty,
                    canRedo: !store.inkRedoStack.isEmpty,
                    onBringToFront: {
                        viewportNSView?.bringSelectionToFront()
                    },
                    onSendToBack: {
                        viewportNSView?.sendSelectionToBack()
                    }
                )
                .padding(.top, store.isInkFocusMode ? 20 : 16)

                // Floating macOS Glass Unified Canvas Toolbar (Shapes, Connectors, Text, Media, Note Link)
                if doc.resolvedCanvasMode == .infinite2D && !store.isInkFocusMode {
                    VStack {
                        Spacer()
                        CanvasUnifiedFloatingToolbar(
                            store: store,
                            isHandToolActive: $isHandToolActive,
                            isConnectorToolActive: $isConnectorToolActive,
                            connectorRoutingMode: $connectorRoutingMode,
                            onInsertShape: { shapeType in
                                insertShape(shapeType)
                            },
                            onInsertTextBlock: {
                                insertTextBlock()
                            },
                            onPromptMediaUpload: {
                                promptMediaUpload()
                            },
                            onPromptLinkNote: {
                                promptLinkNote()
                            }
                        )
                        .padding(.bottom, 20)
                    }
                }

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

                // PDF Import Trim Sheet Overlay (Modal Backdrop that never freezes or glitches AppKit)
                if isShowingPDFImportSheet, let url = pendingImportPDFURL {
                    ZStack {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    isShowingPDFImportSheet = false
                                }
                            }

                        PDFImportTrimSheet(
                            sourceURL: url,
                            totalPages: pendingImportTotalPages,
                            onImport: { startPage, endPage in
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    isShowingPDFImportSheet = false
                                }
                                store.importTrimmedPDFPages(from: url, startPage: startPage, endPage: endPage)
                            },
                            onCancel: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    isShowingPDFImportSheet = false
                                }
                            }
                        )
                        .background(Color(NSColor.windowBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(100)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
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

    // MARK: - Canvas Item & Media Insertion Helpers
    private func insertShape(_ shapeType: CanvasShapeType) {
        let centerPoint = viewportNSView?.centerPointInCanvasCoordinates() ?? CGPoint(x: 200, y: 200)
        let item = CanvasItem(
            canvasDocId: doc.id,
            itemType: .shape,
            shapeType: shapeType,
            x: Double(centerPoint.x) - 75,
            y: Double(centerPoint.y) - 50,
            width: 150,
            height: 100,
            fillColorHex: shapeType == .diamond ? "#FEF3C7" : (shapeType == .ellipse ? "#E0E7FF" : "#EFF6FF"),
            strokeColorHex: "#3B82F6",
            strokeWidth: 2.0,
            title: shapeType == .diamond ? "Decision" : (shapeType == .ellipse ? "Start / End" : "Process Step")
        )
        store.addCanvasItem(item)
    }

    private func insertTextBlock() {
        let centerPoint = viewportNSView?.centerPointInCanvasCoordinates() ?? CGPoint(x: 200, y: 200)
        let item = CanvasItem(
            canvasDocId: doc.id,
            itemType: .textBlock,
            x: Double(centerPoint.x) - 100,
            y: Double(centerPoint.y) - 40,
            width: 200,
            height: 80,
            fillColorHex: "#FFFFFF",
            strokeColorHex: "#CBD5E1",
            strokeWidth: 1.0,
            title: "Text Block",
            markdownContent: "Double-click to edit text"
        )
        store.addCanvasItem(item)
    }

    private func promptMediaUpload() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.image, .movie, .audio, .pdf]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = true
        openPanel.prompt = "Import Media to Canvas"

        openPanel.begin { response in
            if response == .OK {
                let center = viewportNSView?.centerPointInCanvasCoordinates() ?? CGPoint(x: 200, y: 200)
                var offsetX = 0.0
                for (idx, url) in openPanel.urls.enumerated() {
                    let ext = url.pathExtension.lowercased()
                    let itemType: CanvasItemType
                    if ["jpg", "jpeg", "png", "gif", "webp", "tiff", "heic"].contains(ext) {
                        itemType = .mediaImage
                    } else if ["mp4", "mov", "m4v"].contains(ext) {
                        itemType = .mediaVideo
                    } else if ["mp3", "m4a", "wav", "aac"].contains(ext) {
                        itemType = .mediaAudio
                    } else if ext == "pdf" {
                        itemType = .mediaPDF
                    } else {
                        itemType = .mediaImage
                    }

                    if let media = try? CanvasAssetStorage.importMedia(from: url, canvasDocId: doc.id) {
                        let item = CanvasItem(
                            canvasDocId: doc.id,
                            itemType: itemType,
                            x: Double(center.x) + offsetX,
                            y: Double(center.y) + Double(idx * 30),
                            width: itemType == .mediaAudio ? 240 : 280,
                            height: itemType == .mediaAudio ? 60 : 180,
                            title: url.lastPathComponent,
                            mediaAssetKey: media.assetKey
                        )
                        store.addCanvasItem(item)
                        offsetX += 40.0
                    }
                }
            }
        }
    }

    private func promptLinkNote() {
        // Link to the first other document available, or show alert
        if let otherDoc = store.documents.first(where: { $0.id != doc.id }) {
            let centerPoint = viewportNSView?.centerPointInCanvasCoordinates() ?? CGPoint(x: 200, y: 200)
            let item = CanvasItem(
                canvasDocId: doc.id,
                itemType: .noteCard,
                linkedNoteDocId: otherDoc.id,
                x: Double(centerPoint.x) - 110,
                y: Double(centerPoint.y) - 60,
                width: 220,
                height: 120,
                fillColorHex: "#F8FAFC",
                strokeColorHex: "#94A3B8",
                strokeWidth: 1.0,
                title: otherDoc.content.isEmpty ? "Referenced Note" : otherDoc.content
            )
            store.addCanvasItem(item)
            store.attachNoteToCanvasItem(itemId: item.id, noteDocId: otherDoc.id)
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
                DispatchQueue.global(qos: .userInitiated).async {
                    let total = InkPDFImporterService.pageCount(for: url)
                    if total > 0 {
                        DispatchQueue.main.async {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                self.pendingImportPDFURL = url
                                self.pendingImportTotalPages = total
                                self.isShowingPDFImportSheet = true
                            }
                        }
                    }
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
