/**
 * SQLite Schema Parity & Triggers Module for Medha Companion E2E Testing
 * Provides verbatim DDL schemas, FTS5 virtual tables, and mutation triggers
 * matching macOS DatabaseMigrations.swift and Windows migrations.js.
 */

const path = require('path');
const Database = require(path.resolve(__dirname, '../../../desktop/node_modules/better-sqlite3'));

const SCHEMA_DDL = `
-- 1. Table: notebook
CREATE TABLE IF NOT EXISTS notebook (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    icon TEXT,
    sortOrder INTEGER NOT NULL DEFAULT 0
);

-- 2. Table: block
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
    notebookId TEXT,
    canvasMode TEXT DEFAULT 'a4Pages',
    isCollapsed BOOLEAN DEFAULT 0,
    icon TEXT,
    colorTint TEXT,
    verifiedAt DATETIME,
    verifiedExpiresAt DATETIME,
    verifiedBy TEXT,
    isLocked BOOLEAN DEFAULT 0,
    pinnedPropertiesData TEXT
);

CREATE INDEX IF NOT EXISTS idx_block_rootDocId ON block(rootDocId);
CREATE INDEX IF NOT EXISTS idx_block_parentId ON block(parentId);
CREATE INDEX IF NOT EXISTS idx_block_notebookId ON block(notebookId);
CREATE INDEX IF NOT EXISTS idx_block_refTargetId ON block(refTargetId);
CREATE INDEX IF NOT EXISTS idx_block_sortOrder ON block(sortOrder);

-- 3. Table: document
CREATE TABLE IF NOT EXISTS document (
    id TEXT PRIMARY KEY,
    notebookId TEXT NOT NULL,
    parentId TEXT,
    title TEXT NOT NULL,
    isFolder BOOLEAN NOT NULL DEFAULT 0,
    sortOrder INTEGER NOT NULL DEFAULT 0,
    createdAt DATETIME NOT NULL,
    updatedAt DATETIME NOT NULL,
    FOREIGN KEY (notebookId) REFERENCES notebook(id) ON DELETE CASCADE,
    FOREIGN KEY (parentId) REFERENCES document(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_document_notebookId ON document(notebookId);
CREATE INDEX IF NOT EXISTS idx_document_parentId ON document(parentId);
CREATE INDEX IF NOT EXISTS idx_document_sortOrder ON document(sortOrder);

-- Document View over block
CREATE VIEW IF NOT EXISTS document_view AS
SELECT 
    id,
    notebookId,
    parentId,
    content AS title,
    (CASE WHEN type = 'inkDoc' THEN 1 ELSE 0 END) AS isInk,
    sortOrder,
    createdAt,
    updatedAt
FROM block
WHERE type IN ('doc', 'inkDoc');

-- 4. FTS5 Virtual Table: block_fts (unicode61 tokenizer)
CREATE VIRTUAL TABLE IF NOT EXISTS block_fts USING fts5(
    id UNINDEXED,
    rootDocId UNINDEXED,
    content,
    type UNINDEXED,
    tokenize = 'unicode61'
);

-- 5. Table: flashcard
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
    updatedAt DATETIME NOT NULL,
    deckId TEXT DEFAULT 'deck-notes-default',
    isSuspended BOOLEAN DEFAULT 0,
    cardType INTEGER DEFAULT 0,
    imagePath TEXT,
    occlusionMasksData TEXT,
    activeMaskId TEXT,
    occlusionMode INTEGER DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_flashcard_docId ON flashcard(docId);
CREATE INDEX IF NOT EXISTS idx_flashcard_notebookId ON flashcard(notebookId);
CREATE INDEX IF NOT EXISTS idx_flashcard_due ON flashcard(due);
CREATE INDEX IF NOT EXISTS idx_flashcard_fsrsState ON flashcard(fsrsState);
CREATE INDEX IF NOT EXISTS idx_flashcard_deckId ON flashcard(deckId);
CREATE INDEX IF NOT EXISTS idx_flashcard_cardType ON flashcard(cardType);

-- 6. Table: review_log
CREATE TABLE IF NOT EXISTS review_log (
    id TEXT PRIMARY KEY,
    cardId TEXT NOT NULL,
    rating INTEGER NOT NULL,
    state TEXT NOT NULL,
    elapsedDays INTEGER NOT NULL DEFAULT 0,
    scheduledDays INTEGER NOT NULL DEFAULT 0,
    reviewTime DATETIME NOT NULL,
    FOREIGN KEY (cardId) REFERENCES flashcard(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_review_log_cardId ON review_log(cardId);
CREATE INDEX IF NOT EXISTS idx_review_log_reviewTime ON review_log(reviewTime);

-- 7. Table: deck
CREATE TABLE IF NOT EXISTS deck (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    colorHex TEXT NOT NULL DEFAULT '#3B82F6',
    icon TEXT NOT NULL DEFAULT 'rectangle.stack',
    isNotesDefault BOOLEAN NOT NULL DEFAULT 0,
    presetId TEXT,
    createdAt DATETIME NOT NULL,
    updatedAt DATETIME NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_deck_isNotesDefault ON deck(isNotesDefault);

-- 8. Table: deck_options
CREATE TABLE IF NOT EXISTS deck_options (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    isDefault BOOLEAN NOT NULL DEFAULT 0,
    maxNewCardsPerDay INTEGER NOT NULL DEFAULT 20,
    maxReviewsPerDay INTEGER NOT NULL DEFAULT 200,
    learningSteps TEXT NOT NULL DEFAULT '1m 10m',
    insertionOrder TEXT NOT NULL DEFAULT 'sequential',
    relearningSteps TEXT NOT NULL DEFAULT '10m',
    leechThreshold INTEGER NOT NULL DEFAULT 8,
    leechAction TEXT NOT NULL DEFAULT 'tagOnly',
    newCardGatherOrder TEXT NOT NULL DEFAULT 'deck',
    newCardSortOrder TEXT NOT NULL DEFAULT 'orderAdded',
    newReviewOrder TEXT NOT NULL DEFAULT 'afterReviews',
    interdayOrder TEXT NOT NULL DEFAULT 'beforeReviews',
    reviewSortOrder TEXT NOT NULL DEFAULT 'dueDate',
    desiredRetention REAL NOT NULL DEFAULT 0.90,
    maximumInterval INTEGER NOT NULL DEFAULT 36500,
    historicalRetention REAL NOT NULL DEFAULT 0.90,
    createdAt DATETIME NOT NULL,
    updatedAt DATETIME NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_deck_options_isDefault ON deck_options(isDefault);

-- 9. Table: sync_change_log
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

CREATE INDEX IF NOT EXISTS idx_sync_change_log_pending ON sync_change_log(isSynced, timestamp ASC);
CREATE INDEX IF NOT EXISTS idx_sync_change_log_entity ON sync_change_log(entityType, entityId);
CREATE INDEX IF NOT EXISTS idx_sync_change_log_lamport ON sync_change_log(lamportClock);
`;

