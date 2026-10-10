# Phase 3: Mutation Journal (CDC) & Local Delta Tracker

> **Parent Roadmap**: [ANDROID_APP_INTEGRATION_AND_SYNC.md](../../ANDROID_APP_INTEGRATION_AND_SYNC.md)  
> **Target Subsystem**: Local Change Data Capture & Mutation Logging  

---

## 🎯 Phase Objective
Implement an append-only mutation journal (`sync_change_log`) in SQLite to track every local data modification (insert, update, delete) made on the Android companion. This enables reliable offline work and deterministic delta pushes to the sync server without scanning or hashing the whole database.

---

## 📜 Journal Schema & State Tables

```sql
-- Mutation Journal Table
CREATE TABLE IF NOT EXISTS sync_change_log (
    changeId INTEGER PRIMARY KEY AUTOINCREMENT,
    entityType TEXT NOT NULL,                -- 'notebook', 'document', 'block', 'flashcard', 'review_log'
    entityId TEXT NOT NULL,
    operation TEXT NOT NULL,                 -- 'INSERT', 'UPDATE', 'DELETE'
    payloadJson TEXT,                        -- Serialized JSON of updated row (NULL on DELETE)
    timestamp INTEGER NOT NULL,              -- Millisecond epoch timestamp
    deviceId TEXT NOT NULL,                  -- Client UUID
    synced INTEGER NOT NULL DEFAULT 0        -- 0 = pending push, 1 = synced
);

CREATE INDEX IF NOT EXISTS idx_sync_unpushed ON sync_change_log(synced, changeId);
CREATE INDEX IF NOT EXISTS idx_sync_entity ON sync_change_log(entityType, entityId);

-- Local Sync State Table
CREATE TABLE IF NOT EXISTS sync_state (
    key TEXT PRIMARY KEY NOT NULL,           -- 'last_server_cursor', 'device_id', 'sync_url'
    val TEXT NOT NULL
);
```

---

## ⚙️ Automated SQLite Change Triggers (or Repository Hooks)

To ensure zero mutations escape untracked, triggers or repository interceptors record changes:

```sql
-- Flashcard Update Trigger Example
CREATE TRIGGER IF NOT EXISTS trg_track_flashcard_update AFTER UPDATE ON flashcard
BEGIN
    INSERT INTO sync_change_log(entityType, entityId, operation, payloadJson, timestamp, deviceId, synced)
    VALUES (
        'flashcard',
        new.id,
        'UPDATE',
        json_object(
            'id', new.id,
            'docId', new.docId,
            'notebookId', new.notebookId,
            'front', new.front,
            'back', new.back,
            'hint', new.hint,
            'fsrsState', new.fsrsState,
            'stability', new.stability,
            'difficulty', new.difficulty,
            'elapsedDays', new.elapsedDays,
            'scheduledDays', new.scheduledDays,
            'reps', new.reps,
            'lapses', new.lapses,
            'lastReview', new.lastReview,
            'due', new.due,
            'updatedAt', new.updatedAt
        ),
        strftime('%s', 'now') * 1000,
        (SELECT val FROM sync_state WHERE key = 'device_id'),
        0
    );
END;
```

---

## 🧹 Compactification & Garbage Collection
- Once mutations are successfully pushed and acknowledged by the server (`acceptedThroughChangeId`), the client marks `synced = 1`.
- A background maintenance routine prunes synced records older than 14 days:
  ```sql
  DELETE FROM sync_change_log WHERE synced = 1 AND timestamp < (strftime('%s', 'now') * 1000 - 1209600000);
  ```

---

## 🧪 Verification Gate
- Creating, editing, or deleting a block, flashcard, or note inserts a corresponding row in `sync_change_log`.
- Unpushed query returns all pending changes ordered by `changeId ASC`.
- Marking changes as synced successfully updates flags and prunes old logs.
