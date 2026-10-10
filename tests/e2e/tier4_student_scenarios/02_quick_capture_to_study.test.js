/**
 * Tier 4 Real-World Scenario: 02. Quick Capture to Study Pipeline
 * Simulates a student in a lecture capturing rapid flashcards, which
 * instantly appear in their study queue, get reviewed, and enter the FSRS schedule.
 */

const { TestSuite, Assert } = require('../lib/test_framework');
const { createInitializedDatabase } = require('../lib/sqlite_schema');
const { FSRSScheduler, Rating, State } = require('../lib/fsrs_engine');

const suite = new TestSuite('Tier 4: Scenario 2 — Quick Capture to Study Pipeline');

suite.test('4.2 Rapid card capture during lecture to first review cycle', () => {
  const db = createInitializedDatabase();
  const scheduler = new FSRSScheduler();
  const captureTime = new Date('2026-10-09T14:00:00Z');

  // 1. Student captures 3 cards in rapid succession
  const lectureCards = [
    { id: 'fc-lec-1', front: 'Warburg effect?', back: 'Aerobic glycolysis in cancer cells' },
    { id: 'fc-lec-2', front: 'p53 gene function?', back: 'Tumor suppressor inducing apoptosis upon DNA damage' },
    { id: 'fc-lec-3', front: 'Telomerase role?', back: 'Maintains telomere length preventing replicative senescence' }
  ];

  const insertStmt = db.prepare(`
    INSERT INTO flashcard (id, docId, notebookId, front, back, fsrsState, due, createdAt, updatedAt)
    VALUES (?, 'doc-oncology', 'nb-welcome-kb', ?, ?, 0, ?, ?, ?)
  `);

  const tx = db.transaction(() => {
    for (const c of lectureCards) {
      insertStmt.run(c.id, c.front, c.back, captureTime.toISOString(), captureTime.toISOString(), captureTime.toISOString());
    }
  });
  tx();

  // 2. Open study view after lecture (e.g. 15 minutes later)
  const studyTime = new Date('2026-10-09T14:15:00Z');
  const studyQueue = db.prepare(`
    SELECT * FROM flashcard
    WHERE isSuspended = 0 AND (fsrsState = 0 OR due <= ?)
    ORDER BY createdAt ASC
  `).all(studyTime.toISOString());

  Assert.equal(studyQueue.length, 3, 'All 3 lecture cards appear in study queue');

  // 3. Review Card 1 with Good (3) -> interval: 2d
  const r1 = scheduler.review(studyQueue[0], Rating.Good, studyTime);
  Assert.equal(r1.newState, State.Review);
  Assert.equal(r1.intervalDays, 2);
  db.prepare(`UPDATE flashcard SET fsrsState = ?, stability = ?, difficulty = ?, due = ? WHERE id = ?`)
    .run(r1.newState, r1.newStability, r1.newDifficulty, r1.card.due, studyQueue[0].id);

  // 4. Review Card 2 with Hard (2) -> interval: 1d
  const r2 = scheduler.review(studyQueue[1], Rating.Hard, studyTime);
  Assert.equal(r2.newState, State.Review);
  Assert.equal(r2.intervalDays, 1);
  db.prepare(`UPDATE flashcard SET fsrsState = ?, stability = ?, difficulty = ?, due = ? WHERE id = ?`)
    .run(r2.newState, r2.newStability, r2.newDifficulty, r2.card.due, studyQueue[1].id);

  // 5. Review Card 3 with Easy (4) -> interval: 11d
  const r3 = scheduler.review(studyQueue[2], Rating.Easy, studyTime);
  Assert.equal(r3.newState, State.Review);
  Assert.equal(r3.intervalDays, 11);
  db.prepare(`UPDATE flashcard SET fsrsState = ?, stability = ?, difficulty = ?, due = ? WHERE id = ?`)
    .run(r3.newState, r3.newStability, r3.newDifficulty, r3.card.due, studyQueue[2].id);

  // 6. Verify study queue is now completely cleared
  const remainingDue = db.prepare(`
    SELECT COUNT(*) AS c FROM flashcard
    WHERE isSuspended = 0 AND (fsrsState = 0 OR due <= ?)
  `).get(studyTime.toISOString()).c;

  Assert.equal(remainingDue, 0, 'Study queue emptied after first review session');

  db.close();
});

module.exports = suite;

if (require.main === module) {
  suite.run();
}
