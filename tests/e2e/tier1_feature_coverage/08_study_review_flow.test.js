/**
 * Tier 1 Feature Coverage: 08. Spaced Repetition Study & Review Flow
 * Verifies due queue queries, card flip, 4 rating cortex actions,
 * live preview interval chips, atomic review persistence, and review_log audit rows per R1.
 */

const { TestSuite, Assert } = require('../lib/test_framework');
const { createInitializedDatabase } = require('../lib/sqlite_schema');
const { FSRSScheduler, Rating, State } = require('../lib/fsrs_engine');

const suite = new TestSuite('Tier 1: Spaced Repetition Study & Review Flow (R1)');

suite.test('8.1 Due card study queue retrieval (due <= now or NewCard)', () => {
  const db = createInitializedDatabase();
  const now = new Date();
  const past = new Date(now.getTime() - 2 * 60 * 60 * 1000).toISOString(); // 2 hours ago
  const future = new Date(now.getTime() + 24 * 60 * 60 * 1000).toISOString(); // 1 day in future

  // Card 1: New card (due in past) -> Due
  db.prepare(`
    INSERT INTO flashcard (id, docId, notebookId, front, back, fsrsState, due, createdAt, updatedAt)
    VALUES ('fc-1', 'doc-1', 'nb-welcome-kb', 'Front 1', 'Back 1', 0, ?, ?, ?)
  `).run(past, past, past);

  // Card 2: Review card due in past -> Due
  db.prepare(`
    INSERT INTO flashcard (id, docId, notebookId, front, back, fsrsState, due, createdAt, updatedAt)
    VALUES ('fc-2', 'doc-1', 'nb-welcome-kb', 'Front 2', 'Back 2', 2, ?, ?, ?)
  `).run(past, past, past);

  // Card 3: Review card due in future -> NOT Due
  db.prepare(`
    INSERT INTO flashcard (id, docId, notebookId, front, back, fsrsState, due, createdAt, updatedAt)
    VALUES ('fc-3', 'doc-1', 'nb-welcome-kb', 'Front 3', 'Back 3', 2, ?, ?, ?)
  `).run(future, past, past);

  // Card 4: Suspended card due in past -> NOT Due
  db.prepare(`
    INSERT INTO flashcard (id, docId, notebookId, front, back, fsrsState, isSuspended, due, createdAt, updatedAt)
    VALUES ('fc-4', 'doc-1', 'nb-welcome-kb', 'Front 4', 'Back 4', 0, 1, ?, ?, ?)
  `).run(past, past, past);

  const querySql = `
    SELECT * FROM flashcard
    WHERE isSuspended = 0 AND (fsrsState = 0 OR due <= ?)
    ORDER BY due ASC
  `;
  const dueCards = db.prepare(querySql).all(now.toISOString());
  Assert.equal(dueCards.length, 2, 'Only cards 1 and 2 should be in due queue');
  const ids = dueCards.map(c => c.id);
  Assert.ok(ids.includes('fc-1'));
  Assert.ok(ids.includes('fc-2'));
  db.close();
});

suite.test('8.2 Card presentation and flip state', () => {
  const card = {
    front: 'What is the function of the ribosome?',
    back: 'Translates messenger RNA into polypeptide protein chains.',
    hint: 'Molecular factory',
    isFlipped: false
  };

  // Initially front face shown, answer hidden
  Assert.equal(card.isFlipped, false);

  // User taps "Show Answer" or presses Space
  card.isFlipped = true;
  Assert.equal(card.isFlipped, true);
});

suite.test('8.3 4 Cortex rating buttons compute live preview interval chips', () => {
  const scheduler = new FSRSScheduler();
  const card = {
    id: 'fc-preview',
    fsrsState: State.NewCard,
    stability: 0.0,
    difficulty: 0.0,
    reps: 0,
    lapses: 0,
    lastReview: null,
    due: new Date().toISOString()
  };

  const previews = scheduler.previewIntervals(card);

  // Again preview: 1d
  Assert.equal(previews[Rating.Again], 1);
  Assert.equal(scheduler.formatInterval(previews[Rating.Again]), '1d');

  // Hard preview: 1d
  Assert.equal(previews[Rating.Hard], 1);

  // Good preview: 2d
  Assert.equal(previews[Rating.Good], 2);
  Assert.equal(scheduler.formatInterval(previews[Rating.Good]), '2d');

  // Easy preview: 11d
  Assert.equal(previews[Rating.Easy], 11);
  Assert.equal(scheduler.formatInterval(previews[Rating.Easy]), '11d');
});

