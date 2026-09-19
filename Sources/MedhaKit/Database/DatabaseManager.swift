import Foundation
import GRDB

public final class DatabaseManager: @unchecked Sendable {
    public static let shared = DatabaseManager()

    public let dbWriter: any DatabaseWriter

    public init(inMemory: Bool = false, customPath: String? = nil) {
        do {
            var config = Configuration()
            config.foreignKeysEnabled = true
            config.qos = .userInitiated

            if inMemory {
                self.dbWriter = try DatabaseQueue(configuration: config)
            } else {
                let dbURL: URL
                if let customPath = customPath {
                    dbURL = URL(fileURLWithPath: customPath)
                } else {
                    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                    let medhaDir = appSupport.appendingPathComponent("Medha", isDirectory: true)
                    try FileManager.default.createDirectory(at: medhaDir, withIntermediateDirectories: true)
                    dbURL = medhaDir.appendingPathComponent("medha.sqlite")
                }

                config.prepareDatabase { db in
                    try db.execute(sql: "PRAGMA journal_mode = WAL;")
                    try db.execute(sql: "PRAGMA synchronous = NORMAL;")
                }

                self.dbWriter = try DatabasePool(path: dbURL.path, configuration: config)
            }

            try migrate()
            try seedIfEmpty()
            try dbWriter.write { db in
                try MockDataSeeder.seedIfMissing(into: db)
            }
        } catch {
            fatalError("Failed to initialize Medha SQLite database: \(error)")
        }
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(in: &migrator)
        try migrator.migrate(dbWriter)
    }

