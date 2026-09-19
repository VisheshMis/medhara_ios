import Foundation
import GRDB

public enum MockDataSeeder {
    public static func seedIfMissing(into db: Database) throws {
        let now = Date()
        let nbId = "nb-welcome-kb"

        // Ensure default notebook exists
        if try Notebook.filter(Notebook.Columns.id == nbId).fetchOne(db) == nil {
            let nb = Notebook(id: nbId, name: "Knowledge Base", icon: "brain.head.profile", sortOrder: 0)
            try nb.insert(db)
        }

        // Ensure default notes deck exists
        if try Deck.filter(Deck.Columns.id == Deck.notesDefaultId).fetchOne(db) == nil {
            let defaultDeck = Deck(
                id: Deck.notesDefaultId,
                name: "Notes & Documents",
                description: "Auto-grouped collection of all flashcards generated or linked to the notes and folder hierarchy",
                colorHex: "#3B82F6",
                icon: "note.text",
                isNotesDefault: true,
                createdAt: now,
                updatedAt: now
            )
            try defaultDeck.insert(db)
        }

        // 1. Seed Deep Notes Hierarchy
        if try Block.filter(Block.Columns.id == "doc-dist-sys").fetchOne(db) == nil {
            try seedNotesHierarchy(into: db, notebookId: nbId, timestamp: now)
        }

        // 2. Seed Independent Custom Decks with Cards
        if try Deck.filter(Deck.Columns.id == "deck-neuroscience").fetchOne(db) == nil {
            try seedIndependentDecks(into: db, timestamp: now)
        }

        // 3. Seed Memory Palaces with Stock Photos
        if try MemoryPalace.filter(MemoryPalace.Columns.id == "mp-alexandria").fetchOne(db) == nil {
            try seedMemoryPalaces(into: db, timestamp: now)
        }

        // 4. Ensure all loci with flashcardId have links in locus_flashcard table
        let lociWithCards = try PalaceLocus.filter(PalaceLocus.Columns.flashcardId != nil).fetchAll(db)
        for locus in lociWithCards {
            if let fcId = locus.flashcardId, !fcId.isEmpty {
                let exists = try LocusFlashcard.filter(LocusFlashcard.Columns.locusId == locus.id && LocusFlashcard.Columns.flashcardId == fcId).fetchOne(db) != nil
                if !exists {
                    let link = LocusFlashcard(id: "lf-\(locus.id)-\(fcId)", locusId: locus.id, flashcardId: fcId, sortOrder: 0)
                    try link.insert(db)
                }
            }
        }
    }

