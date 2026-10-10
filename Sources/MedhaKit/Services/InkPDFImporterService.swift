import Foundation
import CoreGraphics
import PDFKit
import AppKit

public enum InkPDFImporterService {

    /// Returns the total number of pages in the PDF document at the given URL
    public static func pageCount(for url: URL) -> Int {
        guard let pdfDoc = PDFDocument(url: url) else { return 0 }
        return pdfDoc.pageCount
    }

    /// Application Support persistent assets directory for PDF notes
    public static func documentAssetsDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Medha", isDirectory: true)
            .appendingPathComponent("InkPDFAssets", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Trims a source PDF by copying only [startPage...endPage] (1-indexed, inclusive) into a trimmed PDF file
    /// saved permanently in Application Support/Medha/InkPDFAssets
    /// Returns the relative filename and the total count of trimmed pages.
    public static func importTrimmedPDF(
        from sourceURL: URL,
        docId: String,
        startPage: Int, // 1-indexed
        endPage: Int    // 1-indexed
    ) throws -> (relativeFilename: String, pageCount: Int) {
        guard let sourceDoc = PDFDocument(url: sourceURL) else {
            throw NSError(domain: "InkPDFImporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open source PDF document."])
        }

        let totalSourcePages = sourceDoc.pageCount
        guard totalSourcePages > 0 else {
            throw NSError(domain: "InkPDFImporter", code: 2, userInfo: [NSLocalizedDescriptionKey: "The selected PDF has no pages."])
        }

        let clampedStart = max(1, min(startPage, totalSourcePages))
        let clampedEnd = max(clampedStart, min(endPage, totalSourcePages))

        let trimmedDoc = PDFDocument()
        var destinationPageIndex = 0

        for sourceIdx in (clampedStart - 1)..<clampedEnd {
            if let page = sourceDoc.page(at: sourceIdx) {
                trimmedDoc.insert(page, at: destinationPageIndex)
                destinationPageIndex += 1
            }
        }

        guard trimmedDoc.pageCount > 0 else {
            throw NSError(domain: "InkPDFImporter", code: 3, userInfo: [NSLocalizedDescriptionKey: "No pages were extracted from the PDF."])
        }

        // Save trimmed document to persistent storage
        let safeName = "pdf-\(docId)-\(UUID().uuidString.prefix(8)).pdf"
        let destURL = documentAssetsDirectory().appendingPathComponent(safeName)
        trimmedDoc.write(to: destURL)

        return (relativeFilename: safeName, pageCount: trimmedDoc.pageCount)
    }

    /// Returns the natural CGSize of a specific page (1-indexed) in points
    public static func pageSize(for url: URL, pageIndex: Int) -> CGSize? {
        guard let document = CGPDFDocument(url as CFURL),
              let page = document.page(at: pageIndex) else { return nil }
        let box = page.getBoxRect(.mediaBox)
        guard box.width > 0 && box.height > 0 else { return nil }
        return box.size
    }

    /// Resolves full filesystem URL for a given pdfPath
    public static func resolvePDFURL(for pathOrFilename: String) -> URL? {
        let trimmed = pathOrFilename.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        // Check if already an absolute path and exists
        let absURL = URL(fileURLWithPath: trimmed)
        if FileManager.default.fileExists(atPath: absURL.path) {
            return absURL
        }

        // Check inside document assets directory
        let assetURL = documentAssetsDirectory().appendingPathComponent(trimmed)
        if FileManager.default.fileExists(atPath: assetURL.path) {
            return assetURL
        }

        return nil
    }

    // MARK: - PDFKit In-Memory Cache
    private static var documentCache = NSCache<NSURL, PDFDocument>()

    public static func cachedPDFDocument(for url: URL) -> PDFDocument? {
        if let cached = documentCache.object(forKey: url as NSURL) {
            return cached
        }
        guard let doc = PDFDocument(url: url) else { return nil }
        documentCache.setObject(doc, forKey: url as NSURL)
        return doc
    }

    /// Renders a specific page of a PDF into a CGContext within the target rect, with optional normalized crop bounds [0...1]
    public static func renderPDFPage(
        from url: URL,
        pageIndex: Int, // 1-indexed
        in context: CGContext,
        targetRect: CGRect,
        cropRect: CGRect? = nil // Normalized unit coordinates (x: 0...1, y: 0...1, w: 0...1, h: 0...1) in top-left space
    ) {
        guard let document = CGPDFDocument(url as CFURL) else { return }
        guard let page = document.page(at: pageIndex) else { return }

        let pageRect = page.getBoxRect(.mediaBox)
        guard pageRect.width > 0 && pageRect.height > 0 else { return }

        context.saveGState()

        // White page background under PDF
        context.setFillColor(NSColor.white.cgColor)
        context.fill(targetRect)

        if let crop = cropRect, crop.width > 0.01, crop.height > 0.01 {
            // Apply clip to the targetRect
            context.clip(to: targetRect)

            // The visible portion corresponds to crop: (x, y, w, h) in unit space [0...1]
            // Scale so that cropped portion fills targetRect
            let scaleX = targetRect.width / (pageRect.width * crop.width)
            let scaleY = targetRect.height / (pageRect.height * crop.height)
            let scale = min(scaleX, scaleY)

            let fullScaledWidth = pageRect.width * scale
            let fullScaledHeight = pageRect.height * scale

            // In top-left space, crop.minX and crop.minY offset the origin
            let offsetX = targetRect.origin.x - (crop.origin.x * fullScaledWidth)
            let offsetY = targetRect.origin.y - (crop.origin.y * fullScaledHeight)

            context.translateBy(x: offsetX, y: offsetY + fullScaledHeight)
            context.scaleBy(x: scale, y: -scale)
            context.drawPDFPage(page)
        } else {
            // Calculate aspect-fit scaling
            let scaleX = targetRect.width / pageRect.width
            let scaleY = targetRect.height / pageRect.height
            let scale = min(scaleX, scaleY)

            let scaledWidth = pageRect.width * scale
            let scaledHeight = pageRect.height * scale
            let offsetX = targetRect.origin.x + (targetRect.width - scaledWidth) * 0.5
            let offsetY = targetRect.origin.y + (targetRect.height - scaledHeight) * 0.5

            context.translateBy(x: offsetX, y: offsetY + scaledHeight)
            context.scaleBy(x: scale, y: -scale)
            context.drawPDFPage(page)
        }

        context.restoreGState()
    }

