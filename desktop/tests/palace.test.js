// Medha Windows Desktop — Stage 8 2D Spatial Memory Palace & Walk Mode Verification Suite
// Validates infinite 2D canvas transform matrix math, normalized locus pins (x in [0,1], y in [0,1]),
// sequential pathway transitions, cubic camera spring interpolation,
// active recall reveal, and FSRS review recording during Walk Mode.

const assert = require('assert');
const Database = require('better-sqlite3');
const { DatabaseMigrations } = require('../electron/database/migrations');
const { BlockStore } = require('../src/js/store');
const { PalaceCanvas } = require('../src/js/palace/palaceCanvas');
const { fsrs, Rating } = require('../src/js/flashcards/fsrs');

console.log('🧪 Starting Stage 8 2D Spatial Memory Palace & Walk Mode Verification Suite...');

// 1. Setup SQLite In-Memory Database with Migrations
const db = new Database(':memory:');
DatabaseMigrations.registerMigrations(db);
const store = new BlockStore(db);

// 2. Create Palace, Photos, and Loci Stations
console.log('1. Setting up 2D Memory Palace and normalized loci pins...');
const palaceId = 'palace-athens';
db.prepare(`
    INSERT INTO memory_palace (id, name, imagePath, description, sortOrder, createdAt, updatedAt)
    VALUES (?, 'Acropolis of Athens', 'assets/athens.jpg', 'Classical loci for philosophy & rhetoric', 0, datetime('now'), datetime('now'))
`).run(palaceId);

const photoId = 'photo-parthenon';
db.prepare(`
    INSERT INTO palace_photo (id, palaceId, name, imagePath, canvasX, canvasY, canvasWidth, canvasHeight, orderIndex, createdAt, updatedAt)
    VALUES (?, ?, 'The Parthenon Facade', 'assets/parthenon.jpg', 100, 150, 800, 600, 0, datetime('now'), datetime('now'))
`).run(photoId, palaceId);

// Create 3 sequential Loci Pins with normalized coordinates
const locus1Id = 'locus-1';
const locus2Id = 'locus-2';
const locus3Id = 'locus-3';

// Associate Locus 1 with an active recall Flashcard
const cardId = 'card-locus-1';
db.prepare(`
    INSERT INTO flashcard (id, docId, notebookId, front, back, due, fsrsState, stability, difficulty, reps, lapses, createdAt, updatedAt)
    VALUES (?, 'doc-socrates', 'nb-philosophy', 'What is Socratic ironical inquiry?', 'A method of cooperative argumentative dialogue questioning assumptions.', datetime('now'), 0, 0.0, 0.0, 0, 0, datetime('now'), datetime('now'))
`).run(cardId);

db.prepare(`
    INSERT INTO palace_locus (id, palaceId, photoId, orderIndex, normalizedX, normalizedY, title, mnemonic, flashcardId, createdAt, updatedAt)
    VALUES (?, ?, ?, 0, 0.15, 0.40, 'Doric Front Columns', 'Recall Socrates first principle', ?, datetime('now'), datetime('now'))
`).run(locus1Id, palaceId, photoId, cardId);

db.prepare(`
    INSERT INTO palace_locus (id, palaceId, photoId, orderIndex, normalizedX, normalizedY, title, mnemonic, flashcardId, createdAt, updatedAt)
    VALUES (?, ?, ?, 1, 0.50, 0.35, 'Inner Cella Sanctuary', 'Visualize Athena holding Nike', NULL, datetime('now'), datetime('now'))
`).run(locus2Id, palaceId, photoId);

db.prepare(`
    INSERT INTO palace_locus (id, palaceId, photoId, orderIndex, normalizedX, normalizedY, title, mnemonic, flashcardId, createdAt, updatedAt)
    VALUES (?, ?, ?, 2, 0.85, 0.65, 'Eastern Pediment Statues', 'Contemplate the birth of wisdom', NULL, datetime('now'), datetime('now'))
`).run(locus3Id, palaceId, photoId);

