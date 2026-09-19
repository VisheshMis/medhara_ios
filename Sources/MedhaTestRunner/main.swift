import Foundation
import MedhaKit
import GRDB

@main
struct TestRunner {
    @MainActor
    static func main() async throws {
        print("🚀 Starting Medha test suite...")

        let db = DatabaseManager(inMemory: true)
        let store = BlockStore(dbManager: db)

        // 1. Initial seed test
        assert(store.notebooks.count >= 2, "Failed: Seeded notebooks")
        assert(store.documents.count >= 1, "Failed: Seeded documents")
        assert(store.currentDoc != nil, "Failed: Current document")
        assert(store.blocks.count > 0, "Failed: Document blocks")
        print("✅ testDatabaseInitializationAndSeeding passed")

        // 2. Block CRUD test
        let h1 = store.createBlock(type: .heading1, content: "Dynamic Heading")
        assert(h1.type == .heading1, "Failed: createBlock type")
        assert(h1.content == "Dynamic Heading", "Failed: createBlock content")
        assert(store.blocks.contains(where: { $0.id == h1.id }), "Failed: block in store")

        store.updateBlockContent(id: h1.id, content: "Updated Dynamic Heading")
        assert(store.blocks.first(where: { $0.id == h1.id })?.content == "Updated Dynamic Heading", "Failed: updateBlockContent")

        store.convertBlockType(id: h1.id, to: .callout)
        assert(store.blocks.first(where: { $0.id == h1.id })?.type == .callout, "Failed: convertBlockType")

        store.deleteBlock(id: h1.id)
        assert(!store.blocks.contains(where: { $0.id == h1.id }), "Failed: deleteBlock")
        print("✅ testBlockCRUDOperations passed")

        // 3. Task toggle test
        let task = store.createBlock(type: .taskList, content: "Complete Block PKM")
        assert(task.isCompleted == false, "Failed: task initial state")
        store.toggleTask(id: task.id)
        assert(store.blocks.first(where: { $0.id == task.id })?.isCompleted == true, "Failed: task completed")
        store.toggleTask(id: task.id)
        assert(store.blocks.first(where: { $0.id == task.id })?.isCompleted == false, "Failed: task uncompleted")
        print("✅ testTaskBlockToggle passed")

        // 4. FTS5 full text search test
        let uniqueWord = "GalacticNebula\(Int.random(in: 1000...9999))"
        _ = store.createBlock(type: .paragraph, content: "Searching for \(uniqueWord) in SQLite FTS5 index")

        let searchResults = store.search(query: uniqueWord)
        assert(searchResults.count == 1, "Failed: FTS5 search count")
        assert(searchResults.first?.blockType == .paragraph, "Failed: FTS5 result blockType")
        print("✅ testFTS5Search passed")

        // 5. Block references and backlinks test
        let docA = store.createDocument(title: "Architecture Guide")
        let blockInA = store.createBlock(type: .callout, content: "System invariant")
        let docB = store.createDocument(title: "Design Notes")
        let refBlock = store.createBlock(type: .blockRef, content: "", parentId: docB.id)
        store.setBlockRef(id: refBlock.id, targetId: blockInA.id)

        let backlinks = store.getBacklinks(for: docA.id)
        print("Backlinks found for docA: \(backlinks.count)")
        for b in backlinks {
            print(" -> backlink: sourceDoc=\(b.sourceDocTitle), blockId=\(b.block.id), refTargetId=\(b.block.refTargetId ?? "nil")")
        }
        assert(backlinks.contains(where: { $0.sourceDocTitle == "Design Notes" }), "Failed: Backlinks query")
        print("✅ testBlockReferencesAndBacklinks passed")

        // 6. Outline generation test
        let outlineDoc = store.createDocument(title: "TOC Document")
        _ = store.createBlock(type: .heading1, content: "Chapter 1")
        _ = store.createBlock(type: .heading2, content: "Section 1.1")
        _ = store.createBlock(type: .heading3, content: "Detail 1.1.1")
        let outline = store.getOutline(for: outlineDoc.id)
        assert(outline.count == 3, "Failed: Outline item count")
        assert(outline[0].title == "Chapter 1" && outline[0].level == 1, "Failed: Outline H1")
        assert(outline[1].title == "Section 1.1" && outline[1].level == 2, "Failed: Outline H2")
        assert(outline[2].title == "Detail 1.1.1" && outline[2].level == 3, "Failed: Outline H3")
        print("✅ testOutlineGeneration passed")

        // 7. Markdown export & import test
        _ = store.createDocument(title: "Export Title")
        _ = store.createBlock(type: .heading1, content: "Export Title")
        _ = store.createBlock(type: .paragraph, content: "Paragraph text")
        _ = store.createBlock(type: .bulletList, content: "Bullet item")
        let md = store.exportCurrentAsMarkdown()
        assert(md.contains("# Export Title"), "Failed: Markdown export title")
        assert(md.contains("Paragraph text"), "Failed: Markdown export paragraph")
        assert(md.contains("- Bullet item"), "Failed: Markdown export bullet")

        let imported = ExportService.importMarkdown(text: md, title: "Reimported", notebookId: "nb-test")
        assert(imported.doc.content == "Reimported", "Failed: Markdown import doc title")
        assert(imported.blocks.count >= 3, "Failed: Markdown import blocks count")
        // 8. Document Hierarchy & Sub-Notes Tree test
        let rootDoc = store.createDocument(title: "Master Project")
        let subNote1 = store.createDocument(title: "Milestone 1", parentDocId: rootDoc.id)
        let subNote2 = store.createDocument(title: "Sprint 1.1 Tasks", parentDocId: subNote1.id)

        assert(store.isDocExpanded(id: rootDoc.id), "Failed: Parent doc auto-expanded on sub-note creation")
        assert(store.isDocExpanded(id: subNote1.id), "Failed: Sub-note 1 auto-expanded on sub-note creation")

        let docTree = store.getDocTree()
        guard let rootNode = docTree.first(where: { $0.doc.id == rootDoc.id }) else {
            fatalError("Failed: Root doc not found in docTree")
        }
        assert(rootNode.level == 0, "Failed: Root doc level")
        assert(rootNode.children.count == 1, "Failed: Root doc children count")
        let child1Node = rootNode.children[0]
        assert(child1Node.doc.id == subNote1.id, "Failed: Child 1 id")
        assert(child1Node.level == 1, "Failed: Child 1 level")
        assert(child1Node.children.count == 1, "Failed: Child 1 children count")
        let child2Node = child1Node.children[0]
        assert(child2Node.doc.id == subNote2.id, "Failed: Child 2 id")
        assert(child2Node.level == 2, "Failed: Child 2 level")
        print("✅ testDocumentHierarchyAndTree passed")

        // 9. Document Ancestry Breadcrumbs test
        let ancestry = store.getDocAncestry(for: subNote2.id)
        assert(ancestry.count == 3, "Failed: Ancestry count should be 3")
        assert(ancestry[0].id == rootDoc.id, "Failed: Ancestry root")
        assert(ancestry[1].id == subNote1.id, "Failed: Ancestry parent")
        assert(ancestry[2].id == subNote2.id, "Failed: Ancestry leaf")
        print("✅ testDocumentAncestryBreadcrumbs passed")

        // 10. Tree Expansion Toggle & Filter test
        store.collapseDoc(id: rootDoc.id)
        let flatCollapsed = store.getFlattenedDocTree()
        assert(!flatCollapsed.contains(where: { $0.doc.id == subNote1.id }), "Failed: Collapsed parent should hide children in flattened tree")
        assert(!flatCollapsed.contains(where: { $0.doc.id == subNote2.id }), "Failed: Collapsed parent should hide grandchildren in flattened tree")

        store.expandDoc(id: rootDoc.id)
        let flatExpanded = store.getFlattenedDocTree()
        assert(flatExpanded.contains(where: { $0.doc.id == subNote1.id }), "Failed: Expanded parent should show children in flattened tree")

        let filtered = store.getFilteredDocTree(filter: "Sprint 1.1")
        assert(filtered.contains(where: { $0.doc.id == subNote2.id }), "Failed: Filtered tree should find matching sub-note")
        print("✅ testTreeExpansionAndFilter passed")

        // 11. Recursive Cascade Deletion test
        _ = store.createBlock(type: .paragraph, content: "Task block inside grandchild", parentId: subNote2.id)
        store.deleteDocument(docId: rootDoc.id)
        assert(!store.documents.contains(where: { $0.id == rootDoc.id }), "Failed: Root doc should be deleted")
        assert(!store.documents.contains(where: { $0.id == subNote1.id }), "Failed: Sub-note 1 should be cascade deleted")
        assert(!store.documents.contains(where: { $0.id == subNote2.id }), "Failed: Sub-note 2 should be cascade deleted")
        print("✅ testRecursiveCascadeDeletion passed")

        // 12. Disk Database & Seeded Hierarchy test
        let diskDb = DatabaseManager(inMemory: false)
        let diskStore = BlockStore(dbManager: diskDb)
        assert(diskStore.documents.count >= 4, "Failed: Disk documents count >= 4")
        let subAtomic = diskStore.documents.first(where: { $0.id == "b-doc-sub-atomic" })
        assert(subAtomic != nil, "Failed: Seeded sub-note 'b-doc-sub-atomic' must exist")
        assert(subAtomic?.parentId == "b-doc-welcome", "Failed: Seeded sub-note parentId must be 'b-doc-welcome'")
        let subSprint = diskStore.documents.first(where: { $0.id == "b-doc-sub-sprint1" })
        assert(subSprint != nil, "Failed: Seeded sub-note 'b-doc-sub-sprint1' must exist")
        assert(subSprint?.parentId == "b-doc-roadmap", "Failed: Seeded sub-note parentId must be 'b-doc-roadmap'")
        print("✅ testDiskDatabaseAndSeededHierarchy passed")

        // 13. Focus Timer State Machine & Exact Cycle test
        let timer = store.timerManager
        timer.reset()
        assert(timer.currentPhase == .focus, "Failed: Timer initial phase should be focus")
        assert(timer.remainingSeconds == 600, "Failed: Focus initial duration should be 600s (10m)")
        assert(timer.formattedTime == "10:00", "Failed: Focus formatted time should be 10:00")

        // Fast forward Focus phase to 1 second remaining
        timer.remainingSeconds = 1
        timer.tick() // triggers phase completion
        assert(timer.currentPhase == .beepAndPause, "Failed: After 10m, phase must transition to beepAndPause")
        assert(timer.remainingSeconds == 2, "Failed: Pause phase duration must be 2 seconds")
        assert(timer.formattedTime == "00:02", "Failed: Pause formatted time should be 00:02")

        // Fast forward Beep & Pause to 1 second remaining
        timer.remainingSeconds = 1
        timer.tick()
        assert(timer.currentPhase == .microBreak, "Failed: After pause, phase must transition to microBreak")
        assert(timer.remainingSeconds == 30, "Failed: Micro-break duration must be 30 seconds")
        assert(timer.formattedTime == "00:30", "Failed: Micro-break formatted time should be 00:30")

        // Fast forward Micro-Break to 1 second remaining
        timer.remainingSeconds = 1
        timer.tick()
        assert(timer.currentPhase == .resetInterval, "Failed: After micro-break, phase must transition to resetInterval")
        assert(timer.remainingSeconds == 10, "Failed: Reset interval duration must be 10 seconds")
        assert(timer.formattedTime == "00:10", "Failed: Reset interval formatted time should be 00:10")

        // Fast forward Cycle Reset to 1 second remaining -> restarts from 10 minutes
        timer.remainingSeconds = 1
        timer.tick()
        assert(timer.currentPhase == .focus, "Failed: After reset interval, cycle must repeat to focus")
        assert(timer.remainingSeconds == 600, "Failed: Repeated focus phase must restart at 600 seconds")
        assert(timer.cycleCount == 1, "Failed: Cycle count should increment to 1")

        // Test controls
        timer.toggleMute()
        assert(timer.isMuted == true, "Failed: toggleMute")
        timer.toggleMute()
        assert(timer.isMuted == false, "Failed: toggleMute back")
        timer.skipToNextPhase()
        assert(timer.currentPhase == .beepAndPause, "Failed: skipToNextPhase")
        timer.reset()
        assert(timer.currentPhase == .focus && timer.remainingSeconds == 600, "Failed: timer reset")
        print("✅ testFocusTimerStateCycle passed")

        // 14. FSRS v4.5 Algorithm & Review Calculations test
        let fsrs = FSRSScheduler.shared
        let dummyCard = Flashcard(
            docId: "doc-test",
            notebookId: "nb-test",
            front: "What is FSRS?",
            back: "Free Spaced Repetition Scheduler"
        )
        assert(dummyCard.fsrsState == .newCard, "Failed: Initial card state should be newCard")
        assert(dummyCard.reps == 0, "Failed: Initial reps should be 0")

        // Rating New Card: Again
        let againResult = fsrs.review(card: dummyCard, rating: .again)
        assert(againResult.newState == .learning, "Failed: Again on new card should set state to learning")
        assert(againResult.newStability > 0, "Failed: Again stability > 0")
        assert(againResult.card.lapses == 1, "Failed: Lapses should increment on Again")
        assert(againResult.card.reps == 1, "Failed: Reps should increment to 1")

        // Rating New Card: Good
        let goodResult = fsrs.review(card: dummyCard, rating: .good)
        assert(goodResult.newState == .review, "Failed: Good on new card should set state to review")
        assert(goodResult.newStability >= 2.0, "Failed: Good stability should be >= 2.0")
        assert(goodResult.intervalDays >= 1, "Failed: Good interval should be >= 1 day")
        assert(goodResult.card.lapses == 0, "Failed: Good should not lapse")

        // Rating New Card: Easy
        let easyResult = fsrs.review(card: dummyCard, rating: .easy)
        assert(easyResult.newState == .review, "Failed: Easy on new card should set state to review")
        assert(easyResult.newStability > goodResult.newStability, "Failed: Easy stability must be higher than Good")
        assert(easyResult.intervalDays >= goodResult.intervalDays, "Failed: Easy interval >= Good interval")

        // Subsequent Review (Retention recall)
        let reviewCard = goodResult.card
        let subsequentGood = fsrs.review(card: reviewCard, rating: .good, reviewDate: Date().addingTimeInterval(86400 * Double(goodResult.intervalDays)))
        assert(subsequentGood.newStability > reviewCard.stability, "Failed: Successful recall should increase stability")
        assert(subsequentGood.card.reps == 2, "Failed: Reps should now be 2")

        // Subsequent Lapse (Forget)
        let lapsed = fsrs.review(card: subsequentGood.card, rating: .again, reviewDate: Date().addingTimeInterval(86400 * 10))
        assert(lapsed.newState == .relearning, "Failed: Lapsing card should set state to relearning")
        assert(lapsed.card.lapses == 1, "Failed: Card lapses should be 1")

        // Interval preview check
        let previews = fsrs.previewIntervals(card: dummyCard)
        assert(previews.count == 4, "Failed: Previews must have 4 ratings")
        assert(previews[.again]! <= previews[.hard]!, "Failed: Again interval <= Hard")
        assert(previews[.hard]! <= previews[.good]!, "Failed: Hard interval <= Good")
        assert(previews[.good]! <= previews[.easy]!, "Failed: Good interval <= Easy")
        print("✅ testFSRSScheduler passed")

        // 15. Flashcards in Document/Folder Hierarchy & Global Store test
        let folderParent = store.createDocument(title: "Biology 101")
        let folderChild = store.createDocument(title: "Cell Organelles", parentDocId: folderParent.id)

        // Add flashcards directly attached to the folders
        let card1 = store.createFlashcard(
            docId: folderParent.id,
            front: "What is Biology?",
            back: "The study of living organisms"
        )
        let card2 = store.createFlashcard(
            docId: folderChild.id,
            front: "What is the powerhouse of the cell?",
            back: "Mitochondria",
            hint: "ATP synthesis"
        )

        assert(store.flashcards.contains(where: { $0.id == card1.id }), "Failed: Card 1 in global deck")
        assert(store.flashcards.contains(where: { $0.id == card2.id }), "Failed: Card 2 in global deck")

        // Select parent folder: only card1 should appear in doc-level query
        store.selectDocument(id: folderParent.id)
        assert(store.flashcardsForCurrentDoc.count == 1, "Failed: Parent folder should have 1 attached card")
        assert(store.flashcardsForCurrentDoc.first?.id == card1.id, "Failed: Attached card id matches card1")

        // Select subfolder: only card2 should appear
        store.selectDocument(id: folderChild.id)
        assert(store.flashcardsForCurrentDoc.count == 1, "Failed: Child folder should have 1 attached card")
        assert(store.flashcardsForCurrentDoc.first?.id == card2.id, "Failed: Attached card id matches card2")

        // Rate flashcard through store
        let ratedResult = store.rateFlashcard(id: card2.id, rating: .good)
        assert(ratedResult != nil, "Failed: rateFlashcard result returned")
        assert(store.flashcards.first(where: { $0.id == card2.id })?.reps == 1, "Failed: Reps updated in store")
        assert(store.flashcards.first(where: { $0.id == card2.id })?.stability ?? 0 > 0, "Failed: Stability updated in store")

        // Cascade delete parent folder: both card1 and card2 (child folder card) must be cascade deleted
        store.deleteDocument(docId: folderParent.id)
        assert(!store.flashcards.contains(where: { $0.id == card1.id }), "Failed: Card 1 should be cascade deleted with parent folder")
        assert(!store.flashcards.contains(where: { $0.id == card2.id }), "Failed: Card 2 should be cascade deleted with child folder")
        print("✅ testFlashcardsInHierarchyAndStore passed")

        // 16. 2D Memory Palace & Loci Pinning test
        assert(store.memoryPalaces.count >= 1, "Failed: At least 1 seeded memory palace")
        let seededPalace = store.memoryPalaces.first!
        store.selectPalace(id: seededPalace.id)
        assert(store.loci.count >= 3, "Failed: Seeded palace should have at least 3 loci")

        // Create a custom 2D memory palace
        let customPalace = store.createMemoryPalace(
            name: "Grand Library",
            imagePath: "blueprint://library",
            description: "2D spatial memory palace of library"
        )
        assert(store.memoryPalaces.contains(where: { $0.id == customPalace.id }), "Failed: Custom palace in store")
        assert(store.selectedPalaceId == customPalace.id, "Failed: Custom palace selected")
        assert(store.loci.isEmpty, "Failed: New palace loci should be empty initially")

        // Create a flashcard to link with locus
        let pkmDoc = store.createDocument(title: "Ancient History")
        let pkmCard = store.createFlashcard(docId: pkmDoc.id, front: "Socrates", back: "Greek Philosopher")

        // Add 2D loci with normalized coordinates
        let locus1 = store.addLocus(
            palaceId: customPalace.id,
            flashcardId: pkmCard.id,
            docId: pkmDoc.id,
            title: "Entrance Fountain",
            mnemonic: "Imagine Socrates drinking water from the fountain",
            x: 0.15,
            y: 0.25
        )
        let locus2 = store.addLocus(
            palaceId: customPalace.id,
            flashcardId: nil,
            docId: pkmDoc.id,
            title: "Grand Bookshelf",
            mnemonic: "Piles of scrolls stacked to the ceiling",
            x: 0.85,
            y: 0.70
        )

        assert(store.loci.count == 2, "Failed: Palace should have 2 loci")
        assert(locus2.title == "Grand Bookshelf", "Failed: Locus 2 title")
        assert(store.loci[0].normalizedX == 0.15 && store.loci[0].normalizedY == 0.25, "Failed: Locus 1 normalized coordinates")
        assert(store.loci[0].flashcardId == pkmCard.id, "Failed: Locus 1 linked to flashcard")
        assert(store.loci[1].normalizedX == 0.85 && store.loci[1].normalizedY == 0.70, "Failed: Locus 2 normalized coordinates")

        // Coordinate clamping test
        let clampedLocus = store.addLocus(
            palaceId: customPalace.id,
            title: "Out of Bounds Pin",
            x: 1.5,
            y: -0.5
        )
        assert(clampedLocus.normalizedX == 1.0, "Failed: Normalized X clamped to 1.0")
        assert(clampedLocus.normalizedY == 0.0, "Failed: Normalized Y clamped to 0.0")

        // Update locus mnemonic
        var locusToEdit = locus1
        locusToEdit.mnemonic = "Updated vivid visual mnemonic"
        store.updateLocus(locusToEdit)
        assert(store.loci.first(where: { $0.id == locus1.id })?.mnemonic == "Updated vivid visual mnemonic", "Failed: Update locus mnemonic")

        // Delete palace cascade test
        store.deleteMemoryPalace(id: customPalace.id)
        assert(!store.memoryPalaces.contains(where: { $0.id == customPalace.id }), "Failed: Palace deleted")
        print("✅ testMemoryPalaceAnd2DLoci passed")

        // 17. CONSTRAINT: LINKS ARE NOT HIERARCHY
        // Invariant 1: Writing [[B]] inside node A MUST NOT reparent B or alter position in tree
        let folderRootF = store.createDocument(title: "Folder F")
        let nodeB = store.createDocument(title: "Doc B", parentDocId: folderRootF.id)
        let nodeA = store.createDocument(title: "Doc A")

        assert(nodeB.parentId == folderRootF.id, "Precondition: Doc B is child of Folder F")
        assert(nodeA.parentId == nil, "Precondition: Doc A is at root")

        // Write [[Doc B]] inside Doc A
        store.selectDocument(id: nodeA.id)
        _ = store.createBlock(type: .paragraph, content: "Check out [[Doc B]] for details.")

        // Verify B's parent is completely unchanged in both store and database
        let bAfterLink = store.documents.first(where: { $0.id == nodeB.id })
        assert(bAfterLink?.parentId == folderRootF.id, "Constraint 1 Failed: B's parent was altered by [[B]] link!")
        assert(bAfterLink?.parentId != nodeA.id, "Constraint 1 Failed: B became child of A!")

        // Verify tree has B under F, and A has 0 tree children
        let docTreeSnapshot = store.getDocTree()
        let aNodeInTree = docTreeSnapshot.first(where: { $0.doc.id == nodeA.id })
        assert(aNodeInTree?.children.isEmpty == true, "Constraint 1 Failed: A has children in tree after linking to B")
        let fNodeInTree = docTreeSnapshot.first(where: { $0.doc.id == folderRootF.id })
        assert(fNodeInTree?.children.contains(where: { $0.doc.id == nodeB.id }) == true, "Constraint 1 Failed: B disappeared from F's children in tree")

        // Verify directed graph edge A -> B exists
        let graphAfterLink = store.getGraphData()
        assert(graphAfterLink.edges.contains(where: { $0.sourceId == nodeA.id && $0.targetId == nodeB.id }), "Constraint 1 Failed: LINKS_TO edge A->B not found in graph")

        // Invariant 2: Creating a node via an unresolved link ([[C]]) places C at default/inbox, NOT under A
        _ = store.createBlock(type: .paragraph, content: "Explaining [[Quantum Physics Concept]]")
        let unresolvedLinks = store.docLinks.filter { $0.targetTitle == "Quantum Physics Concept" }
        assert(!unresolvedLinks.isEmpty, "Precondition: Unresolved link record exists")
        assert(unresolvedLinks.first?.targetDocId == nil, "Precondition: Unresolved link targetDocId is nil")

        let nodeC = store.createDocFromUnresolvedLink(title: "Quantum Physics Concept", sourceDocId: nodeA.id)
        assert(nodeC.parentId == nil, "Constraint 2 Failed: Unresolved link node C must be placed at default/inbox (nil)")
        assert(nodeC.parentId != nodeA.id, "Constraint 2 Failed: C was placed under A!")
        let resolvedLink = store.docLinks.first(where: { $0.targetTitle == "Quantum Physics Concept" })
        assert(resolvedLink?.targetDocId == nodeC.id, "Constraint 2 Failed: Link was not resolved to C")

        // Invariant 3: LINKS_TO may contain cycles (A->B->C->A). Must not trigger tree cycle errors.
        let nodeX = store.createDocument(title: "Cycle Node X")
        let nodeY = store.createDocument(title: "Cycle Node Y")
        let nodeZ = store.createDocument(title: "Cycle Node Z")

        store.selectDocument(id: nodeX.id)
        _ = store.createBlock(type: .paragraph, content: "Points to [[Cycle Node Y]]")
        store.selectDocument(id: nodeY.id)
        _ = store.createBlock(type: .paragraph, content: "Points to [[Cycle Node Z]]")
        store.selectDocument(id: nodeZ.id)
        _ = store.createBlock(type: .paragraph, content: "Points to [[Cycle Node X]]")

        let cycleGraph = store.getGraphData()
        assert(cycleGraph.edges.contains(where: { $0.sourceId == nodeX.id && $0.targetId == nodeY.id }), "Constraint 3 Failed: X->Y missing")
        assert(cycleGraph.edges.contains(where: { $0.sourceId == nodeY.id && $0.targetId == nodeZ.id }), "Constraint 3 Failed: Y->Z missing")
        assert(cycleGraph.edges.contains(where: { $0.sourceId == nodeZ.id && $0.targetId == nodeX.id }), "Constraint 3 Failed: Z->X missing")

        // Invariant 4: Tree traversal queries CONTAINS only and ignores LINKS_TO entirely
        let ancestryZ = store.getDocAncestry(for: nodeZ.id)
        assert(ancestryZ.count == 1 && ancestryZ[0].id == nodeZ.id, "Constraint 4 Failed: Tree ancestry of Z must only follow CONTAINS (root), not links")
        let filteredTree = store.getFilteredDocTree(filter: "Cycle Node")
        assert(filteredTree.count == 3, "Constraint 4 Failed: Filtered tree should find all 3 independent root nodes")

        // Invariant 5: Deleting A does not delete nodes A links to. Leaves inbound links unresolved. Cascades to children via CONTAINS.
        let parentM = store.createDocument(title: "Parent M")
        let childN = store.createDocument(title: "Child N", parentDocId: parentM.id)
        let targetP = store.createDocument(title: "Target P")

        store.selectDocument(id: parentM.id)
        _ = store.createBlock(type: .paragraph, content: "Parent M links to [[Target P]]")
        assert(store.docLinks.contains(where: { $0.sourceDocId == parentM.id && $0.targetDocId == targetP.id }), "Precondition: Link M->P exists")

        // Create link from targetP to parentM (inbound to parentM)
        store.selectDocument(id: targetP.id)
        _ = store.createBlock(type: .paragraph, content: "Target P links back to [[Parent M]]")

        store.deleteDocument(docId: parentM.id)
        assert(!store.documents.contains(where: { $0.id == parentM.id }), "Parent M should be deleted")
        assert(!store.documents.contains(where: { $0.id == childN.id }), "Constraint 5 Failed: Child N should be cascade deleted via CONTAINS")
        assert(store.documents.contains(where: { $0.id == targetP.id }), "Constraint 5 Failed: Target P was deleted because M linked to it!")
        // Inbound link from P to M should now be unresolved
        let pToMLink = store.docLinks.first(where: { $0.sourceDocId == targetP.id && $0.targetTitle == "Parent M" })
        assert(pToMLink != nil, "Link record from P to M must still exist")
        assert(pToMLink?.targetDocId == nil, "Constraint 5 Failed: Inbound link to deleted M must be unresolved (targetDocId == nil)")

        // Invariant 6: Moving a node in the tree must not change any of its links (inbound or outbound survive untouched)
        let folder1 = store.createDocument(title: "Folder 1")
        let folder2 = store.createDocument(title: "Folder 2")
        let docR = store.createDocument(title: "Doc R", parentDocId: folder1.id)
        let docS = store.createDocument(title: "Doc S")

        store.selectDocument(id: docR.id)
        _ = store.createBlock(type: .paragraph, content: "Doc R links to [[Target P]]")
        store.selectDocument(id: docS.id)
        _ = store.createBlock(type: .paragraph, content: "Doc S links to [[Doc R]]")

        assert(store.docLinks.contains(where: { $0.sourceDocId == docR.id && $0.targetDocId == targetP.id }), "Precondition: Outbound link R->P")
        assert(store.docLinks.contains(where: { $0.sourceDocId == docS.id && $0.targetDocId == docR.id }), "Precondition: Inbound link S->R")

        // Move Doc R to Folder 2
        store.moveDocument(docId: docR.id, newParentDocId: folder2.id)
        assert(store.documents.first(where: { $0.id == docR.id })?.parentId == folder2.id, "Doc R moved to Folder 2")

        // Assert links survived relocation untouched
        assert(store.docLinks.contains(where: { $0.sourceDocId == docR.id && $0.targetDocId == targetP.id }), "Constraint 6 Failed: Outbound link R->P lost on relocation!")
        assert(store.docLinks.contains(where: { $0.sourceDocId == docS.id && $0.targetDocId == docR.id }), "Constraint 6 Failed: Inbound link S->R lost on relocation!")

        // Invariant 7: Do not display link targets in sidebar tree, and do not display children in backlinks panel
        // Check sidebar tree for Doc A (which links to B)
        let docTreeFinal = store.getDocTree()
        let aFinalNode = docTreeFinal.first(where: { $0.doc.id == nodeA.id })
        assert(aFinalNode?.children.isEmpty == true, "Constraint 7 Failed: Link target B displayed in sidebar tree under A!")

        // Check backlinks for folderRootF: it has child B, but B has no link to F. Backlinks must be empty (NOT containing child B!)
        let fBacklinks = store.getBacklinks(for: folderRootF.id)
        assert(fBacklinks.isEmpty, "Constraint 7 Failed: Child B displayed in backlinks panel of parent F!")

        print("✅ testLinksAreNotHierarchyConstraint passed")

        // 18. Multi-Photo Sequential Memory Palace & Multi-Flashcard Locus Anchors test
        print("Testing Multi-Photo Sequential Palace & Multi-Flashcard Anchors...")
        let palace = store.createMemoryPalace(name: "Villa Medici", imagePath: "bundled:villa_facade")
        assert(store.palacePhotos.count == 1, "Failed: Palace should initialize with default photo 1")
        let photo1 = store.palacePhotos.first!

        // Add Photo 2 and Photo 3 sequentially
        let photo2 = store.addPalacePhoto(palaceId: palace.id, name: "2. Courtyard Gardens", imagePath: "bundled:villa_courtyard")
        let photo3 = store.addPalacePhoto(palaceId: palace.id, name: "3. Upper Observatory", imagePath: "bundled:villa_observatory")
        assert(store.palacePhotos.count == 3, "Failed: 3 sequential photos in palace")
        assert(store.palacePhotos[0].orderIndex == 0, "Failed: Photo 1 orderIndex 0")
        assert(store.palacePhotos[1].orderIndex == 1, "Failed: Photo 2 orderIndex 1")
        assert(store.palacePhotos[2].orderIndex == 2, "Failed: Photo 3 orderIndex 2")

        // Test 18.1: Direct Information Anchoring without Flashcards
        let directLocus = store.addLocus(
            palaceId: palace.id,
            photoId: photo1.id,
            title: "Villa Facade Columns",
            mnemonic: "Giant golden compass measuring the marble columns",
            anchoredInfo: "Golden ratio 1:1.618 measured across the outer colonnade",
            x: 0.25,
            y: 0.35
        )
        assert(directLocus.anchoredInfo == "Golden ratio 1:1.618 measured across the outer colonnade", "Failed: Direct anchored information")
        assert(directLocus.photoId == photo1.id, "Failed: Locus pinned to photo 1")
        assert(store.getFlashcards(for: directLocus.id).isEmpty, "Failed: Direct anchor should have 0 flashcards initially")

        // Test 18.2: Multiple Flashcards per Locus
        let fcA = store.createFlashcard(front: "Who commissioned Villa Medici?", back: "Ferdinando I de' Medici")
        let fcB = store.createFlashcard(front: "In what year was Villa Medici acquired?", back: "1576")
        let multiLocus = store.addLocus(
            palaceId: palace.id,
            photoId: photo2.id,
            title: "Renaissance Garden Fountain",
            mnemonic: "Fountain spewing golden coins with Medici crests",
            anchoredInfo: "Water pressure driven by an ancient Roman aqueduct",
            x: 0.50,
            y: 0.50
        )
        store.attachFlashcard(locusId: multiLocus.id, flashcardId: fcA.id)
        store.attachFlashcard(locusId: multiLocus.id, flashcardId: fcB.id)

        let locus2Cards = store.getFlashcards(for: multiLocus.id)
        assert(locus2Cards.count == 2, "Failed: Locus 2 should have 2 attached flashcards")
        assert(locus2Cards.contains(where: { $0.id == fcA.id }), "Failed: Attached fcA present")
        assert(locus2Cards.contains(where: { $0.id == fcB.id }), "Failed: Attached fcB present")

        // Detach one card
        store.detachFlashcard(locusId: multiLocus.id, flashcardId: fcA.id)
        let remainingCards = store.getFlashcards(for: multiLocus.id)
        assert(remainingCards.count == 1, "Failed: 1 card remaining after detachment")
        assert(remainingCards.first?.id == fcB.id, "Failed: fcB remains attached")

        // Re-attach fcA
        store.attachFlashcard(locusId: multiLocus.id, flashcardId: fcA.id)
        assert(store.getFlashcards(for: multiLocus.id).count == 2, "Failed: fcA re-attached")

        // Test 18.3: Inline Flashcard Creation
        let observatoryLocus = store.addLocus(
            palaceId: palace.id,
            photoId: photo3.id,
            title: "Galileo Telescope Stand",
            x: 0.75,
            y: 0.20
        )
        let inlineCard = store.createAndAttachFlashcard(
            locusId: observatoryLocus.id,
            front: "Which scientist stayed at Villa Medici in 1633?",
            back: "Galileo Galilei",
            hint: "Italian astronomer"
        )
        assert(store.getFlashcards(for: observatoryLocus.id).count == 1, "Failed: Inline card attached")
        assert(store.getFlashcards(for: observatoryLocus.id).first?.id == inlineCard.id, "Failed: Matching inline card ID")
        assert(store.flashcards.contains(where: { $0.id == inlineCard.id }), "Failed: Card in global flashcards deck")

        // Test 18.4: Sequential Walk Across Photos
        let palaceLoci = store.loci.filter { $0.palaceId == palace.id }.sorted(by: { $0.orderIndex < $1.orderIndex })
        assert(palaceLoci.count == 3, "Failed: 3 loci in palace walk")
        assert(palaceLoci[0].photoId == photo1.id, "Failed: Stop 1 on Photo 1")
        assert(palaceLoci[1].photoId == photo2.id, "Failed: Stop 2 on Photo 2")
        assert(palaceLoci[2].photoId == photo3.id, "Failed: Stop 3 on Photo 3")

        // Test 18.5: Cascade cleanups
        // Deleting locus cleans up locus_flashcard but preserves Flashcard
        store.deleteLocus(id: multiLocus.id)
        assert(store.getFlashcards(for: multiLocus.id).isEmpty, "Failed: LocusFlashcard links removed on locus delete")
        assert(store.flashcards.contains(where: { $0.id == fcA.id }), "Failed: Flashcard fcA preserved after locus deletion")
        assert(store.flashcards.contains(where: { $0.id == fcB.id }), "Failed: Flashcard fcB preserved after locus deletion")

        // Deleting palace cleans up all photos, loci, and links
        store.deleteMemoryPalace(id: palace.id)
        assert(!store.memoryPalaces.contains(where: { $0.id == palace.id }), "Failed: Palace deleted")
        assert(!store.palacePhotos.contains(where: { $0.palaceId == palace.id }), "Failed: Palace photos cascade deleted")
        assert(!store.loci.contains(where: { $0.palaceId == palace.id }), "Failed: Palace loci cascade deleted")

        print("✅ testMultiPhotoPalaceAndLocusAnchors passed")

        // 19. Vast Spatial Canvas & Safe Asset Storage test
        print("Running testVastSpatialCanvasAndAssetStorage...")

        // 19.1: Safe Asset Storage
        let tempDir = FileManager.default.temporaryDirectory
        let tempPhotoURL = tempDir.appendingPathComponent("raw_downloaded_\(UUID().uuidString).jpg")
        let dummyPayload = "JPEG_DATA_\(UUID().uuidString)".data(using: .utf8)!
        try dummyPayload.write(to: tempPhotoURL)
        assert(FileManager.default.fileExists(atPath: tempPhotoURL.path), "Failed: Temporary photo created")

        // Import safely into project storage
        let storedPath = try PalaceAssetStorage.importPhoto(from: tempPhotoURL)
        assert(FileManager.default.fileExists(atPath: storedPath), "Failed: Imported photo exists in safe storage")
        assert(storedPath.contains("PalacePhotos"), "Failed: Photo stored in PalacePhotos directory")
        let readPayload = try Data(contentsOf: URL(fileURLWithPath: storedPath))
        assert(readPayload == dummyPayload, "Failed: Stored payload matches original")

        // Delete original raw downloaded file (simulating external deletion / purge)
        try FileManager.default.removeItem(at: tempPhotoURL)
        assert(!FileManager.default.fileExists(atPath: tempPhotoURL.path), "Failed: Temporary file removed")
        assert(FileManager.default.fileExists(atPath: storedPath), "Failed: Safe copy persists after external deletion")

        // 19.2: Spatial Photo Coordinates & Sequential Layout
        let spatialPalace = store.createMemoryPalace(
            name: "Uffizi Gallery Spatial Floorplan",
            imagePath: storedPath,
            description: "Expansive 2D board with interconnected gallery rooms"
        )
        let sPhoto1 = store.palacePhotos.first(where: { $0.palaceId == spatialPalace.id })!
        assert(sPhoto1.canvasX == 80.0, "Failed: Default photo 1 canvasX should be 80.0")
        assert(sPhoto1.canvasY == 120.0, "Failed: Default photo 1 canvasY should be 120.0")
        assert(sPhoto1.canvasWidth == 420.0, "Failed: Default photo 1 canvasWidth should be 420.0")
        assert(sPhoto1.canvasHeight == 280.0, "Failed: Default photo 1 canvasHeight should be 280.0")

        // Add second photo to canvas - should auto-tile to the right
        let sPhoto2 = store.addPalacePhoto(
            palaceId: spatialPalace.id,
            name: "Tribuna Room",
            imagePath: storedPath
        )
        assert(sPhoto2.canvasX == 580.0, "Failed: Photo 2 canvasX tiled to 580.0")
        assert(sPhoto2.canvasY == 120.0, "Failed: Photo 2 canvasY should be 120.0")

        // Drag/reposition photo 1
        store.updatePhotoPosition(id: sPhoto1.id, x: 200.0, y: 300.0)
        let updatedP1 = store.palacePhotos.first(where: { $0.id == sPhoto1.id })!
        assert(updatedP1.canvasX == 200.0, "Failed: Updated photo 1 canvasX")
        assert(updatedP1.canvasY == 300.0, "Failed: Updated photo 1 canvasY")

        // Resize photo 1
        store.updatePhotoDimensions(id: sPhoto1.id, width: 500.0, height: 350.0)
        let resizedP1 = store.palacePhotos.first(where: { $0.id == sPhoto1.id })!
        assert(resizedP1.canvasWidth == 500.0, "Failed: Updated photo 1 width")
        assert(resizedP1.canvasHeight == 350.0, "Failed: Updated photo 1 height")

        // 19.3: Loci Scoped to Spatial Photos & Continuous Canvas Route
        let sLocus1 = store.addLocus(
            palaceId: spatialPalace.id,
            photoId: sPhoto1.id,
            title: "Birth of Venus Centerpiece",
            mnemonic: "Venus emerging with sparkling diamond shells",
            anchoredInfo: "Botticelli tempera on canvas painted c. 1485",
            x: 0.3,
            y: 0.4
        )
        let sLocus2 = store.addLocus(
            palaceId: spatialPalace.id,
            photoId: sPhoto2.id,
            title: "Medici Venus Pedestal",
            mnemonic: "Marble pedestal glowing with neon numbers",
            anchoredInfo: "Hellenistic marble sculpture of Aphrodite",
            x: 0.7,
            y: 0.8
        )

        // Verify normalized coordinates are stored
        assert(sLocus1.normalizedX == 0.3 && sLocus1.normalizedY == 0.4, "Failed: Locus 1 normalized coordinates")
        assert(sLocus2.normalizedX == 0.7 && sLocus2.normalizedY == 0.8, "Failed: Locus 2 normalized coordinates")

        // Verify computed absolute canvas coordinates
        // Header height offset is 36.0
        let p1Current = store.palacePhotos.first(where: { $0.id == sPhoto1.id })!
        let absX1 = p1Current.canvasX + sLocus1.normalizedX * p1Current.canvasWidth
        let absY1 = p1Current.canvasY + 36.0 + sLocus1.normalizedY * p1Current.canvasHeight
        assert(absX1 == 200.0 + 0.3 * 500.0, "Failed: Calculated absX1 (350.0)")
        assert(absY1 == 300.0 + 36.0 + 0.4 * 350.0, "Failed: Calculated absY1 (476.0)")

        // 19.4: Cascade deletion of photo and its loci
        store.deletePalacePhoto(id: sPhoto1.id)
        assert(!store.palacePhotos.contains(where: { $0.id == sPhoto1.id }), "Failed: Photo 1 deleted")
        assert(!store.loci.contains(where: { $0.id == sLocus1.id }), "Failed: Locus 1 cascade deleted with Photo 1")
        assert(store.palacePhotos.contains(where: { $0.id == sPhoto2.id }), "Failed: Photo 2 preserved")
        assert(store.loci.contains(where: { $0.id == sLocus2.id }), "Failed: Locus 2 preserved")

        // Clean up palace and safe asset
        store.deleteMemoryPalace(id: spatialPalace.id)
        assert(!store.palacePhotos.contains(where: { $0.palaceId == spatialPalace.id }), "Failed: All photos deleted with palace")
        assert(!store.loci.contains(where: { $0.palaceId == spatialPalace.id }), "Failed: All loci deleted with palace")
        try? FileManager.default.removeItem(atPath: storedPath)
        assert(!FileManager.default.fileExists(atPath: storedPath), "Failed: Stored photo cleaned up")

        print("✅ testVastSpatialCanvasAndAssetStorage passed")

        // 20. Flashcard Decks & Note-Generated Card Grouping test
        print("Running testFlashcardDecksAndNoteGrouping...")

        // 20.1: Verify default Notes & Documents deck
        let defaultDeck = store.defaultNotesDeck
        assert(defaultDeck != nil, "Failed: Default notes deck should exist")
        assert(defaultDeck?.isNotesDefault == true, "Failed: Default notes deck isNotesDefault flag")
        assert(defaultDeck?.id == Deck.notesDefaultId, "Failed: Default notes deck ID")

        // Verify seeded flashcards are grouped under the default notes deck
        let notesCards = store.flashcards(forDeck: Deck.notesDefaultId)
        assert(notesCards.count >= 3, "Failed: Seeded cards grouped under Notes deck")
        assert(notesCards.contains(where: { $0.id == "fc-atomic-phil" }), "Failed: fc-atomic-phil in Notes deck")
        assert(notesCards.contains(where: { $0.id == "fc-fsrs-retention" }), "Failed: fc-fsrs-retention in Notes deck")
        assert(notesCards.contains(where: { $0.id == "fc-backlinks-bidirectional" }), "Failed: fc-backlinks-bidirectional in Notes deck")

        // 20.2: Verify note grouping by folder hierarchy
        let noteGroups = store.noteGroupedFlashcards()
        assert(!noteGroups.isEmpty, "Failed: Note grouped flashcards should not be empty")
        for group in noteGroups {
            assert(!group.cards.isEmpty, "Failed: Group has non-empty cards list")
            for card in group.cards {
                assert(card.docId == group.doc.id, "Failed: Card docId matches parent folder doc ID")
            }
        }

        // 20.3: Create Custom Deck
        let customDeck = store.createDeck(
            name: "Neuroscience Core",
            description: "Brain structures & synaptic pathways",
            colorHex: "#10B981",
            icon: "brain.head.profile"
        )
        assert(store.decks.contains(where: { $0.id == customDeck.id }), "Failed: Custom deck inserted in store")
        assert(customDeck.isNotesDefault == false, "Failed: Custom deck is not default notes deck")
        assert(store.selectedDeckId == customDeck.id, "Failed: Store auto-selected newly created deck")

        // 20.4: Add new cards saved strictly into the custom deck
        let neuroCard1 = store.createFlashcard(
            deckId: customDeck.id,
            front: "What neurotransmitter is released at neuromuscular junctions?",
            back: "Acetylcholine (ACh)"
        )
        let neuroCard2 = store.createFlashcard(
            deckId: customDeck.id,
            front: "Which lobe of the brain is primary for visual processing?",
            back: "Occipital Lobe"
        )

        assert(neuroCard1.deckId == customDeck.id, "Failed: neuroCard1 deckId matches custom deck")
        assert(neuroCard2.deckId == customDeck.id, "Failed: neuroCard2 deckId matches custom deck")

        // Verify deck isolation
        let customDeckCards = store.flashcards(forDeck: customDeck.id)
        assert(customDeckCards.count == 2, "Failed: Custom deck contains exactly 2 cards")
        assert(customDeckCards.contains(where: { $0.id == neuroCard1.id }), "Failed: neuroCard1 in custom deck")
        assert(customDeckCards.contains(where: { $0.id == neuroCard2.id }), "Failed: neuroCard2 in custom deck")

        // Verify custom deck cards are NOT in the notes deck
        let updatedNotesCards = store.flashcards(forDeck: Deck.notesDefaultId)
        assert(!updatedNotesCards.contains(where: { $0.id == neuroCard1.id }), "Failed: Custom card leaked into notes deck")
        assert(!updatedNotesCards.contains(where: { $0.id == neuroCard2.id }), "Failed: Custom card leaked into notes deck")

        // Verify all cards view includes both
        let allCards = store.flashcards(forDeck: "all")
        assert(allCards.contains(where: { $0.id == neuroCard1.id }), "Failed: All cards contains custom card")
        assert(allCards.contains(where: { $0.id == "fc-atomic-phil" }), "Failed: All cards contains notes card")

        // 20.5: Adding card from note folder automatically routes to notes deck
        let pharDoc = store.createDocument(title: "Pharmacology Basics")
        let pharCard = store.createFlashcard(
            docId: pharDoc.id,
            front: "Where are beta-1 adrenergic receptors predominantly located?",
            back: "Heart muscle & kidneys"
        )
        assert(pharCard.deckId == Deck.notesDefaultId, "Failed: Note-associated card auto-routed to Notes deck")
        assert(store.flashcards(forDeck: Deck.notesDefaultId).contains(where: { $0.id == pharCard.id }), "Failed: Note card visible in Notes deck")

        // 20.6: Deck Deletion Protection & Safe Reassignment
        // Attempting to delete default notes deck must be blocked
        store.deleteDeck(id: Deck.notesDefaultId)
        assert(store.decks.contains(where: { $0.id == Deck.notesDefaultId }), "Failed: Default notes deck should be protected from deletion")

        // Deleting custom deck should safely reassign its cards to the default notes deck
        store.deleteDeck(id: customDeck.id)
        assert(!store.decks.contains(where: { $0.id == customDeck.id }), "Failed: Custom deck removed")
        let reloadedNeuroCard1 = store.flashcards.first(where: { $0.id == neuroCard1.id })
        assert(reloadedNeuroCard1 != nil, "Failed: neuroCard1 preserved after deck deletion")
        assert(reloadedNeuroCard1?.deckId == Deck.notesDefaultId, "Failed: neuroCard1 safely reassigned to notes deck")

        print("✅ testFlashcardDecksAndNoteGrouping passed")

        // 21. Mock Notes Hierarchy, Note Flashcards, Independent Decks & Memory Palaces test
        print("Running testMockNotesDecksAndMemoryPalaces...")

        // 21.1: Verify Mock Notes Hierarchy (Root -> Subtopics -> Sub-subtopics)
        let rootMock = store.documents.first(where: { $0.id == "doc-dist-sys" })
        assert(rootMock != nil, "Failed: Root document 'doc-dist-sys' should exist")
        assert(rootMock?.content == "Distributed Systems & Storage Engines", "Failed: Root document title")

        let subtopics = store.getChildDocuments(for: "doc-dist-sys")
        assert(subtopics.count == 3, "Failed: Expected 3 subtopics under root document")
        let subtopicIds = subtopics.map { $0.id }
        assert(subtopicIds.contains("doc-consensus"), "Failed: Missing doc-consensus subtopic")
        assert(subtopicIds.contains("doc-storage-engines"), "Failed: Missing doc-storage-engines subtopic")
        assert(subtopicIds.contains("doc-transactions"), "Failed: Missing doc-transactions subtopic")

        // Sub-subtopics under doc-consensus
        let consensusSubs = store.getChildDocuments(for: "doc-consensus")
        assert(consensusSubs.count == 3, "Failed: 3 sub-subtopics under Consensus")
        assert(consensusSubs.contains(where: { $0.id == "doc-raft" }), "Failed: Raft sub-subtopic")
        assert(consensusSubs.contains(where: { $0.id == "doc-paxos" }), "Failed: Paxos sub-subtopic")
        assert(consensusSubs.contains(where: { $0.id == "doc-bft" }), "Failed: BFT sub-subtopic")

        // Sub-subtopics under doc-storage-engines
        let storageSubs = store.getChildDocuments(for: "doc-storage-engines")
        assert(storageSubs.count == 3, "Failed: 3 sub-subtopics under Storage Engines")
        assert(storageSubs.contains(where: { $0.id == "doc-lsm" }), "Failed: LSM-Trees sub-subtopic")
        assert(storageSubs.contains(where: { $0.id == "doc-btree" }), "Failed: B+ Trees sub-subtopic")
        assert(storageSubs.contains(where: { $0.id == "doc-wal-aries" }), "Failed: ARIES sub-subtopic")

        // Sub-subtopics under doc-transactions
        let txSubs = store.getChildDocuments(for: "doc-transactions")
        assert(txSubs.count == 2, "Failed: 2 sub-subtopics under Transactions")
        assert(txSubs.contains(where: { $0.id == "doc-mvcc" }), "Failed: MVCC sub-subtopic")
        assert(txSubs.contains(where: { $0.id == "doc-2pl" }), "Failed: 2PL sub-subtopic")

        // 21.2: Verify 12 Note-Generated Flashcards
        let expectedNoteCardIds = [
            "fc-mock-raft-election", "fc-mock-raft-safety", "fc-mock-paxos-quorum",
            "fc-mock-bft-formula", "fc-mock-lsm-path", "fc-mock-lsm-bloom",
            "fc-mock-lsm-compaction", "fc-mock-btree-leaves", "fc-mock-aries-phases",
            "fc-mock-mvcc-isolation", "fc-mock-mvcc-skew", "fc-mock-2pl-strict"
        ]
        let notesDeckCards = store.flashcards(forDeck: Deck.notesDefaultId)
        for cardId in expectedNoteCardIds {
            assert(notesDeckCards.contains(where: { $0.id == cardId }), "Failed: Missing note card \(cardId) in Notes deck")
            let card = store.flashcards.first(where: { $0.id == cardId })!
            assert(card.deckId == Deck.notesDefaultId, "Failed: Card \(cardId) deckId must be notesDefaultId")
            assert(!card.docId.isEmpty, "Failed: Card \(cardId) must be linked to a note docId")
        }

        // Verify folder grouping in Notes deck reflects subtopics
        let folderGroups = store.noteGroupedFlashcards()
        assert(folderGroups.contains(where: { $0.doc.id == "doc-raft" }), "Failed: Folder group for doc-raft")
        assert(folderGroups.contains(where: { $0.doc.id == "doc-lsm" }), "Failed: Folder group for doc-lsm")

        // 21.3: Verify 3 Independent Custom Decks with 4 Cards Each
        let neuroDeck = store.decks.first(where: { $0.id == "deck-neuroscience" })
        assert(neuroDeck != nil, "Failed: deck-neuroscience exists")
        assert(neuroDeck?.name == "Cognitive Neuroscience & Mind", "Failed: neuroDeck name")
        assert(store.flashcards(forDeck: "deck-neuroscience").count == 4, "Failed: 4 cards in neuro deck")

        let siliconDeck = store.decks.first(where: { $0.id == "deck-silicon" })
        assert(siliconDeck != nil, "Failed: deck-silicon exists")
        assert(siliconDeck?.name == "Computer Architecture & Silicon", "Failed: siliconDeck name")
        assert(store.flashcards(forDeck: "deck-silicon").count == 4, "Failed: 4 cards in silicon deck")

        let biochemDeck = store.decks.first(where: { $0.id == "deck-biochem" })
        assert(biochemDeck != nil, "Failed: deck-biochem exists")
        assert(biochemDeck?.name == "Cellular Biochemistry & Energetics", "Failed: biochemDeck name")
        assert(store.flashcards(forDeck: "deck-biochem").count == 4, "Failed: 4 cards in biochem deck")

        // 21.4: Verify Designed Memory Palaces with Stock Photos & Spatial Loci
        let alexPalace = store.memoryPalaces.first(where: { $0.id == "mp-alexandria" })
        assert(alexPalace != nil, "Failed: mp-alexandria palace exists")
        assert(alexPalace?.name == "The Library of Alexandria", "Failed: alexPalace name")

        store.selectPalace(id: "mp-alexandria")
        let alexPhotos = store.palacePhotos.sorted(by: { $0.orderIndex < $1.orderIndex })
        assert(alexPhotos.count == 3, "Failed: 3 sequential photos in alexandria palace")
        assert(alexPhotos[0].orderIndex == 0 && alexPhotos[1].orderIndex == 1 && alexPhotos[2].orderIndex == 2, "Failed: Sequential order indices")
        assert(alexPhotos[0].canvasX == 80.0 && alexPhotos[1].canvasX == 580.0 && alexPhotos[2].canvasX == 1080.0, "Failed: Spatial canvas horizontal tiling")

        let alexLoci = store.loci
        assert(alexLoci.count == 5, "Failed: 5 loci in alexandria palace")
        assert(alexLoci.allSatisfy { !($0.mnemonic?.isEmpty ?? true) }, "Failed: All loci have vivid mnemonics")
        assert(alexLoci.allSatisfy { $0.anchoredInfo != nil && !$0.anchoredInfo!.isEmpty }, "Failed: All loci have direct anchored info")

        let renPalace = store.memoryPalaces.first(where: { $0.id == "mp-renaissance" })
        assert(renPalace != nil, "Failed: mp-renaissance palace exists")
        store.selectPalace(id: "mp-renaissance")
        let renPhotos = store.palacePhotos
        assert(renPhotos.count == 2, "Failed: 2 sequential photos in renaissance palace")
        let renLoci = store.loci
        assert(renLoci.count == 4, "Failed: 4 loci in renaissance palace")

        // Verify photo path resolution
        let resolvedColonnade = PalaceAssetStorage.resolvePhotoPath("photo-alexandria-colonnade.jpg")
        assert(resolvedColonnade != nil, "Failed: photo-alexandria-colonnade.jpg resolved on disk")

        print("✅ testMockNotesDecksAndMemoryPalaces passed")

        // 22. Socratic AI Active Recall & Evaluation Suite
        print("Running testAISocraticEvaluationAndSettings...")

        // 22.1: JSON Parsing for Spot-On Evaluation
        let spotOnJSON = """
        {
            "isSpotOn": true,
            "status": "spot_on",
            "feedback": "Brilliant! You precisely explained why Raft utilizes randomized election timeouts to prevent split votes.",
            "counterQuestion": null,
            "suggestedRating": 4
        }
        """
        let evalSpotOn = try AISocraticService.shared.parseEvaluationJSON(rawText: spotOnJSON)
        assert(evalSpotOn.isSpotOn == true, "Failed: Spot-on flag should be true")
        assert(evalSpotOn.status == "spot_on", "Failed: Status should be spot_on")
        assert(evalSpotOn.counterQuestion == nil, "Failed: Counter-question should be nil for spot-on")
        assert(evalSpotOn.suggestedRating == 4, "Failed: Suggested rating should be 4 (Easy)")

        // 22.2: JSON Parsing with Markdown Code Fences for Probing Evaluation
        let probingJSONWithFences = """
        ```json
        {
            "isSpotOn": false,
            "status": "probing",
            "feedback": "You correctly noted that LSM-trees write to an in-memory MemTable first.",
            "counterQuestion": "What append-only structure on disk ensures durability if power is lost before the MemTable is flushed?",
            "suggestedRating": 2
        }
        ```
        """
        let evalProbing = try AISocraticService.shared.parseEvaluationJSON(rawText: probingJSONWithFences)
        assert(evalProbing.isSpotOn == false, "Failed: Spot-on flag should be false for probing")
        assert(evalProbing.status == "probing", "Failed: Status should be probing")
        assert(evalProbing.counterQuestion?.contains("append-only structure") == true, "Failed: Counter question parsed correctly")
        assert(evalProbing.suggestedRating == 2, "Failed: Suggested rating should be 2 (Hard)")

        // 22.3: Multi-turn Dialogue Model
        let turn1 = AISocraticTurn(
            roundNumber: 1,
            userAnswer: "LSM trees write to an in-memory buffer.",
            feedback: evalProbing.feedback,
            counterQuestion: evalProbing.counterQuestion,
            isSpotOn: false
        )
        assert(turn1.roundNumber == 1, "Failed: Turn round number")
        assert(turn1.isSpotOn == false, "Failed: Turn spot-on flag")
        assert(turn1.counterQuestion != nil, "Failed: Turn counter question")

        let turn2 = AISocraticTurn(
            roundNumber: 2,
            userAnswer: "A Write-Ahead Log (WAL) provides durability on disk before flushing to SSTables.",
            feedback: evalSpotOn.feedback,
            counterQuestion: nil,
            isSpotOn: true
        )
        assert(turn2.roundNumber == 2, "Failed: Turn 2 round number")
        assert(turn2.isSpotOn == true, "Failed: Turn 2 spot-on flag")
        assert(turn2.counterQuestion == nil, "Failed: Turn 2 counter-question nil")

        // 22.4: First-Time Card Detection Logic
        let firstTimeCard = Flashcard(
            docId: "doc-test-1",
            notebookId: "nb-1",
            front: "What is Raft?",
            back: "A consensus algorithm designed for understandability.",
            fsrsState: .newCard,
            reps: 0
        )
        assert(firstTimeCard.reps == 0, "Failed: First-time card has reps == 0")
        assert(firstTimeCard.fsrsState == .newCard, "Failed: First-time card has state == newCard")

        let reviewedCard = Flashcard(
            docId: "doc-test-2",
            notebookId: "nb-1",
            front: "What is Paxos?",
            back: "A foundational distributed consensus protocol.",
            fsrsState: .review,
            reps: 4
        )
        assert(reviewedCard.reps > 0, "Failed: Reviewed card has reps > 0")
        assert(reviewedCard.fsrsState != .newCard, "Failed: Reviewed card is not new")

        // 22.5: AI Settings Masking & Persistence
        let aiSettings = AISettings.shared
        let originalKey = aiSettings.apiKey
        aiSettings.apiKey = "AIzaSyD-TestKey1234567890ABCDEF"
        assert(aiSettings.hasAPIKey == true, "Failed: hasAPIKey should be true")
        assert(aiSettings.maskedKey.hasPrefix("AIza"), "Failed: masked key prefix")
        assert(aiSettings.maskedKey.hasSuffix("CDEF"), "Failed: masked key suffix")
        assert(aiSettings.maskedKey.contains("••••"), "Failed: masked key contains bullets")
        aiSettings.apiKey = originalKey // restore

        print("✅ testAISocraticEvaluationAndSettings passed")

        // ==========================================
        // 23. Notes AI Downward Hierarchy & Dual Configuration Test
        // ==========================================
        print("\n--- Running Suite 23: Notes AI Downward Hierarchy & Dual Configuration ---")

        // 23.1: Dual AI Configuration (Shared vs Independent)
        let aiConfig = AISettings.shared
        let origFCKey = aiConfig.apiKey
        let origFCProv = aiConfig.provider
        let origFCModel = aiConfig.model
        let origNotesShared = aiConfig.useFlashcardSettingsForNotes
        let origNotesKey = aiConfig.notesApiKey
        let origNotesProv = aiConfig.notesProvider
        let origNotesModel = aiConfig.notesModel

        aiConfig.apiKey = "AIzaSyFlashcardSharedKey123456"
        aiConfig.provider = .gemini
        aiConfig.model = "gemini-3.6-flash"
        aiConfig.useFlashcardSettingsForNotes = true

        assert(aiConfig.activeNotesApiKey == "AIzaSyFlashcardSharedKey123456", "Failed: Notes AI should inherit shared API key")
        assert(aiConfig.activeNotesProvider == .gemini, "Failed: Notes AI should inherit shared provider")
        assert(aiConfig.activeNotesModel == "gemini-3.6-flash", "Failed: Notes AI should inherit shared model")
        assert(aiConfig.hasNotesAPIKey == true, "Failed: hasNotesAPIKey should be true when shared key is present")

        // Switch to independent Notes AI configuration
        aiConfig.useFlashcardSettingsForNotes = false
        aiConfig.notesApiKey = "sk-proj-OpenAINotesIndependentKey987654"
        aiConfig.notesProvider = .openai
        aiConfig.notesModel = "gpt-4o-mini"

        assert(aiConfig.activeNotesApiKey == "sk-proj-OpenAINotesIndependentKey987654", "Failed: Notes AI should use independent key when unlinked")
        assert(aiConfig.activeNotesProvider == .openai, "Failed: Notes AI should use independent provider")
        assert(aiConfig.activeNotesModel == "gpt-4o-mini", "Failed: Notes AI should use independent model")
        assert(aiConfig.maskedNotesKey.hasPrefix("sk-p"), "Failed: Masked notes key prefix")
        assert(aiConfig.maskedNotesKey.hasSuffix("7654"), "Failed: Masked notes key suffix")

        // Restore original settings
        aiConfig.apiKey = origFCKey
        aiConfig.provider = origFCProv
        aiConfig.model = origFCModel
        aiConfig.useFlashcardSettingsForNotes = origNotesShared
        aiConfig.notesApiKey = origNotesKey
        aiConfig.notesProvider = origNotesProv
        aiConfig.notesModel = origNotesModel

        // 23.2: Downward Hierarchy JSON Parsing with Nested Structure
        let mockHierarchyJSON = """
        {
          "rootTitle": "Distributed Consensus Protocols",
          "overview": "A downward breakdown of consensus algorithms into Paxos and Raft subtopics.",
          "items": [
            {
              "title": "Paxos Family",
              "summary": "The theoretical foundation of distributed consensus by Leslie Lamport.",
              "blocks": [
                {
                  "typeString": "paragraph",
                  "content": "Paxos operates in phases: Prepare/Promise and Accept/Accepted."
                },
                {
                  "typeString": "bulletList",
                  "content": "Single-decree Paxos reaches consensus on a single value."
                },
                {
                  "typeString": "bulletList",
                  "content": "Multi-Paxos amortizes the prepare phase for a log of values."
                }
              ],
              "children": [
                {
                  "title": "Multi-Paxos Optimization",
                  "summary": "Electing a stable leader to avoid Phase 1 round-trips.",
                  "blocks": [
                    {
                      "typeString": "callout",
                      "content": "Stable leader reduces consensus to one round-trip."
                    }
                  ],
                  "children": []
                }
              ]
            },
            {
              "title": "Raft Protocol",
              "summary": "An algorithm designed for understandability with explicit leader election.",
              "blocks": [
                {
                  "typeString": "paragraph",
                  "content": "Decomposes consensus into Leader Election, Log Replication, and Safety."
                }
              ],
              "children": []
            }
          ]
        }
        """

        let parsedResult = try AISocraticService.shared.parseHierarchicalJSON(rawText: mockHierarchyJSON)
        assert(parsedResult.rootTitle == "Distributed Consensus Protocols", "Failed: Root title parsed")
        assert(parsedResult.items.count == 2, "Failed: Top-level subtopics count")
        assert(parsedResult.items[0].title == "Paxos Family", "Failed: First subtopic title")
        assert(parsedResult.items[0].blocks.count == 3, "Failed: First subtopic block count")
        assert(parsedResult.items[0].children.count == 1, "Failed: Sub-subtopic child count")
        assert(parsedResult.items[0].children[0].title == "Multi-Paxos Optimization", "Failed: Child title")
        assert(parsedResult.items[0].totalNodeCount == 2, "Failed: Total node count for Paxos branch")
        assert(parsedResult.items[1].title == "Raft Protocol", "Failed: Second subtopic title")

        // 23.3: Strict Downward Hierarchy Guarantee & Tree Commitment (.treeSubNotes)
        let rootNote = store.createDocument(title: "Distributed Systems Study Guide")
        let preDocCount = store.documents.count

        // Commit parsed hierarchy as child documents
        store.commitHierarchicalNotes(rootDocId: rootNote.id, result: parsedResult, destination: .treeSubNotes)

        let postDocCount = store.documents.count
        assert(postDocCount == preDocCount + 3, "Failed: Exactly 3 child documents should be added to the tree")

        // Verify Strict Downward Invariant:
        // All level-1 child notes MUST have parentId == rootNote.id
        let level1Docs = store.documents.filter { $0.parentId == rootNote.id }
        assert(level1Docs.count == 2, "Failed: Exactly 2 direct child documents under rootNote")
        assert(level1Docs.contains(where: { $0.content == "Paxos Family" }), "Failed: Paxos Family is direct child")
        assert(level1Docs.contains(where: { $0.content == "Raft Protocol" }), "Failed: Raft Protocol is direct child")

        // Sub-child MUST have parentId == Paxos Family doc ID
        let paxosDoc = level1Docs.first(where: { $0.content == "Paxos Family" })!
        let paxosChildren = store.documents.filter { $0.parentId == paxosDoc.id }
        assert(paxosChildren.count == 1, "Failed: Exactly 1 sub-child under Paxos Family")
        assert(paxosChildren[0].content == "Multi-Paxos Optimization", "Failed: Multi-Paxos is child of Paxos Family")

        // Verify Root note itself was NOT modified or reparented
        let fetchedRoot = store.getBlock(id: rootNote.id)
        assert(fetchedRoot?.parentId == nil, "Failed: Root note parentId remains unchanged (nil)")
        assert(fetchedRoot?.content == "Distributed Systems Study Guide", "Failed: Root note content remains unchanged")

        // 23.4: In-Document Block Outline Commitment (.documentBlocks)
        let preBlockCount = store.blocks.count
        store.selectDocument(id: rootNote.id)
        store.commitHierarchicalNotes(rootDocId: rootNote.id, result: parsedResult, destination: .documentBlocks)
        store.reloadBlocks()

        let postBlockCount = store.blocks.count
        assert(postBlockCount > preBlockCount, "Failed: Blocks should be appended to the current root document")
        assert(store.blocks.contains(where: { $0.type == .heading2 && $0.content == "Paxos Family" }), "Failed: Heading2 Paxos Family added")
        assert(store.blocks.contains(where: { $0.type == .heading3 && $0.content == "Multi-Paxos Optimization" }), "Failed: Heading3 Multi-Paxos added")
        assert(store.blocks.contains(where: { $0.type == .callout && $0.content.contains("Stable leader") }), "Failed: Callout block added")

        // 23.5: NotesGenerationMode & HierarchyDestination UI Models
        assert(NotesGenerationMode.allCases.count == 3, "Failed: 3 generation modes")
        assert(HierarchyDestination.allCases.count == 3, "Failed: 3 hierarchy destinations")
        assert(store.isNotesAIAssistantPresented == false, "Failed: Default assistant visibility is false")
        store.toggleNotesAIAssistant()
        assert(store.isNotesAIAssistantPresented == true, "Failed: Toggled assistant visibility is true")
        store.toggleNotesAIAssistant()
        assert(store.isNotesAIAssistantPresented == false, "Failed: Toggled assistant visibility back to false")

        print("✅ testNotesAIDownwardHierarchyAndDualConfiguration passed")

        print("\n🎉 ALL 23 TEST SUITES PASSED SUCCESSFULLY!")
    }
}
