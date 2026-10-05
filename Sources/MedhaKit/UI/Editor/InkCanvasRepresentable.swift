import SwiftUI
import AppKit

public struct InkCanvasRepresentable: NSViewRepresentable {
    public let docId: String
    public let pageIndex: Int
    public let templateType: InkTemplateType
    public let pdfPath: String?
    public let pdfPageIndex: Int?
    public let strokes: [InkStroke]
    public let activeTool: InkToolType
    public let activeColorHex: String
    public let activeWidth: Double
    public let onStrokesChanged: ([InkStroke]) -> Void

    public init(
        docId: String,
        pageIndex: Int = 0,
        templateType: InkTemplateType = .lined,
        pdfPath: String? = nil,
        pdfPageIndex: Int? = nil,
        strokes: [InkStroke],
        activeTool: InkToolType,
        activeColorHex: String,
        activeWidth: Double,
        onStrokesChanged: @escaping ([InkStroke]) -> Void
    ) {
        self.docId = docId
        self.pageIndex = pageIndex
        self.templateType = templateType
        self.pdfPath = pdfPath
        self.pdfPageIndex = pdfPageIndex
        self.strokes = strokes
        self.activeTool = activeTool
        self.activeColorHex = activeColorHex
        self.activeWidth = activeWidth
        self.onStrokesChanged = onStrokesChanged
    }

    public func makeNSView(context: Context) -> InkCanvasNSView {
        let view = InkCanvasNSView(
            docId: docId,
            pageIndex: pageIndex,
            templateType: templateType,
            pdfPath: pdfPath,
            pdfPageIndex: pdfPageIndex,
            initialStrokes: strokes,
            onStrokesChanged: onStrokesChanged
        )
        updateViewSettings(view)
        return view
    }

    public func updateNSView(_ nsView: InkCanvasNSView, context: Context) {
        updateViewSettings(nsView)

        if nsView.templateType != templateType {
            nsView.setTemplate(templateType)
        }

        nsView.setPDFInfo(pdfPath: pdfPath, pdfPageIndex: pdfPageIndex)

        // Only update strokes if external source changed them (e.g. undo/redo or note switch)
        if nsView.strokes != strokes {
            nsView.setStrokes(strokes)
        }
    }

    private func updateViewSettings(_ nsView: InkCanvasNSView) {
        nsView.activeTool = activeTool
        nsView.activeWidth = activeWidth
        if let color = NSColor(hex: activeColorHex) {
            nsView.activeColor = color
        }
        nsView.activeOpacity = (activeTool == .highlighter) ? 0.6 : 1.0
    }
}