const TRIGGERS_DDL = `
-- FTS5 Synchronization Triggers
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

-- Sync Mutation Journal Triggers: block
CREATE TRIGGER IF NOT EXISTS trg_block_sync_insert AFTER INSERT ON block
BEGIN
    INSERT INTO sync_change_log (entityType, entityId, operation, data, timestamp, isSynced)
    VALUES (
        'block',
        new.id,
        'INSERT',
        json_object(
            'id', new.id, 'rootDocId', new.rootDocId, 'parentId', new.parentId,
            'type', new.type, 'content', new.content, 'sortOrder', new.sortOrder,
            'isCompleted', new.isCompleted, 'refTargetId', new.refTargetId,
            'createdAt', new.createdAt, 'updatedAt', new.updatedAt, 'notebookId', new.notebookId
        ),
        CAST((julianday('now') - 2440587.5) * 86400000.0 AS INTEGER),
        0
    );
END;

CREATE TRIGGER IF NOT EXISTS trg_block_sync_update AFTER UPDATE ON block
BEGIN
    INSERT INTO sync_change_log (entityType, entityId, operation, data, timestamp, isSynced)
    VALUES (
        'block',
        new.id,
        'UPDATE',
        json_object(
            'id', new.id, 'rootDocId', new.rootDocId, 'parentId', new.parentId,
            'type', new.type, 'content', new.content, 'sortOrder', new.sortOrder,
            'isCompleted', new.isCompleted, 'refTargetId', new.refTargetId,
            'createdAt', new.createdAt, 'updatedAt', new.updatedAt, 'notebookId', new.notebookId
        ),
        CAST((julianday('now') - 2440587.5) * 86400000.0 AS INTEGER),
        0
    );
END;

CREATE TRIGGER IF NOT EXISTS trg_block_sync_delete AFTER DELETE ON block
BEGIN
    INSERT INTO sync_change_log (entityType, entityId, operation, data, timestamp, isSynced)
    VALUES (
        'block',
        old.id,
        'DELETE',
        NULL,
        CAST((julianday('now') - 2440587.5) * 86400000.0 AS INTEGER),
        0
    );
END;

-- Sync Mutation Journal Triggers: notebook
CREATE TRIGGER IF NOT EXISTS trg_notebook_sync_insert AFTER INSERT ON notebook
BEGIN
    INSERT INTO sync_change_log (entityType, entityId, operation, data, timestamp, isSynced)
    VALUES (
        'notebook',
        new.id,
        'INSERT',
        json_object('id', new.id, 'name', new.name, 'icon', new.icon, 'sortOrder', new.sortOrder),
        CAST((julianday('now') - 2440587.5) * 86400000.0 AS INTEGER),
        0
    );
END;

CREATE TRIGGER IF NOT EXISTS trg_notebook_sync_update AFTER UPDATE ON notebook
BEGIN
    INSERT INTO sync_change_log (entityType, entityId, operation, data, timestamp, isSynced)
    VALUES (
        'notebook',
        new.id,
        'UPDATE',
        json_object('id', new.id, 'name', new.name, 'icon', new.icon, 'sortOrder', new.sortOrder),
        CAST((julianday('now') - 2440587.5) * 86400000.0 AS INTEGER),
        0
    );
END;

CREATE TRIGGER IF NOT EXISTS trg_notebook_sync_delete AFTER DELETE ON notebook
BEGIN
    INSERT INTO sync_change_log (entityType, entityId, operation, data, timestamp, isSynced)
    VALUES (
        'notebook',
        old.id,
        'DELETE',
        NULL,
        CAST((julianday('now') - 2440587.5) * 86400000.0 AS INTEGER),
        0
    );
END;

-- Sync Mutation Journal Triggers: flashcard
CREATE TRIGGER IF NOT EXISTS trg_flashcard_sync_insert AFTER INSERT ON flashcard
BEGIN
    INSERT INTO sync_change_log (entityType, entityId, operation, data, timestamp, isSynced)
    VALUES (
        'flashcard',
        new.id,
        'INSERT',
        json_object(
            'id', new.id, 'docId', new.docId, 'notebookId', new.notebookId,
            'front', new.front, 'back', new.back, 'hint', new.hint,
            'fsrsState', new.fsrsState, 'stability', new.stability, 'difficulty', new.difficulty,
            'elapsedDays', new.elapsedDays, 'scheduledDays', new.scheduledDays,
            'reps', new.reps, 'lapses', new.lapses, 'lastReview', new.lastReview, 'due', new.due,
            'deckId', new.deckId
        ),
        CAST((julianday('now') - 2440587.5) * 86400000.0 AS INTEGER),
        0
    );
END;

CREATE TRIGGER IF NOT EXISTS trg_flashcard_sync_update AFTER UPDATE ON flashcard
BEGIN
    INSERT INTO sync_change_log (entityType, entityId, operation, data, timestamp, isSynced)
    VALUES (
        'flashcard',
        new.id,
        'UPDATE',
        json_object(
            'id', new.id, 'docId', new.docId, 'notebookId', new.notebookId,
            'front', new.front, 'back', new.back, 'hint', new.hint,
            'fsrsState', new.fsrsState, 'stability', new.stability, 'difficulty', new.difficulty,
            'elapsedDays', new.elapsedDays, 'scheduledDays', new.scheduledDays,
            'reps', new.reps, 'lapses', new.lapses, 'lastReview', new.lastReview, 'due', new.due,
            'deckId', new.deckId
        ),
        CAST((julianday('now') - 2440587.5) * 86400000.0 AS INTEGER),
        0
    );
END;

CREATE TRIGGER IF NOT EXISTS trg_flashcard_sync_delete AFTER DELETE ON flashcard
BEGIN
    INSERT INTO sync_change_log (entityType, entityId, operation, data, timestamp, isSynced)
    VALUES (
        'flashcard',
        old.id,
        'DELETE',
        NULL,
        CAST((julianday('now') - 2440587.5) * 86400000.0 AS INTEGER),
        0
    );
END;
`;

