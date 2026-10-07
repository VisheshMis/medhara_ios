import AppKit
import SwiftUI
import CoreGraphics

// MARK: - Native AppKit Low-Latency Vector Ink Canvas
public final class InkCanvasNSView: NSView {
    public var docId: String
    public var pageIndex: Int
    public var templateType: InkTemplateType
    public var pdfPath: String?
    public var pdfPageIndex: Int?
    public var onStrokesChanged: (([InkStroke]) -> Void)?

    // State
    public private(set) var strokes: [InkStroke] = []
    private var livePoints: [InkPoint] = []
    private var isDrawing: Bool = false
    private var strokeStartTime: Date = Date()
    private var lastEventPoint: CGPoint = .zero
    private var lastEventTime: TimeInterval = 0

    // Lasso Selection State
    private var lassoPoints: [CGPoint] = []
    public private(set) var selectedStrokeIds: Set<String> = []
    private var isDraggingSelection: Bool = false
    private var dragStartLocation: CGPoint = .zero

    // Tool Settings (synced from store)
    public var activeTool: InkToolType = .ballpoint
    public var activeColor: NSColor = NSColor(srgbRed: 0.12, green: 0.16, blue: 0.24, alpha: 1.0)
    public var activeWidth: Double = 2.5
    public var activeOpacity: Double = 1.0
    public var activePattern: StrokePattern = .solid
    public var isRulerActive: Bool = false {
        didSet { needsDisplay = true }
    }
    public var rulerOrigin: CGPoint = CGPoint(x: 200, y: 350)
    public var rulerAngle: CGFloat = 0.0 {
        didSet { needsDisplay = true }
    }
    public var isShapeSnappingEnabled: Bool = true
    private var shapeHoldTimer: Timer? = nil
    private var dragJitterOrigin: CGPoint = .zero

    // Off-screen Raster Cache for Committed Strokes (60–120fps guarantee)
    private var cachedBitmap: NSImage?
    private var isCacheDirty: Bool = true

    public init(
        docId: String,
        pageIndex: Int = 0,
        templateType: InkTemplateType = .lined,
        pdfPath: String? = nil,
        pdfPageIndex: Int? = nil,
        initialStrokes: [InkStroke] = [],
        onStrokesChanged: (([InkStroke]) -> Void)? = nil
    ) {
        self.docId = docId
        self.pageIndex = pageIndex
        self.templateType = templateType
        self.pdfPath = pdfPath
        self.pdfPageIndex = pdfPageIndex
        self.strokes = initialStrokes
        self.onStrokesChanged = onStrokesChanged
        super.init(frame: NSRect(x: 0, y: 0, width: 794, height: 1123))
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.white.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var isFlipped: Bool {
        return true // Top-left origin coordinates
    }

    public func setPDFInfo(pdfPath: String?, pdfPageIndex: Int?) {
        if self.pdfPath != pdfPath || self.pdfPageIndex != pdfPageIndex {
            self.pdfPath = pdfPath
            self.pdfPageIndex = pdfPageIndex
            self.isCacheDirty = true
            self.needsDisplay = true
        }
    }

    public func setStrokes(_ newStrokes: [InkStroke]) {
        self.strokes = newStrokes
        self.isCacheDirty = true
        self.needsDisplay = true
    }

    public func setTemplate(_ template: InkTemplateType) {
        self.templateType = template
        self.isCacheDirty = true
        self.needsDisplay = true
    }

    // MARK: - Drawing & Rendering Pipeline
    public override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // 1. Draw Page Background Template
        drawTemplateBackground(in: context)

        // 2. Render Committed Strokes (from cache or render into cache)
        if isCacheDirty || cachedBitmap == nil || cachedBitmap?.size != bounds.size {
            rebuildBitmapCache()
        }

        if let cached = cachedBitmap {
            cached.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1.0)
        }

        // 3. Render Active Live Stroke (sub-8ms latency layer)
        if isDrawing && !livePoints.isEmpty {
            drawLiveStroke(in: context)
        }

        // 4. Render Lasso Selection overlay
        if activeTool == .lasso {
            drawLassoOverlay(in: context)
        }

