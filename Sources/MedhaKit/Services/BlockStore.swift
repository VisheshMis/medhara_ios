import Foundation
import GRDB
import Combine

public enum MoveDirection {
    case up
    case down
}

public enum InspectorTab: String, CaseIterable, Identifiable {
    case outline = "Outline"
    case backlinks = "Backlinks"
    case graph = "Graph"
    case info = "Info"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .outline: return "list.bullet.indent"
        case .backlinks: return "link"
        case .graph: return "circle.hexagongrid.fill"
        case .info: return "info.circle"
        }
    }
}

public enum QuickFilter: String, CaseIterable, Identifiable {
    case allNotes = "All Notes"
    case recent = "Recent"
    case tasks = "Action Items"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .allNotes: return "tray.full"
        case .recent: return "clock"
        case .tasks: return "checklist"
        }
    }
}

public enum MainViewDestination: String, CaseIterable, Identifiable, Sendable {
    case editor = "Notes & Folders"
    case flashcards = "Flashcard Decks (FSRS)"
    case palace = "Memory Palace"

    public var id: String { rawValue }

    public var systemIcon: String {
        switch self {
        case .editor: return "doc.text"
        case .flashcards: return "rectangle.on.rectangle.angled"
        case .palace: return "building.columns.fill"
        }
    }
}

@MainActor
public final class BlockStore: ObservableObject {
    public let dbManager: DatabaseManager
    public let searchService: SearchService
    public let timerManager = FocusTimerManager()

    @Published public var activeMainView: MainViewDestination = .editor

    @Published public var notebooks: [Notebook] = []
    @Published public var selectedNotebookId: String?
    @Published public var selectedFilter: QuickFilter? = .allNotes

    @Published public var documents: [Block] = []
    @Published public var expandedDocIds: Set<String> = []
    @Published public var selectedDocId: String?
    @Published public var currentDoc: Block?

    @Published public var blocks: [Block] = []
    @Published public var focusedBlockId: String?

    // Flashcards & FSRS Decks
    @Published public var flashcards: [Flashcard] = []
    @Published public var decks: [Deck] = []
    @Published public var selectedDeckId: String? = nil

    // Memory Palace (Method of Loci with sequential 2D photos & multi-flashcard anchors)
    @Published public var memoryPalaces: [MemoryPalace] = []
    @Published public var selectedPalaceId: String?
    @Published public var palacePhotos: [PalacePhoto] = []
    @Published public var activePhotoId: String?
    @Published public var loci: [PalaceLocus] = []
    @Published public var locusFlashcards: [LocusFlashcard] = []

    // Links (LINKS_TO arbitrary directed graph)
    @Published public var docLinks: [DocLink] = []

    // Inspector
    @Published public var isInspectorPresented: Bool = true
    @Published public var selectedInspectorTab: InspectorTab = .outline

    // Document Tree Visibility (Contextual to Notes & Folders)
    @Published public var isDocumentTreeVisible: Bool = true

    public func toggleDocumentTree() {
        isDocumentTreeVisible.toggle()
    }

    // Notes AI Assistant Sidebar Visibility
    @Published public var isNotesAIAssistantPresented: Bool = false

    public func toggleNotesAIAssistant() {
        isNotesAIAssistantPresented.toggle()
        if isNotesAIAssistantPresented {
            isInspectorPresented = false
        }
    }

    public func toggleInspector() {
        if isInspectorPresented && !isNotesAIAssistantPresented {
            isInspectorPresented = false
        } else {
            isInspectorPresented = true
            isNotesAIAssistantPresented = false
        }
    }

    // Overlays
    @Published public var isCommandPalettePresented: Bool = false
    @Published public var isBlockPickerPresented: Bool = false
    @Published public var blockPendingRefId: String?

    public init(dbManager: DatabaseManager = .shared) {
        self.dbManager = dbManager
        self.searchService = SearchService(dbWriter: dbManager.dbWriter)
        refreshAll()
    }

    public func refreshAll() {
        loadNotebooks()
        loadDocuments()
        loadDecks()
        loadFlashcards()
        loadMemoryPalaces()
        loadLocusFlashcards()
        loadDocLinks()
        if let firstDoc = documents.first, selectedDocId == nil {
            selectDocument(id: firstDoc.id)
        }
        if selectedPalaceId == nil, let firstPalace = memoryPalaces.first {
            selectPalace(id: firstPalace.id)
        }
        if selectedDeckId == nil {
            selectedDeckId = defaultNotesDeck?.id ?? Deck.notesDefaultId
        }
    }

    public func loadDocLinks() {
        do {
            try dbManager.dbWriter.read { db in
                self.docLinks = try DocLink.order(DocLink.Columns.createdAt).fetchAll(db)
            }
        } catch {
            print("Error loading doc links: \(error)")
        }
    }

    // MARK: - Notebooks
    public func loadNotebooks() {
        do {
            try dbManager.dbWriter.read { db in
                self.notebooks = try Notebook.order(Notebook.Columns.sortOrder).fetchAll(db)
            }
        } catch {
            print("Error loading notebooks: \(error)")
        }
    }

    public func selectNotebook(id: String?) {
        selectedNotebookId = id
        selectedFilter = nil
        loadDocuments()
        if let first = documents.first {
            selectDocument(id: first.id)
        } else {
            selectDocument(id: nil)
        }
    }

    public func selectQuickFilter(_ filter: QuickFilter) {
        selectedFilter = filter
        selectedNotebookId = nil
        loadDocuments()
        if let first = documents.first {
            selectDocument(id: first.id)
        } else {
            selectDocument(id: nil)
        }
    }

    public func createNotebook(name: String, icon: String? = "book.closed.fill") {
        let newNb = Notebook(
            name: name.isEmpty ? "Untitled Notebook" : name,
            icon: icon,
            sortOrder: notebooks.count
        )
        do {
            try dbManager.dbWriter.write { db in
                try newNb.insert(db)
            }
            loadNotebooks()
            selectNotebook(id: newNb.id)
        } catch {
            print("Error creating notebook: \(error)")
        }
    }

    public func deleteNotebook(id: String) {
        do {
            try dbManager.dbWriter.write { db in
                let docs = try Block.filter(Block.Columns.type == BlockType.doc.rawValue && Block.Columns.notebookId == id).fetchAll(db)
                for doc in docs {
                    _ = try Block.filter(Block.Columns.rootDocId == doc.id).deleteAll(db)
                }
                _ = try Notebook.filter(Notebook.Columns.id == id).deleteAll(db)
            }
            loadNotebooks()
            if selectedNotebookId == id {
                selectedNotebookId = notebooks.first?.id
            }
            loadDocuments()
        } catch {
            print("Error deleting notebook: \(error)")
        }
    }

    // MARK: - Documents & Hierarchy
    public func isDocExpanded(id: String) -> Bool {
        expandedDocIds.contains(id)
    }