function createInitializedDatabase(options = {}) {
  const dbPath = options.path || ':memory:';
  const db = new Database(dbPath);
  db.pragma('foreign_keys = ON');

  // Execute Schema DDL
  db.exec(SCHEMA_DDL);

  // Execute Triggers
  db.exec(TRIGGERS_DDL);

  if (options.seedDefaults !== false) {
    seedDefaultData(db);
  }

  return db;
}

function seedDefaultData(db) {
  const now = new Date().toISOString();
  
  // Seed default notebook
  db.prepare(`
    INSERT OR IGNORE INTO notebook (id, name, icon, sortOrder)
    VALUES ('nb-welcome-kb', 'Knowledge Base', 'book.closed', 0)
  `).run();

  // Seed default deck
  db.prepare(`
    INSERT OR IGNORE INTO deck (id, name, description, colorHex, icon, isNotesDefault, createdAt, updatedAt)
    VALUES ('deck-notes-default', 'Notes & Documents', 'Default deck for generated flashcards', '#3B82F6', 'rectangle.stack', 1, ?, ?)
  `).run(now, now);

  // Seed default deck options
  db.prepare(`
    INSERT OR IGNORE INTO deck_options (id, name, isDefault, maxNewCardsPerDay, maxReviewsPerDay, desiredRetention, maximumInterval, createdAt, updatedAt)
    VALUES ('preset-default', 'Default Preset', 1, 20, 200, 0.90, 36500, ?, ?)
  `).run(now, now);
}

module.exports = {
  SCHEMA_DDL,
  TRIGGERS_DDL,
  createInitializedDatabase,
  seedDefaultData,
};
