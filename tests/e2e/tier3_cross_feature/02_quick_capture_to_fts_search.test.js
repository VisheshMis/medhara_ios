/**
 * Tier 3 Cross-Feature Combination: 02. Quick Capture to FTS5 Search Match
 * Verifies that scratchpad notes created in quick capture are indexed immediately
 * via SQLite triggers and discoverable via prefix-wildcard search with snippets.
 */

const { TestSuite, Assert } = require('../lib/test_framework');
const { createInitializedDatabase } = require('../lib/sqlite_schema');
const { SearchEngine } = require('../lib/search_engine');

const suite = new TestSuite('Tier 3: Quick Capture -> FTS5 Search Match');

suite.test('3.2 Instant quick capture note is immediately indexed and searchable', () => {
  const db = createInitializedDatabase();
  const now = new Date().toISOString();
  const docId = 'doc-med-note';
  const blockId = 'b-med-content';

  // 1. User performs Quick Capture note entry
  const noteTitle = 'Endocrine Pathology Highlights';
  const noteBody = 'Pheochromocytoma causes episodic hypertension through catecholamine hypersecretion in adrenal medulla chromaffin cells.';

  db.transaction(() => {
    db.prepare(`
      INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
      VALUES (?, ?, NULL, 'doc', ?, 0, ?, ?, 'nb-welcome-kb')
    `).run(docId, docId, noteTitle, now, now);

    db.prepare(`
      INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
      VALUES (?, ?, ?, 'paragraph', ?, 1, ?, ?, 'nb-welcome-kb')
    `).run(blockId, docId, docId, noteBody, now, now);
  })();

  // 2. Perform FTS5 search for prefix query 'pheochromocytoma catechol'
  const searchResults = SearchEngine.search(db, 'pheochromocytoma catechol');

  Assert.equal(searchResults.length, 1, 'Search finds newly captured note immediately');
  Assert.equal(searchResults[0].id, blockId);
  Assert.equal(searchResults[0].rootDocId, docId);
  Assert.ok(
    searchResults[0].snippet.includes('<b>Pheochromocytoma</b>') ||
    searchResults[0].snippet.includes('<b>catecholamine</b>'),
    'Snippet contains bold highlight tags'
  );

  // 3. Update note content and re-search
  const updatedBody = 'Pheochromocytoma diagnosed via urinary metanephrines and VMA testing.';
  db.prepare('UPDATE block SET content = ?, updatedAt = ? WHERE id = ?').run(updatedBody, now, blockId);

  const updatedResults = SearchEngine.search(db, 'metanephrines');
  Assert.equal(updatedResults.length, 1);
  Assert.equal(updatedResults[0].id, blockId);

  db.close();
});

module.exports = suite;

if (require.main === module) {
  suite.run();
}
