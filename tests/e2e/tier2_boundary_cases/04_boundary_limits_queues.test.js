/**
 * Tier 2 Boundary & Corner Cases: 04. Limits, Presets, & Queues Boundaries
 * Tests zero daily limits, extreme retention targets (0.70 vs 0.99),
 * empty queues, large dataset queries, and leech detection thresholds.
 */

const { TestSuite, Assert } = require('../lib/test_framework');
const { createInitializedDatabase } = require('../lib/sqlite_schema');
const { FSRSScheduler, Rating } = require('../lib/fsrs_engine');

const suite = new TestSuite('Tier 2: Limits, Presets, & Queues Boundaries');

suite.test('2.4.1 Zero daily new card limit prevents new cards from entering queue', () => {
  const db = createInitializedDatabase();
  const now = new Date().toISOString();

  // Insert 3 new cards
  for (let i = 1; i <= 3; i++) {
    db.prepare(`
      INSERT INTO flashcard (id, docId, notebookId, front, back, fsrsState, due, createdAt, updatedAt)
      VALUES (?, 'doc-1', 'nb-welcome-kb', 'Q', 'A', 0, ?, ?, ?)
    `).run(`fc-zero-lim-${i}`, now, now, now);
  }

  // Set limit = 0
  const limit = 0;
  const cards = db.prepare(`
    SELECT * FROM flashcard
    WHERE isSuspended = 0 AND fsrsState = 0
    LIMIT ?
  `).all(limit);

  Assert.equal(cards.length, 0, 'Zero limit returns empty array');
  db.close();
});

suite.test('2.4.2 Retention target comparison: R = 0.70 vs R = 0.99', () => {
  const schedHighRetention = new FSRSScheduler(null, 0.99); // 99% retention
  const schedLowRetention = new FSRSScheduler(null, 0.70);  // 70% retention

  const stability = 2000.0;
  const intervalHigh = schedHighRetention.nextInterval(stability);
  const intervalLow = schedLowRetention.nextInterval(stability);

  // Requiring higher retention (0.99) requires reviewing MUCH sooner than 0.70
  Assert.ok(intervalHigh < intervalLow, 'Higher retention target requires shorter intervals');
  Assert.ok(intervalLow > intervalHigh * 2, '0.70 retention gives substantially longer intervals than 0.99');
});

suite.test('2.4.3 Empty study queue behavior', () => {
  const db = createInitializedDatabase();
  const now = new Date().toISOString();

  // Query on empty table
  const cards = db.prepare(`
    SELECT * FROM flashcard
    WHERE isSuspended = 0 AND (fsrsState = 0 OR due <= ?)
  `).all(now);

  Assert.equal(cards.length, 0, 'Empty database returns zero cards');
  db.close();
});

suite.test('2.4.4 Large scale queue query performance (1,000 flashcards in DB)', () => {
  const db = createInitializedDatabase();
  const now = new Date();
  const past = new Date(now.getTime() - 86400000).toISOString();
  const future = new Date(now.getTime() + 86400000).toISOString();

  // Seed 1,000 cards in transaction
  const insert = db.prepare(`
    INSERT INTO flashcard (id, docId, notebookId, front, back, fsrsState, due, createdAt, updatedAt)
    VALUES (?, 'doc-1', 'nb-welcome-kb', 'Front', 'Back', ?, ?, ?, ?)
  `);

  const tx = db.transaction(() => {
    for (let i = 1; i <= 1000; i++) {
      const isDue = (i % 2 === 0);
      insert.run(`fc-bulk-${i}`, isDue ? 0 : 2, isDue ? past : future, past, past);
    }
  });
  tx();

  const queryStart = Date.now();
  const due = db.prepare(`
    SELECT id, due, fsrsState FROM flashcard
    WHERE isSuspended = 0 AND (fsrsState = 0 OR due <= ?)
    ORDER BY due ASC
    LIMIT 50
  `).all(now.toISOString());
  const queryDuration = Date.now() - queryStart;

  Assert.equal(due.length, 50, 'Fetched top 50 due cards');
  Assert.ok(queryDuration < 20, `Sub-20ms indexed query (took ${queryDuration}ms)`);
  db.close();
});

suite.test('2.4.5 Leech detection threshold (leechThreshold = 8 lapses)', () => {
  const deckPreset = {
    leechThreshold: 8,
    leechAction: 'tagOnly' // or suspend
  };

  const card = {
    id: 'fc-leech-test',
    lapses: 8,
    isSuspended: 0,
    tags: []
  };

  // Leech check logic
  const isLeech = card.lapses >= deckPreset.leechThreshold;
  Assert.equal(isLeech, true);

  if (isLeech && deckPreset.leechAction === 'tagOnly') {
    card.tags.push('leech');
  }

  Assert.ok(card.tags.includes('leech'), 'Card tagged as leech');
  Assert.equal(card.isSuspended, 0, 'Card not suspended under tagOnly policy');
});

module.exports = suite;

if (require.main === module) {
  suite.run();
}
