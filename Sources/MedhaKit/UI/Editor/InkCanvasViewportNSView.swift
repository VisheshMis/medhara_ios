import AppKit
import SwiftUI
import CoreGraphics
import PDFKit

// MARK: - Native Interactive Canvas Viewport for macOS
/// Handles high-performance vector rendering, smooth trackpad pinch-to-zoom,
/// two-finger pan, Spacebar Hand Tool, and multiple canvas modes (A4, Infinite Vertical, Infinite 2D).
public final class InkCanvasViewportNSView: NSView {
    public var docId: String
    public var canvasMode: InkCanvasMode
    public var templateType: InkTemplateType
    public var pdfPath: String? {
        didSet {
            recalculateInfiniteVerticalHeight()
            needsDisplay = true
        }
    }
    public var pdfPageIndex: Int? {
        didSet {
            recalculateInfiniteVerticalHeight()
            needsDisplay = true
        }
    }
    // Map of pageIndex -> (pdfPath, pdfPageIndex) for multi-page PDF documents
    public var pagePDFInfos: [Int: (path: String, pageIndex: Int)] = [:] {
        didSet {
            recalculateInfiniteVerticalHeight()
            needsDisplay = true
        }
    }

    // Spatial Layout and Crop Overrides per page (for 2D Infinite mode)
    // Map of pageIndex -> (canvasX, canvasY, customWidth, customHeight, cropRect)
    public var spatialPDFLayouts: [Int: (canvasX: Double, canvasY: Double, customWidth: Double?, customHeight: Double?, cropRect: CGRect?)] = [:] {
        didSet {
            needsDisplay = true
        }
    }

    // Callbacks for Spatial PDF Interactions
    public var onUpdatePDFPageLayout: ((Int, Double, Double, Double?, Double?) -> Void)?
    public var onUpdatePDFPageCrop: ((Int, CGRect?) -> Void)?
    public var onDeletePDFPage: ((Int) -> Void)?

    // Interactive Drag / Resize / Crop / Selection State for PDF Pages
    private var draggingPDFPageIndex: Int? = nil
    private var isDraggingPDFPageHeader: Bool = false
    private var pdfPageDragOffset: CGPoint = .zero

    private var resizingPDFPageIndex: Int? = nil
    private var isResizingPDFPage: Bool = false
    private var pdfPageResizeStartPoint: CGPoint = .zero
    private var pdfPageInitialSize: CGSize = .zero

    // Active Cropping Mode
    public var activeCroppingPageIndex: Int? = nil {
        didSet { needsDisplay = true }
    }
    private var isDraggingCropHandle: Bool = false
    private var activeCropHandleIndex: Int? = nil // 0: Top-Left, 1: Top-Right, 2: Bottom-Right, 3: Bottom-Left
    private var cropDragInitialCrop: CGRect = .zero

    // Native PDF Text Selection State
    public var selectedPDFText: String? = nil
    private var textSelectionPageIndex: Int? = nil
    private var textSelectionStartPt: CGPoint? = nil
    private var currentPDFSelection: PDFSelection? = nil
    private var isSelectingPDFText: Bool = false

    // Stored strokes per page: [pageIndex: [InkStroke]]
    public var pagesStrokes: [Int: [InkStroke]] = [:]
    public var totalPagesCount: Int = 1 {
        didSet {
            recalculateInfiniteVerticalHeight()
            needsDisplay = true
        }
    }

    // Viewport transform (Broadened for vast 2D spaces: 0.02x to 20.0x)
    public var zoomScale: CGFloat = 1.0 {
        didSet {
            zoomScale = min(max(zoomScale, 0.02), 20.0)
            needsDisplay = true
        }
    }
    public var panOffset: CGPoint = CGPoint(x: 40, y: 40) {
        didSet {
            needsDisplay = true
        }
    }

    // Embedded Note Cards on Canvas
    public var canvasNoteCards: [CanvasNoteCard] = [] {
        didSet {
            needsDisplay = true
        }
    }
    public var noteSummaryProvider: ((String) -> (title: String, icon: String?, snippets: [String]))?
    public var onAddNoteCard: ((String, Double, Double) -> Void)?
    public var onUpdateNoteCardPosition: ((String, Double, Double) -> Void)?
    public var onDeleteNoteCard: ((String) -> Void)?
    public var onSelectReferencedNote: ((String) -> Void)?

    // Unified Canvas Items & Connectors
    public var canvasItems: [CanvasItem] = [] {
        didSet {
            needsDisplay = true
        }
    }
    public var canvasConnectors: [CanvasConnector] = [] {
        didSet {
            needsDisplay = true
        }
    }
    public var onAddCanvasItem: ((CanvasItem) -> Void)?
    public var onUpdateCanvasItemPosition: ((String, Double, Double) -> Void)?
    public var onUpdateCanvasItemSize: ((String, Double, Double) -> Void)?
    public var onDeleteCanvasItem: ((String) -> Void)?
    public var onAddCanvasConnector: ((String, CanvasPortPosition, String, CanvasPortPosition, ConnectorRoutingType, String?) -> Void)?
    public var onUpdateCanvasConnectorLabel: ((String, String?) -> Void)?
    public var onDeleteCanvasConnector: ((String) -> Void)?

    // Item Selection & Dragging State
    public var selectedItemId: String? = nil
    private var isDraggingItem: Bool = false
    private var itemDragOffset: CGPoint = .zero
    private var isResizingItem: Bool = false
    private var itemResizeStartPoint: CGPoint = .zero
    private var itemInitialSize: CGSize = .zero

    // Dynamic Connector Wiring State
    public var isConnectorToolActive: Bool = false
    public var connectorRoutingMode: ConnectorRoutingType = .orthogonal
    private var connectorStartItemId: String? = nil
    private var connectorStartPort: CanvasPortPosition? = nil
    private var connectorCurrentPoint: CGPoint? = nil
    private var hoveredSnapPort: (itemId: String, port: CanvasPortPosition, point: CGPoint)? = nil

    // Dragging & Interaction State for Note Cards
    private var draggingCardId: String? = nil
    private var cardDragOffset: CGPoint = .zero
    private var isDraggingCard: Bool = false

    // Callbacks
    public var onZoomScaleChanged: ((CGFloat) -> Void)?
    public var onStrokesChanged: ((Int, [InkStroke]) -> Void)?
    public var onAddPage: (() -> Void)?
    public var onDeletePage: ((Int) -> Void)?
    public var onPerformUndo: (() -> Void)?
    public var onPerformRedo: (() -> Void)?
    public var onExitFocusMode: (() -> Void)?

    // Tool Settings
    public var activeTool: InkToolType = .ballpoint
    public var activeColor: NSColor = NSColor(srgbRed: 0.12, green: 0.16, blue: 0.24, alpha: 1.0)
    public var activeWidth: Double = 2.5
    public var activeOpacity: Double = 1.0

    // Hand Tool / Navigation State
    public var isHandToolActive: Bool = false {
        didSet {
            updateCursor()
        }
    }
    private var isSpacebarDown: Bool = false
    private var isPanningWithDrag: Bool = false
    private var lastPanDragLocation: CGPoint = .zero

    // Live Drawing State
    private var activeDrawingPageIndex: Int = 0
    private var livePoints: [InkPoint] = []
    private var isDrawing: Bool = false
    private var strokeStartTime: Date = Date()
    private var lastEventPoint: CGPoint = .zero
    private var lastEventTime: TimeInterval = 0

    // Lasso Selection State
    private var lassoPoints: [CGPoint] = []
    public private(set) var selectedStrokeIds: Set<String> = []
    private var isDraggingSelection: Bool = false
    private var lassoSelectionStartLocation: CGPoint = .zero

    // Tier 1: Stroke Pattern, 2D Ruler, Shape Recognition
    public var activePattern: StrokePattern = .solid
    public var isRulerActive: Bool = false {
        didSet { needsDisplay = true }
    }
    public var rulerOrigin: CGPoint = CGPoint(x: 220, y: 350)
    public var rulerAngle: CGFloat = 0.0 {
        didSet { needsDisplay = true }
    }
    public var isShapeSnappingEnabled: Bool = true
    private var shapeHoldTimer: Timer? = nil
    private var dragJitterOrigin: CGPoint = .zero

    // Canvas Dimensions
    public static let standardPageWidth: CGFloat = 794.0
    public static let standardPageHeight: CGFloat = 1123.0
    public static let pageGap: CGFloat = 40.0

    // Dynamic height for infinite vertical sheet
    private var infiniteVerticalHeight: CGFloat = 1123.0

    // Tracking Area for Mouse Cursor
    private var trackingArea: NSTrackingArea?

    public init(
        docId: String,
        canvasMode: InkCanvasMode = .a4Pages,
        templateType: InkTemplateType = .lined,
        pdfPath: String? = nil,
        pdfPageIndex: Int? = nil,
        pagePDFInfos: [Int: (path: String, pageIndex: Int)] = [:],
        pagesStrokes: [Int: [InkStroke]] = [:],
        totalPagesCount: Int = 1,
        canvasNoteCards: [CanvasNoteCard] = [],
        spatialPDFLayouts: [Int: (canvasX: Double, canvasY: Double, customWidth: Double?, customHeight: Double?, cropRect: CGRect?)] = [:],
        canvasItems: [CanvasItem] = [],
        canvasConnectors: [CanvasConnector] = []
    ) {
        self.docId = docId
        self.canvasMode = canvasMode
        self.templateType = templateType
        self.pdfPath = pdfPath
        self.pdfPageIndex = pdfPageIndex
        self.pagePDFInfos = pagePDFInfos
        self.pagesStrokes = pagesStrokes
        self.totalPagesCount = max(1, totalPagesCount)
        self.canvasNoteCards = canvasNoteCards
        self.spatialPDFLayouts = spatialPDFLayouts
        self.canvasItems = canvasItems
        self.canvasConnectors = canvasConnectors
        super.init(frame: .zero)

        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.layer?.masksToBounds = true
        self.clipsToBounds = true
        registerForDraggedTypes([
            .fileURL,
            .tiff,
            .png,
            .string,
            NSPasteboard.PasteboardType("medha.document.id")
        ])
        recalculateInfiniteVerticalHeight()
    }


    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var isFlipped: Bool {
        return true // Top-left origin coordinates
    }

    public override var wantsDefaultClipping: Bool {
        return true
    }

    public override var acceptsFirstResponder: Bool {
        return true
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        self.trackingArea = area
    }

    // MARK: - Viewport Sizing & Initial Centering
    public override func setFrameSize(_ newSize: NSSize) {
        let oldSize = bounds.size
        super.setFrameSize(newSize)
        if oldSize == .zero && newSize.width > 0 {
            centerCanvasInitially()
        }
    }

    public func centerCanvasInitially() {
        guard bounds.width > 0 else { return }
        switch canvasMode {
        case .a4Pages, .infiniteVertical:
            let contentWidth = Self.standardPageWidth * zoomScale
            let offsetX = max(40.0, (bounds.width - contentWidth) / 2.0)
            self.panOffset = CGPoint(x: offsetX, y: 40.0)
        case .infinite2D:
            self.panOffset = CGPoint(x: bounds.width / 2.0, y: bounds.height / 2.0)
        }
        needsDisplay = true
    }

    public func recalculateInfiniteVerticalHeight() {
        guard canvasMode == .infiniteVertical else { return }
        let strokes = pagesStrokes[0] ?? []
        var maxY: Double = Double(Self.standardPageHeight)
        for stroke in strokes {
            for pt in stroke.points {
                if pt.y > maxY { maxY = pt.y }
            }
        }

        // Account for imported PDF pages in vertical height
        let pdfPagesCount = max(pagePDFInfos.count, (pdfPath != nil ? 1 : 0))
        let pdfTotalHeight = CGFloat(pdfPagesCount) * (Self.standardPageHeight + Self.pageGap)

        self.infiniteVerticalHeight = max(max(Self.standardPageHeight, CGFloat(maxY) + 600.0), pdfTotalHeight)
    }

    // MARK: - Navigation Public Actions
    public func zoomTo(scale: CGFloat, centerInView: CGPoint? = nil) {
        let anchor = centerInView ?? CGPoint(x: bounds.midX, y: bounds.midY)
        let oldScale = zoomScale
        let newScale = min(max(scale, 0.02), 20.0)

        // Point on canvas under anchor before zoom
        let canvasPoint = CGPoint(
            x: (anchor.x - panOffset.x) / oldScale,
            y: (anchor.y - panOffset.y) / oldScale
        )

        self.panOffset = CGPoint(
            x: anchor.x - canvasPoint.x * newScale,
            y: anchor.y - canvasPoint.y * newScale
        )
        self.zoomScale = newScale
        onZoomScaleChanged?(newScale)
        needsDisplay = true
    }

    public func zoomIn() {
        zoomTo(scale: zoomScale * 1.25)
    }

    public func zoomOut() {
        zoomTo(scale: zoomScale / 1.25)
    }

    public func zoomToActualSize() {
        zoomTo(scale: 1.0)
    }

    public func zoomToFitWidth() {
        guard bounds.width > 80 else { return }
        let targetWidth: CGFloat = (canvasMode == .infinite2D ? 1600.0 : Self.standardPageWidth)
        let availableWidth = bounds.width - 80.0
        let targetScale = max(0.05, min(3.0, availableWidth / targetWidth))
        self.zoomScale = targetScale
        self.panOffset.x = max(20.0, (bounds.width - targetWidth * targetScale) / 2.0)
        self.panOffset.y = 40.0
        onZoomScaleChanged?(targetScale)
        needsDisplay = true
    }

