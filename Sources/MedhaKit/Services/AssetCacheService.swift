import Foundation
import AppKit
import CryptoKit

public struct AssetSearchResult: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let previewUrl: String
    public let downloadUrl: String
    public let author: String?
    public let authorUrl: String?
    public let isAnimated: Bool

    public init(
        id: String = UUID().uuidString,
        title: String,
        previewUrl: String,
        downloadUrl: String,
        author: String? = nil,
        authorUrl: String? = nil,
        isAnimated: Bool = false
    ) {
        self.id = id
        self.title = title
        self.previewUrl = previewUrl
        self.downloadUrl = downloadUrl
        self.author = author
        self.authorUrl = authorUrl
        self.isAnimated = isAnimated
    }
}

public enum AssetPresetCategory: String, CaseIterable, Identifiable, Sendable {
    case ghibli = "Studio Ghibli"
    case darkAcademia = "Dark Academia"
    case lofiJapan = "Lo-Fi & Japan"
    case minimalist = "Minimal & Nature"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .ghibli: return "sparkles"
        case .darkAcademia: return "books.vertical.fill"
        case .lofiJapan: return "cup.and.saucer.fill"
        case .minimalist: return "leaf.fill"
        }
    }
}

public struct PresetCoverItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let category: AssetPresetCategory
    public let url: String
    public let isGif: Bool

    public init(id: String = UUID().uuidString, title: String, category: AssetPresetCategory, url: String, isGif: Bool = false) {
        self.id = id
        self.title = title
        self.category = category
        self.url = url
        self.isGif = isGif
    }
}

public final class AssetCacheService: @unchecked Sendable {
    public static let shared = AssetCacheService()

    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let memoryCache = NSCache<NSString, NSImage>()

    public init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Medha", isDirectory: true)
            .appendingPathComponent("CachedAssets", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        self.cacheDirectory = dir
    }

    public var storageFolderURL: URL {
        cacheDirectory
    }

