/**
 * Tier 1 Feature Coverage: 05. Last-Write-Wins (LWW) Conflict Resolution
 * Verifies deterministic multi-master conflict resolution rules:
 * Lamport dominance, ISO timestamp tie-breaker, Device ID tie-breaker,
 * tombstone deletions, resurrection, and immutable review_log set-union.
 */

const { TestSuite, Assert } = require('../lib/test_framework');
const { LWWConflictResolver, LightweightSyncServer } = require('../lib/sync_engine');

const suite = new TestSuite('Tier 1: LWW Conflict Resolution Engine (R3)');

suite.test('5.1 Rule 1: Lamport dominance overrides wall-clock timestamp drift', () => {
  // Device A has Lamport 5, earlier timestamp
  const changeA = {
    id: 'chg-a',
    entityType: 'block',
    entityId: 'b-conflict-1',
    operation: 'UPDATE',
    data: { content: 'Change A (high Lamport)' },
    lamportClock: 5,
    clientTimestamp: '2026-10-09T10:00:00.000Z',
    deviceId: 'device-a'
  };

  // Device B has Lamport 3, later timestamp (clock drift)
  const changeB = {
    id: 'chg-b',
    entityType: 'block',
    entityId: 'b-conflict-1',
    operation: 'UPDATE',
    data: { content: 'Change B (drifted timestamp)' },
    lamportClock: 3,
    clientTimestamp: '2026-10-09T14:00:00.000Z',
    deviceId: 'device-b'
  };

  const winner = LWWConflictResolver.resolve(changeA, changeB);
  Assert.equal(winner, changeA, 'Change with higher Lamport clock (5 > 3) must win');
  Assert.equal(winner.data.content, 'Change A (high Lamport)');
});

suite.test('5.2 Rule 2: Wall-clock ISO timestamp breaks equal Lamport ties', () => {
  const changeA = {
    id: 'chg-a',
    entityType: 'block',
    entityId: 'b-conflict-2',
    operation: 'UPDATE',
    data: { content: 'Earlier edit' },
    lamportClock: 4,
    clientTimestamp: '2026-10-09T12:00:00.000Z',
    deviceId: 'device-a'
  };

  const changeB = {
    id: 'chg-b',
    entityType: 'block',
    entityId: 'b-conflict-2',
    operation: 'UPDATE',
    data: { content: 'Later edit wins' },
    lamportClock: 4,
    clientTimestamp: '2026-10-09T12:05:00.000Z',
    deviceId: 'device-b'
  };

  const winner = LWWConflictResolver.resolve(changeA, changeB);
  Assert.equal(winner, changeB, 'Higher timestamp must break equal Lamport tie');
  Assert.equal(winner.data.content, 'Later edit wins');
});

suite.test('5.3 Rule 3: Lexicographical Device ID breaks equal Lamport & timestamp ties', () => {
  const commonTime = '2026-10-09T12:00:00.000Z';
  const changeAndroid = {
    id: 'chg-and',
    entityType: 'block',
    entityId: 'b-conflict-3',
    operation: 'UPDATE',
    data: { content: 'Android edit' },
    lamportClock: 10,
    clientTimestamp: commonTime,
    deviceId: 'android-pixel-01'
  };

  const changeMac = {
    id: 'chg-mac',
    entityType: 'block',
    entityId: 'b-conflict-3',
    operation: 'UPDATE',
    data: { content: 'Mac edit wins' },
    lamportClock: 10,
    clientTimestamp: commonTime,
    deviceId: 'macbook-pro-01'
  };

  const winner = LWWConflictResolver.resolve(changeAndroid, changeMac);
  Assert.equal(winner, changeMac, 'macbook-pro-01 > android-pixel-01 lexicographically');
  Assert.equal(winner.data.content, 'Mac edit wins');
});

suite.test('5.4 Rule 4: Tombstone DELETE priority with equal or higher Lamport', () => {
  const updateChange = {
    id: 'chg-up',
    entityType: 'flashcard',
    entityId: 'fc-del-1',
    operation: 'UPDATE',
    data: { front: 'Q modified' },
    lamportClock: 7,
    clientTimestamp: '2026-10-09T12:00:00.000Z',
    deviceId: 'dev-1'
  };

  const deleteChange = {
    id: 'chg-del',
    entityType: 'flashcard',
    entityId: 'fc-del-1',
    operation: 'DELETE',
    data: null,
    lamportClock: 7,
    clientTimestamp: '2026-10-09T12:01:00.000Z',
    deviceId: 'dev-2'
  };

  const winner = LWWConflictResolver.resolve(updateChange, deleteChange);
  Assert.equal(winner, deleteChange, 'DELETE with higher timestamp wins');
  Assert.equal(winner.operation, 'DELETE');
});

suite.test('5.5 Rule 4b: Entity resurrection when subsequent UPDATE has higher Lamport', () => {
  const deleteChange = {
    id: 'chg-del',
    entityType: 'block',
    entityId: 'b-resurrect',
    operation: 'DELETE',
    data: null,
    lamportClock: 5,
    clientTimestamp: '2026-10-09T12:00:00.000Z',
    deviceId: 'dev-1'
  };

  const resurrectUpdate = {
    id: 'chg-resurrect',
    entityType: 'block',
    entityId: 'b-resurrect',
    operation: 'UPDATE',
    data: { id: 'b-resurrect', content: 'Resurrected note content' },
    lamportClock: 8,
    clientTimestamp: '2026-10-09T12:10:00.000Z',
    deviceId: 'dev-2'
  };

  const winner = LWWConflictResolver.resolve(deleteChange, resurrectUpdate);
  Assert.equal(winner, resurrectUpdate, 'Higher Lamport UPDATE resurrects entity');
  Assert.equal(winner.data.content, 'Resurrected note content');
});

suite.test('5.6 Rule 5: Set union for review_log entities (no overwrite loss)', () => {
  const server = new LightweightSyncServer();

  // Client 1 submits review log
  server.handlePush({
    deviceId: 'phone-1',
    changes: [
      {
        id: 'rev-chg-1',
        entityType: 'review_log',
        entityId: 'rl-userA-1',
        operation: 'INSERT',
        data: { id: 'rl-userA-1', cardId: 'fc-1', rating: 3, reviewTime: '2026-10-09T09:00:00Z' },
        lamportClock: 1,
        clientTimestamp: '2026-10-09T09:00:00Z',
        deviceId: 'phone-1'
      }
    ]
  });

  // Client 2 submits different review log for same card
  server.handlePush({
    deviceId: 'tablet-1',
    changes: [
      {
        id: 'rev-chg-2',
        entityType: 'review_log',
        entityId: 'rl-userB-1',
        operation: 'INSERT',
        data: { id: 'rl-userB-1', cardId: 'fc-1', rating: 4, reviewTime: '2026-10-09T10:00:00Z' },
        lamportClock: 2,
        clientTimestamp: '2026-10-09T10:00:00Z',
        deviceId: 'tablet-1'
      }
    ]
  });

  // Pull all review logs
  const pull = server.handlePull({ sinceLamport: 0, deviceId: 'desktop-audit' });
  const reviewChanges = pull.changes.filter(c => c.entityType === 'review_log');
  Assert.equal(reviewChanges.length, 2, 'Both review logs preserved in set-union');
  Assert.equal(server.reviewLogs.size, 2, 'Server preserves both historical reviews');
});

module.exports = suite;

if (require.main === module) {
  suite.run();
}
