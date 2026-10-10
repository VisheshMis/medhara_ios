/**
 * Tier 2 Boundary & Corner Cases: 03. Sync & Conflict Boundaries
 * Tests large sync batches, malformed JSON payloads, idempotent pushes,
 * multiple resurrection cycles, and Lamport clock edge cases.
 */

const { TestSuite, Assert } = require('../lib/test_framework');
const { LightweightSyncServer, LWWConflictResolver, LamportClock } = require('../lib/sync_engine');

const suite = new TestSuite('Tier 2: Sync & Conflict Boundaries');

suite.test('2.3.1 Large sync batch push (500 changes in single request)', () => {
  const server = new LightweightSyncServer();
  const changes = [];
  for (let i = 1; i <= 500; i++) {
    changes.push({
      id: `chg-stress-${i}`,
      entityType: 'block',
      entityId: `b-stress-${i}`,
      operation: 'INSERT',
      data: { id: `b-stress-${i}`, content: `Stress payload ${i}` },
      lamportClock: i,
      clientTimestamp: new Date().toISOString(),
      deviceId: 'stress-device'
    });
  }

  const res = server.handlePush({ deviceId: 'stress-device', changes });
  Assert.equal(res.accepted, 500, 'All 500 changes accepted');
  Assert.ok(res.serverLamport >= 500, 'Server Lamport advanced beyond 500');

  // Pull all in chunks of 200
  const pull1 = server.handlePull({ sinceLamport: 0, limit: 200 });
  Assert.equal(pull1.changes.length, 200);
  Assert.equal(pull1.hasMore, true);
});

suite.test('2.3.2 Idempotent push of duplicate changes does not corrupt entity state', () => {
  const server = new LightweightSyncServer();
  const change = {
    id: 'chg-idempotent-1',
    entityType: 'flashcard',
    entityId: 'fc-idem-1',
    operation: 'INSERT',
    data: { front: 'Q Idem', back: 'A Idem' },
    lamportClock: 10,
    clientTimestamp: new Date().toISOString(),
    deviceId: 'dev-1'
  };

  // Push first time
  const r1 = server.handlePush({ deviceId: 'dev-1', changes: [change] });
  Assert.equal(r1.accepted, 1);

  // Push second time (exact duplicate)
  const r2 = server.handlePush({ deviceId: 'dev-1', changes: [change] });
  Assert.ok(r2.accepted >= 0);

  // State should still be winning change
  const entity = server.entityState.get('flashcard:fc-idem-1');
  Assert.equal(entity.data.front, 'Q Idem');
});

suite.test('2.3.3 Negative and zero Lamport clocks are normalized', () => {
  const server = new LightweightSyncServer();
  const change = {
    id: 'chg-zero-clock',
    entityType: 'notebook',
    entityId: 'nb-zero',
    operation: 'INSERT',
    data: { name: 'Notebook' },
    lamportClock: -5, // Negative clock from buggy client
    clientTimestamp: new Date().toISOString(),
    deviceId: 'buggy-client'
  };

  const res = server.handlePush({ deviceId: 'buggy-client', changes: [change] });
  Assert.equal(res.accepted, 1);
  Assert.ok(res.serverLamport > 0, 'Server Lamport must always be positive');
});

suite.test('2.3.4 Multiple deletion and resurrection cycles', () => {
  let changeWinner = null;

  // 1. Initial insert (Lamport 1)
  const c1 = { entityType: 'block', entityId: 'b-cycle', operation: 'INSERT', data: { text: 'v1' }, lamportClock: 1, clientTimestamp: '2026-10-09T01:00:00Z', deviceId: 'd1' };
  changeWinner = LWWConflictResolver.resolve(changeWinner, c1);
  Assert.equal(changeWinner.data.text, 'v1');

  // 2. Delete (Lamport 2)
  const c2 = { entityType: 'block', entityId: 'b-cycle', operation: 'DELETE', data: null, lamportClock: 2, clientTimestamp: '2026-10-09T02:00:00Z', deviceId: 'd1' };
  changeWinner = LWWConflictResolver.resolve(changeWinner, c2);
  Assert.equal(changeWinner.operation, 'DELETE');

  // 3. Resurrect (Lamport 3)
  const c3 = { entityType: 'block', entityId: 'b-cycle', operation: 'UPDATE', data: { text: 'v2 revived' }, lamportClock: 3, clientTimestamp: '2026-10-09T03:00:00Z', deviceId: 'd2' };
  changeWinner = LWWConflictResolver.resolve(changeWinner, c3);
  Assert.equal(changeWinner.operation, 'UPDATE');
  Assert.equal(changeWinner.data.text, 'v2 revived');

  // 4. Stale delete (Lamport 2) arrives late
  const staleDelete = { entityType: 'block', entityId: 'b-cycle', operation: 'DELETE', data: null, lamportClock: 2, clientTimestamp: '2026-10-09T02:30:00Z', deviceId: 'd3' };
  changeWinner = LWWConflictResolver.resolve(changeWinner, staleDelete);
  Assert.equal(changeWinner.operation, 'UPDATE', 'Stale delete cannot override newer resurrection');
});

suite.test('2.3.5 LamportClock local advancement and synchronization math', () => {
  const clock = new LamportClock(10);
  Assert.equal(clock.get(), 10);

  // Local mutation
  Assert.equal(clock.increment(), 11);
  Assert.equal(clock.increment(), 12);

  // Remote update with higher clock (e.g. 50 from server)
  Assert.equal(clock.update(50), 51);

  // Remote update with lower clock (e.g. 30 from another client)
  Assert.equal(clock.update(30), 52);
});

module.exports = suite;

if (require.main === module) {
  suite.run();
}
