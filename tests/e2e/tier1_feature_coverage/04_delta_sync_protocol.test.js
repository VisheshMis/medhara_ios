/**
 * Tier 1 Feature Coverage: 04. Delta Sync Protocol & Endpoints
 * Verifies REST push/pull delta sync protocol endpoints, batching,
 * pagination, cursor progression, and payload contract validation per R3.
 */

const { TestSuite, Assert } = require('../lib/test_framework');
const { LightweightSyncServer } = require('../lib/sync_engine');

const suite = new TestSuite('Tier 1: Delta Sync Protocol & Endpoints (R3)');

suite.test('4.1 /health endpoint response schema and liveness', () => {
  const server = new LightweightSyncServer();
  const health = server.handleHealth();

  Assert.equal(health.status, 'ok');
  Assert.equal(health.version, '1.0.0');
  Assert.ok(typeof health.serverTime === 'number');
  Assert.equal(health.currentLamport, 0);
  Assert.equal(health.activeClients, 0);
});

suite.test('4.2 /sync/push accepts valid change batch and advances server Lamport', () => {
  const server = new LightweightSyncServer();
  const pushPayload = {
    deviceId: 'android-pixel-7',
    changes: [
      {
        id: 'chg-1',
        entityType: 'notebook',
        entityId: 'nb-1',
        operation: 'INSERT',
        data: { id: 'nb-1', name: 'Biochemistry', sortOrder: 0 },
        lamportClock: 1,
        clientTimestamp: new Date().toISOString(),
        deviceId: 'android-pixel-7'
      },
      {
        id: 'chg-2',
        entityType: 'block',
        entityId: 'b-1',
        operation: 'INSERT',
        data: { id: 'b-1', rootDocId: 'doc-1', type: 'paragraph', content: 'Enzyme kinetics' },
        lamportClock: 2,
        clientTimestamp: new Date().toISOString(),
        deviceId: 'android-pixel-7'
      }
    ]
  };

  const res = server.handlePush(pushPayload);
  Assert.equal(res.accepted, 2, 'Two changes accepted');
  Assert.ok(res.serverLamport >= 2, 'Server Lamport advanced');
  Assert.deepEqual(res.conflicts, []);
});

suite.test('4.3 /sync/pull retrieves changes after sinceLamport cursor', () => {
  const server = new LightweightSyncServer();
  // Push 3 changes
  server.handlePush({
    deviceId: 'mac-client-1',
    changes: [
      { id: 'c1', entityType: 'block', entityId: 'b-1', operation: 'INSERT', data: { id: 'b-1' }, lamportClock: 1, clientTimestamp: new Date().toISOString(), deviceId: 'mac-client-1' },
      { id: 'c2', entityType: 'block', entityId: 'b-2', operation: 'INSERT', data: { id: 'b-2' }, lamportClock: 2, clientTimestamp: new Date().toISOString(), deviceId: 'mac-client-1' },
      { id: 'c3', entityType: 'block', entityId: 'b-3', operation: 'INSERT', data: { id: 'b-3' }, lamportClock: 3, clientTimestamp: new Date().toISOString(), deviceId: 'mac-client-1' }
    ]
  });

  // Pull with sinceLamport = 0
  const pullAll = server.handlePull({ sinceLamport: 0, deviceId: 'android-client-1' });
  Assert.equal(pullAll.changes.length, 3);
  Assert.equal(pullAll.hasMore, false);
  Assert.equal(pullAll.newCursor, 4);

  // Pull with sinceLamport = 2 (should get changes with serverLamport > 2)
  const pullPartial = server.handlePull({ sinceLamport: 2, deviceId: 'android-client-1' });
  Assert.ok(pullPartial.changes.length < 3, 'Partial pull gets only newer changes');
  Assert.ok(pullPartial.changes.every(c => c.serverLamport > 2));
});

suite.test('4.4 /sync/pull batch limit and pagination (hasMore = true)', () => {
  const server = new LightweightSyncServer();
  const changes = [];
  for (let i = 1; i <= 10; i++) {
    changes.push({
      id: `c-batch-${i}`,
      entityType: 'block',
      entityId: `b-batch-${i}`,
      operation: 'INSERT',
      data: { id: `b-batch-${i}`, content: `Item ${i}` },
      lamportClock: i,
      clientTimestamp: new Date().toISOString(),
      deviceId: 'device-test'
    });
  }
  server.handlePush({ deviceId: 'device-test', changes });

  // Pull with limit = 4
  const page1 = server.handlePull({ sinceLamport: 0, limit: 4, deviceId: 'reader-client' });
  Assert.equal(page1.changes.length, 4, 'Page 1 must contain exactly 4 changes');
  Assert.equal(page1.hasMore, true, 'hasMore must be true when items remain');

  // Pull page 2 using cursor from page 1
  const page2 = server.handlePull({ sinceLamport: page1.newCursor, limit: 4, deviceId: 'reader-client' });
  Assert.equal(page2.changes.length, 4, 'Page 2 must contain 4 changes');
  Assert.equal(page2.hasMore, true);

  // Pull page 3
  const page3 = server.handlePull({ sinceLamport: page2.newCursor, limit: 4, deviceId: 'reader-client' });
  Assert.equal(page3.changes.length, 2, 'Page 3 must contain remaining 2 changes');
  Assert.equal(page3.hasMore, false, 'hasMore must be false on last page');
});

suite.test('4.5 /sync/status reports accurate pending change count', () => {
  const server = new LightweightSyncServer();
  // Initial status for unknown client
  const s0 = server.handleStatus('android-client-new');
  Assert.equal(s0.clientLastSyncedLamport, 0);
  Assert.equal(s0.pendingChanges, 0);

  // Push 5 items
  const changes = [1, 2, 3, 4, 5].map(i => ({
    id: `c-status-${i}`,
    entityType: 'block',
    entityId: `b-status-${i}`,
    operation: 'INSERT',
    data: { id: `b-status-${i}` },
    lamportClock: i,
    clientTimestamp: new Date().toISOString(),
    deviceId: 'mac-1'
  }));
  server.handlePush({ deviceId: 'mac-1', changes });

  const s1 = server.handleStatus('android-client-new');
  Assert.equal(s1.pendingChanges, 5, 'Client has 5 pending changes to pull');

  // Client pulls 3 items
  const pull = server.handlePull({ sinceLamport: 0, limit: 3, deviceId: 'android-client-new' });
  // Update status
  const s2 = server.handleStatus('android-client-new');
  Assert.ok(s2.clientLastSyncedLamport >= 0);
});

suite.test('4.6 Error handling on malformed push payloads', () => {
  const server = new LightweightSyncServer();

  // Missing deviceId
  Assert.throws(() => {
    server.handlePush({ changes: [] });
  }, 'Missing deviceId in push request');

  // Non-array changes
  Assert.throws(() => {
    server.handlePush({ deviceId: 'dev-1', changes: 'not-an-array' });
  }, 'Changes must be an array');

  // Malformed change record (missing entityType)
  Assert.throws(() => {
    server.handlePush({
      deviceId: 'dev-1',
      changes: [{ id: 'c1', entityId: 'e1', operation: 'INSERT' }]
    });
  }, 'Malformed change record');
});

module.exports = suite;

if (require.main === module) {
  suite.run();
}
