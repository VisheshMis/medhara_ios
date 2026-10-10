import Foundation
import CoreGraphics
import GRDB

public enum ConnectorRoutingType: String, Codable, Sendable, CaseIterable {
    case orthogonal
    case curved
    case straight
}

public enum ConnectorArrowType: String, Codable, Sendable, CaseIterable {
    case none
    case endArrow
    case bothArrows
}

public struct CanvasConnector: Identifiable, Codable, FetchableRecord, PersistableRecord, Equatable, Sendable {
    public var id: String
    public var canvasDocId: String
    public var fromItemId: String
    public var fromPort: CanvasPortPosition
    public var toItemId: String
    public var toPort: CanvasPortPosition
    public var routingType: ConnectorRoutingType
    public var label: String?
    public var strokeColorHex: String
    public var strokeWidth: Double
    public var arrowType: ConnectorArrowType
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = CanvasConnector.generateId(),
        canvasDocId: String,
        fromItemId: String,
        fromPort: CanvasPortPosition = .right,
        toItemId: String,
        toPort: CanvasPortPosition = .left,
        routingType: ConnectorRoutingType = .orthogonal,
        label: String? = nil,
        strokeColorHex: String = "#64748B",
        strokeWidth: Double = 2.0,
        arrowType: ConnectorArrowType = .endArrow,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.canvasDocId = canvasDocId
        self.fromItemId = fromItemId
        self.fromPort = fromPort
        self.toItemId = toItemId
        self.toPort = toPort
        self.routingType = routingType
        self.label = label
        self.strokeColorHex = strokeColorHex
        self.strokeWidth = strokeWidth
        self.arrowType = arrowType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func generateId() -> String {
        "cc-\(UUID().uuidString.lowercased())"
    }
}

extension CanvasConnector {
    public static let databaseTableName = "canvas_connectors"

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let canvasDocId = Column(CodingKeys.canvasDocId)
        public static let fromItemId = Column(CodingKeys.fromItemId)
        public static let fromPort = Column(CodingKeys.fromPort)
        public static let toItemId = Column(CodingKeys.toItemId)
        public static let toPort = Column(CodingKeys.toPort)
        public static let routingType = Column(CodingKeys.routingType)
        public static let label = Column(CodingKeys.label)
        public static let strokeColorHex = Column(CodingKeys.strokeColorHex)
        public static let strokeWidth = Column(CodingKeys.strokeWidth)
        public static let arrowType = Column(CodingKeys.arrowType)
        public static let createdAt = Column(CodingKeys.createdAt)
        public static let updatedAt = Column(CodingKeys.updatedAt)
    }
}