    /// Converts a point in targetRect back into PDFPage coordinate space (bottom-left origin)
    public static func pdfPagePoint(
        from targetPoint: CGPoint,
        in targetRect: CGRect,
        page: PDFPage,
        cropRect: CGRect? = nil
    ) -> CGPoint {
        let pageBounds = page.bounds(for: .mediaBox)
        guard pageBounds.width > 0, pageBounds.height > 0 else { return .zero }

        if let crop = cropRect, crop.width > 0.01, crop.height > 0.01 {
            let scaleX = targetRect.width / (pageBounds.width * crop.width)
            let scaleY = targetRect.height / (pageBounds.height * crop.height)
            let scale = min(scaleX, scaleY)

            let fullScaledWidth = pageBounds.width * scale
            let fullScaledHeight = pageBounds.height * scale
            let offsetX = targetRect.origin.x - (crop.origin.x * fullScaledWidth)
            let offsetY = targetRect.origin.y - (crop.origin.y * fullScaledHeight)

            let relX = (targetPoint.x - offsetX) / scale
            let topRelY = (targetPoint.y - offsetY) / scale
            let pdfY = pageBounds.height - topRelY
            return CGPoint(x: relX, y: pdfY)
        } else {
            let scaleX = targetRect.width / pageBounds.width
            let scaleY = targetRect.height / pageBounds.height
            let scale = min(scaleX, scaleY)

            let scaledWidth = pageBounds.width * scale
            let scaledHeight = pageBounds.height * scale
            let offsetX = targetRect.origin.x + (targetRect.width - scaledWidth) * 0.5
            let offsetY = targetRect.origin.y + (targetRect.height - scaledHeight) * 0.5

            let relX = (targetPoint.x - offsetX) / scale
            let topRelY = (targetPoint.y - offsetY) / scale
            let pdfY = pageBounds.height - topRelY
            return CGPoint(x: relX, y: pdfY)
        }
    }

    /// Converts a rect in PDFPage coordinate space into targetRect coordinates (top-left origin)
    public static func targetRect(
        from pdfRect: NSRect,
        in targetRect: CGRect,
        page: PDFPage,
        cropRect: CGRect? = nil
    ) -> CGRect {
        let pageBounds = page.bounds(for: .mediaBox)
        guard pageBounds.width > 0, pageBounds.height > 0 else { return .zero }

        if let crop = cropRect, crop.width > 0.01, crop.height > 0.01 {
            let scaleX = targetRect.width / (pageBounds.width * crop.width)
            let scaleY = targetRect.height / (pageBounds.height * crop.height)
            let scale = min(scaleX, scaleY)

            let fullScaledWidth = pageBounds.width * scale
            let fullScaledHeight = pageBounds.height * scale
            let offsetX = targetRect.origin.x - (crop.origin.x * fullScaledWidth)
            let offsetY = targetRect.origin.y - (crop.origin.y * fullScaledHeight)

            let x = offsetX + (pdfRect.minX * scale)
            let topRelY = (pageBounds.height - pdfRect.maxY) * scale
            let y = offsetY + topRelY
            let w = pdfRect.width * scale
            let h = pdfRect.height * scale
            return CGRect(x: x, y: y, width: w, height: h)
        } else {
            let scaleX = targetRect.width / pageBounds.width
            let scaleY = targetRect.height / pageBounds.height
            let scale = min(scaleX, scaleY)

            let scaledWidth = pageBounds.width * scale
            let scaledHeight = pageBounds.height * scale
            let offsetX = targetRect.origin.x + (targetRect.width - scaledWidth) * 0.5
            let offsetY = targetRect.origin.y + (targetRect.height - scaledHeight) * 0.5

            let x = offsetX + (pdfRect.minX * scale)
            let topRelY = (pageBounds.height - pdfRect.maxY) * scale
            let y = offsetY + topRelY
            let w = pdfRect.width * scale
            let h = pdfRect.height * scale
            return CGRect(x: x, y: y, width: w, height: h)
        }
    }
}
