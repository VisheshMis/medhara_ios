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

    /// Renders a specific page of a PDF into a CGContext within the target rect
    public static func renderPDFPage(
        from url: URL,
        pageIndex: Int, // 1-indexed
        in context: CGContext,
        targetRect: CGRect
    ) {
        guard let document = CGPDFDocument(url as CFURL) else { return }
        guard let page = document.page(at: pageIndex) else { return }

        let pageRect = page.getBoxRect(.mediaBox)
        guard pageRect.width > 0 && pageRect.height > 0 else { return }

        context.saveGState()

        // White page background under PDF
        context.setFillColor(NSColor.white.cgColor)
        context.fill(targetRect)

        // Calculate aspect-fit scaling
        let scaleX = targetRect.width / pageRect.width
        let scaleY = targetRect.height / pageRect.height
        let scale = min(scaleX, scaleY)

        let scaledWidth = pageRect.width * scale
        let scaledHeight = pageRect.height * scale
        let offsetX = targetRect.origin.x + (targetRect.width - scaledWidth) * 0.5
        let offsetY = targetRect.origin.y + (targetRect.height - scaledHeight) * 0.5

        // CGPDFPage draws in traditional bottom-left Cartesian coordinates.
        // If our context is flipped (top-left origin), we translate to the bottom of the drawn area
        // and invert Y so the PDF text and images render right-side up.
        context.translateBy(x: offsetX, y: offsetY + scaledHeight)
        context.scaleBy(x: scale, y: -scale)

        context.drawPDFPage(page)
        context.restoreGState()
    }
}
