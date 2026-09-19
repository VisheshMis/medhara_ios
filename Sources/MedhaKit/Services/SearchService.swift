import Foundation
import GRDB

public final class SearchService: @unchecked Sendable {
    private let dbWriter: any DatabaseWriter

    public init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    public func search(query: String) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Format FTS5 query with wildcard tokens
        let tokens = trimmed.components(separatedBy: .whitespaces)
            .map { $0.replacingOccurrences(of: "\"", with: "") }
            .filter { !$0.isEmpty }
            .map { "\"\($0)\"*" }
        guard !tokens.isEmpty else { return [] }
        let ftsPattern = tokens.joined(separator: " ")

        do {
            return try dbWriter.read { db in
                let sql = """
                SELECT
                    b.id AS blockId,
                    b.rootDocId AS rootDocId,
                    b.type AS typeStr,
                    b.content AS rawContent,
                    d.content AS docTitle,
                    snippet(block_fts, 2, '【', '】', '...', 16) AS highlightedSnippet
                FROM block_fts
                JOIN block b ON b.id = block_fts.id
                JOIN block d ON d.id = b.rootDocId
                WHERE block_fts MATCH ?
                ORDER BY bm25(block_fts)
                LIMIT 40
                """
                let rows = try Row.fetchAll(db, sql: sql, arguments: [ftsPattern])
                return rows.compactMap { row -> SearchResult? in
                    let blockId: String = row["blockId"]
                    let rootDocId: String = row["rootDocId"]
                    let typeStr: String = row["typeStr"]
                    let rawContent: String = row["rawContent"]
                    let docTitle: String = row["docTitle"]
                    let snippet: String = row["highlightedSnippet"]

                    let blockType = BlockType(rawValue: typeStr) ?? .paragraph
                    return SearchResult(
                        blockId: blockId,
                        rootDocId: rootDocId,
                        docTitle: docTitle.isEmpty ? "Untitled Document" : docTitle,
                        blockType: blockType,
                        snippet: snippet.isEmpty ? rawContent : snippet,
                        rawContent: rawContent
                    )
                }
            }
        } catch {
            print("FTS5 search error: \(error)")
            return []
        }
    }
}