        // 5. Render 2D Ruler Guide overlay
        if isRulerActive {
            drawRulerOverlay(in: context)
        }
    }

    private func drawLassoOverlay(in context: CGContext) {
        // Draw active lasso loop path while dragging
        if !lassoPoints.isEmpty {
            context.saveGState()
            context.setStrokeColor(NSColor.systemBlue.withAlphaComponent(0.8).cgColor)
            context.setFillColor(NSColor.systemBlue.withAlphaComponent(0.1).cgColor)
            context.setLineWidth(1.5)
            context.setLineDash(phase: 0, lengths: [6.0, 4.0])

            let path = CGMutablePath()
            path.addLines(between: lassoPoints)
            if lassoPoints.count > 2 {
                path.closeSubpath()
            }
            context.addPath(path)
            context.drawPath(using: .fillStroke)
            context.restoreGState()
        }

        // Draw bounding box / selection indicator around selected strokes
        if !selectedStrokeIds.isEmpty {
            let selectedStrokes = strokes.filter { selectedStrokeIds.contains($0.id) }
            if !selectedStrokes.isEmpty {
                var minX = Double.greatestFiniteMagnitude
                var minY = Double.greatestFiniteMagnitude
                var maxX = -Double.greatestFiniteMagnitude
                var maxY = -Double.greatestFiniteMagnitude

                for s in selectedStrokes {
                    let b = s.boundingRect
                    minX = min(minX, b.minX)
                    minY = min(minY, b.minY)
                    maxX = max(maxX, b.maxX)
                    maxY = max(maxY, b.maxY)
                }

                let pad: CGFloat = 8.0
                let selRect = CGRect(
                    x: CGFloat(minX) - pad,
                    y: CGFloat(minY) - pad,
                    width: CGFloat(maxX - minX) + pad * 2,
                    height: CGFloat(maxY - minY) + pad * 2
                )

                context.saveGState()
                context.setStrokeColor(NSColor.systemBlue.cgColor)
                context.setFillColor(NSColor.systemBlue.withAlphaComponent(0.06).cgColor)
                context.setLineWidth(1.5)
                context.setLineDash(phase: 0, lengths: [4.0, 4.0])
                context.addRect(selRect)
                context.drawPath(using: .fillStroke)

                // Draw corner handles
                let handleSize: CGFloat = 8.0
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
                    let r = CGRect(x: corner.x - handleSize/2, y: corner.y - handleSize/2, width: handleSize, height: handleSize)
                    context.fill(r)
                    context.stroke(r)
                }
                context.restoreGState()
            }
        }
    }

    private func drawTemplateBackground(in context: CGContext) {
        // Base paper color
        context.setFillColor(NSColor(calibratedRed: 0.99, green: 0.99, blue: 0.99, alpha: 1.0).cgColor)
        context.fill(bounds)

        // If this page has an imported PDF page attached, render it onto the canvas
        if let pdfPath = self.pdfPath, let pageIdx = self.pdfPageIndex,
           let pdfURL = InkPDFImporterService.resolvePDFURL(for: pdfPath) {
            InkPDFImporterService.renderPDFPage(from: pdfURL, pageIndex: pageIdx, in: context, targetRect: bounds)
        }

        let lineColor = NSColor(calibratedRed: 0.88, green: 0.91, blue: 0.95, alpha: 0.7).cgColor

        switch templateType {
        case .blank:
            break

        case .lined:
            context.setStrokeColor(lineColor)
            context.setLineWidth(1.0)
            let lineSpacing: CGFloat = 32.0
            let startY: CGFloat = 64.0
            var y = startY
            while y < bounds.height {
                context.move(to: CGPoint(x: 36, y: y))
                context.addLine(to: CGPoint(x: bounds.width - 36, y: y))
                y += lineSpacing
            }
            context.strokePath()

            // Red vertical margin line
            let marginColor = NSColor(calibratedRed: 0.95, green: 0.75, blue: 0.75, alpha: 0.6).cgColor
            context.setStrokeColor(marginColor)
            context.move(to: CGPoint(x: 72, y: 0))
            context.addLine(to: CGPoint(x: 72, y: bounds.height))
            context.strokePath()

        case .grid:
            context.setStrokeColor(lineColor)
            context.setLineWidth(0.8)
            let gridSize: CGFloat = 24.0

            // Horizontal lines
            var y: CGFloat = gridSize
            while y < bounds.height {
                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: bounds.width, y: y))
                y += gridSize
            }

            // Vertical lines
            var x: CGFloat = gridSize
            while x < bounds.width {
                context.move(to: CGPoint(x: x, y: 0))
                context.addLine(to: CGPoint(x: x, y: bounds.height))
                x += gridSize
            }
            context.strokePath()

        case .dotGrid:
            context.setFillColor(lineColor)
            let dotSize: CGFloat = 2.0
            let spacing: CGFloat = 24.0

            var y: CGFloat = spacing
            while y < bounds.height {
                var x: CGFloat = spacing
                while x < bounds.width {
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
            let summaryY = bounds.height - 140.0
            var y = startY
            while y < summaryY {
                context.move(to: CGPoint(x: 200, y: y))
                context.addLine(to: CGPoint(x: bounds.width - 36, y: y))
                y += lineSpacing
            }
            context.strokePath()

            // Cue column & summary divider
            let marginColor = NSColor(calibratedRed: 0.85, green: 0.80, blue: 0.90, alpha: 0.8).cgColor
            context.setStrokeColor(marginColor)
            context.setLineWidth(1.5)
            context.move(to: CGPoint(x: 200, y: 0))
            context.addLine(to: CGPoint(x: 200, y: summaryY))
            context.move(to: CGPoint(x: 0, y: summaryY))
            context.addLine(to: CGPoint(x: bounds.width, y: summaryY))
            context.strokePath()

        case .multiColumn:
            context.setStrokeColor(lineColor)
            context.setLineWidth(1.0)
            let midX = bounds.width / 2.0
            let lineSpacing: CGFloat = 32.0
            var y: CGFloat = 64.0
            while y < bounds.height {
                context.move(to: CGPoint(x: 36, y: y))
                context.addLine(to: CGPoint(x: midX - 20, y: y))
                context.move(to: CGPoint(x: midX + 20, y: y))
                context.addLine(to: CGPoint(x: bounds.width - 36, y: y))
                y += lineSpacing
            }
            context.strokePath()

            context.setStrokeColor(NSColor(calibratedRed: 0.80, green: 0.85, blue: 0.92, alpha: 0.8).cgColor)
            context.move(to: CGPoint(x: midX, y: 32))
            context.addLine(to: CGPoint(x: midX, y: bounds.height - 32))
            context.strokePath()

        case .squared:
            context.setStrokeColor(lineColor)
            context.setLineWidth(0.5)
            let gridSize: CGFloat = 14.17
            var y: CGFloat = gridSize
            while y < bounds.height {
                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: bounds.width, y: y))
                y += gridSize
            }
            var x: CGFloat = gridSize
            while x < bounds.width {
                context.move(to: CGPoint(x: x, y: 0))
                context.addLine(to: CGPoint(x: x, y: bounds.height))
                x += gridSize
            }
            context.strokePath()

        case .staves:
            context.setStrokeColor(lineColor)
            context.setLineWidth(0.8)
            let staffLineSpacing: CGFloat = 8.0
            let staffGap: CGFloat = 48.0
            var topY: CGFloat = 80.0
            while topY + 4 * staffLineSpacing < bounds.height - 40.0 {
                for lineIdx in 0..<5 {
                    let y = topY + CGFloat(lineIdx) * staffLineSpacing
                    context.move(to: CGPoint(x: 48, y: y))
                    context.addLine(to: CGPoint(x: bounds.width - 48, y: y))
                }
                topY += 4 * staffLineSpacing + staffGap
            }
            context.strokePath()
        }
    }

    private func rebuildBitmapCache() {
        let size = bounds.size
        guard size.width > 0 && size.height > 0 else { return }

        let image = NSImage(size: size)
        image.lockFocus()

        if let context = NSGraphicsContext.current?.cgContext {
            // First render background highlighters (multiply blend)
            for stroke in strokes where stroke.tool == .highlighter {
                renderStroke(stroke, in: context)
            }

            // Next render opaque inks (ballpoint, fountain, etc.)
            for stroke in strokes where stroke.tool != .highlighter {
                renderStroke(stroke, in: context)
            }
        }

        image.unlockFocus()
        self.cachedBitmap = image
        self.isCacheDirty = false
    }

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
                context.setLineWidth(1.5)
                context.setLineDash(phase: 0, lengths: [4.0, 3.0])
                context.addPath(path)
                context.drawPath(using: .fillStroke)
            } else {
                context.setFillColor(baseColor.withAlphaComponent(0.96).cgColor)
                context.setStrokeColor(NSColor(calibratedRed: 0.82, green: 0.50, blue: 0.02, alpha: 1.0).cgColor)
                context.setLineWidth(1.0)
                context.addPath(path)
                context.drawPath(using: .fillStroke)
            }
            context.restoreGState()
            return
        }

        if stroke.pattern == .dashed || stroke.pattern == .dotted {
            let lengths: [CGFloat] = (stroke.pattern == .dashed) ? [12.0, 6.0] : [3.0, 5.0]
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

    // MARK: - Input Handling (Tablet Pressure + Mouse/Trackpad Velocity + Lasso)
    public override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        strokeStartTime = Date()
        lastEventPoint = loc
        lastEventTime = event.timestamp

        if activeTool == .eraser {
            eraseStrokesAt(point: loc)
            return
        }

        if activeTool == .lasso {
            handleLassoMouseDown(at: loc)
            return
        }

        // Check for Tape reveal/hide toggle
        for (idx, stroke) in strokes.enumerated().reversed() {
            if stroke.tool == .tape {
                let b = stroke.boundingRect
                let tapeRect = CGRect(x: b.minX - 4, y: b.minY - 4, width: max(24, b.maxX - b.minX + 8), height: max(20, b.maxY - b.minY + 8))
                if tapeRect.contains(loc) {
                    strokes[idx].isTapeRevealed = !(strokes[idx].isTapeRevealed ?? false)
                    isCacheDirty = true
                    needsDisplay = true
                    onStrokesChanged?(strokes)
                    return
                }
            }
        }

        // If previously had a selection and switched away or tapped, deselect
        if !selectedStrokeIds.isEmpty {
            selectedStrokeIds.removeAll()
            needsDisplay = true
        }

        isDrawing = true
        let pressure = calculatePressure(event: event, currentPoint: loc)
        let initialPt = snapPointToRulerIfClose(loc)
        livePoints = [InkPoint(x: Double(initialPt.x), y: Double(initialPt.y), pressure: pressure, timeOffset: 0.0)]
        needsDisplay = true

        dragJitterOrigin = loc
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
        let loc = convert(event.locationInWindow, from: nil)

        if activeTool == .eraser {
            eraseStrokesAt(point: loc)
            return
        }

        if activeTool == .lasso {
            handleLassoMouseDragged(to: loc)
            return
        }

        guard isDrawing else { return }

        // Ruler edge snapping
        var activePt = snapPointToRulerIfClose(loc)

        // Highlighter auto-straighten horizontal lock
        if activeTool == .highlighter, let firstPt = livePoints.first, livePoints.count >= 6 {
            let dx = abs(activePt.x - CGFloat(firstPt.x))
            let dy = abs(activePt.y - CGFloat(firstPt.y))
            if dx > 40.0 && dy < 14.0 {
                activePt.y = CGFloat(firstPt.y)
            }
        }

        let pressure = calculatePressure(event: event, currentPoint: loc)
        let elapsed = Date().timeIntervalSince(strokeStartTime)
        livePoints.append(InkPoint(x: Double(activePt.x), y: Double(activePt.y), pressure: pressure, timeOffset: elapsed))

        // Reset shape timer if moved appreciably
        if hypot(loc.x - dragJitterOrigin.x, loc.y - dragJitterOrigin.y) > 8.0 {
            dragJitterOrigin = loc
            shapeHoldTimer?.invalidate()
            if isShapeSnappingEnabled {
                shapeHoldTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.checkShapeHoldTrigger()
                    }
                }
            }
        }

        lastEventPoint = loc
        lastEventTime = event.timestamp

        // Refresh canvas for live stroke overlay
        needsDisplay = true
    }

    public override func mouseUp(with event: NSEvent) {
        shapeHoldTimer?.invalidate()
        shapeHoldTimer = nil

        let loc = convert(event.locationInWindow, from: nil)

        if activeTool == .eraser { return }

        if activeTool == .lasso {
            handleLassoMouseUp(at: loc)
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

        strokes.append(newStroke)
        livePoints.removeAll()
        isDrawing = false
        isCacheDirty = true
        needsDisplay = true

        onStrokesChanged?(strokes)
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
        context.setLineWidth(1.0)
        context.strokePath()

        // Graduation marks along top edge
        context.setStrokeColor(NSColor.secondaryLabelColor.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(1.0)
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
        let selected = strokes.filter { selectedStrokeIds.contains($0.id) }
        let unselected = strokes.filter { !selectedStrokeIds.contains($0.id) }
        self.strokes = unselected + selected
        self.isCacheDirty = true
        self.needsDisplay = true
        onStrokesChanged?(strokes)
    }

    public func sendSelectionToBack() {
        guard !selectedStrokeIds.isEmpty else { return }
        let selected = strokes.filter { selectedStrokeIds.contains($0.id) }
        let unselected = strokes.filter { !selectedStrokeIds.contains($0.id) }
        self.strokes = selected + unselected
        self.isCacheDirty = true
        self.needsDisplay = true
        onStrokesChanged?(strokes)
    }

    // MARK: - Lasso Logic
    private func handleLassoMouseDown(at loc: CGPoint) {
        // If clicking inside current selection bounding box, begin drag translation
        if !selectedStrokeIds.isEmpty {
            let selectedStrokes = strokes.filter { selectedStrokeIds.contains($0.id) }
            if !selectedStrokes.isEmpty {
                var minX = Double.greatestFiniteMagnitude
                var minY = Double.greatestFiniteMagnitude
                var maxX = -Double.greatestFiniteMagnitude
                var maxY = -Double.greatestFiniteMagnitude
                for s in selectedStrokes {
                    let b = s.boundingRect
                    minX = min(minX, b.minX)
                    minY = min(minY, b.minY)
                    maxX = max(maxX, b.maxX)
                    maxY = max(maxY, b.maxY)
                }
                let pad: CGFloat = 16.0
                let selRect = CGRect(x: CGFloat(minX) - pad, y: CGFloat(minY) - pad, width: CGFloat(maxX - minX) + pad * 2, height: CGFloat(maxY - minY) + pad * 2)
                if selRect.contains(loc) {
                    isDraggingSelection = true
                    dragStartLocation = loc
                    return
                }
            }
        }

        // Otherwise begin drawing lasso loop
        selectedStrokeIds.removeAll()
        isDraggingSelection = false
        lassoPoints = [loc]
        needsDisplay = true
    }

    private func handleLassoMouseDragged(to loc: CGPoint) {
        if isDraggingSelection {
            let dx = Double(loc.x - dragStartLocation.x)
            let dy = Double(loc.y - dragStartLocation.y)
            dragStartLocation = loc

            // Translate selected strokes
            strokes = strokes.map { stroke in
                if selectedStrokeIds.contains(stroke.id) {
                    return InkGeometry.translate(stroke: stroke, dx: dx, dy: dy)
                }
                return stroke
            }
            isCacheDirty = true
            needsDisplay = true
            return
        }

        lassoPoints.append(loc)
        needsDisplay = true
    }

    private func handleLassoMouseUp(at loc: CGPoint) {
        if isDraggingSelection {
            isDraggingSelection = false
            onStrokesChanged?(strokes)
            return
        }

        guard lassoPoints.count > 3 else {
            lassoPoints.removeAll()
            selectedStrokeIds.removeAll()
            needsDisplay = true
            return
        }

        // Find all strokes that intersect or fall within lasso polygon
        var newlySelected: Set<String> = []
        for stroke in strokes {
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
        strokes.removeAll { selectedStrokeIds.contains($0.id) }
        selectedStrokeIds.removeAll()
        isCacheDirty = true
        needsDisplay = true
        onStrokesChanged?(strokes)
    }

    private func eraseStrokesAt(point: CGPoint) {
        let beforeCount = strokes.count
        strokes.removeAll { stroke in
            InkGeometry.hitTest(stroke: stroke, point: point, eraserRadius: CGFloat(activeWidth))
        }

        if strokes.count != beforeCount {
            isCacheDirty = true
            needsDisplay = true
            onStrokesChanged?(strokes)
        }
    }

    private func calculatePressure(event: NSEvent, currentPoint: CGPoint) -> Double {
        // If hardware tablet / Apple Pencil pressure exists, use it directly
        let devicePressure = Double(event.pressure)
        if devicePressure > 0.01 {
            return max(0.1, min(1.0, devicePressure))
        }

        // Fallback for Trackpad / Mouse: simulate pressure inversely proportional to velocity
        let dt = max(0.005, event.timestamp - lastEventTime)
        let dist = InkGeometry.distance(currentPoint, lastEventPoint)
        let speed = dist / CGFloat(dt) // points per second

        // Fast strokes taper thin; slow deliberate strokes widen
        let normalizedSpeed = max(0.0, min(1.0, Double(speed) / 1200.0))
        let simulatedPressure = 0.85 - (normalizedSpeed * 0.55)
        return max(0.2, min(1.0, simulatedPressure))
    }
}

// MARK: - NSColor Hex Helpers
extension NSColor {
    public convenience init?(hex: String) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleanHex.hasPrefix("#") { cleanHex.removeFirst() }

        var rgb: UInt64 = 0
        guard Scanner(string: cleanHex).scanHexInt64(&rgb) else { return nil }

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }

    public func toHex() -> String {
        guard let rgbColor = usingColorSpace(.sRGB) else { return "#1E293B" }
        let r = Int(round(rgbColor.redComponent * 255))
        let g = Int(round(rgbColor.greenComponent * 255))
        let b = Int(round(rgbColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
