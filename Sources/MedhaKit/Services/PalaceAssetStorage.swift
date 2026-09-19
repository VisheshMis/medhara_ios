import Foundation

public enum PalaceAssetStorage {
    public static var customStorageDirectory: URL?

    public static func storageDirectory() -> URL {
        if let custom = customStorageDirectory {
            try? FileManager.default.createDirectory(at: custom, withIntermediateDirectories: true)
            return custom
        }

        // Try project folder Assets/PalacePhotos first
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let projectAssets = currentDir.appendingPathComponent("Assets", isDirectory: true)
            .appendingPathComponent("PalacePhotos", isDirectory: true)

        if FileManager.default.isWritableFile(atPath: currentDir.path) {
            do {
                try FileManager.default.createDirectory(at: projectAssets, withIntermediateDirectories: true)
                return projectAssets
            } catch {
                // Fallback to Application Support
            }
        }

        // Production Fallback: ~/Library/Application Support/Medha/PalacePhotos
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let safeDir = appSupport.appendingPathComponent("Medha", isDirectory: true)
            .appendingPathComponent("PalacePhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: safeDir, withIntermediateDirectories: true)
        return safeDir
    }

    /// Copies a selected image from its source location (e.g. Downloads, Desktop)
    /// into the safe local project storage directory to prevent accidental deletion.
    /// Returns the permanent destination file path.
    public static func importPhoto(from sourceURL: URL) throws -> String {
        let dir = storageDirectory()
        let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
        let uniqueName = "photo-\(UUID().uuidString.lowercased()).\(ext)"
        let destinationURL = dir.appendingPathComponent(uniqueName)

        // If file exists at destination, remove it first
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL.path
    }

    /// Resolves a photo path or filename to an existing on-disk file.
    public static func resolvePhotoPath(_ path: String) -> String? {
        if path.hasPrefix("bundled:") {
            return nil
        }
        if FileManager.default.fileExists(atPath: path) {
            return path
        }
        // Check relative to storage directory
        let dir = storageDirectory()
        let inStorage = dir.appendingPathComponent(path).path
        if FileManager.default.fileExists(atPath: inStorage) {
            return inStorage
        }
        // Check by filename in storage directory
        let filename = URL(fileURLWithPath: path).lastPathComponent
        let inStorageByFilename = dir.appendingPathComponent(filename).path
        if FileManager.default.fileExists(atPath: inStorageByFilename) {
            return inStorageByFilename
        }
        // Check Application Support fallback
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let appSupportPhoto = appSupport.appendingPathComponent("Medha", isDirectory: true)
                .appendingPathComponent("PalacePhotos", isDirectory: true)
                .appendingPathComponent(filename).path
            if FileManager.default.fileExists(atPath: appSupportPhoto) {
                return appSupportPhoto
            }
        }
        return nil
    }
}
