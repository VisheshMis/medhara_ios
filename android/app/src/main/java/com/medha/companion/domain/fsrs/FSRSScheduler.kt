package com.medha.companion.domain.fsrs

import com.medha.companion.data.model.Flashcard
import com.medha.companion.data.model.FSRSRating
import com.medha.companion.data.model.FSRSState
import java.time.Instant
import java.time.temporal.ChronoUnit
import kotlin.math.*

data class FlashcardReviewResult(
    val card: Flashcard,
    val rating: FSRSRating,
    val intervalDays: Int,
    val newStability: Double,
    val newDifficulty: Double,
    val newState: FSRSState
)

/**
 * Free Spaced Repetition Scheduler (FSRS v4.5) Engine.
 * 100% exact mathematical formula parity with FSRSScheduler.swift and desktop fsrs.js.
 */
class FSRSScheduler(
    val w: DoubleArray = DEFAULT_WEIGHTS,
    val requestRetention: Double = REQUEST_RETENTION
) {
    companion object {
        // Standard FSRS v4.5 Default Parameters (17 weights)
        val DEFAULT_WEIGHTS = doubleArrayOf(
            0.4000, 0.9000, 2.3000, 10.900, // 0..3: Initial stabilities
            4.9300, 0.9400,                 // 4..5: Initial difficulty params
            0.8600, 0.0100,                 // 6..7: Difficulty transition & reversion
            1.4900, 0.1400, 0.9400,         // 8..10: Stability recall success
            2.1800, 0.0500, 0.3400, 1.2600, // 11..14: Stability recall failure
            0.2900, 2.6100                  // 15..16: Hard penalty & Easy bonus
        )

        const val REQUEST_RETENTION = 0.90 // 90% target retention

        val shared by lazy { FSRSScheduler(DEFAULT_WEIGHTS, REQUEST_RETENTION) }
    }

    /**
     * Calculates retrievability probability R based on elapsed days and stability.
     */
    fun retrievability(elapsedDays: Double, stability: Double): Double {
        if (stability <= 0.0) return 0.0
        return (1.0 + 19.0 * (elapsedDays / stability)).pow(-0.5)
    }

    /**
     * Initial stability S_0 for first review ratings (Again=0.4, Hard=0.9, Good=2.3, Easy=10.9).
     */
    fun initStability(rating: FSRSRating): Double {
        return max(0.1, w[rating.value - 1])
    }

    /**
     * Initial difficulty D_0.
     */
    fun initDifficulty(rating: FSRSRating): Double {
        val g = rating.value.toDouble()
        val d = w[4] - exp(w[5] * (g - 1.0)) + 1.0
        return clampDifficulty(d)
    }

    /**
     * Next difficulty update with mean reversion.
     */
    fun nextDifficulty(currentD: Double, rating: FSRSRating): Double {
        val g = rating.value.toDouble()
        val deltaD = -w[6] * (g - 3.0)
        val d0Good = w[4] - exp(w[5] * 2.0) + 1.0
        val nextD = w[7] * d0Good + (1.0 - w[7]) * (currentD + deltaD)
        return clampDifficulty(nextD)
    }

    /**
     * Stability update upon successful recall.
     */
    fun nextRecallStability(d: Double, s: Double, r: Double, rating: FSRSRating): Double {
        val hardPenalty = if (rating == FSRSRating.HARD) w[15] else 1.0
        val easyBonus = if (rating == FSRSRating.EASY) w[16] else 1.0
        val multiplier = 1.0 + exp(w[8]) *
                (11.0 - d) *
                s.pow(-w[9]) *
                (exp(w[10] * (1.0 - r)) - 1.0) *
                hardPenalty *
                easyBonus
        return max(s, s * multiplier)
    }

    /**
     * Stability update upon forgetting (lapse).
     */
    fun nextForgetStability(d: Double, s: Double, r: Double): Double {
        val sFail = w[11] *
                d.pow(-w[12]) *
                ((s + 1.0).pow(w[13]) - 1.0) *
                exp(w[14] * (1.0 - r))
        return max(0.1, min(sFail, s))
    }

    /**
     * Calculates the interval in days given target retention.
     */
    fun intervalDays(stability: Double): Int {
        val interval = (stability / 19.0) * (requestRetention.pow(-2.0) - 1.0)
        val rounded = interval.roundToInt()
        if (rounded <= 0) {
            return max(1, stability.roundToInt())
        }
        return rounded
    }

    /**
     * Human-readable interval formatting (e.g. "10m", "1d", "14d", "2.0mo", "2.0y").
     */
    fun formatInterval(days: Int): String {
        return when {
            days <= 0 -> "10m"
            days < 30 -> "${days}d"
            days < 365 -> {
                val months = days / 30.0
                String.format(java.util.Locale.US, "%.1fmo", months)
            }
            else -> {
                val years = days / 365.0
                String.format(java.util.Locale.US, "%.1fy", years)
            }
        }
    }

    private fun clampDifficulty(d: Double): Double {
        return min(10.0, max(1.0, d))
    }

    /**
     * Previews scheduled intervals for all 4 ratings without committing changes.
     */
    fun previewIntervals(card: Flashcard, reviewDate: Instant = Instant.now()): Map<FSRSRating, Int> {
        val map = mutableMapOf<FSRSRating, Int>()
        for (r in FSRSRating.entries) {
            val result = review(card, r, reviewDate)
            map[r] = result.intervalDays
        }
        return map
    }

    /**
     * Reviews a card producing an updated Flashcard and ReviewResult.
     */
    fun review(
        card: Flashcard,
        rating: FSRSRating,
        reviewDate: Instant = Instant.now()
    ): FlashcardReviewResult {
        val elapsedDays: Int = if (card.lastReview != null) {
            try {
                val last = Instant.parse(card.lastReview)
                max(0L, ChronoUnit.DAYS.between(last, reviewDate)).toInt()
            } catch (e: Exception) {
                0
            }
        } else {
            0
        }

        val newStability: Double
        val newDifficulty: Double
        val newState: FSRSState

        if (card.state == FSRSState.NEW_CARD || card.stability <= 0.0) {
            newStability = initStability(rating)
            newDifficulty = initDifficulty(rating)
            newState = if (rating == FSRSRating.AGAIN) FSRSState.LEARNING else FSRSState.REVIEW
        } else {
            val r = retrievability(elapsedDays.toDouble(), card.stability)
            newDifficulty = nextDifficulty(card.difficulty, rating)

            if (rating == FSRSRating.AGAIN) {
                newStability = nextForgetStability(newDifficulty, card.stability, r)
                newState = FSRSState.RELEARNING
            } else {
                newStability = nextRecallStability(newDifficulty, card.stability, r, rating)
                newState = FSRSState.REVIEW
            }
        }

        val scheduledDays = intervalDays(newStability)
        val dueInstant = if (rating == FSRSRating.AGAIN) {
            reviewDate.plus(10, ChronoUnit.MINUTES) // 10 minute repeat for Again
        } else {
            reviewDate.plus(scheduledDays.toLong(), ChronoUnit.DAYS)
        }

        val roundedStability = (newStability * 100).roundToInt() / 100.0
        val roundedDifficulty = (newDifficulty * 100).roundToInt() / 100.0
        val reps = card.reps + 1
        val lapses = card.lapses + (if (rating == FSRSRating.AGAIN) 1 else 0)

        val updatedCard = card.copy(
            fsrsState = newState.value,
            stability = roundedStability,
            difficulty = roundedDifficulty,
            elapsedDays = elapsedDays,
            scheduledDays = scheduledDays,
            reps = reps,
            lapses = lapses,
            lastReview = reviewDate.toString(),
            due = dueInstant.toString(),
            updatedAt = reviewDate.toString()
        )

        return FlashcardReviewResult(
            card = updatedCard,
            rating = rating,
            intervalDays = scheduledDays,
            newStability = roundedStability,
            newDifficulty = roundedDifficulty,
            newState = newState
        )
    }
}
