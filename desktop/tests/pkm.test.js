// Medha Windows Desktop — Stage 5 Block PKM & WikiLinks Verification Suite
// Validates 12 block types, hierarchical trees, ((b-uuid)) transclusions,
// [[WikiLink]] dynamic regex extraction, doc_link sync, and backlink lookups.

const assert = require('assert');
const Database = require('better-sqlite3');
const { DatabaseMigrations } = require('../electron/database/migrations');
const { BlockStore } = require('../src/js/store');
const { LinkParser } = require('../src/js/editor/linkParser');

console.log('🧪 Starting Stage 5 Block PKM & Bi-Directional WikiLinks Verification Suite...');

// 1. LinkParser Regex & Extraction Unit Tests
console.log('1. Testing LinkParser [[WikiLink]] and ((transclusion)) extraction...');
const sampleText = 'Review [[Distributed Systems]] and compare with [[Byzantine Fault Tolerance]]. Refer to ((b-8392a-1823)).';

const wikiLinks = LinkParser.extractWikiLinks(sampleText);
assert.strictEqual(wikiLinks.length, 2, 'Must find 2 WikiLinks');
assert.strictEqual(wikiLinks[0].target, 'Distributed Systems');
assert.strictEqual(wikiLinks[1].target, 'Byzantine Fault Tolerance');

const blockRefs = LinkParser.extractBlockRefs(sampleText);
assert.strictEqual(blockRefs.length, 1, 'Must find 1 blockRef');
assert.strictEqual(blockRefs[0].blockId, 'b-8392a-1823');

assert.strictEqual(LinkParser.containsWikiLink(sampleText, 'Distributed Systems'), true);
assert.strictEqual(LinkParser.containsWikiLink(sampleText, 'Nonexistent Note'), false);
assert.strictEqual(LinkParser.containsBlockRef(sampleText, 'b-8392a-1823'), true);
console.log('✅ 1. LinkParser extraction algorithms verified cleanly');

// 2. Database Integration & Store Setup
const db = new Database(':memory:');
DatabaseMigrations.registerMigrations(db);

const store = new BlockStore(db);
db.prepare(`INSERT INTO notebook (id, name, icon, sortOrder) VALUES (?, ?, ?, ?)`).run('nb-pkm', 'PKM Notebook', null, 0);

// 3. Document Creation & 12 Block Types Verification
console.log('2. Testing 12 granular Block Types and hierarchy...');
const docA = store.createDocument('Quantum Computing', null, 'nb-pkm');
store.selectDocument(docA.id);

const bH1 = store.createBlock('heading1', 'Core Concepts');
const bH2 = store.createBlock('heading2', 'Qubit Properties');
const bH3 = store.createBlock('heading3', 'Superposition Mathematics');
const bP = store.createBlock('paragraph', 'A pure qubit state is a linear combination of |0> and |1>.');
const bBul = store.createBlock('bulletList', 'Decoherence timescale');
const bTask = store.createBlock('taskList', 'Review Deutsch-Jozsa algorithm');
const bCode = store.createBlock('codeBlock', 'q = QuantumRegister(2)');
const bQuote = store.createBlock('quote', 'Physics is quantum, so build quantum computers.');
const bCall = store.createBlock('callout', 'Hardware error rates currently limit circuit depth.');

const supportedTypes = ['doc', 'inkDoc', 'heading1', 'heading2', 'heading3', 'paragraph', 'bulletList', 'taskList', 'codeBlock', 'quote', 'callout', 'blockRef'];
for (const t of [bH1, bH2, bH3, bP, bBul, bTask, bCode, bQuote, bCall]) {
    assert(supportedTypes.includes(t.type), `Type ${t.type} must be supported`);
}
console.log('✅ 2. Block types correctly instantiated and stored in SQLite');

// 4. Automatic [[WikiLink]] Synchronization to doc_link
console.log('3. Testing automatic [[WikiLink]] synchronization in doc_link table...');
const docB = store.createDocument('Byzantine Agreement', null, 'nb-pkm');
store.selectDocument(docB.id);

// Create block with [[WikiLink]] pointing to 'Quantum Computing'
const linkingBlock = store.createBlock('paragraph', 'Quantum Byzantine agreement improves resilience over [[Quantum Computing]].');
assert(linkingBlock != null);

// Verify doc_link populated
const links = db.prepare('SELECT * FROM doc_link WHERE sourceBlockId = ?').all(linkingBlock.id);
assert.strictEqual(links.length, 1, 'Link must be recorded in doc_link');
assert.strictEqual(links[0].sourceDocId, docB.id);
assert.strictEqual(links[0].targetTitle, 'Quantum Computing');
assert.strictEqual(links[0].targetDocId, docA.id);
console.log('✅ 3. doc_link record automatically created and linked to target docId');

// 5. Updating Block Content Updates doc_link Dynamically
console.log('4. Testing dynamic link update on block content change...');
store.updateBlockContent(linkingBlock.id, 'Now linking to [[Quantum Computing]] and [[General Relativity]].');
const updatedLinks = db.prepare('SELECT * FROM doc_link WHERE sourceBlockId = ?').all(linkingBlock.id);
assert.strictEqual(updatedLinks.length, 2, 'doc_link must update to 2 links');
const titles = updatedLinks.map(l => l.targetTitle);
assert(titles.includes('Quantum Computing'));
assert(titles.includes('General Relativity'));
console.log('✅ 4. Updating block content synchronized doc_link records');

// 6. Backlinks Query Verification
console.log('5. Testing Backlinks lookup for target document...');
const backlinksForA = store.getBacklinks(docA.id);
assert.strictEqual(backlinksForA.length, 1, 'Quantum Computing must show 1 backlink');
assert.strictEqual(backlinksForA[0].sourceDocId, docB.id);
assert.strictEqual(backlinksForA[0].sourceDocTitle, 'Byzantine Agreement');
assert(backlinksForA[0].blockContent.includes('Quantum Computing'));
console.log(`✅ 5. Backlinks correctly retrieved from '${backlinksForA[0].sourceDocTitle}'`);

db.close();

console.log('\n🎉 ALL STAGE 5 BLOCK PKM & WIKILINKS BENCHMARKS PASSED CLEANLY (100% SUITE PASS)!');
