import Foundation
import GRDB

// MARK: - Database Model
public struct NotionDatabase: Identifiable, Codable, FetchableRecord, PersistableRecord, Equatable, Sendable {
    public var id: String             // "db-\(UUID())"
    public var rootDocId: String       // Document hosting this database container
    public var title: String           // Name of database
    public var description: String?    // Optional markdown/rich description
    public var icon: String?          // SF symbol or emoji
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = NotionDatabase.generateId(),
        rootDocId: String,
        title: String = "Untitled Database",
        description: String? = nil,
        icon: String? = "tablecells",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.rootDocId = rootDocId
        self.title = title
        self.description = description
        self.icon = icon
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func generateId() -> String {
        "db-\(UUID().uuidString.lowercased())"
    }
}

extension NotionDatabase {
    public static let databaseTableName = "databases"

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let rootDocId = Column(CodingKeys.rootDocId)
        public static let title = Column(CodingKeys.title)
        public static let description = Column(CodingKeys.description)
        public static let icon = Column(CodingKeys.icon)
        public static let createdAt = Column(CodingKeys.createdAt)
        public static let updatedAt = Column(CodingKeys.updatedAt)
    }
}

// MARK: - Property Types Enum (16+ Supported Types)
public enum DatabasePropertyType: String, Codable, CaseIterable, Sendable {
    case title          // Primary record identifier
    case richText       // Multi-line plain/rich text
    case number         // Numeric with formatting options
    case select         // Single categorical badge
    case multiSelect    // Multi categorical badges
    case status         // Workflow state: To-do, In Progress, Complete
    case date           // ISO Date with optional time & range
    case people         // User/assignee attribution
    case files          // Local sandboxed file attachment
    case checkbox       // Boolean toggle
    case url            // Clickable URL
    case email          // Mailto address
    case phone          // Tel phone number
    case relation       // Directed pointer to record in target database
    case rollup         // Aggregation computed over related records
    case uniqueId       // Deterministic prefixed sequence ID (e.g. TASK-42)
    case createdTime    // Automatic creation timestamp
    case lastEditedTime // Automatic edit timestamp

    public var displayName: String {
        switch self {
        case .title: return "Title"
        case .richText: return "Text"
        case .number: return "Number"
        case .select: return "Select"
        case .multiSelect: return "Multi-Select"
        case .status: return "Status"
        case .date: return "Date"
        case .people: return "Person"
        case .files: return "Files & Media"
        case .checkbox: return "Checkbox"
        case .url: return "URL"
        case .email: return "Email"
        case .phone: return "Phone"
        case .relation: return "Relation"
        case .rollup: return "Rollup"
        case .uniqueId: return "ID"
        case .createdTime: return "Created Time"
        case .lastEditedTime: return "Last Edited Time"
        }
    }

    public var systemIcon: String {
        switch self {
        case .title: return "character"
        case .richText: return "text.alignleft"
        case .number: return "number"
        case .select: return "smallcircle.filled.circle"
        case .multiSelect: return "checklist"
        case .status: return "circle.dashed"
        case .date: return "calendar"
        case .people: return "person.crop.circle"
        case .files: return "paperclip"
        case .checkbox: return "checkmark.square"
        case .url: return "link"
        case .email: return "envelope"
        case .phone: return "phone"
        case .relation: return "arrow.triangle.branch"
        case .rollup: return "function"
        case .uniqueId: return "number.square"
        case .createdTime: return "clock"
        case .lastEditedTime: return "clock.arrow.circlepath"
        }
    }
}

// MARK: - Property Config Helper Structs
public struct SelectOption: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var color: String // "blue", "green", "amber", "red", "purple", "gray"

    public init(id: String = UUID().uuidString, name: String, color: String = "blue") {
        self.id = id
        self.name = name
        self.color = color
    }
}

public struct NumberFormatConfig: Codable, Equatable, Sendable {
    public var format: String // "number", "currency_usd", "currency_eur", "percent"
    public var decimalPlaces: Int?

    public init(format: String = "number", decimalPlaces: Int? = nil) {
        self.format = format
        self.decimalPlaces = decimalPlaces
    }
}

public struct RelationConfig: Codable, Equatable, Sendable {
    public var targetDatabaseId: String
    public var isTwoWay: Bool
    public var twoWayPropertyId: String?

    public init(targetDatabaseId: String, isTwoWay: Bool = false, twoWayPropertyId: String? = nil) {
        self.targetDatabaseId = targetDatabaseId
        self.isTwoWay = isTwoWay
        self.twoWayPropertyId = twoWayPropertyId
    }
}

public enum RollupAggregation: String, Codable, CaseIterable, Sendable {
    case sum = "sum"
    case avg = "avg"
    case count = "count"
    case min = "min"
    case max = "max"
    case countValues = "count_values"

