/**
 * Tier 3 Cross-Feature Combination: 03. Multi-Device Offline Edits & LWW Convergence
 * Verifies two independent devices editing the same block offline, pushing to
 * central sync server, resolving via deterministic LWW, and pulling to converge.
 */

const { TestSuite, Assert } = require('../lib/test_framework');
const { createInitializedDatabase } = require('../lib/sqlite_schema');
const { LightweightSyncServer, LWWConflictResolver, LamportClock } = require('../lib/sync_engine');

const suite = new TestSuite('Tier 3: Multi-Device Offline Edits & LWW Convergence');

suite.test('3.3 Concurrent offline edits converge to identical database state across devices', () => {
  // Device A (Android) and Device B (Mac) have separate local SQLite databases
  const dbA = createInitializedDatabase();
  const dbB = createInitializedDatabase();
  const server = new LightweightSyncServer();

  const now = new Date().toISOString();
  const sharedBlockId = 'b-shared-cardiovascular';

  // Initial shared state seeded on both devices
  const initialSql = `
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
    VALUES (?, 'doc-cardio', NULL, 'paragraph', 'Initial text: Cardiac output equals stroke volume times heart rate.', 0, ?, ?, 'nb-welcome-kb')
  `;
  dbA.prepare(initialSql).run(sharedBlockId, now, now);
  dbB.prepare(initialSql).run(sharedBlockId, now, now);

  // Clear seed sync change logs
  dbA.prepare('DELETE FROM sync_change_log').run();
  dbB.prepare('DELETE FROM sync_change_log').run();

  const clockA = new LamportClock(10);
  const clockB = new LamportClock(10);

  // === Disconnected / Offline phase ===

  // Device A edits block offline (Lamport clock advances to 11)
  const contentA = 'Device A edit: CO = SV * HR with autonomic regulation.';
  dbA.prepare('UPDATE block SET content = ?, updatedAt = ? WHERE id = ?').run(contentA, '2026-10-09T14:10:00Z', sharedBlockId);
  const lA = clockA.increment();

  // Device B edits block offline twice (Lamport clock advances to 12)
  const contentB = 'Device B edit: Cardiac output is modulated by beta-1 adrenergic receptors.';
  dbB.prepare('UPDATE block SET content = ?, updatedAt = ? WHERE id = ?').run(contentB, '2026-10-09T14:15:00Z', sharedBlockId);
  clockB.increment(); // 11
  const lB = clockB.increment(); // 12

  // === Reconnection phase ===

  // Device A pushes to server
  const pushA = server.handlePush({
    deviceId: 'android-companion',
    changes: [
      {
        id: 'chg-a-1',
        entityType: 'block',
        entityId: sharedBlockId,
        operation: 'UPDATE',
        data: { id: sharedBlockId, content: contentA },
        lamportClock: lA, // 11
        clientTimestamp: '2026-10-09T14:10:00Z',
        deviceId: 'android-companion'
      }
    ]
  });
  Assert.equal(pushA.accepted, 1);

  // Device B pushes to server (higher Lamport 12 > 11)
  const pushB = server.handlePush({
    deviceId: 'macos-desktop',
    changes: [
      {
        id: 'chg-b-1',
        entityType: 'block',
        entityId: sharedBlockId,
        operation: 'UPDATE',
        data: { id: sharedBlockId, content: contentB },
        lamportClock: lB, // 12
        clientTimestamp: '2026-10-09T14:15:00Z',
        deviceId: 'macos-desktop'
      }
    ]
  });
  Assert.equal(pushB.accepted, 1, 'Device B accepted as winner');

  // Server state verified
  const serverWinner = server.entityState.get(`block:${sharedBlockId}`);
  Assert.equal(serverWinner.winningChange.data.content, contentB, 'Device B content wins via LWW (12 > 11)');

  // === Pull and Convergence phase ===

  // Device A pulls latest changes from server
  const pullA = server.handlePull({ sinceLamport: 0, deviceId: 'android-companion' });

  // Device A applies pulled changes sequentially
  for (const change of pullA.changes) {
    if (change.entityType === 'block' && change.entityId === sharedBlockId) {
      dbA.prepare('UPDATE block SET content = ? WHERE id = ?').run(change.data.content, sharedBlockId);
    }
  }

  // Both local databases inspected
  const finalContentA = dbA.prepare('SELECT content FROM block WHERE id = ?').get(sharedBlockId).content;
  const finalContentB = dbB.prepare('SELECT content FROM block WHERE id = ?').get(sharedBlockId).content;

  Assert.equal(finalContentA, contentB, 'Device A converged to winning content');
  Assert.equal(finalContentB, contentB, 'Device B possesses winning content');
  Assert.equal(finalContentA, finalContentB, '100% deterministic eventual consistency across devices');

  dbA.close();
  dbB.close();
});

module.exports = suite;

if (require.main === module) {
  suite.run();
}
