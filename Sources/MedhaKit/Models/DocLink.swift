import Foundation
import GRDB

public struct DocLink: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    public var id: String
    public var sourceDocId: String
    public var sourceBlockId: String
    public var targetTitle: String
    public var targetDocId: String? // nil if unresolved
    public var createdAt: Date

    public init(
        id: String = "dl-\(UUID().uuidString.lowercased())",
        sourceDocId: String,
        sourceBlockId: String,
        targetTitle: String,
        targetDocId: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceDocId = sourceDocId
        self.sourceBlockId = sourceBlockId
        self.targetTitle = targetTitle
        self.targetDocId = targetDocId
        self.createdAt = createdAt
    }

    public var isResolved: Bool {
        targetDocId != nil
    }

    public static let databaseTableName = "doc_link"

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let sourceDocId = Column(CodingKeys.sourceDocId)
        public static let sourceBlockId = Column(CodingKeys.sourceBlockId)
        public static let targetTitle = Column(CodingKeys.targetTitle)
        public static let targetDocId = Column(CodingKeys.targetDocId)
        public static let createdAt = Column(CodingKeys.createdAt)
    }
}