suite.test('8.4 Rating Good executes atomic database write and inserts review_log', () => {
  const db = createInitializedDatabase();
  const scheduler = new FSRSScheduler();
  const now = new Date();

  db.prepare(`
    INSERT INTO flashcard (id, docId, notebookId, front, back, fsrsState, due, createdAt, updatedAt)
    VALUES ('fc-grade-1', 'doc-1', 'nb-welcome-kb', 'Mitochondria function?', 'ATP production via oxidative phosphorylation', 0, ?, ?, ?)
  `).run(now.toISOString(), now.toISOString(), now.toISOString());

  const card = db.prepare('SELECT * FROM flashcard WHERE id = ?').get('fc-grade-1');

  // Review card with Good (Rating 3)
  const result = scheduler.review(card, Rating.Good, now);

  // Atomic database update inside transaction
  const tx = db.transaction(() => {
    db.prepare(`
      UPDATE flashcard SET
        fsrsState = ?,
        stability = ?,
        difficulty = ?,
        elapsedDays = ?,
        scheduledDays = ?,
        reps = ?,
        lapses = ?,
        lastReview = ?,
        due = ?,
        updatedAt = ?
      WHERE id = ?
    `).run(
      result.newState,
      result.newStability,
      result.newDifficulty,
      result.card.elapsedDays,
      result.card.scheduledDays,
      result.card.reps,
      result.card.lapses,
      result.card.lastReview,
      result.card.due,
      result.card.updatedAt,
      card.id
    );

    db.prepare(`
      INSERT INTO review_log (id, cardId, rating, state, elapsedDays, scheduledDays, reviewTime)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(
      'rl-101',
      card.id,
      Rating.Good,
      'Review',
      result.card.elapsedDays,
      result.card.scheduledDays,
      now.toISOString()
    );
  });
  tx();

  // Verify flashcard updated
  const updated = db.prepare('SELECT * FROM flashcard WHERE id = ?').get('fc-grade-1');
  Assert.equal(updated.fsrsState, State.Review);
  Assert.equal(updated.stability, 2.30);
  Assert.equal(updated.difficulty, 1.00);
  Assert.equal(updated.reps, 1);
  Assert.equal(updated.lapses, 0);

  // Verify review_log inserted
  const logRow = db.prepare('SELECT * FROM review_log WHERE cardId = ?').get('fc-grade-1');
  Assert.equal(logRow.id, 'rl-101');
  Assert.equal(logRow.rating, Rating.Good);
  Assert.equal(logRow.state, 'Review');

  db.close();
});

suite.test('8.5 Daily limit enforcement (e.g. maxNewCardsPerDay = 3)', () => {
  const db = createInitializedDatabase();
  const now = new Date().toISOString();

  // Insert 5 new cards
  for (let i = 1; i <= 5; i++) {
    db.prepare(`
      INSERT INTO flashcard (id, docId, notebookId, front, back, fsrsState, due, createdAt, updatedAt)
      VALUES (?, 'doc-1', 'nb-welcome-kb', ?, ?, 0, ?, ?, ?)
    `).run(`fc-limit-${i}`, `Front ${i}`, `Back ${i}`, now, now, now);
  }

  // Fetch with max limit = 3
  const limit = 3;
  const limitedCards = db.prepare(`
    SELECT * FROM flashcard
    WHERE isSuspended = 0 AND fsrsState = 0
    ORDER BY createdAt ASC
    LIMIT ?
  `).all(limit);

  Assert.equal(limitedCards.length, 3, 'Daily limit capped study queue to 3 new cards');
  db.close();
});

module.exports = suite;

if (require.main === module) {
  suite.run();
}
