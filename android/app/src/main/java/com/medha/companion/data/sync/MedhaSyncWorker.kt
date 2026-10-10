package com.medha.companion.data.sync

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.medha.companion.data.local.MedhaDatabaseOpenHelper
import java.util.concurrent.TimeUnit

/**
 * Jetpack WorkManager background sync worker with exponential backoff and network constraints.
 */
class MedhaSyncWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        return try {
            val dbHelper = MedhaDatabaseOpenHelper(applicationContext)
            val db = dbHelper.writableDatabase
            val journalManager = MutationJournalManager(db)
            val lamportClock = LamportClock()
            val syncClient = MedhaSyncClient()
            val syncManager = MedhaSyncManager(
                db = db,
                journalManager = journalManager,
                syncClient = syncClient,
                lamportClock = lamportClock
            )

            val syncResult = syncManager.performFullSync()
            if (syncResult.success) {
                Result.success()
            } else {
                if (runAttemptCount < 3) Result.retry() else Result.failure()
            }
        } catch (e: Exception) {
            if (runAttemptCount < 3) Result.retry() else Result.failure()
        }
    }

    companion object {
        const val PERIODIC_WORK_TAG = "MedhaPeriodicSync"
        const val ONE_TIME_WORK_TAG = "MedhaImmediateSync"

        private fun getWorkManager(context: Context): WorkManager {
            return try {
                WorkManager.getInstance(context)
            } catch (e: IllegalStateException) {
                try {
                    val config = androidx.work.Configuration.Builder().build()
                    WorkManager.initialize(context, config)
                } catch (ignored: Exception) {}
                WorkManager.getInstance(context)
            }
        }

        /**
         * Enqueues periodic 15-minute background sync constrained to active network connection.
         */
        fun enqueuePeriodicSync(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val syncRequest = PeriodicWorkRequestBuilder<MedhaSyncWorker>(15, TimeUnit.MINUTES)
                .setConstraints(constraints)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
                .build()

            getWorkManager(context).enqueueUniquePeriodicWork(
                PERIODIC_WORK_TAG,
                ExistingPeriodicWorkPolicy.KEEP,
                syncRequest
            )
        }

        /**
         * Triggers an immediate one-time sync task (e.g. on user swipe-refresh or card review).
         */
        fun triggerImmediateSync(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val syncRequest = OneTimeWorkRequestBuilder<MedhaSyncWorker>()
                .setConstraints(constraints)
                .build()

            getWorkManager(context).enqueue(syncRequest)
        }
    }
}
