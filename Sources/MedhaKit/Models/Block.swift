import Foundation
import GRDB

public enum BlockType: String, Codable, CaseIterable, Sendable {
    case doc
    case inkDoc
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
    case toggle
    case table

    public var displayName: String {
        switch self {
        case .doc: return "Document"
        case .inkDoc: return "Handwritten Note"
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
        case .toggle: return "Toggle List"
        case .table: return "Table"
        }
    }

    public var systemIcon: String {
        switch self {
        case .doc: return "doc.text"
        case .inkDoc: return "pencil.tip"
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
        case .toggle: return "chevron.right"
        case .table: return "tablecells"
        }
    }

    public var placeholder: String {
        switch self {
        case .doc: return "Document Title..."
        case .inkDoc: return "Handwritten Note Title..."
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
        case .toggle: return "Toggle section..."
        case .table: return ""
        }
    }
}

public struct TableBlockPayload: Codable, Equatable, Sendable {
    public var rows: [[String]]
    public var hasHeaderRow: Bool
    public var hasHeaderCol: Bool

    public init(
        rows: [[String]] = [["", ""], ["", ""]],
        hasHeaderRow: Bool = true,
        hasHeaderCol: Bool = false
    ) {
        self.rows = rows
        self.hasHeaderRow = hasHeaderRow
        self.hasHeaderCol = hasHeaderCol
    }

    public static func defaultTable() -> TableBlockPayload {
        TableBlockPayload(
            rows: [
                ["Header 1", "Header 2", "Header 3"],
                ["", "", ""],
                ["", "", ""]
            ],
            hasHeaderRow: true,
            hasHeaderCol: false
        )
    }

    public func serialize() -> String {
        if let data = try? JSONEncoder().encode(self), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return ""
    }

    public static func deserialize(from json: String) -> TableBlockPayload {
        guard let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(TableBlockPayload.self, from: data) else {
            return .defaultTable()
        }
        return payload
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
    public var canvasMode: InkCanvasMode? // Optional canvas mode for .inkDoc (defaults to .a4Pages)
    
    // Notion Tier 1 & 2 Extensions
    public var isCollapsed: Bool?    // For toggles and folded headings
    public var icon: String?         // Custom icon / emoji
    public var colorTint: String?    // Accent color tint name or hex
    public var verifiedAt: Date?     // When verification was granted
    public var verifiedExpiresAt: Date? // When verification expires
    public var verifiedBy: String?   // Who certified this note
    public var isLocked: Bool?       // Egress read-only protection
    public var pinnedPropertiesData: String? // JSON metadata for pinned chips

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
        notebookId: String? = nil,
        canvasMode: InkCanvasMode? = nil,
        isCollapsed: Bool? = nil,
        icon: String? = nil,
        colorTint: String? = nil,
        verifiedAt: Date? = nil,
        verifiedExpiresAt: Date? = nil,
        verifiedBy: String? = nil,
        isLocked: Bool? = nil,
        pinnedPropertiesData: String? = nil
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
        self.canvasMode = canvasMode
        self.isCollapsed = isCollapsed
        self.icon = icon
        self.colorTint = colorTint
        self.verifiedAt = verifiedAt
        self.verifiedExpiresAt = verifiedExpiresAt
        self.verifiedBy = verifiedBy
        self.isLocked = isLocked
        self.pinnedPropertiesData = pinnedPropertiesData
    }

    public static func generateId() -> String {
        "b-\(UUID().uuidString.lowercased())"
    }

    public var isDocument: Bool {
        type == .doc || type == .inkDoc
    }

    public var isInkDocument: Bool {
        type == .inkDoc
    }

    public var isHeading: Bool {
        type == .heading1 || type == .heading2 || type == .heading3
    }

    public var resolvedCanvasMode: InkCanvasMode {
        canvasMode ?? .a4Pages
    }

    public var isVerified: Bool {
        guard let expires = verifiedExpiresAt else { return false }
        return expires > Date()
    }

    public var verificationDaysRemaining: Int {
        guard let expires = verifiedExpiresAt else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expires).day ?? 0
        return max(0, days)
    }

    public var tablePayload: TableBlockPayload? {
        guard type == .table else { return nil }
        return TableBlockPayload.deserialize(from: content)
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
        public static let canvasMode = Column(CodingKeys.canvasMode)
        public static let isCollapsed = Column(CodingKeys.isCollapsed)
        public static let icon = Column(CodingKeys.icon)
        public static let colorTint = Column(CodingKeys.colorTint)
        public static let verifiedAt = Column(CodingKeys.verifiedAt)
        public static let verifiedExpiresAt = Column(CodingKeys.verifiedExpiresAt)
        public static let verifiedBy = Column(CodingKeys.verifiedBy)
        public static let isLocked = Column(CodingKeys.isLocked)
        public static let pinnedPropertiesData = Column(CodingKeys.pinnedPropertiesData)
    }
}
