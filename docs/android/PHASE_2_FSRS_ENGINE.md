# Phase 2: FSRS-4.5 Spaced Repetition Mathematical Engine

> **Parent Roadmap**: [ANDROID_APP_INTEGRATION_AND_SYNC.md](../../ANDROID_APP_INTEGRATION_AND_SYNC.md)  
> **Source Parity**: `Sources/MedhaKit/Services/FSRSScheduler.swift` & `desktop/src/main/fsrs/scheduler.ts`  

---

## 🎯 Phase Objective
Implement the Free Spaced Repetition Scheduler (FSRS-4.5) algorithm in pure Kotlin with 100% mathematical parity to Mac Swift. Given any card state and rating, the Kotlin engine must generate exact stability, difficulty, interval, and state values matching Mac and Windows test vectors.

---

## 📐 Mathematical Parameters & Constants

### Default Weights (17 Parameters)
```kotlin
val DEFAULT_WEIGHTS = doubleArrayOf(
    0.4000, 0.9000, 2.3000, 10.900, // 0..3: Initial stabilities for ratings [Again, Hard, Good, Easy]
    4.9300, 0.9400,                 // 4..5: Initial difficulty parameters
    0.8600, 0.0100,                 // 6..7: Difficulty transition & mean reversion
    1.4900, 0.1400, 0.9400,         // 8..10: Stability recall success multipliers
    2.1800, 0.0500, 0.3400, 1.2600, // 11..14: Stability recall failure multipliers
    0.2900, 2.6100                  // 15..16: Hard penalty & Easy bonus
)
const val REQUEST_RETENTION = 0.90 // 90% target retention rate
```

---

## 🔢 Core FSRS Formulas (Kotlin Implementation)

```kotlin
package com.medha.companion.domain.fsrs

import java.util.Date
import kotlin.math.*

enum class FSRSRating(val value: Int) {
    AGAIN(1),
    HARD(2),
    GOOD(3),
    EASY(4)
}

enum class FSRSState(val value: Int) {
    NEW(0),
    LEARNING(1),
    REVIEW(2),
    RELEARNING(3)
}

data class FSRSReviewResult(
    val intervalDays: Int,
    val newStability: Double,
    val newDifficulty: Double,
    val newState: FSRSState
)

class FSRSScheduler(
    val w: DoubleArray = DEFAULT_WEIGHTS,
    val requestRetention: Double = REQUEST_RETENTION
) {
    fun retrievability(elapsedDays: Double, stability: Double): Double {
        if (stability <= 0.0) return 0.0
        return (1.0 + elapsedDays / (9.0 * stability)).pow(-1.0)
    }

    fun initStability(rating: FSRSRating): Double {
        return max(0.1, w[rating.value - 1])
    }

    fun initDifficulty(rating: FSRSRating): Double {
        val d = w[4] - (rating.value - 3) * w[5]
        return min(max(d, 1.0), 10.0)
    }

    fun nextDifficulty(currentD: Double, rating: FSRSRating): Double {
        val delta = -w[6] * (rating.value - 3)
        val dPrime = currentD + delta
        val nextD = w[7] * initDifficulty(FSRSRating.EASY) + (1.0 - w[7]) * dPrime
        return min(max(nextD, 1.0), 10.0)
    }

    fun nextRecallStability(d: Double, s: Double, r: Double, rating: FSRSRating): Double {
        val hardPenalty = if (rating == FSRSRating.HARD) w[15] else 1.0
        val easyBonus = if (rating == FSRSRating.EASY) w[16] else 1.0
        val factor = exp(w[8]) *
                (11.0 - d) *
                s.pow(-w[9]) *
                (exp((1.0 - r) * w[10]) - 1.0) *
                hardPenalty *
                easyBonus
        return s * (1.0 + factor)
    }

    fun nextForgetStability(d: Double, s: Double, r: Double): Double {
        val factor = w[11] *
                d.pow(-w[12]) *
                ((s + 1.0).pow(w[13]) - 1.0) *
                exp((1.0 - r) * w[14])
        return min(s, max(0.1, factor))
    }

    fun nextInterval(stability: Double): Int {
        val interval = (stability / 19.0) * ((requestRetention.pow(-1.0 / 0.5)) - 1.0)
        return max(1, interval.roundToInt())
    }

    fun review(
        state: FSRSState,
        stability: Double,
        difficulty: Double,
        elapsedDays: Int,
        rating: FSRSRating
    ): FSRSReviewResult {
        if (state == FSRSState.NEW || stability <= 0.0) {
            val initS = initStability(rating)
            val initD = initDifficulty(rating)
            val newState = if (rating == FSRSRating.AGAIN) FSRSState.LEARNING else FSRSState.REVIEW
            val interval = if (rating == FSRSRating.AGAIN) 0 else nextInterval(initS)
            return FSRSReviewResult(interval, initS, initD, newState)
        }

        val r = retrievability(elapsedDays.toDouble(), stability)
        val nextD = nextDifficulty(difficulty, rating)

        return if (rating == FSRSRating.AGAIN) {
            val nextS = nextForgetStability(nextD, stability, r)
            FSRSReviewResult(0, nextS, nextD, FSRSState.RELEARNING)
        } else {
            val nextS = nextRecallStability(nextD, stability, r, rating)
            val interval = nextInterval(nextS)
            FSRSReviewResult(interval, nextS, nextD, FSRSState.REVIEW)
        }
    }
}
```

---

## 🧪 Verification Gate
- Unit tests verify calculations against exact test outputs from `tests/fsrs.test.js` and `FSRSScheduler.swift`.
- Edge cases tested: Initial "Again", "Hard", "Good", "Easy", repeated reviews, long hiatus (e.g. 180 days elapsed), and stability clamping.
