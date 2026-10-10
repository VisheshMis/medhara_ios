/**
 * Tier 2 Boundary & Corner Cases: 01. Notes, Text, & Hierarchy Boundaries
 * Exercises empty notes, massive text payloads, multilingual unicode edge cases,
 * deep tree nesting, orphan blocks, and malformed WikiLinks.
 */

const { TestSuite, Assert } = require('../lib/test_framework');
const { createInitializedDatabase } = require('../lib/sqlite_schema');
const { ReaderEngine } = require('../lib/reader_engine');
const { SearchEngine } = require('../lib/search_engine');

const suite = new TestSuite('Tier 2: Notes, Text, & Hierarchy Boundaries');

suite.test('2.1.1 Empty and whitespace-only note content', () => {
  const db = createInitializedDatabase();
  const now = new Date().toISOString();

  // Empty string content
  db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
    VALUES ('b-empty', 'doc-1', NULL, 'paragraph', '', 0, ?, ?, 'nb-welcome-kb')
  `).run(now, now);

  // Whitespace-only content
  db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
    VALUES ('b-ws', 'doc-1', NULL, 'paragraph', '   \t\n  ', 1, ?, ?, 'nb-welcome-kb')
  `).run(now, now);

  // Both blocks exist in table block and block_fts without trigger crashes
  const count = db.prepare("SELECT COUNT(*) AS c FROM block WHERE id IN ('b-empty', 'b-ws')").get().c;
  Assert.equal(count, 2);

  // Searching for empty/whitespace query returns safe empty results
  Assert.deepEqual(SearchEngine.search(db, ''), []);
  Assert.deepEqual(SearchEngine.search(db, '   '), []);
  db.close();
});

suite.test('2.1.2 Massive text payload (50KB markdown block)', () => {
  const db = createInitializedDatabase();
  const now = new Date().toISOString();

  const largeContent = 'Quantum superposition principles and Hilbert space dimensions. '.repeat(800); // ~50KB
  Assert.ok(largeContent.length > 50000, 'Payload exceeds 50,000 characters');

  db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
    VALUES ('b-huge', 'doc-1', NULL, 'paragraph', ?, 0, ?, ?, 'nb-welcome-kb')
  `).run(largeContent, now, now);

  // Verify FTS search over massive block succeeds and extracts snippet safely
  const results = SearchEngine.search(db, 'superposition Hilbert');
  Assert.equal(results.length, 1);
  Assert.equal(results[0].id, 'b-huge');
  Assert.ok(results[0].snippet.includes('<b>superposition</b>'));
  Assert.ok(results[0].snippet.length < 500, 'Snippet remains bounded in size');
  db.close();
});

suite.test('2.1.3 Multilingual Unicode stress (emojis, RTL Arabic/Hebrew, ZWJ)', () => {
  const db = createInitializedDatabase();
  const now = new Date().toISOString();

  // Emojis with Zero-Width Joiner (family, skin tone), RTL text, mathematical symbols
  const complexText = '🧠 Neuroscience: 👨‍👩‍👧‍👦 семья, שלום עולם, مرحباً بالعالم, ∑_{i=1}^n x_i ∈ ℝ';

  db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
    VALUES ('b-unicode', 'doc-1', NULL, 'paragraph', ?, 0, ?, ?, 'nb-welcome-kb')
  `).run(complexText, now, now);

  // Search Hebrew
  const hebRes = SearchEngine.search(db, 'שלום');
  Assert.equal(hebRes.length, 1);

  // Search Arabic
  const arRes = SearchEngine.search(db, 'مرحباً');
  Assert.equal(arRes.length, 1);

  // Search Russian
  const ruRes = SearchEngine.search(db, 'семья');
  Assert.equal(ruRes.length, 1);

  db.close();
});

suite.test('2.1.4 Deeply nested hierarchy (depth = 15)', () => {
  const blocks = [
    { id: 'doc-root', rootDocId: 'doc-root', parentId: null, type: 'doc', content: 'Root', sortOrder: 0 }
  ];

  let prevId = 'doc-root';
  for (let i = 1; i <= 15; i++) {
    const curId = `b-depth-${i}`;
    blocks.push({
      id: curId,
      rootDocId: 'doc-root',
      parentId: prevId,
      type: 'bulletList',
      content: `Level ${i}`,
      sortOrder: i
    });
    prevId = curId;
  }

  const tree = ReaderEngine.buildBlockTree(blocks, 'doc-root');
  Assert.equal(tree.allBlocks.length, 16);

  const deepest = tree.allBlocks.find(b => b.id === 'b-depth-15');
  Assert.equal(deepest.depth, 15, 'Depth must reach 15');
  Assert.equal(deepest.indentDp, 300, 'Indent must equal 15 * 20 = 300dp');
});

suite.test('2.1.5 Orphan block and circular reference resilience in reader', () => {
  // Orphan block whose parent does not exist
  const orphanBlocks = [
    { id: 'doc-1', rootDocId: 'doc-1', parentId: null, content: 'Doc' },
    { id: 'b-orphan', rootDocId: 'doc-1', parentId: 'nonexistent-parent-id', content: 'Orphan' },
    // Circular reference (bA -> bB -> bA)
    { id: 'b-circ-1', rootDocId: 'doc-1', parentId: 'b-circ-2', content: 'Circ 1' },
    { id: 'b-circ-2', rootDocId: 'doc-1', parentId: 'b-circ-1', content: 'Circ 2' },
  ];

  // Must not throw or hang in infinite recursion
  Assert.doesNotThrow(() => {
    const tree = ReaderEngine.buildBlockTree(orphanBlocks, 'doc-1');
    Assert.ok(tree.allBlocks.length === 4);
  });
});

suite.test('2.1.6 Malformed WikiLinks and block references', () => {
  // Unclosed brackets, empty links, nested brackets
  const malformed = 'Normal [[Unclosed link and [[Nested [[Deep]]]] and empty [[]] and ((bad uuid with spaces))';

  const links = ReaderEngine.extractWikiLinks(malformed);
  Assert.ok(Array.isArray(links));

  const refs = ReaderEngine.extractBlockRefs(malformed);
  Assert.ok(Array.isArray(refs));
  Assert.equal(refs.length, 0, 'Malformed block reference with spaces ignored');
});

module.exports = suite;

if (require.main === module) {
  suite.run();
}
