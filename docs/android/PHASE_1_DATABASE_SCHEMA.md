# Phase 1: SQLite / Room Schema Parity & FTS5 Search Engine

> **Parent Roadmap**: [ANDROID_APP_INTEGRATION_AND_SYNC.md](../../ANDROID_APP_INTEGRATION_AND_SYNC.md)  
> **Source Parity**: `Sources/MedhaKit/Database/DatabaseMigrations.swift` & `desktop/src/main/database/migrations.ts`  

---

## 🎯 Phase Objective
Implement the complete relational schema in Android (using Room or AndroidX SQLite) maintaining 100% column, type, foreign key, and index parity with the Mac desktop app, including an FTS5 virtual table (`block_fts`) with unicode61 tokenizer and automated sync triggers.

---

## 💾 Relational Schema Definitions

```sql
-- 1. Notebooks table
CREATE TABLE IF NOT EXISTS notebook (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    icon TEXT,
    sortOrder INTEGER NOT NULL DEFAULT 0,
    isArchived INTEGER NOT NULL DEFAULT 0,
    updatedAt INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);

-- 2. Documents table
CREATE TABLE IF NOT EXISTS document (
    id TEXT PRIMARY KEY NOT NULL,
    notebookId TEXT NOT NULL,
    title TEXT NOT NULL,
    icon TEXT,
    sortOrder INTEGER NOT NULL DEFAULT 0,
    isPinned INTEGER NOT NULL DEFAULT 0,
    createdAt INTEGER NOT NULL,
    updatedAt INTEGER NOT NULL,
    FOREIGN KEY (notebookId) REFERENCES notebook(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_document_notebookId ON document(notebookId);

-- 3. Blocks table
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
CREATE INDEX IF NOT EXISTS idx_block_rootDocId ON block(rootDocId);
CREATE INDEX IF NOT EXISTS idx_block_parentId ON block(parentId);
CREATE INDEX IF NOT EXISTS idx_block_notebookId ON block(notebookId);
CREATE INDEX IF NOT EXISTS idx_block_sortOrder ON block(sortOrder);

-- 4. FTS5 Virtual Table for Instant Search
CREATE VIRTUAL TABLE IF NOT EXISTS block_fts USING fts5(
    id UNINDEXED,
    rootDocId UNINDEXED,
    content,
    type UNINDEXED,
    tokenize = 'unicode61'
);

-- Triggers for FTS5 Sync
CREATE TRIGGER IF NOT EXISTS trg_block_fts_insert AFTER INSERT ON block
BEGIN
    INSERT INTO block_fts(id, rootDocId, content, type)
    VALUES (new.id, new.rootDocId, new.content, new.type);
END;

CREATE TRIGGER IF NOT EXISTS trg_block_fts_update AFTER UPDATE ON block
BEGIN
    DELETE FROM block_fts WHERE id = old.id;
    INSERT INTO block_fts(id, rootDocId, content, type)
    VALUES (new.id, new.rootDocId, new.content, new.type);
END;

CREATE TRIGGER IF NOT EXISTS trg_block_fts_delete AFTER DELETE ON block
BEGIN
    DELETE FROM block_fts WHERE id = old.id;
END;

-- 5. Flashcards table (FSRS tracking)
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
CREATE INDEX IF NOT EXISTS idx_flashcard_docId ON flashcard(docId);
CREATE INDEX IF NOT EXISTS idx_flashcard_due ON flashcard(due);
CREATE INDEX IF NOT EXISTS idx_flashcard_fsrsState ON flashcard(fsrsState);

-- 6. Review Log table
CREATE TABLE IF NOT EXISTS review_log (
    id TEXT PRIMARY KEY NOT NULL,
    cardId TEXT NOT NULL,
    rating INTEGER NOT NULL,
    scheduledDays INTEGER NOT NULL,
    elapsedDays INTEGER NOT NULL,
    reviewTime INTEGER NOT NULL,
    state INTEGER NOT NULL,
    lastState INTEGER NOT NULL,
    FOREIGN KEY (cardId) REFERENCES flashcard(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_review_log_cardId ON review_log(cardId);
CREATE INDEX IF NOT EXISTS idx_review_log_reviewTime ON review_log(reviewTime);

-- 7. Deck Options table
CREATE TABLE IF NOT EXISTS deck_options (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    desiredRetention REAL NOT NULL DEFAULT 0.90,
    maxIntervalDays INTEGER NOT NULL DEFAULT 36500,
    weightsJson TEXT
);
```

---

## 🧪 Verification Gate
- Automated tests verify table creation, cascading delete behavior (`DELETE FROM notebook` clears all child documents and blocks), and FTS5 BM25 search queries.
- Triggers correctly update `block_fts` on block updates and deletions without manual re-indexing.