    public func seedIfEmpty() throws {
        try dbWriter.write { db in
            let count = try Notebook.fetchCount(db)
            guard count == 0 else { return }

            let now = Date()

            // 1. Primary Notebook
            let nb1 = Notebook(id: "nb-welcome-kb", name: "Knowledge Base", icon: "brain.head.profile", sortOrder: 0)
            try nb1.insert(db)

            // 2. Secondary Notebook
            let nb2 = Notebook(id: "nb-projects", name: "Projects & Tasks", icon: "checklist", sortOrder: 1)
            try nb2.insert(db)

            // Document 1 in nb1 (Root Page)
            let doc1Id = "b-doc-welcome"
            let doc1 = Block(
                id: doc1Id,
                rootDocId: doc1Id,
                parentId: nil,
                type: .doc,
                content: "Welcome to Medha & Block PKM",
                sortOrder: 0,
                createdAt: now,
                updatedAt: now,
                notebookId: nb1.id
            )
            try doc1.insert(db)

            let calloutId = "b-welcome-callout-1"
            let targetCodeId = "b-welcome-code-1"

            let doc1Blocks: [Block] = [
                Block(id: "b-welcome-h1-1", rootDocId: doc1Id, parentId: doc1Id, type: .heading1, content: "The Philosophy: Everything is a Block", sortOrder: 1, createdAt: now, updatedAt: now),
                Block(id: calloutId, rootDocId: doc1Id, parentId: doc1Id, type: .callout, content: "Medha is inspired by SiYuan Note. Every paragraph, heading, list item, or code snippet is an atomic block with a stable UUID. Ideas stay modular and endlessly reusable.", sortOrder: 2, createdAt: now, updatedAt: now),
                Block(id: "b-welcome-p-1", rootDocId: doc1Id, parentId: doc1Id, type: .paragraph, content: "Unlike traditional file-based markdown editors, Medha stores content at block-granularity in a local-first SQLite database. You can reference individual blocks, transclude them live, and trace backlinks without breaking links when renaming.", sortOrder: 3, createdAt: now, updatedAt: now),
                Block(id: "b-welcome-h2-1", rootDocId: doc1Id, parentId: doc1Id, type: .heading2, content: "Native macOS Shortcuts & Editing", sortOrder: 4, createdAt: now, updatedAt: now),
                Block(id: "b-welcome-task-1", rootDocId: doc1Id, parentId: doc1Id, type: .taskList, content: "Press ⌘K to open the Spotlight-speed Command Palette (FTS5 search)", sortOrder: 5, isCompleted: true, createdAt: now, updatedAt: now),
                Block(id: "b-welcome-task-2", rootDocId: doc1Id, parentId: doc1Id, type: .taskList, content: "Type / anywhere in a block to convert it via the Slash Menu", sortOrder: 6, isCompleted: true, createdAt: now, updatedAt: now),
                Block(id: "b-welcome-task-3", rootDocId: doc1Id, parentId: doc1Id, type: .taskList, content: "Press Enter to create a new block below, or Backspace to delete/outdent", sortOrder: 7, isCompleted: false, createdAt: now, updatedAt: now),
                Block(id: "b-welcome-task-4", rootDocId: doc1Id, parentId: doc1Id, type: .taskList, content: "Click the ⋮⋮ handle on the left to copy a block reference ((id))", sortOrder: 8, isCompleted: false, createdAt: now, updatedAt: now),
                Block(id: "b-welcome-h2-2", rootDocId: doc1Id, parentId: doc1Id, type: .heading2, content: "Atomic Data Architecture", sortOrder: 9, createdAt: now, updatedAt: now),
                Block(id: targetCodeId, rootDocId: doc1Id, parentId: doc1Id, type: .codeBlock, content: """
                struct Block: Identifiable, Codable {
                    var id: String            // Stable UUID: "b-$UUID"
                    var rootDocId: String     // Document container
                    var parentId: String?     // Nested hierarchy (Tab/Shift-Tab)
                    var type: BlockType       // .doc, .heading, .paragraph, .blockRef...
                    var content: String       // Block body text
                    var refTargetId: String?  // Target for live transclusion
                }
                """, sortOrder: 10, createdAt: now, updatedAt: now),
                Block(id: "b-welcome-h2-3", rootDocId: doc1Id, parentId: doc1Id, type: .heading2, content: "Block Reference & Live Transclusion", sortOrder: 11, createdAt: now, updatedAt: now),
                Block(id: "b-welcome-ref-1", rootDocId: doc1Id, parentId: doc1Id, type: .blockRef, content: "", sortOrder: 12, refTargetId: calloutId, createdAt: now, updatedAt: now),
                Block(id: "b-welcome-p-2", rootDocId: doc1Id, parentId: doc1Id, type: .paragraph, content: "The block above is a live transclusion of the callout at the top of this note! Notice how it mirrors its content with an interactive link pill.", sortOrder: 13, createdAt: now, updatedAt: now),
                Block(id: "b-welcome-quote-1", rootDocId: doc1Id, parentId: doc1Id, type: .quote, content: "The real power of knowledge management comes not from collecting files, but from linking atomic thoughts into a coherent graph.", sortOrder: 14, createdAt: now, updatedAt: now)
            ]

            for block in doc1Blocks {
                try block.insert(db)
            }

            // Sub-note 1 under doc1: "Deep Dive: Atomic Blocks"
            let subDoc1Id = "b-doc-sub-atomic"
            let subDoc1 = Block(
                id: subDoc1Id,
                rootDocId: subDoc1Id,
                parentId: doc1Id, // Nested under doc1!
                type: .doc,
                content: "Deep Dive: Atomic Blocks",
                sortOrder: 0,
                createdAt: now,
                updatedAt: now,
                notebookId: nb1.id
            )
            try subDoc1.insert(db)

            let subDoc1Blocks: [Block] = [
                Block(id: "b-sub-h1-1", rootDocId: subDoc1Id, parentId: subDoc1Id, type: .heading1, content: "Granular Knowledge Architecture", sortOrder: 1, createdAt: now, updatedAt: now),
                Block(id: "b-sub-p-1", rootDocId: subDoc1Id, parentId: subDoc1Id, type: .paragraph, content: "In Medha, every block has its own identity. Documents can also nest to create deep, structured hierarchies of sub-notes.", sortOrder: 2, createdAt: now, updatedAt: now),
                Block(id: "b-sub-callout-1", rootDocId: subDoc1Id, parentId: subDoc1Id, type: .callout, content: "Look at the Document Tree on the left: this note is nested under 'Welcome to Medha & Block PKM' as a first-class sub-note!", sortOrder: 3, createdAt: now, updatedAt: now)
            ]
            for b in subDoc1Blocks {
                try b.insert(db)
            }

            // Document 2 in nb1: Bidirectional Linking & Graph
            let doc2Id = "b-doc-graph"
            let doc2 = Block(
                id: doc2Id,
                rootDocId: doc2Id,
                parentId: nil,
                type: .doc,
                content: "Bidirectional Linking & Knowledge Graph",
                sortOrder: 1,
                createdAt: now,
                updatedAt: now,
                notebookId: nb1.id
            )
            try doc2.insert(db)

            let doc2Blocks: [Block] = [
                Block(id: "b-graph-h1-1", rootDocId: doc2Id, parentId: doc2Id, type: .heading1, content: "Understanding Backlinks", sortOrder: 1, createdAt: now, updatedAt: now),
                Block(id: "b-graph-p-1", rootDocId: doc2Id, parentId: doc2Id, type: .paragraph, content: "In Medha, every block reference creates a bidirectional connection. Check the right Inspector (⌘I) under the Backlinks tab to see all references.", sortOrder: 2, createdAt: now, updatedAt: now),
                Block(id: "b-graph-ref-1", rootDocId: doc2Id, parentId: doc2Id, type: .blockRef, content: "", sortOrder: 3, refTargetId: doc1Id, createdAt: now, updatedAt: now),
                Block(id: "b-graph-callout-1", rootDocId: doc2Id, parentId: doc2Id, type: .callout, content: "Try opening the Inspector (⌘I) to view the Outline, Backlinks, Document Metadata, and the interactive Local Graph!", sortOrder: 4, createdAt: now, updatedAt: now)
            ]

            for block in doc2Blocks {
                try block.insert(db)
            }

            // Document 3 in nb2: Project Roadmap
            let doc3Id = "b-doc-roadmap"
            let doc3 = Block(
                id: doc3Id,
                rootDocId: doc3Id,
                parentId: nil,
                type: .doc,
                content: "Q4 Engineering Roadmap",
                sortOrder: 0,
                createdAt: now,
                updatedAt: now,
                notebookId: nb2.id
            )
            try doc3.insert(db)

            let doc3Blocks: [Block] = [
                Block(id: "b-road-h1-1", rootDocId: doc3Id, parentId: doc3Id, type: .heading1, content: "Milestones & Deliverables", sortOrder: 1, createdAt: now, updatedAt: now),
                Block(id: "b-road-task-1", rootDocId: doc3Id, parentId: doc3Id, type: .taskList, content: "Implement GRDB SQLite engine with FTS5 token triggers", sortOrder: 2, isCompleted: true, createdAt: now, updatedAt: now),
                Block(id: "b-road-task-2", rootDocId: doc3Id, parentId: doc3Id, type: .taskList, content: "Build 3-column macOS HIG NavigationSplitView with sub-note tree", sortOrder: 3, isCompleted: true, createdAt: now, updatedAt: now),
                Block(id: "b-road-task-3", rootDocId: doc3Id, parentId: doc3Id, type: .taskList, content: "Integrate AppKit NSTextView bridge for block keyboard accelerators", sortOrder: 4, isCompleted: true, createdAt: now, updatedAt: now),
                Block(id: "b-road-task-4", rootDocId: doc3Id, parentId: doc3Id, type: .taskList, content: "Ship interactive 2D graph view and document hierarchy", sortOrder: 5, isCompleted: true, createdAt: now, updatedAt: now)
            ]

            for block in doc3Blocks {
                try block.insert(db)
            }

            // Sub-note under doc3: "Sprint 1: Core Engine"
            let subDoc3Id = "b-doc-sub-sprint1"
            let subDoc3 = Block(
                id: subDoc3Id,
                rootDocId: subDoc3Id,
                parentId: doc3Id,
                type: .doc,
                content: "Sprint 1: Core Engine",
                sortOrder: 0,
                createdAt: now,
                updatedAt: now,
                notebookId: nb2.id
            )
            try subDoc3.insert(db)

            let subDoc3Blocks: [Block] = [
                Block(id: "b-sp1-h1-1", rootDocId: subDoc3Id, parentId: subDoc3Id, type: .heading1, content: "Engine Architecture Review", sortOrder: 1, createdAt: now, updatedAt: now),
                Block(id: "b-sp1-task-1", rootDocId: subDoc3Id, parentId: subDoc3Id, type: .taskList, content: "Zero-latency SQLite WAL concurrency", sortOrder: 2, isCompleted: true, createdAt: now, updatedAt: now),
                Block(id: "b-sp1-task-2", rootDocId: subDoc3Id, parentId: subDoc3Id, type: .taskList, content: "Hierarchical sub-notes with recursive cascade deletion", sortOrder: 3, isCompleted: true, createdAt: now, updatedAt: now)
            ]
            for b in subDoc3Blocks {
                try b.insert(db)
            }

            // 3. Seed Sample Flashcards (Preserving Folder/Note Hierarchy)
            let fc1 = Flashcard(
                id: "fc-atomic-phil",
                docId: doc1Id, // Attached to "Welcome to Medha & Block PKM" folder
                notebookId: nb1.id,
                deckId: Deck.notesDefaultId,
                front: "What is the core principle of SiYuan & Medha's block-based PKM?",
                back: "Every unit of information (paragraph, heading, task, code) is an atomic block with a stable UUID. Renaming notes or reorganizing content never breaks backlinks or references.",
                hint: "Think about atomic blocks vs monolithic files"
            )
            try fc1.insert(db)

            let fc2 = Flashcard(
                id: "fc-fsrs-retention",
                docId: subDoc1Id, // Attached to "Deep Dive: Atomic Blocks" sub-folder
                notebookId: nb1.id,
                deckId: Deck.notesDefaultId,
                front: "How does the FSRS algorithm calculate retrievability (R)?",
                back: "R(t, S) = (1 + 19 * (t / S))^(-0.5), where t is elapsed days since last review and S is memory stability.",
                hint: "Power law of forgetting"
            )
            try fc2.insert(db)

            let fc3 = Flashcard(
                id: "fc-backlinks-bidirectional",
                docId: doc2Id, // Attached to "Bidirectional Linking & Knowledge Graph"
                notebookId: nb1.id,
                deckId: Deck.notesDefaultId,
                front: "What is the difference between unidirectional hyperlinks and bidirectional block references?",
                back: "Bidirectional references are automatically indexed in both directions: referencing ((id)) registers an incoming backlink on the target block without modifying the target document.",
                hint: "Automatic backlink discovery"
            )
            try fc3.insert(db)

            // 4. Seed Default Memory Palace (Method of Loci with 2D Visual Map)
            let defaultPalaceId = "mp-athenaeum"
            let palace = MemoryPalace(
                id: defaultPalaceId,
                name: "The Grand Athenaeum Library",
                imagePath: "bundled:athenaeum_blueprint",
                description: "A classical Roman rotunda library featuring spatial loci along an architectural colonnade.",
                sortOrder: 0
            )
            try palace.insert(db)

            // Seed Sequential Palace Photos
            let photo1 = PalacePhoto(
                id: "photo-athenaeum-1",
                palaceId: defaultPalaceId,
                name: "1. Rotunda Colonnade",
                imagePath: "bundled:athenaeum_blueprint",
                orderIndex: 0
            )
            let photo2 = PalacePhoto(
                id: "photo-athenaeum-2",
                palaceId: defaultPalaceId,
                name: "2. Celestial Gallery",
                imagePath: "bundled:athenaeum_gallery",
                orderIndex: 1
            )
            try photo1.insert(db)
            try photo2.insert(db)

            let loci: [PalaceLocus] = [
                PalaceLocus(
                    id: "locus-entrance",
                    palaceId: defaultPalaceId,
                    photoId: photo1.id,
                    flashcardId: fc1.id,
                    docId: doc1Id,
                    title: "1. Colonnade Entrance",
                    mnemonic: "Marble pillars inscribed with atomic UUIDs holding up the archway of knowledge.",
                    anchoredInfo: "Classical Ionic colonnade with 12 marble pillars representing the foundational core axioms.",
                    normalizedX: 0.22,
                    normalizedY: 0.78,
                    orderIndex: 0
                ),
                PalaceLocus(
                    id: "locus-fountain",
                    palaceId: defaultPalaceId,
                    photoId: photo1.id,
                    flashcardId: fc2.id,
                    docId: subDoc1Id,
                    title: "2. Central Reflection Pool",
                    mnemonic: "Clear water pulsing with FSRS forgetting curves, ripples expanding as stability increases.",
                    anchoredInfo: "Constructed with circular white marble basins; water ripples calibrate retention curves.",
                    normalizedX: 0.50,
                    normalizedY: 0.50,
                    orderIndex: 1
                ),
                PalaceLocus(
                    id: "locus-rotunda",
                    palaceId: defaultPalaceId,
                    photoId: photo2.id,
                    flashcardId: fc3.id,
                    docId: doc2Id,
                    title: "3. Rotunda Constellation Dome",
                    mnemonic: "Golden filaments connecting floating scrolls across the domed ceiling like a 2D knowledge graph.",
                    anchoredInfo: "Astronomical dome featuring 88 golden constellation inlays mapping cross-document backlinks.",
                    normalizedX: 0.78,
                    normalizedY: 0.28,
                    orderIndex: 2
                )
            ]
            for locus in loci {
                try locus.insert(db)
            }

            // Seed Multi-Flashcard Links (locus-entrance has multiple flashcards: fc1 and fc2)
            let lf1 = LocusFlashcard(id: "lf-entrance-1", locusId: "locus-entrance", flashcardId: fc1.id, sortOrder: 0)
            let lf2 = LocusFlashcard(id: "lf-entrance-2", locusId: "locus-entrance", flashcardId: fc2.id, sortOrder: 1)
            let lf3 = LocusFlashcard(id: "lf-fountain-1", locusId: "locus-fountain", flashcardId: fc2.id, sortOrder: 0)
            let lf4 = LocusFlashcard(id: "lf-rotunda-1", locusId: "locus-rotunda", flashcardId: fc3.id, sortOrder: 0)
            try lf1.insert(db)
            try lf2.insert(db)
            try lf3.insert(db)
            try lf4.insert(db)

            // 7. Seed Sample WikiLink (LINKS_TO graph edge)
            let seedLink = DocLink(
                id: "dl-graph-to-welcome",
                sourceDocId: doc2Id,
                sourceBlockId: "b-graph-p-1",
                targetTitle: "Welcome to Medha & Block PKM",
                targetDocId: doc1Id,
                createdAt: now
            )
            try seedLink.insert(db)
        }
    }
}
