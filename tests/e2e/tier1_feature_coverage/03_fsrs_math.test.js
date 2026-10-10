/**
 * Tier 1 Feature Coverage: 03. FSRS-4.5 Mathematical Engine
 * Rigorously verifies all 17 default parameters, initial formulas,
 * retrievability decay, recall growth, lapse stability decay, and scheduled intervals
 * against the authoritative Swift FSRSScheduler.swift and test runner benchmarks.
 */

const { TestSuite, Assert } = require('../lib/test_framework');
const { FSRSScheduler, Rating, State } = require('../lib/fsrs_engine');

const suite = new TestSuite('Tier 1: FSRS-4.5 Mathematical Engine (R2)');

suite.test('3.1 Exactly 17 default weights and 90% retention target', () => {
  const scheduler = new FSRSScheduler();
  Assert.equal(scheduler.w.length, 17, 'Parameter vector w must have length 17');
  Assert.equal(scheduler.requestRetention, 0.90, 'Default requestRetention must be 0.90');

  const expectedW = [
    0.4000, 0.9000, 2.3000, 10.9000,
    4.9300, 0.9400,
    0.8600, 0.0100,
    1.4900, 0.1400, 0.9400,
    2.1800, 0.0500, 0.3400, 1.2600,
    0.2900,
    2.6100
  ];
  for (let i = 0; i < 17; i++) {
    Assert.closeTo(scheduler.w[i], expectedW[i], 0.0001, `Weight w[${i}]`);
  }
});

suite.test('3.2 Initial stability S0(G) for all 4 ratings', () => {
  const scheduler = new FSRSScheduler();
  Assert.closeTo(scheduler.initStability(Rating.Again), 0.40, 0.001);
  Assert.closeTo(scheduler.initStability(Rating.Hard), 0.90, 0.001);
  Assert.closeTo(scheduler.initStability(Rating.Good), 2.30, 0.001);
  Assert.closeTo(scheduler.initStability(Rating.Easy), 10.90, 0.001);
});

suite.test('3.3 Initial difficulty D0(G) and clamping to [1.0, 10.0]', () => {
  const scheduler = new FSRSScheduler();
  // Again: 4.93 - exp(0) + 1.0 = 4.93
  Assert.closeTo(scheduler.initDifficulty(Rating.Again), 4.93, 0.01);
  // Hard: 4.93 - exp(0.94) + 1.0 = 5.93 - 2.56 = 3.37
  Assert.closeTo(scheduler.initDifficulty(Rating.Hard), 3.37, 0.01);
  // Good: unclamped -0.62 -> clamped to 1.0
  Assert.closeTo(scheduler.initDifficulty(Rating.Good), 1.00, 0.01);
  // Easy: unclamped -10.85 -> clamped to 1.0
  Assert.closeTo(scheduler.initDifficulty(Rating.Easy), 1.00, 0.01);
});

suite.test('3.4 Power-law Retrievability R(t, S)', () => {
  const scheduler = new FSRSScheduler();
  // S <= 0 returns 0
  Assert.equal(scheduler.retrievability(0, 0), 0.0);
  Assert.equal(scheduler.retrievability(5, -1), 0.0);

  // t = 0 -> R = 1.0
  Assert.closeTo(scheduler.retrievability(0, 2.3), 1.0, 0.001);

  // t = 2, S = 2.3 -> R = (1 + 19 * 2 / 2.3)^-0.5 = (1 + 16.5217)^-0.5 = 17.5217^-0.5 = ~0.2389
  const rVal = scheduler.retrievability(2, 2.3);
  Assert.closeTo(rVal, 0.2389, 0.005);
});

suite.test('3.5 Test Vector 1: Fresh card rating responses and state transitions', () => {
  const scheduler = new FSRSScheduler();
  const freshCard = {
    id: 'fc-fresh',
    docId: 'doc-1',
    notebookId: 'nb-1',
    front: 'Q',
    back: 'A',
    fsrsState: State.NewCard,
    stability: 0.0,
    difficulty: 0.0,
    elapsedDays: 0,
    scheduledDays: 0,
    reps: 0,
    lapses: 0,
    lastReview: null,
    due: new Date().toISOString()
  };

  // 1. Again: enters Learning (1), S = 0.40, D = 4.93, interval = 1d, reps = 1, lapses = 1
  const resAgain = scheduler.review(freshCard, Rating.Again);
  Assert.equal(resAgain.newState, State.Learning);
  Assert.closeTo(resAgain.newStability, 0.40, 0.01);
  Assert.closeTo(resAgain.newDifficulty, 4.93, 0.01);
  Assert.equal(resAgain.card.reps, 1);
  Assert.equal(resAgain.card.lapses, 1);
  Assert.equal(resAgain.intervalDays, 1);

  // 2. Hard: enters Review (2), S = 0.90, D = 3.37, interval = 1d, reps = 1, lapses = 0
  const resHard = scheduler.review(freshCard, Rating.Hard);
  Assert.equal(resHard.newState, State.Review);
  Assert.closeTo(resHard.newStability, 0.90, 0.01);
  Assert.closeTo(resHard.newDifficulty, 3.37, 0.01);
  Assert.equal(resHard.card.reps, 1);
  Assert.equal(resHard.card.lapses, 0);

  // 3. Good: enters Review (2), S = 2.30, D = 1.00, interval = 2d, reps = 1, lapses = 0
  const resGood = scheduler.review(freshCard, Rating.Good);
  Assert.equal(resGood.newState, State.Review);
  Assert.closeTo(resGood.newStability, 2.30, 0.01);
  Assert.closeTo(resGood.newDifficulty, 1.00, 0.01);
  Assert.equal(resGood.card.reps, 1);
  Assert.equal(resGood.card.lapses, 0);
  Assert.equal(resGood.intervalDays, 2);

  // 4. Easy: enters Review (2), S = 10.90, D = 1.00, interval = 11d, reps = 1, lapses = 0
  const resEasy = scheduler.review(freshCard, Rating.Easy);
  Assert.equal(resEasy.newState, State.Review);
  Assert.closeTo(resEasy.newStability, 10.90, 0.01);
  Assert.closeTo(resEasy.newDifficulty, 1.00, 0.01);
  Assert.equal(resEasy.card.reps, 1);
  Assert.equal(resEasy.card.lapses, 0);
  Assert.equal(resEasy.intervalDays, 11);
});

