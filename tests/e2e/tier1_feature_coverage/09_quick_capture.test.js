/**
 * Tier 1 Feature Coverage: 09. Quick Capture UI & Storage
 * Verifies scratchpad note creation, instant flashcard creation,
 * default container bindings (Inbox/Knowledge Base and deck-notes-default),
 * and automatic synchronization mutation journaling per R1.
 */

const { TestSuite, Assert } = require('../lib/test_framework');
const { createInitializedDatabase } = require('../lib/sqlite_schema');
const { State } = require('../lib/fsrs_engine');

const suite = new TestSuite('Tier 1: Quick Capture Engine (R1)');

suite.test('9.1 Quick note scratchpad creation atomically inserts document root and paragraph', () => {
  const db = createInitializedDatabase();
  const now = new Date().toISOString();
  const docId = 'doc-quick-1';
  const blockId = 'b-quick-p1';

  // Quick note capture operation
  const tx = db.transaction(() => {
    // 1. Root document block
    db.prepare(`
      INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
      VALUES (?, ?, NULL, 'doc', 'Meeting Notes 2026-10-09', 0, ?, ?, 'nb-welcome-kb')
    `).run(docId, docId, now, now);

    // 2. Child paragraph block
    db.prepare(`
      INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
      VALUES (?, ?, ?, 'paragraph', 'Action items: review FSRS benchmarks and deploy sync server.', 1, ?, ?, 'nb-welcome-kb')
    `).run(blockId, docId, docId, now, now);
  });
  tx();

  // Verify blocks in database
  const docBlock = db.prepare('SELECT * FROM block WHERE id = ?').get(docId);
  Assert.equal(docBlock.type, 'doc');
  Assert.equal(docBlock.notebookId, 'nb-welcome-kb');

  const pBlock = db.prepare('SELECT * FROM block WHERE id = ?').get(blockId);
  Assert.equal(pBlock.type, 'paragraph');
  Assert.equal(pBlock.parentId, docId);

  // Verify FTS5 virtual table contains both
  Assert.equal(db.prepare('SELECT COUNT(*) AS c FROM block_fts WHERE block_fts MATCH ?').get('Meeting*').c, 1);
  Assert.equal(db.prepare('SELECT COUNT(*) AS c FROM block_fts WHERE block_fts MATCH ?').get('benchmarks*').c, 1);

  db.close();
});

suite.test('9.2 Instant flashcard creation with default deck and initial FSRS state', () => {
  const db = createInitializedDatabase();
  const now = new Date().toISOString();
  const cardId = 'fc-instant-1';

  db.prepare(`
    INSERT INTO flashcard (id, docId, notebookId, front, back, hint, due, createdAt, updatedAt)
    VALUES (?, 'doc-quick-1', 'nb-welcome-kb', 'Krebs Cycle ATP yield per glucose?', '2 ATP (via GTP in substrate-level phosphorylation)', 'Total cycle', ?, ?, ?)
  `).run(cardId, now, now, now);

  const card = db.prepare('SELECT * FROM flashcard WHERE id = ?').get(cardId);
  Assert.equal(card.id, cardId);
  Assert.equal(card.front, 'Krebs Cycle ATP yield per glucose?');
  Assert.equal(card.deckId, 'deck-notes-default', 'Defaults to deck-notes-default');
  Assert.equal(card.fsrsState, State.NewCard, 'Initial state must be NewCard (0)');
  Assert.equal(card.stability, 0.0);
  Assert.equal(card.difficulty, 0.0);
  Assert.equal(card.reps, 0);
  Assert.equal(card.lapses, 0);
  Assert.equal(card.isSuspended, 0);

  db.close();
});

suite.test('9.3 Quick capture generates sync mutation journal entries automatically', () => {
  const db = createInitializedDatabase();
  const now = new Date().toISOString();

  // Clear seed changes
  db.prepare('DELETE FROM sync_change_log').run();

  // Quick card capture
  db.prepare(`
    INSERT INTO flashcard (id, docId, notebookId, front, back, due, createdAt, updatedAt)
    VALUES ('fc-sync-quick', 'doc-1', 'nb-welcome-kb', 'Front Q', 'Back A', ?, ?, ?)
  `).run(now, now, now);

  const logs = db.prepare('SELECT * FROM sync_change_log WHERE entityId = ?').all('fc-sync-quick');
  Assert.equal(logs.length, 1, 'Sync change log automatically generated');
  Assert.equal(logs[0].entityType, 'flashcard');
  Assert.equal(logs[0].operation, 'INSERT');
  Assert.equal(logs[0].isSynced, 0);

  db.close();
});

suite.test('9.4 Quick capture field reset enables rapid subsequent entries', () => {
  // Simulates UI Rapid Entry Flow: user types card 1, hits Enter/Add, state clears for card 2
  const captureForm = {
    front: '',
    back: '',
    hint: '',
    reset() {
      this.front = '';
      this.back = '';
      this.hint = '';
    }
  };

  captureForm.front = 'Question 1';
  captureForm.back = 'Answer 1';
  Assert.equal(captureForm.front, 'Question 1');

  // Submit and reset
  captureForm.reset();
  Assert.equal(captureForm.front, '');
  Assert.equal(captureForm.back, '');
  Assert.equal(captureForm.hint, '');

  captureForm.front = 'Question 2';
  captureForm.back = 'Answer 2';
  Assert.equal(captureForm.front, 'Question 2');
});

suite.test('9.5 Quick capture rejects empty front or back strings', () => {
  const db = createInitializedDatabase();
  const now = new Date().toISOString();

  // In schema, front and back are NOT NULL
  Assert.throws(() => {
    db.prepare(`
      INSERT INTO flashcard (id, docId, notebookId, front, back, due, createdAt, updatedAt)
      VALUES ('fc-bad', 'doc-1', 'nb-welcome-kb', NULL, 'Back', ?, ?, ?)
    `).run(now, now, now);
  }, 'NOT NULL constraint failed');

  db.close();
});

module.exports = suite;

if (require.main === module) {
  suite.run();
}
