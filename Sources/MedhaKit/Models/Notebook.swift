import Foundation
import GRDB

public struct Notebook: Identifiable, Codable, FetchableRecord, PersistableRecord, Equatable, Sendable {
    public var id: String
    public var name: String
    public var icon: String?
    public var sortOrder: Int

    public init(
        id: String = Notebook.generateId(),
        name: String,
        icon: String? = "book.closed.fill",
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.sortOrder = sortOrder
    }

    public static func generateId() -> String {
        "nb-\(UUID().uuidString.lowercased())"
    }
}

extension Notebook {
    public static let databaseTableName = "notebook"

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let name = Column(CodingKeys.name)
        public static let icon = Column(CodingKeys.icon)
        public static let sortOrder = Column(CodingKeys.sortOrder)
    }
}