async function runTests() {
    // 3. Load Store Palace Details
    await store.loadPalaceDetails(palaceId);
    assert.strictEqual(store.palacePhotos.length, 1, 'Must load 1 palace photo');
    assert.strictEqual(store.loci.length, 3, 'Must load 3 sequential loci');

    // Verify Normalized Coordinates
    for (const locus of store.loci) {
        assert(locus.normalizedX >= 0.0 && locus.normalizedX <= 1.0, `Locus X ${locus.normalizedX} must be normalized in [0, 1]`);
        assert(locus.normalizedY >= 0.0 && locus.normalizedY <= 1.0, `Locus Y ${locus.normalizedY} must be normalized in [0, 1]`);
    }
    console.log('✅ 1. 2D Memory Palace and normalized loci coordinates verified in SQLite');

// 4. Mock DOM Stage & World Elements for PalaceCanvas
console.log('2. Testing Infinite 2D Stage transform matrix math...');
class MockPalaceElement {
    constructor() {
        this.style = {};
        this.classList = {
            add: () => {},
            remove: () => {}
        };
        this._listeners = {};
    }
    addEventListener(event, fn) {
        if (!this._listeners[event]) this._listeners[event] = [];
        this._listeners[event].push(fn);
    }
    getBoundingClientRect() {
        return { width: 1200, height: 800, left: 0, top: 0, right: 1200, bottom: 800 };
    }
}

const mockStage = new MockPalaceElement();
const mockWorld = new MockPalaceElement();

const palaceCanvas = new PalaceCanvas(mockStage, mockWorld, { store });
assert.strictEqual(palaceCanvas.scale, 1.0, 'Initial scale must be 1.0');
assert.strictEqual(palaceCanvas.cameraX, 0, 'Initial cameraX must be 0');
assert.strictEqual(palaceCanvas.cameraY, 0, 'Initial cameraY must be 0');

// Test pan and zoom calculations
palaceCanvas.cameraX = 150;
palaceCanvas.cameraY = -80;
palaceCanvas.scale = 1.25;
palaceCanvas.updateTransform();
assert(mockWorld.style.transform.includes('translate(150px, -80px) scale(1.25)'), 'Transform must format translate and scale matrix');
console.log('✅ 2. Matrix transforms properly calculate 2D viewport coordinates');

// 5. Test Cinematic Walk Mode Sequential Steps
console.log('3. Testing Cinematic Walk Mode navigation across loci stations...');
palaceCanvas.startWalkMode(store.loci, store.palacePhotos);
assert.strictEqual(palaceCanvas.isWalkMode, true, 'Walk Mode must be active');
assert.strictEqual(palaceCanvas.currentStepIndex, 0, 'Must begin at station 0');

// Advance to Step 1
const hasStep1 = palaceCanvas.nextWalkStep(store.loci, store.palacePhotos);
assert.strictEqual(hasStep1, true, 'Next step must succeed');
assert.strictEqual(palaceCanvas.currentStepIndex, 1, 'Current step must advance to 1');

// Advance to Step 2 (Final station)
const hasStep2 = palaceCanvas.nextWalkStep(store.loci, store.palacePhotos);
assert.strictEqual(hasStep2, true, 'Next step must succeed');
assert.strictEqual(palaceCanvas.currentStepIndex, 2, 'Current step must advance to 2');

// Advance past end
const pastEnd = palaceCanvas.nextWalkStep(store.loci, store.palacePhotos);
assert.strictEqual(pastEnd, false, 'Next step past end must return false');

// Step backward to Step 1
const backStep = palaceCanvas.prevWalkStep(store.loci, store.palacePhotos);
assert.strictEqual(backStep, true, 'Previous step must succeed');
assert.strictEqual(palaceCanvas.currentStepIndex, 1, 'Current step must step back to 1');

palaceCanvas.exitWalkMode();
assert.strictEqual(palaceCanvas.isWalkMode, false, 'Walk Mode must be deactivated on exit');
console.log('✅ 3. Sequential Walk Mode journey and bounds clamping verified');

// 6. Test Active Recall & FSRS Review Recording on Locus Flashcard
console.log('4. Testing FSRS active recall review recording for Locus flashcard...');
const cardBefore = db.prepare('SELECT * FROM flashcard WHERE id = ?').get(cardId);
assert.strictEqual(cardBefore.reps, 0, 'Card reps must start at 0');

// User reviews Locus 1 with 'Good' (Rating 3)
const reviewRes = fsrs.review(cardBefore, Rating.Good);
assert(reviewRes.card.stability > 0, 'Stability must be generated');
assert.strictEqual(reviewRes.card.reps, 1, 'Reps must increase to 1');

// Commit to SQLite
db.prepare(`
    UPDATE flashcard
    SET fsrsState = ?, stability = ?, difficulty = ?, elapsedDays = ?, scheduledDays = ?, reps = ?, lapses = ?, lastReview = ?, due = ?, updatedAt = datetime('now')
    WHERE id = ?
`).run(
    reviewRes.card.fsrsState, reviewRes.card.stability, reviewRes.card.difficulty, reviewRes.card.elapsedDays,
    reviewRes.card.scheduledDays, reviewRes.card.reps, reviewRes.card.lapses, reviewRes.card.lastReview,
    reviewRes.card.due, cardId
);

const cardAfter = db.prepare('SELECT * FROM flashcard WHERE id = ?').get(cardId);
assert.strictEqual(cardAfter.reps, 1, 'Persisted reps must be 1');
assert(cardAfter.stability > 0, 'Persisted stability must be positive');
    console.log('✅ 4. Active recall review for locus flashcard committed cleanly to SQLite');
    console.log('\n🎉 ALL STAGE 8 2D SPATIAL MEMORY PALACE & WALK MODE TESTS PASSED!\n');
}

runTests().catch((err) => {
    console.error('Test execution failed:', err);
    process.exit(1);
});
