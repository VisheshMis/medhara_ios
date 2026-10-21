// Medha Web — Free Spaced Repetition Scheduler (FSRS v4.5)
// Mathematically mirrors MedhaKit/Services/FSRSScheduler.swift

export const State = {
    New: 0,
    Learning: 1,
    Review: 2,
    Relearning: 3
};

export const Rating = {
    Again: 1,
    Hard: 2,
    Good: 3,
    Easy: 4
};

// Default FSRS-4.5 weights
const DEFAULT_WEIGHTS = [
    0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046,
    1.54575, 0.1192, 1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315, 2.9898
];

const DECAY = -0.5;
const FACTOR = Math.pow(0.9, 1 / DECAY) - 1; // ~19/81

export class FSRSScheduler {
    constructor(weights = DEFAULT_WEIGHTS, requestRetention = 0.9, maximumInterval = 36500) {
        this.w = weights;
        this.requestRetention = requestRetention;
        this.maximumInterval = maximumInterval;
    }

    // Initialize difficulty for a new card
    initDifficulty(rating) {
        const val = this.w[4] - Math.exp(this.w[5] * (rating - 1)) + 1;
        return Math.min(Math.max(val, 1.0), 10.0);
    }

    // Initialize stability for a new card
    initStability(rating) {
        return Math.max(this.w[rating - 1], 0.1);
    }

    // Next difficulty computation
    nextDifficulty(d, rating) {
        const delta = -this.w[6] * (rating - 3);
        const nextD = d + delta;
        const meanReversion = this.w[7] * this.initDifficulty(Rating.Easy) + (1 - this.w[7]) * nextD;
        return Math.min(Math.max(meanReversion, 1.0), 10.0);
    }

    // Retrievability at time t (in days)
    retrievability(stability, elapsedDays) {
        if (stability <= 0) return 0;
        return Math.pow(1 + (FACTOR * elapsedDays) / stability, DECAY);
    }

    // Next stability when successfully recalled (Good, Hard, Easy)
    nextRecallStability(d, s, r, rating) {
        const hardPenalty = rating === Rating.Hard ? this.w[15] : 1.0;
        const easyBonus = rating === Rating.Easy ? this.w[16] : 1.0;
        const sPrime = s * (1 + Math.exp(this.w[8]) *
            (11 - d) *
            Math.pow(s, -this.w[9]) *
            (Math.exp((1 - r) * this.w[10]) - 1) *
            hardPenalty *
            easyBonus);
        return Math.max(sPrime, 0.1);
    }

    // Next stability when forgotten (Again)
    nextForgetStability(d, s, r) {
        const sPrime = this.w[11] *
            Math.pow(d, -this.w[12]) *
            (Math.pow(s + 1, this.w[13]) - 1) *
            Math.exp((1 - r) * this.w[14]);
        return Math.min(Math.max(sPrime, 0.1), s);
    }

    // Computes interval in days from stability
    calculateInterval(stability) {
        const interval = (stability / FACTOR) * (Math.pow(this.requestRetention, 1 / DECAY) - 1);
        return Math.min(Math.max(Math.round(interval), 1), this.maximumInterval);
    }

    // Review step: returns { nextCard, intervalDays, nextDueDate }
    review(card, rating, now = Date.now()) {
        const elapsedDays = card.lastReview
            ? Math.max(0, (now - card.lastReview) / (1000 * 60 * 60 * 24))
            : 0;

        let nextDifficulty = card.difficulty;
        let nextStability = card.stability;
        let nextState = card.state;
        let intervalDays = 1;

        if (card.state === State.New) {
            nextDifficulty = this.initDifficulty(rating);
            nextStability = this.initStability(rating);

            if (rating === Rating.Again) {
                nextState = State.Learning;
                intervalDays = 0.007; // ~10 minutes
            } else if (rating === Rating.Hard) {
                nextState = State.Learning;
                intervalDays = 0.02; // ~30 minutes
            } else if (rating === Rating.Good) {
                nextState = State.Review;
                intervalDays = this.calculateInterval(nextStability);
            } else if (rating === Rating.Easy) {
                nextState = State.Review;
                intervalDays = Math.max(this.calculateInterval(nextStability) * 1.3, 4);
            }
        } else {
            // Existing review or learning
            const r = this.retrievability(card.stability, elapsedDays);
            nextDifficulty = this.nextDifficulty(card.difficulty, rating);

            if (rating === Rating.Again) {
                nextState = State.Relearning;
                nextStability = this.nextForgetStability(nextDifficulty, card.stability, r);
                intervalDays = 0.007; // ~10 minutes
            } else {
                nextState = State.Review;
                nextStability = this.nextRecallStability(nextDifficulty, card.stability, r, rating);
                intervalDays = this.calculateInterval(nextStability);
            }
        }

        const nextDueDate = now + Math.round(intervalDays * 24 * 60 * 60 * 1000);

        return {
            updatedCard: {
                ...card,
                difficulty: Number(nextDifficulty.toFixed(2)),
                stability: Number(nextStability.toFixed(2)),
                state: nextState,
                due: nextDueDate,
                reps: card.reps + 1,
                lapses: rating === Rating.Again ? card.lapses + 1 : card.lapses,
                lastReview: now
            },
            intervalDays
        };
    }

    // Predicts next interval string for each of the 4 ratings
    predictIntervals(card, now = Date.now()) {
        const ratings = [Rating.Again, Rating.Hard, Rating.Good, Rating.Easy];
        const res = {};
        for (const r of ratings) {
            const { intervalDays } = this.review(card, r, now);
            res[r] = this.formatInterval(intervalDays);
        }
        return res;
    }

    formatInterval(days) {
        if (days < 0.02) return '10m';
        if (days < 0.05) return '30m';
        if (days < 1) return `${Math.round(days * 24)}h`;
        if (days < 30) return `${Math.round(days)}d`;
        if (days < 365) return `${(days / 30).toFixed(1)}mo`;
        return `${(days / 365).toFixed(1)}y`;
    }
}

export const fsrs = new FSRSScheduler();
