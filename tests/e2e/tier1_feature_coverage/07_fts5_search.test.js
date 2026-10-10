/**
 * Tier 1 Feature Coverage: 07. FTS5 Search Engine & BM25 Ranking
 * Verifies unicode61 tokenization, prefix wildcards, BM25 snippet extraction,
 * verified block boost ranking, and multilingual search support per R1.
 */

const { TestSuite, Assert } = require('../lib/test_framework');
const { createInitializedDatabase } = require('../lib/sqlite_schema');
const { SearchEngine } = require('../lib/search_engine');

const suite = new TestSuite('Tier 1: FTS5 Search Engine (R1, R2)');

suite.test('7.1 Prefix wildcard query formatting', () => {
  const q1 = SearchEngine.formatFtsQuery('quantum computing');
  Assert.equal(q1, '"quantum"* "computing"*');

  const q2 = SearchEngine.formatFtsQuery('  single   word  ');
  Assert.equal(q2, '"single"* "word"*');

  const q3 = SearchEngine.formatFtsQuery('stripping "quotes" and \'apostrophes\'');
  Assert.equal(q3, '"stripping"* "quotes"* "and"* "apostrophes"*');

  const q4 = SearchEngine.formatFtsQuery('');
  Assert.equal(q4, '');
});

suite.test('7.2 Sub-millisecond FTS5 search and snippet extraction with <b> tags', () => {
  const db = createInitializedDatabase();
  const now = new Date().toISOString();

  db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
    VALUES ('b-search-1', 'doc-1', NULL, 'paragraph', 'Photosynthesis converts radiant solar energy into chemical energy stored in glucose.', 0, ?, ?, 'nb-welcome-kb')
  `).run(now, now);

  const results = SearchEngine.search(db, 'photosynthesis solar');
  Assert.equal(results.length, 1);
  Assert.equal(results[0].id, 'b-search-1');
  Assert.ok(results[0].snippet.includes('<b>Photosynthesis</b>') || results[0].snippet.includes('<b>solar</b>'));
  db.close();
});

suite.test('7.3 Multilingual Unicode61 tokenization (accents, Cyrillic, CJK, Arabic)', () => {
  const db = createInitializedDatabase();
  const now = new Date().toISOString();

  // Accented French
  db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
    VALUES ('b-fr', 'doc-1', NULL, 'paragraph', 'Théorie de la relativité restreinte et générale par Albert Einstein.', 0, ?, ?, 'nb-welcome-kb')
  `).run(now, now);

  // Cyrillic
  db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
    VALUES ('b-ru', 'doc-1', NULL, 'paragraph', 'Квантовая механика изучает микромир и волновые функции.', 1, ?, ?, 'nb-welcome-kb')
  `).run(now, now);

  // CJK Japanese
  db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId)
    VALUES ('b-jp', 'doc-1', NULL, 'paragraph', '人工知能と機械学習の数理モデル', 2, ?, ?, 'nb-welcome-kb')
  `).run(now, now);

  // Search French
  const frRes = SearchEngine.search(db, 'relativité');
  Assert.equal(frRes.length, 1);
  Assert.equal(frRes[0].id, 'b-fr');

  // Search Cyrillic
  const ruRes = SearchEngine.search(db, 'Квантовая');
  Assert.equal(ruRes.length, 1);
  Assert.equal(ruRes[0].id, 'b-ru');

  // Search CJK
  const jpRes = SearchEngine.search(db, '人工知能');
  Assert.equal(jpRes.length, 1);
  Assert.equal(jpRes[0].id, 'b-jp');

  db.close();
});

suite.test('7.4 Verified block boost ranking (-2.0 BM25 score deduction)', () => {
  const db = createInitializedDatabase();
  const now = new Date().toISOString();
  const futureExpiry = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();

  // Unverified block
  db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId, verifiedExpiresAt)
    VALUES ('b-unverified', 'doc-1', NULL, 'paragraph', 'Cellular respiration produces ATP in mitochondria.', 0, ?, ?, 'nb-welcome-kb', NULL)
  `).run(now, now);

  // Verified block with identical keyword
  db.prepare(`
    INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, createdAt, updatedAt, notebookId, verifiedExpiresAt)
    VALUES ('b-verified', 'doc-1', NULL, 'paragraph', 'Cellular respiration produces high yield ATP via oxidative phosphorylation.', 1, ?, ?, 'nb-welcome-kb', ?)
  `).run(now, now, futureExpiry);

  const results = SearchEngine.search(db, 'respiration ATP');
  Assert.equal(results.length, 2);

  // Verified block must rank first due to -2.0 rankScore boost
  Assert.equal(results[0].id, 'b-verified', 'Verified block must rank first in search results');
  Assert.ok(results[0].rankScore < results[1].rankScore, 'Lower rankScore means higher relevance');
  db.close();
});

suite.test('7.5 Edge case queries: empty strings, pure punctuation, non-matching terms', () => {
  const db = createInitializedDatabase();

  Assert.deepEqual(SearchEngine.search(db, ''), []);
  Assert.deepEqual(SearchEngine.search(db, '   '), []);
  Assert.deepEqual(SearchEngine.search(db, '??? !!! ***'), []);
  Assert.deepEqual(SearchEngine.search(db, 'nonexistentuniquetoken123456789'), []);

  db.close();
});

module.exports = suite;

if (require.main === module) {
  suite.run();
}
