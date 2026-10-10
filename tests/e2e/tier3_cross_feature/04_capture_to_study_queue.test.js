/**
 * Tier 3 Cross-Feature Combination: 04. Capture to Study Queue Pipeline
 * Verifies quick flashcard capture immediately populates active study session queue,
 * undergoes first review rating, and transitions out of the due queue into future schedule.
 */

const { TestSuite, Assert } = require('../lib/test_framework');
const { createInitializedDatabase } = require('../lib/sqlite_schema');
const { FSRSScheduler, Rating, State } = require('../lib/fsrs_engine');

const suite = new TestSuite('Tier 3: Quick Capture -> Study Queue -> First Review');

suite.test('3.4 Instant card capture seamlessly flows into study session and schedules future interval', () => {
  const db = createInitializedDatabase();
  const scheduler = new FSRSScheduler();
  const now = new Date();
  const cardId = 'fc-instant-study-1';

  // 1. User performs Quick Flashcard Capture
  db.prepare(`
    INSERT INTO flashcard (id, docId, notebookId, front, back, hint, fsrsState, due, createdAt, updatedAt)
    VALUES (?, 'doc-quick', 'nb-welcome-kb', 'Definition of allosteric regulation?', 'Binding of an effector molecule at a site other than the active site.', 'Enzyme kinetics', 0, ?, ?, ?)
  `).run(cardId, now.toISOString(), now.toISOString(), now.toISOString());

  // 2. Open study session and check due queue
  const dueQueueBefore = db.prepare(`
    SELECT * FROM flashcard
    WHERE isSuspended = 0 AND (fsrsState = 0 OR due <= ?)
    ORDER BY due ASC
  `).all(now.toISOString());

  Assert.equal(dueQueueBefore.length, 1, 'Newly captured card immediately present in study queue');
  Assert.equal(dueQueueBefore[0].id, cardId);
  Assert.equal(dueQueueBefore[0].fsrsState, State.NewCard);

  // 3. Rate the card Good (3) in study session
  const reviewResult = scheduler.review(dueQueueBefore[0], Rating.Good, now);
  Assert.equal(reviewResult.newState, State.Review);
  Assert.equal(reviewResult.intervalDays, 2);

  // 4. Update database
  db.prepare(`
    UPDATE flashcard SET
      fsrsState = ?, stability = ?, difficulty = ?, reps = ?, lapses = ?,
      lastReview = ?, due = ?, updatedAt = ?
    WHERE id = ?
  `).run(
    reviewResult.newState,
    reviewResult.newStability,
    reviewResult.newDifficulty,
    reviewResult.card.reps,
    reviewResult.card.lapses,
    reviewResult.card.lastReview,
    reviewResult.card.due,
    reviewResult.card.updatedAt,
    cardId
  );

  // 5. Query study queue again for current moment
  const dueQueueAfter = db.prepare(`
    SELECT * FROM flashcard
    WHERE isSuspended = 0 AND (fsrsState = 0 OR due <= ?)
  `).all(now.toISOString());

  Assert.equal(dueQueueAfter.length, 0, 'Card successfully scheduled for future and removed from current due queue');

  // Verify due date is 2 days in future
  const updatedCard = db.prepare('SELECT * FROM flashcard WHERE id = ?').get(cardId);
  const scheduledTime = new Date(updatedCard.due).getTime();
  const expectedMinTime = now.getTime() + 1.9 * 24 * 60 * 60 * 1000;
  Assert.ok(scheduledTime >= expectedMinTime, 'Card due date advanced ~2 days into future');

  db.close();
});

module.exports = suite;

if (require.main === module) {
  suite.run();
}
