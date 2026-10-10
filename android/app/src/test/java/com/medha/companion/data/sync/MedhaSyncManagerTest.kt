package com.medha.companion.data.sync

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.medha.companion.data.local.MedhaDatabaseManager
import com.medha.companion.data.local.MedhaDatabaseOpenHelper
import com.medha.companion.data.model.SyncChangeLog
import com.medha.companion.data.model.SyncOperation
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class MedhaSyncManagerTest {

    private lateinit var helper: MedhaDatabaseOpenHelper
    private lateinit var dbManager: MedhaDatabaseManager
    private lateinit var journalManager: MutationJournalManager
    private lateinit var clock: LamportClock

    @Before
    fun setUp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        helper = MedhaDatabaseOpenHelper(context, "sync_manager_test.db")
        dbManager = MedhaDatabaseManager(helper.writableDatabase)
        clock = LamportClock(1L)
        journalManager = MutationJournalManager(helper.writableDatabase, clock)
    }

    @After
    fun tearDown() {
        helper.close()
    }

    @Test
    fun testApplyRemoteChangesToDatabase() {
        val mockClient = object : MedhaSyncClient("http://localhost:9999") {}
        val syncManager = MedhaSyncManager(
            db = helper.writableDatabase,
            journalManager = journalManager,
            syncClient = mockClient,
            lamportClock = clock,
            deviceId = "android_test_1"
        )

        val remoteChanges = listOf(
            RemoteChange(
                cursor = 1,
                deviceId = "mac_client_1",
                entityType = "notebook",
                entityId = "nb_sync_1",
                operation = "INSERT",
                data = "{\"name\":\"Bio 101\",\"icon\":\"🧬\",\"sortOrder\":1}",
                timestamp = 1000L,
                lamportClock = 5L
            ),
            RemoteChange(
                cursor = 2,
                deviceId = "mac_client_1",
                entityType = "document",
                entityId = "doc_sync_1",
                operation = "INSERT",
                data = "{\"notebookId\":\"nb_sync_1\",\"title\":\"Cell Structure\",\"isFolder\":false,\"sortOrder\":1}",
                timestamp = 1005L,
                lamportClock = 6L
            ),
            RemoteChange(
                cursor = 3,
                deviceId = "mac_client_1",
                entityType = "block",
                entityId = "blk_sync_1",
                operation = "INSERT",
                data = "{\"rootDocId\":\"doc_sync_1\",\"type\":\"paragraph\",\"content\":\"Mitochondria is the powerhouse.\",\"sortOrder\":0}",
                timestamp = 1010L,
                lamportClock = 7L
            ),
            RemoteChange(
                cursor = 4,
                deviceId = "mac_client_1",
                entityType = "flashcard",
                entityId = "card_sync_1",
                operation = "INSERT",
                data = "{\"docId\":\"doc_sync_1\",\"front\":\"What produces ATP?\",\"back\":\"Mitochondria\",\"fsrsState\":1,\"stability\":2.5,\"difficulty\":4.8,\"due\":\"2026-10-15T00:00:00Z\"}",
                timestamp = 1015L,
                lamportClock = 8L
            ),
            RemoteChange(
                cursor = 5,
                deviceId = "mac_client_1",
                entityType = "review_log",
                entityId = "rev_sync_1",
                operation = "INSERT",
                data = "{\"cardId\":\"card_sync_1\",\"rating\":3,\"state\":\"review\",\"scheduledDays\":3,\"elapsedDays\":1}",
                timestamp = 1020L,
                lamportClock = 9L
            )
        )

        syncManager.applyRemoteChanges(remoteChanges)

        // Verify entities inserted
        val notebooks = dbManager.getNotebooks()
        assertEquals(1, notebooks.size)
        assertEquals("Bio 101", notebooks[0].name)

        val docs = dbManager.getDocumentsByNotebook("nb_sync_1")
        assertEquals(1, docs.size)
        assertEquals("Cell Structure", docs[0].title)

        val blocks = dbManager.getBlocksByDocument("doc_sync_1")
        assertEquals(1, blocks.size)
        assertEquals("Mitochondria is the powerhouse.", blocks[0].content)

        val dueCards = dbManager.getDueFlashcards("2026-10-20T00:00:00Z")
        assertEquals(1, dueCards.size)
        assertEquals("What produces ATP?", dueCards[0].front)

        // Verify remote delete operation
        val deleteChange = listOf(
            RemoteChange(
                cursor = 6,
                deviceId = "mac_client_1",
                entityType = "block",
                entityId = "blk_sync_1",
                operation = "DELETE",
                data = null,
                timestamp = 1030L,
                lamportClock = 10L
            )
        )
        syncManager.applyRemoteChanges(deleteChange)

        val blocksAfterDelete = dbManager.getBlocksByDocument("doc_sync_1")
        assertTrue(blocksAfterDelete.isEmpty())
    }

    @Test
    fun testPerformFullSyncLoop() {
        // Record 2 local changes
        val localChangeId1 = journalManager.recordChange(
            entityType = "document",
            entityId = "doc_local_1",
            operation = SyncOperation.INSERT,
            dataJson = "{\"title\":\"My Quick Mobile Note\"}"
        )
        val localChangeId2 = journalManager.recordChange(
            entityType = "block",
            entityId = "blk_local_1",
            operation = SyncOperation.INSERT,
            dataJson = "{\"rootDocId\":\"doc_local_1\",\"content\":\"Draft thought\"}"
        )

        // Create a fake sync client that mimics successful server responses
        val fakeClient = object : MedhaSyncClient("http://fake") {
            var pushCalled = false
            var pullCalled = false

            override fun push(deviceId: String, changes: List<SyncChangeLog>): PushResult {
                pushCalled = true
                assertEquals(2, changes.size)
                return PushResult(
                    success = true,
                    acceptedThroughChangeId = changes.last().id,
                    serverCursor = 10,
                    serverLamport = 25
                )
            }

            override fun pull(sinceCursor: Long, limit: Int): PullResult {
                pullCalled = true
                return if (sinceCursor == 0L) {
                    PullResult(
                        serverCursor = 12,
                        serverLamport = 30,
                        hasMore = false,
                        changes = listOf(
                            RemoteChange(
                                cursor = 11,
                                deviceId = "windows_client_1",
                                entityType = "notebook",
                                entityId = "nb_from_windows",
                                operation = "INSERT",
                                data = "{\"name\":\"Chemistry\",\"icon\":\"🧪\"}",
                                timestamp = 2000L,
                                lamportClock = 28L
                            )
                        )
                    )
                } else {
                    PullResult(
                        serverCursor = sinceCursor,
                        serverLamport = 30,
                        hasMore = false,
                        changes = emptyList()
                    )
                }
            }
        }

        val syncManager = MedhaSyncManager(
            db = helper.writableDatabase,
            journalManager = journalManager,
            syncClient = fakeClient,
            lamportClock = clock,
            deviceId = "android_test_1"
        )

        val result = syncManager.performFullSync()

        assertTrue(result.success)
        assertEquals(2, result.pushedCount)
        assertEquals(1, result.pulledCount)

        // Verify unpushed changes are now marked as synced
        val remainingUnpushed = journalManager.getUnpushedChanges()
        assertTrue(remainingUnpushed.isEmpty())

        // Verify cursor was persisted in sync_state
        assertEquals("12", journalManager.getSyncState("last_server_cursor"))

        // Verify local lamport clock was advanced
        assertTrue(clock.get() >= 30L)

        // Verify remote change was written to SQLite
        val notebooks = dbManager.getNotebooks()
        assertEquals(1, notebooks.size)
        assertEquals("Chemistry", notebooks[0].name)
    }

    @Test
    fun testWorkManagerHelpersDoNotCrash() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        // Verify WorkManager scheduling helpers can be invoked safely
        MedhaSyncWorker.enqueuePeriodicSync(context)
        MedhaSyncWorker.triggerImmediateSync(context)
    }
}
