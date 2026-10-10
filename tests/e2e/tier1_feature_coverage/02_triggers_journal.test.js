/**
 * Tier 1 Feature Coverage: 02. SQLite Triggers & Mutation Journaling
 * Verifies real-time FTS5 synchronization triggers and sync_change_log
 * mutation journal triggers for block, notebook, and flashcard entities.
 */

const { TestSuite, Assert } = require('../lib/test_framework');
const { createInitializedDatabase } = require('../lib/sqlite_schema');

const suite = new TestSuite('Tier 1: Triggers & Mutation Journaling (R1, R2, R3)');

suite.test('2.1 block_after_insert synchronizes block_fts in real time', () => {
  const db = createInitializedDatabase({ seedDefaults: false });
  const now = new Date().toISOString();

  db.prepare('INSERT INTO notebook (id, name, sortOrder) VALUES (?, ?, ?)').run('nb-trg', 'Triggers Notebook', 0);

  // Insert block into table block
  db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
    VALUES ('b-trg-1', 'doc-1', NULL, 'paragraph', 'Heuristic evaluation of distributed consensus algorithms', 0, ?, ?, 'nb-trg')
  `).run(now, now);

  // Check block_fts immediately contains row
  const ftsRow = db.prepare('SELECT id, content FROM block_fts WHERE id = ?').get('b-trg-1');
  Assert.ok(ftsRow !== undefined, 'block_fts must contain inserted block');
  Assert.equal(ftsRow.content, 'Heuristic evaluation of distributed consensus algorithms');

  // Verify match query
  const matchResult = db.prepare('SELECT * FROM block_fts WHERE block_fts MATCH ?').all('consensus*');
  Assert.equal(matchResult.length, 1);
  db.close();
});

suite.test('2.2 block_after_update atomically updates FTS index', () => {
  const db = createInitializedDatabase({ seedDefaults: false });
  const now = new Date().toISOString();
  db.prepare('INSERT INTO notebook (id, name, sortOrder) VALUES (?, ?, ?)').run('nb-trg', 'Triggers Notebook', 0);

  db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
    VALUES ('b-trg-2', 'doc-1', NULL, 'paragraph', 'Initial draft about Byzantine Fault Tolerance', 0, ?, ?, 'nb-trg')
  `).run(now, now);

  // Verify initial index
  const initMatch = db.prepare('SELECT * FROM block_fts WHERE block_fts MATCH ?').all('Byzantine*');
  Assert.equal(initMatch.length, 1);

  // Update block content
  db.prepare(`
    UPDATE block SET content = 'Revised draft on Raft leader election mechanism', updatedAt = ? WHERE id = 'b-trg-2'
  `).run(now);

  // Old term must no longer match
  const oldMatch = db.prepare('SELECT * FROM block_fts WHERE block_fts MATCH ?').all('Byzantine*');
  Assert.equal(oldMatch.length, 0, 'Old search term must be purged from FTS');

  // New term must match
  const newMatch = db.prepare('SELECT * FROM block_fts WHERE block_fts MATCH ?').all('Raft*');
  Assert.equal(newMatch.length, 1, 'New search term must match in FTS');
  db.close();
});

suite.test('2.3 block_after_delete purges row from FTS index', () => {
  const db = createInitializedDatabase({ seedDefaults: false });
  const now = new Date().toISOString();
  db.prepare('INSERT INTO notebook (id, name, sortOrder) VALUES (?, ?, ?)').run('nb-trg', 'Triggers Notebook', 0);

  db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
    VALUES ('b-trg-3', 'doc-1', NULL, 'paragraph', 'Ephemeral notes about CRDT state-based replication', 0, ?, ?, 'nb-trg')
  `).run(now, now);

  // Verify present
  Assert.equal(db.prepare('SELECT COUNT(*) AS c FROM block_fts WHERE id = ?').get('b-trg-3').c, 1);

  // Delete from block
  db.prepare('DELETE FROM block WHERE id = ?').run('b-trg-3');

  // Verify purged from block_fts
  Assert.equal(db.prepare('SELECT COUNT(*) AS c FROM block_fts WHERE id = ?').get('b-trg-3').c, 0);
  Assert.equal(db.prepare('SELECT * FROM block_fts WHERE block_fts MATCH ?').all('CRDT*').length, 0);
  db.close();
});

suite.test('2.4 trg_block_sync_insert logs INSERT operation to sync_change_log', () => {
  const db = createInitializedDatabase({ seedDefaults: false });
  const now = new Date().toISOString();
  db.prepare('INSERT INTO notebook (id, name, sortOrder) VALUES (?, ?, ?)').run('nb-trg', 'Triggers Notebook', 0);

  // Clear previous sync log from notebook insert
  db.prepare('DELETE FROM sync_change_log').run();

  db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
    VALUES ('b-sync-1', 'doc-1', NULL, 'heading1', 'System Architecture Overview', 0, ?, ?, 'nb-trg')
  `).run(now, now);

  const logs = db.prepare('SELECT * FROM sync_change_log WHERE entityType = ? AND entityId = ?').all('block', 'b-sync-1');
  Assert.equal(logs.length, 1, 'One sync change log entry generated');
  Assert.equal(logs[0].operation, 'INSERT');
  Assert.equal(logs[0].isSynced, 0);
  Assert.ok(logs[0].timestamp > 0);

  const payload = JSON.parse(logs[0].data);
  Assert.equal(payload.id, 'b-sync-1');
  Assert.equal(payload.content, 'System Architecture Overview');
  Assert.equal(payload.type, 'heading1');
  db.close();
});

