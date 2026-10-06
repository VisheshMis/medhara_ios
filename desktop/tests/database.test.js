// Medha Windows Desktop — Stage 1 Dedicated Database & FTS5 Test Suite
// Rigorously verifies migrations v1 through v11, trigger syncs, and search edge cases

const assert = require('assert');
const Database = require('better-sqlite3');
const { DatabaseMigrations } = require('../electron/database/migrations');
const { DatabaseManager } = require('../electron/database/db');

console.log('🧪 Starting Stage 1 Database & FTS5 Verification Suite...');

// 1. Fresh Database Migration Run
const db = new Database(':memory:');
db.pragma('foreign_keys = ON');

DatabaseMigrations.registerMigrations(db);

const appliedMigrations = db.prepare('SELECT identifier FROM schema_migrations ORDER BY applied_at ASC').all();
const identifiers = appliedMigrations.map(m => m.identifier);

assert(identifiers.includes('v1_initial_schema'), 'Failed: v1 missing');
assert(identifiers.includes('v2_flashcards_and_palaces'), 'Failed: v2 missing');
assert(identifiers.includes('v3_links_to_graph'), 'Failed: v3 missing');
assert(identifiers.includes('v4_multiphoto_palace_and_locus_anchors'), 'Failed: v4 missing');
assert(identifiers.includes('v5_vast_canvas_photos'), 'Failed: v5 missing');
assert(identifiers.includes('v6_flashcard_decks'), 'Failed: v6 missing');
assert(identifiers.includes('v7_deck_options_and_card_flags'), 'Failed: v7 missing');
assert(identifiers.includes('v8_ink_notes'), 'Failed: v8 missing');
assert(identifiers.includes('v9_ink_page_pdf_import'), 'Failed: v9 missing');
assert(identifiers.includes('v10_image_occlusion_flashcards'), 'Failed: v10 missing');
assert(identifiers.includes('v11_ink_canvas_mode'), 'Failed: v11 missing');
console.log('✅ 1. All migrations v1 to v11 successfully registered and recorded in schema_migrations');

// 2. Migration Idempotency Test (run again on same DB)
assert.doesNotThrow(() => {
    DatabaseMigrations.registerMigrations(db);
}, 'Failed: Migration runner threw on re-run');
console.log('✅ 2. Migration runner is 100% idempotent on existing database');

// 3. Schema Column Verifications for v10 and v11
const flashcardCols = db.prepare('PRAGMA table_info(flashcard)').all().map(c => c.name);
assert(flashcardCols.includes('cardType'), 'Missing flashcard.cardType');
assert(flashcardCols.includes('imagePath'), 'Missing flashcard.imagePath');
assert(flashcardCols.includes('occlusionMasksData'), 'Missing flashcard.occlusionMasksData');
assert(flashcardCols.includes('activeMaskId'), 'Missing flashcard.activeMaskId');
assert(flashcardCols.includes('occlusionMode'), 'Missing flashcard.occlusionMode');

const blockCols = db.prepare('PRAGMA table_info(block)').all().map(c => c.name);
assert(blockCols.includes('canvasMode'), 'Missing block.canvasMode');
console.log('✅ 3. Schema columns for Image Occlusion (v10) and Ink Canvas Mode (v11) confirmed');

// 4. FTS5 Triggers & Search Verification
const docId = 'test-doc-1';
const nbId = 'test-nb-1';
const now = new Date().toISOString();

db.prepare(`INSERT INTO notebook (id, name, icon, sortOrder) VALUES (?, ?, ?, ?)`).run(nbId, 'Test NB', null, 0);

// Insert blocks of various types
db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
    VALUES (?, ?, NULL, 'doc', 'Quantum Computing Fundamentals', 0, ?, ?, ?)
`).run(docId, docId, now, now, nbId);

db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
    VALUES ('b1', ?, ?, 'heading1', 'Superposition and Entanglement', 1, ?, ?, ?)
`).run(docId, docId, now, now, nbId);

db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
    VALUES ('b2', ?, ?, 'paragraph', 'Qubits exploit coherent quantum mechanical phenomena.', 2, ?, ?, ?)
`).run(docId, docId, now, now, nbId);

// Test FTS search via MATCH
const searchMatch = db.prepare(`
    SELECT b.id, snippet(block_fts, 2, '<b>', '</b>', '...', 16) AS snippet
    FROM block_fts f
    JOIN block b ON b.id = f.id
    WHERE block_fts MATCH 'Entanglement*'
`).all();

assert.strictEqual(searchMatch.length, 1, 'Failed: FTS match count');
assert.strictEqual(searchMatch[0].id, 'b1', 'Failed: FTS match id');
assert(searchMatch[0].snippet.includes('<b>Entanglement</b>'), 'Failed: BM25 snippet highlighting');
console.log('✅ 4. FTS5 unicode61 tokenizer and BM25 snippet highlights verified');

// 5. Real-Time Trigger Updates
db.prepare(`UPDATE block SET content = 'Quantum decoherence occurs rapidly' WHERE id = 'b2'`).run();
const updatedSearch = db.prepare(`SELECT * FROM block_fts WHERE block_fts MATCH 'decoherence*'`).all();
assert.strictEqual(updatedSearch.length, 1, 'Failed: FTS after update trigger');

db.prepare(`DELETE FROM block WHERE id = 'b2'`).run();
const deletedSearch = db.prepare(`SELECT * FROM block_fts WHERE block_fts MATCH 'decoherence*'`).all();
assert.strictEqual(deletedSearch.length, 0, 'Failed: FTS after delete trigger');
console.log('✅ 5. Real-time FTS triggers (UPDATE and DELETE) verified');

// 6. DatabaseManager Class Methods
const manager = new DatabaseManager(':memory:');
assert(manager.getDatabase() !== null, 'Failed: manager.getDatabase()');

const insertInfo = manager.run(
    `INSERT INTO block (id, rootDocId, type, content, sortOrder, createdAt, updatedAt) VALUES (?, ?, ?, ?, ?, ?, ?)`,
    ['mgr-b1', 'mgr-doc', 'paragraph', 'Distributed Consensus with Paxos', 0, now, now]
);
assert.strictEqual(insertInfo.changes, 1, 'Failed: manager.run() changes');

const results = manager.searchFTS('Paxos');
assert.strictEqual(results.length, 1, 'Failed: manager.searchFTS');
assert.strictEqual(results[0].id, 'mgr-b1', 'Failed: manager.searchFTS id');
assert(results[0].snippet.includes('<b>Paxos</b>'), 'Failed: manager.searchFTS snippet');

// Transaction test
let committed = false;
manager.inTransaction(() => {
    manager.run(`UPDATE block SET content = 'Raft Consensus Algorithm' WHERE id = 'mgr-b1'`);
    committed = true;
});
assert(committed, 'Failed: inTransaction committed');
const queryRow = manager.queryOne(`SELECT content FROM block WHERE id = 'mgr-b1'`);
assert.strictEqual(queryRow.content, 'Raft Consensus Algorithm', 'Failed: inTransaction result');

manager.close();
console.log('✅ 6. DatabaseManager query, run, inTransaction, and searchFTS methods verified');

console.log('\n🎉 ALL STAGE 1 DATABASE VERIFICATIONS PASSED CLEANLY (100% SUITE PASS)!');
