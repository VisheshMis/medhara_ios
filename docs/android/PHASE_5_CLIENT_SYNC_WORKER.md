# Phase 5: Android Background Sync Client & Jetpack WorkManager

> **Parent Roadmap**: [ANDROID_APP_INTEGRATION_AND_SYNC.md](../../ANDROID_APP_INTEGRATION_AND_SYNC.md)  
> **Target Subsystem**: Android Client Sync Engine & WorkManager  

---

## 🎯 Phase Objective
Implement the Android-side sync engine: a robust synchronization client combining immediate foreground sync (on pull-to-refresh or card review) and periodic background synchronization managed by Android Jetpack `WorkManager`, with exponential backoff and network constraint checks.

---

## 🔄 Two-Way Sync Loop Execution Flow

```mermaid
sequenceDiagram
    participant App as Android UI / Worker
    participant DB as Local SQLite (Room)
    participant API as Remote Sync Server

    App->>DB: 1. Query unpushed changes (synced = 0)
    alt Has unpushed changes
        App->>API: 2. POST /api/v1/sync/push { changes }
        API-->>App: 200 OK { acceptedThroughChangeId }
        App->>DB: 3. UPDATE sync_change_log SET synced = 1
    end

    App->>DB: 4. Read last_server_cursor from sync_state
    App->>API: 5. GET /api/v1/sync/pull?sinceCursor=N
    API-->>App: 200 OK { serverCursor, changes }
    alt Has remote changes
        App->>DB: 6. Apply changes in SQLite Transaction (LWW / Append)
        App->>DB: 7. Save new last_server_cursor
    end
    App-->>App: 8. Trigger UI State Invalidation (Flow / StateFlow)
```

---

## 🛠️ WorkManager Worker Implementation

```kotlin
package com.medha.companion.data.sync

import android.content.Context
import androidx.work.*
import java.util.concurrent.TimeUnit

class MedhaSyncWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        val syncManager = MedhaSyncManager.getInstance(applicationContext)
        return try {
            val syncResult = syncManager.performFullSync()
            if (syncResult.isSuccess) {
                Result.success()
            } else {
                if (runAttemptCount < 3) Result.retry() else Result.failure()
            }
        } catch (e: Exception) {
            if (runAttemptCount < 3) Result.retry() else Result.failure()
        }
    }

    companion object {
        fun enqueuePeriodicSync(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val syncRequest = PeriodicWorkRequestBuilder<MedhaSyncWorker>(15, TimeUnit.MINUTES)
                .setConstraints(constraints)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "MedhaPeriodicSync",
                ExistingPeriodicWorkPolicy.KEEP,
                syncRequest
            )
        }
    }
}
```

---

## 🧪 Verification Gate
- Unit tests verify the sync loop: local mutations push successfully, remote changes merge deterministically without duplicate rows.
- WorkManager schedules without crashing on battery/network constraints.