suite.test('2.5 trg_block_sync_update logs UPDATE operation to sync_change_log', () => {
  const db = createInitializedDatabase({ seedDefaults: false });
  const now = new Date().toISOString();
  db.prepare('INSERT INTO notebook (id, name, sortOrder) VALUES (?, ?, ?)').run('nb-trg', 'Triggers Notebook', 0);

  db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
    VALUES ('b-sync-2', 'doc-1', NULL, 'paragraph', 'Initial text', 0, ?, ?, 'nb-trg')
  `).run(now, now);

  db.prepare('DELETE FROM sync_change_log').run();

  db.prepare(`UPDATE block SET content = 'Updated text payload' WHERE id = 'b-sync-2'`).run();

  const logs = db.prepare('SELECT * FROM sync_change_log WHERE entityId = ?').all('b-sync-2');
  Assert.equal(logs.length, 1);
  Assert.equal(logs[0].operation, 'UPDATE');
  const payload = JSON.parse(logs[0].data);
  Assert.equal(payload.content, 'Updated text payload');
  db.close();
});

suite.test('2.6 trg_block_sync_delete logs DELETE operation with NULL data', () => {
  const db = createInitializedDatabase({ seedDefaults: false });
  const now = new Date().toISOString();
  db.prepare('INSERT INTO notebook (id, name, sortOrder) VALUES (?, ?, ?)').run('nb-trg', 'Triggers Notebook', 0);

  db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
    VALUES ('b-sync-3', 'doc-1', NULL, 'paragraph', 'Temporary item', 0, ?, ?, 'nb-trg')
  `).run(now, now);

  db.prepare('DELETE FROM sync_change_log').run();

  db.prepare('DELETE FROM block WHERE id = ?').run('b-sync-3');

  const logs = db.prepare('SELECT * FROM sync_change_log WHERE entityId = ?').all('b-sync-3');
  Assert.equal(logs.length, 1);
  Assert.equal(logs[0].operation, 'DELETE');
  Assert.equal(logs[0].data, null, 'DELETE operation data must be NULL');
  db.close();
});

suite.test('2.7 trg_flashcard_sync_insert and update mutations journaled', () => {
  const db = createInitializedDatabase({ seedDefaults: true });
  const now = new Date().toISOString();

  db.prepare('DELETE FROM sync_change_log').run();

  // Insert flashcard
  db.prepare(`
    INSERT INTO flashcard (id, docId, notebookId, front, back, hint, due, createdAt, updatedAt)
    VALUES ('fc-sync-1', 'doc-1', 'nb-welcome-kb', 'What is CAP theorem?', 'Consistency, Availability, Partition Tolerance', 'Brewer', ?, ?, ?)
  `).run(now, now, now);

  const insertLogs = db.prepare('SELECT * FROM sync_change_log WHERE entityType = ? AND entityId = ?').all('flashcard', 'fc-sync-1');
  Assert.equal(insertLogs.length, 1);
  Assert.equal(insertLogs[0].operation, 'INSERT');

  const data = JSON.parse(insertLogs[0].data);
  Assert.equal(data.front, 'What is CAP theorem?');
  Assert.equal(data.back, 'Consistency, Availability, Partition Tolerance');

  // Update flashcard (e.g. reviewed)
  db.prepare('DELETE FROM sync_change_log').run();
  db.prepare(`
    UPDATE flashcard SET stability = 2.30, difficulty = 1.00, reps = 1, updatedAt = ? WHERE id = 'fc-sync-1'
  `).run(now);

  const updateLogs = db.prepare('SELECT * FROM sync_change_log WHERE entityId = ?').all('fc-sync-1');
  Assert.equal(updateLogs.length, 1);
  Assert.equal(updateLogs[0].operation, 'UPDATE');
  const updateData = JSON.parse(updateLogs[0].data);
  Assert.equal(updateData.stability, 2.30);
  Assert.equal(updateData.reps, 1);
  db.close();
});

module.exports = suite;

if (require.main === module) {
  suite.run();
}
