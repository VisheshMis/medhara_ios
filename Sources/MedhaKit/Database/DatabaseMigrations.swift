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

        migrator.registerMigration("v7_deck_options_and_card_flags") { db in
            try db.execute(sql: "ALTER TABLE deck ADD COLUMN presetId TEXT;")
            try db.execute(sql: "ALTER TABLE flashcard ADD COLUMN isSuspended BOOLEAN DEFAULT 0;")
        }

        migrator.registerMigration("v8_ink_notes") { db in
            try db.create(table: "ink_document_page") { t in
                t.column("id", .text).primaryKey()
                t.column("docId", .text).notNull()
                t.column("pageIndex", .integer).notNull().defaults(to: 0)
                t.column("templateType", .text).notNull().defaults(to: "lined")
                t.column("strokesData", .text).notNull()
                t.column("textProjection", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            try db.create(index: "idx_ink_page_docId", on: "ink_document_page", columns: ["docId"])
            try db.create(index: "idx_ink_page_doc_idx", on: "ink_document_page", columns: ["docId", "pageIndex"])
        }

        migrator.registerMigration("v9_ink_page_pdf_import") { db in
            try db.execute(sql: "ALTER TABLE ink_document_page ADD COLUMN pdfPath TEXT;")
            try db.execute(sql: "ALTER TABLE ink_document_page ADD COLUMN pdfPageIndex INTEGER;")
        }

        migrator.registerMigration("v10_image_occlusion_flashcards") { db in
            try db.execute(sql: "ALTER TABLE flashcard ADD COLUMN cardType INTEGER DEFAULT 0;")
            try db.execute(sql: "ALTER TABLE flashcard ADD COLUMN imagePath TEXT;")
            try db.execute(sql: "ALTER TABLE flashcard ADD COLUMN occlusionMasksData TEXT;")
            try db.execute(sql: "ALTER TABLE flashcard ADD COLUMN activeMaskId TEXT;")
            try db.execute(sql: "ALTER TABLE flashcard ADD COLUMN occlusionMode INTEGER DEFAULT 1;")
            try db.create(index: "idx_flashcard_cardType", on: "flashcard", columns: ["cardType"])
        }

        migrator.registerMigration("v11_ink_canvas_mode") { db in
            try db.execute(sql: "ALTER TABLE block ADD COLUMN canvasMode TEXT DEFAULT 'a4Pages';")
        }

        migrator.registerMigration("v12_focus_sessions") { db in
            try db.create(table: "focus_session") { t in
                t.column("id", .text).primaryKey()
                t.column("durationSeconds", .integer).notNull().defaults(to: 0)
                t.column("focusedSeconds", .integer).notNull().defaults(to: 0)
                t.column("phase", .text).notNull().defaults(to: "focus")
                t.column("docId", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("completedAt", .datetime)
                t.column("isCompleted", .boolean).notNull().defaults(to: false)
            }

            try db.create(index: "idx_focus_session_createdAt", on: "focus_session", columns: ["createdAt"])
            try db.create(index: "idx_focus_session_completedAt", on: "focus_session", columns: ["completedAt"])
        }

        migrator.registerMigration("v13_block_tier1_primitives_and_metadata") { db in
            try db.execute(sql: "ALTER TABLE block ADD COLUMN isCollapsed BOOLEAN DEFAULT 0;")
            try db.execute(sql: "ALTER TABLE block ADD COLUMN icon TEXT;")
            try db.execute(sql: "ALTER TABLE block ADD COLUMN colorTint TEXT;")
            try db.execute(sql: "ALTER TABLE block ADD COLUMN verifiedAt DATETIME;")
            try db.execute(sql: "ALTER TABLE block ADD COLUMN verifiedExpiresAt DATETIME;")
            try db.execute(sql: "ALTER TABLE block ADD COLUMN verifiedBy TEXT;")
            try db.execute(sql: "ALTER TABLE block ADD COLUMN isLocked BOOLEAN DEFAULT 0;")
            try db.execute(sql: "ALTER TABLE block ADD COLUMN pinnedPropertiesData TEXT;")
        }

        migrator.registerMigration("v14_canvas_note_cards") { db in
            try db.create(table: "canvas_note_card") { t in
                t.column("id", .text).primaryKey()
                t.column("canvasDocId", .text).notNull()
                t.column("noteDocId", .text).notNull()
                t.column("canvasX", .double).notNull().defaults(to: 100.0)
                t.column("canvasY", .double).notNull().defaults(to: 100.0)
                t.column("canvasWidth", .double).notNull().defaults(to: 320.0)
                t.column("canvasHeight", .double).notNull().defaults(to: 200.0)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(index: "idx_canvas_note_card_canvasDocId", on: "canvas_note_card", columns: ["canvasDocId"])
            try db.create(index: "idx_canvas_note_card_noteDocId", on: "canvas_note_card", columns: ["noteDocId"])
        }

        migrator.registerMigration("v15_notion_relational_databases") { db in
            // Databases table
            try db.create(table: "databases") { t in
                t.column("id", .text).primaryKey()
                t.column("rootDocId", .text).notNull()
                t.column("title", .text).notNull().defaults(to: "Untitled Database")
                t.column("description", .text)
                t.column("icon", .text).defaults(to: "tablecells")
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(index: "idx_databases_rootDocId", on: "databases", columns: ["rootDocId"])

            // Database properties table
            try db.create(table: "database_properties") { t in
                t.column("id", .text).primaryKey()
                t.column("databaseId", .text).notNull()
                t.column("name", .text).notNull()
                t.column("type", .text).notNull()
                t.column("configJson", .text)
                t.column("sortOrder", .integer).notNull().defaults(to: 0)
            }
            try db.create(index: "idx_database_properties_databaseId", on: "database_properties", columns: ["databaseId"])
            try db.create(index: "idx_database_properties_sortOrder", on: "database_properties", columns: ["sortOrder"])

            // Database records table
            try db.create(table: "database_records") { t in
                t.column("id", .text).primaryKey()
                t.column("databaseId", .text).notNull()
                t.column("docId", .text).notNull()
                t.column("uniqueSeqNumber", .integer)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(index: "idx_database_records_databaseId", on: "database_records", columns: ["databaseId"])
            try db.create(index: "idx_database_records_docId", on: "database_records", columns: ["docId"])

            // Database cell values table (EAV store)
            try db.create(table: "database_cell_values") { t in
                t.column("recordId", .text).notNull()
                t.column("propertyId", .text).notNull()
                t.column("valueText", .text)
                t.column("valueNumber", .double)
                t.column("valueDate", .datetime)
                t.column("valueJson", .text)
                t.primaryKey(["recordId", "propertyId"])
            }
            try db.create(index: "idx_cell_values_recordId", on: "database_cell_values", columns: ["recordId"])
            try db.create(index: "idx_cell_values_propertyId", on: "database_cell_values", columns: ["propertyId"])

            // Record relations table
            try db.create(table: "record_relations") { t in
                t.column("id", .text).primaryKey()
                t.column("fromRecordId", .text).notNull()
                t.column("toRecordId", .text).notNull()
                t.column("relationPropertyId", .text).notNull()
            }
            try db.create(index: "idx_record_relations_fromRecordId", on: "record_relations", columns: ["fromRecordId"])
            try db.create(index: "idx_record_relations_toRecordId", on: "record_relations", columns: ["toRecordId"])
            try db.create(index: "idx_record_relations_propId", on: "record_relations", columns: ["relationPropertyId"])
        }

        migrator.registerMigration("v16_ink_page_spatial_layout_and_crop") { db in
            try db.execute(sql: "ALTER TABLE ink_document_page ADD COLUMN canvasX DOUBLE;")
            try db.execute(sql: "ALTER TABLE ink_document_page ADD COLUMN canvasY DOUBLE;")
            try db.execute(sql: "ALTER TABLE ink_document_page ADD COLUMN customWidth DOUBLE;")
            try db.execute(sql: "ALTER TABLE ink_document_page ADD COLUMN customHeight DOUBLE;")
            try db.execute(sql: "ALTER TABLE ink_document_page ADD COLUMN cropRectData TEXT;")
        }

        migrator.registerMigration("v17_unified_infinite_canvas") { db in
            try db.create(table: "canvas_items") { t in
                t.column("id", .text).primaryKey()
                t.column("canvasDocId", .text).notNull().references("block", onDelete: .cascade)
                t.column("itemType", .text).notNull() // shape, mediaImage, mediaVideo, mediaAudio, mediaPDF, textBlock, noteCard
                t.column("linkedNoteDocId", .text).references("block", onDelete: .setNull)
                t.column("shapeType", .text) // rectangle, roundedRectangle, diamond, ellipse, group
                t.column("x", .double).notNull()
                t.column("y", .double).notNull()
                t.column("width", .double).notNull()
                t.column("height", .double).notNull()
                t.column("rotationDegrees", .double).notNull().defaults(to: 0.0)
                t.column("zIndex", .integer).notNull().defaults(to: 0)
                t.column("fillColorHex", .text)
                t.column("strokeColorHex", .text)
                t.column("strokeWidth", .double).notNull().defaults(to: 1.5)
                t.column("cornerRadius", .double).notNull().defaults(to: 8.0)
                t.column("title", .text)
                t.column("summarySnippet", .text)
                t.column("markdownContent", .text)
                t.column("mediaAssetKey", .text)
                t.column("metadataJson", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(index: "idx_canvas_items_canvasDocId", on: "canvas_items", columns: ["canvasDocId"])
            try db.create(index: "idx_canvas_items_itemType", on: "canvas_items", columns: ["itemType"])
            try db.create(index: "idx_canvas_items_linkedNoteDocId", on: "canvas_items", columns: ["linkedNoteDocId"])
            try db.create(index: "idx_canvas_items_zIndex", on: "canvas_items", columns: ["zIndex"])

            try db.create(table: "canvas_connectors") { t in
                t.column("id", .text).primaryKey()
                t.column("canvasDocId", .text).notNull().references("block", onDelete: .cascade)
                t.column("fromItemId", .text).notNull().references("canvas_items", onDelete: .cascade)
                t.column("fromPort", .text).notNull() // top, right, bottom, left
                t.column("toItemId", .text).notNull().references("canvas_items", onDelete: .cascade)
                t.column("toPort", .text).notNull() // top, right, bottom, left
                t.column("routingType", .text).notNull().defaults(to: "orthogonal") // orthogonal, curved, straight
                t.column("label", .text)
                t.column("strokeColorHex", .text).notNull().defaults(to: "#64748B")
                t.column("strokeWidth", .double).notNull().defaults(to: 2.0)
                t.column("arrowType", .text).notNull().defaults(to: "endArrow") // none, endArrow, bothArrows
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(index: "idx_canvas_connectors_canvasDocId", on: "canvas_connectors", columns: ["canvasDocId"])
            try db.create(index: "idx_canvas_connectors_fromItemId", on: "canvas_connectors", columns: ["fromItemId"])
            try db.create(index: "idx_canvas_connectors_toItemId", on: "canvas_connectors", columns: ["toItemId"])
        }
    }
}


