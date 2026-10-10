package com.medha.companion.data.sync

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.medha.companion.data.local.MedhaDatabaseOpenHelper
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
class MutationJournalManagerTest {

    private lateinit var helper: MedhaDatabaseOpenHelper
    private lateinit var journalManager: MutationJournalManager
    private lateinit var clock: LamportClock

    @Before
    fun setUp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        helper = MedhaDatabaseOpenHelper(context, "mutation_test.db")
        clock = LamportClock(10L)
        journalManager = MutationJournalManager(helper.writableDatabase, clock)
    }

    @After
    fun tearDown() {
        helper.close()
    }

    @Test
    fun testLamportClockMonotonicityAndSynchronization() {
        assertEquals(10L, clock.get())
        assertEquals(11L, clock.increment())
        assertEquals(12L, clock.increment())

        // Remote clock incoming from desktop: 50
        val updated = clock.update(50L)
        assertEquals(51L, updated)
        assertEquals(51L, clock.get())
        assertEquals(52L, clock.increment())
    }

    @Test
    fun testRecordAndQueryUnpushedMutations() {
        // Initially empty
        assertTrue(journalManager.getUnpushedChanges().isEmpty())

        // Record a new card insert
        val rowId1 = journalManager.recordChange(
            entityType = "flashcard",
            entityId = "fc-001",
            operation = SyncOperation.INSERT,
            dataJson = "{\"front\":\"Q\",\"back\":\"A\"}"
        )
        assertTrue(rowId1 > 0)

        // Record an update to a block
        val rowId2 = journalManager.recordChange(
            entityType = "block",
            entityId = "b-100",
            operation = SyncOperation.UPDATE,
            dataJson = "{\"content\":\"Modified note\"}"
        )
        assertTrue(rowId2 > rowId1)

        val unpushed = journalManager.getUnpushedChanges()
        assertEquals(2, unpushed.size)
        assertEquals("flashcard", unpushed[0].entityType)
        assertEquals("fc-001", unpushed[0].entityId)
        assertEquals(SyncOperation.INSERT, unpushed[0].syncOperation)
        assertFalse(unpushed[0].isSynced)

        assertEquals("block", unpushed[1].entityType)
        assertEquals("b-100", unpushed[1].entityId)
        assertEquals(SyncOperation.UPDATE, unpushed[1].syncOperation)

        // Verify Lamport clocks advanced monotonically
        assertTrue(unpushed[1].lamportClock > unpushed[0].lamportClock)

        // Acknowledge sync of first item
        journalManager.markChangesSynced(unpushed[0].id)

        val remaining = journalManager.getUnpushedChanges()
        assertEquals(1, remaining.size)
        assertEquals("b-100", remaining[0].entityId)
    }

    @Test
    fun testPruningAndGarbageCollection() {
        val id1 = journalManager.recordChange("document", "doc-1", SyncOperation.INSERT, null)
        journalManager.markChangesSynced(id1)

        // Pruning with 0 ms olderThan cutoff prunes all synced items
        val prunedCount = journalManager.pruneSyncedLogs(olderThanMs = -1000L)
        assertTrue(prunedCount >= 1)

        // Verify journal entry deleted
        helper.writableDatabase.query("SELECT COUNT(*) FROM sync_change_log WHERE id = ?", arrayOf(id1.toString())).use { cursor ->
            cursor.moveToFirst()
            assertEquals(0, cursor.getInt(0))
        }
    }

    @Test
    fun testSyncStatePersistence() {
        assertNull(journalManager.getSyncState("server_cursor"))

        journalManager.setSyncState("server_cursor", "4500")
        journalManager.setSyncState("device_id", "pixel-9-uuid")

        assertEquals("4500", journalManager.getSyncState("server_cursor"))
        assertEquals("pixel-9-uuid", journalManager.getSyncState("device_id"))

        // Update existing state key
        journalManager.setSyncState("server_cursor", "4501")
        assertEquals("4501", journalManager.getSyncState("server_cursor"))
    }
}
