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

    /// Exports an ink document to a crisp Vector PDF according to its canvas mode
    public static func exportDocumentToVectorPDF(
        title: String,
        pages: [InkDocumentPage],
        canvasMode: InkCanvasMode,
        pageWidth: CGFloat = 794.0,
        pageHeight: CGFloat = 1123.0
    ) -> Data? {
        switch canvasMode {
        case .a4Pages:
            return exportToVectorPDF(title: title, pages: pages, pageWidth: pageWidth, pageHeight: pageHeight)

        case .infiniteVertical:
            return exportInfiniteVerticalToPDF(title: title, pages: pages, pageWidth: pageWidth, pageHeight: pageHeight)

        case .infinite2D:
            return exportInfinite2DToPDF(title: title, pages: pages, minWidth: pageWidth, minHeight: pageHeight)
        }
    }

    /// Exports an ink document to high-resolution PNG bitmap according to its canvas mode
    public static func exportDocumentToPNG(
        pages: [InkDocumentPage],
        canvasMode: InkCanvasMode,
        pageWidth: CGFloat = 794.0,
        pageHeight: CGFloat = 1123.0,
        scale: CGFloat = 2.0
    ) -> Data? {
        switch canvasMode {
        case .a4Pages:
            guard let first = pages.first else { return nil }
            return exportToPNG(page: first, pageWidth: pageWidth, pageHeight: pageHeight, scale: scale)

        case .infiniteVertical:
            return exportInfiniteVerticalToPNG(pages: pages, pageWidth: pageWidth, pageHeight: pageHeight, scale: scale)

        case .infinite2D:
            return exportInfinite2DToPNG(pages: pages, minWidth: pageWidth, minHeight: pageHeight, scale: scale)
        }
    }

    // MARK: - Infinite Vertical Export
    private static func exportInfiniteVerticalToPDF(
        title: String,
        pages: [InkDocumentPage],
        pageWidth: CGFloat,
        pageHeight: CGFloat
    ) -> Data? {
        let allStrokes = pages.flatMap { InkPagePayload.deserialize(from: $0.strokesData).strokes }
        let template = pages.first?.templateType ?? .lined

        var maxY: Double = Double(pageHeight)
        for stroke in allStrokes {
            for pt in stroke.points {
                if pt.y > maxY { maxY = pt.y }
            }
        }

        // Account for imported PDF pages
        let pdfPages = pages.filter { $0.pdfPath != nil && $0.pdfPageIndex != nil }
        let pdfTotalHeight = CGFloat(pdfPages.count) * (pageHeight + 40.0)

        let totalHeight = max(max(pageHeight, ceil(CGFloat(maxY + 40.0) / pageHeight) * pageHeight), pdfTotalHeight)
        let sliceCount = max(1, Int(round(totalHeight / pageHeight)))

        let pdfData = NSMutableData()
        var pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let pdfContext = CGContext(consumer: consumer, mediaBox: &pageRect, nil) else {
            return nil
        }

        for sliceIndex in 0..<sliceCount {
            var box = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
            pdfContext.beginPage(mediaBox: &box)

            pdfContext.saveGState()
            pdfContext.translateBy(x: 0, y: pageHeight)
            pdfContext.scaleBy(x: 1.0, y: -1.0)

            // Draw template background for this slice
            drawTemplate(template: template, width: pageWidth, height: pageHeight, in: pdfContext)

            // Clip & translate to slice viewport
            let sliceOffsetY = CGFloat(sliceIndex) * pageHeight
            pdfContext.clip(to: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
            pdfContext.translateBy(x: 0, y: -sliceOffsetY)

            // Render any PDF page falling on this vertical canvas area
            for (idx, page) in pdfPages.enumerated() {
                if let path = page.pdfPath, let pIdx = page.pdfPageIndex,
                   let pdfURL = InkPDFImporterService.resolvePDFURL(for: path) {
                    let pageY = CGFloat(idx) * (pageHeight + 40.0)
                    let pageTargetRect = CGRect(x: 0, y: pageY, width: pageWidth, height: pageHeight)
                    InkPDFImporterService.renderPDFPage(from: pdfURL, pageIndex: pIdx, in: pdfContext, targetRect: pageTargetRect)
                }
            }

            // Render strokes
            for stroke in allStrokes where stroke.tool == .highlighter {
                renderStrokeToCGContext(stroke, in: pdfContext)
            }
            for stroke in allStrokes where stroke.tool != .highlighter {
                renderStrokeToCGContext(stroke, in: pdfContext)
            }

            pdfContext.restoreGState()

            drawPageNumber(pageNumber: sliceIndex + 1, totalPages: sliceCount, in: pdfContext, width: pageWidth)
            pdfContext.endPage()
        }

        pdfContext.closePDF()
        return pdfData as Data
    }

    private static func exportInfiniteVerticalToPNG(
        pages: [InkDocumentPage],
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        scale: CGFloat
    ) -> Data? {
        let allStrokes = pages.flatMap { InkPagePayload.deserialize(from: $0.strokesData).strokes }
        let template = pages.first?.templateType ?? .lined

        var maxY: Double = Double(pageHeight)
        for stroke in allStrokes {
            for pt in stroke.points {
                if pt.y > maxY { maxY = pt.y }
            }
        }

        // Account for imported PDF pages
        let pdfPages = pages.filter { $0.pdfPath != nil && $0.pdfPageIndex != nil }
        let pdfTotalHeight = CGFloat(pdfPages.count) * (pageHeight + 40.0)

        let totalHeight = max(max(pageHeight, CGFloat(maxY + 60.0)), pdfTotalHeight)

        let scaledWidth = Int(pageWidth * scale)
        let scaledHeight = Int(totalHeight * scale)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: nil,
            width: scaledWidth,
            height: scaledHeight,
            bitsPerComponent: 8,
            bytesPerRow: scaledWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.scaleBy(x: scale, y: scale)
        drawTemplate(template: template, width: pageWidth, height: totalHeight, in: context)

        // Render PDF pages
        for (idx, page) in pdfPages.enumerated() {
            if let path = page.pdfPath, let pIdx = page.pdfPageIndex,
               let pdfURL = InkPDFImporterService.resolvePDFURL(for: path) {
                let pageY = CGFloat(idx) * (pageHeight + 40.0)
                let pageTargetRect = CGRect(x: 0, y: pageY, width: pageWidth, height: pageHeight)
                InkPDFImporterService.renderPDFPage(from: pdfURL, pageIndex: pIdx, in: context, targetRect: pageTargetRect)
            }
        }

        for stroke in allStrokes where stroke.tool == .highlighter {
            renderStrokeToCGContext(stroke, in: context)
        }
        for stroke in allStrokes where stroke.tool != .highlighter {
            renderStrokeToCGContext(stroke, in: context)
        }

        guard let cgImage = context.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
    }

    // MARK: - Infinite 2D Export
    private static func exportInfinite2DToPDF(
        title: String,
        pages: [InkDocumentPage],
        minWidth: CGFloat,
        minHeight: CGFloat
    ) -> Data? {
        let allStrokes = pages.flatMap { InkPagePayload.deserialize(from: $0.strokesData).strokes }
        let template = pages.first?.templateType ?? .dotGrid

        var boundingBox = InkGeometry.combinedBoundingBox(for: allStrokes)

        let pdfPages = pages.filter { $0.pdfPath != nil && $0.pdfPageIndex != nil }
        if !pdfPages.isEmpty {
            let totalPDFH = CGFloat(pdfPages.count) * (minHeight + 40.0)
            let pdfRect = CGRect(x: 0, y: 0, width: minWidth, height: totalPDFH)
            if let existing = boundingBox {
                boundingBox = existing.union(pdfRect)
            } else {
                boundingBox = pdfRect
            }
        }

        let effectiveBox = boundingBox ?? CGRect(x: 0, y: 0, width: minWidth, height: minHeight)
        let paddedRect = effectiveBox.insetBy(dx: -48.0, dy: -48.0)
        let exportWidth = max(minWidth, paddedRect.width)
        let exportHeight = max(minHeight, paddedRect.height)

        let pdfData = NSMutableData()
        var pageRect = CGRect(x: 0, y: 0, width: exportWidth, height: exportHeight)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let pdfContext = CGContext(consumer: consumer, mediaBox: &pageRect, nil) else {
            return nil
        }

        var box = CGRect(x: 0, y: 0, width: exportWidth, height: exportHeight)
        pdfContext.beginPage(mediaBox: &box)

        pdfContext.saveGState()
        pdfContext.translateBy(x: 0, y: exportHeight)
        pdfContext.scaleBy(x: 1.0, y: -1.0)

        // Draw template across the framed bounding area
        drawTemplate(template: template, width: exportWidth, height: exportHeight, in: pdfContext)

        // Translate world coordinates so strokes & pages align inside the padded area
        pdfContext.translateBy(x: -paddedRect.minX, y: -paddedRect.minY)

        // Render PDF pages with white paper backdrop
        for (idx, page) in pdfPages.enumerated() {
            if let path = page.pdfPath, let pIdx = page.pdfPageIndex,
               let pdfURL = InkPDFImporterService.resolvePDFURL(for: path) {
                let pageY = CGFloat(idx) * (minHeight + 40.0)
                let pageTargetRect = CGRect(x: 0, y: pageY, width: minWidth, height: minHeight)

                pdfContext.saveGState()
                pdfContext.setFillColor(NSColor.white.cgColor)
                pdfContext.fill(pageTargetRect)
                pdfContext.restoreGState()

                InkPDFImporterService.renderPDFPage(from: pdfURL, pageIndex: pIdx, in: pdfContext, targetRect: pageTargetRect)
            }
        }

        for stroke in allStrokes where stroke.tool == .highlighter {
            renderStrokeToCGContext(stroke, in: pdfContext)
        }
        for stroke in allStrokes where stroke.tool != .highlighter {
            renderStrokeToCGContext(stroke, in: pdfContext)
        }

        pdfContext.restoreGState()
        pdfContext.endPage()
        pdfContext.closePDF()

        return pdfData as Data
    }

    private static func exportInfinite2DToPNG(
        pages: [InkDocumentPage],
        minWidth: CGFloat,
        minHeight: CGFloat,
        scale: CGFloat
    ) -> Data? {
        let allStrokes = pages.flatMap { InkPagePayload.deserialize(from: $0.strokesData).strokes }
        let template = pages.first?.templateType ?? .dotGrid

        var boundingBox = InkGeometry.combinedBoundingBox(for: allStrokes)

        let pdfPages = pages.filter { $0.pdfPath != nil && $0.pdfPageIndex != nil }
        if !pdfPages.isEmpty {
            let totalPDFH = CGFloat(pdfPages.count) * (minHeight + 40.0)
            let pdfRect = CGRect(x: 0, y: 0, width: minWidth, height: totalPDFH)
            if let existing = boundingBox {
                boundingBox = existing.union(pdfRect)
            } else {
                boundingBox = pdfRect
            }
        }

        let effectiveBox = boundingBox ?? CGRect(x: 0, y: 0, width: minWidth, height: minHeight)
        let paddedRect = effectiveBox.insetBy(dx: -48.0, dy: -48.0)
        let exportWidth = max(minWidth, paddedRect.width)
        let exportHeight = max(minHeight, paddedRect.height)

        let scaledWidth = Int(exportWidth * scale)
        let scaledHeight = Int(exportHeight * scale)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: nil,
            width: scaledWidth,
            height: scaledHeight,
            bitsPerComponent: 8,
            bytesPerRow: scaledWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.scaleBy(x: scale, y: scale)
        drawTemplate(template: template, width: exportWidth, height: exportHeight, in: context)

        context.translateBy(x: -paddedRect.minX, y: -paddedRect.minY)

        // Render PDF pages
        for (idx, page) in pdfPages.enumerated() {
            if let path = page.pdfPath, let pIdx = page.pdfPageIndex,
               let pdfURL = InkPDFImporterService.resolvePDFURL(for: path) {
                let pageY = CGFloat(idx) * (minHeight + 40.0)
                let pageTargetRect = CGRect(x: 0, y: pageY, width: minWidth, height: minHeight)

                context.saveGState()
                context.setFillColor(NSColor.white.cgColor)
                context.fill(pageTargetRect)
                context.restoreGState()

                InkPDFImporterService.renderPDFPage(from: pdfURL, pageIndex: pIdx, in: context, targetRect: pageTargetRect)
            }
        }

        for stroke in allStrokes where stroke.tool == .highlighter {
            renderStrokeToCGContext(stroke, in: context)
        }
        for stroke in allStrokes where stroke.tool != .highlighter {
            renderStrokeToCGContext(stroke, in: context)
        }

        guard let cgImage = context.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
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
