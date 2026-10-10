/**
 * FSRS-4.5 Scheduler Mathematical Engine
 * Authoritative implementation matching macOS FSRSScheduler.swift
 * and Windows desktop/src/js/flashcards/fsrs.js.
 */

const Rating = Object.freeze({
  Again: 1,
  Hard: 2,
  Good: 3,
  Easy: 4,
});

const State = Object.freeze({
  NewCard: 0,
  Learning: 1,
  Review: 2,
  Relearning: 3,
});

class FSRSScheduler {
  constructor(weights = null, requestRetention = 0.90) {
    this.w = weights || [
      0.4000, 0.9000, 2.3000, 10.9000, // Initial stabilities
      4.9300, 0.9400,                  // Initial difficulty intercept and slope
      0.8600, 0.0100,                  // Difficulty step and reversion
      1.4900, 0.1400, 0.9400,          // Recall stability growth params
      2.1800, 0.0500, 0.3400, 1.2600,  // Forget stability decay params
      0.2900,                          // Hard penalty
      2.6100                           // Easy bonus
    ];
    this.requestRetention = requestRetention;
  }

  clampDifficulty(d) {
    return Math.min(10.0, Math.max(1.0, d));
  }

  retrievability(elapsedDays, stability) {
    if (stability <= 0) return 0.0;
    return Math.pow(1.0 + 19.0 * (elapsedDays / stability), -0.5);
  }

  initStability(rating) {
    return Math.max(0.1, this.w[rating - 1]);
  }

  initDifficulty(rating) {
    const raw = this.w[4] - Math.exp(this.w[5] * (rating - 1.0)) + 1.0;
    return this.clampDifficulty(raw);
  }

  nextDifficulty(d, rating) {
    const deltaD = -this.w[6] * (rating - 3.0);
    const dGood = this.w[4] - Math.exp(this.w[5] * 2.0) + 1.0;
    const nextD = this.w[7] * dGood + (1.0 - this.w[7]) * (d + deltaD);
    return this.clampDifficulty(nextD);
  }

  nextRecallStability(d, s, r, rating) {
    const hardPenalty = (rating === Rating.Hard) ? this.w[15] : 1.0;
    const easyBonus = (rating === Rating.Easy) ? this.w[16] : 1.0;
    const multiplier = 1.0 + Math.exp(this.w[8]) *
      (11.0 - d) *
      Math.pow(s, -this.w[9]) *
      (Math.exp(this.w[10] * (1.0 - r)) - 1.0) *
      hardPenalty *
      easyBonus;
    return Math.max(s, s * multiplier);
  }

  nextForgetStability(d, s, r) {
    const sFail = this.w[11] *
      Math.pow(d, -this.w[12]) *
      (Math.pow(s + 1.0, this.w[13]) - 1.0) *
      Math.exp(this.w[14] * (1.0 - r));
    return Math.max(0.1, Math.min(sFail, s));
  }

  nextInterval(stability) {
    const interval = (stability / 19.0) * (Math.pow(this.requestRetention, -2.0) - 1.0);
    const rounded = Math.round(interval);
    if (rounded <= 0) {
      return Math.max(1, Math.round(stability));
    }
    return rounded;
  }

  previewIntervals(card, reviewDate = new Date()) {
    const ratings = [Rating.Again, Rating.Hard, Rating.Good, Rating.Easy];
    const preview = {};
    for (const r of ratings) {
      const res = this.review(card, r, reviewDate);
      preview[r] = res.intervalDays;
    }
    return preview;
  }

  review(card, rating, reviewDate = new Date()) {
    const now = (reviewDate instanceof Date) ? reviewDate : new Date(reviewDate);
    let elapsedDays = 0;
    if (card.lastReview) {
      const last = new Date(card.lastReview);
      elapsedDays = Math.max(0, Math.floor((now.getTime() - last.getTime()) / (24 * 60 * 60 * 1000)));
    }

    let newStability = 0.0;
    let newDifficulty = 0.0;
    let newState = card.fsrsState;
    let lapses = card.lapses || 0;
    let reps = (card.reps || 0) + 1;

    if (card.fsrsState === State.NewCard) {
      newStability = this.initStability(rating);
      newDifficulty = this.initDifficulty(rating);

      if (rating === Rating.Again) {
        newState = State.Learning;
        lapses += 1;
      } else {
        newState = State.Review;
      }
    } else {
      const r = this.retrievability(elapsedDays, card.stability);
      newDifficulty = this.nextDifficulty(card.difficulty, rating);

      if (rating === Rating.Again) {
        newStability = this.nextForgetStability(newDifficulty, card.stability, r);
        newState = State.Relearning;
        lapses += 1;
      } else {
        newStability = this.nextRecallStability(newDifficulty, card.stability, r, rating);
        newState = State.Review;
      }
    }

    let intervalDays = 0;
    let dueDate = new Date(now);

    if (rating === Rating.Again && newState === State.Learning) {
      // First review lapse: 10m in UI or 1 day fallback
      intervalDays = 1;
      dueDate.setDate(dueDate.getDate() + 1);
    } else {
      intervalDays = this.nextInterval(newStability);
      dueDate.setDate(dueDate.getDate() + intervalDays);
    }

    const updatedCard = {
      ...card,
      fsrsState: newState,
      stability: Math.round(newStability * 100) / 100,
      difficulty: Math.round(newDifficulty * 100) / 100,
      elapsedDays,
      scheduledDays: intervalDays,
      reps,
      lapses,
      lastReview: now.toISOString(),
      due: dueDate.toISOString(),
      updatedAt: now.toISOString()
    };

    return {
      card: updatedCard,
      newState,
      newStability: Math.round(newStability * 100) / 100,
      newDifficulty: Math.round(newDifficulty * 100) / 100,
      intervalDays
    };
  }

  formatInterval(days) {
    if (days === 0) return '10m';
    if (days < 30) return `${days}d`;
    if (days < 365) return `${(days / 30.0).toFixed(1)}mo`;
    return `${(days / 365.0).toFixed(1)}y`;
  }
}

module.exports = {
  Rating,
  State,
  FSRSScheduler,
};
