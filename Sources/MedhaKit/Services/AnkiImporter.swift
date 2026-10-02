import Foundation
import GRDB
import UniformTypeIdentifiers
import AppKit

public struct AnkiImportResult: Sendable {
    public let deckNames: [String]
    public let importedCardCount: Int
    public let createdDeckCount: Int
    public let parsedFromModern: Bool
    public let details: String
}

public enum AnkiImportError: LocalizedError {
    case fileNotFound
    case unzipFailed(String)
    case databaseNotFound
    case decompressorMissing(String)
    case invalidDatabase(String)
    case noCardsFound
    case compatibilityNotice(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "The selected Anki package file could not be found."
        case .unzipFailed(let msg):
            return "Failed to extract Anki package (.apkg): \(msg)"
        case .databaseNotFound:
            return "No valid collection database (collection.anki21b, collection.anki21, or collection.anki2) found inside the package."
        case .decompressorMissing(let msg):
            return "Zstandard decompression required: \(msg)"
        case .invalidDatabase(let msg):
            return "Failed to read Anki database: \(msg)"
        case .noCardsFound:
            return "No flashcards found to import from this Anki package."
        case .compatibilityNotice(let msg):
            return msg
        }
    }
}

public final class AnkiImporter: Sendable {
    public static let shared = AnkiImporter()

    private init() {}

    /// Strips HTML tags and converts common formatting into clean readable text
    public static func stripHTML(_ raw: String) -> String {
        var text = raw
        // Newline replacements
        text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</div>", with: "\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "</p>", with: "\n\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "</li>", with: "\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "<li>", with: "• ", options: .caseInsensitive)

        // Strip sounds and media references [sound:...]
        text = text.replacingOccurrences(of: "\\[sound:[^\\]]+\\]", with: "", options: .regularExpression)

        // Strip any remaining HTML tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // Decode common HTML entities
        text = text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")

        // Collapse multiple blank lines
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Resolves Anki cloze deletion syntax like {{c1::answer}} or {{c1::answer::hint}}
    public static func resolveCloze(text: String, clozeIndex: Int = 1) -> (front: String, back: String)? {
        let pattern = "\\{\\{c(\\d+)::([^:}]+?)(?:::([^}]+?))?\\}\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        guard !matches.isEmpty else { return nil }

        var front = text
        var back = text

        for match in matches.reversed() {
            let cIndexStr = nsString.substring(with: match.range(at: 1))
            let answer = nsString.substring(with: match.range(at: 2))
            let hint: String? = match.range(at: 3).location != NSNotFound ? nsString.substring(with: match.range(at: 3)) : nil

            let thisIndex = Int(cIndexStr) ?? 1
            if thisIndex == clozeIndex {
                let placeholder = hint != nil ? "[\(hint!)]" : "[...]"
                front = (front as NSString).replacingCharacters(in: match.range, with: placeholder)
            } else {
                front = (front as NSString).replacingCharacters(in: match.range, with: answer)
            }
            back = (back as NSString).replacingCharacters(in: match.range, with: "**\(answer)**")
        }
        return (front, back)
    }

    /// Checks if a file starts with standard SQLite 3 header ("SQLite format 3\0")
    public static func isSQLiteDatabase(at url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        let headerData = handle.readData(ofLength: 16)
        guard headerData.count >= 16 else { return false }
        let expected = "SQLite format 3\0".data(using: .utf8)!
        return headerData == expected
    }

    /// Locates an available Zstandard decompressor binary
    public static func findDecompressor() -> (path: String, isUnzstdTool: Bool)? {
        let fm = FileManager.default

        // 1. App Bundle Contents/Resources/unzstd
        if let resURL = Bundle.main.resourceURL {
            let p = resURL.appendingPathComponent("unzstd").path
            if fm.isExecutableFile(atPath: p) { return (p, true) }
        }
        if let exeURL = Bundle.main.executableURL {
            let altP = exeURL.deletingLastPathComponent().appendingPathComponent("../Resources/unzstd").standardized.path
            if fm.isExecutableFile(atPath: altP) { return (altP, true) }
        }

        // 2. Development path Resources/bin/unzstd
        let devP = URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent("Resources/bin/unzstd").path
        if fm.isExecutableFile(atPath: devP) { return (devP, true) }

        // 3. Known system & brew paths
        let candidates = [
            "/opt/homebrew/bin/zstd",
            "/usr/local/bin/zstd",
            "/opt/anaconda3/bin/zstd",
            "/usr/bin/zstd"
        ]
        for c in candidates {
            if fm.isExecutableFile(atPath: c) { return (c, false) }
        }

        // 4. Shell `which zstd`
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = ["zstd"]
        let pipe = Pipe()
        which.standardOutput = pipe
        try? which.run()
        which.waitUntilExit()
        if which.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty, fm.isExecutableFile(atPath: output) {
                return (output, false)
            }
        }

