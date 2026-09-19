import Foundation
import GRDB

public enum DatabaseMigrations {
    public static func registerMigrations(in migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1_initial_schema") { db in
            // Notebooks table
            try db.create(table: "notebook") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("icon", .text)
                t.column("sortOrder", .integer).notNull().defaults(to: 0)
            }

            // Blocks table
            try db.create(table: "block") { t in
                t.column("id", .text).primaryKey()
                t.column("rootDocId", .text).notNull()
                t.column("parentId", .text)
                t.column("type", .text).notNull()
                t.column("content", .text).notNull()
                t.column("sortOrder", .integer).notNull().defaults(to: 0)
                t.column("isCompleted", .boolean)
                t.column("refTargetId", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("notebookId", .text)
            }

            // High-performance relational indexes
            try db.create(index: "idx_block_rootDocId", on: "block", columns: ["rootDocId"])
            try db.create(index: "idx_block_parentId", on: "block", columns: ["parentId"])
            try db.create(index: "idx_block_notebookId", on: "block", columns: ["notebookId"])
            try db.create(index: "idx_block_refTargetId", on: "block", columns: ["refTargetId"])
            try db.create(index: "idx_block_sortOrder", on: "block", columns: ["sortOrder"])

            // FTS5 Virtual Table for Full-Text Search
            try db.execute(sql: """
            CREATE VIRTUAL TABLE block_fts USING fts5(
                id UNINDEXED,
                rootDocId UNINDEXED,
                content,
                type UNINDEXED,
                tokenize = 'unicode61'
            );
            """)

            // Real-time synchronization triggers for FTS5
            try db.execute(sql: """
            CREATE TRIGGER block_after_insert AFTER INSERT ON block
            BEGIN
                INSERT INTO block_fts(id, rootDocId, content, type)
                VALUES (new.id, new.rootDocId, new.content, new.type);
            END;
            """)

            try db.execute(sql: """
            CREATE TRIGGER block_after_update AFTER UPDATE ON block
            BEGIN
                DELETE FROM block_fts WHERE id = old.id;
                INSERT INTO block_fts(id, rootDocId, content, type)
                VALUES (new.id, new.rootDocId, new.content, new.type);
            END;
            """)

            try db.execute(sql: """
            CREATE TRIGGER block_after_delete AFTER DELETE ON block
            BEGIN
                DELETE FROM block_fts WHERE id = old.id;
            END;
            """)
        }