    public var displayName: String {
        switch self {
        case .sum: return "Sum"
        case .avg: return "Average"
        case .count: return "Count All"
        case .min: return "Min"
        case .max: return "Max"
        case .countValues: return "Count Values"
        }
    }
}

public struct RollupConfig: Codable, Equatable, Sendable {
    public var relationPropertyId: String
    public var targetPropertyId: String
    public var aggregation: RollupAggregation

    public init(relationPropertyId: String, targetPropertyId: String, aggregation: RollupAggregation = .sum) {
        self.relationPropertyId = relationPropertyId
        self.targetPropertyId = targetPropertyId
        self.aggregation = aggregation
    }
}

public struct UniqueIdConfig: Codable, Equatable, Sendable {
    public var prefix: String // e.g. "TASK-", "ISSUE-"

    public init(prefix: String = "TASK-") {
        self.prefix = prefix
    }
}

public struct DatabasePropertyConfig: Codable, Equatable, Sendable {
    public var selectOptions: [SelectOption]?
    public var numberConfig: NumberFormatConfig?
    public var relationConfig: RelationConfig?
    public var rollupConfig: RollupConfig?
    public var uniqueIdConfig: UniqueIdConfig?

    public init(
        selectOptions: [SelectOption]? = nil,
        numberConfig: NumberFormatConfig? = nil,
        relationConfig: RelationConfig? = nil,
        rollupConfig: RollupConfig? = nil,
        uniqueIdConfig: UniqueIdConfig? = nil
    ) {
        self.selectOptions = selectOptions
        self.numberConfig = numberConfig
        self.relationConfig = relationConfig
        self.rollupConfig = rollupConfig
        self.uniqueIdConfig = uniqueIdConfig
    }

    public func serialize() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func deserialize(from json: String?) -> DatabasePropertyConfig? {
        guard let json = json, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(DatabasePropertyConfig.self, from: data)
    }
}

// MARK: - Database Property Schema
public struct DatabaseProperty: Identifiable, Codable, FetchableRecord, PersistableRecord, Equatable, Sendable {
    public var id: String             // "prop-\(UUID())"
    public var databaseId: String     // Parent database
    public var name: String           // Property name
    public var type: DatabasePropertyType
    public var configJson: String?    // Serialized DatabasePropertyConfig
    public var sortOrder: Int

    public init(
        id: String = DatabaseProperty.generateId(),
        databaseId: String,
        name: String,
        type: DatabasePropertyType,
        configJson: String? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.databaseId = databaseId
        self.name = name
        self.type = type
        self.configJson = configJson
        self.sortOrder = sortOrder
    }

    public static func generateId() -> String {
        "prop-\(UUID().uuidString.lowercased())"
    }

    public var parsedConfig: DatabasePropertyConfig? {
        DatabasePropertyConfig.deserialize(from: configJson)
    }
}

extension DatabaseProperty {
    public static let databaseTableName = "database_properties"

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let databaseId = Column(CodingKeys.databaseId)
        public static let name = Column(CodingKeys.name)
        public static let type = Column(CodingKeys.type)
        public static let configJson = Column(CodingKeys.configJson)
        public static let sortOrder = Column(CodingKeys.sortOrder)
    }
}

// MARK: - Database Record
public struct DatabaseRecord: Identifiable, Codable, FetchableRecord, PersistableRecord, Equatable, Sendable {
    public var id: String             // "rec-\(UUID())"
    public var databaseId: String     // Parent database
    public var docId: String          // Associated Document/Note ID
    public var uniqueSeqNumber: Int?  // Auto-increment sequence for uniqueId
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = DatabaseRecord.generateId(),
        databaseId: String,
        docId: String,
        uniqueSeqNumber: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.databaseId = databaseId
        self.docId = docId
        self.uniqueSeqNumber = uniqueSeqNumber
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func generateId() -> String {
        "rec-\(UUID().uuidString.lowercased())"
    }
}

extension DatabaseRecord {
    public static let databaseTableName = "database_records"

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let databaseId = Column(CodingKeys.databaseId)
        public static let docId = Column(CodingKeys.docId)
        public static let uniqueSeqNumber = Column(CodingKeys.uniqueSeqNumber)
        public static let createdAt = Column(CodingKeys.createdAt)
        public static let updatedAt = Column(CodingKeys.updatedAt)
    }
}

// MARK: - Database Cell Value
public struct DatabaseCellValue: Codable, FetchableRecord, PersistableRecord, Equatable, Sendable {
    public var recordId: String
    public var propertyId: String
    public var valueText: String?
    public var valueNumber: Double?
    public var valueDate: Date?
    public var valueJson: String?

    public init(
        recordId: String,
        propertyId: String,
        valueText: String? = nil,
        valueNumber: Double? = nil,
        valueDate: Date? = nil,
        valueJson: String? = nil
    ) {
        self.recordId = recordId
        self.propertyId = propertyId
        self.valueText = valueText
        self.valueNumber = valueNumber
        self.valueDate = valueDate
        self.valueJson = valueJson
    }
}

