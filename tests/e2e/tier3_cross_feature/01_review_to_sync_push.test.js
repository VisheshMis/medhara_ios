/**
 * Tier 3 Cross-Feature Combination: 01. Card Review to Sync Push Pipeline
 * Verifies full end-to-end integration: Card study review -> FSRS-4.5 computation
 * -> atomic SQLite write -> review_log creation -> sync_change_log trigger
 * -> sync server push batch -> server journal and Lamport advancement.
 */

const { TestSuite, Assert } = require('../lib/test_framework');
const { createInitializedDatabase } = require('../lib/sqlite_schema');
const { FSRSScheduler, Rating, State } = require('../lib/fsrs_engine');
const { LightweightSyncServer } = require('../lib/sync_engine');

const suite = new TestSuite('Tier 3: Card Review -> SQLite -> Sync Server Push');

suite.test('3.1 Full pipeline: Review -> FSRS -> SQLite -> ReviewLog -> Sync Push', () => {
  const db = createInitializedDatabase();
  const scheduler = new FSRSScheduler();
  const server = new LightweightSyncServer();
  const now = new Date();

  // 1. Setup new card in local DB
  const cardId = 'fc-e2e-rev-1';
  db.prepare(`
    INSERT INTO flashcard (id, docId, notebookId, front, back, fsrsState, due, createdAt, updatedAt)
    VALUES (?, 'doc-bio', 'nb-welcome-kb', 'What is glycolysis?', 'Metabolic pathway converting glucose to pyruvate', 0, ?, ?, ?)
  `).run(cardId, now.toISOString(), now.toISOString(), now.toISOString());

  // Clear previous sync change logs from card creation
  db.prepare('DELETE FROM sync_change_log').run();

  // 2. Fetch card and perform study review (Rating Good = 3)
  const card = db.prepare('SELECT * FROM flashcard WHERE id = ?').get(cardId);
  const reviewResult = scheduler.review(card, Rating.Good, now);

  Assert.equal(reviewResult.newState, State.Review);
  Assert.equal(reviewResult.newStability, 2.30);
  Assert.equal(reviewResult.newDifficulty, 1.00);
  Assert.equal(reviewResult.intervalDays, 2);

  // 3. Atomically persist review to SQLite
  const tx = db.transaction(() => {
    db.prepare(`
      UPDATE flashcard SET
        fsrsState = ?, stability = ?, difficulty = ?, elapsedDays = ?, scheduledDays = ?,
        reps = ?, lapses = ?, lastReview = ?, due = ?, updatedAt = ?
      WHERE id = ?
    `).run(
      reviewResult.newState,
      reviewResult.newStability,
      reviewResult.newDifficulty,
      reviewResult.card.elapsedDays,
      reviewResult.card.scheduledDays,
      reviewResult.card.reps,
      reviewResult.card.lapses,
      reviewResult.card.lastReview,
      reviewResult.card.due,
      reviewResult.card.updatedAt,
      cardId
    );

    db.prepare(`
      INSERT INTO review_log (id, cardId, rating, state, elapsedDays, scheduledDays, reviewTime)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run('rl-pipe-1', cardId, Rating.Good, 'Review', 0, reviewResult.intervalDays, now.toISOString());
  });
  tx();

  // 4. Verify trigger wrote to sync_change_log
  const pendingChanges = db.prepare('SELECT * FROM sync_change_log WHERE isSynced = 0').all();
  Assert.ok(pendingChanges.length >= 1, 'At least one sync mutation change logged');

  const cardChange = pendingChanges.find(c => c.entityId === cardId);
  Assert.equal(cardChange.operation, 'UPDATE');
  const payload = JSON.parse(cardChange.data);
  Assert.equal(payload.stability, 2.30);
  Assert.equal(payload.fsrsState, State.Review);

  // 5. Construct client push request
  const clientPushPayload = {
    deviceId: 'android-companion-dev1',
    changes: [
      {
        id: `chg-${cardChange.id}`,
        entityType: cardChange.entityType,
        entityId: cardChange.entityId,
        operation: cardChange.operation,
        data: payload,
        lamportClock: 1,
        clientTimestamp: now.toISOString(),
        deviceId: 'android-companion-dev1'
      },
      {
        id: 'chg-rl-1',
        entityType: 'review_log',
        entityId: 'rl-pipe-1',
        operation: 'INSERT',
        data: { id: 'rl-pipe-1', cardId, rating: Rating.Good, scheduledDays: 2 },
        lamportClock: 2,
        clientTimestamp: now.toISOString(),
        deviceId: 'android-companion-dev1'
      }
    ]
  };

  // 6. Push to Sync Server
  const pushResponse = server.handlePush(clientPushPayload);
  Assert.equal(pushResponse.accepted, 2, 'Both changes accepted by server');
  Assert.ok(pushResponse.serverLamport >= 2);

  // 7. Mark as synced in local DB
  db.prepare('UPDATE sync_change_log SET isSynced = 1 WHERE id = ?').run(cardChange.id);
  const remainingUnsynced = db.prepare('SELECT COUNT(*) AS c FROM sync_change_log WHERE isSynced = 0').get().c;
  Assert.equal(remainingUnsynced, 0, 'Zero unsynced changes remaining in local journal');

  db.close();
});

module.exports = suite;

if (require.main === module) {
  suite.run();
}
