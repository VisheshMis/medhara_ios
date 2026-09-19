import Foundation
import GRDB

public enum BlockType: String, Codable, CaseIterable, Sendable {
    case doc
    case heading1
    case heading2
    case heading3
    case paragraph
    case bulletList
    case taskList
    case codeBlock
    case quote
    case callout
    case blockRef

    public var displayName: String {
        switch self {
        case .doc: return "Document"
        case .heading1: return "Heading 1"
        case .heading2: return "Heading 2"
        case .heading3: return "Heading 3"
        case .paragraph: return "Paragraph"
        case .bulletList: return "Bullet List"
        case .taskList: return "To-Do List"
        case .codeBlock: return "Code Block"
        case .quote: return "Quote"
        case .callout: return "Callout"
        case .blockRef: return "Block Reference"
        }
    }

    public var systemIcon: String {
        switch self {
        case .doc: return "doc.text"
        case .heading1: return "textformat.size.larger"
        case .heading2: return "textformat.size"
        case .heading3: return "textformat.size.smaller"
        case .paragraph: return "paragraph"
        case .bulletList: return "list.bullet"
        case .taskList: return "checkmark.square"
        case .codeBlock: return "curlybraces"
        case .quote: return "quote.opening"
        case .callout: return "lightbulb.fill"
        case .blockRef: return "link"
        }
    }

    public var placeholder: String {
        switch self {
        case .doc: return "Document Title..."
        case .heading1: return "Heading 1"
        case .heading2: return "Heading 2"
        case .heading3: return "Heading 3"
        case .paragraph: return "Type '/' for commands or (( for block reference..."
        case .bulletList: return "List item..."
        case .taskList: return "To-do task..."
        case .codeBlock: return "// Enter code here..."
        case .quote: return "Quote..."
        case .callout: return "Callout note..."
        case .blockRef: return "Select a block to reference..."
        }
    }
}

public struct Block: Identifiable, Codable, FetchableRecord, PersistableRecord, Equatable, Sendable {
    public var id: String            // Stable UUID: "b-\(UUID().uuidString)"
    public var rootDocId: String     // ID of document block
    public var parentId: String?     // Parent block (for indentation / nesting)
    public var type: BlockType
    public var content: String       // Plain text / markdown snippet
    public var sortOrder: Int        // Ordering in parent/document
    public var isCompleted: Bool?    // For task items
    public var refTargetId: String?  // Target block ID if this is a block reference/embed
    public var createdAt: Date
    public var updatedAt: Date
    public var notebookId: String?   // Optional notebook ID (for root docs)

    public init(
        id: String = Block.generateId(),
        rootDocId: String,
        parentId: String? = nil,
        type: BlockType = .paragraph,
        content: String = "",
        sortOrder: Int = 0,
        isCompleted: Bool? = nil,
        refTargetId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        notebookId: String? = nil
    ) {
        self.id = id
        self.rootDocId = rootDocId
        self.parentId = parentId
        self.type = type
        self.content = content
        self.sortOrder = sortOrder
        self.isCompleted = isCompleted
        self.refTargetId = refTargetId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.notebookId = notebookId
    }

    public static func generateId() -> String {
        "b-\(UUID().uuidString.lowercased())"
    }

    public var isDocument: Bool {
        type == .doc
    }

    public var isHeading: Bool {
        type == .heading1 || type == .heading2 || type == .heading3
    }
}

// GRDB Table definition
extension Block {
    public static let databaseTableName = "block"

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let rootDocId = Column(CodingKeys.rootDocId)
        public static let parentId = Column(CodingKeys.parentId)
        public static let type = Column(CodingKeys.type)
        public static let content = Column(CodingKeys.content)
        public static let sortOrder = Column(CodingKeys.sortOrder)
        public static let isCompleted = Column(CodingKeys.isCompleted)
        public static let refTargetId = Column(CodingKeys.refTargetId)
        public static let createdAt = Column(CodingKeys.createdAt)
        public static let updatedAt = Column(CodingKeys.updatedAt)
        public static let notebookId = Column(CodingKeys.notebookId)
    }
}
