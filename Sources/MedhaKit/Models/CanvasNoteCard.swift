import Foundation
import GRDB

public struct CanvasNoteCard: Identifiable, Codable, FetchableRecord, PersistableRecord, Equatable, Sendable {
    public var id: String             // "card-\(UUID())"
    public var canvasDocId: String    // ID of the canvas / ink document hosting this card
    public var noteDocId: String      // ID of the referenced note document
    public var canvasX: Double        // 2D X coordinate in canvas space
    public var canvasY: Double        // 2D Y coordinate in canvas space
    public var canvasWidth: Double    // Card width (default 320.0)
    public var canvasHeight: Double   // Card height (default 200.0)
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = CanvasNoteCard.generateId(),
        canvasDocId: String,
        noteDocId: String,
        canvasX: Double = 100.0,
        canvasY: Double = 100.0,
        canvasWidth: Double = 320.0,
        canvasHeight: Double = 200.0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.canvasDocId = canvasDocId
        self.noteDocId = noteDocId
        self.canvasX = canvasX
        self.canvasY = canvasY
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func generateId() -> String {
        "card-\(UUID().uuidString.lowercased())"
    }

    public var boundingRect: CGRect {
        CGRect(x: canvasX, y: canvasY, width: canvasWidth, height: canvasHeight)
    }
}

extension CanvasNoteCard {
    public static let databaseTableName = "canvas_note_card"

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let canvasDocId = Column(CodingKeys.canvasDocId)
        public static let noteDocId = Column(CodingKeys.noteDocId)
        public static let canvasX = Column(CodingKeys.canvasX)
        public static let canvasY = Column(CodingKeys.canvasY)
        public static let canvasWidth = Column(CodingKeys.canvasWidth)
        public static let canvasHeight = Column(CodingKeys.canvasHeight)
        public static let createdAt = Column(CodingKeys.createdAt)
        public static let updatedAt = Column(CodingKeys.updatedAt)
    }
}
