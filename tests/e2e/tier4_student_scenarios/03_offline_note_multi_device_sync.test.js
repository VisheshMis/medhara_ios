/**
 * Tier 4 Real-World Scenario: 03. Offline Note Taking & Multi-Device Sync
 * Simulates a student writing notes offline on mobile, which get journaled in
 * sync_change_log, and upon reconnecting, bidirectionally synchronizes with
 * the sync server and desktop client without conflict.
 */

const { TestSuite, Assert } = require('../lib/test_framework');
const { createInitializedDatabase } = require('../lib/sqlite_schema');
const { LightweightSyncServer } = require('../lib/sync_engine');

const suite = new TestSuite('Tier 4: Scenario 3 — Offline Note Taking & Sync');

suite.test('4.3 Offline note taking on mobile with delayed delta sync', () => {
  const dbMobile = createInitializedDatabase();
  const dbDesktop = createInitializedDatabase();
  const syncServer = new LightweightSyncServer();

  const flightTime = new Date('2026-10-09T10:00:00Z').toISOString();
  const landTime = new Date('2026-10-09T13:00:00Z').toISOString();

  // Clear seed changes
  dbMobile.prepare('DELETE FROM sync_change_log').run();
  dbDesktop.prepare('DELETE FROM sync_change_log').run();

  // 1. Mobile is offline (on a flight): student writes new lecture notes
  const noteId = 'doc-flight-genetics';
  const headingId = 'b-fl-h1';
  const paragraphId = 'b-fl-p1';

  dbMobile.transaction(() => {
    dbMobile.prepare(`
      INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
      VALUES (?, ?, NULL, 'doc', 'Mendelian Genetics Review', 0, ?, ?, 'nb-welcome-kb')
    `).run(noteId, noteId, flightTime, flightTime);

    dbMobile.prepare(`
      INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
      VALUES (?, ?, ?, 'heading1', 'Law of Independent Assortment', 1, ?, ?, 'nb-welcome-kb')
    `).run(headingId, noteId, noteId, flightTime, flightTime);

    dbMobile.prepare(`
      INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
      VALUES (?, ?, ?, 'paragraph', 'Alleles of different genes segregate independently during gamete formation.', 2, ?, ?, 'nb-welcome-kb')
    `).run(paragraphId, noteId, headingId, flightTime, flightTime);
  })();

  // Verify mobile recorded 3 unsynced changes in journal
  const mobilePending = dbMobile.prepare('SELECT * FROM sync_change_log WHERE isSynced = 0').all();
  Assert.equal(mobilePending.length, 3, 'Three local mutations journaled offline');

  // 2. Desktop independently creates a flashcard deck preset
  dbDesktop.prepare(`
    INSERT INTO deck_options (id, name, maxNewCardsPerDay, maxReviewsPerDay, desiredRetention, maximumInterval, createdAt, updatedAt)
    VALUES ('preset-usmle', 'USMLE Step 1 Cram', 50, 400, 0.92, 180, ?, ?)
  `).run(flightTime, flightTime);

  // Desktop pushes its changes to sync server
  syncServer.handlePush({
    deviceId: 'mac-laptop',
    changes: [
      {
        id: 'chg-desk-1',
        entityType: 'deck_options',
        entityId: 'preset-usmle',
        operation: 'INSERT',
        data: { id: 'preset-usmle', name: 'USMLE Step 1 Cram', maxNewCardsPerDay: 50 },
        lamportClock: 1,
        clientTimestamp: flightTime,
        deviceId: 'mac-laptop'
      }
    ]
  });

  // 3. Flight lands: Mobile connects to Wi-Fi and pushes offline batch
  const mobileBatch = mobilePending.map(log => ({
    id: `chg-mob-${log.id}`,
    entityType: log.entityType,
    entityId: log.entityId,
    operation: log.operation,
    data: JSON.parse(log.data),
    lamportClock: log.id,
    clientTimestamp: landTime,
    deviceId: 'pixel-phone'
  }));

  const pushRes = syncServer.handlePush({ deviceId: 'pixel-phone', changes: mobileBatch });
  Assert.equal(pushRes.accepted, 3, 'All 3 offline mobile changes accepted by server');

  // Mobile marks local records as synced
  dbMobile.prepare('UPDATE sync_change_log SET isSynced = 1').run();
  Assert.equal(dbMobile.prepare('SELECT COUNT(*) AS c FROM sync_change_log WHERE isSynced = 0').get().c, 0);

  // 4. Mobile pulls remote updates from desktop
  const mobilePull = syncServer.handlePull({ sinceLamport: 0, deviceId: 'pixel-phone' });
  const remoteDeckOption = mobilePull.changes.find(c => c.entityId === 'preset-usmle');
  Assert.ok(remoteDeckOption !== undefined, 'Mobile receives deck preset created by desktop');

  // 5. Desktop pulls mobile's lecture notes
  const desktopPull = syncServer.handlePull({ sinceLamport: 1, deviceId: 'mac-laptop' });
  const pulledBlocks = desktopPull.changes.filter(c => c.entityType === 'block');
  Assert.equal(pulledBlocks.length, 3, 'Desktop receives all 3 blocks created offline on mobile');

  dbMobile.close();
  dbDesktop.close();
});

module.exports = suite;

if (require.main === module) {
  suite.run();
}
