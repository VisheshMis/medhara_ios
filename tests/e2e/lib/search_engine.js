/**
 * Medha FTS5 Search Engine Service
 * Authoritative implementation matching SearchService.swift
 * and desktop/electron/database/db.js.
 */

class SearchEngine {
  /**
   * Transforms raw user query into FTS5 prefix-wildcard query string.
   */
  static formatFtsQuery(query) {
    if (!query || typeof query !== 'string') return '';
    const trimmed = query.trim();
    if (!trimmed) return '';

    const tokens = trimmed
      .split(/\s+/)
      .map(t => t.replace(/['"]/g, ''))
      .filter(t => t.length > 0)
      .map(t => `"${t}"*`);

    return tokens.join(' ');
  }

  /**
   * Executes FTS5 search query with BM25 snippet extraction and verified boost ranking.
   */
  static search(db, query, limit = 40) {
    const ftsPattern = this.formatFtsQuery(query);
    if (!ftsPattern) return [];

    const sql = `
      SELECT 
        b.id,
        b.rootDocId,
        b.type,
        b.content,
        b.notebookId,
        snippet(block_fts, 2, '<b>', '</b>', '...', 20) AS snippet,
        (
          CASE 
            WHEN b.verifiedExpiresAt IS NOT NULL AND b.verifiedExpiresAt > datetime('now') 
            THEN bm25(block_fts) - 2.0 
            ELSE bm25(block_fts) 
          END
        ) AS rankScore
      FROM block_fts f
      JOIN block b ON b.id = f.id
      WHERE block_fts MATCH ?
      ORDER BY rankScore ASC
      LIMIT ?
    `;

    return db.prepare(sql).all(ftsPattern, limit);
  }
}

module.exports = {
  SearchEngine,
};
