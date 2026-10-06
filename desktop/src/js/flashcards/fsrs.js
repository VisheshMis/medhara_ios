// Medha Windows Desktop — FSRS-4.5 Scheduler Engine
// 100% faithful port of FSRSScheduler.swift

const Rating = {
    Again: 1,
    Hard: 2,
    Good: 3,
    Easy: 4
};

const State = {
    NewCard: 0,
    Learning: 1,
    Review: 2,
    Relearning: 3
};

class FSRSScheduler {
    constructor() {
        // Standard FSRS v4.5 Default Parameters (17 weights)
        this.w = [
            0.4000, 0.9000, 2.3000, 10.900, // 0..3: Initial stabilities
            4.9300, 0.9400,                 // 4..5: Initial difficulty params
            0.8600, 0.0100,                 // 6..7: Difficulty transition & reversion
            1.4900, 0.1400, 0.9400,         // 8..10: Stability recall success
            2.1800, 0.0500, 0.3400, 1.2600, // 11..14: Stability recall failure
            0.2900, 2.6100                  // 15..16: Hard penalty & Easy bonus
        ];
        this.requestRetention = 0.9; // 90% target retention
    }

    retrievability(elapsedDays, stability) {
        if (stability <= 0.0) return 0.0;
        return Math.pow(1.0 + (19.0 * elapsedDays) / (9.0 * stability), -0.5);
    }

    initStability(rating) {
        return Math.max(0.1, this.w[rating - 1]);
    }

    initDifficulty(rating) {
        const val = this.w[4] - Math.exp(this.w[5] * (rating - 1)) + 1.0;
        return Math.min(10.0, Math.max(1.0, val));
    }

    nextDifficulty(currentD, rating) {
        const delta = -this.w[6] * (rating - 3);
        const nextD = currentD + delta;
        const meanReversion = this.w[7] * this.initDifficulty(Rating.Easy) + (1.0 - this.w[7]) * nextD;
        return Math.min(10.0, Math.max(1.0, meanReversion));
    }

    nextRecallStability(d, s, r, rating) {
        const hardPenalty = rating === Rating.Hard ? this.w[15] : 1.0;
        const easyBonus = rating === Rating.Easy ? this.w[16] : 1.0;
        const factor = Math.exp(this.w[8]) *
            (11.0 - d) *
            Math.pow(s, -this.w[9]) *
            (Math.exp((1.0 - r) * this.w[10]) - 1.0) *
            hardPenalty *
            easyBonus;
        return s * (1.0 + factor);
    }

    nextForgetStability(d, s, r) {
        const val = this.w[11] *
            Math.pow(d, -this.w[12]) *
            (Math.pow(s + 1.0, this.w[13]) - 1.0) *
            Math.exp((1.0 - r) * this.w[14]);
        return Math.max(0.1, Math.min(s, val));
    }

    intervalDays(stability) {
        const factor = (Math.pow(this.requestRetention, -2.0) - 1.0) * 9.0 / 19.0;
        const days = Math.round(stability * factor);
        return Math.max(1, days);
    }

    review(card, rating, reviewDate = new Date()) {
        let elapsedDays = 0;
        if (card.lastReview) {
            const last = new Date(card.lastReview);
            const diffMs = reviewDate.getTime() - last.getTime();
            elapsedDays = Math.max(0, Math.floor(diffMs / (1000 * 60 * 60 * 24)));
        }

        let newStability = 0.0;
        let newDifficulty = 0.0;
        let newState = State.Review;

        if (card.fsrsState === State.NewCard || card.stability <= 0.0) {
            newStability = this.initStability(rating);
            newDifficulty = this.initDifficulty(rating);
            newState = (rating === Rating.Again) ? State.Learning : State.Review;
        } else {
            const r = this.retrievability(elapsedDays, card.stability);
            newDifficulty = this.nextDifficulty(card.difficulty, rating);

            if (rating === Rating.Again) {
                newStability = this.nextForgetStability(newDifficulty, card.stability, r);
                newState = State.Relearning;
            } else {
                newStability = this.nextRecallStability(newDifficulty, card.stability, r, rating);
                newState = State.Review;
            }
        }

        const scheduledDays = (rating === Rating.Again) ? 0 : this.intervalDays(newStability);
        const due = new Date(reviewDate);
        if (rating === Rating.Again) {
            due.setMinutes(due.getMinutes() + 10); // 10 minute repeat for Again
        } else {
            due.setDate(due.getDate() + scheduledDays);
        }

        const reps = (card.reps || 0) + 1;
        const lapses = (card.lapses || 0) + (rating === Rating.Again ? 1 : 0);

        const updatedCard = {
            ...card,
            fsrsState: newState,
            stability: newStability,
            difficulty: newDifficulty,
            elapsedDays,
            scheduledDays,
            reps,
            lapses,
            lastReview: reviewDate.toISOString(),
            due: due.toISOString(),
            updatedAt: reviewDate.toISOString()
        };

        return {
            card: updatedCard,
            rating,
            intervalDays: scheduledDays,
            newStability,
            newDifficulty,
            newState
        };
    }

    formatInterval(days) {
        if (days <= 0) return '10m';
        if (days === 1) return '1d';
        if (days < 30) return `${days}d`;
        if (days < 365) return `${(days / 30).toFixed(1)}mo`;
        return `${(days / 365).toFixed(1)}y`;
    }
}

const fsrs = new FSRSScheduler();

if (typeof module !== 'undefined') {
    module.exports = { FSRSScheduler, fsrs, Rating, State };
}