    public func toggleDocExpansion(id: String) {
        if expandedDocIds.contains(id) {
            expandedDocIds.remove(id)
        } else {
            expandedDocIds.insert(id)
        }
    }

    public func expandDoc(id: String) {
        expandedDocIds.insert(id)
    }

    public func collapseDoc(id: String) {
        expandedDocIds.remove(id)
    }

    public func expandAll() {
        expandedDocIds = Set(documents.map { $0.id })
    }

    public func collapseAll() {
        expandedDocIds.removeAll()
    }

    public func loadDocuments() {
        do {
            try dbManager.dbWriter.read { db in
                var query = Block.filter(Block.Columns.type == BlockType.doc.rawValue)
                if let nbId = self.selectedNotebookId {
                    query = query.filter(Block.Columns.notebookId == nbId)
                }
                if let filter = self.selectedFilter {
                    switch filter {
                    case .allNotes:
                        break
                    case .recent:
                        query = query.order(Block.Columns.updatedAt.desc)
                    case .tasks:
                        break
                    }
                }
                self.documents = try query.order(Block.Columns.sortOrder).fetchAll(db)
            }
            if self.expandedDocIds.isEmpty {
                let parentIds = Set(self.documents.compactMap { $0.parentId })
                self.expandedDocIds = parentIds
            }
        } catch {
            print("Error loading documents: \(error)")
        }
    }

    public func getDocTree() -> [DocTreeNode] {
        let docMap = Dictionary(grouping: documents, by: { $0.parentId ?? "" })
        let docIdSet = Set(documents.map { $0.id })
        let rootDocs = documents.filter { doc in
            guard let parentId = doc.parentId else { return true }
            return !docIdSet.contains(parentId)
        }.sorted { $0.sortOrder < $1.sortOrder }

        func buildNode(doc: Block, level: Int) -> DocTreeNode {
            let children = (docMap[doc.id] ?? [])
                .sorted { $0.sortOrder < $1.sortOrder }
                .map { buildNode(doc: $0, level: level + 1) }
            return DocTreeNode(doc: doc, level: level, children: children)
        }

        return rootDocs.map { buildNode(doc: $0, level: 0) }
    }

    public func getFlattenedDocTree() -> [DocTreeNode] {
        let tree = getDocTree()
        var flat: [DocTreeNode] = []

        func traverse(_ node: DocTreeNode) {
            flat.append(node)
            if expandedDocIds.contains(node.doc.id) {
                for child in node.children {
                    traverse(child)
                }
            }
        }

        for root in tree {
            traverse(root)
        }
        return flat
    }

    public func getFilteredDocTree(filter: String) -> [DocTreeNode] {
        let trimmed = filter.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return getFlattenedDocTree()
        }

        let tree = getDocTree()
        func filterNode(_ node: DocTreeNode) -> DocTreeNode? {
            let matchesSelf = node.doc.content.localizedCaseInsensitiveContains(trimmed)
            let filteredChildren = node.children.compactMap { filterNode($0) }
            if matchesSelf || !filteredChildren.isEmpty {
                return DocTreeNode(doc: node.doc, level: node.level, children: filteredChildren)
            }
            return nil
        }

