import SwiftUI
import AppKit

public struct InkCanvasViewportRepresentable: NSViewRepresentable {
    public let docId: String
    public let canvasMode: InkCanvasMode
    public let templateType: InkTemplateType
    public let pdfPath: String?
    public let pdfPageIndex: Int?
    public let pagesStrokes: [Int: [InkStroke]]
    public let totalPagesCount: Int
    public let activeTool: InkToolType
    public let activeColorHex: String
    public let activeWidth: Double
    public let activePattern: StrokePattern
    public let isRulerActive: Bool
    public let rulerAngle: CGFloat
    public let isShapeSnappingEnabled: Bool
    @Binding public var zoomScale: CGFloat
    @Binding public var isHandToolActive: Bool
    public let viewportRef: Binding<InkCanvasViewportNSView?>?
    public let onStrokesChanged: (Int, [InkStroke]) -> Void
    public let onAddPage: (() -> Void)?
    public let onDeletePage: ((Int) -> Void)?
    public let onPerformUndo: (() -> Void)?
    public let onPerformRedo: (() -> Void)?
    public let onExitFocusMode: (() -> Void)?

    public init(
        docId: String,
        canvasMode: InkCanvasMode,
        templateType: InkTemplateType,
        pdfPath: String? = nil,
        pdfPageIndex: Int? = nil,
        pagesStrokes: [Int: [InkStroke]],
        totalPagesCount: Int = 1,
        activeTool: InkToolType,
        activeColorHex: String,
        activeWidth: Double,
        activePattern: StrokePattern = .solid,
        isRulerActive: Bool = false,
        rulerAngle: CGFloat = 0.0,
        isShapeSnappingEnabled: Bool = true,
        zoomScale: Binding<CGFloat>,
        isHandToolActive: Binding<Bool>,
        viewportRef: Binding<InkCanvasViewportNSView?>? = nil,
        onStrokesChanged: @escaping (Int, [InkStroke]) -> Void,
        onAddPage: (() -> Void)? = nil,
        onDeletePage: ((Int) -> Void)? = nil,
        onPerformUndo: (() -> Void)? = nil,
        onPerformRedo: (() -> Void)? = nil,
        onExitFocusMode: (() -> Void)? = nil
    ) {
        self.docId = docId
        self.canvasMode = canvasMode
        self.templateType = templateType
        self.pdfPath = pdfPath
        self.pdfPageIndex = pdfPageIndex
        self.pagesStrokes = pagesStrokes
        self.totalPagesCount = totalPagesCount
        self.activeTool = activeTool
        self.activeColorHex = activeColorHex
        self.activeWidth = activeWidth
        self.activePattern = activePattern
        self.isRulerActive = isRulerActive
        self.rulerAngle = rulerAngle
        self.isShapeSnappingEnabled = isShapeSnappingEnabled
        self._zoomScale = zoomScale
        self._isHandToolActive = isHandToolActive
        self.viewportRef = viewportRef
        self.onStrokesChanged = onStrokesChanged
        self.onAddPage = onAddPage
        self.onDeletePage = onDeletePage
        self.onPerformUndo = onPerformUndo
        self.onPerformRedo = onPerformRedo
        self.onExitFocusMode = onExitFocusMode
    }

    public func makeNSView(context: Context) -> InkCanvasViewportNSView {
        let view = InkCanvasViewportNSView(
            docId: docId,
            canvasMode: canvasMode,
            templateType: templateType,
            pdfPath: pdfPath,
            pdfPageIndex: pdfPageIndex,
            pagesStrokes: pagesStrokes,
            totalPagesCount: totalPagesCount
        )

        view.zoomScale = zoomScale
        view.isHandToolActive = isHandToolActive
        updateViewSettings(view)

        view.onZoomScaleChanged = { newScale in
            DispatchQueue.main.async {
                self.zoomScale = newScale
            }
        }
        view.onStrokesChanged = onStrokesChanged
        view.onAddPage = onAddPage
        view.onDeletePage = onDeletePage
        view.onPerformUndo = onPerformUndo
        view.onPerformRedo = onPerformRedo
        view.onExitFocusMode = onExitFocusMode

        DispatchQueue.main.async {
            self.viewportRef?.wrappedValue = view
        }

        return view
    }

    public func updateNSView(_ nsView: InkCanvasViewportNSView, context: Context) {
        if nsView.docId != docId {
            nsView.docId = docId
            nsView.centerCanvasInitially()
        }

        nsView.canvasMode = canvasMode
        nsView.templateType = templateType
        nsView.pdfPath = pdfPath
        nsView.pdfPageIndex = pdfPageIndex
        nsView.totalPagesCount = max(1, totalPagesCount)

        if abs(nsView.zoomScale - zoomScale) > 0.001 {
            nsView.zoomScale = zoomScale
        }

        if nsView.isHandToolActive != isHandToolActive {
            nsView.isHandToolActive = isHandToolActive
        }

        nsView.onExitFocusMode = onExitFocusMode
        updateViewSettings(nsView)

        // Only update pagesStrokes if externally modified (e.g. undo/redo or note switch)
        if nsView.pagesStrokes != pagesStrokes {
            nsView.pagesStrokes = pagesStrokes
            nsView.recalculateInfiniteVerticalHeight()
            nsView.needsDisplay = true
        }

        DispatchQueue.main.async {
            if self.viewportRef?.wrappedValue !== nsView {
                self.viewportRef?.wrappedValue = nsView
            }
        }
    }

    private func updateViewSettings(_ nsView: InkCanvasViewportNSView) {
        nsView.activeTool = activeTool
        nsView.activeWidth = activeWidth
        nsView.activePattern = activePattern
        nsView.isRulerActive = isRulerActive
        nsView.rulerAngle = rulerAngle
        nsView.isShapeSnappingEnabled = isShapeSnappingEnabled
        if let color = NSColor(hex: activeColorHex) {
            nsView.activeColor = color
        }
        nsView.activeOpacity = (activeTool == .highlighter) ? 0.6 : 1.0
    }
}
