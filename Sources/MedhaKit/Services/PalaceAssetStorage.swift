import Foundation

public enum PalaceAssetStorage {
    public static var customStorageDirectory: URL?

    public static func storageDirectory() -> URL {
        if let custom = customStorageDirectory {
            try? FileManager.default.createDirectory(at: custom, withIntermediateDirectories: true)
            return custom
        }

        // Primary Persistent Storage: ~/Library/Application Support/Medha/PalacePhotos
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let safeDir = appSupport.appendingPathComponent("Medha", isDirectory: true)
            .appendingPathComponent("PalacePhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: safeDir, withIntermediateDirectories: true)
        
        // Ensure bundled stock photos are copied on first access
        ensureBundledPhotosAvailable(in: safeDir)
        
        return safeDir
    }

    /// Automatically syncs stock classical architecture photos to Application Support
    /// so newly seeded palaces or default scenes have concrete images on disk.
    public static func ensureBundledPhotosAvailable(in targetDir: URL? = nil) {
        let dest = targetDir ?? {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("Medha", isDirectory: true)
                .appendingPathComponent("PalacePhotos", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }()

        let stockFilenames = [
            "photo-alexandria-colonnade.jpg",
            "photo-alexandria-courtyard.jpg",
            "photo-alexandria-rotunda.jpg",
            "photo-villa-salon.jpg",
            "photo-villa-terrace.jpg"
        ]

        for filename in stockFilenames {
            let destFile = dest.appendingPathComponent(filename)
            if !FileManager.default.fileExists(atPath: destFile.path) {
                // Find source
                if let source = findSourceStockPhoto(filename) {
                    try? FileManager.default.copyItem(at: source, to: destFile)
                }
            }
        }
    }

    private static func findSourceStockPhoto(_ filename: String) -> URL? {
        // 1. Bundle PalacePhotos folder
        if let resURL = Bundle.main.resourceURL {
            let inBundle = resURL.appendingPathComponent("PalacePhotos", isDirectory: true).appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: inBundle.path) {
                return inBundle
            }
            let atRoot = resURL.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: atRoot.path) {
                return atRoot
            }
        }

        // 2. Project Assets/PalacePhotos
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let inProject = currentDir.appendingPathComponent("Assets", isDirectory: true)
            .appendingPathComponent("PalacePhotos", isDirectory: true)
            .appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: inProject.path) {
            return inProject
        }

        // 3. Known absolute dev path
        let devURL = URL(fileURLWithPath: "/Users/visheshmishra/Downloads/medharara/Assets/PalacePhotos/\(filename)")
        if FileManager.default.fileExists(atPath: devURL.path) {
            return devURL
        }

        return nil
    }

    /// Copies a selected image from its source location (e.g. Downloads, Desktop, Sandbox containers)
    /// into the safe local project storage directory to prevent accidental deletion or sandbox loss.
    /// Returns the permanent destination file path.
    public static func importPhoto(from sourceURL: URL) throws -> String {
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let dir = storageDirectory()
        let ext = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension.lowercased()
        let uniqueName = "photo-\(UUID().uuidString.lowercased()).\(ext)"
        let destinationURL = dir.appendingPathComponent(uniqueName)

        // If file exists at destination, remove it first
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }

        // Read raw data directly while security-scoped access is active, then write atomically
        let data = try Data(contentsOf: sourceURL)
        try data.write(to: destinationURL, options: .atomic)
        return destinationURL.path
    }

    /// Resolves a photo path or filename to an existing on-disk file.
    public static func resolvePhotoPath(_ path: String) -> String? {
        let clean = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }

        // Map bundled aliases to concrete photo files
        var lookupName = clean
        if clean == "bundled:athenaeum_blueprint" || clean == "bundled:default" {
            lookupName = "photo-alexandria-rotunda.jpg"
        } else if clean == "bundled:athenaeum_gallery" {
            lookupName = "photo-alexandria-colonnade.jpg"
        } else if clean.hasPrefix("bundled:") {
            lookupName = String(clean.dropFirst("bundled:".count))
            if !lookupName.contains(".") {
                lookupName += ".jpg"
            }
        }

        // 1. Direct path on disk (if absolute and exists)
        if FileManager.default.fileExists(atPath: lookupName) {
            return lookupName
        }

        let filename = URL(fileURLWithPath: lookupName).lastPathComponent

        // 2. Check storage directory (~/Library/Application Support/Medha/PalacePhotos)
        let dir = storageDirectory()
        let inStorage = dir.appendingPathComponent(filename).path
        if FileManager.default.fileExists(atPath: inStorage) {
            return inStorage
        }

        // 3. Check App Bundle Resources
        if let bundlePhoto = Bundle.main.url(forResource: filename, withExtension: nil)?.path,
           FileManager.default.fileExists(atPath: bundlePhoto) {
            return bundlePhoto
        }
        if let resURL = Bundle.main.resourceURL {
            let bundlePalacePhotos = resURL.appendingPathComponent("PalacePhotos").appendingPathComponent(filename).path
            if FileManager.default.fileExists(atPath: bundlePalacePhotos) {
                return bundlePalacePhotos
            }
        }

        // 4. Check Project Assets/PalacePhotos (development & test runners)
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let projectAssets = currentDir.appendingPathComponent("Assets", isDirectory: true)
            .appendingPathComponent("PalacePhotos", isDirectory: true)
            .appendingPathComponent(filename).path
        if FileManager.default.fileExists(atPath: projectAssets) {
            return projectAssets
        }

        // 5. Check hardcoded dev fallback
        let devFallback = "/Users/visheshmishra/Downloads/medharara/Assets/PalacePhotos/\(filename)"
        if FileManager.default.fileExists(atPath: devFallback) {
            return devFallback
        }

        return nil
    }
}
