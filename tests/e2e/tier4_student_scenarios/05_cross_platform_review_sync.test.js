/**
 * Tier 4 Real-World Scenario: 05. Cross-Platform Review Sync Parity
 * Simulates rating a card on Android Companion, pushing delta to sync server,
 * pulling on macOS/desktop, and mathematically verifying bitwise FSRS-4.5
 * scheduler parity between both platforms.
 */

const { TestSuite, Assert } = require('../lib/test_framework');
const { createInitializedDatabase } = require('../lib/sqlite_schema');
const { FSRSScheduler, Rating, State } = require('../lib/fsrs_engine');
const { LightweightSyncServer } = require('../lib/sync_engine');

const suite = new TestSuite('Tier 4: Scenario 5 — Cross-Platform Review Sync');

suite.test('4.5 Android review delta syncs to desktop with identical mathematical FSRS stability', () => {
  const dbAndroid = createInitializedDatabase();
  const dbDesktop = createInitializedDatabase();
  const syncServer = new LightweightSyncServer();

  const schedulerAndroid = new FSRSScheduler();
  const schedulerDesktop = new FSRSScheduler();

  const reviewTime = new Date('2026-10-09T16:00:00Z');
  const cardId = 'fc-cross-plat-1';

  // Seed card on Android
  dbAndroid.prepare(`
    INSERT INTO flashcard (id, docId, notebookId, front, back, fsrsState, due, createdAt, updatedAt)
    VALUES (?, 'doc-patho', 'nb-welcome-kb', 'Pathophysiology of Myasthenia Gravis?', 'Autoantibodies against post-synaptic nicotinic acetylcholine receptors at NMJ.', 0, ?, ?, ?)
  `).run(cardId, reviewTime.toISOString(), reviewTime.toISOString(), reviewTime.toISOString());

  // 1. Android reviews card with Good (Rating 3)
  const androidCard = dbAndroid.prepare('SELECT * FROM flashcard WHERE id = ?').get(cardId);
  const androidResult = schedulerAndroid.review(androidCard, Rating.Good, reviewTime);

  Assert.equal(androidResult.newState, State.Review);
  Assert.equal(androidResult.newStability, 2.30);
  Assert.equal(androidResult.newDifficulty, 1.00);
  Assert.equal(androidResult.intervalDays, 2);

  // Update Android DB
  dbAndroid.prepare(`
    UPDATE flashcard SET fsrsState = ?, stability = ?, difficulty = ?, due = ?, updatedAt = ?
    WHERE id = ?
  `).run(androidResult.newState, androidResult.newStability, androidResult.newDifficulty, androidResult.card.due, androidResult.card.updatedAt, cardId);

  // 2. Android pushes delta to Sync Server
  const pushRes = syncServer.handlePush({
    deviceId: 'android-pixel-companion',
    changes: [
      {
        id: 'chg-sync-xplat',
        entityType: 'flashcard',
        entityId: cardId,
        operation: 'UPDATE',
        data: {
          id: cardId,
          front: androidCard.front,
          back: androidCard.back,
          fsrsState: androidResult.newState,
          stability: androidResult.newStability,
          difficulty: androidResult.newDifficulty,
          lastReview: androidResult.card.lastReview,
          due: androidResult.card.due,
          updatedAt: androidResult.card.updatedAt
        },
        lamportClock: 1,
        clientTimestamp: reviewTime.toISOString(),
        deviceId: 'android-pixel-companion'
      }
    ]
  });

  Assert.equal(pushRes.accepted, 1);

  // 3. Desktop pulls from Sync Server
  const desktopPull = syncServer.handlePull({ sinceLamport: 0, deviceId: 'macos-macbook' });
  const pulledCardChange = desktopPull.changes.find(c => c.entityId === cardId);
  Assert.ok(pulledCardChange !== undefined);

  // Desktop applies update to its database
  dbDesktop.prepare(`
    INSERT OR REPLACE INTO flashcard (id, docId, notebookId, front, back, fsrsState, stability, difficulty, lastReview, due, createdAt, updatedAt)
    VALUES (?, 'doc-patho', 'nb-welcome-kb', ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    cardId,
    pulledCardChange.data.front,
    pulledCardChange.data.back,
    pulledCardChange.data.fsrsState,
    pulledCardChange.data.stability,
    pulledCardChange.data.difficulty,
    pulledCardChange.data.lastReview,
    pulledCardChange.data.due,
    reviewTime.toISOString(),
    pulledCardChange.data.updatedAt
  );

  // 4. Verify Desktop FSRS Scheduler matches Android calculations for the next review
  const desktopCard = dbDesktop.prepare('SELECT * FROM flashcard WHERE id = ?').get(cardId);
  Assert.equal(desktopCard.stability, androidResult.newStability);
  Assert.equal(desktopCard.difficulty, androidResult.newDifficulty);

  // Simulate review 2 days later on Desktop with Good
  const t2 = new Date('2026-10-11T16:00:00Z');
  const desktopResult2 = schedulerDesktop.review(desktopCard, Rating.Good, t2);
  const androidResult2 = schedulerAndroid.review(androidResult.card, Rating.Good, t2);

  // Check 100% mathematical parity across platforms
  Assert.equal(desktopResult2.newStability, androidResult2.newStability, 'Stability identical between platforms');
  Assert.equal(desktopResult2.newDifficulty, androidResult2.newDifficulty, 'Difficulty identical between platforms');
  Assert.equal(desktopResult2.intervalDays, androidResult2.intervalDays, 'Scheduled interval identical between platforms');

  dbAndroid.close();
  dbDesktop.close();
});

module.exports = suite;

if (require.main === module) {
  suite.run();
}
