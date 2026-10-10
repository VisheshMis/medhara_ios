/**
 * Tier 1 Feature Coverage: 06. Hierarchical Document Reader & Parser
 * Verifies tree construction, indentation calculations (20dp * depth),
 * fold/toggle collapse filtering, WikiLink [[...]] and blockRef ((...)) parsing per R1.
 */

const { TestSuite, Assert } = require('../lib/test_framework');
const { ReaderEngine } = require('../lib/reader_engine');

const suite = new TestSuite('Tier 1: Hierarchical Document Reader (R1)');

suite.test('6.1 Hierarchical block tree assembly and rootDocId grouping', () => {
  const blocks = [
    { id: 'doc-neuro', rootDocId: 'doc-neuro', parentId: null, type: 'doc', content: 'Neurobiology', sortOrder: 0 },
    { id: 'h1-synapse', rootDocId: 'doc-neuro', parentId: 'doc-neuro', type: 'heading1', content: 'Synaptic Transmission', sortOrder: 1 },
    { id: 'p-axon', rootDocId: 'doc-neuro', parentId: 'h1-synapse', type: 'paragraph', content: 'Action potential propagates along the axon.', sortOrder: 2 },
  ];

  const tree = ReaderEngine.buildBlockTree(blocks, 'doc-neuro');
  Assert.equal(tree.allBlocks.length, 3);
  Assert.equal(tree.visibleBlocks.length, 3);

  const root = tree.allBlocks.find(b => b.id === 'doc-neuro');
  const h1 = tree.allBlocks.find(b => b.id === 'h1-synapse');
  const p = tree.allBlocks.find(b => b.id === 'p-axon');

  Assert.equal(root.depth, 0);
  Assert.equal(h1.depth, 1);
  Assert.equal(p.depth, 2);
});

suite.test('6.2 Indentation calculation: 20dp padding per depth level', () => {
  const blocks = [
    { id: 'root', rootDocId: 'root', parentId: null, type: 'doc', content: 'Root', sortOrder: 0 },
    { id: 'lvl1', rootDocId: 'root', parentId: 'root', type: 'bulletList', content: 'Item 1', sortOrder: 1 },
    { id: 'lvl2', rootDocId: 'root', parentId: 'lvl1', type: 'bulletList', content: 'Subitem 1.1', sortOrder: 2 },
    { id: 'lvl3', rootDocId: 'root', parentId: 'lvl2', type: 'bulletList', content: 'Subitem 1.1.1', sortOrder: 3 },
  ];

  const tree = ReaderEngine.buildBlockTree(blocks, 'root');
  Assert.equal(tree.allBlocks[0].indentDp, 0, 'Root level indentation = 0dp');
  Assert.equal(tree.allBlocks[1].indentDp, 20, 'Level 1 indentation = 20dp');
  Assert.equal(tree.allBlocks[2].indentDp, 40, 'Level 2 indentation = 40dp');
  Assert.equal(tree.allBlocks[3].indentDp, 60, 'Level 3 indentation = 60dp');
});

suite.test('6.3 Block ordering strictly preserves sortOrder ASC', () => {
  const unorderedBlocks = [
    { id: 'b3', rootDocId: 'doc-1', parentId: 'doc-1', sortOrder: 3, content: 'Third' },
    { id: 'b1', rootDocId: 'doc-1', parentId: null, sortOrder: 0, content: 'First' },
    { id: 'b2', rootDocId: 'doc-1', parentId: 'doc-1', sortOrder: 1, content: 'Second' },
  ];

  const tree = ReaderEngine.buildBlockTree(unorderedBlocks, 'doc-1');
  const contents = tree.allBlocks.map(b => b.content);
  Assert.deepEqual(contents, ['First', 'Second', 'Third']);
});

suite.test('6.4 Folding/collapsing: isCollapsed excludes descendant blocks from visibleBlocks', () => {
  const blocks = [
    { id: 'doc-1', rootDocId: 'doc-1', parentId: null, type: 'doc', content: 'Title', sortOrder: 0 },
    // Collapsed heading
    { id: 'h-fold', rootDocId: 'doc-1', parentId: 'doc-1', type: 'heading2', content: 'Collapsible Section', isCollapsed: 1, sortOrder: 1 },
    // Direct child of folded heading
    { id: 'p-child', rootDocId: 'doc-1', parentId: 'h-fold', type: 'paragraph', content: 'Hidden child paragraph', sortOrder: 2 },
    // Grandchild of folded heading
    { id: 'p-grandchild', rootDocId: 'doc-1', parentId: 'p-child', type: 'paragraph', content: 'Hidden grandchild', sortOrder: 3 },
    // Sibling of folded heading (not child)
    { id: 'h-next', rootDocId: 'doc-1', parentId: 'doc-1', type: 'heading2', content: 'Next Visible Section', isCollapsed: 0, sortOrder: 4 },
  ];

  const tree = ReaderEngine.buildBlockTree(blocks, 'doc-1');
  Assert.equal(tree.allBlocks.length, 5, 'All 5 blocks exist in full tree');
  Assert.equal(tree.visibleBlocks.length, 3, 'Only 3 blocks visible when section is folded');

  const visibleIds = tree.visibleBlocks.map(b => b.id);
  Assert.ok(visibleIds.includes('doc-1'));
  Assert.ok(visibleIds.includes('h-fold'));
  Assert.ok(!visibleIds.includes('p-child'), 'Child block hidden by collapse');
  Assert.ok(!visibleIds.includes('p-grandchild'), 'Grandchild block hidden by collapse');
  Assert.ok(visibleIds.includes('h-next'), 'Sibling section remains visible');
});

suite.test('6.5 WikiLink [[Target]] and BlockRef ((uuid)) extraction', () => {
  const text = 'Review [[Neurobiology]] and [[Glial Cells]] or consult reference ((b-ref-9876)).';

  const wikilinks = ReaderEngine.extractWikiLinks(text);
  Assert.deepEqual(wikilinks, ['Neurobiology', 'Glial Cells']);

  const refs = ReaderEngine.extractBlockRefs(text);
  Assert.deepEqual(refs, ['b-ref-9876']);
});

suite.test('6.6 Markdown inline formatting and task parsing', () => {
  const t1 = ReaderEngine.parseMarkdownInline('**Bold Concept** with *italic note* and `code sample`');
  Assert.ok(t1.hasBold);
  Assert.ok(t1.hasItalic);
  Assert.ok(t1.hasCode);
  Assert.equal(t1.isTask, false);

  const t2 = ReaderEngine.parseMarkdownInline('[x] Submit neurology lab report');
  Assert.ok(t2.isTask);
  Assert.ok(t2.isTaskCompleted);

  const t3 = ReaderEngine.parseMarkdownInline('[ ] Review flashcard queue');
  Assert.ok(t3.isTask);
  Assert.equal(t3.isTaskCompleted, false);
});

module.exports = suite;

if (require.main === module) {
  suite.run();
}
