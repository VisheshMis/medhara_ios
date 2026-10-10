import SwiftUI
import AppKit

public struct InkCanvasViewportRepresentable: NSViewRepresentable {
    public let docId: String
    public let canvasMode: InkCanvasMode
    public let templateType: InkTemplateType
    public let pdfPath: String?
    public let pdfPageIndex: Int?
    public let pagePDFInfos: [Int: (path: String, pageIndex: Int)]
    public let pagesStrokes: [Int: [InkStroke]]
    public let totalPagesCount: Int
    public let canvasNoteCards: [CanvasNoteCard]
    public let spatialPDFLayouts: [Int: (canvasX: Double, canvasY: Double, customWidth: Double?, customHeight: Double?, cropRect: CGRect?)]
    public let canvasItems: [CanvasItem]
    public let canvasConnectors: [CanvasConnector]
    public let activeTool: InkToolType
    public let activeColorHex: String
    public let activeWidth: Double
    public let activePattern: StrokePattern
    public let isRulerActive: Bool
    public let rulerAngle: CGFloat
    public let isShapeSnappingEnabled: Bool
    public let isConnectorToolActive: Bool
    public let connectorRoutingMode: ConnectorRoutingType
    @Binding public var zoomScale: CGFloat
    @Binding public var isHandToolActive: Bool
    public let viewportRef: Binding<InkCanvasViewportNSView?>?
    public let noteSummaryProvider: ((String) -> (title: String, icon: String?, snippets: [String]))?
    public let onAddNoteCard: ((String, Double, Double) -> Void)?
    public let onUpdateNoteCardPosition: ((String, Double, Double) -> Void)?
    public let onDeleteNoteCard: ((String) -> Void)?
    public let onAddCanvasItem: ((CanvasItem) -> Void)?
    public let onUpdateCanvasItemPosition: ((String, Double, Double) -> Void)?
    public let onUpdateCanvasItemSize: ((String, Double, Double) -> Void)?
    public let onDeleteCanvasItem: ((String) -> Void)?
    public let onRecordItemMoved: ((String, Double, Double, Double, Double) -> Void)?
    public let onRecordItemResized: ((String, Double, Double, Double, Double) -> Void)?
    public let onAddCanvasConnector: ((String, CanvasPortPosition, String, CanvasPortPosition, ConnectorRoutingType, String?) -> Void)?
    public let onUpdateCanvasConnectorLabel: ((String, String?) -> Void)?
    public let onDeleteCanvasConnector: ((String) -> Void)?
    public let onSelectReferencedNote: ((String) -> Void)?
    public let onUpdatePDFPageLayout: ((Int, Double, Double, Double?, Double?) -> Void)?
    public let onUpdatePDFPageCrop: ((Int, CGRect?) -> Void)?
    public let onDeletePDFPage: ((Int) -> Void)?
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
        pagePDFInfos: [Int: (path: String, pageIndex: Int)] = [:],
        pagesStrokes: [Int: [InkStroke]],
        totalPagesCount: Int = 1,
        canvasNoteCards: [CanvasNoteCard] = [],
        spatialPDFLayouts: [Int: (canvasX: Double, canvasY: Double, customWidth: Double?, customHeight: Double?, cropRect: CGRect?)] = [:],
        canvasItems: [CanvasItem] = [],
        canvasConnectors: [CanvasConnector] = [],
        activeTool: InkToolType,
        activeColorHex: String,
        activeWidth: Double,
        activePattern: StrokePattern = .solid,
        isRulerActive: Bool = false,
        rulerAngle: CGFloat = 0.0,
        isShapeSnappingEnabled: Bool = true,
        isConnectorToolActive: Bool = false,
        connectorRoutingMode: ConnectorRoutingType = .orthogonal,
        zoomScale: Binding<CGFloat>,
        isHandToolActive: Binding<Bool>,
        viewportRef: Binding<InkCanvasViewportNSView?>? = nil,
        noteSummaryProvider: ((String) -> (title: String, icon: String?, snippets: [String]))? = nil,
        onAddNoteCard: ((String, Double, Double) -> Void)? = nil,
        onUpdateNoteCardPosition: ((String, Double, Double) -> Void)? = nil,
        onDeleteNoteCard: ((String) -> Void)? = nil,
        onAddCanvasItem: ((CanvasItem) -> Void)? = nil,
        onUpdateCanvasItemPosition: ((String, Double, Double) -> Void)? = nil,
        onUpdateCanvasItemSize: ((String, Double, Double) -> Void)? = nil,
        onDeleteCanvasItem: ((String) -> Void)? = nil,
        onRecordItemMoved: ((String, Double, Double, Double, Double) -> Void)? = nil,
        onRecordItemResized: ((String, Double, Double, Double, Double) -> Void)? = nil,
        onAddCanvasConnector: ((String, CanvasPortPosition, String, CanvasPortPosition, ConnectorRoutingType, String?) -> Void)? = nil,
        onUpdateCanvasConnectorLabel: ((String, String?) -> Void)? = nil,
        onDeleteCanvasConnector: ((String) -> Void)? = nil,
        onSelectReferencedNote: ((String) -> Void)? = nil,
        onUpdatePDFPageLayout: ((Int, Double, Double, Double?, Double?) -> Void)? = nil,
        onUpdatePDFPageCrop: ((Int, CGRect?) -> Void)? = nil,
        onDeletePDFPage: ((Int) -> Void)? = nil,
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
        self.pagePDFInfos = pagePDFInfos
        self.pagesStrokes = pagesStrokes
        self.totalPagesCount = totalPagesCount
        self.canvasNoteCards = canvasNoteCards
        self.spatialPDFLayouts = spatialPDFLayouts
        self.canvasItems = canvasItems
        self.canvasConnectors = canvasConnectors
        self.activeTool = activeTool
        self.activeColorHex = activeColorHex
        self.activeWidth = activeWidth
        self.activePattern = activePattern
        self.isRulerActive = isRulerActive
        self.rulerAngle = rulerAngle
        self.isShapeSnappingEnabled = isShapeSnappingEnabled
        self.isConnectorToolActive = isConnectorToolActive
        self.connectorRoutingMode = connectorRoutingMode
        self._zoomScale = zoomScale
        self._isHandToolActive = isHandToolActive
        self.viewportRef = viewportRef
        self.noteSummaryProvider = noteSummaryProvider
        self.onAddNoteCard = onAddNoteCard
        self.onUpdateNoteCardPosition = onUpdateNoteCardPosition
        self.onDeleteNoteCard = onDeleteNoteCard
        self.onAddCanvasItem = onAddCanvasItem
        self.onUpdateCanvasItemPosition = onUpdateCanvasItemPosition
        self.onUpdateCanvasItemSize = onUpdateCanvasItemSize
        self.onDeleteCanvasItem = onDeleteCanvasItem
        self.onRecordItemMoved = onRecordItemMoved
        self.onRecordItemResized = onRecordItemResized
        self.onAddCanvasConnector = onAddCanvasConnector
        self.onUpdateCanvasConnectorLabel = onUpdateCanvasConnectorLabel
        self.onDeleteCanvasConnector = onDeleteCanvasConnector
        self.onSelectReferencedNote = onSelectReferencedNote
        self.onUpdatePDFPageLayout = onUpdatePDFPageLayout
        self.onUpdatePDFPageCrop = onUpdatePDFPageCrop
        self.onDeletePDFPage = onDeletePDFPage
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
            pagePDFInfos: pagePDFInfos,
            pagesStrokes: pagesStrokes,
            totalPagesCount: totalPagesCount,
            canvasNoteCards: canvasNoteCards,
            spatialPDFLayouts: spatialPDFLayouts,
            canvasItems: canvasItems,
            canvasConnectors: canvasConnectors
        )

        view.zoomScale = zoomScale
        view.isHandToolActive = isHandToolActive
        view.isConnectorToolActive = isConnectorToolActive
        view.connectorRoutingMode = connectorRoutingMode
        view.noteSummaryProvider = noteSummaryProvider
        view.onAddNoteCard = onAddNoteCard
        view.onUpdateNoteCardPosition = onUpdateNoteCardPosition
        view.onDeleteNoteCard = onDeleteNoteCard
        view.onAddCanvasItem = onAddCanvasItem
        view.onUpdateCanvasItemPosition = onUpdateCanvasItemPosition
        view.onUpdateCanvasItemSize = onUpdateCanvasItemSize
        view.onDeleteCanvasItem = onDeleteCanvasItem
        view.onRecordItemMoved = onRecordItemMoved
        view.onRecordItemResized = onRecordItemResized
        view.onAddCanvasConnector = onAddCanvasConnector
        view.onUpdateCanvasConnectorLabel = onUpdateCanvasConnectorLabel
        view.onDeleteCanvasConnector = onDeleteCanvasConnector
        view.onSelectReferencedNote = onSelectReferencedNote
        view.onUpdatePDFPageLayout = onUpdatePDFPageLayout
        view.onUpdatePDFPageCrop = onUpdatePDFPageCrop
        view.onDeletePDFPage = onDeletePDFPage
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
        nsView.pagePDFInfos = pagePDFInfos
        nsView.totalPagesCount = max(1, totalPagesCount)
        nsView.canvasNoteCards = canvasNoteCards
        nsView.spatialPDFLayouts = spatialPDFLayouts
        nsView.canvasItems = canvasItems
        nsView.canvasConnectors = canvasConnectors
        nsView.isConnectorToolActive = isConnectorToolActive
        nsView.connectorRoutingMode = connectorRoutingMode
        nsView.noteSummaryProvider = noteSummaryProvider
        nsView.onAddNoteCard = onAddNoteCard
        nsView.onUpdateNoteCardPosition = onUpdateNoteCardPosition
        nsView.onDeleteNoteCard = onDeleteNoteCard
        nsView.onAddCanvasItem = onAddCanvasItem
        nsView.onUpdateCanvasItemPosition = onUpdateCanvasItemPosition
        nsView.onUpdateCanvasItemSize = onUpdateCanvasItemSize
        nsView.onDeleteCanvasItem = onDeleteCanvasItem
        nsView.onRecordItemMoved = onRecordItemMoved
        nsView.onRecordItemResized = onRecordItemResized
        nsView.onAddCanvasConnector = onAddCanvasConnector
        nsView.onUpdateCanvasConnectorLabel = onUpdateCanvasConnectorLabel
        nsView.onDeleteCanvasConnector = onDeleteCanvasConnector
        nsView.onSelectReferencedNote = onSelectReferencedNote
        nsView.onUpdatePDFPageLayout = onUpdatePDFPageLayout
        nsView.onUpdatePDFPageCrop = onUpdatePDFPageCrop
        nsView.onDeletePDFPage = onDeletePDFPage


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
