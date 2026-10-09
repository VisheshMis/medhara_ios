// Medha Windows Desktop — Database Migrations (v1 to v9)
// 100% faithful port of DatabaseMigrations.swift using SQLite & FTS5

const DatabaseMigrations = {
    registerMigrations(db) {
        // Ensure schema_migrations table exists
        db.exec(`
            CREATE TABLE IF NOT EXISTS schema_migrations (
                identifier TEXT PRIMARY KEY,
                applied_at DATETIME NOT NULL
            );
        `);

        const isMigrationApplied = (id) => {
            const row = db.prepare('SELECT 1 FROM schema_migrations WHERE identifier = ?').get(id);
            return !!row;
        };
        const markMigrationApplied = (id) => {
            db.prepare("INSERT INTO schema_migrations (identifier, applied_at) VALUES (?, datetime('now'))").run(id);
        };
        const runMigration = (id, fn) => {
            if (!isMigrationApplied(id)) {
                db.transaction(() => {
                    fn();
                    markMigrationApplied(id);
                })();
            }
        };

        // v1: Initial Schema (Notebooks, Blocks, Relational Indexes, FTS5 virtual table & triggers)
        runMigration('v1_initial_schema', () => {
            db.exec(`
                CREATE TABLE IF NOT EXISTS notebook (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    icon TEXT,
                    sortOrder INTEGER NOT NULL DEFAULT 0
                );

                CREATE TABLE IF NOT EXISTS block (
                    id TEXT PRIMARY KEY,
                    rootDocId TEXT NOT NULL,
                    parentId TEXT,
                    type TEXT NOT NULL,
                    content TEXT NOT NULL,
                    sortOrder INTEGER NOT NULL DEFAULT 0,
                    isCompleted BOOLEAN,
                    refTargetId TEXT,
                    createdAt DATETIME NOT NULL,
                    updatedAt DATETIME NOT NULL,
                    notebookId TEXT
                );

                CREATE INDEX IF NOT EXISTS idx_block_rootDocId ON block(rootDocId);
                CREATE INDEX IF NOT EXISTS idx_block_parentId ON block(parentId);
                CREATE INDEX IF NOT EXISTS idx_block_notebookId ON block(notebookId);
                CREATE INDEX IF NOT EXISTS idx_block_refTargetId ON block(refTargetId);
                CREATE INDEX IF NOT EXISTS idx_block_sortOrder ON block(sortOrder);

                CREATE VIRTUAL TABLE IF NOT EXISTS block_fts USING fts5(
                    id UNINDEXED,
                    rootDocId UNINDEXED,
                    content,
                    type UNINDEXED,
                    tokenize = 'unicode61'
                );

                CREATE TRIGGER IF NOT EXISTS block_after_insert AFTER INSERT ON block
                BEGIN
                    INSERT INTO block_fts(id, rootDocId, content, type)
                    VALUES (new.id, new.rootDocId, new.content, new.type);
                END;

                CREATE TRIGGER IF NOT EXISTS block_after_update AFTER UPDATE ON block
                BEGIN
                    DELETE FROM block_fts WHERE id = old.id;
                    INSERT INTO block_fts(id, rootDocId, content, type)
                    VALUES (new.id, new.rootDocId, new.content, new.type);
                END;

                CREATE TRIGGER IF NOT EXISTS block_after_delete AFTER DELETE ON block
                BEGIN
                    DELETE FROM block_fts WHERE id = old.id;
                END;
            `);
        });

        // v2: Flashcards (FSRS parameters) and Memory Palaces
        runMigration('v2_flashcards_and_palaces', () => {
            db.exec(`
                CREATE TABLE IF NOT EXISTS flashcard (
                    id TEXT PRIMARY KEY,
                    docId TEXT NOT NULL,
                    notebookId TEXT NOT NULL,
                    front TEXT NOT NULL,
                    back TEXT NOT NULL,
                    sourceBlockId TEXT,
                    hint TEXT,
                    fsrsState INTEGER NOT NULL DEFAULT 0,
                    stability REAL NOT NULL DEFAULT 0.0,
                    difficulty REAL NOT NULL DEFAULT 0.0,
                    elapsedDays INTEGER NOT NULL DEFAULT 0,
                    scheduledDays INTEGER NOT NULL DEFAULT 0,
                    reps INTEGER NOT NULL DEFAULT 0,
                    lapses INTEGER NOT NULL DEFAULT 0,
                    lastReview DATETIME,
                    due DATETIME NOT NULL,
                    createdAt DATETIME NOT NULL,
                    updatedAt DATETIME NOT NULL
                );

                CREATE INDEX IF NOT EXISTS idx_flashcard_docId ON flashcard(docId);
                CREATE INDEX IF NOT EXISTS idx_flashcard_notebookId ON flashcard(notebookId);
                CREATE INDEX IF NOT EXISTS idx_flashcard_due ON flashcard(due);
                CREATE INDEX IF NOT EXISTS idx_flashcard_fsrsState ON flashcard(fsrsState);

                CREATE TABLE IF NOT EXISTS review_log (
                    id TEXT PRIMARY KEY,
                    cardId TEXT NOT NULL,
                    rating INTEGER NOT NULL,
                    state TEXT NOT NULL,
                    elapsedDays INTEGER NOT NULL DEFAULT 0,
                    scheduledDays INTEGER NOT NULL DEFAULT 0,
                    reviewTime DATETIME NOT NULL
                );

                CREATE INDEX IF NOT EXISTS idx_review_log_cardId ON review_log(cardId);
                CREATE INDEX IF NOT EXISTS idx_review_log_reviewTime ON review_log(reviewTime);

                CREATE TABLE IF NOT EXISTS memory_palace (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    imagePath TEXT NOT NULL,
                    imageData TEXT,
                    description TEXT,
                    sortOrder INTEGER NOT NULL DEFAULT 0,
                    createdAt DATETIME NOT NULL,
                    updatedAt DATETIME NOT NULL
                );

                CREATE TABLE IF NOT EXISTS palace_locus (
                    id TEXT PRIMARY KEY,
                    palaceId TEXT NOT NULL,
                    flashcardId TEXT,
                    docId TEXT,
                    title TEXT NOT NULL,
                    mnemonic TEXT,
                    normalizedX REAL NOT NULL,
                    normalizedY REAL NOT NULL,
                    orderIndex INTEGER NOT NULL DEFAULT 0,
                    createdAt DATETIME NOT NULL,
                    updatedAt DATETIME NOT NULL
                );

                CREATE INDEX IF NOT EXISTS idx_palace_locus_palaceId ON palace_locus(palaceId);
                CREATE INDEX IF NOT EXISTS idx_palace_locus_flashcardId ON palace_locus(flashcardId);
            `);
        });

        // v3: Bidirectional Links to Graph (doc_link)
        runMigration('v3_links_to_graph', () => {
            db.exec(`
                CREATE TABLE IF NOT EXISTS doc_link (
                    id TEXT PRIMARY KEY,
                    sourceDocId TEXT NOT NULL,
                    sourceBlockId TEXT NOT NULL,
                    targetTitle TEXT NOT NULL,
                    targetDocId TEXT,
                    createdAt DATETIME NOT NULL
                );

                CREATE INDEX IF NOT EXISTS idx_doc_link_sourceDocId ON doc_link(sourceDocId);
                CREATE INDEX IF NOT EXISTS idx_doc_link_targetDocId ON doc_link(targetDocId);
                CREATE INDEX IF NOT EXISTS idx_doc_link_targetTitle ON doc_link(targetTitle);
            `);
        });

        // v4: Multi-photo Palace and Locus Anchors
        runMigration('v4_multiphoto_palace_and_locus_anchors', () => {
            db.exec(`
                CREATE TABLE IF NOT EXISTS palace_photo (
                    id TEXT PRIMARY KEY,
                    palaceId TEXT NOT NULL,
                    name TEXT NOT NULL,
                    imagePath TEXT NOT NULL,
                    imageData TEXT,
                    orderIndex INTEGER NOT NULL DEFAULT 0,
                    createdAt DATETIME NOT NULL,
                    updatedAt DATETIME NOT NULL
                );

                CREATE INDEX IF NOT EXISTS idx_palace_photo_palaceId ON palace_photo(palaceId);
                CREATE INDEX IF NOT EXISTS idx_palace_photo_orderIndex ON palace_photo(orderIndex);

                CREATE TABLE IF NOT EXISTS locus_flashcard (
                    id TEXT PRIMARY KEY,
                    locusId TEXT NOT NULL,
                    flashcardId TEXT NOT NULL,
                    sortOrder INTEGER NOT NULL DEFAULT 0,
                    createdAt DATETIME NOT NULL
                );

                CREATE INDEX IF NOT EXISTS idx_locus_flashcard_locusId ON locus_flashcard(locusId);
                CREATE INDEX IF NOT EXISTS idx_locus_flashcard_flashcardId ON locus_flashcard(flashcardId);
            `);

            // Add columns safely if not already present
            const cols = db.prepare("PRAGMA table_info(palace_locus)").all().map(c => c.name);
            if (!cols.includes('photoId')) {
                db.exec("ALTER TABLE palace_locus ADD COLUMN photoId TEXT;");
            }
            if (!cols.includes('anchoredInfo')) {
                db.exec("ALTER TABLE palace_locus ADD COLUMN anchoredInfo TEXT;");
            }
            db.exec("CREATE INDEX IF NOT EXISTS idx_palace_locus_photoId ON palace_locus(photoId);");

            db.exec(`
                INSERT OR IGNORE INTO palace_photo (id, palaceId, name, imagePath, imageData, orderIndex, createdAt, updatedAt)
                SELECT 'photo-' || id, id, name, imagePath, imageData, 0, createdAt, updatedAt
                FROM memory_palace;

                UPDATE palace_locus
                SET photoId = (SELECT id FROM palace_photo WHERE palace_photo.palaceId = palace_locus.palaceId LIMIT 1)
                WHERE photoId IS NULL;

                INSERT OR IGNORE INTO locus_flashcard (id, locusId, flashcardId, sortOrder, createdAt)
                SELECT 'lf-' || id, id, flashcardId, 0, datetime('now')
                FROM palace_locus
                WHERE flashcardId IS NOT NULL AND flashcardId != '';
            `);
        });

        // v5: Vast Canvas Photos (Spatial coordinates on canvas)
        runMigration('v5_vast_canvas_photos', () => {
            const cols = db.prepare("PRAGMA table_info(palace_photo)").all().map(c => c.name);
            if (!cols.includes('canvasX')) db.exec("ALTER TABLE palace_photo ADD COLUMN canvasX REAL DEFAULT 100.0;");
            if (!cols.includes('canvasY')) db.exec("ALTER TABLE palace_photo ADD COLUMN canvasY REAL DEFAULT 100.0;");
            if (!cols.includes('canvasWidth')) db.exec("ALTER TABLE palace_photo ADD COLUMN canvasWidth REAL DEFAULT 420.0;");
            if (!cols.includes('canvasHeight')) db.exec("ALTER TABLE palace_photo ADD COLUMN canvasHeight REAL DEFAULT 280.0;");

            db.exec(`
                UPDATE palace_photo
                SET canvasX = 80.0 + (orderIndex * 500.0),
                    canvasY = 120.0,
                    canvasWidth = 420.0,
                    canvasHeight = 280.0;
            `);
        });

        // v6: Flashcard Decks
        runMigration('v6_flashcard_decks', () => {
            db.exec(`
                CREATE TABLE IF NOT EXISTS deck (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    description TEXT,
                    colorHex TEXT NOT NULL DEFAULT '#3B82F6',
                    icon TEXT NOT NULL DEFAULT 'rectangle.stack',
                    isNotesDefault BOOLEAN NOT NULL DEFAULT 0,
                    createdAt DATETIME NOT NULL,
                    updatedAt DATETIME NOT NULL
                );

                CREATE INDEX IF NOT EXISTS idx_deck_isNotesDefault ON deck(isNotesDefault);
            `);

            const cols = db.prepare("PRAGMA table_info(flashcard)").all().map(c => c.name);
            if (!cols.includes('deckId')) {
                db.exec("ALTER TABLE flashcard ADD COLUMN deckId TEXT;");
            }
            db.exec("CREATE INDEX IF NOT EXISTS idx_flashcard_deckId ON flashcard(deckId);");

            db.exec(`
                INSERT OR IGNORE INTO deck (id, name, description, colorHex, icon, isNotesDefault, createdAt, updatedAt)
                VALUES (
                    'deck-notes-default',
                    'Notes & Documents',
                    'Auto-grouped collection of all flashcards generated or linked to the notes and folder hierarchy',
                    '#3B82F6',
                    'note.text',
                    1,
                    datetime('now'),
                    datetime('now')
                );

                UPDATE flashcard
                SET deckId = 'deck-notes-default'
                WHERE deckId IS NULL;
            `);
        });

        // v7: Deck Options Presets and Card Flags
        runMigration('v7_deck_options_and_card_flags', () => {
            const deckCols = db.prepare("PRAGMA table_info(deck)").all().map(c => c.name);
            if (!deckCols.includes('presetId')) {
                db.exec("ALTER TABLE deck ADD COLUMN presetId TEXT;");
            }
            const cardCols = db.prepare("PRAGMA table_info(flashcard)").all().map(c => c.name);
            if (!cardCols.includes('isSuspended')) {
                db.exec("ALTER TABLE flashcard ADD COLUMN isSuspended BOOLEAN DEFAULT 0;");
            }
        });

        // v8: Vector Ink Notes
        runMigration('v8_ink_notes', () => {
            db.exec(`
                CREATE TABLE IF NOT EXISTS ink_document_page (
                    id TEXT PRIMARY KEY,
                    docId TEXT NOT NULL,
                    pageIndex INTEGER NOT NULL DEFAULT 0,
                    templateType TEXT NOT NULL DEFAULT 'lined',
                    strokesData TEXT NOT NULL,
                    textProjection TEXT,
                    createdAt DATETIME NOT NULL,
                    updatedAt DATETIME NOT NULL
                );

                CREATE INDEX IF NOT EXISTS idx_ink_page_docId ON ink_document_page(docId);
                CREATE INDEX IF NOT EXISTS idx_ink_page_doc_idx ON ink_document_page(docId, pageIndex);
            `);
        });

        // v9: Ink Page PDF Import
        runMigration('v9_ink_page_pdf_import', () => {
            const cols = db.prepare("PRAGMA table_info(ink_document_page)").all().map(c => c.name);
            if (!cols.includes('pdfPath')) {
                db.exec("ALTER TABLE ink_document_page ADD COLUMN pdfPath TEXT;");
            }
            if (!cols.includes('pdfPageIndex')) {
                db.exec("ALTER TABLE ink_document_page ADD COLUMN pdfPageIndex INTEGER;");
            }
        });

        // v10: Image Occlusion Flashcards
        runMigration('v10_image_occlusion_flashcards', () => {
            const cols = db.prepare("PRAGMA table_info(flashcard)").all().map(c => c.name);
            if (!cols.includes('cardType')) {
                db.exec("ALTER TABLE flashcard ADD COLUMN cardType INTEGER DEFAULT 0;");
            }
            if (!cols.includes('imagePath')) {
                db.exec("ALTER TABLE flashcard ADD COLUMN imagePath TEXT;");
            }
            if (!cols.includes('occlusionMasksData')) {
                db.exec("ALTER TABLE flashcard ADD COLUMN occlusionMasksData TEXT;");
            }
            if (!cols.includes('activeMaskId')) {
                db.exec("ALTER TABLE flashcard ADD COLUMN activeMaskId TEXT;");
            }
            if (!cols.includes('occlusionMode')) {
                db.exec("ALTER TABLE flashcard ADD COLUMN occlusionMode INTEGER DEFAULT 1;");
            }
            db.exec("CREATE INDEX IF NOT EXISTS idx_flashcard_cardType ON flashcard(cardType);");
        });

        // v11: Ink Canvas Mode
        runMigration('v11_ink_canvas_mode', () => {
            const cols = db.prepare("PRAGMA table_info(block)").all().map(c => c.name);
            if (!cols.includes('canvasMode')) {
                db.exec("ALTER TABLE block ADD COLUMN canvasMode TEXT DEFAULT 'a4Pages';");
            }
        });

        // v12: Focus Sessions
        runMigration('v12_focus_sessions', () => {
            db.exec(`
                CREATE TABLE IF NOT EXISTS focus_session (
                    id TEXT PRIMARY KEY,
                    durationSeconds INTEGER NOT NULL DEFAULT 0,
                    focusedSeconds INTEGER NOT NULL DEFAULT 0,
                    phase TEXT NOT NULL DEFAULT 'focus',
                    docId TEXT,
                    createdAt DATETIME NOT NULL,
                    completedAt DATETIME,
                    isCompleted BOOLEAN NOT NULL DEFAULT 0
                );

                CREATE INDEX IF NOT EXISTS idx_focus_session_createdAt ON focus_session(createdAt);
                CREATE INDEX IF NOT EXISTS idx_focus_session_completedAt ON focus_session(completedAt);
            `);
        });

        // v13: Block Tier 1 Primitives & Document Metadata Parity
        runMigration('v13_block_tier1_primitives_and_metadata', () => {
            const cols = db.prepare("PRAGMA table_info(block)").all().map(c => c.name);
            if (!cols.includes('isCollapsed')) {
                db.exec("ALTER TABLE block ADD COLUMN isCollapsed BOOLEAN DEFAULT 0;");
            }
            if (!cols.includes('icon')) {
                db.exec("ALTER TABLE block ADD COLUMN icon TEXT;");
            }
            if (!cols.includes('colorTint')) {
                db.exec("ALTER TABLE block ADD COLUMN colorTint TEXT;");
            }
            if (!cols.includes('verifiedAt')) {
                db.exec("ALTER TABLE block ADD COLUMN verifiedAt DATETIME;");
            }
            if (!cols.includes('verifiedExpiresAt')) {
                db.exec("ALTER TABLE block ADD COLUMN verifiedExpiresAt DATETIME;");
            }
            if (!cols.includes('verifiedBy')) {
                db.exec("ALTER TABLE block ADD COLUMN verifiedBy TEXT;");
            }
            if (!cols.includes('isLocked')) {
                db.exec("ALTER TABLE block ADD COLUMN isLocked BOOLEAN DEFAULT 0;");
            }
            if (!cols.includes('pinnedPropertiesData')) {
                db.exec("ALTER TABLE block ADD COLUMN pinnedPropertiesData TEXT;");
            }
        });
    }
};

module.exports = { DatabaseMigrations };