    // MARK: - 1. Notes Hierarchy & Note-Generated Flashcards
    private static func seedNotesHierarchy(into db: Database, notebookId: String, timestamp: Date) throws {
        // Root Document: "Distributed Systems & Storage Engines"
        let rootDocId = "doc-dist-sys"
        let rootDoc = Block(
            id: rootDocId,
            rootDocId: rootDocId,
            parentId: nil,
            type: .doc,
            content: "Distributed Systems & Storage Engines",
            sortOrder: 2,
            createdAt: timestamp,
            updatedAt: timestamp,
            notebookId: notebookId
        )
        try rootDoc.insert(db)

        let rootBlocks: [Block] = [
            Block(rootDocId: rootDocId, parentId: rootDocId, type: .heading1, content: "Architectural Foundations of Modern Data Systems", sortOrder: 1, createdAt: timestamp, updatedAt: timestamp),
            Block(rootDocId: rootDocId, parentId: rootDocId, type: .callout, content: "This comprehensive knowledge tree explores the core mechanics of distributed state machine replication, low-latency disk storage engines, and ACID transaction isolation.", sortOrder: 2, createdAt: timestamp, updatedAt: timestamp),
            Block(rootDocId: rootDocId, parentId: rootDocId, type: .paragraph, content: "Modern cloud databases balance the fundamental trade-offs formalized in the CAP theorem and PACELC model. Achieving dependable distributed persistence requires coordinating consensus across unpredictable networks while managing storage structures optimized for modern SSD media.", sortOrder: 3, createdAt: timestamp, updatedAt: timestamp),
            Block(rootDocId: rootDocId, parentId: rootDocId, type: .taskList, content: "Master Raft leader election invariants and log matching safety", sortOrder: 4, isCompleted: true, createdAt: timestamp, updatedAt: timestamp),
            Block(rootDocId: rootDocId, parentId: rootDocId, type: .taskList, content: "Contrast LSM-Tree write amplification with B+ Tree page splits", sortOrder: 5, isCompleted: true, createdAt: timestamp, updatedAt: timestamp),
            Block(rootDocId: rootDocId, parentId: rootDocId, type: .taskList, content: "Analyze Snapshot Isolation anomalies including Write Skew", sortOrder: 6, isCompleted: false, createdAt: timestamp, updatedAt: timestamp),
            Block(rootDocId: rootDocId, parentId: rootDocId, type: .quote, content: "There are only two hard things in Computer Science: cache invalidation and naming things. — Phil Karlton", sortOrder: 7, createdAt: timestamp, updatedAt: timestamp)
        ]
        for b in rootBlocks { try b.insert(db) }

        // --- SUBTOPIC 1: Consensus & Replication ---
        let sub1Id = "doc-consensus"
        let sub1 = Block(id: sub1Id, rootDocId: sub1Id, parentId: rootDocId, type: .doc, content: "1. Consensus & Replication", sortOrder: 0, createdAt: timestamp, updatedAt: timestamp, notebookId: notebookId)
        try sub1.insert(db)
        try Block(rootDocId: sub1Id, parentId: sub1Id, type: .heading1, content: "The Distributed Consensus Challenge", sortOrder: 1, createdAt: timestamp, updatedAt: timestamp).insert(db)
        try Block(rootDocId: sub1Id, parentId: sub1Id, type: .paragraph, content: "Consensus protocols allow a cluster of machines to work as a coherent group that can survive failures of some of its members.", sortOrder: 2, createdAt: timestamp, updatedAt: timestamp).insert(db)
        try Block(rootDocId: sub1Id, parentId: sub1Id, type: .callout, content: "Core Rule: A quorum of nodes must confirm receipt and order of every transaction before it is made permanent.", sortOrder: 3, createdAt: timestamp, updatedAt: timestamp).insert(db)

        // Sub-subtopic 1.1: Raft
        let sub11Id = "doc-raft"
        let sub11 = Block(id: sub11Id, rootDocId: sub11Id, parentId: sub1Id, type: .doc, content: "1.1 Raft Consensus Protocol", sortOrder: 0, createdAt: timestamp, updatedAt: timestamp, notebookId: notebookId)
        try sub11.insert(db)
        let sub11Blocks: [Block] = [
            Block(rootDocId: sub11Id, parentId: sub11Id, type: .heading1, content: "Raft: Understandable Distributed Consensus", sortOrder: 1, createdAt: timestamp, updatedAt: timestamp),
            Block(rootDocId: sub11Id, parentId: sub11Id, type: .callout, content: "Raft structures consensus around an elected leader, which assumes complete responsibility for managing the replicated log.", sortOrder: 2, createdAt: timestamp, updatedAt: timestamp),
            Block(rootDocId: sub11Id, parentId: sub11Id, type: .heading2, content: "Heartbeats and Randomized Election Timers", sortOrder: 3, createdAt: timestamp, updatedAt: timestamp),
            Block(rootDocId: sub11Id, parentId: sub11Id, type: .paragraph, content: "Followers remain passive until their randomized election timer (150ms–300ms) expires without receiving an AppendEntries heartbeat. Once expired, the node increments its currentTerm, converts to Candidate, and solicits votes.", sortOrder: 4, createdAt: timestamp, updatedAt: timestamp),
            Block(rootDocId: sub11Id, parentId: sub11Id, type: .codeBlock, content: "type RaftNode struct {\n    currentTerm int\n    votedFor    string\n    log         []LogEntry\n    commitIndex int\n}", sortOrder: 5, createdAt: timestamp, updatedAt: timestamp)
        ]
        for b in sub11Blocks { try b.insert(db) }

        // Sub-subtopic 1.2: Paxos
        let sub12Id = "doc-paxos"
        let sub12 = Block(id: sub12Id, rootDocId: sub12Id, parentId: sub1Id, type: .doc, content: "1.2 Paxos & Multi-Paxos Dynamics", sortOrder: 1, createdAt: timestamp, updatedAt: timestamp, notebookId: notebookId)
        try sub12.insert(db)
        let sub12Blocks: [Block] = [
            Block(rootDocId: sub12Id, parentId: sub12Id, type: .heading1, content: "Leslie Lamport's Paxos Algorithm", sortOrder: 1, createdAt: timestamp, updatedAt: timestamp),
            Block(rootDocId: sub12Id, parentId: sub12Id, type: .paragraph, content: "Phase 1: A proposer selects proposal number n and sends Prepare(n) to a majority of acceptors. Acceptors promise not to accept proposals numbered less than n.", sortOrder: 2, createdAt: timestamp, updatedAt: timestamp),
            Block(rootDocId: sub12Id, parentId: sub12Id, type: .callout, content: "Phase 2: If the proposer receives promises from a majority, it sends Accept(n, v). An overlapping majority guarantees proposal consistency via the pigeonhole principle.", sortOrder: 3, createdAt: timestamp, updatedAt: timestamp)
        ]
        for b in sub12Blocks { try b.insert(db) }

        // Sub-subtopic 1.3: BFT
        let sub13Id = "doc-bft"
        let sub13 = Block(id: sub13Id, rootDocId: sub13Id, parentId: sub1Id, type: .doc, content: "1.3 Byzantine Fault Tolerance (BFT)", sortOrder: 2, createdAt: timestamp, updatedAt: timestamp, notebookId: notebookId)
        try sub13.insert(db)
        try Block(rootDocId: sub13Id, parentId: sub13Id, type: .heading1, content: "Byzantine Generals & Malicious Failure Models", sortOrder: 1, createdAt: timestamp, updatedAt: timestamp).insert(db)
        try Block(rootDocId: sub13Id, parentId: sub13Id, type: .callout, content: "Practical Byzantine Fault Tolerance (PBFT) operates across Pre-Prepare, Prepare, and Commit phases, requiring N >= 3f + 1 nodes to safely withstand f rogue actors.", sortOrder: 2, createdAt: timestamp, updatedAt: timestamp).insert(db)

        // --- SUBTOPIC 2: Storage Engine Internals ---
        let sub2Id = "doc-storage-engines"
        let sub2 = Block(id: sub2Id, rootDocId: sub2Id, parentId: rootDocId, type: .doc, content: "2. Storage Engine Internals", sortOrder: 1, createdAt: timestamp, updatedAt: timestamp, notebookId: notebookId)
        try sub2.insert(db)
        try Block(rootDocId: sub2Id, parentId: sub2Id, type: .heading1, content: "LSM-Trees vs B+ Trees", sortOrder: 1, createdAt: timestamp, updatedAt: timestamp).insert(db)
        try Block(rootDocId: sub2Id, parentId: sub2Id, type: .paragraph, content: "Storage engines are primarily divided into update-in-place B+ Trees and append-only Log-Structured Merge-Trees.", sortOrder: 2, createdAt: timestamp, updatedAt: timestamp).insert(db)

        // Sub-subtopic 2.1: LSM-Trees
        let sub21Id = "doc-lsm"
        let sub21 = Block(id: sub21Id, rootDocId: sub21Id, parentId: sub2Id, type: .doc, content: "2.1 Log-Structured Merge-Trees (LSM-Trees)", sortOrder: 0, createdAt: timestamp, updatedAt: timestamp, notebookId: notebookId)
        try sub21.insert(db)
        let sub21Blocks: [Block] = [
            Block(rootDocId: sub21Id, parentId: sub21Id, type: .heading1, content: "Sequential Disk I/O & Compaction", sortOrder: 1, createdAt: timestamp, updatedAt: timestamp),
            Block(rootDocId: sub21Id, parentId: sub21Id, type: .callout, content: "All writes enter an in-memory MemTable and append to a Write-Ahead Log. Flushed MemTables become immutable SSTables organized into tiered or leveled hierarchies.", sortOrder: 2, createdAt: timestamp, updatedAt: timestamp),
            Block(rootDocId: sub21Id, parentId: sub21Id, type: .paragraph, content: "Bloom filters are calculated for every SSTable to eliminate disk I/O when looking up keys that do not exist.", sortOrder: 3, createdAt: timestamp, updatedAt: timestamp)
        ]
        for b in sub21Blocks { try b.insert(db) }

        // Sub-subtopic 2.2: B+ Trees
        let sub22Id = "doc-btree"
        let sub22 = Block(id: sub22Id, rootDocId: sub22Id, parentId: sub2Id, type: .doc, content: "2.2 B+ Tree Indexing & Page Layout", sortOrder: 1, createdAt: timestamp, updatedAt: timestamp, notebookId: notebookId)
        try sub22.insert(db)
        try Block(rootDocId: sub22Id, parentId: sub22Id, type: .heading1, content: "Page-Oriented B+ Tree Storage", sortOrder: 1, createdAt: timestamp, updatedAt: timestamp).insert(db)
        try Block(rootDocId: sub22Id, parentId: sub22Id, type: .callout, content: "Internal nodes only store router keys; all record payloads reside in leaf pages. Leaves are chained in a doubly-linked list for optimal range scans.", sortOrder: 2, createdAt: timestamp, updatedAt: timestamp).insert(db)

        // Sub-subtopic 2.3: WAL & ARIES
        let sub23Id = "doc-wal-aries"
        let sub23 = Block(id: sub23Id, rootDocId: sub23Id, parentId: sub2Id, type: .doc, content: "2.3 Write-Ahead Logging & ARIES Recovery", sortOrder: 2, createdAt: timestamp, updatedAt: timestamp, notebookId: notebookId)
        try sub23.insert(db)
        try Block(rootDocId: sub23Id, parentId: sub23Id, type: .heading1, content: "Crash Recovery with ARIES", sortOrder: 1, createdAt: timestamp, updatedAt: timestamp).insert(db)
        try Block(rootDocId: sub23Id, parentId: sub23Id, type: .callout, content: "Three phases: Analysis (finds dirty pages), Redo (repeats history to crash state), and Undo (reverses uncommitted transactions).", sortOrder: 2, createdAt: timestamp, updatedAt: timestamp).insert(db)

        // --- SUBTOPIC 3: Concurrency Control & Isolation ---
        let sub3Id = "doc-transactions"
        let sub3 = Block(id: sub3Id, rootDocId: sub3Id, parentId: rootDocId, type: .doc, content: "3. Concurrency Control & Isolation", sortOrder: 2, createdAt: timestamp, updatedAt: timestamp, notebookId: notebookId)
        try sub3.insert(db)
        try Block(rootDocId: sub3Id, parentId: sub3Id, type: .heading1, content: "ACID Isolation Levels & Anomalies", sortOrder: 1, createdAt: timestamp, updatedAt: timestamp).insert(db)

        // Sub-subtopic 3.1: MVCC
        let sub31Id = "doc-mvcc"
        let sub31 = Block(id: sub31Id, rootDocId: sub31Id, parentId: sub3Id, type: .doc, content: "3.1 Multi-Version Concurrency Control (MVCC)", sortOrder: 0, createdAt: timestamp, updatedAt: timestamp, notebookId: notebookId)
        try sub31.insert(db)
        try Block(rootDocId: sub31Id, parentId: sub31Id, type: .heading1, content: "Snapshot Isolation & Version Chains", sortOrder: 1, createdAt: timestamp, updatedAt: timestamp).insert(db)
        try Block(rootDocId: sub31Id, parentId: sub31Id, type: .callout, content: "Readers view a consistent snapshot based on their transaction start timestamp without taking shared read locks. Writers create new row versions.", sortOrder: 2, createdAt: timestamp, updatedAt: timestamp).insert(db)

        // Sub-subtopic 3.2: 2PL
        let sub32Id = "doc-2pl"
        let sub32 = Block(id: sub32Id, rootDocId: sub32Id, parentId: sub3Id, type: .doc, content: "3.2 Two-Phase Locking (2PL) & Deadlocks", sortOrder: 1, createdAt: timestamp, updatedAt: timestamp, notebookId: notebookId)
        try sub32.insert(db)
        try Block(rootDocId: sub32Id, parentId: sub32Id, type: .heading1, content: "Pessimistic Concurrency Control", sortOrder: 1, createdAt: timestamp, updatedAt: timestamp).insert(db)
        try Block(rootDocId: sub32Id, parentId: sub32Id, type: .callout, content: "Strict 2PL prevents cascading aborts by holding all exclusive write locks until the transaction commits or aborts.", sortOrder: 2, createdAt: timestamp, updatedAt: timestamp).insert(db)

        // --- 11 NOTE-GENERATED FLASHCARDS ---
        let noteCards: [Flashcard] = [
            Flashcard(
                id: "fc-mock-raft-election",
                docId: sub11Id,
                notebookId: notebookId,
                deckId: Deck.notesDefaultId,
                front: "In the Raft consensus protocol, what triggers a follower node to convert to a candidate?",
                back: "Expiration of its randomized election timer (150ms–300ms) without receiving an AppendEntries heartbeat or RequestVote message.",
                hint: "Election timeout expiration"
            ),
            Flashcard(
                id: "fc-mock-raft-safety",
                docId: sub11Id,
                notebookId: notebookId,
                deckId: Deck.notesDefaultId,
                front: "Define the Leader Completeness safety invariant in Raft.",
                back: "If a log entry is committed in a given term, that entry will be present in the logs of the leaders for all higher-numbered terms.",
                hint: "Committed logs persist across leader terms"
            ),
            Flashcard(
                id: "fc-mock-paxos-quorum",
                docId: sub12Id,
                notebookId: notebookId,
                deckId: Deck.notesDefaultId,
                front: "Why do Paxos Phase 1 (Prepare) and Phase 2 (Accept) require overlapping majority quorums?",
                back: "By the pigeonhole principle, any two majorities must intersect in at least one acceptor, guaranteeing Phase 2 sees any previously accepted value.",
                hint: "Pigeonhole principle & quorum overlap"
            ),
            Flashcard(
                id: "fc-mock-bft-formula",
                docId: sub13Id,
                notebookId: notebookId,
                deckId: Deck.notesDefaultId,
                front: "What is the minimum cluster size N required in Byzantine Fault Tolerance (BFT) to tolerate f arbitrary malicious nodes?",
                back: "N >= 3f + 1 nodes. Even if f nodes lie and f nodes are delayed, the remaining f + 1 honest responses form a decisive majority of the 2f + 1 quorum.",
                hint: "3f + 1 formula"
            ),
            Flashcard(
                id: "fc-mock-lsm-path",
                docId: sub21Id,
                notebookId: notebookId,
                deckId: Deck.notesDefaultId,
                front: "What are the two components of the initial write path in an LSM-Tree storage engine?",
                back: "1. Append to the on-disk Write-Ahead Log (WAL) for durability.\n2. Insert into the in-memory MemTable (SkipList/Red-Black tree) for sorted fast indexing.",
                hint: "WAL + MemTable"
            ),
            Flashcard(
                id: "fc-mock-lsm-bloom",
                docId: sub21Id,
                notebookId: notebookId,
                deckId: Deck.notesDefaultId,
                front: "How do Bloom filters optimize the read path in Log-Structured Merge-Tree (LSM) architectures?",
                back: "They determine with 100% certainty if a key is ABSENT from an on-disk SSTable, preventing costly disk I/O seeks on cache misses.",
                hint: "Zero false negatives on absence check"
            ),
            Flashcard(
                id: "fc-mock-lsm-compaction",
                docId: sub21Id,
                notebookId: notebookId,
                deckId: Deck.notesDefaultId,
                front: "Compare Leveled Compaction with Size-Tiered Compaction in LSM-Tree databases.",
                back: "Size-Tiered compaction optimizes for high write throughput but suffers from ~100% space amplification. Leveled compaction maintains non-overlapping key ranges per level, reducing space amplification to ~10% at the cost of higher write amplification.",
                hint: "Write throughput vs space amplification"
            ),
            Flashcard(
                id: "fc-mock-btree-leaves",
                docId: sub22Id,
                notebookId: notebookId,
                deckId: Deck.notesDefaultId,
                front: "Why are leaf nodes in a B+ Tree structured as a doubly-linked list?",
                back: "To enable sequential range scans without traversing parent routing nodes, yielding optimal sequential disk read performance.",
                hint: "Sequential range queries without tree traversal"
            ),
            Flashcard(
                id: "fc-mock-aries-phases",
                docId: sub23Id,
                notebookId: notebookId,
                deckId: Deck.notesDefaultId,
                front: "List and describe the three sequential recovery phases in the ARIES crash recovery algorithm.",
                back: "1. Analysis: scans forward from checkpoint to identify active transactions and dirty pages.\n2. Redo: repeats history from oldest unwritten page to restore crash state.\n3. Undo: scans backward rolling back actions of uncommitted active transactions.",
                hint: "Analysis, Redo, Undo"
            ),
            Flashcard(
                id: "fc-mock-mvcc-isolation",
                docId: sub31Id,
                notebookId: notebookId,
                deckId: Deck.notesDefaultId,
                front: "How does Multi-Version Concurrency Control (MVCC) prevent reader-writer lock contention?",
                back: "Updates write a new version with the transaction's commit timestamp rather than overwriting in-place. Readers read the latest visible version as of their snapshot timestamp without taking shared locks.",
                hint: "Readers never block writers; writers never block readers"
            ),
            Flashcard(
                id: "fc-mock-mvcc-skew",
                docId: sub31Id,
                notebookId: notebookId,
                deckId: Deck.notesDefaultId,
                front: "Define the Write Skew anomaly under Snapshot Isolation.",
                back: "An anomaly where two concurrent transactions read overlapping data, satisfy integrity constraints independently, but write to disjoint keys in a way that violates a global constraint.",
                hint: "Concurrent disjoint writes based on overlapping reads"
            ),
            Flashcard(
                id: "fc-mock-2pl-strict",
                docId: sub32Id,
                notebookId: notebookId,
                deckId: Deck.notesDefaultId,
                front: "What is the critical rule of Strict Two-Phase Locking (SS2PL) and what problem does it eliminate?",
                back: "All exclusive (write) locks must be held until the transaction finishes (commit or abort). This eliminates cascading aborts (dirty reads by subsequent transactions).",
                hint: "Locks held until commit/abort prevents cascading rollbacks"
            )
        ]
        for card in noteCards { try card.insert(db) }
    }

