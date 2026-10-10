package com.medha.companion.data.local

/**
 * SQL Schema constants and migration scripts for Medha Android Companion.
 * 100% parity with macOS DatabaseMigrations.swift and Windows migrations.ts.
 */
object DatabaseSchema {

    const val DB_NAME = "medha_companion.db"
    const val DB_VERSION = 1

    val CREATE_TABLES = arrayOf(
        // 1. Notebook table
        """
        CREATE TABLE IF NOT EXISTS notebook (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            icon TEXT,
            sortOrder INTEGER NOT NULL DEFAULT 0,
            isArchived INTEGER NOT NULL DEFAULT 0,
            updatedAt INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
        );
        """.trimIndent(),

        // 2. Document table
        """
        CREATE TABLE IF NOT EXISTS document (
            id TEXT PRIMARY KEY NOT NULL,
            notebookId TEXT NOT NULL,
            parentId TEXT,
            title TEXT NOT NULL,
            icon TEXT,
            isFolder INTEGER NOT NULL DEFAULT 0,
            sortOrder INTEGER NOT NULL DEFAULT 0,
            isPinned INTEGER NOT NULL DEFAULT 0,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            FOREIGN KEY (notebookId) REFERENCES notebook(id) ON DELETE CASCADE
        );
        """.trimIndent(),

        // 3. Document indexes
        """
        CREATE INDEX IF NOT EXISTS idx_document_notebookId ON document(notebookId);
        """.trimIndent(),

        // 4. Block table
        """
        CREATE TABLE IF NOT EXISTS block (
            id TEXT PRIMARY KEY NOT NULL,
            rootDocId TEXT NOT NULL,
            parentId TEXT,
            type TEXT NOT NULL,
            content TEXT NOT NULL,
            sortOrder INTEGER NOT NULL DEFAULT 0,
            isCompleted INTEGER DEFAULT 0,
            refTargetId TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            notebookId TEXT,
            FOREIGN KEY (rootDocId) REFERENCES document(id) ON DELETE CASCADE
        );
        """.trimIndent(),

        // 5. Block indexes
        """
        CREATE INDEX IF NOT EXISTS idx_block_rootDocId ON block(rootDocId);
        """.trimIndent(),
        """
        CREATE INDEX IF NOT EXISTS idx_block_parentId ON block(parentId);
        """.trimIndent(),
        """
        CREATE INDEX IF NOT EXISTS idx_block_notebookId ON block(notebookId);
        """.trimIndent(),
        """
        CREATE INDEX IF NOT EXISTS idx_block_sortOrder ON block(sortOrder);
        """.trimIndent(),

        // 6. FTS5 Virtual Table for Blocks
        """
        CREATE VIRTUAL TABLE IF NOT EXISTS block_fts USING fts5(
            id UNINDEXED,
            rootDocId UNINDEXED,
            content,
            type UNINDEXED,
            tokenize = 'unicode61'
        );
        """.trimIndent(),

        // 7. FTS5 Synchronisation Triggers
        """
        CREATE TRIGGER IF NOT EXISTS trg_block_fts_insert AFTER INSERT ON block
        BEGIN
            INSERT INTO block_fts(id, rootDocId, content, type)
            VALUES (new.id, new.rootDocId, new.content, new.type);
        END;
        """.trimIndent(),
        """
        CREATE TRIGGER IF NOT EXISTS trg_block_fts_update AFTER UPDATE ON block
        BEGIN
            DELETE FROM block_fts WHERE id = old.id;
            INSERT INTO block_fts(id, rootDocId, content, type)
            VALUES (new.id, new.rootDocId, new.content, new.type);
        END;
        """.trimIndent(),
        """
        CREATE TRIGGER IF NOT EXISTS trg_block_fts_delete AFTER DELETE ON block
        BEGIN
            DELETE FROM block_fts WHERE id = old.id;
        END;
        """.trimIndent(),

        // 8. Flashcard table (FSRS parameters)
        """
        CREATE TABLE IF NOT EXISTS flashcard (
            id TEXT PRIMARY KEY NOT NULL,
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
            lastReview INTEGER,
            due INTEGER NOT NULL,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
        );
        """.trimIndent(),

        // 9. Flashcard indexes
        """
        CREATE INDEX IF NOT EXISTS idx_flashcard_docId ON flashcard(docId);
        """.trimIndent(),
        """
        CREATE INDEX IF NOT EXISTS idx_flashcard_due ON flashcard(due);
        """.trimIndent(),
        """
        CREATE INDEX IF NOT EXISTS idx_flashcard_fsrsState ON flashcard(fsrsState);
        """.trimIndent(),

        // 10. Review Log table
        """
        CREATE TABLE IF NOT EXISTS review_log (
            id TEXT PRIMARY KEY NOT NULL,
            cardId TEXT NOT NULL,
            rating INTEGER NOT NULL,
            state TEXT NOT NULL DEFAULT 'review',
            elapsedDays INTEGER NOT NULL DEFAULT 0,
            scheduledDays INTEGER NOT NULL DEFAULT 0,
            reviewTime TEXT NOT NULL,
            lastState INTEGER DEFAULT 0,
            FOREIGN KEY (cardId) REFERENCES flashcard(id) ON DELETE CASCADE
        );
        """.trimIndent(),

        // 11. Review Log indexes
        """
        CREATE INDEX IF NOT EXISTS idx_review_log_cardId ON review_log(cardId);
        """.trimIndent(),
        """
        CREATE INDEX IF NOT EXISTS idx_review_log_reviewTime ON review_log(reviewTime);
        """.trimIndent(),

        // 12. Deck Options table
        """
        CREATE TABLE IF NOT EXISTS deck_options (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            desiredRetention REAL NOT NULL DEFAULT 0.90,
            maxIntervalDays INTEGER NOT NULL DEFAULT 36500,
            weightsJson TEXT
        );
        """.trimIndent(),

        // 13. Mutation Journal (Change Data Capture)
        """
        CREATE TABLE IF NOT EXISTS sync_change_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entityType TEXT NOT NULL,
            entityId TEXT NOT NULL,
            operation TEXT NOT NULL,
            data TEXT,
            timestamp INTEGER NOT NULL,
            lamportClock INTEGER NOT NULL DEFAULT 0,
            isSynced INTEGER NOT NULL DEFAULT 0
        );
        """.trimIndent(),

        // 14. Mutation Journal indexes
        """
        CREATE INDEX IF NOT EXISTS idx_sync_unpushed ON sync_change_log(isSynced, id);
        """.trimIndent(),
        """
        CREATE INDEX IF NOT EXISTS idx_sync_entity ON sync_change_log(entityType, entityId);
        """.trimIndent(),

        // 15. Local Sync State table
        """
        CREATE TABLE IF NOT EXISTS sync_state (
            key TEXT PRIMARY KEY NOT NULL,
            val TEXT NOT NULL
        );
        """.trimIndent()
    )
}
