import Foundation
import CoreGraphics
import AppKit
import AVFoundation
import PDFKit

public enum CanvasAssetStorage {

    /// Persistent assets directory: Application Support/Medha/CanvasAssets/
    public static func assetsDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Medha", isDirectory: true)
            .appendingPathComponent("CanvasAssets", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // In-memory raster cache to maintain 60 FPS performance without disk re-reads
    private static let thumbnailCache = NSCache<NSString, NSImage>()

    /// Imports a local file by copying into CanvasAssets and generating metadata/thumbnails
    public static func importMedia(
        from sourceURL: URL,
        canvasDocId: String
    ) throws -> (assetKey: String, itemType: CanvasItemType, naturalSize: CGSize, title: String) {
        let ext = sourceURL.pathExtension.lowercased()
        let filename = sourceURL.lastPathComponent
        let uniqueKey = "asset-\(canvasDocId.prefix(8))-\(UUID().uuidString.prefix(8)).\(ext)"
        let destURL = assetsDirectory().appendingPathComponent(uniqueKey)

        if FileManager.default.fileExists(atPath: destURL.path) {
            try? FileManager.default.removeItem(at: destURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destURL)

        // Classify media type and natural size
        let itemType: CanvasItemType
        var naturalSize = CGSize(width: 280, height: 200)

        if ["png", "jpg", "jpeg", "heic", "webp", "gif"].contains(ext) {
            itemType = .mediaImage
            if let image = NSImage(contentsOf: destURL) {
                naturalSize = image.size
                thumbnailCache.setObject(image, forKey: uniqueKey as NSString)
            }
        } else if ["mp4", "mov", "m4v"].contains(ext) {
            itemType = .mediaVideo
            let asset = AVURLAsset(url: destURL)
            if let track = asset.tracks(withMediaType: .video).first {
                naturalSize = track.naturalSize.applying(track.preferredTransform)
                naturalSize = CGSize(width: abs(naturalSize.width), height: abs(naturalSize.height))
            }
            if let poster = generateVideoPoster(for: destURL) {
                thumbnailCache.setObject(poster, forKey: uniqueKey as NSString)
            }
        } else if ["mp3", "m4a", "wav", "aac"].contains(ext) {
            itemType = .mediaAudio
            naturalSize = CGSize(width: 280, height: 76)
        } else if ext == "pdf" {
            itemType = .mediaPDF
            if let pdfDoc = PDFDocument(url: destURL), let page = pdfDoc.page(at: 0) {
                let box = page.bounds(for: .mediaBox)
                naturalSize = box.size
            }
        } else {
            itemType = .mediaImage
        }

        return (assetKey: uniqueKey, itemType: itemType, naturalSize: naturalSize, title: filename)
    }

    /// Imports raw data into CanvasAssets
    public static func importMediaData(
        _ data: Data,
        suggestedExtension: String,
        canvasDocId: String
    ) throws -> (assetKey: String, itemType: CanvasItemType, naturalSize: CGSize) {
        let ext = suggestedExtension.lowercased()
        let uniqueKey = "asset-\(canvasDocId.prefix(8))-\(UUID().uuidString.prefix(8)).\(ext)"
        let destURL = assetsDirectory().appendingPathComponent(uniqueKey)

        try data.write(to: destURL)

        let itemType: CanvasItemType = .mediaImage
        var size = CGSize(width: 280, height: 200)

        if let image = NSImage(data: data) {
            size = image.size
            thumbnailCache.setObject(image, forKey: uniqueKey as NSString)
        }

        return (assetKey: uniqueKey, itemType: itemType, naturalSize: size)
    }

    /// Resolves full filesystem URL for a given assetKey
    public static func resolveURL(for assetKey: String) -> URL? {
        let destURL = assetsDirectory().appendingPathComponent(assetKey)
        return FileManager.default.fileExists(atPath: destURL.path) ? destURL : nil
    }

    /// Fetches or generates cached thumbnail
    public static func thumbnail(for assetKey: String) -> NSImage? {
        if let cached = thumbnailCache.object(forKey: assetKey as NSString) {
            return cached
        }
        guard let url = resolveURL(for: assetKey) else { return nil }

        let ext = url.pathExtension.lowercased()
        if ["png", "jpg", "jpeg", "heic", "webp", "gif"].contains(ext) {
            if let image = NSImage(contentsOf: url) {
                thumbnailCache.setObject(image, forKey: assetKey as NSString)
                return image
            }
        } else if ["mp4", "mov", "m4v"].contains(ext) {
            if let poster = generateVideoPoster(for: url) {
                thumbnailCache.setObject(poster, forKey: assetKey as NSString)
                return poster
            }
        }
        return nil
    }

    /// Generates video poster frame at 0.5s via AVAssetImageGenerator
    public static func generateVideoPoster(for url: URL) -> NSImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0.5, preferredTimescale: 600)
        if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }
        return nil
    }

    /// Extracts duration string (e.g. "03:42") for audio/video assets
    public static func durationString(for assetKey: String) -> String {
        guard let url = resolveURL(for: assetKey) else { return "00:00" }
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        if duration.isNaN || duration <= 0 { return "00:00" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Generates synthetic waveform peak heights [0...1] for audio bar visualizer
    public static func generateWaveformPeaks(for assetKey: String, sampleCount: Int = 32) -> [Double] {
        // Hash assetKey for stable deterministic waveform shape
        var seed = UInt64(abs(assetKey.hashValue))
        var peaks: [Double] = []
        for _ in 0..<sampleCount {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let val = Double((seed >> 32) & 0xFFFF) / Double(0xFFFF)
            let shaped = 0.2 + 0.8 * sin(val * .pi)
            peaks.append(max(0.15, min(1.0, shaped)))
        }
        return peaks
    }
}