    // MARK: - 2. Independent Custom Decks with Cards
    private static func seedIndependentDecks(into db: Database, timestamp: Date) throws {
        let nbId = "nb-welcome-kb"

        // Deck 1: Cognitive Neuroscience
        let deckNeuro = Deck(
            id: "deck-neuroscience",
            name: "Cognitive Neuroscience & Mind",
            description: "Neural mechanisms, memory consolidation, hippocampal pathways, and synaptic plasticity.",
            colorHex: "#8B5CF6",
            icon: "brain.head.profile",
            isNotesDefault: false,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try deckNeuro.insert(db)

        let neuroCards: [Flashcard] = [
            Flashcard(
                id: "fc-neuro-ltp",
                docId: "doc-dist-sys",
                notebookId: nbId,
                deckId: deckNeuro.id,
                front: "What is Long-Term Potentiation (LTP) and which receptor acts as its coincidence detector?",
                back: "LTP is persistent synaptic strengthening following high-frequency stimulation. The NMDA glutamate receptor acts as the coincidence detector, requiring both glutamate binding and postsynaptic depolarization to dislodge the Mg2+ block.",
                hint: "NMDA receptor & Mg2+ unblocking"
            ),
            Flashcard(
                id: "fc-neuro-consolidation",
                docId: "doc-dist-sys",
                notebookId: nbId,
                deckId: deckNeuro.id,
                front: "Explain the Standard Consolidation Theory of memory.",
                back: "The hippocampus rapidly binds multi-modal representations into episodic memory traces and directs the gradual, prolonged reorganization and stabilization of memories into neocortical networks.",
                hint: "Hippocampal to neocortical transfer"
            ),
            Flashcard(
                id: "fc-neuro-amnesia",
                docId: "doc-dist-sys",
                notebookId: nbId,
                deckId: deckNeuro.id,
                front: "Differentiate between anterograde and retrograde amnesia.",
                back: "Anterograde amnesia is the inability to encode new long-term declarative memories after brain damage (e.g. Patient H.M.). Retrograde amnesia is the loss of memories formed prior to the trauma.",
                hint: "New vs past declarative memory loss"
            ),
            Flashcard(
                id: "fc-neuro-amygdala",
                docId: "doc-dist-sys",
                notebookId: nbId,
                deckId: deckNeuro.id,
                front: "Which subcortical nucleus is central to Pavlovian fear conditioning and affective valence encoding?",
                back: "The Amygdala (specifically the basolateral amygdala complex).",
                hint: "Emotional valence and threat detection"
            )
        ]
        for card in neuroCards { try card.insert(db) }

        // Deck 2: Computer Architecture & Silicon
        let deckSilicon = Deck(
            id: "deck-silicon",
            name: "Computer Architecture & Silicon",
            description: "Instruction pipelining, cache coherency protocols, branch predictors, and memory barriers.",
            colorHex: "#10B981",
            icon: "cpu",
            isNotesDefault: false,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try deckSilicon.insert(db)

        let siliconCards: [Flashcard] = [
            Flashcard(
                id: "fc-silicon-mesi",
                docId: "doc-dist-sys",
                notebookId: nbId,
                deckId: deckSilicon.id,
                front: "What do the four states in the MESI cache coherency protocol represent?",
                back: "Modified (dirty, exclusive), Exclusive (clean, exclusive), Shared (clean, in multiple caches), and Invalid (stale/empty).",
                hint: "M, E, S, I states"
            ),
            Flashcard(
                id: "fc-silicon-btb",
                docId: "doc-dist-sys",
                notebookId: nbId,
                deckId: deckSilicon.id,
                front: "Distinguish between a Branch Target Buffer (BTB) and a Branch History Table (BHT).",
                back: "The BHT predicts whether a conditional branch will be taken or not taken; the BTB predicts the target instruction address of the branch before the instruction is decoded.",
                hint: "Direction prediction vs Target address cache"
            ),
            Flashcard(
                id: "fc-silicon-false-sharing",
                docId: "doc-dist-sys",
                notebookId: nbId,
                deckId: deckSilicon.id,
                front: "What is false sharing in multicore shared-memory systems?",
                back: "When threads on different cores update independent variables that happen to share the same cache line (typically 64 bytes), inducing continuous cache line invalidation and bus traffic.",
                hint: "Same cache line, independent variables"
            ),
            Flashcard(
                id: "fc-silicon-llsc",
                docId: "doc-dist-sys",
                notebookId: nbId,
                deckId: deckSilicon.id,
                front: "Why is Load-Linked / Store-Conditional (LL/SC) immune to the ABA problem that affects Compare-And-Swap (CAS)?",
                back: "LL/SC tracks any store to the monitored address between the load and the conditional store, failing if any write occurred even if the value was restored to 'A'.",
                hint: "Intervening write tracking"
            )
        ]
        for card in siliconCards { try card.insert(db) }

        // Deck 3: Cellular Biochemistry & Energetics
        let deckBiochem = Deck(
            id: "deck-biochem",
            name: "Cellular Biochemistry & Energetics",
            description: "Mitochondrial ATP synthesis, enzyme kinetics, glycolysis, and metabolic feedback.",
            colorHex: "#EC4899",
            icon: "flask",
            isNotesDefault: false,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try deckBiochem.insert(db)

        let biochemCards: [Flashcard] = [
            Flashcard(
                id: "fc-biochem-glycolysis",
                docId: "doc-dist-sys",
                notebookId: nbId,
                deckId: deckBiochem.id,
                front: "What is the net energetic yield from one molecule of glucose undergoing glycolysis?",
                back: "Net 2 ATP (4 produced minus 2 consumed in the preparatory phase), 2 NADH, and 2 Pyruvate.",
                hint: "2 ATP + 2 NADH + 2 Pyruvate"
            ),
            Flashcard(
                id: "fc-biochem-pfk1",
                docId: "doc-dist-sys",
                notebookId: nbId,
                deckId: deckBiochem.id,
                front: "Which enzyme serves as the primary rate-limiting pacemaker of glycolysis?",
                back: "Phosphofructokinase-1 (PFK-1), allosterically inhibited by high ATP and citrate, and activated by AMP and fructose-2,6-bisphosphate.",
                hint: "PFK-1 committed step"
            ),
            Flashcard(
                id: "fc-biochem-chemiosmosis",
                docId: "doc-dist-sys",
                notebookId: nbId,
                deckId: deckBiochem.id,
                front: "Describe the mechanism of Peter Mitchell's Chemiosmotic Hypothesis in mitochondria.",
                back: "Electrons transported down complexes I, III, and IV pump protons from the matrix into the intermembrane space, generating a proton motive force that drives rotational catalysis in ATP synthase.",
                hint: "Proton motive force & ATP synthase"
            ),
            Flashcard(
                id: "fc-biochem-km",
                docId: "doc-dist-sys",
                notebookId: nbId,
                deckId: deckBiochem.id,
                front: "What does the Michaelis constant (Km) signify in enzyme kinetics?",
                back: "The substrate concentration at which the reaction velocity is half of Vmax. A smaller Km indicates higher substrate binding affinity.",
                hint: "Substrate concentration at 1/2 Vmax"
            )
        ]
        for card in biochemCards { try card.insert(db) }
    }

    // MARK: - 3. Memory Palaces Designed with Stock Photos
    private static func seedMemoryPalaces(into db: Database, timestamp: Date) throws {
        // Palace 1: The Alexandrian Library of Philosophy
        let pal1Id = "mp-alexandria"
        let pal1 = MemoryPalace(
            id: pal1Id,
            name: "The Library of Alexandria",
            imagePath: "photo-alexandria-colonnade.jpg",
            description: "A vast classical repository of ancient thought with spatial loci mapped across the Grand Nave, the Celestial Rotunda, and the Marble Courtyard.",
            sortOrder: 1
        )
        try pal1.insert(db)

        let p1Photo1 = PalacePhoto(
            id: "photo-alex-1",
            palaceId: pal1Id,
            name: "1. The Grand Colonnade Nave",
            imagePath: "photo-alexandria-colonnade.jpg",
            orderIndex: 0,
            canvasX: 80.0,
            canvasY: 120.0,
            canvasWidth: 440.0,
            canvasHeight: 300.0
        )
        let p1Photo2 = PalacePhoto(
            id: "photo-alex-2",
            palaceId: pal1Id,
            name: "2. The Celestial Rotunda",
            imagePath: "photo-alexandria-rotunda.jpg",
            orderIndex: 1,
            canvasX: 580.0,
            canvasY: 120.0,
            canvasWidth: 440.0,
            canvasHeight: 300.0
        )
        let p1Photo3 = PalacePhoto(
            id: "photo-alex-3",
            palaceId: pal1Id,
            name: "3. The Marble Arcade Courtyard",
            imagePath: "photo-alexandria-courtyard.jpg",
            orderIndex: 2,
            canvasX: 1080.0,
            canvasY: 120.0,
            canvasWidth: 440.0,
            canvasHeight: 300.0
        )
        try p1Photo1.insert(db)
        try p1Photo2.insert(db)
        try p1Photo3.insert(db)

        let p1Loci: [PalaceLocus] = [
            PalaceLocus(
                id: "loc-alex-1",
                palaceId: pal1Id,
                photoId: p1Photo1.id,
                flashcardId: "fc-mock-raft-election",
                title: "1. Cedar Bookcases Colonnade",
                mnemonic: "Ancient towering cedar shelves glowing with phosphorescent green papyrus scrolls.",
                anchoredInfo: "The Library was founded under Ptolemy I Soter c. 283 BC and housed over 400,000 parchment scrolls.",
                normalizedX: 0.28,
                normalizedY: 0.42,
                orderIndex: 0
            ),
            PalaceLocus(
                id: "loc-alex-2",
                palaceId: pal1Id,
                photoId: p1Photo1.id,
                flashcardId: "fc-mock-paxos-quorum",
                title: "2. The Scribe's Lectern",
                mnemonic: "A solid bronze scribe writing with a diamond stylus into molten gold tablets.",
                anchoredInfo: "Callimachus compiled the Pinakes, the first comprehensive bibliographic catalog of ancient Greek literature.",
                normalizedX: 0.65,
                normalizedY: 0.72,
                orderIndex: 1
            ),
            PalaceLocus(
                id: "loc-alex-3",
                palaceId: pal1Id,
                photoId: p1Photo2.id,
                flashcardId: "fc-mock-lsm-bloom",
                title: "3. The Oculus of Alexandria",
                mnemonic: "A giant stained-glass eye at the apex casting concentrated beams of violet light.",
                anchoredInfo: "Eratosthenes accurately measured Earth's circumference (252,000 stadia, ~40,000 km) while serving as chief librarian.",
                normalizedX: 0.50,
                normalizedY: 0.25,
                orderIndex: 2
            ),
            PalaceLocus(
                id: "loc-alex-4",
                palaceId: pal1Id,
                photoId: p1Photo2.id,
                flashcardId: "fc-mock-aries-phases",
                title: "4. The Astrolabe Pedestal",
                mnemonic: "A rotating brass astrolabe orbiting with miniature sparkling planets.",
                anchoredInfo: "Hipparchus created the first known star catalogue containing 850 stars and discovered the precession of the equinoxes.",
                normalizedX: 0.52,
                normalizedY: 0.68,
                orderIndex: 3
            ),
            PalaceLocus(
                id: "loc-alex-5",
                palaceId: pal1Id,
                photoId: p1Photo3.id,
                flashcardId: "fc-mock-mvcc-isolation",
                title: "5. The Fountain of Hypatia",
                mnemonic: "Water droplets freezing in mid-air into crystalline mathematical equations.",
                anchoredInfo: "Hypatia of Alexandria taught philosophy and astronomy, editing Archimedes and Apollonius of Perga.",
                normalizedX: 0.45,
                normalizedY: 0.55,
                orderIndex: 4
            )
        ]
        for locus in p1Loci {
            try locus.insert(db)
            if let fcId = locus.flashcardId, !fcId.isEmpty {
                let link = LocusFlashcard(id: "lf-\(locus.id)-\(fcId)", locusId: locus.id, flashcardId: fcId, sortOrder: 0)
                try link.insert(db)
            }
        }

        // Palace 2: Villa Bellissima: The Renaissance Cloister
        let pal2Id = "mp-renaissance"
        let pal2 = MemoryPalace(
            id: pal2Id,
            name: "Villa Bellissima: The Renaissance Cloister",
            imagePath: "photo-villa-salon.jpg",
            description: "An Italian Renaissance estate featuring spatial loci through the Gilded Salon and the Panoramic Terrace.",
            sortOrder: 2
        )
        try pal2.insert(db)

        let p2Photo1 = PalacePhoto(
            id: "photo-villa-1",
            palaceId: pal2Id,
            name: "1. The Gilded Renaissance Salon",
            imagePath: "photo-villa-salon.jpg",
            orderIndex: 0,
            canvasX: 80.0,
            canvasY: 120.0,
            canvasWidth: 450.0,
            canvasHeight: 300.0
        )
        let p2Photo2 = PalacePhoto(
            id: "photo-villa-2",
            palaceId: pal2Id,
            name: "2. The Panoramic Garden Terrace",
            imagePath: "photo-villa-terrace.jpg",
            orderIndex: 1,
            canvasX: 580.0,
            canvasY: 120.0,
            canvasWidth: 450.0,
            canvasHeight: 300.0
        )
        try p2Photo1.insert(db)
        try p2Photo2.insert(db)

        let p2Loci: [PalaceLocus] = [
            PalaceLocus(
                id: "loc-villa-1",
                palaceId: pal2Id,
                photoId: p2Photo1.id,
                flashcardId: "fc-silicon-mesi",
                title: "1. The Carved Marble Fireplace",
                mnemonic: "Four flickering colored flames (Modified, Exclusive, Shared, Invalid) dancing in the grate.",
                anchoredInfo: "The MESI protocol invalidates cached cache-lines across symmetric multiprocessing interconnects.",
                normalizedX: 0.25,
                normalizedY: 0.60,
                orderIndex: 0
            ),
            PalaceLocus(
                id: "loc-villa-2",
                palaceId: pal2Id,
                photoId: p2Photo1.id,
                flashcardId: "fc-silicon-false-sharing",
                title: "2. The Ceiling Chandelier",
                mnemonic: "Crystal prisms swinging violently as two invisible pendulums strike the same crystal simultaneously.",
                anchoredInfo: "False sharing occurs when distinct threads modify independent variables residing on the same 64-byte cache line.",
                normalizedX: 0.50,
                normalizedY: 0.22,
                orderIndex: 1
            ),
            PalaceLocus(
                id: "loc-villa-3",
                palaceId: pal2Id,
                photoId: p2Photo2.id,
                flashcardId: "fc-biochem-chemiosmosis",
                title: "3. The Cypress Balustrade",
                mnemonic: "A torrential waterfall of glowing hydrogen ions rushing through a tiny spinning waterwheel.",
                anchoredInfo: "Peter Mitchell's chemiosmotic hypothesis explains ATP synthesis driven by proton-motive force across the inner mitochondrial membrane.",
                normalizedX: 0.70,
                normalizedY: 0.45,
                orderIndex: 2
            ),
            PalaceLocus(
                id: "loc-villa-4",
                palaceId: pal2Id,
                photoId: p2Photo2.id,
                flashcardId: "fc-biochem-glycolysis",
                title: "4. The Sunken Roman Bath",
                mnemonic: "Thermal water steaming with microscopic molecular turbines spinning at 9,000 RPM.",
                anchoredInfo: "ATP synthase F0 rotor subunit rotates at over 100 revolutions per second during proton translocation.",
                normalizedX: 0.30,
                normalizedY: 0.75,
                orderIndex: 3
            )
        ]
        for locus in p2Loci {
            try locus.insert(db)
            if let fcId = locus.flashcardId, !fcId.isEmpty {
                let link = LocusFlashcard(id: "lf-\(locus.id)-\(fcId)", locusId: locus.id, flashcardId: fcId, sortOrder: 0)
                try link.insert(db)
            }
        }
    }
}