    public func zoomToFitContent() {
        let allStrokes = pagesStrokes.values.flatMap { $0 }
        var contentBBox = InkGeometry.combinedBoundingBox(for: allStrokes)

        // Account for PDF pages in bounding box
        let pdfPagesCount = max(pagePDFInfos.count, (pdfPath != nil ? 1 : 0))
        if pdfPagesCount > 0 {
            let pdfHeight = CGFloat(pdfPagesCount) * (Self.standardPageHeight + Self.pageGap)
            let pdfRect = CGRect(x: 0, y: 0, width: Self.standardPageWidth, height: pdfHeight)
            if let existing = contentBBox {
                contentBBox = existing.union(pdfRect)
            } else {
                contentBBox = pdfRect
            }
        }

        // Account for embedded note cards in bounding box
        for card in canvasNoteCards {
            let cardRect = CGRect(x: card.canvasX, y: card.canvasY, width: card.canvasWidth, height: card.canvasHeight)
            if let existing = contentBBox {
                contentBBox = existing.union(cardRect)
            } else {
                contentBBox = cardRect
            }
        }

        guard let bbox = contentBBox else {
            zoomToActualSize()
            return
        }

        let padded = bbox.insetBy(dx: -60.0, dy: -60.0)
        let scaleX = bounds.width / max(100.0, padded.width)
        let scaleY = bounds.height / max(100.0, padded.height)
        let newScale = min(max(min(scaleX, scaleY), 0.02), 3.0)

        self.zoomScale = newScale
        self.panOffset = CGPoint(
            x: (bounds.width - padded.width * newScale) / 2.0 - padded.minX * newScale,
            y: (bounds.height - padded.height * newScale) / 2.0 - padded.minY * newScale
        )
        onZoomScaleChanged?(newScale)
        needsDisplay = true
    }

    // MARK: - Trackpad & Mouse Event Navigation
    public override func magnify(with event: NSEvent) {
        // Trackpad pinch-to-zoom centered on mouse pointer
        let mouseLocation = convert(event.locationInWindow, from: nil)
        let magnificationDelta = event.magnification
        let oldScale = zoomScale
        let newScale = min(max(oldScale * (1.0 + magnificationDelta), 0.02), 20.0)

        let canvasPoint = CGPoint(
            x: (mouseLocation.x - panOffset.x) / oldScale,
            y: (mouseLocation.y - panOffset.y) / oldScale
        )

        self.panOffset = CGPoint(
            x: mouseLocation.x - canvasPoint.x * newScale,
            y: mouseLocation.y - canvasPoint.y * newScale
        )
        self.zoomScale = newScale
        onZoomScaleChanged?(newScale)
        needsDisplay = true
    }

