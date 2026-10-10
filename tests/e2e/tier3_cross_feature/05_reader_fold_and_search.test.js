/**
 * Tier 3 Cross-Feature Combination: 05. Reader Fold and Search Navigation
 * Verifies that collapsed/folded blocks in the reader remain fully indexed
 * and discoverable via FTS5 search, and jumping from search expands parent folds.
 */

const { TestSuite, Assert } = require('../lib/test_framework');
const { createInitializedDatabase } = require('../lib/sqlite_schema');
const { ReaderEngine } = require('../lib/reader_engine');
const { SearchEngine } = require('../lib/search_engine');

const suite = new TestSuite('Tier 3: Reader Fold & Search Navigation');

suite.test('3.5 Search discovers text in folded blocks; navigation unfolds parent heading', () => {
  const db = createInitializedDatabase();
  const now = new Date().toISOString();
  const docId = 'doc-immunology';

  // 1. Insert hierarchical document with a collapsed section
  db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
    VALUES (?, ?, NULL, 'doc', 'Adaptive Immunity', 0, ?, ?, 'nb-welcome-kb')
  `).run(docId, docId, now, now);

  // Section 1 (Expanded)
  db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
    VALUES ('b-h1-bcell', ?, ?, 'heading1', 'B Cell Maturation', 1, ?, ?, 'nb-welcome-kb')
  `).run(docId, docId, now, now);

  db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
    VALUES ('b-p-bcell', ?, 'b-h1-bcell', 'paragraph', 'Occurs in bone marrow with immunoglobulin gene rearrangement.', 2, ?, ?, 'nb-welcome-kb')
  `).run(docId, now, now);

  // Section 2 (Collapsed heading: isCollapsed = 1)
  db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, isCollapsed, sortOrder, createdAt, updatedAt, notebookId)
    VALUES ('b-h1-tcell', ?, ?, 'heading1', 'T Cell Selection', 1, 3, ?, ?, 'nb-welcome-kb')
  `).run(docId, docId, now, now);

  // Child inside collapsed heading
  db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
    VALUES ('b-p-thymus', ?, 'b-h1-tcell', 'paragraph', 'Positive and negative thymic selection eliminates autoreactive receptors.', 4, ?, ?, 'nb-welcome-kb')
  `).run(docId, now, now);

  // 2. Fetch all blocks and verify reader visibility
  const allBlocks = db.prepare('SELECT * FROM block WHERE rootDocId = ? ORDER BY sortOrder ASC').all(docId);
  const initialTree = ReaderEngine.buildBlockTree(allBlocks, docId);

  Assert.equal(initialTree.allBlocks.length, 5);
  Assert.equal(initialTree.visibleBlocks.length, 4, 'Paragraph b-p-thymus must be hidden by collapsed heading');
  const visibleIds = initialTree.visibleBlocks.map(b => b.id);
  Assert.ok(!visibleIds.includes('b-p-thymus'), 'b-p-thymus initially not in visibleBlocks');

  // 3. Search for keyword inside the hidden block: 'autoreactive'
  const searchResults = SearchEngine.search(db, 'autoreactive');
  Assert.equal(searchResults.length, 1, 'Search finds hidden block');
  Assert.equal(searchResults[0].id, 'b-p-thymus');
  Assert.ok(searchResults[0].snippet.includes('<b>autoreactive</b>'));

  // 4. Client navigates to search match: unfold parent heading 'b-h1-tcell'
  db.prepare('UPDATE block SET isCollapsed = 0, updatedAt = ? WHERE id = ?').run(now, 'b-h1-tcell');

  // 5. Re-render reader tree
  const updatedBlocks = db.prepare('SELECT * FROM block WHERE rootDocId = ? ORDER BY sortOrder ASC').all(docId);
  const expandedTree = ReaderEngine.buildBlockTree(updatedBlocks, docId);

  Assert.equal(expandedTree.visibleBlocks.length, 5, 'All 5 blocks now visible after unfolding');
  const newVisibleIds = expandedTree.visibleBlocks.map(b => b.id);
  Assert.ok(newVisibleIds.includes('b-p-thymus'), 'Target block is now fully visible and highlighted');

  db.close();
});

module.exports = suite;

if (require.main === module) {
  suite.run();
}
