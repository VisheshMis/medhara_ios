import AppKit
import SwiftUI
import CoreGraphics

// MARK: - Native Interactive Canvas Viewport for macOS
/// Handles high-performance vector rendering, smooth trackpad pinch-to-zoom,
/// two-finger pan, Spacebar Hand Tool, and multiple canvas modes (A4, Infinite Vertical, Infinite 2D).
public final class InkCanvasViewportNSView: NSView {
    public var docId: String
    public var canvasMode: InkCanvasMode
    public var templateType: InkTemplateType
    public var pdfPath: String?
    public var pdfPageIndex: Int?

    // Stored strokes per page: [pageIndex: [InkStroke]]
    public var pagesStrokes: [Int: [InkStroke]] = [:]
    public var totalPagesCount: Int = 1

    // Viewport transform
    public var zoomScale: CGFloat = 1.0 {
        didSet {
            zoomScale = min(max(zoomScale, 0.1), 10.0)
            needsDisplay = true
        }
    }
    public var panOffset: CGPoint = CGPoint(x: 40, y: 40) {
        didSet {
            needsDisplay = true
        }
    }

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
        pagesStrokes: [Int: [InkStroke]] = [:],
        totalPagesCount: Int = 1
    ) {
        self.docId = docId
        self.canvasMode = canvasMode
        self.templateType = templateType
        self.pdfPath = pdfPath
        self.pdfPageIndex = pdfPageIndex
        self.pagesStrokes = pagesStrokes
        self.totalPagesCount = max(1, totalPagesCount)
        super.init(frame: .zero)

        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.layer?.masksToBounds = true
        self.clipsToBounds = true
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
        self.infiniteVerticalHeight = max(Self.standardPageHeight, CGFloat(maxY) + 600.0)
    }

    // MARK: - Navigation Public Actions
    public func zoomTo(scale: CGFloat, centerInView: CGPoint? = nil) {
        let anchor = centerInView ?? CGPoint(x: bounds.midX, y: bounds.midY)
        let oldScale = zoomScale
        let newScale = min(max(scale, 0.1), 10.0)

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
        let targetWidth: CGFloat = (canvasMode == .infinite2D ? 1200.0 : Self.standardPageWidth)
        let availableWidth = bounds.width - 80.0
        let targetScale = max(0.2, min(3.0, availableWidth / targetWidth))
        self.zoomScale = targetScale
        self.panOffset.x = max(20.0, (bounds.width - targetWidth * targetScale) / 2.0)
        self.panOffset.y = 40.0
        onZoomScaleChanged?(targetScale)
        needsDisplay = true
    }

    public func zoomToFitContent() {
        let allStrokes = pagesStrokes.values.flatMap { $0 }
        guard let bbox = InkGeometry.combinedBoundingBox(for: allStrokes) else {
            zoomToActualSize()
            return
        }

        let padded = bbox.insetBy(dx: -60.0, dy: -60.0)
        let scaleX = bounds.width / max(100.0, padded.width)
        let scaleY = bounds.height / max(100.0, padded.height)
        let newScale = min(max(min(scaleX, scaleY), 0.1), 3.0)

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
        let newScale = min(max(oldScale * (1.0 + magnificationDelta), 0.1), 10.0)

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

        // Direct drawing / lasso / eraser
        let canvasPoint = canvasPointFrom(viewPoint: locInView)
        strokeStartTime = Date()
        lastEventPoint = locInView
        lastEventTime = event.timestamp

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

        if !selectedStrokeIds.isEmpty {
            selectedStrokeIds.removeAll()
            needsDisplay = true
        }

        isDrawing = true
        let pressure = calculatePressure(event: event, currentPoint: locInView)
        livePoints = [InkPoint(x: Double(pageRelPoint.x), y: Double(pageRelPoint.y), pressure: pressure, timeOffset: 0.0)]
        needsDisplay = true
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
        let pressure = calculatePressure(event: event, currentPoint: locInView)
        let elapsed = Date().timeIntervalSince(strokeStartTime)
        livePoints.append(InkPoint(x: Double(pageRelPoint.x), y: Double(pageRelPoint.y), pressure: pressure, timeOffset: elapsed))

        lastEventPoint = locInView
        lastEventTime = event.timestamp

        // Expand infinite vertical sheet height dynamically if drawing extends down
        if canvasMode == .infiniteVertical && canvasPoint.y + 400.0 > infiniteVerticalHeight {
            infiniteVerticalHeight = canvasPoint.y + 600.0
        }

        needsDisplay = true
    }

    public override func mouseUp(with event: NSEvent) {
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

        let newStroke = InkStroke(
            tool: activeTool,
            colorHex: activeColor.toHex(),
            baseWidth: activeWidth,
            opacity: activeOpacity,
            points: livePoints
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

            // Render PDF if page has one
            if let path = self.pdfPath, let pIdx = self.pdfPageIndex, pageIdx == 0,
               let pdfURL = InkPDFImporterService.resolvePDFURL(for: path) {
                InkPDFImporterService.renderPDFPage(from: pdfURL, pageIndex: pIdx, in: context, targetRect: CGRect(x: 0, y: 0, width: width, height: height))
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
        }
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
        let path = InkGeometry.generateOutlinePath(for: stroke)
        let color = NSColor(hex: stroke.colorHex) ?? NSColor.black

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
            colorHex: activeColor.toHex(),
            baseWidth: activeWidth,
            opacity: activeOpacity,
            points: livePoints
        )
        renderStroke(liveStroke, in: context)
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
}
