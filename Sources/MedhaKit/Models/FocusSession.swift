import Foundation
import GRDB

public struct FocusSession: Identifiable, Codable, FetchableRecord, PersistableRecord, TableRecord, Sendable {
    public static let databaseTableName = "focus_session"

    public var id: String
    public var durationSeconds: Int      // Planned duration in seconds
    public var focusedSeconds: Int       // Actual focused seconds elapsed
    public var phase: String             // "focus", "shortBreak", "longBreak", etc.
    public var docId: String?            // Optional document being studied
    public var createdAt: Date
    public var completedAt: Date?
    public var isCompleted: Bool

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let durationSeconds = Column(CodingKeys.durationSeconds)
        public static let focusedSeconds = Column(CodingKeys.focusedSeconds)
        public static let phase = Column(CodingKeys.phase)
        public static let docId = Column(CodingKeys.docId)
        public static let createdAt = Column(CodingKeys.createdAt)
        public static let completedAt = Column(CodingKeys.completedAt)
        public static let isCompleted = Column(CodingKeys.isCompleted)
    }

    public init(
        id: String = UUID().uuidString,
        durationSeconds: Int,
        focusedSeconds: Int,
        phase: String = "focus",
        docId: String? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.durationSeconds = durationSeconds
        self.focusedSeconds = focusedSeconds
        self.phase = phase
        self.docId = docId
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.isCompleted = isCompleted
    }
}