        migrator.registerMigration("v2_flashcards_and_palaces") { db in
            // Flashcard table with full FSRS tracking
            try db.create(table: "flashcard") { t in
                t.column("id", .text).primaryKey()
                t.column("docId", .text).notNull()
                t.column("notebookId", .text).notNull()
                t.column("front", .text).notNull()
                t.column("back", .text).notNull()
                t.column("sourceBlockId", .text)
                t.column("hint", .text)
                t.column("fsrsState", .integer).notNull().defaults(to: 0)
                t.column("stability", .double).notNull().defaults(to: 0.0)
                t.column("difficulty", .double).notNull().defaults(to: 0.0)
                t.column("elapsedDays", .integer).notNull().defaults(to: 0)
                t.column("scheduledDays", .integer).notNull().defaults(to: 0)
                t.column("reps", .integer).notNull().defaults(to: 0)
                t.column("lapses", .integer).notNull().defaults(to: 0)
                t.column("lastReview", .datetime)
                t.column("due", .datetime).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            try db.create(index: "idx_flashcard_docId", on: "flashcard", columns: ["docId"])
            try db.create(index: "idx_flashcard_notebookId", on: "flashcard", columns: ["notebookId"])
            try db.create(index: "idx_flashcard_due", on: "flashcard", columns: ["due"])
            try db.create(index: "idx_flashcard_fsrsState", on: "flashcard", columns: ["fsrsState"])

            // Memory Palace table (Method of Loci with 2D images)
            try db.create(table: "memory_palace") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("imagePath", .text).notNull()
                t.column("imageData", .text)
                t.column("description", .text)
                t.column("sortOrder", .integer).notNull().defaults(to: 0)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // Palace Loci table (pins on 2D image)
            try db.create(table: "palace_locus") { t in
                t.column("id", .text).primaryKey()
                t.column("palaceId", .text).notNull()
                t.column("flashcardId", .text)
                t.column("docId", .text)
                t.column("title", .text).notNull()
                t.column("mnemonic", .text)
                t.column("normalizedX", .double).notNull()
                t.column("normalizedY", .double).notNull()
                t.column("orderIndex", .integer).notNull().defaults(to: 0)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            try db.create(index: "idx_palace_locus_palaceId", on: "palace_locus", columns: ["palaceId"])
            try db.create(index: "idx_palace_locus_flashcardId", on: "palace_locus", columns: ["flashcardId"])
        }

        migrator.registerMigration("v3_links_to_graph") { db in
            try db.create(table: "doc_link") { t in
                t.column("id", .text).primaryKey()
                t.column("sourceDocId", .text).notNull()
                t.column("sourceBlockId", .text).notNull()
                t.column("targetTitle", .text).notNull()
                t.column("targetDocId", .text)
                t.column("createdAt", .datetime).notNull()
            }

            try db.create(index: "idx_doc_link_sourceDocId", on: "doc_link", columns: ["sourceDocId"])
            try db.create(index: "idx_doc_link_targetDocId", on: "doc_link", columns: ["targetDocId"])
            try db.create(index: "idx_doc_link_targetTitle", on: "doc_link", columns: ["targetTitle"])
        }

        migrator.registerMigration("v4_multiphoto_palace_and_locus_anchors") { db in
            // 1. Sequential photos per palace
            try db.create(table: "palace_photo") { t in
                t.column("id", .text).primaryKey()
                t.column("palaceId", .text).notNull()
                t.column("name", .text).notNull()
                t.column("imagePath", .text).notNull()
                t.column("imageData", .text)
                t.column("orderIndex", .integer).notNull().defaults(to: 0)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(index: "idx_palace_photo_palaceId", on: "palace_photo", columns: ["palaceId"])
            try db.create(index: "idx_palace_photo_orderIndex", on: "palace_photo", columns: ["orderIndex"])

            // 2. Multi-flashcard junction table (locus_flashcard)
            try db.create(table: "locus_flashcard") { t in
                t.column("id", .text).primaryKey()
                t.column("locusId", .text).notNull()
                t.column("flashcardId", .text).notNull()
                t.column("sortOrder", .integer).notNull().defaults(to: 0)
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(index: "idx_locus_flashcard_locusId", on: "locus_flashcard", columns: ["locusId"])
            try db.create(index: "idx_locus_flashcard_flashcardId", on: "locus_flashcard", columns: ["flashcardId"])

            // 3. Extend palace_locus
            try db.execute(sql: "ALTER TABLE palace_locus ADD COLUMN photoId TEXT;")
            try db.execute(sql: "ALTER TABLE palace_locus ADD COLUMN anchoredInfo TEXT;")
            try db.create(index: "idx_palace_locus_photoId", on: "palace_locus", columns: ["photoId"])

            // 4. Backfill existing data
            try db.execute(sql: """
            INSERT INTO palace_photo (id, palaceId, name, imagePath, imageData, orderIndex, createdAt, updatedAt)
            SELECT 'photo-' || id, id, name, imagePath, imageData, 0, createdAt, updatedAt
            FROM memory_palace;
            """)

            try db.execute(sql: """
            UPDATE palace_locus
            SET photoId = (SELECT id FROM palace_photo WHERE palace_photo.palaceId = palace_locus.palaceId LIMIT 1)
            WHERE photoId IS NULL;
            """)

            try db.execute(sql: """
            INSERT INTO locus_flashcard (id, locusId, flashcardId, sortOrder, createdAt)
            SELECT 'lf-' || id, id, flashcardId, 0, datetime('now')
            FROM palace_locus
            WHERE flashcardId IS NOT NULL AND flashcardId != '';
            """)
        }

        migrator.registerMigration("v5_vast_canvas_photos") { db in
            try db.execute(sql: "ALTER TABLE palace_photo ADD COLUMN canvasX REAL DEFAULT 100.0;")
            try db.execute(sql: "ALTER TABLE palace_photo ADD COLUMN canvasY REAL DEFAULT 100.0;")
            try db.execute(sql: "ALTER TABLE palace_photo ADD COLUMN canvasWidth REAL DEFAULT 420.0;")
            try db.execute(sql: "ALTER TABLE palace_photo ADD COLUMN canvasHeight REAL DEFAULT 280.0;")

            try db.execute(sql: """
            UPDATE palace_photo
            SET canvasX = 80.0 + (orderIndex * 500.0),
                canvasY = 120.0,
                canvasWidth = 420.0,
                canvasHeight = 280.0;
            """)
        }

        migrator.registerMigration("v6_flashcard_decks") { db in
            try db.create(table: "deck") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("description", .text)
                t.column("colorHex", .text).notNull().defaults(to: "#3B82F6")
                t.column("icon", .text).notNull().defaults(to: "rectangle.stack")
                t.column("isNotesDefault", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(index: "idx_deck_isNotesDefault", on: "deck", columns: ["isNotesDefault"])

            try db.execute(sql: "ALTER TABLE flashcard ADD COLUMN deckId TEXT;")
            try db.create(index: "idx_flashcard_deckId", on: "flashcard", columns: ["deckId"])

            // Insert default Notes & Documents deck
            try db.execute(sql: """
            INSERT INTO deck (id, name, description, colorHex, icon, isNotesDefault, createdAt, updatedAt)
            VALUES (
                '\(Deck.notesDefaultId)',
                'Notes & Documents',
                'Auto-grouped collection of all flashcards generated or linked to the notes and folder hierarchy',
                '#3B82F6',
                'note.text',
                1,
                datetime('now'),
                datetime('now')
            );
            """)

            // Backfill existing flashcards
            try db.execute(sql: """
            UPDATE flashcard
            SET deckId = '\(Deck.notesDefaultId)'
            WHERE deckId IS NULL;
            """)
        }
    }
}