    public override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            // Cmd + Scroll Wheel to Zoom anchored at mouse
            let mouseLocation = convert(event.locationInWindow, from: nil)
            let factor: CGFloat = event.scrollingDeltaY > 0 ? 1.08 : 0.92
            zoomTo(scale: zoomScale * factor, centerInView: mouseLocation)
            return
        }

        // Smooth two-finger pan
        panOffset.x += event.scrollingDeltaX
        panOffset.y += event.scrollingDeltaY
        needsDisplay = true
    }

    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            if isHandToolActive {
                isHandToolActive = false
                updateCursor()
            }
            onExitFocusMode?()
            return
        }

        if event.keyCode == 49 { // Spacebar
            isSpacebarDown = true
            updateCursor()
            return
        }

        // Keyboard Shortcuts
        if event.modifierFlags.contains(.command) {
            if event.charactersIgnoringModifiers == "0" {
                zoomToActualSize()
                return
            } else if event.charactersIgnoringModifiers == "9" {
                zoomToFitWidth()
                return
            } else if event.charactersIgnoringModifiers == "=" || event.charactersIgnoringModifiers == "+" {
                zoomIn()
                return
            } else if event.charactersIgnoringModifiers == "-" {
                zoomOut()
                return
            } else if event.charactersIgnoringModifiers == "c" {
                // Copy selected PDF text to clipboard
                if let text = selectedPDFText, !text.isEmpty {
                    let pboard = NSPasteboard.general
                    pboard.clearContents()
                    pboard.setString(text, forType: .string)
                    return
                }
            } else if event.charactersIgnoringModifiers == "z" {
                if event.modifierFlags.contains(.shift) {
                    onPerformRedo?()
                } else {
                    onPerformUndo?()
                }
                return
            }
        }

        switch event.charactersIgnoringModifiers?.lowercased() {
        case "p":
            activeTool = .ballpoint
            needsDisplay = true
        case "f":
            activeTool = .fountain
            needsDisplay = true
        case "h":
            isHandToolActive.toggle()
        case "e":
            activeTool = .eraser
            needsDisplay = true
        case "l":
            activeTool = .lasso
            needsDisplay = true
        default:
            super.keyDown(with: event)
        }
    }

    public override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let locInView = convert(event.locationInWindow, from: nil)
        let canvasPoint = canvasPointFrom(viewPoint: locInView)

        // If hovering over PDF text in 2D mode, turn cursor to I-beam
        if canvasMode == .infinite2D && activeTool == .ballpoint {
            for pageIdx in pagePDFInfos.keys {
                let fallbackOrderIdx = pagePDFInfos.keys.sorted().firstIndex(of: pageIdx) ?? 0
                let layoutData = spatialPDFRect(for: pageIdx, fallbackOrderIndex: fallbackOrderIdx)
                let tileRect = layoutData.rect
                let cropRect = layoutData.cropRect

                if tileRect.contains(canvasPoint),
                   let info = pagePDFInfos[pageIdx],
                   let pdfURL = InkPDFImporterService.resolvePDFURL(for: info.path),
                   let pdfDoc = InkPDFImporterService.cachedPDFDocument(for: pdfURL),
                   let pdfPage = pdfDoc.page(at: info.pageIndex - 1) {
                    let pagePt = InkPDFImporterService.pdfPagePoint(from: canvasPoint, in: tileRect, page: pdfPage, cropRect: cropRect)
                    let charIdx = pdfPage.characterIndex(at: pagePt)
                    if charIdx >= 0 && charIdx < pdfPage.numberOfCharacters {
                        NSCursor.iBeam.set()
                        return
                    }
                }
            }
        }
        updateCursor()
    }

    public override func keyUp(with event: NSEvent) {
        if event.keyCode == 49 { // Spacebar
            isSpacebarDown = false
            updateCursor()
            return
        }
        super.keyUp(with: event)
    }

    private func updateCursor() {
        if isSpacebarDown || isHandToolActive {
            if isPanningWithDrag {
                NSCursor.closedHand.set()
            } else {
                NSCursor.openHand.set()
            }
        } else {
            if activeTool == .eraser {
                NSCursor.crosshair.set()
            } else if activeTool == .lasso {
                NSCursor.crosshair.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }

    // MARK: - Mouse Input (Drawing vs Panning)
    public override func mouseDown(with event: NSEvent) {
        let locInView = convert(event.locationInWindow, from: nil)

        // Hand tool panning
        if isSpacebarDown || isHandToolActive {
            isPanningWithDrag = true
            lastPanDragLocation = locInView
            updateCursor()
            return
        }

        // Ignore touches originating completely outside the canvas bounds
        guard bounds.contains(locInView) else { return }

        // Direct drawing / lasso / eraser / card interaction
        let canvasPoint = canvasPointFrom(viewPoint: locInView)
        strokeStartTime = Date()
        lastEventPoint = locInView
        lastEventTime = event.timestamp

        // Check for click/interaction on Canvas Items (Shapes, Media, Text Blocks)
        if canvasMode == .infinite2D {
            // If connector tool is active, start wiring from clicked snap port
            if isConnectorToolActive {
                for item in canvasItems.reversed() {
                    let (port, pt, dist) = item.closestPort(to: canvasPoint)
                    if dist <= 24.0 / zoomScale {
                        connectorStartItemId = item.id
                        connectorStartPort = port
                        connectorCurrentPoint = pt
                        needsDisplay = true
                        return
                    }
                }
            }

            // Check click on Canvas Items (reverse zIndex order)
            for item in canvasItems.sorted(by: { $0.zIndex > $1.zIndex }) {
                let rect = item.boundingRect

                // 1. Check Resize Handle (Bottom-Right corner)
                let handleSize: CGFloat = 20.0 / zoomScale
                let handleRect = CGRect(x: rect.maxX - handleSize, y: rect.maxY - handleSize, width: handleSize, height: handleSize)
                if selectedItemId == item.id && handleRect.contains(canvasPoint) {
                    isResizingItem = true
                    itemResizeStartPoint = canvasPoint
                    itemInitialSize = CGSize(width: item.width, height: item.height)
                    return
                }

                if rect.contains(canvasPoint) {
                    selectedItemId = item.id

                    // 2. Double click to jump to referenced note if linked
                    if event.clickCount >= 2, let noteDocId = item.linkedNoteDocId, !noteDocId.isEmpty {
                        onSelectReferencedNote?(noteDocId)
                        return
                    }

                    // 3. Item Dragging
                    isDraggingItem = true
                    itemDragOffset = CGPoint(x: canvasPoint.x - CGFloat(item.x), y: canvasPoint.y - CGFloat(item.y))
                    needsDisplay = true
                    return
                }
            }
        }

        // Check for click/interaction on Canvas Note Cards (reverse order for top-most)
        for card in canvasNoteCards.reversed() {
            let cardRect = CGRect(x: card.canvasX, y: card.canvasY, width: card.canvasWidth, height: card.canvasHeight)
            if cardRect.contains(canvasPoint) {
                // Check if user clicked Delete 'X' button (top-right 28x28)
                let deleteBtnRect = CGRect(x: cardRect.maxX - 28.0, y: cardRect.minY, width: 28.0, height: 28.0)
                if deleteBtnRect.contains(canvasPoint) {
                    onDeleteNoteCard?(card.id)
                    needsDisplay = true
                    return
                }

                // Check for double click on header to jump to referenced note
                if event.clickCount >= 2 {
                    onSelectReferencedNote?(card.noteDocId)
                    return
                }

                // Card Dragging (dragging on card top header or body)
                isDraggingCard = true
                draggingCardId = card.id
                cardDragOffset = CGPoint(x: canvasPoint.x - CGFloat(card.canvasX), y: canvasPoint.y - CGFloat(card.canvasY))
                return
            }
        }

        // Check for click/interaction on Spatial PDF Pages in 2D Mode
        if canvasMode == .infinite2D {
            let sortedPDFKeys = pagePDFInfos.keys.sorted().reversed()
            let pdfKeysToCheck: [Int] = !sortedPDFKeys.isEmpty ? Array(sortedPDFKeys) : (pdfPath != nil ? [0] : [])

            for pageIdx in pdfKeysToCheck {
                let fallbackOrderIdx = pagePDFInfos.keys.sorted().firstIndex(of: pageIdx) ?? 0
                let layoutData = spatialPDFRect(for: pageIdx, fallbackOrderIndex: fallbackOrderIdx)
                let tileRect = layoutData.rect
                let cropRect = layoutData.cropRect
                let isCropActive = (activeCroppingPageIndex == pageIdx)

                // 1. Crop Handles Hit-Testing (if crop mode is active)
                if isCropActive {
                    let unitCrop = cropRect ?? CGRect(x: 0, y: 0, width: 1, height: 1)
                    let cropCanvasRect = CGRect(
                        x: tileRect.origin.x + unitCrop.origin.x * tileRect.width,
                        y: tileRect.origin.y + unitCrop.origin.y * tileRect.height,
                        width: unitCrop.width * tileRect.width,
                        height: unitCrop.height * tileRect.height
                    )

                    let handleRadius: CGFloat = 16.0 / zoomScale
                    let corners = [
                        CGPoint(x: cropCanvasRect.minX, y: cropCanvasRect.minY), // 0: Top-Left
                        CGPoint(x: cropCanvasRect.maxX, y: cropCanvasRect.minY), // 1: Top-Right
                        CGPoint(x: cropCanvasRect.maxX, y: cropCanvasRect.maxY), // 2: Bottom-Right
                        CGPoint(x: cropCanvasRect.minX, y: cropCanvasRect.maxY)  // 3: Bottom-Left
                    ]

                    for (cIdx, corner) in corners.enumerated() {
                        let handleRect = CGRect(x: corner.x - handleRadius, y: corner.y - handleRadius, width: handleRadius * 2, height: handleRadius * 2)
                        if handleRect.contains(canvasPoint) {
                            isDraggingCropHandle = true
                            activeCropHandleIndex = cIdx
                            cropDragInitialCrop = unitCrop
                            return
                        }
                    }
                }

                // 2. Header Pill Hit-Testing
                let headerHeight: CGFloat = 34.0
                let headerRect = CGRect(x: tileRect.origin.x, y: tileRect.origin.y - headerHeight - 4.0, width: tileRect.width, height: headerHeight)

                if headerRect.contains(canvasPoint) {
                    // Check Crop Button
                    let cropBtnRect = CGRect(x: headerRect.maxX - 72.0, y: headerRect.origin.y + 4.0, width: 26.0, height: 26.0)
                    if cropBtnRect.contains(canvasPoint) {
                        if activeCroppingPageIndex == pageIdx {
                            activeCroppingPageIndex = nil
                        } else {
                            activeCroppingPageIndex = pageIdx
                        }
                        needsDisplay = true
                        return
                    }

                    // Check Delete Page Button
                    let delBtnRect = CGRect(x: headerRect.maxX - 36.0, y: headerRect.origin.y + 4.0, width: 26.0, height: 26.0)
                    if delBtnRect.contains(canvasPoint) {
                        onDeletePDFPage?(pageIdx)
                        needsDisplay = true
                        return
                    }

                    // Otherwise start dragging the PDF page
                    isDraggingPDFPageHeader = true
                    draggingPDFPageIndex = pageIdx
                    pdfPageDragOffset = CGPoint(x: canvasPoint.x - tileRect.origin.x, y: canvasPoint.y - tileRect.origin.y)
                    return
                }

                // 3. Resize Handle Hit-Testing (Bottom-Right 24x24)
                let resizeHandleRect = CGRect(x: tileRect.maxX - 24.0, y: tileRect.maxY - 24.0, width: 24.0, height: 24.0)
                if resizeHandleRect.contains(canvasPoint) {
                    isResizingPDFPage = true
                    resizingPDFPageIndex = pageIdx
                    pdfPageResizeStartPoint = canvasPoint
                    pdfPageInitialSize = tileRect.size
                    return
                }

                // 4. Native PDF Text Selection Hit-Testing
                // If user clicks inside the page tile, check if they are clicking on text or starting a text selection
                let info = pagePDFInfos[pageIdx]
                let targetPath = info?.path ?? pdfPath
                let targetPageIdx = info?.pageIndex ?? pdfPageIndex ?? 1

                if let path = targetPath,
                   let pdfURL = InkPDFImporterService.resolvePDFURL(for: path),
                   let pdfDoc = InkPDFImporterService.cachedPDFDocument(for: pdfURL),
                   let pdfPage = pdfDoc.page(at: targetPageIdx - 1),
                   tileRect.contains(canvasPoint) && activeTool == .ballpoint {

                    let pagePt = InkPDFImporterService.pdfPagePoint(from: canvasPoint, in: tileRect, page: pdfPage, cropRect: cropRect)
                    let charIdx = pdfPage.characterIndex(at: pagePt)
                    if charIdx >= 0 && charIdx < pdfPage.numberOfCharacters {
                        // User clicked directly on text; initiate text drag selection
                        isSelectingPDFText = true
                        textSelectionPageIndex = pageIdx
                        textSelectionStartPt = pagePt
                        if let sel = pdfPage.selection(for: NSRect(origin: pagePt, size: CGSize(width: 4, height: 4))) {
                            currentPDFSelection = sel
                            selectedPDFText = sel.string
                        }
                        needsDisplay = true
                        return
                    }
                }
            }
        }

        let pageIdx = pageIndexFor(canvasY: canvasPoint.y)
        self.activeDrawingPageIndex = pageIdx
        let pageRelPoint = pageRelativePoint(for: canvasPoint, pageIndex: pageIdx)

        if activeTool == .eraser {
            eraseStrokesAt(canvasPoint: pageRelPoint, pageIndex: pageIdx)
            return
        }

        if activeTool == .lasso {
            handleLassoMouseDown(at: pageRelPoint, pageIndex: pageIdx)
            return
        }

        // Check for Tape reveal/hide toggle
        let currentStrokes = pagesStrokes[pageIdx] ?? []
        for (idx, stroke) in currentStrokes.enumerated().reversed() {
            if stroke.tool == .tape {
                let b = stroke.boundingRect
                let tapeRect = CGRect(x: b.minX - 4, y: b.minY - 4, width: max(24, b.maxX - b.minX + 8), height: max(20, b.maxY - b.minY + 8))
                if tapeRect.contains(pageRelPoint) {
                    var updated = currentStrokes
                    updated[idx].isTapeRevealed = !(updated[idx].isTapeRevealed ?? false)
                    pagesStrokes[pageIdx] = updated
                    needsDisplay = true
                    onStrokesChanged?(pageIdx, updated)
                    return
                }
            }
        }

        if !selectedStrokeIds.isEmpty {
            selectedStrokeIds.removeAll()
            needsDisplay = true
        }

        isDrawing = true
        let pressure = calculatePressure(event: event, currentPoint: locInView)
        let initialPt = snapPointToRulerIfClose(pageRelPoint)
        livePoints = [InkPoint(x: Double(initialPt.x), y: Double(initialPt.y), pressure: pressure, timeOffset: 0.0)]
        needsDisplay = true

        dragJitterOrigin = locInView
        shapeHoldTimer?.invalidate()
        if isShapeSnappingEnabled {
            shapeHoldTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.checkShapeHoldTrigger()
                }
            }
        }
    }

    public override func mouseDragged(with event: NSEvent) {
        let rawLocInView = convert(event.locationInWindow, from: nil)

        if isPanningWithDrag {
            let dx = rawLocInView.x - lastPanDragLocation.x
            let dy = rawLocInView.y - lastPanDragLocation.y
            panOffset.x += dx
            panOffset.y += dy
            lastPanDragLocation = rawLocInView
            needsDisplay = true
            return
        }

        // Clamp drag coordinates strictly within canvas bounds to eliminate cross-view bleeding
        let clampedX = min(max(rawLocInView.x, 0), bounds.width)
        let clampedY = min(max(rawLocInView.y, 0), bounds.height)
        let locInView = CGPoint(x: clampedX, y: clampedY)

        let canvasPoint = canvasPointFrom(viewPoint: locInView)

        // Dynamic Connector Live Wiring Drag
        if isConnectorToolActive, connectorStartItemId != nil {
            connectorCurrentPoint = canvasPoint
            // Snap to closest port on other shapes if within threshold
            hoveredSnapPort = nil
            for item in canvasItems where item.id != connectorStartItemId {
                let (port, pt, dist) = item.closestPort(to: canvasPoint)
                if dist <= 30.0 / zoomScale {
                    hoveredSnapPort = (itemId: item.id, port: port, point: pt)
                    break
                }
            }
            needsDisplay = true
            return
        }

        // Canvas Item Dragging
        if isDraggingItem, let itemId = selectedItemId {
            let newX = Double(canvasPoint.x - itemDragOffset.x)
            let newY = Double(canvasPoint.y - itemDragOffset.y)
            if let idx = canvasItems.firstIndex(where: { $0.id == itemId }) {
                canvasItems[idx].x = newX
                canvasItems[idx].y = newY
            }
            needsDisplay = true
            return
        }

        // Canvas Item Resizing
        if isResizingItem, let itemId = selectedItemId {
            let dx = canvasPoint.x - itemResizeStartPoint.x
            let dy = canvasPoint.y - itemResizeStartPoint.y
            let newW = max(60.0, Double(itemInitialSize.width + dx))
            let newH = max(40.0, Double(itemInitialSize.height + dy))
            if let idx = canvasItems.firstIndex(where: { $0.id == itemId }) {
                canvasItems[idx].width = newW
                canvasItems[idx].height = newH
            }
            needsDisplay = true
            return
        }

        // Card Dragging
        if isDraggingCard, let cardId = draggingCardId {
            let newX = Double(canvasPoint.x - cardDragOffset.x)
            let newY = Double(canvasPoint.y - cardDragOffset.y)
            if let idx = canvasNoteCards.firstIndex(where: { $0.id == cardId }) {
                canvasNoteCards[idx].canvasX = newX
                canvasNoteCards[idx].canvasY = newY
            }
            needsDisplay = true
            return
        }

        // 1. Spatial PDF Page Header Dragging (Move Page in 2D space)
        if isDraggingPDFPageHeader, let pageIdx = draggingPDFPageIndex {
            let newX = Double(canvasPoint.x - pdfPageDragOffset.x)
            let newY = Double(canvasPoint.y - pdfPageDragOffset.y)
            var current = spatialPDFLayouts[pageIdx] ?? (canvasX: 0.0, canvasY: 0.0, customWidth: nil, customHeight: nil, cropRect: nil)
            current.canvasX = newX
            current.canvasY = newY
            spatialPDFLayouts[pageIdx] = current
            needsDisplay = true
            return
        }

        // 2. Spatial PDF Page Resizing (Drag Bottom-Right Handle)
        if isResizingPDFPage, let pageIdx = resizingPDFPageIndex {
            let dx = canvasPoint.x - pdfPageResizeStartPoint.x
            let dy = canvasPoint.y - pdfPageResizeStartPoint.y
            let newW = max(240.0, Double(pdfPageInitialSize.width + dx))
            let newH = max(320.0, Double(pdfPageInitialSize.height + dy))
            var current = spatialPDFLayouts[pageIdx] ?? (canvasX: 0.0, canvasY: 0.0, customWidth: nil, customHeight: nil, cropRect: nil)
            current.customWidth = newW
            current.customHeight = newH
            spatialPDFLayouts[pageIdx] = current
            needsDisplay = true
            return
        }

        // 3. Interactive Crop Adjustment (Drag 4 corner handles)
        if isDraggingCropHandle, let pageIdx = activeCroppingPageIndex, let handleIdx = activeCropHandleIndex {
            let fallbackOrderIdx = pagePDFInfos.keys.sorted().firstIndex(of: pageIdx) ?? 0
            let layoutData = spatialPDFRect(for: pageIdx, fallbackOrderIndex: fallbackOrderIdx)
            let tileRect = layoutData.rect

            // Normalized point in [0...1] space inside tileRect
            let normX = min(max(0.0, Double((canvasPoint.x - tileRect.minX) / tileRect.width)), 1.0)
            let normY = min(max(0.0, Double((canvasPoint.y - tileRect.minY) / tileRect.height)), 1.0)

            var crop = cropDragInitialCrop
            switch handleIdx {
            case 0: // Top-Left
                let newMaxX = crop.maxX
                let newMaxY = crop.maxY
                let newMinX = min(normX, Double(newMaxX - 0.05))
                let newMinY = min(normY, Double(newMaxY - 0.05))
                crop = CGRect(x: newMinX, y: newMinY, width: Double(newMaxX) - newMinX, height: Double(newMaxY) - newMinY)
            case 1: // Top-Right
                let newMinX = crop.minX
                let newMaxY = crop.maxY
                let newMaxX = max(normX, Double(newMinX + 0.05))
                let newMinY = min(normY, Double(newMaxY - 0.05))
                crop = CGRect(x: Double(newMinX), y: newMinY, width: newMaxX - Double(newMinX), height: Double(newMaxY) - newMinY)
            case 2: // Bottom-Right
                let newMinX = crop.minX
                let newMinY = crop.minY
                let newMaxX = max(normX, Double(newMinX + 0.05))
                let newMaxY = max(normY, Double(newMinY + 0.05))
                crop = CGRect(x: Double(newMinX), y: Double(newMinY), width: newMaxX - Double(newMinX), height: newMaxY - Double(newMinY))
            case 3: // Bottom-Left
                let newMaxX = crop.maxX
                let newMinY = crop.minY
                let newMinX = min(normX, Double(newMaxX - 0.05))
                let newMaxY = max(normY, Double(newMinY + 0.05))
                crop = CGRect(x: newMinX, y: Double(newMinY), width: Double(newMaxX) - newMinX, height: newMaxY - Double(newMinY))
            default:
                break
            }

            var current = spatialPDFLayouts[pageIdx] ?? (canvasX: 0.0, canvasY: 0.0, customWidth: nil, customHeight: nil, cropRect: nil)
            current.cropRect = crop
            spatialPDFLayouts[pageIdx] = current
            needsDisplay = true
            return
        }

        // 4. Native PDF Text Drag Selection
        if isSelectingPDFText, let pageIdx = textSelectionPageIndex, let startPt = textSelectionStartPt {
            let fallbackOrderIdx = pagePDFInfos.keys.sorted().firstIndex(of: pageIdx) ?? 0
            let layoutData = spatialPDFRect(for: pageIdx, fallbackOrderIndex: fallbackOrderIdx)
            let tileRect = layoutData.rect
            let cropRect = layoutData.cropRect

            let info = pagePDFInfos[pageIdx]
            let targetPath = info?.path ?? pdfPath
            let targetPageIdx = info?.pageIndex ?? pdfPageIndex ?? 1

            if let path = targetPath,
               let pdfURL = InkPDFImporterService.resolvePDFURL(for: path),
               let pdfDoc = InkPDFImporterService.cachedPDFDocument(for: pdfURL),
               let pdfPage = pdfDoc.page(at: targetPageIdx - 1) {
                let currentPt = InkPDFImporterService.pdfPagePoint(from: canvasPoint, in: tileRect, page: pdfPage, cropRect: cropRect)
                if let sel = pdfPage.selection(from: startPt, to: currentPt) {
                    currentPDFSelection = sel
                    selectedPDFText = sel.string
                    needsDisplay = true
                    return
                }
            }
        }

        let pageRelPoint = pageRelativePoint(for: canvasPoint, pageIndex: activeDrawingPageIndex)

        if activeTool == .eraser {
            eraseStrokesAt(canvasPoint: pageRelPoint, pageIndex: activeDrawingPageIndex)
            return
        }

        if activeTool == .lasso {
            handleLassoMouseDragged(to: pageRelPoint, pageIndex: activeDrawingPageIndex)
            return
        }

        guard isDrawing else { return }

        // Ruler edge snapping
        var activePt = snapPointToRulerIfClose(pageRelPoint)

        // Highlighter auto-straighten horizontal lock
        if activeTool == .highlighter, let firstPt = livePoints.first, livePoints.count >= 6 {
            let dx = abs(activePt.x - CGFloat(firstPt.x))
            let dy = abs(activePt.y - CGFloat(firstPt.y))
            if dx > 40.0 && dy < 14.0 {
                activePt.y = CGFloat(firstPt.y)
            }
        }

        let pressure = calculatePressure(event: event, currentPoint: locInView)
        let elapsed = Date().timeIntervalSince(strokeStartTime)
        livePoints.append(InkPoint(x: Double(activePt.x), y: Double(activePt.y), pressure: pressure, timeOffset: elapsed))

        // Reset shape timer if finger/stylus moved appreciably
        if hypot(locInView.x - dragJitterOrigin.x, locInView.y - dragJitterOrigin.y) > 8.0 {
            dragJitterOrigin = locInView
            shapeHoldTimer?.invalidate()
            if isShapeSnappingEnabled {
                shapeHoldTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.checkShapeHoldTrigger()
                    }
                }
            }
        }

        lastEventPoint = locInView
        lastEventTime = event.timestamp

        // Expand infinite vertical sheet height dynamically if drawing extends down
        if canvasMode == .infiniteVertical && canvasPoint.y + 400.0 > infiniteVerticalHeight {
            infiniteVerticalHeight = canvasPoint.y + 600.0
        }

        needsDisplay = true
    }

    public override func mouseUp(with event: NSEvent) {
        shapeHoldTimer?.invalidate()
        shapeHoldTimer = nil

        // Commit Dynamic Connector Wiring
        if isConnectorToolActive, let startId = connectorStartItemId, let startPort = connectorStartPort {
            if let target = hoveredSnapPort {
                onAddCanvasConnector?(startId, startPort, target.itemId, target.port, connectorRoutingMode, nil)
            }
            connectorStartItemId = nil
            connectorStartPort = nil
            connectorCurrentPoint = nil
            hoveredSnapPort = nil
            needsDisplay = true
            return
        }

        // Commit Canvas Item Dragging
        if isDraggingItem, let itemId = selectedItemId {
            isDraggingItem = false
            if let item = canvasItems.first(where: { $0.id == itemId }) {
                onUpdateCanvasItemPosition?(item.id, item.x, item.y)
            }
            needsDisplay = true
            return
        }

        // Commit Canvas Item Resizing
        if isResizingItem, let itemId = selectedItemId {
            isResizingItem = false
            if let item = canvasItems.first(where: { $0.id == itemId }) {
                onUpdateCanvasItemSize?(item.id, item.width, item.height)
            }
            needsDisplay = true
            return
        }

        if isDraggingCard, let cardId = draggingCardId {
            if let card = canvasNoteCards.first(where: { $0.id == cardId }) {
                onUpdateNoteCardPosition?(card.id, card.canvasX, card.canvasY)
            }
            isDraggingCard = false
            draggingCardId = nil
            return
        }

        // Commit Spatial PDF Header Dragging Position
        if isDraggingPDFPageHeader, let pageIdx = draggingPDFPageIndex {
            isDraggingPDFPageHeader = false
            draggingPDFPageIndex = nil
            if let layout = spatialPDFLayouts[pageIdx] {
                onUpdatePDFPageLayout?(pageIdx, layout.canvasX, layout.canvasY, layout.customWidth, layout.customHeight)
            }
            needsDisplay = true
            return
        }

        // Commit Spatial PDF Page Resizing
        if isResizingPDFPage, let pageIdx = resizingPDFPageIndex {
            isResizingPDFPage = false
            resizingPDFPageIndex = nil
            if let layout = spatialPDFLayouts[pageIdx] {
                onUpdatePDFPageLayout?(pageIdx, layout.canvasX, layout.canvasY, layout.customWidth, layout.customHeight)
            }
            needsDisplay = true
            return
        }

        // Commit Interactive Crop Handle Adjustment
        if isDraggingCropHandle, let pageIdx = activeCroppingPageIndex {
            isDraggingCropHandle = false
            activeCropHandleIndex = nil
            if let layout = spatialPDFLayouts[pageIdx] {
                onUpdatePDFPageCrop?(pageIdx, layout.cropRect)
            }
            needsDisplay = true
            return
        }

        // Finalize Text Selection
        if isSelectingPDFText {
            isSelectingPDFText = false
            textSelectionStartPt = nil
            needsDisplay = true
            return
        }

        if isPanningWithDrag {
            isPanningWithDrag = false
            updateCursor()
            return
        }

        if activeTool == .eraser { return }

        if activeTool == .lasso {
            let locInView = convert(event.locationInWindow, from: nil)
            let canvasPoint = canvasPointFrom(viewPoint: locInView)
            let pageRelPoint = pageRelativePoint(for: canvasPoint, pageIndex: activeDrawingPageIndex)
            handleLassoMouseUp(at: pageRelPoint, pageIndex: activeDrawingPageIndex)
            return
        }

        guard isDrawing, !livePoints.isEmpty else {
            isDrawing = false
            livePoints.removeAll()
            return
        }

        let isTape = (activeTool == .tape)
        let newStroke = InkStroke(
            tool: activeTool,
            colorHex: isTape ? "#F59E0B" : activeColor.toHex(),
            baseWidth: isTape ? max(24.0, activeWidth * 5.0) : activeWidth,
            opacity: activeOpacity,
            points: livePoints,
            pattern: isTape ? .solid : activePattern,
            isTapeRevealed: false
        )

        var pageList = pagesStrokes[activeDrawingPageIndex] ?? []
        pageList.append(newStroke)
        pagesStrokes[activeDrawingPageIndex] = pageList
        livePoints.removeAll()
        isDrawing = false

        recalculateInfiniteVerticalHeight()
        needsDisplay = true
        onStrokesChanged?(activeDrawingPageIndex, pageList)
    }

    // MARK: - Coordinate Transformations
    public func canvasPointFrom(viewPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: (viewPoint.x - panOffset.x) / zoomScale,
            y: (viewPoint.y - panOffset.y) / zoomScale
        )
    }

    public func viewPointFrom(canvasPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: canvasPoint.x * zoomScale + panOffset.x,
            y: canvasPoint.y * zoomScale + panOffset.y
        )
    }

    public func centerPointInCanvasCoordinates() -> CGPoint {
        let centerInView = CGPoint(x: bounds.midX, y: bounds.midY)
        return canvasPointFrom(viewPoint: centerInView)
    }

    private func pageIndexFor(canvasY: CGFloat) -> Int {
        switch canvasMode {
        case .a4Pages:
            let step = Self.standardPageHeight + Self.pageGap
            let idx = Int(floor(max(0, canvasY) / step))
            return max(0, min(totalPagesCount - 1, idx))
        case .infiniteVertical, .infinite2D:
            return 0
        }
    }

    private func pageRelativePoint(for canvasPoint: CGPoint, pageIndex: Int) -> CGPoint {
        switch canvasMode {
        case .a4Pages:
            let offsetY = CGFloat(pageIndex) * (Self.standardPageHeight + Self.pageGap)
            return CGPoint(x: canvasPoint.x, y: canvasPoint.y - offsetY)
        case .infiniteVertical, .infinite2D:
            return canvasPoint
        }
    }

    // MARK: - Drawing & Rendering Pipeline
    public override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Hard boundary clip to prevent any stroke or background bleed outside the viewport NSView
        context.saveGState()
        context.clip(to: bounds)

        // Desk Background
        context.setFillColor(NSColor(calibratedWhite: 0.94, alpha: 1.0).cgColor)
        context.fill(bounds)

        context.saveGState()
        context.translateBy(x: panOffset.x, y: panOffset.y)
        context.scaleBy(x: zoomScale, y: zoomScale)

        switch canvasMode {
        case .a4Pages:
            drawA4PagesMode(in: context)
        case .infiniteVertical:
            drawInfiniteVerticalMode(in: context)
        case .infinite2D:
            drawInfinite2DMode(in: context)
        }

        if isRulerActive {
            drawRulerOverlay(in: context)
        }

        context.restoreGState() // restores transform
        context.restoreGState() // restores bounds clip
    }

    // MARK: - Mode 1: A4 Multi-Page Rendering
    private func drawA4PagesMode(in context: CGContext) {
        let width = Self.standardPageWidth
        let height = Self.standardPageHeight
        let gap = Self.pageGap

        for pageIdx in 0..<totalPagesCount {
            let pageY = CGFloat(pageIdx) * (height + gap)
            let pageRect = CGRect(x: 0, y: pageY, width: width, height: height)

            // Page drop shadow & paper rect
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: -4), blur: 12, color: NSColor.black.withAlphaComponent(0.12).cgColor)
            context.setFillColor(NSColor.white.cgColor)
            context.fill(pageRect)
            context.restoreGState()

            // Page Background Template inside pageRect
            context.saveGState()
            context.clip(to: pageRect)
            context.translateBy(x: 0, y: pageY)

            drawTemplateLines(template: templateType, width: width, height: height, in: context)

            // Render PDF background if this page has one
            let targetPDF: (path: String, pageIndex: Int)? = pagePDFInfos[pageIdx] ?? (pageIdx == 0 && pdfPath != nil && pdfPageIndex != nil ? (pdfPath!, pdfPageIndex!) : nil)
            if let pdf = targetPDF,
               let pdfURL = InkPDFImporterService.resolvePDFURL(for: pdf.path) {
                InkPDFImporterService.renderPDFPage(from: pdfURL, pageIndex: pdf.pageIndex, in: context, targetRect: CGRect(x: 0, y: 0, width: width, height: height))
            }

            // Render committed strokes
            let pageStrokes = pagesStrokes[pageIdx] ?? []
            for stroke in pageStrokes where stroke.tool == .highlighter {
                renderStroke(stroke, in: context)
            }
            for stroke in pageStrokes where stroke.tool != .highlighter {
                renderStroke(stroke, in: context)
            }

            // Live stroke overlay for this page
            if isDrawing && activeDrawingPageIndex == pageIdx && !livePoints.isEmpty {
                drawLiveStroke(in: context)
            }

            // Lasso overlay for this page
            if activeDrawingPageIndex == pageIdx && (activeTool == .lasso || !selectedStrokeIds.isEmpty) {
                drawLassoOverlay(in: context, strokes: pageStrokes)
            }

            context.restoreGState()

            // Draw small page index tag above sheet
            drawPageLabel(index: pageIdx + 1, at: CGPoint(x: 0, y: pageY - 18.0), in: context)
        }
    }

    // MARK: - Mode 2: Infinite Long Sheet Rendering
    private func drawInfiniteVerticalMode(in context: CGContext) {
        let width = Self.standardPageWidth
        let height = max(Self.standardPageHeight, infiniteVerticalHeight)
        let sheetRect = CGRect(x: 0, y: 0, width: width, height: height)

        // Seamless continuous sheet shadow & paper
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -4), blur: 14, color: NSColor.black.withAlphaComponent(0.12).cgColor)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(sheetRect)
        context.restoreGState()

        // Background template from 0 to dynamic height
        context.saveGState()
        context.clip(to: sheetRect)

        drawTemplateLines(template: templateType, width: width, height: height, in: context)

        // Render imported PDF pages stacked vertically down the continuous sheet
        let sortedPDFKeys = pagePDFInfos.keys.sorted()
        if !sortedPDFKeys.isEmpty {
            for (idx, pageIdx) in sortedPDFKeys.enumerated() {
                if let info = pagePDFInfos[pageIdx],
                   let pdfURL = InkPDFImporterService.resolvePDFURL(for: info.path) {
                    let pageY = CGFloat(idx) * (Self.standardPageHeight + Self.pageGap)
                    let pageTargetRect = CGRect(x: 0, y: pageY, width: width, height: Self.standardPageHeight)
                    InkPDFImporterService.renderPDFPage(from: pdfURL, pageIndex: info.pageIndex, in: context, targetRect: pageTargetRect)
                }
            }
        } else if let path = pdfPath, let pIdx = pdfPageIndex,
                  let pdfURL = InkPDFImporterService.resolvePDFURL(for: path) {
            let pageTargetRect = CGRect(x: 0, y: 0, width: width, height: Self.standardPageHeight)
            InkPDFImporterService.renderPDFPage(from: pdfURL, pageIndex: pIdx, in: context, targetRect: pageTargetRect)
        }

        // Render embedded note cards
        drawCanvasNoteCards(in: context)

        let strokes = pagesStrokes[0] ?? []
        for stroke in strokes where stroke.tool == .highlighter {
            renderStroke(stroke, in: context)
        }
        for stroke in strokes where stroke.tool != .highlighter {
            renderStroke(stroke, in: context)
        }

        if isDrawing && !livePoints.isEmpty {
            drawLiveStroke(in: context)
        }

        if activeTool == .lasso || !selectedStrokeIds.isEmpty {
            drawLassoOverlay(in: context, strokes: strokes)
        }

        context.restoreGState()
    }

    // MARK: - Mode 3: Open Space 2D Infinite Rendering
    private func drawInfinite2DMode(in context: CGContext) {
        // Visible canvas rect in canvas coordinates
        let minX = -panOffset.x / zoomScale
        let minY = -panOffset.y / zoomScale
        let maxX = (bounds.width - panOffset.x) / zoomScale
        let maxY = (bounds.height - panOffset.y) / zoomScale
        let visibleRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

        // Draw white base
        context.setFillColor(NSColor(calibratedRed: 0.99, green: 0.99, blue: 0.99, alpha: 1.0).cgColor)
        context.fill(visibleRect)

        // Draw continuous tiling pattern across entire visible 2D space
        drawInfiniteTilingGrid(in: context, visibleRect: visibleRect)

        // Render imported PDF pages as spatial document tiles in 2D space with paper shadow
        let sortedPDFKeys = pagePDFInfos.keys.sorted()
        if !sortedPDFKeys.isEmpty {
            for (idx, pageIdx) in sortedPDFKeys.enumerated() {
                if let info = pagePDFInfos[pageIdx],
                   let pdfURL = InkPDFImporterService.resolvePDFURL(for: info.path) {
                    let layoutData = spatialPDFRect(for: pageIdx, fallbackOrderIndex: idx)
                    let pageTargetRect = layoutData.rect
                    let cropRect = layoutData.cropRect

                    // Page drop shadow & paper rect
                    context.saveGState()
                    context.setShadow(offset: CGSize(width: 0, height: -4), blur: 12, color: NSColor.black.withAlphaComponent(0.12).cgColor)
                    context.setFillColor(NSColor.white.cgColor)
                    context.fill(pageTargetRect)
                    context.restoreGState()

                    // Render PDF page content (with crop if specified)
                    InkPDFImporterService.renderPDFPage(from: pdfURL, pageIndex: info.pageIndex, in: context, targetRect: pageTargetRect, cropRect: cropRect)

                    // Draw Native PDF Text Selection Highlight if this page has an active selection
                    if textSelectionPageIndex == pageIdx, let selection = currentPDFSelection,
                       let pdfDoc = InkPDFImporterService.cachedPDFDocument(for: pdfURL),
                       let pdfPage = pdfDoc.page(at: info.pageIndex - 1) {
                        context.saveGState()
                        context.setFillColor(NSColor.selectedTextBackgroundColor.withAlphaComponent(0.35).cgColor)
                        let selBounds = selection.bounds(for: pdfPage)
                        if selBounds.width > 0 && selBounds.height > 0 {
                            let mappedRect = InkPDFImporterService.targetRect(from: selBounds, in: pageTargetRect, page: pdfPage, cropRect: cropRect)
                            context.fill(mappedRect)
                        }
                        context.restoreGState()
                    }

                    // Draw interactive spatial header pill (Page title, Crop ✂︎, Delete ✕, and Resize handle)
                    let isCropActive = (activeCroppingPageIndex == pageIdx)
                    drawSpatialPDFHeader(pageIndex: pageIdx, tileRect: pageTargetRect, isCropActive: isCropActive, in: context)

                    // Draw crop handles and dark overlay if in Crop Mode
                    if isCropActive {
                        drawCropOverlay(for: pageIdx, tileRect: pageTargetRect, in: context)
                    }
                }
            }
        } else if let path = pdfPath, let pIdx = pdfPageIndex,
                  let pdfURL = InkPDFImporterService.resolvePDFURL(for: path) {
            let layoutData = spatialPDFRect(for: 0, fallbackOrderIndex: 0)
            let pageTargetRect = layoutData.rect
            let cropRect = layoutData.cropRect

            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: -4), blur: 12, color: NSColor.black.withAlphaComponent(0.12).cgColor)
            context.setFillColor(NSColor.white.cgColor)
            context.fill(pageTargetRect)
            context.restoreGState()

            InkPDFImporterService.renderPDFPage(from: pdfURL, pageIndex: pIdx, in: context, targetRect: pageTargetRect, cropRect: cropRect)

            if textSelectionPageIndex == 0, let selection = currentPDFSelection,
               let pdfDoc = InkPDFImporterService.cachedPDFDocument(for: pdfURL),
               let pdfPage = pdfDoc.page(at: pIdx - 1) {
                context.saveGState()
                context.setFillColor(NSColor.selectedTextBackgroundColor.withAlphaComponent(0.35).cgColor)
                let selBounds = selection.bounds(for: pdfPage)
                if selBounds.width > 0 && selBounds.height > 0 {
                    let mappedRect = InkPDFImporterService.targetRect(from: selBounds, in: pageTargetRect, page: pdfPage, cropRect: cropRect)
                    context.fill(mappedRect)
                }
                context.restoreGState()
            }

            let isCropActive = (activeCroppingPageIndex == 0)
            drawSpatialPDFHeader(pageIndex: 0, tileRect: pageTargetRect, isCropActive: isCropActive, in: context)

            if isCropActive {
                drawCropOverlay(for: 0, tileRect: pageTargetRect, in: context)
            }
        }

        // Render unified canvas connectors (behind shapes and cards)
        drawCanvasConnectors(in: context)

        // Render live rubberband connector if wiring
        drawLiveConnectorWire(in: context)

        // Render unified canvas items (shapes, media, text blocks)
        drawCanvasItems(in: context)

        // Render embedded note cards in 2D space
        drawCanvasNoteCards(in: context)

        // Render strokes
        let strokes = pagesStrokes[0] ?? []
        for stroke in strokes where stroke.tool == .highlighter {
            renderStroke(stroke, in: context)
        }
        for stroke in strokes where stroke.tool != .highlighter {
            renderStroke(stroke, in: context)
        }

        if isDrawing && !livePoints.isEmpty {
            drawLiveStroke(in: context)
        }

        if activeTool == .lasso || !selectedStrokeIds.isEmpty {
            drawLassoOverlay(in: context, strokes: strokes)
        }
    }

    private func drawCanvasNoteCards(in context: CGContext) {
        guard !canvasNoteCards.isEmpty else { return }

        for card in canvasNoteCards {
            let cardRect = CGRect(x: card.canvasX, y: card.canvasY, width: card.canvasWidth, height: card.canvasHeight)
            let isDraggingThis = isDraggingCard && draggingCardId == card.id

            // 1. Drop shadow & card container background
            context.saveGState()
            let shadowBlur: CGFloat = isDraggingThis ? 18.0 : 10.0
            let shadowAlpha: CGFloat = isDraggingThis ? 0.22 : 0.12
            context.setShadow(
                offset: CGSize(width: 0, height: isDraggingThis ? -6 : -3),
                blur: shadowBlur,
                color: NSColor.black.withAlphaComponent(shadowAlpha).cgColor
            )

            let cornerRadius: CGFloat = 12.0
            let cardPath = CGPath(roundedRect: cardRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

            context.addPath(cardPath)
            context.setFillColor(NSColor.windowBackgroundColor.cgColor)
            context.fillPath()
            context.restoreGState()

            // 2. Card outline border
            context.saveGState()
            context.addPath(cardPath)
            context.setStrokeColor(isDraggingThis ? NSColor.systemBlue.cgColor : NSColor.separatorColor.cgColor)
            context.setLineWidth((isDraggingThis ? 2.0 : 1.0) / zoomScale)
            context.strokePath()
            context.restoreGState()

            // 3. Card Header Banner (Top 42 points)
            let headerRect = CGRect(x: cardRect.origin.x, y: cardRect.origin.y, width: cardRect.width, height: 42.0)
            context.saveGState()
            context.clip(to: cardRect)

            context.setFillColor(NSColor.controlBackgroundColor.cgColor)
            context.fill(headerRect)

            context.setStrokeColor(NSColor.separatorColor.withAlphaComponent(0.5).cgColor)
            context.setLineWidth(1.0 / zoomScale)
            context.move(to: CGPoint(x: headerRect.minX, y: headerRect.maxY))
            context.addLine(to: CGPoint(x: headerRect.maxX, y: headerRect.maxY))
            context.strokePath()

            // Fetch summary info
            let summary = noteSummaryProvider?(card.noteDocId) ?? (title: "Note", icon: "doc.text", snippets: [])

            // Document Title text in Header
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .bold),
                .foregroundColor: NSColor.labelColor
            ]
            let titleStr = "📄 \(summary.title)" as NSString
            let titleDrawRect = CGRect(x: headerRect.minX + 12.0, y: headerRect.minY + 11.0, width: headerRect.width - 44.0, height: 20.0)
            titleStr.draw(in: titleDrawRect, withAttributes: titleAttrs)

            // Delete 'x' Button in top right
            let closeAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .bold),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            ("✕" as NSString).draw(at: CGPoint(x: headerRect.maxX - 22.0, y: headerRect.minY + 10.0), withAttributes: closeAttrs)

            // 4. Card Body: Text Snippets
            let bodyRect = CGRect(x: cardRect.origin.x + 14.0, y: cardRect.origin.y + 52.0, width: cardRect.width - 28.0, height: cardRect.height - 60.0)
            let snippetText = summary.snippets.isEmpty ? "(No content yet — double-click to open)" : summary.snippets.joined(separator: "\n\n")

            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11.5, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            (snippetText as NSString).draw(in: bodyRect, withAttributes: bodyAttrs)

            context.restoreGState()
        }
    }

    // MARK: - Unified Canvas Items & Connectors Rendering with LOD Zoom Engine
    private func drawCanvasConnectors(in context: CGContext) {
        guard !canvasConnectors.isEmpty else { return }

        // Map items by ID for quick port resolution
        let itemMap = Dictionary(uniqueKeysWithValues: canvasItems.map { ($0.id, $0) })

        for conn in canvasConnectors {
            guard let fromItem = itemMap[conn.fromItemId],
                  let toItem = itemMap[conn.toItemId] else { continue }

            let startPt = fromItem.portPoint(for: conn.fromPort)
            let endPt = toItem.portPoint(for: conn.toPort)

            let route = CanvasRoutingService.computeRoute(
                from: startPt,
                startPort: conn.fromPort,
                to: endPt,
                endPort: conn.toPort,
                routingType: conn.routingType
            )

            let strokeColor = NSColor(hex: conn.strokeColorHex) ?? NSColor(calibratedRed: 0.39, green: 0.45, blue: 0.55, alpha: 1.0)

            context.saveGState()
            context.addPath(route.path)
            context.setStrokeColor(strokeColor.cgColor)
            context.setLineWidth(CGFloat(conn.strokeWidth) / zoomScale)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.strokePath()

            // Draw arrowhead if required
            if conn.arrowType == .endArrow || conn.arrowType == .bothArrows {
                CanvasRoutingService.drawArrowhead(
                    at: endPt,
                    angle: route.endAngle,
                    size: 11.0 / zoomScale,
                    color: strokeColor,
                    in: context
                )
            }
            context.restoreGState()

            // Render Center Label Pill (Medium & Deep Detail LOD only: zoom >= 0.35)
            if zoomScale >= 0.35, let label = conn.label, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                drawConnectorLabelPill(text: label, at: route.midPoint, strokeColor: strokeColor, in: context)
            }
        }
    }

    private func drawConnectorLabelPill(text: String, at centerPt: CGPoint, strokeColor: NSColor, in context: CGContext) {
        let font = NSFont.systemFont(ofSize: max(10, min(13, 12 / zoomScale)), weight: .semibold)
        let str = text as NSString
        let textSize = str.size(withAttributes: [.font: font])
        let pillW = textSize.width + 16.0 / zoomScale
        let pillH = max(20.0 / zoomScale, textSize.height + 6.0 / zoomScale)
        let pillRect = CGRect(x: centerPt.x - pillW / 2.0, y: centerPt.y - pillH / 2.0, width: pillW, height: pillH)

        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -2), blur: 6.0, color: NSColor.black.withAlphaComponent(0.15).cgColor)
        let pillPath = CGPath(roundedRect: pillRect, cornerWidth: pillH / 2.0, cornerHeight: pillH / 2.0, transform: nil)
        context.addPath(pillPath)
        context.setFillColor(NSColor.windowBackgroundColor.cgColor)
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addPath(pillPath)
        context.setStrokeColor(strokeColor.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(1.0 / zoomScale)
        context.strokePath()

        let textRect = CGRect(x: pillRect.minX + 8.0 / zoomScale, y: pillRect.midY - textSize.height / 2.0, width: textSize.width, height: textSize.height)
        str.draw(in: textRect, withAttributes: [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ])
        context.restoreGState()
    }

    private func drawLiveConnectorWire(in context: CGContext) {
        guard isConnectorToolActive,
              let startId = connectorStartItemId,
              let startPort = connectorStartPort,
              let curPt = connectorCurrentPoint,
              let fromItem = canvasItems.first(where: { $0.id == startId }) else { return }

        let startPt = fromItem.portPoint(for: startPort)
        let endPt = hoveredSnapPort?.point ?? curPt
        let endPort = hoveredSnapPort?.port ?? .left

        let route = CanvasRoutingService.computeRoute(
            from: startPt,
            startPort: startPort,
            to: endPt,
            endPort: endPort,
            routingType: connectorRoutingMode
        )

        context.saveGState()
        context.addPath(route.path)
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(2.5 / zoomScale)
        let dash: [CGFloat] = [6.0 / zoomScale, 4.0 / zoomScale]
        context.setLineDash(phase: 0, lengths: dash)
        context.strokePath()

        CanvasRoutingService.drawArrowhead(at: endPt, angle: route.endAngle, size: 12.0 / zoomScale, color: NSColor.systemBlue, in: context)
        context.restoreGState()
    }

    private func drawCanvasItems(in context: CGContext) {
        guard !canvasItems.isEmpty else { return }

        for item in canvasItems.sorted(by: { $0.zIndex < $1.zIndex }) {
            let itemRect = item.boundingRect
            let isSelected = (selectedItemId == item.id)

            // 1. Semantic Level-of-Detail (LOD):
            // - Macro View (zoomScale < 0.35): High-contrast clean silhouettes, title, zero clutter
            // - Medium View (0.35 <= zoomScale < 1.0): Normal shape, previews, badges, 2-line snippets
            // - Deep Detail View (zoomScale >= 1.0): Full rich detail, high-res media, controls
            let isMacro = (zoomScale < 0.35)
            let isDeepDetail = (zoomScale >= 1.0)

            // 2. Render Base Shape / Frame
            context.saveGState()

            // Drop Shadow
            if !isMacro {
                let shadowBlur: CGFloat = isSelected ? 16.0 : 8.0
                let shadowAlpha: CGFloat = isSelected ? 0.25 : 0.12
                context.setShadow(
                    offset: CGSize(width: 0, height: isSelected ? -5 : -3),
                    blur: shadowBlur,
                    color: NSColor.black.withAlphaComponent(shadowAlpha).cgColor
                )
            }

            let shapePath = createShapePath(for: item, rect: itemRect)
            context.addPath(shapePath)

            // Fill
            let defaultFill = item.itemType == .shape ? NSColor.controlBackgroundColor : NSColor.windowBackgroundColor
            let fillColor = item.fillColorHex != nil ? (NSColor(hex: item.fillColorHex!) ?? defaultFill) : defaultFill
            context.setFillColor(fillColor.cgColor)
            context.fillPath()
            context.restoreGState()

            // Stroke
            context.saveGState()
            context.addPath(shapePath)
            let defaultStroke = isSelected ? NSColor.systemBlue : NSColor.separatorColor
            let strokeColor = item.strokeColorHex != nil ? (NSColor(hex: item.strokeColorHex!) ?? defaultStroke) : defaultStroke
            let borderWidth = (isSelected ? max(2.5, item.strokeWidth * 1.5) : item.strokeWidth) / zoomScale
            context.setStrokeColor((isSelected ? NSColor.systemBlue : strokeColor).cgColor)
            context.setLineWidth(borderWidth)
            context.strokePath()
            context.restoreGState()

            // 3. Render Content by Item Type
            switch item.itemType {
            case .shape:
                drawShapeContent(item: item, rect: itemRect, isMacro: isMacro, isDeepDetail: isDeepDetail, in: context)
            case .mediaImage, .mediaVideo, .mediaPDF:
                drawMediaContent(item: item, rect: itemRect, isMacro: isMacro, isDeepDetail: isDeepDetail, in: context)
            case .mediaAudio:
                drawAudioContent(item: item, rect: itemRect, isMacro: isMacro, isDeepDetail: isDeepDetail, in: context)
            case .textBlock, .noteCard:
                drawTextOrCardContent(item: item, rect: itemRect, isMacro: isMacro, isDeepDetail: isDeepDetail, in: context)
            }

            // 4. Render Universal Note Link Badge if linked (Medium & Deep Detail LOD only)
            if !isMacro, let noteId = item.linkedNoteDocId, !noteId.isEmpty {
                drawNoteLinkBadge(item: item, in: context)
            }

            // 5. Render Magnetic Snap Ports when connector tool is active or hovered
            if isConnectorToolActive {
                drawMagneticSnapPorts(for: item, in: context)
            }

            // 6. Corner Resize Handle (if selected)
            if isSelected {
                drawItemResizeHandle(for: item, in: context)
            }
        }
    }

    private func createShapePath(for item: CanvasItem, rect: CGRect) -> CGPath {
        let shape = item.shapeType ?? .roundedRectangle
        let path = CGMutablePath()

        switch shape {
        case .rectangle:
            path.addRect(rect)
        case .roundedRectangle, .group:
            let cr = CGFloat(item.cornerRadius)
            path.addRoundedRect(in: rect, cornerWidth: cr, cornerHeight: cr)
        case .ellipse:
            path.addEllipse(in: rect)
        case .diamond:
            // Decision Diamond Node
            path.move(to: CGPoint(x: rect.midX, y: rect.minY)) // Top
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)) // Right
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY)) // Bottom
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY)) // Left
            path.closeSubpath()
        }
        return path
    }

    private func drawShapeContent(item: CanvasItem, rect: CGRect, isMacro: Bool, isDeepDetail: Bool, in context: CGContext) {
        guard let title = item.title, !title.isEmpty else { return }

        let fontSize: CGFloat = isMacro ? max(12, min(24, 18 / zoomScale)) : 14.0
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]

        let titleStr = title as NSString
        let textSize = titleStr.size(withAttributes: titleAttrs)
        let textRect = CGRect(x: rect.midX - textSize.width / 2.0, y: rect.midY - textSize.height / 2.0, width: textSize.width, height: textSize.height)

        context.saveGState()
        context.clip(to: rect)
        titleStr.draw(in: textRect, withAttributes: titleAttrs)
        context.restoreGState()
    }

    private func drawMediaContent(item: CanvasItem, rect: CGRect, isMacro: Bool, isDeepDetail: Bool, in context: CGContext) {
        guard let key = item.mediaAssetKey else { return }

        if isMacro {
            // Silhouette icon representation
            let iconStr = (item.itemType == .mediaVideo ? "🎬 Video" : (item.itemType == .mediaPDF ? "📑 PDF" : "🖼️ Image")) as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: max(11, 14 / zoomScale), weight: .bold),
                .foregroundColor: NSColor.labelColor
            ]
            let sz = iconStr.size(withAttributes: attrs)
            iconStr.draw(at: CGPoint(x: rect.midX - sz.width / 2.0, y: rect.midY - sz.height / 2.0), withAttributes: attrs)
            return
        }

        // Render cached thumbnail or image
        if let thumb = CanvasAssetStorage.thumbnail(for: key), let cgThumb = thumb.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.saveGState()
            let cr = CGFloat(item.cornerRadius)
            let clipPath = CGPath(roundedRect: rect, cornerWidth: cr, cornerHeight: cr, transform: nil)
            context.addPath(clipPath)
            context.clip()

            // CoreGraphics flipped coordinate image drawing
            context.translateBy(x: rect.minX, y: rect.maxY)
            context.scaleBy(x: 1.0, y: -1.0)
            context.draw(cgThumb, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
            context.restoreGState()

            // Play badge for videos
            if item.itemType == .mediaVideo {
                let badgeSize: CGFloat = 36.0 / zoomScale
                let badgeRect = CGRect(x: rect.midX - badgeSize / 2.0, y: rect.midY - badgeSize / 2.0, width: badgeSize, height: badgeSize)
                context.saveGState()
                context.setFillColor(NSColor.black.withAlphaComponent(0.65).cgColor)
                context.fillEllipse(in: badgeRect)
                ("▶" as NSString).draw(at: CGPoint(x: badgeRect.midX - 5.0 / zoomScale, y: badgeRect.midY - 8.0 / zoomScale), withAttributes: [
                    .font: NSFont.systemFont(ofSize: 13 / zoomScale, weight: .bold),
                    .foregroundColor: NSColor.white
                ])
                context.restoreGState()
            }
        }
    }

    private func drawAudioContent(item: CanvasItem, rect: CGRect, isMacro: Bool, isDeepDetail: Bool, in context: CGContext) {
        if isMacro {
            let label = "🎵 Audio Note" as NSString
            label.draw(at: CGPoint(x: rect.minX + 16, y: rect.midY - 8), withAttributes: [
                .font: NSFont.systemFont(ofSize: max(11, 14 / zoomScale), weight: .bold),
                .foregroundColor: NSColor.labelColor
            ])
            return
        }

        // Play/Pause button on left
        let btnRadius: CGFloat = 16.0
        let btnCenter = CGPoint(x: rect.minX + 28.0, y: rect.midY)
        context.saveGState()
        context.setFillColor(NSColor.systemBlue.cgColor)
        context.fillEllipse(in: CGRect(x: btnCenter.x - btnRadius, y: btnCenter.y - btnRadius, width: btnRadius * 2, height: btnRadius * 2))
        ("▶" as NSString).draw(at: CGPoint(x: btnCenter.x - 4.0, y: btnCenter.y - 7.0), withAttributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: NSColor.white
        ])
        context.restoreGState()

        // Waveform Visualizer
        let peaks = CanvasAssetStorage.generateWaveformPeaks(for: item.mediaAssetKey ?? item.id, sampleCount: 28)
        let waveStartX = rect.minX + 54.0
        let waveWidth = rect.width - 110.0
        let barSpacing = waveWidth / CGFloat(peaks.count)

        context.saveGState()
        context.setStrokeColor(NSColor.systemBlue.withAlphaComponent(0.7).cgColor)
        context.setLineWidth(2.5 / zoomScale)
        context.setLineCap(.round)

        for (idx, peak) in peaks.enumerated() {
            let barX = waveStartX + CGFloat(idx) * barSpacing
            let barH = CGFloat(peak) * (rect.height - 32.0)
            context.move(to: CGPoint(x: barX, y: rect.midY - barH / 2.0))
            context.addLine(to: CGPoint(x: barX, y: rect.midY + barH / 2.0))
        }
        context.strokePath()
        context.restoreGState()

        // Duration text on right
        let durStr = CanvasAssetStorage.durationString(for: item.mediaAssetKey ?? "") as NSString
        durStr.draw(at: CGPoint(x: rect.maxX - 48.0, y: rect.midY - 7.0), withAttributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ])
    }

    private func drawTextOrCardContent(item: CanvasItem, rect: CGRect, isMacro: Bool, isDeepDetail: Bool, in context: CGContext) {
        if isMacro {
            let title = (item.title?.isEmpty == false ? item.title! : "Text Block") as NSString
            title.draw(at: CGPoint(x: rect.minX + 14, y: rect.midY - 8), withAttributes: [
                .font: NSFont.systemFont(ofSize: max(11, 14 / zoomScale), weight: .bold),
                .foregroundColor: NSColor.labelColor
            ])
            return
        }

        // Header Title
        let titleText = item.title?.isEmpty == false ? item.title! : "Text Block"
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: NSColor.labelColor
        ]
        (titleText as NSString).draw(in: CGRect(x: rect.minX + 14, y: rect.minY + 12, width: rect.width - 28, height: 20), withAttributes: titleAttrs)

        // Body Content (Snippet or full markdown)
        let bodyText = item.markdownContent ?? item.summarySnippet ?? ""
        if !bodyText.isEmpty {
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11.5, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            (bodyText as NSString).draw(in: CGRect(x: rect.minX + 14, y: rect.minY + 36, width: rect.width - 28, height: rect.height - 44), withAttributes: bodyAttrs)
        }
    }

    private func drawNoteLinkBadge(item: CanvasItem, in context: CGContext) {
        let badgeRect = CGRect(x: item.x + item.width - 32.0, y: item.y + 8.0, width: 24.0, height: 24.0)
        context.saveGState()
        context.setFillColor(NSColor.systemIndigo.withAlphaComponent(0.88).cgColor)
        context.fillEllipse(in: badgeRect)
        ("🔗" as NSString).draw(at: CGPoint(x: badgeRect.minX + 4.0, y: badgeRect.minY + 3.0), withAttributes: [
            .font: NSFont.systemFont(ofSize: 11)
        ])
        context.restoreGState()
    }

    private func drawMagneticSnapPorts(for item: CanvasItem, in context: CGContext) {
        let ports: [CanvasPortPosition] = [.top, .right, .bottom, .left]
        let portRadius: CGFloat = 6.0 / zoomScale

        for port in ports {
            let pt = item.portPoint(for: port)
            let isHovered = (hoveredSnapPort?.itemId == item.id && hoveredSnapPort?.port == port)

            context.saveGState()
            if isHovered {
                // Glowing outer halo
                context.setFillColor(NSColor.systemBlue.withAlphaComponent(0.35).cgColor)
                context.fillEllipse(in: CGRect(x: pt.x - portRadius * 2, y: pt.y - portRadius * 2, width: portRadius * 4, height: portRadius * 4))
            }
            context.setFillColor(isHovered ? NSColor.systemBlue.cgColor : NSColor.white.cgColor)
            context.fillEllipse(in: CGRect(x: pt.x - portRadius, y: pt.y - portRadius, width: portRadius * 2, height: portRadius * 2))
            context.setStrokeColor(NSColor.systemBlue.cgColor)
            context.setLineWidth(2.0 / zoomScale)
            context.strokeEllipse(in: CGRect(x: pt.x - portRadius, y: pt.y - portRadius, width: portRadius * 2, height: portRadius * 2))
            context.restoreGState()
        }
    }

    private func drawItemResizeHandle(for item: CanvasItem, in context: CGContext) {
        let handleSize: CGFloat = 12.0 / zoomScale
        let handleRect = CGRect(x: item.x + item.width - handleSize / 2.0, y: item.y + item.height - handleSize / 2.0, width: handleSize, height: handleSize)

        context.saveGState()
        context.setFillColor(NSColor.white.cgColor)
        context.fillEllipse(in: handleRect)
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(2.0 / zoomScale)
        context.strokeEllipse(in: handleRect)
        context.restoreGState()
    }


    private func drawInfiniteTilingGrid(in context: CGContext, visibleRect: CGRect) {
        let lineColor = NSColor(calibratedRed: 0.85, green: 0.88, blue: 0.92, alpha: 0.7).cgColor
        let spacing: CGFloat = 28.0

        switch templateType {
        case .blank:
            break

        case .lined:
            context.setStrokeColor(lineColor)
            context.setLineWidth(1.0 / zoomScale)
            var y = floor(visibleRect.minY / spacing) * spacing
            while y <= visibleRect.maxY {
                context.move(to: CGPoint(x: visibleRect.minX, y: y))
                context.addLine(to: CGPoint(x: visibleRect.maxX, y: y))
                y += spacing
            }
            context.strokePath()

        case .grid:
            context.setStrokeColor(lineColor)
            context.setLineWidth(0.8 / zoomScale)
            var x = floor(visibleRect.minX / spacing) * spacing
            while x <= visibleRect.maxX {
                context.move(to: CGPoint(x: x, y: visibleRect.minY))
                context.addLine(to: CGPoint(x: x, y: visibleRect.maxY))
                x += spacing
            }
            var y = floor(visibleRect.minY / spacing) * spacing
            while y <= visibleRect.maxY {
                context.move(to: CGPoint(x: visibleRect.minX, y: y))
                context.addLine(to: CGPoint(x: visibleRect.maxX, y: y))
                y += spacing
            }
            context.strokePath()

        case .dotGrid:
            context.setFillColor(lineColor)
            let dotSize: CGFloat = 2.2 / zoomScale
            var y = floor(visibleRect.minY / spacing) * spacing
            while y <= visibleRect.maxY {
                var x = floor(visibleRect.minX / spacing) * spacing
                while x <= visibleRect.maxX {
                    context.fillEllipse(in: CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize))
                    x += spacing
                }
                y += spacing
            }

        case .cornell, .multiColumn:
            context.setStrokeColor(lineColor)
            context.setLineWidth(1.0 / zoomScale)
            var y = floor(visibleRect.minY / spacing) * spacing
            while y <= visibleRect.maxY {
                context.move(to: CGPoint(x: visibleRect.minX, y: y))
                context.addLine(to: CGPoint(x: visibleRect.maxX, y: y))
                y += spacing
            }
            context.strokePath()

        case .squared:
            context.setStrokeColor(lineColor)
            context.setLineWidth(0.6 / zoomScale)
            let sqSpacing: CGFloat = 14.17
            var x = floor(visibleRect.minX / sqSpacing) * sqSpacing
            while x <= visibleRect.maxX {
                context.move(to: CGPoint(x: x, y: visibleRect.minY))
                context.addLine(to: CGPoint(x: x, y: visibleRect.maxY))
                x += sqSpacing
            }
            var y = floor(visibleRect.minY / sqSpacing) * sqSpacing
            while y <= visibleRect.maxY {
                context.move(to: CGPoint(x: visibleRect.minX, y: y))
                context.addLine(to: CGPoint(x: visibleRect.maxX, y: y))
                y += sqSpacing
            }
            context.strokePath()

        case .staves:
            context.setStrokeColor(lineColor)
            context.setLineWidth(0.8 / zoomScale)
            let staffSpacing: CGFloat = 8.0
            let staffBlock: CGFloat = 56.0
            var topY = floor(visibleRect.minY / staffBlock) * staffBlock
            while topY <= visibleRect.maxY {
                for lineIdx in 0..<5 {
                    let y = topY + CGFloat(lineIdx) * staffSpacing
                    context.move(to: CGPoint(x: visibleRect.minX, y: y))
                    context.addLine(to: CGPoint(x: visibleRect.maxX, y: y))
                }
                topY += staffBlock
            }
            context.strokePath()
        }
    }

    // MARK: - Template Line Helpers
    private func drawTemplateLines(template: InkTemplateType, width: CGFloat, height: CGFloat, in context: CGContext) {
        let lineColor = NSColor(calibratedRed: 0.88, green: 0.91, blue: 0.95, alpha: 0.75).cgColor

        switch template {
        case .blank:
            break

        case .lined:
            context.setStrokeColor(lineColor)
            context.setLineWidth(1.0)
            let lineSpacing: CGFloat = 32.0
            var y: CGFloat = 64.0
            while y < height {
                context.move(to: CGPoint(x: 36, y: y))
                context.addLine(to: CGPoint(x: width - 36, y: y))
                y += lineSpacing
            }
            context.strokePath()

            // Red vertical margin
            let marginColor = NSColor(calibratedRed: 0.95, green: 0.75, blue: 0.75, alpha: 0.6).cgColor
            context.setStrokeColor(marginColor)
            context.move(to: CGPoint(x: 72, y: 0))
            context.addLine(to: CGPoint(x: 72, y: height))
            context.strokePath()

        case .grid:
            context.setStrokeColor(lineColor)
            context.setLineWidth(0.8)
            let gridSize: CGFloat = 24.0
            var y: CGFloat = gridSize
            while y < height {
                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: width, y: y))
                y += gridSize
            }
            var x: CGFloat = gridSize
            while x < width {
                context.move(to: CGPoint(x: x, y: 0))
                context.addLine(to: CGPoint(x: x, y: height))
                x += gridSize
            }
            context.strokePath()

        case .dotGrid:
            context.setFillColor(lineColor)
            let dotSize: CGFloat = 2.0
            let spacing: CGFloat = 24.0
            var y: CGFloat = spacing
            while y < height {
                var x: CGFloat = spacing
                while x < width {
                    context.fillEllipse(in: CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize))
                    x += spacing
                }
                y += spacing
            }

        case .cornell:
            context.setStrokeColor(lineColor)
            context.setLineWidth(1.0)
            let lineSpacing: CGFloat = 32.0
            let startY: CGFloat = 64.0
            let summaryY = height - 140.0
            var y = startY
            while y < summaryY {
                context.move(to: CGPoint(x: 200, y: y))
                context.addLine(to: CGPoint(x: width - 36, y: y))
                y += lineSpacing
            }
            context.strokePath()

            let marginColor = NSColor(calibratedRed: 0.85, green: 0.80, blue: 0.90, alpha: 0.8).cgColor
            context.setStrokeColor(marginColor)
            context.setLineWidth(1.5)
            context.move(to: CGPoint(x: 200, y: 0))
            context.addLine(to: CGPoint(x: 200, y: summaryY))
            context.move(to: CGPoint(x: 0, y: summaryY))
            context.addLine(to: CGPoint(x: width, y: summaryY))
            context.strokePath()

        case .multiColumn:
            context.setStrokeColor(lineColor)
            context.setLineWidth(1.0)
            let midX = width / 2.0
            let lineSpacing: CGFloat = 32.0
            var y: CGFloat = 64.0
            while y < height {
                context.move(to: CGPoint(x: 36, y: y))
                context.addLine(to: CGPoint(x: midX - 20, y: y))
                context.move(to: CGPoint(x: midX + 20, y: y))
                context.addLine(to: CGPoint(x: width - 36, y: y))
                y += lineSpacing
            }
            context.strokePath()

            context.setStrokeColor(NSColor(calibratedRed: 0.80, green: 0.85, blue: 0.92, alpha: 0.8).cgColor)
            context.move(to: CGPoint(x: midX, y: 32))
            context.addLine(to: CGPoint(x: midX, y: height - 32))
            context.strokePath()

        case .squared:
            context.setStrokeColor(lineColor)
            context.setLineWidth(0.5)
            let gridSize: CGFloat = 14.17
            var y: CGFloat = gridSize
            while y < height {
                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: width, y: y))
                y += gridSize
            }
            var x: CGFloat = gridSize
            while x < width {
                context.move(to: CGPoint(x: x, y: 0))
                context.addLine(to: CGPoint(x: x, y: height))
                x += gridSize
            }
            context.strokePath()

        case .staves:
            context.setStrokeColor(lineColor)
            context.setLineWidth(0.8)
            let staffLineSpacing: CGFloat = 8.0
            let staffGap: CGFloat = 48.0
            var topY: CGFloat = 80.0
            while topY + 4 * staffLineSpacing < height - 40.0 {
                for lineIdx in 0..<5 {
                    let y = topY + CGFloat(lineIdx) * staffLineSpacing
                    context.move(to: CGPoint(x: 48, y: y))
                    context.addLine(to: CGPoint(x: width - 48, y: y))
                }
                topY += 4 * staffLineSpacing + staffGap
            }
            context.strokePath()
        }
    }

    // MARK: - Spatial PDF Layout Calculations & Overlays
    public func spatialPDFRect(for pageIdx: Int, fallbackOrderIndex: Int) -> (rect: CGRect, cropRect: CGRect?) {
        let layout = spatialPDFLayouts[pageIdx]
        let w = CGFloat(layout?.customWidth ?? Double(Self.standardPageWidth))
        let h = CGFloat(layout?.customHeight ?? Double(Self.standardPageHeight))
        let defaultY = CGFloat(fallbackOrderIndex) * (Self.standardPageHeight + Self.pageGap)
        let x = CGFloat(layout?.canvasX ?? 0.0)
        let y = CGFloat(layout?.canvasY ?? Double(defaultY))
        return (rect: CGRect(x: x, y: y, width: w, height: h), cropRect: layout?.cropRect)
    }

    private func drawSpatialPDFHeader(
        pageIndex: Int,
        tileRect: CGRect,
        isCropActive: Bool,
        in context: CGContext
    ) {
        let headerHeight: CGFloat = 34.0
        let headerRect = CGRect(x: tileRect.origin.x, y: tileRect.origin.y - headerHeight - 4.0, width: tileRect.width, height: headerHeight)

        context.saveGState()
        // Pill background
        let pillPath = CGPath(roundedRect: headerRect, cornerWidth: 8.0, cornerHeight: 8.0, transform: nil)
        context.addPath(pillPath)
        context.setFillColor(NSColor.controlBackgroundColor.withAlphaComponent(0.92).cgColor)
        context.fillPath()

        context.addPath(pillPath)
        context.setStrokeColor(NSColor.separatorColor.cgColor)
        context.setLineWidth(1.0 / zoomScale)
        context.strokePath()

        // Page title
        let titleStr = "📄 PDF Page \(pageIndex + 1)" as NSString
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        titleStr.draw(at: CGPoint(x: headerRect.origin.x + 12.0, y: headerRect.origin.y + 8.0), withAttributes: titleAttrs)

        // Action Buttons:
        // [Crop] button (right side - 70)
        let cropBtnRect = CGRect(x: headerRect.maxX - 72.0, y: headerRect.origin.y + 4.0, width: 26.0, height: 26.0)
        let cropBg = CGPath(roundedRect: cropBtnRect, cornerWidth: 5.0, cornerHeight: 5.0, transform: nil)
        context.addPath(cropBg)
        context.setFillColor((isCropActive ? NSColor.systemBlue : NSColor.quaternaryLabelColor).cgColor)
        context.fillPath()

        let cropLabel = "✂︎" as NSString
        let cropAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: isCropActive ? NSColor.white : NSColor.labelColor
        ]
        cropLabel.draw(at: CGPoint(x: cropBtnRect.origin.x + 6.0, y: cropBtnRect.origin.y + 3.0), withAttributes: cropAttrs)

        // [Reset / Delete] button (right side - 36)
        let delBtnRect = CGRect(x: headerRect.maxX - 36.0, y: headerRect.origin.y + 4.0, width: 26.0, height: 26.0)
        let delBg = CGPath(roundedRect: delBtnRect, cornerWidth: 5.0, cornerHeight: 5.0, transform: nil)
        context.addPath(delBg)
        context.setFillColor(NSColor.quaternaryLabelColor.cgColor)
        context.fillPath()

        let delLabel = "✕" as NSString
        let delAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        delLabel.draw(at: CGPoint(x: delBtnRect.origin.x + 8.0, y: delBtnRect.origin.y + 5.0), withAttributes: delAttrs)

        // Resize Handle Icon at Bottom-Right of Page Tile (18x18)
        let resizeHandleRect = CGRect(x: tileRect.maxX - 18.0, y: tileRect.maxY - 18.0, width: 16.0, height: 16.0)
        let resizePath = CGPath(roundedRect: resizeHandleRect, cornerWidth: 4.0, cornerHeight: 4.0, transform: nil)
        context.addPath(resizePath)
        context.setFillColor(NSColor.secondaryLabelColor.withAlphaComponent(0.2).cgColor)
        context.fillPath()

        context.setStrokeColor(NSColor.secondaryLabelColor.cgColor)
        context.setLineWidth(1.5 / zoomScale)
        // Two small diagonal lines indicating resize
        context.move(to: CGPoint(x: resizeHandleRect.maxX - 4, y: resizeHandleRect.maxY - 10))
        context.addLine(to: CGPoint(x: resizeHandleRect.maxX - 10, y: resizeHandleRect.maxY - 4))
        context.move(to: CGPoint(x: resizeHandleRect.maxX - 4, y: resizeHandleRect.maxY - 6))
        context.addLine(to: CGPoint(x: resizeHandleRect.maxX - 6, y: resizeHandleRect.maxY - 4))
        context.strokePath()

        context.restoreGState()
    }

    private func drawCropOverlay(
        for pageIdx: Int,
        tileRect: CGRect,
        in context: CGContext
    ) {
        let layout = spatialPDFLayouts[pageIdx]
        let unitCrop = layout?.cropRect ?? CGRect(x: 0, y: 0, width: 1, height: 1)
        let cropCanvasRect = CGRect(
            x: tileRect.origin.x + unitCrop.origin.x * tileRect.width,
            y: tileRect.origin.y + unitCrop.origin.y * tileRect.height,
            width: unitCrop.width * tileRect.width,
            height: unitCrop.height * tileRect.height
        )

        context.saveGState()

        // Darkened mask outside crop
        context.setFillColor(NSColor.black.withAlphaComponent(0.45).cgColor)
        // Top rect
        context.fill(CGRect(x: tileRect.minX, y: tileRect.minY, width: tileRect.width, height: cropCanvasRect.minY - tileRect.minY))
        // Bottom rect
        context.fill(CGRect(x: tileRect.minX, y: cropCanvasRect.maxY, width: tileRect.width, height: tileRect.maxY - cropCanvasRect.maxY))
        // Left rect
        context.fill(CGRect(x: tileRect.minX, y: cropCanvasRect.minY, width: cropCanvasRect.minX - tileRect.minX, height: cropCanvasRect.height))
        // Right rect
        context.fill(CGRect(x: cropCanvasRect.maxX, y: cropCanvasRect.minY, width: tileRect.maxX - cropCanvasRect.maxX, height: cropCanvasRect.height))

        // Crop frame border
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(2.0 / zoomScale)
        context.stroke(cropCanvasRect)

        // 4 Corner Handles
        let handleSize: CGFloat = 12.0 / zoomScale
        let corners = [
            CGPoint(x: cropCanvasRect.minX, y: cropCanvasRect.minY),
            CGPoint(x: cropCanvasRect.maxX, y: cropCanvasRect.minY),
            CGPoint(x: cropCanvasRect.maxX, y: cropCanvasRect.maxY),
            CGPoint(x: cropCanvasRect.minX, y: cropCanvasRect.maxY)
        ]
        context.setFillColor(NSColor.white.cgColor)
        for corner in corners {
            let hr = CGRect(x: corner.x - handleSize / 2, y: corner.y - handleSize / 2, width: handleSize, height: handleSize)
            context.fill(hr)
            context.stroke(hr)
        }

        context.restoreGState()
    }

    private func drawPageLabel(index: Int, at point: CGPoint, in context: CGContext) {
        let str = "Page \(index)" as NSString
        let font = NSFont.systemFont(ofSize: 11, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        str.draw(at: point, withAttributes: attrs)
    }

    // MARK: - Stroke Vector Rendering
    private func renderStroke(_ stroke: InkStroke, in context: CGContext) {
        let color = NSColor(hex: stroke.colorHex) ?? NSColor.black

        if stroke.tool == .tape {
            let isRevealed = stroke.isTapeRevealed ?? false
            let path = InkGeometry.generateOutlinePath(for: stroke)
            let baseColor = NSColor(hex: stroke.colorHex) ?? NSColor(calibratedRed: 0.96, green: 0.62, blue: 0.05, alpha: 1.0)
            context.saveGState()
            if isRevealed {
                context.setFillColor(baseColor.withAlphaComponent(0.12).cgColor)
                context.setStrokeColor(baseColor.withAlphaComponent(0.6).cgColor)
                context.setLineWidth(1.5 / zoomScale)
                context.setLineDash(phase: 0, lengths: [4.0 / zoomScale, 3.0 / zoomScale])
                context.addPath(path)
                context.drawPath(using: .fillStroke)
            } else {
                context.setFillColor(baseColor.withAlphaComponent(0.96).cgColor)
                context.setStrokeColor(NSColor(calibratedRed: 0.82, green: 0.50, blue: 0.02, alpha: 1.0).cgColor)
                context.setLineWidth(1.0 / zoomScale)
                context.addPath(path)
                context.drawPath(using: .fillStroke)
            }
            context.restoreGState()
            return
        }

        if stroke.pattern == .dashed || stroke.pattern == .dotted {
            let lengths: [CGFloat] = (stroke.pattern == .dashed) ? [12.0 / zoomScale, 6.0 / zoomScale] : [3.0 / zoomScale, 5.0 / zoomScale]
            context.saveGState()
            context.setLineDash(phase: 0, lengths: lengths)
            context.setLineWidth(CGFloat(stroke.baseWidth))
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setStrokeColor(color.withAlphaComponent(CGFloat(stroke.opacity)).cgColor)
            let smoothed = InkGeometry.smoothPoints(from: stroke.points)
            if let first = smoothed.first {
                let centerPath = CGMutablePath()
                centerPath.move(to: CGPoint(x: first.x, y: first.y))
                for pt in smoothed.dropFirst() {
                    centerPath.addLine(to: CGPoint(x: pt.x, y: pt.y))
                }
                context.addPath(centerPath)
                context.strokePath()
            }
            context.restoreGState()
            return
        }

        let path = InkGeometry.generateOutlinePath(for: stroke)
        context.saveGState()
        if stroke.tool == .highlighter {
            context.setBlendMode(.multiply)
            context.setFillColor(color.withAlphaComponent(CGFloat(stroke.opacity * 0.45)).cgColor)
        } else {
            context.setBlendMode(.normal)
            context.setFillColor(color.withAlphaComponent(CGFloat(stroke.opacity)).cgColor)
        }
        context.addPath(path)
        context.fillPath()
        context.restoreGState()
    }

    private func drawLiveStroke(in context: CGContext) {
        let liveStroke = InkStroke(
            tool: activeTool,
            colorHex: (activeTool == .tape) ? "#F59E0B" : activeColor.toHex(),
            baseWidth: (activeTool == .tape) ? max(24.0, activeWidth * 5.0) : activeWidth,
            opacity: activeOpacity,
            points: livePoints,
            pattern: (activeTool == .tape) ? .solid : activePattern,
            isTapeRevealed: false
        )
        renderStroke(liveStroke, in: context)
    }

    // MARK: - 2D Ruler Overlay & Snapping
    private func drawRulerOverlay(in context: CGContext) {
        guard isRulerActive else { return }
        context.saveGState()

        let rad = rulerAngle * .pi / 180.0
        context.translateBy(x: rulerOrigin.x, y: rulerOrigin.y)
        context.rotate(by: rad)

        let rulerWidth: CGFloat = 540.0
        let rulerHeight: CGFloat = 64.0
        let rRect = CGRect(x: -rulerWidth / 2.0, y: -rulerHeight / 2.0, width: rulerWidth, height: rulerHeight)

        let clipPath = CGPath(roundedRect: rRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
        context.addPath(clipPath)
        context.setFillColor(NSColor.windowBackgroundColor.withAlphaComponent(0.88).cgColor)
        context.fillPath()

        context.addPath(clipPath)
        context.setStrokeColor(NSColor.separatorColor.cgColor)
        context.setLineWidth(1.0 / zoomScale)
        context.strokePath()

        context.setStrokeColor(NSColor.secondaryLabelColor.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(1.0 / zoomScale)
        let topY = -rulerHeight / 2.0
        var x = -rulerWidth / 2.0 + 20.0
        var mm = 0
        while x <= rulerWidth / 2.0 - 20.0 {
            let isCm = (mm % 5 == 0)
            let tickLen: CGFloat = isCm ? 14.0 : 7.0
            context.move(to: CGPoint(x: x, y: topY))
            context.addLine(to: CGPoint(x: x, y: topY + tickLen))
            x += 10.0
            mm += 1
        }
        context.strokePath()

        let badgeStr = String(format: "%.1f°", rulerAngle) as NSString
        let badgeAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold),
            .foregroundColor: NSColor.labelColor
        ]
        let badgeSize = badgeStr.size(withAttributes: badgeAttrs)
        let badgeRect = CGRect(x: -badgeSize.width / 2.0 - 8, y: -badgeSize.height / 2.0, width: badgeSize.width + 16, height: badgeSize.height + 4)
        context.setFillColor(NSColor.controlBackgroundColor.cgColor)
        context.fill(badgeRect)
        badgeStr.draw(at: CGPoint(x: -badgeSize.width / 2.0, y: -badgeSize.height / 2.0 + 2), withAttributes: badgeAttrs)

        context.restoreGState()
    }

    private func snapPointToRulerIfClose(_ point: CGPoint) -> CGPoint {
        guard isRulerActive else { return point }
        let rad = rulerAngle * .pi / 180.0
        let u = CGPoint(x: cos(rad), y: sin(rad))
        let n = CGPoint(x: -sin(rad), y: cos(rad))

        let edgeCenter = CGPoint(x: rulerOrigin.x - n.x * 32.0, y: rulerOrigin.y - n.y * 32.0)
        let lineStart = CGPoint(x: edgeCenter.x - u.x * 270.0, y: edgeCenter.y - u.y * 270.0)
        let lineEnd = CGPoint(x: edgeCenter.x + u.x * 270.0, y: edgeCenter.y + u.y * 270.0)

        let projected = InkGeometry.projectPointOntoLine(point: point, lineStart: lineStart, lineEnd: lineEnd)
        let dist = InkGeometry.distance(point, projected)
        if dist <= 24.0 {
            return projected
        }
        return point
    }

    private func checkShapeHoldTrigger() {
        guard isDrawing && isShapeSnappingEnabled && livePoints.count >= 6 else { return }
        if let shape = InkGeometry.fitPrimitive(from: livePoints) {
            let fitted = InkGeometry.generatePoints(for: shape, basePressure: livePoints.last?.pressure ?? 0.6)
            self.livePoints = fitted
            self.needsDisplay = true
        }
    }

    // MARK: - Z-Index Ordering
    public func bringSelectionToFront() {
        guard !selectedStrokeIds.isEmpty else { return }
        for (pageIdx, strokes) in pagesStrokes {
            let selected = strokes.filter { selectedStrokeIds.contains($0.id) }
            let unselected = strokes.filter { !selectedStrokeIds.contains($0.id) }
            if !selected.isEmpty {
                let updated = unselected + selected
                pagesStrokes[pageIdx] = updated
                onStrokesChanged?(pageIdx, updated)
            }
        }
        needsDisplay = true
    }

    public func sendSelectionToBack() {
        guard !selectedStrokeIds.isEmpty else { return }
        for (pageIdx, strokes) in pagesStrokes {
            let selected = strokes.filter { selectedStrokeIds.contains($0.id) }
            let unselected = strokes.filter { !selectedStrokeIds.contains($0.id) }
            if !selected.isEmpty {
                let updated = selected + unselected
                pagesStrokes[pageIdx] = updated
                onStrokesChanged?(pageIdx, updated)
            }
        }
        needsDisplay = true
    }

    // MARK: - Lasso Rendering & Manipulation
    private func drawLassoOverlay(in context: CGContext, strokes: [InkStroke]) {
        if !lassoPoints.isEmpty {
            context.saveGState()
            context.setStrokeColor(NSColor.systemBlue.withAlphaComponent(0.8).cgColor)
            context.setFillColor(NSColor.systemBlue.withAlphaComponent(0.08).cgColor)
            context.setLineWidth(1.5 / zoomScale)
            context.setLineDash(phase: 0, lengths: [6.0 / zoomScale, 4.0 / zoomScale])

            let path = CGMutablePath()
            path.addLines(between: lassoPoints)
            if lassoPoints.count > 2 {
                path.closeSubpath()
            }
            context.addPath(path)
            context.drawPath(using: .fillStroke)
            context.restoreGState()
        }

        if !selectedStrokeIds.isEmpty {
            let selectedStrokes = strokes.filter { selectedStrokeIds.contains($0.id) }
            if let bbox = InkGeometry.combinedBoundingBox(for: selectedStrokes) {
                let pad: CGFloat = 8.0
                let selRect = bbox.insetBy(dx: -pad, dy: -pad)

                context.saveGState()
                context.setStrokeColor(NSColor.systemBlue.cgColor)
                context.setFillColor(NSColor.systemBlue.withAlphaComponent(0.06).cgColor)
                context.setLineWidth(1.5 / zoomScale)
                context.setLineDash(phase: 0, lengths: [4.0 / zoomScale, 4.0 / zoomScale])
                context.addRect(selRect)
                context.drawPath(using: .fillStroke)

                let handleSize: CGFloat = 8.0 / zoomScale
                let corners = [
                    CGPoint(x: selRect.minX, y: selRect.minY),
                    CGPoint(x: selRect.maxX, y: selRect.minY),
                    CGPoint(x: selRect.maxX, y: selRect.maxY),
                    CGPoint(x: selRect.minX, y: selRect.maxY)
                ]
                context.setFillColor(NSColor.white.cgColor)
                context.setStrokeColor(NSColor.systemBlue.cgColor)
                context.setLineDash(phase: 0, lengths: [])
                for corner in corners {
                    let r = CGRect(x: corner.x - handleSize / 2, y: corner.y - handleSize / 2, width: handleSize, height: handleSize)
                    context.fill(r)
                    context.stroke(r)
                }
                context.restoreGState()
            }
        }
    }

    private func handleLassoMouseDown(at loc: CGPoint, pageIndex: Int) {
        if !selectedStrokeIds.isEmpty {
            let pageStrokes = pagesStrokes[pageIndex] ?? []
            let selected = pageStrokes.filter { selectedStrokeIds.contains($0.id) }
            if let bbox = InkGeometry.combinedBoundingBox(for: selected) {
                let selRect = bbox.insetBy(dx: -16.0, dy: -16.0)
                if selRect.contains(loc) {
                    isDraggingSelection = true
                    lassoSelectionStartLocation = loc
                    return
                }
            }
        }

        selectedStrokeIds.removeAll()
        isDraggingSelection = false
        lassoPoints = [loc]
        needsDisplay = true
    }

    private func handleLassoMouseDragged(to loc: CGPoint, pageIndex: Int) {
        if isDraggingSelection {
            let dx = Double(loc.x - lassoSelectionStartLocation.x)
            let dy = Double(loc.y - lassoSelectionStartLocation.y)
            lassoSelectionStartLocation = loc

            var current = pagesStrokes[pageIndex] ?? []
            current = current.map { stroke in
                if selectedStrokeIds.contains(stroke.id) {
                    return InkGeometry.translate(stroke: stroke, dx: dx, dy: dy)
                }
                return stroke
            }
            pagesStrokes[pageIndex] = current
            needsDisplay = true
            return
        }

        lassoPoints.append(loc)
        needsDisplay = true
    }

    private func handleLassoMouseUp(at loc: CGPoint, pageIndex: Int) {
        if isDraggingSelection {
            isDraggingSelection = false
            if let current = pagesStrokes[pageIndex] {
                onStrokesChanged?(pageIndex, current)
            }
            return
        }

        guard lassoPoints.count > 3 else {
            lassoPoints.removeAll()
            selectedStrokeIds.removeAll()
            needsDisplay = true
            return
        }

        let current = pagesStrokes[pageIndex] ?? []
        var newlySelected: Set<String> = []
        for stroke in current {
            if InkGeometry.lassoSelects(stroke: stroke, polygon: lassoPoints) {
                newlySelected.insert(stroke.id)
            }
        }

        self.selectedStrokeIds = newlySelected
        self.lassoPoints.removeAll()
        needsDisplay = true
    }

    public func deleteSelectedStrokes() {
        guard !selectedStrokeIds.isEmpty else { return }
        for (pageIdx, strokes) in pagesStrokes {
            let filtered = strokes.filter { !selectedStrokeIds.contains($0.id) }
            if filtered.count != strokes.count {
                pagesStrokes[pageIdx] = filtered
                onStrokesChanged?(pageIdx, filtered)
            }
        }
        selectedStrokeIds.removeAll()
        needsDisplay = true
    }

    private func eraseStrokesAt(canvasPoint: CGPoint, pageIndex: Int) {
        var pageStrokes = pagesStrokes[pageIndex] ?? []
        let beforeCount = pageStrokes.count
        pageStrokes.removeAll { stroke in
            InkGeometry.hitTest(stroke: stroke, point: canvasPoint, eraserRadius: CGFloat(activeWidth))
        }

        if pageStrokes.count != beforeCount {
            pagesStrokes[pageIndex] = pageStrokes
            needsDisplay = true
            onStrokesChanged?(pageIndex, pageStrokes)
        }
    }

    private func calculatePressure(event: NSEvent, currentPoint: CGPoint) -> Double {
        let devicePressure = Double(event.pressure)
        if devicePressure > 0.01 {
            return max(0.1, min(1.0, devicePressure))
        }

        let dt = max(0.005, event.timestamp - lastEventTime)
        let dist = InkGeometry.distance(currentPoint, lastEventPoint)
        let speed = dist / CGFloat(dt)

        let normalizedSpeed = max(0.0, min(1.0, Double(speed) / 1200.0))
        let simulatedPressure = 0.85 - (normalizedSpeed * 0.55)
        return max(0.2, min(1.0, simulatedPressure))
    }

    // MARK: - NSDraggingDestination (Drag & Drop Media and Notes onto Canvas)
    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pboard = sender.draggingPasteboard
        let types = [
            NSPasteboard.PasteboardType.fileURL.rawValue,
            NSPasteboard.PasteboardType.tiff.rawValue,
            NSPasteboard.PasteboardType.png.rawValue,
            NSPasteboard.PasteboardType.string.rawValue,
            "medha.document.id"
        ]
        if pboard.canReadItem(withDataConformingToTypes: types) {
            return .copy
        }
        return []
    }

    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pboard = sender.draggingPasteboard
        let locInWindow = sender.draggingLocation
        let locInView = convert(locInWindow, from: nil)
        let canvasPoint = canvasPointFrom(viewPoint: locInView)

        // 1. Check for dropped file URLs (Images, Videos, Audio, PDFs)
        if let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let firstURL = urls.first {
            do {
                let media = try CanvasAssetStorage.importMedia(from: firstURL, canvasDocId: docId)
                let dropX = Double(canvasPoint.x - media.naturalSize.width / 2.0)
                let dropY = Double(canvasPoint.y - media.naturalSize.height / 2.0)
                let item = CanvasItem(
                    canvasDocId: docId,
                    itemType: media.itemType,
                    x: dropX,
                    y: dropY,
                    width: Double(min(600.0, max(140.0, media.naturalSize.width))),
                    height: Double(min(450.0, max(80.0, media.naturalSize.height))),
                    title: media.title,
                    mediaAssetKey: media.assetKey
                )
                onAddCanvasItem?(item)
                needsDisplay = true
                return true
            } catch {
                print("Error importing dropped media: \(error)")
            }
        }

        // 2. Check for raw pasted image
        if let image = NSImage(pasteboard: pboard), let tiff = image.tiffRepresentation {
            if let media = try? CanvasAssetStorage.importMediaData(tiff, suggestedExtension: "png", canvasDocId: docId) {
                let dropX = Double(canvasPoint.x - media.naturalSize.width / 2.0)
                let dropY = Double(canvasPoint.y - media.naturalSize.height / 2.0)
                let item = CanvasItem(
                    canvasDocId: docId,
                    itemType: .mediaImage,
                    x: dropX,
                    y: dropY,
                    width: Double(min(600.0, max(140.0, media.naturalSize.width))),
                    height: Double(min(450.0, max(80.0, media.naturalSize.height))),
                    title: "Pasted Image",
                    mediaAssetKey: media.assetKey
                )
                onAddCanvasItem?(item)
                needsDisplay = true
                return true
            }
        }

        // 3. Check for dropped note documents
        guard let noteDocId = pboard.string(forType: NSPasteboard.PasteboardType("medha.document.id")) ?? pboard.string(forType: .string) else {
            return false
        }

        // Drop the card centered at drop point
        let cardX = Double(canvasPoint.x - 160.0)
        let cardY = Double(canvasPoint.y - 90.0)

        onAddNoteCard?(noteDocId, cardX, cardY)
        needsDisplay = true
        return true
    }

}

