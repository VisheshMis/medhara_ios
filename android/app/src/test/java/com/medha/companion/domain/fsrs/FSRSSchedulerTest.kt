package com.medha.companion.domain.fsrs

import com.medha.companion.data.model.Flashcard
import com.medha.companion.data.model.FSRSRating
import com.medha.companion.data.model.FSRSState
import org.junit.Assert.*
import org.junit.Test
import java.time.Instant
import java.time.temporal.ChronoUnit

class FSRSSchedulerTest {

    private val scheduler = FSRSScheduler()

    @Test
    fun testWeightConfigurationAndRetention() {
        assertEquals(17, scheduler.w.size)
        assertEquals(0.4000, scheduler.w[0], 0.0001)
        assertEquals(0.9000, scheduler.w[1], 0.0001)
        assertEquals(2.3000, scheduler.w[2], 0.0001)
        assertEquals(10.900, scheduler.w[3], 0.0001)
        assertEquals(0.90, scheduler.requestRetention, 0.0001)
    }

    @Test
    fun testInitialStabilityAndDifficulty() {
        assertEquals(0.4, scheduler.initStability(FSRSRating.AGAIN), 0.0001)
        assertEquals(0.9, scheduler.initStability(FSRSRating.HARD), 0.0001)
        assertEquals(2.3, scheduler.initStability(FSRSRating.GOOD), 0.0001)
        assertEquals(10.9, scheduler.initStability(FSRSRating.EASY), 0.0001)

        val dAgain = scheduler.initDifficulty(FSRSRating.AGAIN)
        val dHard = scheduler.initDifficulty(FSRSRating.HARD)
        val dGood = scheduler.initDifficulty(FSRSRating.GOOD)
        val dEasy = scheduler.initDifficulty(FSRSRating.EASY)

        assertTrue("dAgain in [1..10]", dAgain in 1.0..10.0)
        assertTrue("dHard in [1..10]", dHard in 1.0..10.0)
        assertTrue("dGood in [1..10]", dGood in 1.0..10.0)
        assertTrue("dEasy in [1..10]", dEasy in 1.0..10.0)

        assertTrue("Again difficulty >= Hard", dAgain >= dHard)
        assertTrue("Hard difficulty >= Good", dHard >= dGood)
        assertTrue("Good difficulty >= Easy", dGood >= dEasy)
    }

    @Test
    fun testNewCardReviewLifecycle() {
        val now = Instant.now()
        val newCard = Flashcard(
            id = "fc-bench-1",
            docId = "doc-1",
            notebookId = "nb-1",
            front = "What is active recall?",
            back = "Testing yourself to strengthen memory traces.",
            fsrsState = FSRSState.NEW_CARD.value,
            stability = 0.0,
            difficulty = 0.0,
            elapsedDays = 0,
            scheduledDays = 0,
            reps = 0,
            lapses = 0,
            lastReview = null,
            due = now.toString()
        )

        // 1. Review Again -> State becomes Learning, lapses increment
        val againRes = scheduler.review(newCard, FSRSRating.AGAIN, now)
        assertEquals(FSRSState.LEARNING, againRes.newState)
        assertEquals(1, againRes.card.lapses)
        assertEquals(1, againRes.card.reps)
        assertEquals(0.4, againRes.newStability, 0.01)

        // 2. Review Good -> State becomes Review
        val goodRes = scheduler.review(newCard, FSRSRating.GOOD, now)
        assertEquals(FSRSState.REVIEW, goodRes.newState)
        assertEquals(0, goodRes.card.lapses)
        assertEquals(1, goodRes.card.reps)
        assertEquals(2.3, goodRes.newStability, 0.01)
        assertTrue(goodRes.intervalDays >= 1)
    }

    @Test
    fun testRepeatedReviewAndStabilityGrowth() {
        val t0 = Instant.now()
        val card0 = Flashcard(
            id = "fc-bench-2",
            docId = "doc-1",
            notebookId = "nb-1",
            front = "Q",
            back = "A",
            fsrsState = FSRSState.REVIEW.value,
            stability = 2.3,
            difficulty = 5.0,
            elapsedDays = 0,
            scheduledDays = 1,
            reps = 1,
            lapses = 0,
            lastReview = t0.toString(),
            due = t0.plus(1, ChronoUnit.DAYS).toString()
        )

        // 3 days later, student recalls correctly (Rating: Good)
        val t1 = t0.plus(3, ChronoUnit.DAYS)
        val res1 = scheduler.review(card0, FSRSRating.GOOD, t1)

        assertEquals(3, res1.card.elapsedDays)
        assertTrue("Stability should increase", res1.newStability > card0.stability)
        assertTrue("Interval scheduled", res1.intervalDays >= 1)

        // 10 days later, student lapses (Rating: Again)
        val t2 = t1.plus(10, ChronoUnit.DAYS)
        val lapseRes = scheduler.review(res1.card, FSRSRating.AGAIN, t2)

        assertEquals(FSRSState.RELEARNING, lapseRes.newState)
        assertEquals(1, lapseRes.card.lapses)
        assertTrue("Stability decays on lapse", lapseRes.newStability < res1.newStability)
    }

    @Test
    fun testPreviewIntervals() {
        val card = Flashcard(
            docId = "doc-1",
            notebookId = "nb-1",
            front = "Q",
            back = "A",
            fsrsState = FSRSState.REVIEW.value,
            stability = 5.0,
            difficulty = 4.0
        )
        val preview = scheduler.previewIntervals(card)

        val again = preview[FSRSRating.AGAIN] ?: 0
        val hard = preview[FSRSRating.HARD] ?: 0
        val good = preview[FSRSRating.GOOD] ?: 0
        val easy = preview[FSRSRating.EASY] ?: 0

        assertTrue("Easy interval >= Good interval", easy >= good)
        assertTrue("Good interval >= Hard interval", good >= hard)
    }

    @Test
    fun testFormatIntervalHelper() {
        assertEquals("10m", scheduler.formatInterval(0))
        assertEquals("1d", scheduler.formatInterval(1))
        assertEquals("14d", scheduler.formatInterval(14))
        assertEquals("2.0mo", scheduler.formatInterval(60))
        assertEquals("2.0y", scheduler.formatInterval(730))
    }
}
