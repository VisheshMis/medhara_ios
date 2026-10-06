// Medha Windows Desktop — Database Seeder
// Mirrors MockDataSeeder.swift to provide rich demonstration content on first launch.

const MockDataSeeder = {
    seedIfMissing(db) {
        const now = new Date().toISOString();
        const nbId = 'nb-welcome-kb';

        // 1. Ensure default notebook exists
        const nb = db.prepare('SELECT 1 FROM notebook WHERE id = ?').get(nbId);
        if (!nb) {
            db.prepare(`
                INSERT INTO notebook (id, name, icon, sortOrder)
                VALUES (?, ?, ?, ?)
            `).run(nbId, 'Knowledge Base', 'brain.head.profile', 0);
        }

        // Second notebook
        const nb2 = db.prepare('SELECT 1 FROM notebook WHERE id = ?').get('nb-personal');
        if (!nb2) {
            db.prepare(`
                INSERT INTO notebook (id, name, icon, sortOrder)
                VALUES (?, ?, ?, ?)
            `).run('nb-personal', 'Research & Projects', 'folder.fill', 1);
        }

        // 2. Ensure default notes deck exists
        const defDeck = db.prepare('SELECT 1 FROM deck WHERE id = ?').get('deck-notes-default');
        if (!defDeck) {
            db.prepare(`
                INSERT INTO deck (id, name, description, colorHex, icon, isNotesDefault, createdAt, updatedAt)
                VALUES (?, ?, ?, ?, ?, 1, ?, ?)
            `).run(
                'deck-notes-default',
                'Notes & Documents',
                'Auto-grouped collection of all flashcards generated or linked to the notes and folder hierarchy',
                '#3B82F6',
                'note.text',
                now,
                now
            );
        }

        // 3. Seed Notes Hierarchy
        const rootDoc = db.prepare('SELECT 1 FROM block WHERE id = ?').get('doc-dist-sys');
        if (!rootDoc) {
            this.seedNotesHierarchy(db, nbId, now);
        }

        // 4. Seed Custom Decks
        const neuroDeck = db.prepare('SELECT 1 FROM deck WHERE id = ?').get('deck-neuroscience');
        if (!neuroDeck) {
            this.seedCustomDecks(db, now);
        }

        // 5. Seed Memory Palaces
        const alexandria = db.prepare('SELECT 1 FROM memory_palace WHERE id = ?').get('mp-alexandria');
        if (!alexandria) {
            this.seedMemoryPalaces(db, now);
        }

        // 6. Seed Demo Ink Document
        const inkDoc = db.prepare('SELECT 1 FROM block WHERE id = ?').get('doc-ink-demo');
        if (!inkDoc) {
            this.seedDemoInkDocument(db, nbId, now);
        }
    },

    seedNotesHierarchy(db, notebookId, timestamp) {
        const insertBlock = db.prepare(`
            INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, isCompleted, refTargetId, createdAt, updatedAt, notebookId)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `);

        // Root Doc
        const rootDocId = 'doc-dist-sys';
        insertBlock.run(rootDocId, rootDocId, null, 'doc', 'Distributed Systems & Storage Engines', 0, null, null, timestamp, timestamp, notebookId);

        insertBlock.run('b-root-1', rootDocId, rootDocId, 'heading1', 'Architectural Foundations of Modern Data Systems', 1, null, null, timestamp, timestamp, null);
        insertBlock.run('b-root-2', rootDocId, rootDocId, 'callout', 'This comprehensive knowledge tree explores state machine replication, low-latency disk engines, and ACID isolation.', 2, null, null, timestamp, timestamp, null);
        insertBlock.run('b-root-3', rootDocId, rootDocId, 'paragraph', 'Modern cloud databases balance the trade-offs formalized in the CAP theorem and PACELC model. See [[1. Consensus & Replication]] for distributed safety.', 3, null, null, timestamp, timestamp, null);
        insertBlock.run('b-root-4', rootDocId, rootDocId, 'taskList', 'Master Raft leader election invariants and log matching safety', 4, 1, null, timestamp, timestamp, null);
        insertBlock.run('b-root-5', rootDocId, rootDocId, 'taskList', 'Contrast LSM-Tree write amplification with B+ Tree page splits', 5, 1, null, timestamp, timestamp, null);
        insertBlock.run('b-root-6', rootDocId, rootDocId, 'quote', 'There are only two hard things in Computer Science: cache invalidation and naming things. — Phil Karlton', 6, null, null, timestamp, timestamp, null);

        // Subtopic 1: Consensus
        const sub1Id = 'doc-consensus';
        insertBlock.run(sub1Id, sub1Id, rootDocId, 'doc', '1. Consensus & Replication', 0, null, null, timestamp, timestamp, notebookId);
        insertBlock.run('b-sub1-1', sub1Id, sub1Id, 'heading1', 'The Distributed Consensus Challenge', 1, null, null, timestamp, timestamp, null);
        insertBlock.run('b-sub1-2', sub1Id, sub1Id, 'paragraph', 'Consensus protocols allow a cluster of machines to work as a coherent group surviving network partitions and node crashes.', 2, null, null, timestamp, timestamp, null);

        // Sub-subtopic 1.1: Raft
        const sub11Id = 'doc-raft';
        insertBlock.run(sub11Id, sub11Id, sub1Id, 'doc', '1.1 Raft Consensus Protocol', 0, null, null, timestamp, timestamp, notebookId);
        insertBlock.run('b-raft-1', sub11Id, sub11Id, 'heading1', 'Raft: Understandable Distributed Consensus', 1, null, null, timestamp, timestamp, null);
        insertBlock.run('b-raft-2', sub11Id, sub11Id, 'paragraph', 'Raft decomposes consensus into Leader Election, Log Replication, and Safety invariants.', 2, null, null, timestamp, timestamp, null);
        insertBlock.run('b-raft-3', sub11Id, sub11Id, 'codeBlock', '// Raft AppendEntries RPC\ntype AppendEntriesArgs struct {\n    Term         int\n    LeaderId     int\n    PrevLogIndex int\n    PrevLogTerm  int\n    Entries      []LogEntry\n    LeaderCommit int\n}', 3, null, null, timestamp, timestamp, null);

        // Generate Flashcards for notes
        const insertCard = db.prepare(`
            INSERT INTO flashcard (id, docId, notebookId, front, back, sourceBlockId, hint, fsrsState, stability, difficulty, elapsedDays, scheduledDays, reps, lapses, lastReview, due, createdAt, updatedAt, deckId, isSuspended)
            VALUES (?, ?, ?, ?, ?, ?, ?, 0, 0.0, 0.0, 0, 0, 0, 0, null, ?, ?, ?, 'deck-notes-default', 0)
        `);

        insertCard.run('fc-raft-1', sub11Id, notebookId, 'What are the three core subproblems in the Raft consensus algorithm?', '1. Leader Election\n2. Log Replication\n3. Safety Invariants', 'b-raft-2', 'Think of the three decomposed phases', timestamp, timestamp, timestamp);
        insertCard.run('fc-raft-2', sub11Id, notebookId, 'Under what condition does a Raft candidate win an election?', 'When it receives votes from a strict quorum (majority) of cluster servers for the current term.', 'b-raft-2', 'Majority requirement', timestamp, timestamp, timestamp);

        // Subtopic 2: Storage Engines
        const sub2Id = 'doc-lsm';
        insertBlock.run(sub2Id, sub2Id, rootDocId, 'doc', '2. LSM-Trees vs B+ Trees', 1, null, null, timestamp, timestamp, notebookId);
        insertBlock.run('b-lsm-1', sub2Id, sub2Id, 'heading1', 'Log-Structured Merge-Trees (LSM)', 1, null, null, timestamp, timestamp, null);
        insertBlock.run('b-lsm-2', sub2Id, sub2Id, 'paragraph', 'LSM-Trees append all writes sequentially to an in-memory MemTable and commit log, flushing immutable SSTables to disk.', 2, null, null, timestamp, timestamp, null);

        insertCard.run('fc-lsm-1', sub2Id, notebookId, 'Why do LSM-Trees outperform B+ Trees on write-heavy workloads?', 'LSM-Trees transform random disk writes into sequential append-only writes via in-memory buffering (MemTable) and background compaction.', 'b-lsm-2', 'Random vs sequential I/O', timestamp, timestamp, timestamp);
    },

    seedCustomDecks(db, timestamp) {
        db.prepare(`
            INSERT INTO deck (id, name, description, colorHex, icon, isNotesDefault, createdAt, updatedAt)
            VALUES (?, ?, ?, ?, ?, 0, ?, ?)
        `).run(
            'deck-neuroscience',
            'Cognitive Neuroscience & Memory',
            'Synaptic plasticity, long-term potentiation, hippocampal spatial maps, and cognitive architectures',
            '#8B5CF6',
            'brain.head.profile',
            timestamp,
            timestamp
        );

        const insertCard = db.prepare(`
            INSERT INTO flashcard (id, docId, notebookId, front, back, sourceBlockId, hint, fsrsState, stability, difficulty, elapsedDays, scheduledDays, reps, lapses, lastReview, due, createdAt, updatedAt, deckId, isSuspended)
            VALUES (?, ?, ?, ?, ?, null, ?, 0, 0.0, 0.0, 0, 0, 0, 0, null, ?, ?, ?, 'deck-neuroscience', 0)
        `);

        insertCard.run('fc-neuro-1', 'doc-neuro', 'nb-welcome-kb', 'What molecular mechanism underlies Long-Term Potentiation (LTP)?', 'Activation of NMDA glutamate receptors leads to Ca2+ influx and insertion of AMPA receptors into the postsynaptic density.', 'NMDA / AMPA receptor dynamic', timestamp, timestamp, timestamp);
        insertCard.run('fc-neuro-2', 'doc-neuro', 'nb-welcome-kb', 'Which brain structure provides the neural substrate for the Method of Loci?', 'The Hippocampus (specifically place cells in CA1/CA3 and grid cells in the entorhinal cortex).', 'Spatial cognitive map', timestamp, timestamp, timestamp);
    },

    seedMemoryPalaces(db, timestamp) {
        // Memory Palace: Royal Library of Alexandria
        db.prepare(`
            INSERT INTO memory_palace (id, name, imagePath, imageData, description, sortOrder, createdAt, updatedAt)
            VALUES (?, ?, ?, null, ?, 0, ?, ?)
        `).run(
            'mp-alexandria',
            'The Grand Library Hall',
            'stock-library.jpg',
            'A magnificent two-story library atrium featuring classical marble colonnades, grand staircase, and vaulted skylight.',
            timestamp,
            timestamp
        );

        // Photo 1
        db.prepare(`
            INSERT INTO palace_photo (id, palaceId, name, imagePath, imageData, orderIndex, canvasX, canvasY, canvasWidth, canvasHeight, createdAt, updatedAt)
            VALUES (?, ?, ?, ?, null, 0, 100.0, 100.0, 520.0, 360.0, ?, ?)
        `).run(
            'photo-mp-alexandria-1',
            'mp-alexandria',
            'Main Reading Atrium',
            'stock-library.jpg',
            timestamp,
            timestamp
        );

        // Photo 2
        db.prepare(`
            INSERT INTO palace_photo (id, palaceId, name, imagePath, imageData, orderIndex, canvasX, canvasY, canvasWidth, canvasHeight, createdAt, updatedAt)
            VALUES (?, ?, ?, ?, null, 1, 660.0, 100.0, 520.0, 360.0, ?, ?)
        `).run(
            'photo-mp-alexandria-2',
            'mp-alexandria',
            'Upper Gallery Archives',
            'stock-gallery.jpg',
            timestamp,
            timestamp
        );

        // Loci Pins
        const insertLocus = db.prepare(`
            INSERT INTO palace_locus (id, palaceId, photoId, flashcardId, docId, title, mnemonic, anchoredInfo, normalizedX, normalizedY, orderIndex, createdAt, updatedAt)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `);

        insertLocus.run(
            'locus-1',
            'mp-alexandria',
            'photo-mp-alexandria-1',
            'fc-raft-1',
            'doc-raft',
            '1. Grand Marble Colonnade',
            'Visualize three statues holding elected ballots representing the three Raft pillars.',
            'Leader Election, Log Replication, Safety Invariants.',
            0.24,
            0.48,
            0,
            timestamp,
            timestamp
        );

        insertLocus.run(
            'locus-2',
            'mp-alexandria',
            'photo-mp-alexandria-1',
            'fc-raft-2',
            'doc-raft',
            '2. Central Fountain & Basin',
            'A massive quorum of scholars raising their hands to vote for the new leader.',
            'Majority quorum rule for candidate election.',
            0.52,
            0.65,
            1,
            timestamp,
            timestamp
        );

        insertLocus.run(
            'locus-3',
            'mp-alexandria',
            'photo-mp-alexandria-2',
            'fc-lsm-1',
            'doc-lsm',
            '3. Spiral Wooden Staircase',
            'A conveyor belt smoothly carrying stacks of parchment upstairs (sequential writes vs random hopping).',
            'LSM sequential write speed vs B+ tree random page splits.',
            0.78,
            0.35,
            2,
            timestamp,
            timestamp
        );

        // Link locus to flashcards
        const insertLF = db.prepare(`
            INSERT OR IGNORE INTO locus_flashcard (id, locusId, flashcardId, sortOrder, createdAt)
            VALUES (?, ?, ?, ?, ?)
        `);
        insertLF.run('lf-locus-1-fc-raft-1', 'locus-1', 'fc-raft-1', 0, timestamp);
        insertLF.run('lf-locus-2-fc-raft-2', 'locus-2', 'fc-raft-2', 0, timestamp);
        insertLF.run('lf-locus-3-fc-lsm-1', 'locus-3', 'fc-lsm-1', 0, timestamp);
    },

    seedDemoInkDocument(db, notebookId, timestamp) {
        const docId = 'doc-ink-demo';
        db.prepare(`
            INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, isCompleted, refTargetId, createdAt, updatedAt, notebookId)
            VALUES (?, ?, null, 'inkDoc', ?, 3, null, null, ?, ?, ?)
        `).run(docId, docId, 'Handwritten Ink Note: Math & Circuit Sketches', timestamp, timestamp, notebookId);

        // Seed a sample vector ink page
        const samplePageData = {
            schemaVersion: 1,
            pageWidth: 794.0,
            pageHeight: 1123.0,
            strokes: [
                {
                    id: 's-demo-1',
                    tool: 'ballpoint',
                    colorHex: '#1E293B',
                    baseWidth: 2.8,
                    opacity: 1.0,
                    points: [
                        { x: 120, y: 150, p: 0.5, t: 0 },
                        { x: 140, y: 145, p: 0.6, t: 16 },
                        { x: 180, y: 155, p: 0.7, t: 32 },
                        { x: 220, y: 148, p: 0.5, t: 48 },
                        { x: 260, y: 152, p: 0.4, t: 64 }
                    ]
                },
                {
                    id: 's-demo-2',
                    tool: 'highlighter',
                    colorHex: '#FBBF24',
                    baseWidth: 16.0,
                    opacity: 0.4,
                    points: [
                        { x: 110, y: 150, p: 0.8, t: 0 },
                        { x: 270, y: 150, p: 0.8, t: 50 }
                    ]
                }
            ]
        };

        db.prepare(`
            INSERT INTO ink_document_page (id, docId, pageIndex, templateType, strokesData, textProjection, createdAt, updatedAt)
            VALUES (?, ?, 0, 'lined', ?, 'Sample Math Handwritten Derivations', ?, ?)
        `).run(`inkpage-${docId}-0`, docId, JSON.stringify(samplePageData), timestamp, timestamp);
    }
};

module.exports = { MockDataSeeder };
