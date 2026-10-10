/**
 * Tier 1 Feature Coverage: 01. SQLite Schema Parity
 * Verifies table schemas, primary keys, NOT NULL constraints, indexes,
 * views, and foreign keys matching macOS DatabaseMigrations.swift and Windows migrations.js.
 */

const { TestSuite, Assert } = require('../lib/test_framework');
const { createInitializedDatabase } = require('../lib/sqlite_schema');

const suite = new TestSuite('Tier 1: SQLite Schema Parity (R2)');

suite.test('1.1 notebook table schema and constraints', () => {
  const db = createInitializedDatabase({ seedDefaults: false });

  // Verify columns in notebook
  const cols = db.prepare('PRAGMA table_info(notebook)').all();
  const colNames = cols.map(c => c.name);
  Assert.ok(colNames.includes('id'), 'notebook must contain id');
  Assert.ok(colNames.includes('name'), 'notebook must contain name');
  Assert.ok(colNames.includes('icon'), 'notebook must contain icon');
  Assert.ok(colNames.includes('sortOrder'), 'notebook must contain sortOrder');

  // Verify NOT NULL constraint on name
  Assert.throws(() => {
    db.prepare('INSERT INTO notebook (id, name, sortOrder) VALUES (?, NULL, ?)').run('nb-fail', 0);
  }, 'NOT NULL constraint failed');

  // Verify successful insert
  db.prepare('INSERT INTO notebook (id, name, icon, sortOrder) VALUES (?, ?, ?, ?)').run('nb-1', 'Physics', 'atom', 1);
  const row = db.prepare('SELECT * FROM notebook WHERE id = ?').get('nb-1');
  Assert.equal(row.name, 'Physics');
  Assert.equal(row.sortOrder, 1);
  db.close();
});

suite.test('1.2 block table 20 columns and indexes', () => {
  const db = createInitializedDatabase({ seedDefaults: false });
  const cols = db.prepare('PRAGMA table_info(block)').all();
  const colNames = cols.map(c => c.name);

  const requiredCols = [
    'id', 'rootDocId', 'parentId', 'type', 'content', 'sortOrder',
    'isCompleted', 'refTargetId', 'createdAt', 'updatedAt', 'notebookId',
    'canvasMode', 'isCollapsed', 'icon', 'colorTint', 'verifiedAt',
    'verifiedExpiresAt', 'verifiedBy', 'isLocked', 'pinnedPropertiesData'
  ];

  for (const rc of requiredCols) {
    Assert.ok(colNames.includes(rc), `block table must contain column: ${rc}`);
  }

  // Verify indexes
  const indexes = db.prepare('PRAGMA index_list(block)').all().map(i => i.name);
  Assert.ok(indexes.includes('idx_block_rootDocId'), 'idx_block_rootDocId exists');
  Assert.ok(indexes.includes('idx_block_parentId'), 'idx_block_parentId exists');
  Assert.ok(indexes.includes('idx_block_notebookId'), 'idx_block_notebookId exists');
  Assert.ok(indexes.includes('idx_block_refTargetId'), 'idx_block_refTargetId exists');
  Assert.ok(indexes.includes('idx_block_sortOrder'), 'idx_block_sortOrder exists');
  db.close();
});

suite.test('1.3 document table and foreign key cascade', () => {
  const db = createInitializedDatabase({ seedDefaults: false });
  const now = new Date().toISOString();

  // Create notebook
  db.prepare('INSERT INTO notebook (id, name, sortOrder) VALUES (?, ?, ?)').run('nb-cs', 'Computer Science', 0);

  // Insert root document
  db.prepare(`
    INSERT INTO document (id, notebookId, parentId, title, isFolder, sortOrder, createdAt, updatedAt)
    VALUES (?, ?, NULL, ?, 0, 0, ?, ?)
  `).run('doc-algo', 'nb-cs', 'Algorithms', now, now);

  // Insert child document
  db.prepare(`
    INSERT INTO document (id, notebookId, parentId, title, isFolder, sortOrder, createdAt, updatedAt)
    VALUES (?, ?, ?, ?, 0, 1, ?, ?)
  `).run('doc-sort', 'nb-cs', 'doc-algo', 'Sorting Algorithms', now, now);

  const countBefore = db.prepare('SELECT COUNT(*) AS count FROM document').get().count;
  Assert.equal(countBefore, 2, 'Two documents inserted');

  // Deleting notebook must cascade delete all documents
  db.prepare('DELETE FROM notebook WHERE id = ?').run('nb-cs');
  const countAfter = db.prepare('SELECT COUNT(*) AS count FROM document').get().count;
  Assert.equal(countAfter, 0, 'Cascade delete removed child documents');
  db.close();
});

