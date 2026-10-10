/**
 * Tier 4 Real-World Scenario: 04. Knowledge Base Search & Reader Navigation
 * Simulates a student searching their knowledge base via FTS5 prefix queries,
 * inspecting BM25 highlighted snippets, and navigating directly into the
 * hierarchical document reader with indentation, WikiLinks, and section folding.
 */

const { TestSuite, Assert } = require('../lib/test_framework');
const { createInitializedDatabase } = require('../lib/sqlite_schema');
const { SearchEngine } = require('../lib/search_engine');
const { ReaderEngine } = require('../lib/reader_engine');

const suite = new TestSuite('Tier 4: Scenario 4 — KB Search & Reader Navigation');

suite.test('4.4 End-to-end search query to hierarchical reader inspection and folding', () => {
  const db = createInitializedDatabase();
  const now = new Date().toISOString();
  const docId = 'doc-biochem-kb';

  // 1. Seed complex hierarchical note with WikiLinks and sections
  db.transaction(() => {
    // Root doc
    db.prepare(`
      INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
      VALUES (?, ?, NULL, 'doc', 'Cellular Metabolism & Bioenergetics', 0, ?, ?, 'nb-welcome-kb')
    `).run(docId, docId, now, now);

    // Heading 1: Glycolysis
    db.prepare(`
      INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
      VALUES ('b-h1-glyco', ?, ?, 'heading1', 'Glycolytic Pathway', 1, ?, ?, 'nb-welcome-kb')
    `).run(docId, docId, now, now);

    // Paragraph with key search terms and WikiLink
    db.prepare(`
      INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
      VALUES ('b-p-pfk1', ?, 'b-h1-glyco', 'paragraph', 'Phosphofructokinase-1 (PFK-1) is the rate-limiting committed step of glycolysis. See [[Krebs Cycle]] for downstream pyruvate fate.', 2, ?, ?, 'nb-welcome-kb')
    `).run(docId, now, now);

    // Heading 1: Gluconeogenesis (will fold)
    db.prepare(`
      INSERT INTO block (id, rootDocId, parentId, type, content, isCollapsed, sortOrder, createdAt, updatedAt, notebookId)
      VALUES ('b-h1-gluco', ?, ?, 'heading1', 'Gluconeogenesis Reversals', 0, 3, ?, ?, 'nb-welcome-kb')
    `).run(docId, docId, now, now);

    // Paragraph inside gluconeogenesis
    db.prepare(`
      INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
      VALUES ('b-p-fbpase', ?, 'b-h1-gluco', 'paragraph', 'Fructose-1,6-bisphosphatase bypasses PFK-1 in liver hepatocytes.', 4, ?, ?, 'nb-welcome-kb')
    `).run(docId, now, now);
  })();

  // 2. Student searches: 'glycoly phospho'
  const searchResults = SearchEngine.search(db, 'glycoly phospho');
  Assert.ok(searchResults.length >= 1, 'Search finds metabolic notes');

  const topMatch = searchResults[0];
  Assert.equal(topMatch.id, 'b-p-pfk1');
  Assert.ok(topMatch.snippet.includes('<b>Phosphofructokinase</b>') || topMatch.snippet.includes('<b>glycolysis</b>'));

  // 3. User taps result to open Document Reader for docId
  const docBlocks = db.prepare('SELECT * FROM block WHERE rootDocId = ? ORDER BY sortOrder ASC').all(topMatch.rootDocId);
  const readerTree = ReaderEngine.buildBlockTree(docBlocks, topMatch.rootDocId);

  // 4. Verify indentation structure
  const pfk1Block = readerTree.allBlocks.find(b => b.id === 'b-p-pfk1');
  Assert.equal(pfk1Block.depth, 2, 'PFK-1 block indented at depth 2');
  Assert.equal(pfk1Block.indentDp, 40, 'Indentation = 40dp');

  // 5. Verify WikiLink extraction
  const extractedLinks = ReaderEngine.extractWikiLinks(pfk1Block.content);
  Assert.deepEqual(extractedLinks, ['Krebs Cycle'], 'Extracted WikiLink to Krebs Cycle');

  // 6. Student collapses Gluconeogenesis section to focus
  db.prepare('UPDATE block SET isCollapsed = 1 WHERE id = ?').run('b-h1-gluco');
  const refreshedBlocks = db.prepare('SELECT * FROM block WHERE rootDocId = ? ORDER BY sortOrder ASC').all(docId);
  const foldedTree = ReaderEngine.buildBlockTree(refreshedBlocks, docId);

  Assert.equal(foldedTree.visibleBlocks.length, 4, 'Bypassed paragraph hidden by fold');
  const visibleIds = foldedTree.visibleBlocks.map(b => b.id);
  Assert.ok(!visibleIds.includes('b-p-fbpase'));

  db.close();
});

module.exports = suite;

if (require.main === module) {
  suite.run();
}
