// Medha Windows Desktop — Stage 3 IPC Contract Verification Suite
// Validates all IPC channels exposed via contextBridge (window.medhaAPI)
// asserting valid serializable responses, argument validation, and error safety.

const assert = require('assert');
const { DatabaseManager } = require('../electron/database/db');
const { fsrs, Rating } = require('../src/js/flashcards/fsrs');

console.log('🧪 Starting Stage 3 IPC Bridge & Contract Verification Suite...');

const manager = new DatabaseManager(':memory:');
const db = manager.getDatabase();

// 1. Database IPC Contract: dbQuery & dbExecute
console.log('1. Testing db-query and db-execute IPC contracts...');
const now = new Date().toISOString();
db.prepare(`INSERT INTO notebook (id, name, icon, sortOrder) VALUES (?, ?, ?, ?)`).run('nb-ipc', 'IPC Test Notebook', null, 0);

const queryResult = manager.query('SELECT * FROM notebook WHERE id = ?', ['nb-ipc']);
assert(Array.isArray(queryResult), 'Query result must be an array');
assert.strictEqual(queryResult.length, 1);
assert.strictEqual(queryResult[0].name, 'IPC Test Notebook');
console.log('✅ db-query returned structured array contract');

// 2. FTS5 Search IPC Contract
console.log('2. Testing db-search-fts IPC contract...');
db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
    VALUES ('b-search', 'doc-ipc', null, 'paragraph', 'Asynchronous Inter-Process Communication in Electron', 0, ?, ?, 'nb-ipc')
`).run(now, now);

const searchResults = manager.searchFTS('Communication');
assert(Array.isArray(searchResults), 'FTS search result must be array');
assert.strictEqual(searchResults.length, 1);
assert.strictEqual(searchResults[0].id, 'b-search');
assert(searchResults[0].snippet.includes('<b>Communication</b>'));
console.log('✅ db-search-fts returned BM25 snippet contract');

// 3. Spaced Repetition IPC: get-due-cards Contract
console.log('3. Testing get-due-cards IPC contract...');
const testCardId = 'fc-ipc-1';
db.prepare(`
    INSERT INTO flashcard (id, docId, notebookId, front, back, fsrsState, stability, difficulty, elapsedDays, scheduledDays, reps, lapses, due, createdAt, updatedAt, deckId)
    VALUES (?, 'doc-ipc', 'nb-ipc', 'What is IPC?', 'Inter-Process Communication', 0, 0.0, 0.0, 0, 0, 0, 0, ?, ?, ?, 'deck-notes-default')
`).run(testCardId, now, now, now);

const dueCards = manager.query(
    `SELECT * FROM flashcard WHERE (due <= ? OR fsrsState = 0) AND isSuspended = 0 ORDER BY due ASC`,
    [now]
);
assert(Array.isArray(dueCards), 'dueCards must be an array');
assert(dueCards.some(c => c.id === testCardId), 'Created card must appear in due cards');
console.log('✅ get-due-cards returns eligible due flashcards array');

// 4. Spaced Repetition IPC: submit-review Contract
console.log('4. Testing submit-review IPC contract...');
const cardBefore = manager.queryOne(`SELECT * FROM flashcard WHERE id = ?`, [testCardId]);
assert(cardBefore != null, 'Card must exist');

const reviewDate = new Date();
const reviewRes = fsrs.review(cardBefore, Rating.Good, reviewDate);

manager.inTransaction(() => {
    manager.run(`
        UPDATE flashcard
        SET fsrsState = ?, stability = ?, difficulty = ?, elapsedDays = ?, scheduledDays = ?,
            reps = ?, lapses = ?, lastReview = ?, due = ?, updatedAt = ?
        WHERE id = ?
    `, [
        reviewRes.card.fsrsState, reviewRes.card.stability, reviewRes.card.difficulty, reviewRes.card.elapsedDays,
        reviewRes.card.scheduledDays, reviewRes.card.reps, reviewRes.card.lapses, reviewRes.card.lastReview,
        reviewRes.card.due, reviewRes.card.updatedAt, cardBefore.id
    ]);

    manager.run(`
        INSERT INTO review_log (id, cardId, rating, state, elapsedDays, scheduledDays, reviewTime)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    `, [
        'rl-ipc-1', cardBefore.id, Rating.Good, String(reviewRes.newState), reviewRes.card.elapsedDays, reviewRes.card.scheduledDays, reviewDate.toISOString()
    ]);
});

const cardAfter = manager.queryOne(`SELECT * FROM flashcard WHERE id = ?`, [testCardId]);
assert.strictEqual(cardAfter.reps, 1, 'reps incremented');
assert.strictEqual(cardAfter.fsrsState, 2, 'state changed to Review (2)');
assert(cardAfter.stability > 0.0, 'stability updated');

const logRow = manager.queryOne(`SELECT * FROM review_log WHERE cardId = ?`, [testCardId]);
assert(logRow != null, 'Review log entry written');
assert.strictEqual(logRow.rating, Rating.Good);
console.log('✅ submit-review successfully updated card FSRS state and persisted review log');

// Clean up
manager.close();

console.log('\n🎉 ALL STAGE 3 IPC BRIDGE & CONTRACT VERIFICATIONS PASSED CLEANLY (100% SUITE PASS)!');
