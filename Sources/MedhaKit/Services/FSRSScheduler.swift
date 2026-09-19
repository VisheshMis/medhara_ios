import Foundation

public struct FlashcardReviewResult: Sendable {
    public let card: Flashcard
    public let rating: FSRSRating
    public let intervalDays: Int
    public let newStability: Double
    public let newDifficulty: Double
    public let newState: FSRSState
}

public struct FSRSScheduler: Sendable {
    public static let shared = FSRSScheduler()

    // Standard FSRS v4.5 Default Parameters
    public let w: [Double] = [
        0.4000, 0.9000, 2.3000, 10.900, // 0..3: Initial stabilities
        4.9300, 0.9400,                 // 4..5: Initial difficulty params
        0.8600, 0.0100,                 // 6..7: Difficulty transition & reversion
        1.4900, 0.1400, 0.9400,         // 8..10: Stability recall success
        2.1800, 0.0500, 0.3400, 1.2600, // 11..14: Stability recall failure
        0.2900, 2.6100                  // 15..16: Hard penalty & Easy bonus
    ]

    public let requestRetention: Double = 0.9 // 90% target retention

    public init() {}

    /// Reviews a flashcard with a given rating and produces an updated card.
    public func review(card: Flashcard, rating: FSRSRating, reviewDate: Date = Date()) -> FlashcardReviewResult {
        var updated = card

        let elapsedDays: Int
        if let last = card.lastReview {
            elapsedDays = max(0, Calendar.current.dateComponents([.day], from: last, to: reviewDate).day ?? 0)
        } else {
            elapsedDays = 0
        }

        let newStability: Double
        let newDifficulty: Double
        let newState: FSRSState

        if card.fsrsState == .newCard || card.stability <= 0.0 {
            // Initial learning step
            newStability = initStability(rating: rating)
            newDifficulty = initDifficulty(rating: rating)
            newState = (rating == .again) ? .learning : .review
        } else {
            // Existing card in review / learning
            let r = retrievability(elapsedDays: Double(elapsedDays), stability: card.stability)
            newDifficulty = nextDifficulty(currentD: card.difficulty, rating: rating)

            if rating == .again {
                newStability = nextForgetStability(d: newDifficulty, s: card.stability, r: r)
                newState = .relearning
            } else {
                newStability = nextRecallStability(d: newDifficulty, s: card.stability, r: r, rating: rating)
                newState = .review
            }
        }

        let nextDays = nextInterval(stability: newStability)
        let nextDueDate = Calendar.current.date(byAdding: .day, value: nextDays, to: reviewDate) ?? reviewDate.addingTimeInterval(Double(nextDays) * 86400)

        updated.fsrsState = newState
        updated.stability = (newStability * 100).rounded() / 100
        updated.difficulty = (newDifficulty * 100).rounded() / 100
        updated.elapsedDays = elapsedDays
        updated.scheduledDays = nextDays
        updated.reps += 1
        if rating == .again {
            updated.lapses += 1
        }
        updated.lastReview = reviewDate
        updated.due = nextDueDate
        updated.updatedAt = reviewDate

        return FlashcardReviewResult(
            card: updated,
            rating: rating,
            intervalDays: nextDays,
            newStability: updated.stability,
            newDifficulty: updated.difficulty,
            newState: newState
        )
    }

    /// Previews next scheduled intervals (in days) for each rating option.
    public func previewIntervals(card: Flashcard, reviewDate: Date = Date()) -> [FSRSRating: Int] {
        var results: [FSRSRating: Int] = [:]
        for rating in FSRSRating.allCases {
            let res = review(card: card, rating: rating, reviewDate: reviewDate)
            results[rating] = res.intervalDays
        }
        return results
    }

    // MARK: - Mathematical Formulas
    private func initStability(rating: FSRSRating) -> Double {
        max(0.1, w[rating.rawValue - 1])
    }

    private func initDifficulty(rating: FSRSRating) -> Double {
        let g = Double(rating.rawValue)
        let d = w[4] - exp(w[5] * (g - 1.0)) + 1.0
        return clampDifficulty(d)
    }

    private func retrievability(elapsedDays: Double, stability: Double) -> Double {
        guard stability > 0 else { return 0.0 }
        return pow(1.0 + 19.0 * (elapsedDays / stability), -0.5)
    }

    private func nextDifficulty(currentD: Double, rating: FSRSRating) -> Double {
        let g = Double(rating.rawValue)
        let deltaD = -w[6] * (g - 3.0)
        let d0Good = w[4] - exp(w[5] * 2.0) + 1.0
        let nextD = w[7] * d0Good + (1.0 - w[7]) * (currentD + deltaD)
        return clampDifficulty(nextD)
    }

    private func nextRecallStability(d: Double, s: Double, r: Double, rating: FSRSRating) -> Double {
        let hardPenalty = (rating == .hard) ? w[15] : 1.0
        let easyBonus = (rating == .easy) ? w[16] : 1.0
        let multiplier = 1.0 + exp(w[8]) * (11.0 - d) * pow(s, -w[9]) * (exp(w[10] * (1.0 - r)) - 1.0) * hardPenalty * easyBonus
        return max(s, s * multiplier)
    }

    private func nextForgetStability(d: Double, s: Double, r: Double) -> Double {
        let sFail = w[11] * pow(d, -w[12]) * (pow(s + 1.0, w[13]) - 1.0) * exp(w[14] * (1.0 - r))
        return max(0.1, min(sFail, s))
    }

    private func nextInterval(stability: Double) -> Int {
        // Standard FSRS formula: Interval in days based on stability and target retention
        let interval = (stability / 19.0) * (pow(requestRetention, -2.0) - 1.0)
        let rounded = Int(round(interval))
        if rounded <= 0 {
            // For early learning cards (stability < 1.0 day), minimum interval is 1 day
            return max(1, Int(round(stability)))
        }
        return rounded
    }

    private func clampDifficulty(_ d: Double) -> Double {
        min(10.0, max(1.0, d))
    }
}