suite.test('1.4 document_view over block table', () => {
  const db = createInitializedDatabase({ seedDefaults: false });
  const now = new Date().toISOString();

  db.prepare('INSERT INTO notebook (id, name, sortOrder) VALUES (?, ?, ?)').run('nb-view', 'View Test', 0);

  // Insert doc block
  db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
    VALUES ('b-doc-1', 'b-doc-1', NULL, 'doc', 'Distributed Systems Note', 0, ?, ?, 'nb-view')
  `).run(now, now);

  // Insert paragraph block (not a document)
  db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
    VALUES ('b-p-1', 'b-doc-1', 'b-doc-1', 'paragraph', 'Content here', 1, ?, ?, 'nb-view')
  `).run(now, now);

  // Query document_view
  const viewRows = db.prepare('SELECT * FROM document_view').all();
  Assert.equal(viewRows.length, 1, 'Only doc block appears in document_view');
  Assert.equal(viewRows[0].id, 'b-doc-1');
  Assert.equal(viewRows[0].title, 'Distributed Systems Note');
  Assert.equal(viewRows[0].isInk, 0);
  db.close();
});

suite.test('1.5 flashcard and review_log tables parity', () => {
  const db = createInitializedDatabase({ seedDefaults: false });
  const fcCols = db.prepare('PRAGMA table_info(flashcard)').all().map(c => c.name);

  const expectedFcCols = [
    'id', 'docId', 'notebookId', 'front', 'back', 'hint', 'fsrsState',
    'stability', 'difficulty', 'elapsedDays', 'scheduledDays', 'reps',
    'lapses', 'lastReview', 'due', 'createdAt', 'updatedAt', 'deckId',
    'isSuspended', 'cardType', 'imagePath', 'occlusionMasksData', 'activeMaskId', 'occlusionMode'
  ];

  for (const c of expectedFcCols) {
    Assert.ok(fcCols.includes(c), `flashcard must include column: ${c}`);
  }

  // review_log verification
  const rlCols = db.prepare('PRAGMA table_info(review_log)').all().map(c => c.name);
  Assert.ok(rlCols.includes('id'), 'review_log has id');
  Assert.ok(rlCols.includes('cardId'), 'review_log has cardId');
  Assert.ok(rlCols.includes('rating'), 'review_log has rating');
  Assert.ok(rlCols.includes('state'), 'review_log has state');
  Assert.ok(rlCols.includes('elapsedDays'), 'review_log has elapsedDays');
  Assert.ok(rlCols.includes('scheduledDays'), 'review_log has scheduledDays');
  Assert.ok(rlCols.includes('reviewTime'), 'review_log has reviewTime');
  db.close();
});

suite.test('1.6 deck and deck_options seed presets', () => {
  const db = createInitializedDatabase({ seedDefaults: true });

  const defaultDeck = db.prepare('SELECT * FROM deck WHERE id = ?').get('deck-notes-default');
  Assert.ok(defaultDeck !== undefined, 'Default deck must exist');
  Assert.equal(defaultDeck.name, 'Notes & Documents');
  Assert.equal(defaultDeck.isNotesDefault, 1);

  const defaultPreset = db.prepare('SELECT * FROM deck_options WHERE id = ?').get('preset-default');
  Assert.ok(defaultPreset !== undefined, 'Default preset must exist');
  Assert.equal(defaultPreset.maxNewCardsPerDay, 20);
  Assert.equal(defaultPreset.maxReviewsPerDay, 200);
  Assert.equal(defaultPreset.desiredRetention, 0.90);
  db.close();
});

suite.test('1.7 sync_change_log table structure and auto-increment', () => {
  const db = createInitializedDatabase({ seedDefaults: false });
  const cols = db.prepare('PRAGMA table_info(sync_change_log)').all().map(c => c.name);

  Assert.ok(cols.includes('id'), 'sync_change_log has id');
  Assert.ok(cols.includes('entityType'), 'sync_change_log has entityType');
  Assert.ok(cols.includes('entityId'), 'sync_change_log has entityId');
  Assert.ok(cols.includes('operation'), 'sync_change_log has operation');
  Assert.ok(cols.includes('data'), 'sync_change_log has data');
  Assert.ok(cols.includes('timestamp'), 'sync_change_log has timestamp');
  Assert.ok(cols.includes('lamportClock'), 'sync_change_log has lamportClock');
  Assert.ok(cols.includes('isSynced'), 'sync_change_log has isSynced');

  // Verify auto-increment primary key
  const insertStmt = db.prepare(`
    INSERT INTO sync_change_log (entityType, entityId, operation, data, timestamp, lamportClock, isSynced)
    VALUES (?, ?, ?, ?, ?, ?, 0)
  `);
  const r1 = insertStmt.run('block', 'b-1', 'INSERT', '{}', Date.now(), 1);
  const r2 = insertStmt.run('block', 'b-2', 'INSERT', '{}', Date.now(), 2);
  Assert.equal(r2.lastInsertRowid, r1.lastInsertRowid + 1, 'Auto-increment increments sequentially');
  db.close();
});

module.exports = suite;

if (require.main === module) {
  suite.run();
}