extension DatabaseCellValue {
    public static let databaseTableName = "database_cell_values"

    public enum Columns {
        public static let recordId = Column(CodingKeys.recordId)
        public static let propertyId = Column(CodingKeys.propertyId)
        public static let valueText = Column(CodingKeys.valueText)
        public static let valueNumber = Column(CodingKeys.valueNumber)
        public static let valueDate = Column(CodingKeys.valueDate)
        public static let valueJson = Column(CodingKeys.valueJson)
    }
}

// MARK: - Record Relation
public struct RecordRelation: Identifiable, Codable, FetchableRecord, PersistableRecord, Equatable, Sendable {
    public var id: String
    public var fromRecordId: String
    public var toRecordId: String
    public var relationPropertyId: String

    public init(
        id: String = RecordRelation.generateId(),
        fromRecordId: String,
        toRecordId: String,
        relationPropertyId: String
    ) {
        self.id = id
        self.fromRecordId = fromRecordId
        self.toRecordId = toRecordId
        self.relationPropertyId = relationPropertyId
    }

    public static func generateId() -> String {
        "rel-\(UUID().uuidString.lowercased())"
    }
}

extension RecordRelation {
    public static let databaseTableName = "record_relations"

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let fromRecordId = Column(CodingKeys.fromRecordId)
        public static let toRecordId = Column(CodingKeys.toRecordId)
        public static let relationPropertyId = Column(CodingKeys.relationPropertyId)
    }
}

// MARK: - Multi-View Canvas Mode Enum
public enum DatabaseViewMode: String, Codable, CaseIterable, Sendable {
    case table
    case board
    case gallery
    case calendar
    case chart

    public var displayName: String {
        switch self {
        case .table: return "Table"
        case .board: return "Board"
        case .gallery: return "Gallery"
        case .calendar: return "Calendar"
        case .chart: return "Analytics"
        }
    }

    public var systemIcon: String {
        switch self {
        case .table: return "tablecells"
        case .board: return "square.grid.3x2"
        case .gallery: return "square.grid.2x2"
        case .calendar: return "calendar"
        case .chart: return "chart.bar.xaxis"
        }
    }
}

// MARK: - Visual Analytics (Swift Charts Engine)
public enum DatabaseChartType: String, Codable, CaseIterable, Sendable {
    case verticalBar = "vertical_bar"
    case horizontalBar = "horizontal_bar"
    case line = "line"
    case sector = "sector"
    case kpi = "kpi"

    public var displayName: String {
        switch self {
        case .verticalBar: return "Vertical Bar"
        case .horizontalBar: return "Horizontal Bar"
        case .line: return "Line Trend"
        case .sector: return "Donut / Sector"
        case .kpi: return "KPI Metric Card"
        }
    }

    public var systemIcon: String {
        switch self {
        case .verticalBar: return "chart.bar.fill"
        case .horizontalBar: return "chart.bar.xaxis"
        case .line: return "chart.xyaxis.line"
        case .sector: return "chart.pie.fill"
        case .kpi: return "number.square.fill"
        }
    }
}

public struct ChartDataPoint: Identifiable, Equatable, Sendable {
    public var id: String { category }
    public var category: String
    public var value: Double
    public var colorName: String?

    public init(category: String, value: Double, colorName: String? = nil) {
        self.category = category
        self.value = value
        self.colorName = colorName
    }
}

// MARK: - Database Automations & Buttons
public enum AutomationTriggerType: String, Codable, CaseIterable, Sendable {
    case recordCreated
    case statusChanged
    case buttonClicked
}

public enum AutomationActionType: String, Codable, CaseIterable, Sendable {
    case updateProperty
    case markComplete
    case setDateFieldToNow
}

public struct DatabaseAutomationRule: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var databaseId: String
    public var name: String
    public var triggerType: AutomationTriggerType
    public var triggerPropertyId: String?
    public var triggerValueText: String?
    public var actionType: AutomationActionType
    public var targetPropertyId: String?
    public var targetValueText: String?
    public var targetValueNumber: Double?

    public init(
        id: String = "auto-\(UUID().uuidString.lowercased())",
        databaseId: String,
        name: String,
        triggerType: AutomationTriggerType,
        triggerPropertyId: String? = nil,
        triggerValueText: String? = nil,
        actionType: AutomationActionType,
        targetPropertyId: String? = nil,
        targetValueText: String? = nil,
        targetValueNumber: Double? = nil
    ) {
        self.id = id
        self.databaseId = databaseId
        self.name = name
        self.triggerType = triggerType
        self.triggerPropertyId = triggerPropertyId
        self.triggerValueText = triggerValueText
        self.actionType = actionType
        self.targetPropertyId = targetPropertyId
        self.targetValueText = targetValueText
        self.targetValueNumber = targetValueNumber
    }
}


