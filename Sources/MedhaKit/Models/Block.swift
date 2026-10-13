import Foundation
import SwiftUI
import AppKit
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
    case subPage
    case columnList
    case column
    case mathEquation
    case subjectCard
    case calendarEmbed

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
        case .subPage: return "Sub-page"
        case .columnList: return "2 Columns"
        case .column: return "Column"
        case .mathEquation: return "Math Equation"
        case .subjectCard: return "Subject Box"
        case .calendarEmbed: return "Google Calendar Hub"
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
        case .subPage: return "doc.badge.plus"
        case .columnList: return "rectangle.split.2x1"
        case .column: return "rectangle.portrait"
        case .mathEquation: return "function"
        case .subjectCard: return "graduationcap.fill"
        case .calendarEmbed: return "calendar.badge.clock"
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
        case .subPage: return "Sub-page title..."
        case .columnList: return ""
        case .column: return ""
        case .mathEquation: return "E = mc^2"
        case .subjectCard: return "Subject Title..."
        case .calendarEmbed: return ""
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

public struct SubjectCardLink: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var targetDocId: String?
    public var icon: String

    public init(id: String = UUID().uuidString, title: String, targetDocId: String? = nil, icon: String = "doc.text") {
        self.id = id
        self.title = title
        self.targetDocId = targetDocId
        self.icon = icon
    }
}

public struct SubjectCardPayload: Codable, Equatable, Sendable {
    public var subjectName: String
    public var courseCode: String
    public var instructor: String
    public var scheduleRoom: String
    public var status: String // "Active", "Completed", "Upcoming"
    public var colorTheme: String // "green", "purple", "blue", "orange", "pink"
    public var bannerUrl: String?
    public var linkedDocId: String?
    public var quickLinks: [SubjectCardLink]

    public init(
        subjectName: String = "Subject / Course",
        courseCode: String = "CS 101",
        instructor: String = "Prof. Smith",
        scheduleRoom: String = "MWF 10:00 AM • Hall B",
        status: String = "Active",
        colorTheme: String = "blue",
        bannerUrl: String? = nil,
        linkedDocId: String? = nil,
        quickLinks: [SubjectCardLink] = [
            SubjectCardLink(title: "Lectures & Notes", icon: "book.fill"),
            SubjectCardLink(title: "Assignments & Labs", icon: "checklist"),
            SubjectCardLink(title: "Exam Prep & Flashcards", icon: "brain.head.profile")
        ]
    ) {
        self.subjectName = subjectName
        self.courseCode = courseCode
        self.instructor = instructor
        self.scheduleRoom = scheduleRoom
        self.status = status
        self.colorTheme = colorTheme
        self.bannerUrl = bannerUrl
        self.linkedDocId = linkedDocId
        self.quickLinks = quickLinks
    }

    public func serialize() -> String {
        if let data = try? JSONEncoder().encode(self), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return ""
    }

    public static func deserialize(from json: String) -> SubjectCardPayload {
        guard let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(SubjectCardPayload.self, from: data) else {
            return SubjectCardPayload()
        }
        return payload
    }
}

public struct StudyCalendarEvent: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var dateString: String // YYYY-MM-DD
    public var timeString: String // e.g. "10:00 AM"
    public var tag: String // "Exam", "Lecture", "Assignment", "Study"
    public var isCompleted: Bool

    public init(
        id: String = UUID().uuidString,
        title: String,
        dateString: String,
        timeString: String = "10:00 AM",
        tag: String = "Study",
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.dateString = dateString
        self.timeString = timeString
        self.tag = tag
        self.isCompleted = isCompleted
    }
}

public struct CalendarEmbedPayload: Codable, Equatable, Sendable {
    public var googleCalendarUrl: String?
    public var calendarTitle: String
    public var events: [StudyCalendarEvent]

    public init(
        googleCalendarUrl: String? = nil,
        calendarTitle: String = "Academic & Study Calendar",
        events: [StudyCalendarEvent] = [
            StudyCalendarEvent(title: "Linear Algebra Midterm", dateString: "2026-10-20", tag: "Exam"),
            StudyCalendarEvent(title: "Operating Systems Lab Due", dateString: "2026-10-24", tag: "Assignment"),
            StudyCalendarEvent(title: "Deep Learning Study Session", dateString: "2026-10-26", tag: "Study")
        ]
    ) {
        self.googleCalendarUrl = googleCalendarUrl
        self.calendarTitle = calendarTitle
        self.events = events
    }