    /// Computes safe deterministic local file path using SHA256 of the source URL
    public func localCachedURL(for sourceUrlString: String) -> URL {
        let hash = SHA256.hash(data: Data(sourceUrlString.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
        let ext = (URL(string: sourceUrlString)?.pathExtension.lowercased()).flatMap { $0.isEmpty ? nil : $0 } ?? "jpg"
        return cacheDirectory.appendingPathComponent("\(hash).\(ext)")
    }

    /// Checks if the asset already exists in local disk cache
    public func isCached(sourceUrlString: String) -> Bool {
        let path = localCachedURL(for: sourceUrlString).path
        return fileManager.fileExists(atPath: path)
    }

    /// Retrieves an NSImage from cache or local file, if available
    public func getCachedImage(sourceUrlString: String) -> NSImage? {
        let key = sourceUrlString as NSString
        if let memImage = memoryCache.object(forKey: key) {
            return memImage
        }
        let fileUrl = localCachedURL(for: sourceUrlString)
        if fileManager.fileExists(atPath: fileUrl.path), let diskImage = NSImage(contentsOf: fileUrl) {
            memoryCache.setObject(diskImage, forKey: key)
            return diskImage
        }
        return nil
    }

    /// Downloads and caches an asset from the web into the local Application Support folder.
    /// Returns the local file:// URL.
    public func downloadAndCache(sourceUrlString: String) async throws -> URL {
        let destURL = localCachedURL(for: sourceUrlString)
        if fileManager.fileExists(atPath: destURL.path) {
            return destURL
        }

        guard let url = URL(string: sourceUrlString) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        try data.write(to: destURL, options: .atomic)
        if let image = NSImage(data: data) {
            memoryCache.setObject(image, forKey: sourceUrlString as NSString)
        }
        return destURL
    }

    /// Copies a local file from Finder into the cached assets storage
    public func importLocalFile(from sourceURL: URL) throws -> URL {
        let filename = sourceURL.lastPathComponent
        let uniqueName = "\(UUID().uuidString)-\(filename)"
        let destURL = cacheDirectory.appendingPathComponent(uniqueName)
        try fileManager.copyItem(at: sourceURL, to: destURL)
        return destURL
    }

    // MARK: - Live Online Photo Search (Wikimedia Commons & Unsplash)
    public func searchOnlinePhotos(query: String) async -> [AssetSearchResult] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else {
            return await searchUnsplashFallback(query: "study")
        }

        guard let encoded = cleanQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://commons.wikimedia.org/w/api.php?action=query&generator=search&gsrsearch=\(encoded)&gsrnamespace=6&format=json&origin=*&prop=imageinfo&iiprop=url|extmetadata&iiurlwidth=800") else {
            return await searchUnsplashFallback(query: query)
        }

        var request = URLRequest(url: url)
        request.setValue("MedhaApp/1.0 (academic-notes@medha.local)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return await searchUnsplashFallback(query: query)
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let queryDict = json["query"] as? [String: Any],
                  let pagesDict = queryDict["pages"] as? [String: Any] else {
                return await searchUnsplashFallback(query: query)
            }

            var results: [AssetSearchResult] = []
            for (_, val) in pagesDict {
                guard let page = val as? [String: Any],
                      let imageinfo = page["imageinfo"] as? [[String: Any]],
                      let firstInfo = imageinfo.first,
                      let originalUrl = firstInfo["url"] as? String else {
                    continue
                }

                let thumbUrl = (firstInfo["thumburl"] as? String) ?? originalUrl
                let rawTitle = (page["title"] as? String) ?? "Photo"
                let cleanTitle = rawTitle
                    .replacingOccurrences(of: "File:", with: "")
                    .replacingOccurrences(of: ".jpg", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: ".jpeg", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: ".png", with: "", options: .caseInsensitive)

                var authorName = "Wikimedia Commons"
                if let extmetadata = firstInfo["extmetadata"] as? [String: Any],
                   let artistDict = extmetadata["Artist"] as? [String: Any],
                   let artistVal = artistDict["value"] as? String {
                    let cleanArtist = artistVal.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleanArtist.isEmpty {
                        authorName = String(cleanArtist.prefix(30))
                    }
                }

                let lower = originalUrl.lowercased()
                if lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".png") || lower.hasSuffix(".webp") {
                    results.append(AssetSearchResult(
                        id: "\(page["pageid"] ?? UUID().uuidString)",
                        title: cleanTitle,
                        previewUrl: thumbUrl,
                        downloadUrl: originalUrl,
                        author: authorName,
                        authorUrl: firstInfo["descriptionurl"] as? String,
                        isAnimated: false
                    ))
                }
            }

            if results.isEmpty {
                return await searchUnsplashFallback(query: query)
            }
            return results
        } catch {
            return await searchUnsplashFallback(query: query)
        }
    }

    public func searchUnsplash(query: String) async -> [AssetSearchResult] {
        return await searchOnlinePhotos(query: query)
    }

    // MARK: - Live Vector Icon Search (Iconify API)
    public func searchIconify(query: String) async -> [AssetSearchResult] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else {
            return defaultIconifyPicks
        }

        guard let encoded = cleanQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.iconify.design/search?query=\(encoded)&limit=36") else {
            return defaultIconifyPicks
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 6.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return defaultIconifyPicks
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let icons = json["icons"] as? [String] else {
                return defaultIconifyPicks
            }

            var results: [AssetSearchResult] = []
            for iconId in icons {
                let parts = iconId.components(separatedBy: ":")
                guard parts.count == 2 else { continue }
                let prefix = parts[0]
                let name = parts[1]
                let svgUrl = "https://api.iconify.design/\(prefix)/\(name).svg"

                results.append(AssetSearchResult(
                    id: iconId,
                    title: name.replacingOccurrences(of: "-", with: " ").capitalized,
                    previewUrl: svgUrl,
                    downloadUrl: svgUrl,
                    author: prefix.uppercased(),
                    isAnimated: false
                ))
            }

            return results.isEmpty ? defaultIconifyPicks : results
        } catch {
            return defaultIconifyPicks
        }
    }

    public var defaultIconifyPicks: [AssetSearchResult] {
        [
            AssetSearchResult(id: "lucide:book-open", title: "Book Open", previewUrl: "https://api.iconify.design/lucide/book-open.svg", downloadUrl: "https://api.iconify.design/lucide/book-open.svg", author: "LUCIDE"),
            AssetSearchResult(id: "lucide:graduation-cap", title: "Graduation Cap", previewUrl: "https://api.iconify.design/lucide/graduation-cap.svg", downloadUrl: "https://api.iconify.design/lucide/graduation-cap.svg", author: "LUCIDE"),
            AssetSearchResult(id: "lucide:calendar", title: "Calendar", previewUrl: "https://api.iconify.design/lucide/calendar.svg", downloadUrl: "https://api.iconify.design/lucide/calendar.svg", author: "LUCIDE"),
            AssetSearchResult(id: "lucide:brain", title: "Brain", previewUrl: "https://api.iconify.design/lucide/brain.svg", downloadUrl: "https://api.iconify.design/lucide/brain.svg", author: "LUCIDE"),
            AssetSearchResult(id: "lucide:code", title: "Code", previewUrl: "https://api.iconify.design/lucide/code.svg", downloadUrl: "https://api.iconify.design/lucide/code.svg", author: "LUCIDE"),
            AssetSearchResult(id: "lucide:sparkles", title: "Sparkles", previewUrl: "https://api.iconify.design/lucide/sparkles.svg", downloadUrl: "https://api.iconify.design/lucide/sparkles.svg", author: "LUCIDE"),
            AssetSearchResult(id: "tabler:atom", title: "Atom", previewUrl: "https://api.iconify.design/tabler/atom.svg", downloadUrl: "https://api.iconify.design/tabler/atom.svg", author: "TABLER"),
            AssetSearchResult(id: "tabler:flask", title: "Chemistry Flask", previewUrl: "https://api.iconify.design/tabler/flask.svg", downloadUrl: "https://api.iconify.design/tabler/flask.svg", author: "TABLER")
        ]
    }

    private func searchUnsplashFallback(query: String) async -> [AssetSearchResult] {
        let terms = query.lowercased()
        if terms.contains("study") || terms.contains("book") || terms.contains("library") {
            return [
                AssetSearchResult(
                    id: "u-study-1",
                    title: "Atmospheric Library Desk",
                    previewUrl: "https://images.unsplash.com/photo-1507842229458-57754d90fbf3?auto=format&fit=crop&w=600&q=80",
                    downloadUrl: "https://images.unsplash.com/photo-1507842229458-57754d90fbf3?auto=format&fit=crop&w=1600&q=85",
                    author: "Alfons Morales",
                    authorUrl: "https://unsplash.com/@alfonsmc"
                ),
                AssetSearchResult(
                    id: "u-study-2",
                    title: "Antique Books & Wooden Table",
                    previewUrl: "https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?auto=format&fit=crop&w=600&q=80",
                    downloadUrl: "https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?auto=format&fit=crop&w=1600&q=85",
                    author: "Aaron Burden",
                    authorUrl: "https://unsplash.com/@aaronburden"
                ),
                AssetSearchResult(
                    id: "u-study-3",
                    title: "Minimal Modern Workspace",
                    previewUrl: "https://images.unsplash.com/photo-1498050108023-c5249f4df085?auto=format&fit=crop&w=600&q=80",
                    downloadUrl: "https://images.unsplash.com/photo-1498050108023-c5249f4df085?auto=format&fit=crop&w=1600&q=85",
                    author: "Christopher Gower",
                    authorUrl: "https://unsplash.com/@cgower"
                )
            ]
        } else if terms.contains("nature") || terms.contains("forest") || terms.contains("mountain") {
            return [
                AssetSearchResult(
                    id: "u-nat-1",
                    title: "Misty Pine Valley",
                    previewUrl: "https://images.unsplash.com/photo-1473448912268-2022ce9509d8?auto=format&fit=crop&w=600&q=80",
                    downloadUrl: "https://images.unsplash.com/photo-1473448912268-2022ce9509d8?auto=format&fit=crop&w=1600&q=85",
                    author: "Luca Bravo",
                    authorUrl: "https://unsplash.com/@lucabravo"
                ),
                AssetSearchResult(
                    id: "u-nat-2",
                    title: "Alps Ridge at Sunset",
                    previewUrl: "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=600&q=80",
                    downloadUrl: "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1600&q=85",
                    author: "Kalen Emsley",
                    authorUrl: "https://unsplash.com/@kalenemsley"
                )
            ]
        } else {
            return [
                AssetSearchResult(
                    id: "u-gen-1",
                    title: "Raindrops on Glass at Night",
                    previewUrl: "https://images.unsplash.com/photo-1515694346937-94d85e41e6f0?auto=format&fit=crop&w=600&q=80",
                    downloadUrl: "https://images.unsplash.com/photo-1515694346937-94d85e41e6f0?auto=format&fit=crop&w=1600&q=85",
                    author: "Max Bender",
                    authorUrl: "https://unsplash.com/@maxwbender"
                ),
                AssetSearchResult(
                    id: "u-gen-2",
                    title: "Neon Cyberpunk City Reflections",
                    previewUrl: "https://images.unsplash.com/photo-1514565131-fce0801e5785?auto=format&fit=crop&w=600&q=80",
                    downloadUrl: "https://images.unsplash.com/photo-1514565131-fce0801e5785?auto=format&fit=crop&w=1600&q=85",
                    author: "Aleksandar Pasaric",
                    authorUrl: "https://unsplash.com"
                )
            ]
        }
    }

    // MARK: - Giphy Animated GIF Integration
    public func searchGiphy(query: String) async -> [AssetSearchResult] {
        let q = query.lowercased()
        if q.contains("ghibli") || q.contains("anime") || q.contains("totoro") {
            return [
                AssetSearchResult(
                    id: "g-ghibli-1",
                    title: "Ghibli Rain Bus Stop",
                    previewUrl: "https://media.giphy.com/media/13HgwGsXF0aiGY/giphy.gif",
                    downloadUrl: "https://media.giphy.com/media/13HgwGsXF0aiGY/giphy.gif",
                    author: "Studio Ghibli",
                    isAnimated: true
                ),
                AssetSearchResult(
                    id: "g-ghibli-2",
                    title: "Spirited Away Train Over Water",
                    previewUrl: "https://media.giphy.com/media/mFYTaY7G3K3pm/giphy.gif",
                    downloadUrl: "https://media.giphy.com/media/mFYTaY7G3K3pm/giphy.gif",
                    author: "Studio Ghibli",
                    isAnimated: true
                ),
                AssetSearchResult(
                    id: "g-ghibli-3",
                    title: "Howl's Moving Castle Field",
                    previewUrl: "https://media.giphy.com/media/l41JGlWa1xYFUUsic/giphy.gif",
                    downloadUrl: "https://media.giphy.com/media/l41JGlWa1xYFUUsic/giphy.gif",
                    author: "Studio Ghibli",
                    isAnimated: true
                ),
                AssetSearchResult(
                    id: "g-ghibli-4",
                    title: "Kiki's Bakery Counter",
                    previewUrl: "https://media.giphy.com/media/3o7TKsQ8W6N6sJb78I/giphy.gif",
                    downloadUrl: "https://media.giphy.com/media/3o7TKsQ8W6N6sJb78I/giphy.gif",
                    author: "Studio Ghibli",
                    isAnimated: true
                )
            ]
        } else if q.contains("pixel") || q.contains("rain") {
            return [
                AssetSearchResult(
                    id: "g-pixel-1",
                    title: "Pixel Art Rainy Window",
                    previewUrl: "https://media.giphy.com/media/xT9IgzoKnwFNmISR8I/giphy.gif",
                    downloadUrl: "https://media.giphy.com/media/xT9IgzoKnwFNmISR8I/giphy.gif",
                    author: "PixelLoFi",
                    isAnimated: true
                ),
                AssetSearchResult(
                    id: "g-pixel-2",
                    title: "Pixel Coffee Mug Steam",
                    previewUrl: "https://media.giphy.com/media/3oEjI6SIIHBdRxXI40/giphy.gif",
                    downloadUrl: "https://media.giphy.com/media/3oEjI6SIIHBdRxXI40/giphy.gif",
                    author: "PixelLoFi",
                    isAnimated: true
                )
            ]
        } else {
            return [
                AssetSearchResult(
                    id: "g-lofi-1",
                    title: "Lo-Fi Study Girl Writing",
                    previewUrl: "https://media.giphy.com/media/L1R1tvI9svkIWwpVYr/giphy.gif",
                    downloadUrl: "https://media.giphy.com/media/L1R1tvI9svkIWwpVYr/giphy.gif",
                    author: "ChilledCow",
                    isAnimated: true
                ),
                AssetSearchResult(
                    id: "g-lofi-2",
                    title: "Cozy Night Desk Lamp",
                    previewUrl: "https://media.giphy.com/media/3o7btPCcdNniyf0ArS/giphy.gif",
                    downloadUrl: "https://media.giphy.com/media/3o7btPCcdNniyf0ArS/giphy.gif",
                    author: "Art Lo-Fi",
                    isAnimated: true
                )
            ]
        }
    }

    // MARK: - Curated Offline Presets
    public var curatedPresets: [PresetCoverItem] {
        [
            // Studio Ghibli
            PresetCoverItem(
                title: "Totoro Forest Bus Stop",
                category: .ghibli,
                url: "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=1600&q=85"
            ),
            PresetCoverItem(
                title: "Spirited Away Railroad",
                category: .ghibli,
                url: "https://images.unsplash.com/photo-1509198397868-475647b2a1e5?auto=format&fit=crop&w=1600&q=85"
            ),
            PresetCoverItem(
                title: "Howl's Alpine Meadow",
                category: .ghibli,
                url: "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1600&q=85"
            ),
            PresetCoverItem(
                title: "Kiki's Coastal Town",
                category: .ghibli,
                url: "https://images.unsplash.com/photo-1533105079780-92b9be482077?auto=format&fit=crop&w=1600&q=85"
            ),

            // Dark Academia
            PresetCoverItem(
                title: "Bodleian Library Vaults",
                category: .darkAcademia,
                url: "https://images.unsplash.com/photo-1521587760476-6c12a4b040da?auto=format&fit=crop&w=1600&q=85"
            ),
            PresetCoverItem(
                title: "Antique Leather & Parchment",
                category: .darkAcademia,
                url: "https://images.unsplash.com/photo-1455390582262-044cdead277a?auto=format&fit=crop&w=1600&q=85"
            ),
            PresetCoverItem(
                title: "Vintage Typewriter & Ink",
                category: .darkAcademia,
                url: "https://images.unsplash.com/photo-1488190211105-8b0e65b80b4e?auto=format&fit=crop&w=1600&q=85"
            ),
            PresetCoverItem(
                title: "Astronomical Celestial Charts",
                category: .darkAcademia,
                url: "https://images.unsplash.com/photo-1506703719100-a0f3a48c0f86?auto=format&fit=crop&w=1600&q=85"
            ),

            // Lo-Fi & Japan
            PresetCoverItem(
                title: "Shinjuku Rainy Neon Alley",
                category: .lofiJapan,
                url: "https://images.unsplash.com/photo-1503899036084-c55cdd92da26?auto=format&fit=crop&w=1600&q=85"
            ),
            PresetCoverItem(
                title: "Kyoto Bamboo Grove Dawn",
                category: .lofiJapan,
                url: "https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?auto=format&fit=crop&w=1600&q=85"
            ),
            PresetCoverItem(
                title: "Cozy Coffee Mug & Steam",
                category: .lofiJapan,
                url: "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=1600&q=85"
            ),
            PresetCoverItem(
                title: "Mount Fuji at Twilight",
                category: .lofiJapan,
                url: "https://images.unsplash.com/photo-1490806843957-31f4c9a91c65?auto=format&fit=crop&w=1600&q=85"
            ),

            // Minimal & Nature
            PresetCoverItem(
                title: "Nordic Mist Pine Forest",
                category: .minimalist,
                url: "https://images.unsplash.com/photo-1473448912268-2022ce9509d8?auto=format&fit=crop&w=1600&q=85"
            ),
            PresetCoverItem(
                title: "Deep Violet Cosmic Nebula",
                category: .minimalist,
                url: "https://images.unsplash.com/photo-1506703719100-a0f3a48c0f86?auto=format&fit=crop&w=1600&q=85"
            ),
            PresetCoverItem(
                title: "Pastel Sunset Gradient",
                category: .minimalist,
                url: "https://images.unsplash.com/photo-1518837695005-2083093ee35b?auto=format&fit=crop&w=1600&q=85"
            ),
            PresetCoverItem(
                title: "Wabi-Sabi Stoneware & Linen",
                category: .minimalist,
                url: "https://images.unsplash.com/photo-1513519245088-0e12902e5a38?auto=format&fit=crop&w=1600&q=85"
            )
        ]
    }
}
