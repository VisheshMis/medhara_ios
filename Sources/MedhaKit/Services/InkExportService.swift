import Foundation
import CoreGraphics
import AppKit

public enum InkExportService {

    /// Exports all pages of an ink document to a crisp multi-page Vector PDF
    public static func exportToVectorPDF(
        title: String,
        pages: [InkDocumentPage],
        pageWidth: CGFloat = 794.0,
        pageHeight: CGFloat = 1123.0
    ) -> Data? {
        let pdfData = NSMutableData()
        var pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let pdfContext = CGContext(consumer: consumer, mediaBox: &pageRect, nil) else {
            return nil
        }

        for (pageIndex, page) in pages.enumerated() {
            var box = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
            pdfContext.beginPage(mediaBox: &box)

            // PDF origin is bottom-left; flip vertically for top-left drawing coordinates
            pdfContext.saveGState()
            pdfContext.translateBy(x: 0, y: pageHeight)
            pdfContext.scaleBy(x: 1.0, y: -1.0)

            // 1. Draw page background template or imported PDF
            drawTemplate(
                template: page.templateType,
                width: pageWidth,
                height: pageHeight,
                in: pdfContext
            )

            // If page has an imported PDF page attached, render it
            if let pdfPath = page.pdfPath, let pIdx = page.pdfPageIndex,
               let pdfURL = InkPDFImporterService.resolvePDFURL(for: pdfPath) {
                InkPDFImporterService.renderPDFPage(
                    from: pdfURL,
                    pageIndex: pIdx,
                    in: pdfContext,
                    targetRect: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
                )
            }

            // 2. Render vector strokes
            let payload = InkPagePayload.deserialize(from: page.strokesData)

            // Highlighters first (multiply blend)
            for stroke in payload.strokes where stroke.tool == .highlighter {
                renderStrokeToCGContext(stroke, in: pdfContext)
            }

            // Opaque inks second (pen, fountain, etc.)
            for stroke in payload.strokes where stroke.tool != .highlighter {
                renderStrokeToCGContext(stroke, in: pdfContext)
            }

            pdfContext.restoreGState()

            // 3. Optional small page number footer
            drawPageNumber(pageNumber: pageIndex + 1, totalPages: pages.count, in: pdfContext, width: pageWidth)

            pdfContext.endPage()
        }

        pdfContext.closePDF()
        return pdfData as Data
    }

    /// Exports a specific ink page to a high-resolution PNG bitmap
    public static func exportToPNG(
        page: InkDocumentPage,
        pageWidth: CGFloat = 794.0,
        pageHeight: CGFloat = 1123.0,
        scale: CGFloat = 2.0 // 2x Retina resolution
    ) -> Data? {
        let scaledWidth = Int(pageWidth * scale)
        let scaledHeight = Int(pageHeight * scale)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: scaledWidth,
            height: scaledHeight,
            bitsPerComponent: 8,
            bytesPerRow: scaledWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.scaleBy(x: scale, y: scale)

        // Draw background template
        drawTemplate(
            template: page.templateType,
            width: pageWidth,
            height: pageHeight,
            in: context
        )

        // If page has an imported PDF page attached, render it
        if let pdfPath = page.pdfPath, let pIdx = page.pdfPageIndex,
           let pdfURL = InkPDFImporterService.resolvePDFURL(for: pdfPath) {
            InkPDFImporterService.renderPDFPage(
                from: pdfURL,
                pageIndex: pIdx,
                in: context,
                targetRect: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
            )
        }

        // Render strokes
        let payload = InkPagePayload.deserialize(from: page.strokesData)
        for stroke in payload.strokes where stroke.tool == .highlighter {
            renderStrokeToCGContext(stroke, in: context)
        }
        for stroke in payload.strokes where stroke.tool != .highlighter {
            renderStrokeToCGContext(stroke, in: context)
        }

        guard let cgImage = context.makeImage() else { return nil }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .png, properties: [:])
    }

    // MARK: - Private Drawing Helpers
    private static func drawTemplate(
        template: InkTemplateType,
        width: CGFloat,
        height: CGFloat,
        in context: CGContext
    ) {
        // Base paper background
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let lineColor = NSColor(calibratedRed: 0.88, green: 0.91, blue: 0.95, alpha: 0.7).cgColor

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

            // Left vertical margin
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
            let spacing: CGFloat = 24.0
            let dotRadius: CGFloat = 1.2
            var y: CGFloat = spacing
            while y < height {
                var x: CGFloat = spacing
                while x < width {
                    context.fillEllipse(in: CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
                    x += spacing
                }
                y += spacing
            }
        }
    }

    private static func renderStrokeToCGContext(_ stroke: InkStroke, in context: CGContext) {
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

    private static func drawPageNumber(pageNumber: Int, totalPages: Int, in context: CGContext, width: CGFloat) {
        let text = "\(pageNumber) / \(totalPages)" as NSString
        let font = NSFont.systemFont(ofSize: 9, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let textSize = text.size(withAttributes: attrs)
        let point = NSPoint(x: (width - textSize.width) * 0.5, y: 24.0)
        text.draw(at: point, withAttributes: attrs)
    }
}
