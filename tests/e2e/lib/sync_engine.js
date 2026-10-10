/**
 * Medha Delta Sync Protocol & LWW Conflict Resolver Engine
 * Authoritative implementation matching specifications in
 * ORIGINAL_REQUEST.md and explorer_survey_2/handoff.md.
 */

class LamportClock {
  constructor(initial = 0) {
    this.value = initial;
  }

  increment() {
    this.value += 1;
    return this.value;
  }

  update(receivedLamport) {
    this.value = Math.max(this.value, receivedLamport) + 1;
    return this.value;
  }

  get() {
    return this.value;
  }
}

class LWWConflictResolver {
  /**
   * Deterministically resolves conflict between two changes on the same entity.
   * Returns the winning change.
   */
  static resolve(changeA, changeB) {
    if (!changeA) return changeB;
    if (!changeB) return changeA;

    // Rule 5: review_log is immutable audit trail; set-union behavior handled by callers
    if (changeA.entityType === 'review_log') {
      // In set-union, either can be preserved or both merged
      return changeA;
    }

    // Rule 1: Lamport dominance
    if (changeA.lamportClock > changeB.lamportClock) {
      return changeA;
    }
    if (changeB.lamportClock > changeA.lamportClock) {
      return changeB;
    }

    // Rule 2: Wall-clock ISO timestamp tie-breaker
    const timeA = new Date(changeA.clientTimestamp).getTime();
    const timeB = new Date(changeB.clientTimestamp).getTime();
    if (timeA > timeB) {
      return changeA;
    }
    if (timeB > timeA) {
      return changeB;
    }

    // Rule 3: Deterministic device ID tie-breaker (lexicographical)
    if (changeA.deviceId > changeB.deviceId) {
      return changeA;
    }
    if (changeB.deviceId > changeA.deviceId) {
      return changeB;
    }

    // Identical changes
    return changeA;
  }
}

class LightweightSyncServer {
  constructor() {
    this.serverLamport = 0;
    this.changeJournal = []; // Array of { ...change, serverLamport }
    this.entityState = new Map(); // key: `${entityType}:${entityId}` -> { winningChange, data }
    this.reviewLogs = new Map(); // id -> data (set union)
    this.clientCursors = new Map(); // deviceId -> lastSyncedLamport
  }

  handleHealth() {
    return {
      status: 'ok',
      version: '1.0.0',
      serverTime: Date.now(),
      currentLamport: this.serverLamport,
      activeClients: this.clientCursors.size,
    };
  }

  handlePush(request) {
    const { deviceId, changes } = request;
    if (!deviceId) throw new Error('Missing deviceId in push request');
    if (!Array.isArray(changes)) throw new Error('Changes must be an array');

    let accepted = 0;
    const conflicts = [];

    for (const change of changes) {
      if (!change.id || !change.entityType || !change.entityId || !change.operation) {
        throw new Error('Malformed change record in push batch');
      }

      // Advance server logical clock
      this.serverLamport = Math.max(this.serverLamport, change.lamportClock || 0) + 1;
      const stampedChange = {
        ...change,
        serverLamport: this.serverLamport,
      };

      const key = `${change.entityType}:${change.entityId}`;

      if (change.entityType === 'review_log') {
        // Set union: immutable log row
        if (!this.reviewLogs.has(change.entityId)) {
          this.reviewLogs.set(change.entityId, change.data);
          this.changeJournal.push(stampedChange);
          accepted++;
        }
      } else {
        const existing = this.entityState.get(key);
        if (!existing) {
          this.entityState.set(key, { winningChange: stampedChange, data: change.data });
          this.changeJournal.push(stampedChange);
          accepted++;
        } else {
          const winner = LWWConflictResolver.resolve(existing.winningChange, stampedChange);
          if (winner === stampedChange) {
            this.entityState.set(key, { winningChange: stampedChange, data: change.data });
            this.changeJournal.push(stampedChange);
            accepted++;
          } else {
            // Existing change won, conflict detected
            conflicts.push(key);
          }
        }
      }
    }

    this.clientCursors.set(deviceId, this.serverLamport);

    return {
      accepted,
      serverLamport: this.serverLamport,
      conflicts,
    };
  }

  handlePull(request) {
    const { sinceLamport = 0, limit = 100, deviceId } = request;
    if (deviceId) {
      this.clientCursors.set(deviceId, Math.max(this.clientCursors.get(deviceId) || 0, sinceLamport));
    }

    const filtered = this.changeJournal.filter(c => c.serverLamport > sinceLamport);
    const batch = filtered.slice(0, limit);
    const hasMore = filtered.length > limit;
    const newCursor = batch.length > 0 ? batch[batch.length - 1].serverLamport : sinceLamport;

    return {
      changes: batch,
      newCursor,
      hasMore,
    };
  }

  handleStatus(deviceId) {
    const clientCursor = this.clientCursors.get(deviceId) || 0;
    const pendingChanges = this.changeJournal.filter(c => c.serverLamport > clientCursor).length;
    return {
      serverLamport: this.serverLamport,
      clientLastSyncedLamport: clientCursor,
      pendingChanges,
    };
  }
}

module.exports = {
  LamportClock,
  LWWConflictResolver,
  LightweightSyncServer,
};