    public func serialize() -> String {
        if let data = try? JSONEncoder().encode(self), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return ""
    }

    public static func deserialize(from json: String) -> CalendarEmbedPayload {
        guard let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(CalendarEmbedPayload.self, from: data) else {
            return CalendarEmbedPayload()
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
    public var coverUrl: String?     // Cover image URL or local cached file path
    public var coverY: Double?       // Vertical reposition offset (0.0 ... 1.0)
    public var subPageDocId: String? // Target document ID if this is a sub-page block
    public var columnRatio: Double?  // Width ratio if inside a column layout

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
        pinnedPropertiesData: String? = nil,
        coverUrl: String? = nil,
        coverY: Double? = nil,
        subPageDocId: String? = nil,
        columnRatio: Double? = nil
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
        self.coverUrl = coverUrl
        self.coverY = coverY
        self.subPageDocId = subPageDocId
        self.columnRatio = columnRatio
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

    public var subjectCardPayload: SubjectCardPayload? {
        guard type == .subjectCard else { return nil }
        return SubjectCardPayload.deserialize(from: content)
    }

    public var calendarEmbedPayload: CalendarEmbedPayload? {
        guard type == .calendarEmbed else { return nil }
        return CalendarEmbedPayload.deserialize(from: content)
    }

    public var resolvedTextColor: NSColor {
        guard let tint = colorTint?.lowercased(), !tint.hasPrefix("bg-") else {
            return .labelColor
        }
        switch tint {
        case "gray": return NSColor(calibratedRed: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)
        case "brown": return NSColor(calibratedRed: 0.62, green: 0.42, blue: 0.33, alpha: 1.0)
        case "orange": return NSColor(calibratedRed: 0.85, green: 0.45, blue: 0.05, alpha: 1.0)
        case "yellow": return NSColor(calibratedRed: 0.80, green: 0.57, blue: 0.18, alpha: 1.0)
        case "green": return NSColor(calibratedRed: 0.27, green: 0.51, blue: 0.38, alpha: 1.0)
        case "blue": return NSColor(calibratedRed: 0.20, green: 0.49, blue: 0.66, alpha: 1.0)
        case "purple": return NSColor(calibratedRed: 0.56, green: 0.40, blue: 0.69, alpha: 1.0)
        case "pink": return NSColor(calibratedRed: 0.76, green: 0.30, blue: 0.54, alpha: 1.0)
        case "red": return NSColor(calibratedRed: 0.83, green: 0.30, blue: 0.28, alpha: 1.0)
        default: return .labelColor
        }
    }

    public var resolvedBgColor: Color? {
        guard let tint = colorTint?.lowercased(), tint.hasPrefix("bg-") else {
            return nil
        }
        let clean = String(tint.dropFirst(3))
        switch clean {
        case "gray": return Color(red: 0.5, green: 0.5, blue: 0.5).opacity(0.18)
        case "brown": return Color(red: 0.62, green: 0.42, blue: 0.33).opacity(0.18)
        case "orange": return Color(red: 0.85, green: 0.45, blue: 0.05).opacity(0.18)
        case "yellow": return Color(red: 0.80, green: 0.57, blue: 0.18).opacity(0.18)
        case "green": return Color(red: 0.27, green: 0.51, blue: 0.38).opacity(0.18)
        case "blue": return Color(red: 0.20, green: 0.49, blue: 0.66).opacity(0.18)
        case "purple": return Color(red: 0.56, green: 0.40, blue: 0.69).opacity(0.18)
        case "pink": return Color(red: 0.76, green: 0.30, blue: 0.54).opacity(0.18)
        case "red": return Color(red: 0.83, green: 0.30, blue: 0.28).opacity(0.18)
        default: return nil
        }
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
        public static let coverUrl = Column(CodingKeys.coverUrl)
        public static let coverY = Column(CodingKeys.coverY)
        public static let subPageDocId = Column(CodingKeys.subPageDocId)
        public static let columnRatio = Column(CodingKeys.columnRatio)
    }
}
