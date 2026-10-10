/**
 * Tier 4 Real-World Scenario: 01. Complete Student Review Session
 * Simulates a student opening Medha Companion, reviewing due cards across
 * different states (mature review, lapse failure, fresh cards), verifying
 * FSRS interval expansions, live preview chips, and session completion.
 */

const { TestSuite, Assert } = require('../lib/test_framework');
const { createInitializedDatabase } = require('../lib/sqlite_schema');
const { FSRSScheduler, Rating, State } = require('../lib/fsrs_engine');

const suite = new TestSuite('Tier 4: Scenario 1 — Student Review Session');

suite.test('4.1 Multi-card active recall study session workflow', () => {
  const db = createInitializedDatabase();
  const scheduler = new FSRSScheduler();
  const sessionTime = new Date('2026-10-09T15:00:00Z');
  const past3d = new Date('2026-10-06T15:00:00Z').toISOString();
  const past5d = new Date('2026-10-04T15:00:00Z').toISOString();
  const futureDate = new Date('2026-10-15T15:00:00Z').toISOString();

  // Populate Deck with realistic student cards
  // Card 1: Review card due today (will rate Good)
  db.prepare(`
    INSERT INTO flashcard (id, docId, notebookId, front, back, fsrsState, stability, difficulty, reps, lapses, lastReview, due, createdAt, updatedAt)
    VALUES ('c1-cardio', 'doc-1', 'nb-welcome-kb', 'Frank-Starling Law mechanism?', 'Increased end-diastolic volume stretches cardiac myocytes, increasing contractile force.', 2, 2.30, 1.00, 1, 0, ?, ?, ?, ?)
  `).run(past3d, past3d, past3d, past3d);

  // Card 2: Review card due today (student forgets, will rate Again)
  db.prepare(`
    INSERT INTO flashcard (id, docId, notebookId, front, back, fsrsState, stability, difficulty, reps, lapses, lastReview, due, createdAt, updatedAt)
    VALUES ('c2-renal', 'doc-1', 'nb-welcome-kb', 'Glomerular filtration barrier layers?', 'Fenestrated endothelium, basement membrane, and podocyte foot processes.', 2, 25.0, 3.0, 3, 0, ?, ?, ?, ?)
  `).run(past5d, past5d, past5d, past5d);

  // Card 3: Fresh card (student finds easy, will rate Easy)
  db.prepare(`
    INSERT INTO flashcard (id, docId, notebookId, front, back, fsrsState, due, createdAt, updatedAt)
    VALUES ('c3-anatomy', 'doc-1', 'nb-welcome-kb', 'Cranial Nerve X name?', 'Vagus nerve', 0, ?, ?, ?)
  `).run(past3d, past3d, past3d);

  // Card 4: Future card (NOT due)
  db.prepare(`
    INSERT INTO flashcard (id, docId, notebookId, front, back, fsrsState, due, createdAt, updatedAt)
    VALUES ('c4-future', 'doc-1', 'nb-welcome-kb', 'Future card', 'Not due yet', 2, ?, ?, ?)
  `).run(futureDate, past3d, past3d);

  // --- Session Starts ---

  // Step 1: Fetch session queue
  const queue = db.prepare(`
    SELECT * FROM flashcard
    WHERE isSuspended = 0 AND (fsrsState = 0 OR due <= ?)
    ORDER BY due ASC
  `).all(sessionTime.toISOString());

  Assert.equal(queue.length, 3, 'Exactly 3 cards are due in study session');
  Assert.equal(queue[0].id, 'c2-renal');
  Assert.equal(queue[1].id, 'c1-cardio');
  Assert.equal(queue[2].id, 'c3-anatomy');

  // Step 2: Review Card 1 (c2-renal) -> Student lapses (Again)
  const card1 = queue[0];
  const prev1 = scheduler.previewIntervals(card1, sessionTime);
  Assert.equal(prev1[Rating.Again], 8); // Decayed interval

  const res1 = scheduler.review(card1, Rating.Again, sessionTime);
  Assert.equal(res1.newState, State.Relearning, 'Card enters Relearning');
  Assert.equal(res1.card.lapses, 1, 'Lapses incremented');

  db.prepare(`
    UPDATE flashcard SET
      fsrsState = ?, stability = ?, difficulty = ?, elapsedDays = ?, scheduledDays = ?,
      reps = ?, lapses = ?, lastReview = ?, due = ?, updatedAt = ?
    WHERE id = ?
  `).run(
    res1.newState, res1.newStability, res1.newDifficulty, res1.card.elapsedDays,
    res1.card.scheduledDays, res1.card.reps, res1.card.lapses, res1.card.lastReview,
    res1.card.due, res1.card.updatedAt, card1.id
  );
  db.prepare('INSERT INTO review_log VALUES (?, ?, ?, ?, ?, ?, ?)').run(
    'rl-s1-1', card1.id, Rating.Again, 'Relearning', res1.card.elapsedDays, res1.intervalDays, sessionTime.toISOString()
  );

  // Step 3: Review Card 2 (c1-cardio) -> Student recalls successfully (Good)
  const card2 = queue[1];
  const prev2 = scheduler.previewIntervals(card2, sessionTime);
  Assert.ok(prev2[Rating.Good] >= 1);

  const res2 = scheduler.review(card2, Rating.Good, sessionTime);
  Assert.equal(res2.newState, State.Review);
  Assert.ok(res2.newStability > card2.stability, 'Stability expanded');

  db.prepare(`
    UPDATE flashcard SET
      fsrsState = ?, stability = ?, difficulty = ?, elapsedDays = ?, scheduledDays = ?,
      reps = ?, lapses = ?, lastReview = ?, due = ?, updatedAt = ?
    WHERE id = ?
  `).run(
    res2.newState, res2.newStability, res2.newDifficulty, res2.card.elapsedDays,
    res2.card.scheduledDays, res2.card.reps, res2.card.lapses, res2.card.lastReview,
    res2.card.due, res2.card.updatedAt, card2.id
  );
  db.prepare('INSERT INTO review_log VALUES (?, ?, ?, ?, ?, ?, ?)').run(
    'rl-s1-2', card2.id, Rating.Good, 'Review', res2.card.elapsedDays, res2.intervalDays, sessionTime.toISOString()
  );

  // Step 4: Review Card 3 (c3-anatomy) -> Student rates Easy
  const card3 = queue[2];
  const res3 = scheduler.review(card3, Rating.Easy, sessionTime);
  Assert.equal(res3.newState, State.Review);
  Assert.equal(res3.intervalDays, 11, 'Easy rating on fresh card schedules 11 days');

  db.prepare(`
    UPDATE flashcard SET
      fsrsState = ?, stability = ?, difficulty = ?, elapsedDays = ?, scheduledDays = ?,
      reps = ?, lapses = ?, lastReview = ?, due = ?, updatedAt = ?
    WHERE id = ?
  `).run(
    res3.newState, res3.newStability, res3.newDifficulty, res3.card.elapsedDays,
    res3.card.scheduledDays, res3.card.reps, res3.card.lapses, res3.card.lastReview,
    res3.card.due, res3.card.updatedAt, card3.id
  );
  db.prepare('INSERT INTO review_log VALUES (?, ?, ?, ?, ?, ?, ?)').run(
    'rl-s1-3', card3.id, Rating.Easy, 'Review', 0, 11, sessionTime.toISOString()
  );

  // Step 5: Check remaining queue for current session
  const remaining = db.prepare(`
    SELECT COUNT(*) AS c FROM flashcard
    WHERE isSuspended = 0 AND (fsrsState = 0 OR due <= ?)
  `).get(sessionTime.toISOString()).c;

  Assert.equal(remaining, 0, 'Session complete! 0 cards remaining due.');

  // Step 6: Verify 3 review log entries recorded
  const reviewLogs = db.prepare('SELECT * FROM review_log').all();
  Assert.equal(reviewLogs.length, 3, 'Audit trail records all 3 reviews');

  db.close();
});

module.exports = suite;

if (require.main === module) {
  suite.run();
}
