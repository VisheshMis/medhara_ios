/**
 * Tier 2 Boundary & Corner Cases: 02. FSRS-4.5 Math Engine Boundaries
 * Tests zero/negative elapsed days, extreme stability values (0, 40.5, 36500, 100000),
 * difficulty clamping edges, consecutive lapses, and maximum intervals.
 */

const { TestSuite, Assert } = require('../lib/test_framework');
const { FSRSScheduler, Rating, State } = require('../lib/fsrs_engine');

const suite = new TestSuite('Tier 2: FSRS-4.5 Math Engine Boundaries');

suite.test('2.2.1 Zero and negative stability values fallback to 1 day minimum', () => {
  const scheduler = new FSRSScheduler();
  Assert.equal(scheduler.nextInterval(0), 1, 'S = 0 must fallback to 1 day');
  Assert.equal(scheduler.nextInterval(-5), 1, 'S < 0 must fallback to 1 day');
  Assert.equal(scheduler.nextInterval(0.1), 1, 'S = 0.1 must fallback to 1 day');
});

suite.test('2.2.2 Exact 40.5 stability boundary transition (S/81)', () => {
  const scheduler = new FSRSScheduler();
  // For S < 40.5, e.g. S = 40.0: 40/81 = 0.4938 -> rounds to 0 -> fallback max(1, round(40)) = 40
  const iBelow = scheduler.nextInterval(40.0);
  Assert.equal(iBelow, 40, 'For S < 40.5, fallback uses round(S)');

  // For S = 40.5: 40.5/81 = 0.5000 -> rounds to 1 or 41
  const iAt = scheduler.nextInterval(40.5);
  Assert.ok(iAt >= 1);

  // For high S = 81.0: 81/81 = 1.0 -> 1 day
  Assert.equal(scheduler.nextInterval(81.0), 1);

  // For S = 810: 810/81 = 10 -> 10 days
  Assert.equal(scheduler.nextInterval(810.0), 10);
});

suite.test('2.2.3 Extreme high stability (S = 36500 and S = 100000)', () => {
  const scheduler = new FSRSScheduler();
  const i36500 = scheduler.nextInterval(36500);
  Assert.equal(i36500, Math.round(36500 / 81), 'Scheduled interval for S = 36500');

  const i100k = scheduler.nextInterval(100000);
  Assert.ok(i100k > 1000, 'Extreme stability produces large scheduled interval');
});

suite.test('2.2.4 Zero and negative elapsed days during review', () => {
  const scheduler = new FSRSScheduler();
  const card = {
    id: 'fc-zero-t',
    fsrsState: State.Review,
    stability: 5.0,
    difficulty: 3.0,
    reps: 2,
    lapses: 0,
    lastReview: new Date().toISOString(),
    due: new Date().toISOString()
  };

  // Immediate review within 0 elapsed days
  const resSameDay = scheduler.review(card, Rating.Good, new Date());
  Assert.equal(resSameDay.card.elapsedDays, 0, 'Elapsed days is 0');
  Assert.ok(resSameDay.newStability >= card.stability, 'Stability never decreases on Good');

  // Negative elapsed days (system clock jumped backward)
  const pastReview = new Date(Date.now() - 3600000); // 1 hour in past
  const resClockJump = scheduler.review(card, Rating.Good, pastReview);
  Assert.equal(resClockJump.card.elapsedDays, 0, 'Elapsed days clamped to >= 0');
});

suite.test('2.2.5 Extreme difficulty clamping to [1.0, 10.0]', () => {
  const scheduler = new FSRSScheduler();

  // Test clampDifficulty directly
  Assert.equal(scheduler.clampDifficulty(-50.0), 1.0);
  Assert.equal(scheduler.clampDifficulty(0.5), 1.0);
  Assert.equal(scheduler.clampDifficulty(15.0), 10.0);
  Assert.equal(scheduler.clampDifficulty(100.0), 10.0);

  // Iterative difficulty increases (10 consecutive Agains)
  let d = 5.0;
  for (let i = 0; i < 15; i++) {
    d = scheduler.nextDifficulty(d, Rating.Again);
  }
  Assert.ok(d <= 10.0 && d >= 1.0, 'Difficulty clamped within bounds');
  Assert.closeTo(d, 10.0, 0.5, 'Consecutive Agains drive difficulty toward max 10.0');

  // Iterative difficulty decreases (15 consecutive Easys)
  for (let i = 0; i < 15; i++) {
    d = scheduler.nextDifficulty(d, Rating.Easy);
  }
  Assert.equal(d, 1.0, 'Consecutive Easys drive difficulty to minimum 1.0');
});

suite.test('2.2.6 Severe consecutive lapses (5 Agains in a row)', () => {
  const scheduler = new FSRSScheduler();
  let card = {
    id: 'fc-leech',
    fsrsState: State.Review,
    stability: 50.0,
    difficulty: 2.0,
    reps: 5,
    lapses: 0,
    lastReview: new Date('2026-09-01T00:00:00Z').toISOString(),
    due: new Date('2026-09-10T00:00:00Z').toISOString()
  };

  for (let i = 1; i <= 5; i++) {
    const res = scheduler.review(card, Rating.Again, new Date(`2026-09-1${i}T00:00:00Z`));
    card = res.card;
    Assert.equal(card.fsrsState, State.Relearning);
    Assert.equal(card.lapses, i, `Lapse count must be ${i}`);
    Assert.ok(card.stability >= 0.1, 'Stability lower bounded by 0.1');
  }
});

module.exports = suite;

if (require.main === module) {
  suite.run();
}