suite.test('3.6 Test Vector 2: Multi-step review cycle (Good -> Recall -> Lapse -> Relearn)', () => {
  const scheduler = new FSRSScheduler();
  const t0 = new Date('2026-10-01T12:00:00Z');

  // Step 1: Initial Good review
  const freshCard = {
    id: 'fc-v2',
    docId: 'doc-1',
    notebookId: 'nb-1',
    front: 'Q2',
    back: 'A2',
    fsrsState: State.NewCard,
    stability: 0.0,
    difficulty: 0.0,
    reps: 0,
    lapses: 0,
    lastReview: null,
    due: t0.toISOString()
  };
  const step1 = scheduler.review(freshCard, Rating.Good, t0);
  Assert.equal(step1.newState, State.Review);
  Assert.closeTo(step1.newStability, 2.30, 0.01);
  Assert.closeTo(step1.newDifficulty, 1.00, 0.01);

  // Step 2: 2 days later, review Good
  const t1 = new Date('2026-10-03T12:00:00Z');
  const step2 = scheduler.review(step1.card, Rating.Good, t1);
  Assert.equal(step2.newState, State.Review);
  Assert.equal(step2.card.elapsedDays, 2);
  Assert.ok(step2.newStability > 90.0, 'Stability must experience significant recall growth');
  Assert.equal(step2.card.reps, 2);
  Assert.equal(step2.card.lapses, 0);

  // Step 3: 10 days later, review Again (Lapse)
  const t2 = new Date('2026-10-13T12:00:00Z');
  const step3 = scheduler.review(step2.card, Rating.Again, t2);
  Assert.equal(step3.newState, State.Relearning, 'Lapse puts card into Relearning state');
  Assert.equal(step3.card.lapses, 1, 'Lapse counter incremented');
  Assert.ok(step3.newStability < step2.newStability, 'Stability must decay significantly upon lapse');
  Assert.closeTo(step3.newStability, 13.38, 0.5);

  // Step 4: 1 day later, review Good (Relearning recovery)
  const t3 = new Date('2026-10-14T12:00:00Z');
  const step4 = scheduler.review(step3.card, Rating.Good, t3);
  Assert.equal(step4.newState, State.Review, 'Recovered card returns to Review state');
  Assert.equal(step4.card.reps, 4);
  Assert.ok(step4.newStability > step3.newStability, 'Stability grows again after recovery');
});

suite.test('3.7 Preview intervals without card mutation', () => {
  const scheduler = new FSRSScheduler();
  const card = {
    id: 'fc-prev',
    docId: 'doc-1',
    notebookId: 'nb-1',
    front: 'Q',
    back: 'A',
    fsrsState: State.NewCard,
    stability: 0.0,
    difficulty: 0.0,
    reps: 0,
    lapses: 0,
    lastReview: null,
    due: new Date().toISOString()
  };

  const previews = scheduler.previewIntervals(card);
  Assert.equal(previews[Rating.Again], 1);
  Assert.equal(previews[Rating.Hard], 1);
  Assert.equal(previews[Rating.Good], 2);
  Assert.equal(previews[Rating.Easy], 11);

  // Check monotonic relationship: Easy >= Good >= Hard >= Again
  Assert.ok(previews[Rating.Easy] >= previews[Rating.Good]);
  Assert.ok(previews[Rating.Good] >= previews[Rating.Hard]);
  Assert.ok(previews[Rating.Hard] >= previews[Rating.Again]);

  // Card object is untouched
  Assert.equal(card.fsrsState, State.NewCard);
  Assert.equal(card.reps, 0);
});

suite.test('3.8 Human-readable interval formatting', () => {
  const scheduler = new FSRSScheduler();
  Assert.equal(scheduler.formatInterval(0), '10m');
  Assert.equal(scheduler.formatInterval(1), '1d');
  Assert.equal(scheduler.formatInterval(14), '14d');
  Assert.equal(scheduler.formatInterval(60), '2.0mo');
  Assert.equal(scheduler.formatInterval(730), '2.0y');
});

module.exports = suite;

if (require.main === module) {
  suite.run();
}