        return nil
    }

    /// Decompresses a .zst or .anki21b file into an uncompressed SQLite file
    public static func decompressZstd(inputURL: URL, outputURL: URL) throws {
        guard let decompressor = findDecompressor() else {
            throw AnkiImportError.decompressorMissing(
                "Modern Anki packages (.anki21b) use Zstandard compression. Neither the bundled decompressor nor system zstd was detected."
            )
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: decompressor.path)
        if decompressor.isUnzstdTool {
            process.arguments = [inputURL.path, outputURL.path]
        } else {
            process.arguments = ["-d", "-q", "-f", inputURL.path, "-o", outputURL.path]
        }

        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMsg = String(data: errorData, encoding: .utf8) ?? "Exit code \(process.terminationStatus)"
                throw AnkiImportError.invalidDatabase("Failed to decompress collection.anki21b: \(errorMsg)")
            }
        } catch {
            throw AnkiImportError.invalidDatabase("Decompression execution failed: \(error.localizedDescription)")
        }

        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw AnkiImportError.invalidDatabase("Decompressed database file was not created.")
        }
    }

    /// Imports cards and decks from an Anki .apkg file or SQLite collection file into BlockStore
    @MainActor
    public func importDeck(from fileURL: URL, into store: BlockStore) async throws -> AnkiImportResult {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw AnkiImportError.fileNotFound
        }

        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("anki_import_\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Determine if direct sqlite/zstd file or zipped apkg
        var dbPathURL: URL?
        var isModern = false

        let ext = fileURL.pathExtension.lowercased()
        let filename = fileURL.lastPathComponent

        if ext == "anki21b" || filename == "collection.anki21b" {
            let decompressed = tempDir.appendingPathComponent("collection_decompressed.sqlite")
            try Self.decompressZstd(inputURL: fileURL, outputURL: decompressed)
            dbPathURL = decompressed
            isModern = true
        } else if ext == "anki21" || filename == "collection.anki21" {
            dbPathURL = fileURL
            isModern = true
        } else if ext == "anki2" || filename == "collection.anki2" {
            dbPathURL = fileURL
            isModern = false
        } else {
            // Unpack apkg (ZIP archive)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-q", "-o", fileURL.path, "-d", tempDir.path]

            let errorPipe = Pipe()
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown unzip exit code \(process.terminationStatus)"
                    throw AnkiImportError.unzipFailed(errorMsg)
                }
            } catch {
                throw AnkiImportError.unzipFailed(error.localizedDescription)
            }

            // Look for collection.anki21b first (modern zstd format containing the real database!)
            let anki21bURL = tempDir.appendingPathComponent("collection.anki21b")
            let anki21URL = tempDir.appendingPathComponent("collection.anki21")
            let anki2URL = tempDir.appendingPathComponent("collection.anki2")

            // 1. Modern Anki 2.1.50+ zstd format (contains ALL real cards!)
            if fileManager.fileExists(atPath: anki21bURL.path) {
                let decompressed = tempDir.appendingPathComponent("collection_decompressed.sqlite")
                try Self.decompressZstd(inputURL: anki21bURL, outputURL: decompressed)
                if Self.isSQLiteDatabase(at: decompressed) {
                    dbPathURL = decompressed
                    isModern = true
                }
            }

            // 2. Uncompressed modern format
            if dbPathURL == nil && fileManager.fileExists(atPath: anki21URL.path) && Self.isSQLiteDatabase(at: anki21URL) {
                dbPathURL = anki21URL
                isModern = true
            }

            // 3. Legacy format
            if dbPathURL == nil && fileManager.fileExists(atPath: anki2URL.path) && Self.isSQLiteDatabase(at: anki2URL) {
                dbPathURL = anki2URL
                isModern = false
            }

            // Fallback attempts
            if dbPathURL == nil {
                if fileManager.fileExists(atPath: anki21URL.path) {
                    dbPathURL = anki21URL
                    isModern = true
                } else if fileManager.fileExists(atPath: anki2URL.path) {
                    dbPathURL = anki2URL
                    isModern = false
                }
            }
        }

        guard let resolvedDbURL = dbPathURL, fileManager.fileExists(atPath: resolvedDbURL.path) else {
            throw AnkiImportError.databaseNotFound
        }

        // Open Anki SQLite Database
        let dbQueue: DatabaseQueue
        do {
            dbQueue = try DatabaseQueue(path: resolvedDbURL.path)
        } catch {
            throw AnkiImportError.invalidDatabase(error.localizedDescription)
        }

        // 1. Parse Deck Names from `col` table (JSON) or fallback to `decks` table
        let decksDict: [Int64: String] = try await dbQueue.read { db in
            var map: [Int64: String] = [:]
            if let colRow = try? Row.fetchOne(db, sql: "SELECT decks FROM col LIMIT 1"),
               let decksJson: String = colRow["decks"],
               let data = decksJson.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
                for (idKey, deckObj) in json {
                    if let did = Int64(idKey), let name = deckObj["name"] as? String {
                        map[did] = name
                    }
                }
            }

            if map.isEmpty {
                let hasDecksTable = (try? Row.fetchOne(db, sql: "SELECT 1 FROM sqlite_master WHERE type='table' AND name='decks'")) != nil
                if hasDecksTable {
                    if let rows = try? Row.fetchAll(db, sql: "SELECT id, name FROM decks") {
                        for row in rows {
                            if let did: Int64 = row["id"], let name: String = row["name"] {
                                map[did] = name
                            }
                        }
                    }
                }
            }
            return map
        }

        // 2. Query Notes & Cards
        struct ExtractedCard: Sendable {
            let deckId: Int64
            let front: String
            let back: String
            let hint: String?
            let type: Int
            let queue: Int
            let reps: Int
            let lapses: Int
            let ivl: Int
            let factor: Int
        }

        let extractedCards: [ExtractedCard] = try await dbQueue.read { db in
            let sql = """
            SELECT c.did AS deck_id, c.ord AS card_ord, c.type AS card_type, c.queue AS card_queue,
                   c.reps AS reps, c.lapses AS lapses, c.ivl AS ivl, c.factor AS factor,
                   n.flds AS note_fields
            FROM cards c
            JOIN notes n ON c.nid = n.id
            """

            let rows = try Row.fetchAll(db, sql: sql)
            var cards: [ExtractedCard] = []
            for row in rows {
                let did: Int64 = row["deck_id"] ?? 1
                let ord: Int = row["card_ord"] ?? 0
                let cardType: Int = row["card_type"] ?? 0
                let cardQueue: Int = row["card_queue"] ?? 0
                let reps: Int = row["reps"] ?? 0
                let lapses: Int = row["lapses"] ?? 0
                let ivl: Int = row["ivl"] ?? 0
                let factor: Int = row["factor"] ?? 2500
                let flds: String = row["note_fields"] ?? ""

                let parts = flds.components(separatedBy: "\u{1F}")
                guard !parts.isEmpty else { continue }

                let frontRaw = parts[0]
                let backRaw = parts.count > 1 ? parts[1] : (parts.dropFirst().joined(separator: "\n"))
                let hintRaw = parts.count > 2 ? parts[2] : nil

                // Detect and resolve Cloze deletions if present
                var cleanFront: String
                var cleanBack: String
                var cleanHint: String?

                if let cloze = Self.resolveCloze(text: frontRaw, clozeIndex: ord + 1) {
                    cleanFront = Self.stripHTML(cloze.front)
                    let extraBack = Self.stripHTML(backRaw)
                    cleanBack = extraBack.isEmpty ? Self.stripHTML(cloze.back) : "\(Self.stripHTML(cloze.back))\n\n\(extraBack)"
                    cleanHint = hintRaw != nil ? Self.stripHTML(hintRaw!) : nil
                } else {
                    cleanFront = Self.stripHTML(frontRaw)
                    cleanBack = Self.stripHTML(backRaw)
                    cleanHint = hintRaw != nil ? Self.stripHTML(hintRaw!) : nil
                }

                // Filter out Anki's dummy compatibility warning card
                if cleanFront.contains("Please update to the latest Anki version") {
                    continue
                }

                guard !cleanFront.isEmpty || !cleanBack.isEmpty else { continue }

                cards.append(ExtractedCard(
                    deckId: did,
                    front: cleanFront.isEmpty ? "Untitled Card" : cleanFront,
                    back: cleanBack,
                    hint: cleanHint?.isEmpty == true ? nil : cleanHint,
                    type: cardType,
                    queue: cardQueue,
                    reps: reps,
                    lapses: lapses,
                    ivl: ivl,
                    factor: factor
                ))
            }
            return cards
        }

        guard !extractedCards.isEmpty else {
            throw AnkiImportError.noCardsFound
        }

        // 3. Map to Medha Decks and Batch Insert Flashcards
        let fallbackDeckName = fileURL.deletingPathExtension().lastPathComponent
        var targetMedhaDeckIds: [Int64: String] = [:]
        var createdDeckCount = 0
        var distinctDeckNames: [String] = []

        let groupedByDeck = Dictionary(grouping: extractedCards, by: { $0.deckId })

        for (ankiDeckId, _) in groupedByDeck {
            var rawName = decksDict[ankiDeckId] ?? fallbackDeckName
            if rawName == "Default" && groupedByDeck.count == 1 {
                rawName = fallbackDeckName
            }
            if rawName.isEmpty {
                rawName = fallbackDeckName
            }

            distinctDeckNames.append(rawName)

            let existingDeck = store.decks.first(where: {
                $0.name.localizedCaseInsensitiveCompare(rawName) == .orderedSame
            })

            let medhaDeckId: String
            if let existing = existingDeck {
                medhaDeckId = existing.id
            } else {
                let newDeck = store.createDeck(
                    name: rawName,
                    description: "Imported from Anki (\(isModern ? "collection.anki21b / anki21" : "collection.anki2"))"
                )
                medhaDeckId = newDeck.id
                createdDeckCount += 1
            }
            targetMedhaDeckIds[ankiDeckId] = medhaDeckId
        }

        // Target document and notebook IDs for default storage (imported deck cards do not belong to a note)
        let targetDocId = ""
        let nbId = store.selectedNotebookId ?? store.notebooks.first?.id ?? "nb-default"

        var cardsToBatchInsert: [Flashcard] = []
        cardsToBatchInsert.reserveCapacity(extractedCards.count)

        for card in extractedCards {
            guard let medhaDeckId = targetMedhaDeckIds[card.deckId] else { continue }
            let isSuspended = card.queue == -1

            let fsrsState: FSRSState
            if card.type == 0 || card.queue == 0 {
                fsrsState = .newCard
            } else if card.type == 1 || card.type == 3 {
                fsrsState = .learning
            } else {
                fsrsState = .review
            }

            let stability = Double(max(1, card.ivl))
            let difficulty = min(10.0, max(1.0, 10.0 - (Double(card.factor) / 300.0)))

            var flashcard = Flashcard(
                docId: targetDocId,
                notebookId: nbId,
                deckId: medhaDeckId,
                front: card.front,
                back: card.back,
                sourceBlockId: nil,
                hint: card.hint
            )
            flashcard.fsrsState = fsrsState
            flashcard.stability = stability
            flashcard.difficulty = difficulty
            flashcard.reps = card.reps
            flashcard.lapses = card.lapses
            flashcard.scheduledDays = max(0, card.ivl)
            flashcard.isSuspended = isSuspended

            cardsToBatchInsert.append(flashcard)
        }

        // Execute bulk insert in a single fast transaction!
        store.batchInsertFlashcards(cardsToBatchInsert)

        let summary = "Successfully imported \(cardsToBatchInsert.count) flashcards into \(distinctDeckNames.count) deck(s) using \(isModern ? "modern Anki (.anki21b / .anki21)" : "legacy Anki (.anki2)") schema."

        return AnkiImportResult(
            deckNames: distinctDeckNames,
            importedCardCount: cardsToBatchInsert.count,
            createdDeckCount: createdDeckCount,
            parsedFromModern: isModern,
            details: summary
        )
    }
}