        let filteredRoots = tree.compactMap { filterNode($0) }
        var flat: [DocTreeNode] = []
        func flattenAll(_ node: DocTreeNode) {
            flat.append(node)
            for child in node.children {
                flattenAll(child)
            }
        }
        for root in filteredRoots {
            flattenAll(root)
        }
        return flat
    }

    public func getDocAncestry(for docId: String) -> [Block] {
        var ancestry: [Block] = []
        var currentId: String? = docId
        var visited: Set<String> = []

        while let id = currentId, !visited.contains(id) {
            visited.insert(id)
            if let doc = documents.first(where: { $0.id == id }) ?? getBlock(id: id) {
                ancestry.append(doc)
                currentId = doc.parentId
            } else {
                break
            }
        }
        return ancestry.reversed()
    }

    @discardableResult
    public func createDocument(
        title: String = "Untitled Document",
        notebookId: String? = nil,
        parentDocId: String? = nil
    ) -> Block {
        let now = Date()
        let parentDoc = parentDocId != nil ? (documents.first(where: { $0.id == parentDocId }) ?? getBlock(id: parentDocId!)) : nil
        let targetNbId = notebookId ?? parentDoc?.notebookId ?? selectedNotebookId ?? notebooks.first?.id ?? "nb-default"
        let newDocId = Block.generateId()

        if let parentId = parentDocId {
            expandedDocIds.insert(parentId)
        }

        let doc = Block(
            id: newDocId,
            rootDocId: newDocId,
            parentId: parentDocId,
            type: .doc,
            content: title,
            sortOrder: documents.count,
            createdAt: now,
            updatedAt: now,
            notebookId: targetNbId
        )

        let initialBlock = Block(
            id: Block.generateId(),
            rootDocId: newDocId,
            parentId: newDocId,
            type: .paragraph,
            content: "",
            sortOrder: 0,
            createdAt: now,
            updatedAt: now
        )

        do {
            try dbManager.dbWriter.write { db in
                try doc.insert(db)
                try initialBlock.insert(db)
            }
            loadDocuments()
            selectDocument(id: newDocId)
            focusedBlockId = initialBlock.id
        } catch {
            print("Error creating document: \(error)")
        }
        return doc
    }

    public func renameDocument(docId: String, newTitle: String) {
        do {
            try dbManager.dbWriter.write { db in
                if var doc = try Block.fetchOne(db, key: docId) {
                    doc.content = newTitle
                    doc.updatedAt = Date()
                    try doc.update(db)
                }
            }
            loadDocuments()
            if selectedDocId == docId {
                currentDoc?.content = newTitle
            }
        } catch {
            print("Error renaming document: \(error)")
        }
    }

    public func deleteDocument(docId: String) {
        do {
            var toDelete: Set<String> = [docId]
            try dbManager.dbWriter.write { db in
                var queue = [docId]
                while !queue.isEmpty {
                    let current = queue.removeFirst()
                    let children = try Block.filter(Block.Columns.type == BlockType.doc.rawValue && Block.Columns.parentId == current).fetchAll(db)
                    for child in children {
                        if !toDelete.contains(child.id) {
                            toDelete.insert(child.id)
                            queue.append(child.id)
                        }
                    }
                }

                for id in toDelete {
                    _ = try Block.filter(Block.Columns.rootDocId == id).deleteAll(db)
                    _ = try Block.filter(Block.Columns.id == id).deleteAll(db)
                    _ = try Flashcard.filter(Flashcard.Columns.docId == id).deleteAll(db)
                    _ = try PalaceLocus.filter(PalaceLocus.Columns.docId == id).deleteAll(db)
                    _ = try DocLink.filter(DocLink.Columns.sourceDocId == id).deleteAll(db)
                    try db.execute(sql: "UPDATE doc_link SET targetDocId = NULL WHERE targetDocId = ?", arguments: [id])
                }
            }
            for id in toDelete {
                expandedDocIds.remove(id)
            }
            loadDocuments()
            loadFlashcards()
            loadDocLinks()
            if let palId = selectedPalaceId {
                loadLoci(for: palId)
            }
            if let sel = selectedDocId, toDelete.contains(sel) {
                selectDocument(id: documents.first?.id)
            }
        } catch {
            print("Error deleting document hierarchy: \(error)")
        }
    }

    // MARK: - Notes AI Hierarchy Commitment
    public func commitHierarchicalNotes(
        rootDocId: String,
        result: HierarchicalGenerationResult,
        destination: HierarchyDestination
    ) {
        guard let parentDoc = documents.first(where: { $0.id == rootDocId }) ?? getBlock(id: rootDocId) else {
            return
        }

        let now = Date()
        let targetNbId = parentDoc.notebookId ?? selectedNotebookId ?? notebooks.first?.id ?? "nb-default"

        do {
            try dbManager.dbWriter.write { db in
                // 1. If destination includes .treeSubNotes or .both: create child documents in the downward tree
                if destination == .treeSubNotes || destination == .both {
                    func insertSubtree(nodes: [HierarchicalNode], parentId: String, currentSort: inout Int) throws {
                        for node in nodes where node.isSelected {
                            let docId = Block.generateId()
                            let docBlock = Block(
                                id: docId,
                                rootDocId: docId,
                                parentId: parentId, // STRICT DOWNWARD HIERARCHY
                                type: .doc,
                                content: node.title,
                                sortOrder: currentSort,
                                createdAt: now,
                                updatedAt: now,
                                notebookId: targetNbId
                            )
                            try docBlock.insert(db)
                            currentSort += 1

                            // Insert blocks inside this newly created child document
                            var innerSort = 0
                            if !node.summary.isEmpty {
                                let summaryBlock = Block(
                                    id: Block.generateId(),
                                    rootDocId: docId,
                                    parentId: docId,
                                    type: .paragraph,
                                    content: node.summary,
                                    sortOrder: innerSort,
                                    createdAt: now,
                                    updatedAt: now
                                )
                                try summaryBlock.insert(db)
                                innerSort += 1
                            }

                            for item in node.blocks {
                                let contentBlock = Block(
                                    id: Block.generateId(),
                                    rootDocId: docId,
                                    parentId: docId,
                                    type: item.blockType,
                                    content: item.content,
                                    sortOrder: innerSort,
                                    createdAt: now,
                                    updatedAt: now
                                )
                                try contentBlock.insert(db)
                                innerSort += 1
                            }

                            if innerSort == 0 {
                                let emptyBlock = Block(
                                    id: Block.generateId(),
                                    rootDocId: docId,
                                    parentId: docId,
                                    type: .paragraph,
                                    content: "",
                                    sortOrder: 0,
                                    createdAt: now,
                                    updatedAt: now
                                )
                                try emptyBlock.insert(db)
                            }

                            // Recursively insert downward children
                            if !node.children.isEmpty {
                                try insertSubtree(nodes: node.children, parentId: docId, currentSort: &currentSort)
                            }
                        }
                    }

                    var sortCounter = (try Block.filter(Block.Columns.parentId == rootDocId).fetchCount(db))
                    try insertSubtree(nodes: result.items, parentId: rootDocId, currentSort: &sortCounter)
                }

                // 2. If destination includes .documentBlocks or .both: insert blocks directly into current document body
                if destination == .documentBlocks || destination == .both {
                    var currentBlockSort = ((try Block.filter(Block.Columns.rootDocId == rootDocId && Block.Columns.type != BlockType.doc.rawValue)
                        .order(Block.Columns.sortOrder)
                        .fetchAll(db).last?.sortOrder) ?? -1) + 1

                    func insertBlocksOutline(nodes: [HierarchicalNode], depth: Int) throws {
                        for node in nodes where node.isSelected {
                            let headingType: BlockType = depth == 0 ? .heading2 : .heading3
                            let titleBlock = Block(
                                id: Block.generateId(),
                                rootDocId: rootDocId,
                                parentId: rootDocId,
                                type: headingType,
                                content: node.title,
                                sortOrder: currentBlockSort,
                                createdAt: now,
                                updatedAt: now
                            )
                            try titleBlock.insert(db)
                            currentBlockSort += 1

                            if !node.summary.isEmpty {
                                let sumBlock = Block(
                                    id: Block.generateId(),
                                    rootDocId: rootDocId,
                                    parentId: rootDocId,
                                    type: .callout,
                                    content: node.summary,
                                    sortOrder: currentBlockSort,
                                    createdAt: now,
                                    updatedAt: now
                                )
                                try sumBlock.insert(db)
                                currentBlockSort += 1
                            }

                            for item in node.blocks {
                                let b = Block(
                                    id: Block.generateId(),
                                    rootDocId: rootDocId,
                                    parentId: rootDocId,
                                    type: item.blockType,
                                    content: item.content,
                                    sortOrder: currentBlockSort,
                                    createdAt: now,
                                    updatedAt: now
                                )
                                try b.insert(db)
                                currentBlockSort += 1
                            }

                            if !node.children.isEmpty {
                                try insertBlocksOutline(nodes: node.children, depth: depth + 1)
                            }
                        }
                    }

                    try insertBlocksOutline(nodes: result.items, depth: 0)
                }
            }

            expandedDocIds.insert(rootDocId)
            loadDocuments()
            reloadBlocks()
        } catch {
            print("Error committing hierarchical notes: \(error)")
        }
    }

    // MARK: - Unresolved Link Resolution
    @discardableResult
    public func createDocFromUnresolvedLink(
        title: String,
        sourceDocId: String? = nil,
        notebookId: String? = nil
    ) -> Block {
        // Required behavior: Creating a node via an unresolved link ([[C]] where C does not exist)
        // places C at the default/inbox location (parentDocId == nil), NOT under A.
        let targetNbId = notebookId ?? selectedNotebookId ?? notebooks.first?.id ?? "nb-default"
        let newDoc = createDocument(title: title, notebookId: targetNbId, parentDocId: nil)

        do {
            try dbManager.dbWriter.write { db in
                try db.execute(
                    sql: "UPDATE doc_link SET targetDocId = ? WHERE lower(targetTitle) = lower(?) AND targetDocId IS NULL",
                    arguments: [newDoc.id, title]
                )
            }
            loadDocLinks()
        } catch {
            print("Error resolving doc links for newly created doc: \(error)")
        }

        return newDoc
    }

    // MARK: - Tree Relocation (CONTAINS)
    public func moveDocument(docId: String, newParentDocId: String?) {
        guard let index = documents.firstIndex(where: { $0.id == docId }) else { return }
        if let targetParent = newParentDocId {
            guard targetParent != docId else { return }
            let descendants = getAllDescendantDocIds(for: docId)
            guard !descendants.contains(targetParent) else { return }
        }

        documents[index].parentId = newParentDocId
        documents[index].updatedAt = Date()
        let docToSave = documents[index]

        do {
            try dbManager.dbWriter.write { db in
                try docToSave.update(db)
            }
            if let newParent = newParentDocId {
                expandedDocIds.insert(newParent)
            }
            loadDocuments()
        } catch {
            print("Error moving document in tree: \(error)")
        }
    }

    public func getAllDescendantDocIds(for docId: String) -> Set<String> {
        var descendants: Set<String> = []
        var queue = [docId]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            let children = documents.filter { $0.parentId == current }
            for child in children {
                if !descendants.contains(child.id) {
                    descendants.insert(child.id)
                    queue.append(child.id)
                }
            }
        }
        return descendants
    }

    public func selectDocument(id: String?) {
        selectedDocId = id
        guard let id = id else {
            currentDoc = nil
            blocks = []
            return
        }
        do {
            try dbManager.dbWriter.read { db in
                self.currentDoc = try Block.fetchOne(db, key: id)
                self.blocks = try Block.filter(Block.Columns.rootDocId == id && Block.Columns.type != BlockType.doc.rawValue)
                    .order(Block.Columns.sortOrder)
                    .fetchAll(db)
            }
        } catch {
            print("Error selecting document: \(error)")
        }
    }

    public func reloadBlocks() {
        guard let docId = selectedDocId else { return }
        do {
            try dbManager.dbWriter.read { db in
                self.blocks = try Block.filter(Block.Columns.rootDocId == docId && Block.Columns.type != BlockType.doc.rawValue)
                    .order(Block.Columns.sortOrder)
                    .fetchAll(db)
            }
        } catch {
            print("Error reloading blocks: \(error)")
        }
    }

    // MARK: - Block Editing Operations
    @discardableResult
    public func createBlock(
        after currentBlock: Block? = nil,
        type: BlockType = .paragraph,
        content: String = "",
        parentId: String? = nil
    ) -> Block {
        guard let docId = selectedDocId else {
            fatalError("Cannot create block without selected document")
        }
        let now = Date()
        let newSortOrder: Int
        if let currentBlock = currentBlock {
            newSortOrder = currentBlock.sortOrder + 1
        } else {
            newSortOrder = (blocks.last?.sortOrder ?? 0) + 1
        }

        let newBlock = Block(
            id: Block.generateId(),
            rootDocId: docId,
            parentId: parentId ?? currentBlock?.parentId ?? docId,
            type: type,
            content: content,
            sortOrder: newSortOrder,
            isCompleted: type == .taskList ? false : nil,
            createdAt: now,
            updatedAt: now
        )

        do {
            try dbManager.dbWriter.write { db in
                try db.execute(
                    sql: "UPDATE block SET sortOrder = sortOrder + 1 WHERE rootDocId = ? AND sortOrder >= ? AND id != ?",
                    arguments: [docId, newSortOrder, newBlock.id]
                )
                try newBlock.insert(db)
            }
            reloadBlocks()
            focusedBlockId = newBlock.id
            if !newBlock.content.isEmpty {
                syncLinksForBlock(newBlock)
            }
        } catch {
            print("Error creating block: \(error)")
        }
        return newBlock
    }

    public func updateBlockContent(id: String, content: String) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks[index].content = content
        blocks[index].updatedAt = Date()

        let blockToSave = blocks[index]
        do {
            try dbManager.dbWriter.write { db in
                try blockToSave.update(db)
            }
            syncLinksForBlock(blockToSave)
        } catch {
            print("Error updating block content: \(error)")
        }
    }

    // MARK: - Link Synchronization (LINKS_TO)
    public func syncLinksForBlock(_ block: Block) {
        let wikiLinks = LinkParser.extractWikiLinks(from: block.content)
        do {
            try dbManager.dbWriter.write { db in
                _ = try DocLink.filter(DocLink.Columns.sourceBlockId == block.id).deleteAll(db)
                for link in wikiLinks {
                    let target = link.target
                    // Match against document title or id (case-insensitive)
                    let matchedDoc = try Block.filter(
                        Block.Columns.type == BlockType.doc.rawValue &&
                        (Block.Columns.id == target || Block.Columns.content.like(target))
                    ).fetchOne(db)

                    let docLink = DocLink(
                        sourceDocId: block.rootDocId,
                        sourceBlockId: block.id,
                        targetTitle: target,
                        targetDocId: matchedDoc?.id
                    )
                    try docLink.insert(db)
                }
            }
            loadDocLinks()
        } catch {
            print("Error syncing links for block: \(error)")
        }
    }

    public func toggleTask(id: String) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        let current = blocks[index].isCompleted ?? false
        blocks[index].isCompleted = !current
        blocks[index].updatedAt = Date()

        let blockToSave = blocks[index]
        do {
            try dbManager.dbWriter.write { db in
                try blockToSave.update(db)
            }
        } catch {
            print("Error toggling task: \(error)")
        }
    }

    public func convertBlockType(id: String, to newType: BlockType) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks[index].type = newType
        if newType == .taskList && blocks[index].isCompleted == nil {
            blocks[index].isCompleted = false
        }
        blocks[index].updatedAt = Date()

        let blockToSave = blocks[index]
        do {
            try dbManager.dbWriter.write { db in
                try blockToSave.update(db)
            }
        } catch {
            print("Error converting block type: \(error)")
        }
    }

    public func setBlockRef(id: String, targetId: String) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks[index].type = .blockRef
        blocks[index].refTargetId = targetId
        blocks[index].updatedAt = Date()

        let blockToSave = blocks[index]
        do {
            try dbManager.dbWriter.write { db in
                try blockToSave.update(db)
            }
        } catch {
            print("Error setting block ref: \(error)")
        }
    }

    public func deleteBlock(id: String) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        let prevBlockId = index > 0 ? blocks[index - 1].id : nil

        blocks.remove(at: index)
        focusedBlockId = prevBlockId

        do {
            try dbManager.dbWriter.write { db in
                _ = try Block.filter(Block.Columns.id == id).deleteAll(db)
                _ = try DocLink.filter(DocLink.Columns.sourceBlockId == id).deleteAll(db)
            }
            loadDocLinks()
        } catch {
            print("Error deleting block: \(error)")
        }
    }

    public func indentBlock(id: String) {
        guard let index = blocks.firstIndex(where: { $0.id == id }), index > 0 else { return }
        let prevBlock = blocks[index - 1]
        blocks[index].parentId = prevBlock.id
        blocks[index].updatedAt = Date()

        let blockToSave = blocks[index]
        do {
            try dbManager.dbWriter.write { db in
                try blockToSave.update(db)
            }
        } catch {
            print("Error indenting block: \(error)")
        }
    }

    public func outdentBlock(id: String) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks[index].parentId = selectedDocId
        blocks[index].updatedAt = Date()

        let blockToSave = blocks[index]
        do {
            try dbManager.dbWriter.write { db in
                try blockToSave.update(db)
            }
        } catch {
            print("Error outdenting block: \(error)")
        }
    }

    public func moveBlock(id: String, direction: MoveDirection) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        let targetIndex: Int
        switch direction {
        case .up: targetIndex = index - 1
        case .down: targetIndex = index + 1
        }
        guard targetIndex >= 0 && targetIndex < blocks.count else { return }

        blocks.swapAt(index, targetIndex)
        for (i, _) in blocks.enumerated() {
            blocks[i].sortOrder = i
        }

        let updatedBlocks = blocks
        do {
            try dbManager.dbWriter.write { db in
                for b in updatedBlocks {
                    try b.update(db)
                }
            }
        } catch {
            print("Error moving block: \(error)")
        }
    }

    public func getBlock(id: String) -> Block? {
        if let local = blocks.first(where: { $0.id == id }) {
            return local
        }
        do {
            return try dbManager.dbWriter.read { db in
                try Block.fetchOne(db, key: id)
            }
        } catch {
            return nil
        }
    }

    // MARK: - Backlinks & Outline
    public func getBacklinks(for docId: String) -> [BacklinkItem] {
        guard let targetDoc = documents.first(where: { $0.id == docId }) ?? getBlock(id: docId) else { return [] }
        let targetTitle = targetDoc.content

        do {
            return try dbManager.dbWriter.read { db in
                var items: [BacklinkItem] = []
                var seenBlockIds: Set<String> = []

                // 1. Inbound WikiLinks from doc_link table (LINKS_TO)
                let links = try DocLink.filter(
                    DocLink.Columns.sourceDocId != docId &&
                    (DocLink.Columns.targetDocId == docId || DocLink.Columns.targetTitle == targetTitle)
                ).fetchAll(db)

                for link in links {
                    if let sourceBlock = try Block.fetchOne(db, key: link.sourceBlockId),
                       let sourceDoc = try Block.fetchOne(db, key: link.sourceDocId) {
                        seenBlockIds.insert(sourceBlock.id)
                        items.append(BacklinkItem(
                            block: sourceBlock,
                            sourceDocTitle: sourceDoc.content,
                            contextSnippet: sourceBlock.content,
                            linkType: .wikiLink,
                            isUnresolved: link.targetDocId == nil
                        ))
                    }
                }

                // 2. Inbound Block References / Transclusions
                let transSql = """
                SELECT b.*, d.content AS sourceDocTitle
                FROM block b
                JOIN block d ON d.id = b.rootDocId
                WHERE b.rootDocId != ?
                  AND (
                    b.refTargetId = ?
                    OR b.refTargetId IN (SELECT id FROM block WHERE rootDocId = ?)
                    OR b.content LIKE ?
                    OR b.content LIKE ?
                  )
                ORDER BY b.updatedAt DESC
                LIMIT 50;
                """
                let pattern1 = "%((\(docId)))%"
                let pattern2 = "%((b-%"
                let rows = try Row.fetchAll(db, sql: transSql, arguments: [docId, docId, docId, pattern1, pattern2])

                for row in rows {
                    guard let block = try? Block(row: row), !seenBlockIds.contains(block.id) else { continue }
                    let sourceDocTitle: String = row["sourceDocTitle"]
                    let context = block.content.isEmpty ? "Block Reference (\(block.type.displayName))" : block.content
                    items.append(BacklinkItem(
                        block: block,
                        sourceDocTitle: sourceDocTitle,
                        contextSnippet: context,
                        linkType: .blockRef,
                        isUnresolved: false
                    ))
                }

                // Strictly ensure no CONTAINS child document nodes appear in backlinks panel
                return items.filter { item in
                    !(item.block.type == .doc && item.block.parentId == docId)
                }
            }
        } catch {
            print("Error querying backlinks: \(error)")
            return []
        }
    }

    public func getOutline(for docId: String) -> [DocOutlineItem] {
        blocks.compactMap { block in
            guard block.isHeading else { return nil }
            let level = block.type == .heading1 ? 1 : (block.type == .heading2 ? 2 : 3)
            return DocOutlineItem(
                blockId: block.id,
                title: block.content.isEmpty ? "Untitled \(block.type.displayName)" : block.content,
                level: level,
                sortOrder: block.sortOrder
            )
        }
    }

    public func getGraphData() -> (nodes: [GraphNode], edges: [GraphEdge]) {
        do {
            return try dbManager.dbWriter.read { db in
                let docs = try Block.filter(Block.Columns.type == BlockType.doc.rawValue).fetchAll(db)
                var nodes: [GraphNode] = []
                for doc in docs {
                    let count = try Block.filter(Block.Columns.rootDocId == doc.id).fetchCount(db)
                    nodes.append(GraphNode(
                        id: doc.id,
                        title: doc.content.isEmpty ? "Untitled" : doc.content,
                        isCurrentDoc: doc.id == selectedDocId,
                        blockCount: count
                    ))
                }

                var edgeSet: Set<GraphEdge> = []

                // 1. Transclusion edges
                let refSql = """
                SELECT DISTINCT b.rootDocId AS sourceDocId, target.rootDocId AS targetDocId
                FROM block b
                JOIN block target ON target.id = b.refTargetId
                WHERE b.rootDocId != target.rootDocId;
                """
                let refRows = try Row.fetchAll(db, sql: refSql)
                for row in refRows {
                    let source: String = row["sourceDocId"]
                    let target: String = row["targetDocId"]
                    edgeSet.insert(GraphEdge(sourceId: source, targetId: target))
                }

                // 2. WikiLink edges from doc_link (LINKS_TO directed graph, cycles supported)
                let links = try DocLink.filter(DocLink.Columns.targetDocId != nil).fetchAll(db)
                for link in links {
                    guard let targetId = link.targetDocId, link.sourceDocId != targetId else { continue }
                    edgeSet.insert(GraphEdge(sourceId: link.sourceDocId, targetId: targetId))
                }

                return (nodes, Array(edgeSet))
            }
        } catch {
            return ([], [])
        }
    }

    // MARK: - Search
    public func search(query: String) -> [SearchResult] {
        searchService.search(query: query)
    }

    // MARK: - Export
    public func exportCurrentAsMarkdown() -> String {
        guard let doc = currentDoc else { return "" }
        return ExportService.exportToMarkdown(doc: doc, blocks: blocks)
    }

    public func exportCurrentAsJSON() -> String {
        guard let doc = currentDoc else { return "" }
        return (try? ExportService.exportToJSON(doc: doc, blocks: blocks)) ?? "{}"
    }

    // MARK: - Folder & Child Document Queries
    public func getChildDocuments(for docId: String) -> [Block] {
        documents.filter { $0.parentId == docId }.sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - Flashcards & FSRS Decks
    public var defaultNotesDeck: Deck? {
        decks.first(where: { $0.isNotesDefault }) ?? decks.first(where: { $0.id == Deck.notesDefaultId })
    }

    public var selectedDeck: Deck? {
        guard let id = selectedDeckId, id != "all" else { return nil }
        return decks.first(where: { $0.id == id })
    }

    public func loadDecks() {
        do {
            try dbManager.dbWriter.read { db in
                self.decks = try Deck.order(Deck.Columns.isNotesDefault.desc, Deck.Columns.createdAt.asc).fetchAll(db)
            }
        } catch {
            print("Error loading decks: \(error)")
        }
    }

    @discardableResult
    public func createDeck(
        name: String,
        description: String? = nil,
        colorHex: String = "#3B82F6",
        icon: String = "rectangle.stack"
    ) -> Deck {
        let deck = Deck(
            name: name.isEmpty ? "New Deck" : name,
            description: description,
            colorHex: colorHex,
            icon: icon,
            isNotesDefault: false
        )
        do {
            try dbManager.dbWriter.write { db in
                try deck.insert(db)
            }
            loadDecks()
            self.selectedDeckId = deck.id
        } catch {
            print("Error creating deck: \(error)")
        }
        return deck
    }

    public func updateDeck(_ deck: Deck) {
        do {
            try dbManager.dbWriter.write { db in
                try deck.update(db)
            }
            loadDecks()
        } catch {
            print("Error updating deck: \(error)")
        }
    }

    public func deleteDeck(id: String) {
        // Protect default notes deck
        guard let deck = decks.first(where: { $0.id == id }), !deck.isNotesDefault else { return }
        let fallbackDeckId = defaultNotesDeck?.id ?? Deck.notesDefaultId

        do {
            try dbManager.dbWriter.write { db in
                // Reassign cards in this deck to the default notes deck so cards are never lost
                try db.execute(
                    sql: "UPDATE flashcard SET deckId = ? WHERE deckId = ?",
                    arguments: [fallbackDeckId, id]
                )
                _ = try Deck.filter(Deck.Columns.id == id).deleteAll(db)
            }
            loadDecks()
            loadFlashcards()
            if selectedDeckId == id {
                selectedDeckId = fallbackDeckId
            }
        } catch {
            print("Error deleting deck: \(error)")
        }
    }

    public func flashcards(forDeck deckId: String?) -> [Flashcard] {
        guard let deckId = deckId, deckId != "all" else {
            return flashcards
        }
        if deckId == defaultNotesDeck?.id || deckId == Deck.notesDefaultId {
            // Group all flashcards generated from the notes section:
            // either deckId is explicitly the notes deck, or deckId is nil but docId is present
            return flashcards.filter { $0.deckId == deckId || ($0.deckId == nil && !$0.docId.isEmpty) }
        }
        return flashcards.filter { $0.deckId == deckId }
    }

    public func dueFlashcards(forDeck deckId: String?) -> [Flashcard] {
        flashcards(forDeck: deckId).filter { $0.isDue }
    }

    public struct NoteFlashcardGroup: Identifiable {
        public var id: String { doc.id }
        public let doc: Block
        public let cards: [Flashcard]
    }

    public func noteGroupedFlashcards() -> [NoteFlashcardGroup] {
        let notesCards = flashcards(forDeck: defaultNotesDeck?.id ?? Deck.notesDefaultId)
        let grouped = Dictionary(grouping: notesCards, by: { $0.docId })
        var result: [NoteFlashcardGroup] = []

        for doc in documents {
            if let cards = grouped[doc.id], !cards.isEmpty {
                result.append(NoteFlashcardGroup(doc: doc, cards: cards))
            }
        }
        // Also capture any cards with docs not found in documents list
        for (docId, cards) in grouped where !documents.contains(where: { $0.id == docId }) {
            let placeholder = Block(id: docId, rootDocId: docId, type: .doc, content: "Archived / Unlinked Folder")
            result.append(NoteFlashcardGroup(doc: placeholder, cards: cards))
        }
        return result
    }

    public var flashcardsForCurrentDoc: [Flashcard] {
        guard let docId = selectedDocId else { return [] }
        return flashcards.filter { $0.docId == docId }
    }

    public var dueFlashcards: [Flashcard] {
        flashcards.filter { $0.isDue }
    }

    public func loadFlashcards() {
        do {
            try dbManager.dbWriter.read { db in
                self.flashcards = try Flashcard.order(Flashcard.Columns.due).fetchAll(db)
            }
        } catch {
            print("Error loading flashcards: \(error)")
        }
    }

    @discardableResult
    public func createFlashcard(
        docId: String? = nil,
        deckId: String? = nil,
        front: String,
        back: String,
        sourceBlockId: String? = nil,
        hint: String? = nil
    ) -> Flashcard {
        let targetDocId = docId ?? selectedDocId ?? documents.first?.id ?? "b-doc-welcome"
        let nbId = documents.first(where: { $0.id == targetDocId })?.notebookId ?? selectedNotebookId ?? "nb-welcome-kb"

        // Determine target deck:
        // 1. Explicitly passed deckId
        // 2. Explicitly passed docId (note-associated card) -> routes to Notes & Documents deck
        // 3. Currently selected custom deck (if viewing in Flashcard Manager)
        // 4. Fallback to default notes deck
        let resolvedDeckId: String
        if let explicit = deckId, !explicit.isEmpty, explicit != "all" {
            resolvedDeckId = explicit
        } else if docId != nil {
            resolvedDeckId = defaultNotesDeck?.id ?? Deck.notesDefaultId
        } else if let activeDeck = selectedDeckId, !activeDeck.isEmpty, activeDeck != "all" {
            resolvedDeckId = activeDeck
        } else {
            resolvedDeckId = defaultNotesDeck?.id ?? Deck.notesDefaultId
        }

        let card = Flashcard(
            docId: targetDocId,
            notebookId: nbId,
            deckId: resolvedDeckId,
            front: front,
            back: back,
            sourceBlockId: sourceBlockId,
            hint: hint
        )
        do {
            try dbManager.dbWriter.write { db in
                try card.insert(db)
            }
            loadFlashcards()
        } catch {
            print("Error creating flashcard: \(error)")
        }
        return card
    }

    public func updateFlashcard(_ card: Flashcard) {
        do {
            try dbManager.dbWriter.write { db in
                try card.update(db)
            }
            loadFlashcards()
        } catch {
            print("Error updating flashcard: \(error)")
        }
    }

    public func deleteFlashcard(id: String) {
        do {
            try dbManager.dbWriter.write { db in
                _ = try Flashcard.filter(Flashcard.Columns.id == id).deleteAll(db)
                _ = try LocusFlashcard.filter(LocusFlashcard.Columns.flashcardId == id).deleteAll(db)
                try db.execute(sql: "UPDATE palace_locus SET flashcardId = NULL WHERE flashcardId = ?", arguments: [id])
            }
            loadFlashcards()
            loadLocusFlashcards()
            if let palId = selectedPalaceId {
                loadLoci(for: palId)
            }
        } catch {
            print("Error deleting flashcard: \(error)")
        }
    }

    @discardableResult
    public func rateFlashcard(id: String, rating: FSRSRating) -> FlashcardReviewResult? {
        guard let card = flashcards.first(where: { $0.id == id }) else { return nil }
        let result = FSRSScheduler.shared.review(card: card, rating: rating)
        updateFlashcard(result.card)
        return result
    }

    // MARK: - Memory Palace (Sequential Photos & Multi-Flashcard Anchors)
    public var selectedPalace: MemoryPalace? {
        memoryPalaces.first(where: { $0.id == selectedPalaceId })
    }

    public var activePhoto: PalacePhoto? {
        if let id = activePhotoId, let photo = palacePhotos.first(where: { $0.id == id }) {
            return photo
        }
        return palacePhotos.first
    }

    public func loadMemoryPalaces() {
        do {
            try dbManager.dbWriter.read { db in
                self.memoryPalaces = try MemoryPalace.order(MemoryPalace.Columns.sortOrder).fetchAll(db)
            }
            if selectedPalaceId == nil {
                selectedPalaceId = memoryPalaces.first?.id
            }
            if let currentId = selectedPalaceId {
                loadPalacePhotos(for: currentId)
                loadLoci(for: currentId)
            }
        } catch {
            print("Error loading memory palaces: \(error)")
        }
    }

    public func selectPalace(id: String?) {
        selectedPalaceId = id
        if let id = id {
            loadPalacePhotos(for: id)
            loadLoci(for: id)
            loadLocusFlashcards()
        } else {
            palacePhotos = []
            activePhotoId = nil
            loci = []
        }
    }

    public func loadPalacePhotos(for palaceId: String) {
        do {
            try dbManager.dbWriter.read { db in
                self.palacePhotos = try PalacePhoto.filter(PalacePhoto.Columns.palaceId == palaceId)
                    .order(PalacePhoto.Columns.orderIndex)
                    .fetchAll(db)
            }
            if activePhotoId == nil || !palacePhotos.contains(where: { $0.id == activePhotoId }) {
                activePhotoId = palacePhotos.first?.id
            }
        } catch {
            print("Error loading palace photos: \(error)")
        }
    }

    public func selectPhoto(id: String?) {
        self.activePhotoId = id
    }

    @discardableResult
    public func addPalacePhoto(
        palaceId: String,
        name: String,
        imagePath: String,
        imageData: String? = nil,
        canvasX: Double? = nil,
        canvasY: Double? = nil,
        canvasWidth: Double = 420.0,
        canvasHeight: Double = 280.0
    ) -> PalacePhoto {
        let order = palacePhotos.count
        let defaultX = Double(order) * 500.0 + 80.0
        let defaultY = 120.0
        let photo = PalacePhoto(
            palaceId: palaceId,
            name: name.isEmpty ? "Scene \(order + 1)" : name,
            imagePath: imagePath,
            imageData: imageData,
            orderIndex: order,
            canvasX: canvasX ?? defaultX,
            canvasY: canvasY ?? defaultY,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        )
        do {
            try dbManager.dbWriter.write { db in
                try photo.insert(db)
            }
            loadPalacePhotos(for: palaceId)
            activePhotoId = photo.id
        } catch {
            print("Error adding palace photo: \(error)")
        }
        return photo
    }

    public func updatePhotoPosition(id: String, x: Double, y: Double) {
        if let idx = palacePhotos.firstIndex(where: { $0.id == id }) {
            palacePhotos[idx].canvasX = x
            palacePhotos[idx].canvasY = y
        }
        do {
            try dbManager.dbWriter.write { db in
                try db.execute(sql: "UPDATE palace_photo SET canvasX = ?, canvasY = ? WHERE id = ?", arguments: [x, y, id])
            }
        } catch {
            print("Error updating photo position: \(error)")
        }
    }

    public func updatePhotoDimensions(id: String, width: Double, height: Double) {
        if let idx = palacePhotos.firstIndex(where: { $0.id == id }) {
            palacePhotos[idx].canvasWidth = width
            palacePhotos[idx].canvasHeight = height
        }
        do {
            try dbManager.dbWriter.write { db in
                try db.execute(sql: "UPDATE palace_photo SET canvasWidth = ?, canvasHeight = ? WHERE id = ?", arguments: [width, height, id])
            }
        } catch {
            print("Error updating photo dimensions: \(error)")
        }
    }

    public func updatePalacePhoto(_ photo: PalacePhoto) {
        do {
            try dbManager.dbWriter.write { db in
                try photo.update(db)
            }
            loadPalacePhotos(for: photo.palaceId)
        } catch {
            print("Error updating palace photo: \(error)")
        }
    }

    public func deletePalacePhoto(id: String) {
        guard let palaceId = selectedPalaceId else { return }
        do {
            try dbManager.dbWriter.write { db in
                let deletedLoci = try PalaceLocus.filter(PalaceLocus.Columns.photoId == id).fetchAll(db)
                for locus in deletedLoci {
                    _ = try LocusFlashcard.filter(LocusFlashcard.Columns.locusId == locus.id).deleteAll(db)
                }
                _ = try PalaceLocus.filter(PalaceLocus.Columns.photoId == id).deleteAll(db)
                _ = try PalacePhoto.filter(PalacePhoto.Columns.id == id).deleteAll(db)
            }
            loadPalacePhotos(for: palaceId)
            loadLoci(for: palaceId)
            loadLocusFlashcards()
        } catch {
            print("Error deleting palace photo: \(error)")
        }
    }

    public func reorderPalacePhotos(palaceId: String, photoIds: [String]) {
        do {
            try dbManager.dbWriter.write { db in
                for (index, id) in photoIds.enumerated() {
                    try db.execute(sql: "UPDATE palace_photo SET orderIndex = ? WHERE id = ?", arguments: [index, id])
                }
            }
            loadPalacePhotos(for: palaceId)
        } catch {
            print("Error reordering palace photos: \(error)")
        }
    }

    public func loadLoci(for palaceId: String) {
        do {
            try dbManager.dbWriter.read { db in
                self.loci = try PalaceLocus.filter(PalaceLocus.Columns.palaceId == palaceId)
                    .order(PalaceLocus.Columns.orderIndex)
                    .fetchAll(db)
            }
        } catch {
            print("Error loading loci: \(error)")
        }
    }

    @discardableResult
    public func createMemoryPalace(
        name: String,
        imagePath: String,
        imageData: String? = nil,
        description: String? = nil
    ) -> MemoryPalace {
        let palace = MemoryPalace(
            name: name.isEmpty ? "Untitled Palace" : name,
            imagePath: imagePath,
            imageData: imageData,
            description: description,
            sortOrder: memoryPalaces.count
        )
        let initialPhoto = PalacePhoto(
            palaceId: palace.id,
            name: "1. Main Hall",
            imagePath: imagePath,
            imageData: imageData,
            orderIndex: 0,
            canvasX: 80.0,
            canvasY: 120.0,
            canvasWidth: 420.0,
            canvasHeight: 280.0
        )
        do {
            try dbManager.dbWriter.write { db in
                try palace.insert(db)
                try initialPhoto.insert(db)
            }
            loadMemoryPalaces()
            selectPalace(id: palace.id)
            activePhotoId = initialPhoto.id
        } catch {
            print("Error creating memory palace: \(error)")
        }
        return palace
    }

    public func deleteMemoryPalace(id: String) {
        do {
            try dbManager.dbWriter.write { db in
                let lociToDelete = try PalaceLocus.filter(PalaceLocus.Columns.palaceId == id).fetchAll(db)
                for locus in lociToDelete {
                    _ = try LocusFlashcard.filter(LocusFlashcard.Columns.locusId == locus.id).deleteAll(db)
                }
                _ = try PalaceLocus.filter(PalaceLocus.Columns.palaceId == id).deleteAll(db)
                _ = try PalacePhoto.filter(PalacePhoto.Columns.palaceId == id).deleteAll(db)
                _ = try MemoryPalace.filter(MemoryPalace.Columns.id == id).deleteAll(db)
            }
            loadMemoryPalaces()
            loadLocusFlashcards()
            if selectedPalaceId == id {
                selectPalace(id: memoryPalaces.first?.id)
            }
        } catch {
            print("Error deleting memory palace: \(error)")
        }
    }

    // MARK: - Multi-Flashcards & Direct Anchors per Locus
    public func loadLocusFlashcards() {
        do {
            try dbManager.dbWriter.read { db in
                self.locusFlashcards = try LocusFlashcard.order(LocusFlashcard.Columns.sortOrder).fetchAll(db)
            }
        } catch {
            print("Error loading locus flashcards: \(error)")
        }
    }

    public func getFlashcards(for locusId: String) -> [Flashcard] {
        let links = locusFlashcards.filter { $0.locusId == locusId }.sorted(by: { $0.sortOrder < $1.sortOrder })
        var results: [Flashcard] = []
        for link in links {
            if let card = flashcards.first(where: { $0.id == link.flashcardId }) {
                results.append(card)
            }
        }
        // Fallback: If no links in locusFlashcards, check direct locus.flashcardId
        if results.isEmpty, let locus = loci.first(where: { $0.id == locusId }), let fcId = locus.flashcardId, !fcId.isEmpty {
            if let card = flashcards.first(where: { $0.id == fcId }) {
                results.append(card)
            }
        }
        return results
    }

    public func attachFlashcard(locusId: String, flashcardId: String) {
        guard !locusFlashcards.contains(where: { $0.locusId == locusId && $0.flashcardId == flashcardId }) else { return }
        let currentCount = locusFlashcards.filter { $0.locusId == locusId }.count
        let link = LocusFlashcard(locusId: locusId, flashcardId: flashcardId, sortOrder: currentCount)
        do {
            try dbManager.dbWriter.write { db in
                try link.insert(db)
                try db.execute(sql: "UPDATE palace_locus SET flashcardId = ? WHERE id = ? AND (flashcardId IS NULL OR flashcardId = '')", arguments: [flashcardId, locusId])
            }
            loadLocusFlashcards()
            if let palaceId = selectedPalaceId {
                loadLoci(for: palaceId)
            }
        } catch {
            print("Error attaching flashcard: \(error)")
        }
    }

    public func detachFlashcard(locusId: String, flashcardId: String) {
        do {
            try dbManager.dbWriter.write { db in
                _ = try LocusFlashcard.filter(LocusFlashcard.Columns.locusId == locusId && LocusFlashcard.Columns.flashcardId == flashcardId).deleteAll(db)
                let remaining = try LocusFlashcard.filter(LocusFlashcard.Columns.locusId == locusId).order(LocusFlashcard.Columns.sortOrder).fetchAll(db)
                let nextPrimary = remaining.first?.flashcardId
                try db.execute(sql: "UPDATE palace_locus SET flashcardId = ? WHERE id = ?", arguments: [nextPrimary, locusId])
            }
            loadLocusFlashcards()
            if let palaceId = selectedPalaceId {
                loadLoci(for: palaceId)
            }
        } catch {
            print("Error detaching flashcard: \(error)")
        }
    }

    @discardableResult
    public func createAndAttachFlashcard(
        locusId: String,
        front: String,
        back: String,
        hint: String? = nil
    ) -> Flashcard {
        let locus = loci.first(where: { $0.id == locusId })
        let card = createFlashcard(
            docId: locus?.docId ?? selectedDocId,
            front: front,
            back: back,
            hint: hint
        )
        attachFlashcard(locusId: locusId, flashcardId: card.id)
        return card
    }

    @discardableResult
    public func addLocus(
        palaceId: String,
        photoId: String? = nil,
        flashcardId: String? = nil,
        docId: String? = nil,
        title: String,
        mnemonic: String? = nil,
        anchoredInfo: String? = nil,
        x: Double,
        y: Double
    ) -> PalaceLocus {
        let count = loci.count
        let resolvedPhotoId = photoId ?? activePhotoId ?? palacePhotos.first?.id
        let locus = PalaceLocus(
            palaceId: palaceId,
            photoId: resolvedPhotoId,
            flashcardId: flashcardId,
            docId: docId ?? selectedDocId,
            title: title.isEmpty ? "Locus \(count + 1)" : title,
            mnemonic: mnemonic,
            anchoredInfo: anchoredInfo,
            normalizedX: min(1.0, max(0.0, x)),
            normalizedY: min(1.0, max(0.0, y)),
            orderIndex: count
        )
        do {
            try dbManager.dbWriter.write { db in
                try locus.insert(db)
                if let fcId = flashcardId, !fcId.isEmpty {
                    let link = LocusFlashcard(locusId: locus.id, flashcardId: fcId, sortOrder: 0)
                    try link.insert(db)
                }
            }
            loadLoci(for: palaceId)
            loadLocusFlashcards()
        } catch {
            print("Error adding locus: \(error)")
        }
        return locus
    }

    public func updateLocus(_ locus: PalaceLocus) {
        do {
            try dbManager.dbWriter.write { db in
                try locus.update(db)
            }
            loadLoci(for: locus.palaceId)
        } catch {
            print("Error updating locus: \(error)")
        }
    }

    public func deleteLocus(id: String) {
        guard let palaceId = selectedPalaceId else { return }
        do {
            try dbManager.dbWriter.write { db in
                _ = try LocusFlashcard.filter(LocusFlashcard.Columns.locusId == id).deleteAll(db)
                _ = try PalaceLocus.filter(PalaceLocus.Columns.id == id).deleteAll(db)
            }
            loadLoci(for: palaceId)
            loadLocusFlashcards()
        } catch {
            print("Error deleting locus: \(error)")
        }
    }
}
