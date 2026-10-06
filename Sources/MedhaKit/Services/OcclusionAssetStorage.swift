import Foundation
import AppKit

public enum OcclusionAssetStorage {
    public static var customStorageDirectory: URL?

    public static func storageDirectory() -> URL {
        if let custom = customStorageDirectory {
            try? FileManager.default.createDirectory(at: custom, withIntermediateDirectories: true)
            return custom
        }

        // Primary Persistent Storage: ~/Library/Application Support/Medha/OcclusionImages
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let safeDir = appSupport.appendingPathComponent("Medha", isDirectory: true)
            .appendingPathComponent("OcclusionImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: safeDir, withIntermediateDirectories: true)
        return safeDir
    }

    /// Saves an image (from NSImage or raw data) to disk and returns its filename
    @discardableResult
    public static func saveImage(_ image: NSImage, filename: String? = nil) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        let name = filename ?? "occlusion-\(UUID().uuidString.lowercased()).png"
        let dest = storageDirectory().appendingPathComponent(name)
        do {
            try pngData.write(to: dest)
            return name
        } catch {
            print("Error saving occlusion image: \(error)")
            return nil
        }
    }

    /// Saves raw image data to disk and returns its filename
    @discardableResult
    public static func saveImageData(_ data: Data, fileExtension: String = "png") -> String? {
        let name = "occlusion-\(UUID().uuidString.lowercased()).\(fileExtension)"
        let dest = storageDirectory().appendingPathComponent(name)
        do {
            try data.write(to: dest)
            return name
        } catch {
            print("Error saving occlusion image data: \(error)")
            return nil
        }
    }

    /// Resolves full URL for an image filename
    public static func resolveImageURL(for filename: String) -> URL? {
        // If it's already an absolute file URL or path
        if filename.hasPrefix("/") {
            let url = URL(fileURLWithPath: filename)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        // Look in OcclusionImages directory
        let inStorage = storageDirectory().appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: inStorage.path) {
            return inStorage
        }

        // Check temp directory
        let inTemp = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: inTemp.path) {
            return inTemp
        }

        return nil
    }

    /// Loads NSImage for given filename
    public static func loadImage(for filename: String) -> NSImage? {
        guard let url = resolveImageURL(for: filename) else { return nil }
        return NSImage(contentsOf: url)
    }
}
