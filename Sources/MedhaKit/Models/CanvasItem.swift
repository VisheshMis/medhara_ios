import Foundation
import CoreGraphics
import GRDB

public enum CanvasItemType: String, Codable, Sendable, CaseIterable {
    case shape
    case mediaImage
    case mediaVideo
    case mediaAudio
    case mediaPDF
    case textBlock
    case noteCard
}

public enum CanvasShapeType: String, Codable, Sendable, CaseIterable {
    case rectangle
    case roundedRectangle
    case diamond
    case ellipse
    case group
}

public enum CanvasPortPosition: String, Codable, Sendable, CaseIterable {
    case top
    case right
    case bottom
    case left

    public var normalVector: CGVector {
        switch self {
        case .top: return CGVector(dx: 0, dy: -1)
        case .right: return CGVector(dx: 1, dy: 0)
        case .bottom: return CGVector(dx: 0, dy: 1)
        case .left: return CGVector(dx: -1, dy: 0)
        }
    }
}

public struct CanvasItem: Identifiable, Codable, FetchableRecord, PersistableRecord, Equatable, Sendable {
    public var id: String
    public var canvasDocId: String
    public var itemType: CanvasItemType
    public var linkedNoteDocId: String?
    public var shapeType: CanvasShapeType?
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var rotationDegrees: Double
    public var zIndex: Int
    public var fillColorHex: String?
    public var strokeColorHex: String?
    public var strokeWidth: Double
    public var cornerRadius: Double
    public var title: String?
    public var summarySnippet: String?
    public var markdownContent: String?
    public var mediaAssetKey: String?
    public var metadataJson: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = CanvasItem.generateId(),
        canvasDocId: String,
        itemType: CanvasItemType,
        linkedNoteDocId: String? = nil,
        shapeType: CanvasShapeType? = nil,
        x: Double = 100.0,
        y: Double = 100.0,
        width: Double = 220.0,
        height: Double = 140.0,
        rotationDegrees: Double = 0.0,
        zIndex: Int = 0,
        fillColorHex: String? = nil,
        strokeColorHex: String? = nil,
        strokeWidth: Double = 1.5,
        cornerRadius: Double = 8.0,
        title: String? = nil,
        summarySnippet: String? = nil,
        markdownContent: String? = nil,
        mediaAssetKey: String? = nil,
        metadataJson: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.canvasDocId = canvasDocId
        self.itemType = itemType
        self.linkedNoteDocId = linkedNoteDocId
        self.shapeType = shapeType
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.rotationDegrees = rotationDegrees
        self.zIndex = zIndex
        self.fillColorHex = fillColorHex
        self.strokeColorHex = strokeColorHex
        self.strokeWidth = strokeWidth
        self.cornerRadius = cornerRadius
        self.title = title
        self.summarySnippet = summarySnippet
        self.markdownContent = markdownContent
        self.mediaAssetKey = mediaAssetKey
        self.metadataJson = metadataJson
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func generateId() -> String {
        "ci-\(UUID().uuidString.lowercased())"
    }

    public var boundingRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    /// Computes the absolute CGPoint on the canvas for a magnetic snap port
    public func portPoint(for port: CanvasPortPosition) -> CGPoint {
        switch port {
        case .top:
            return CGPoint(x: x + width / 2.0, y: y)
        case .right:
            return CGPoint(x: x + width, y: y + height / 2.0)
        case .bottom:
            return CGPoint(x: x + width / 2.0, y: y + height)
        case .left:
            return CGPoint(x: x, y: y + height / 2.0)
        }
    }

    /// Finds the closest snap port on this item to a given canvas coordinate
    public func closestPort(to point: CGPoint) -> (port: CanvasPortPosition, point: CGPoint, distance: CGFloat) {
        var closest = CanvasPortPosition.top
        var closestPt = portPoint(for: .top)
        var minDistance = hypot(point.x - closestPt.x, point.y - closestPt.y)

        for port in [CanvasPortPosition.right, .bottom, .left] {
            let pt = portPoint(for: port)
            let d = hypot(point.x - pt.x, point.y - pt.y)
            if d < minDistance {
                minDistance = d
                closest = port
                closestPt = pt
            }
        }
        return (closest, closestPt, minDistance)
    }
}

extension CanvasItem {
    public static let databaseTableName = "canvas_items"

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let canvasDocId = Column(CodingKeys.canvasDocId)
        public static let itemType = Column(CodingKeys.itemType)
        public static let linkedNoteDocId = Column(CodingKeys.linkedNoteDocId)
        public static let shapeType = Column(CodingKeys.shapeType)
        public static let x = Column(CodingKeys.x)
        public static let y = Column(CodingKeys.y)
        public static let width = Column(CodingKeys.width)
        public static let height = Column(CodingKeys.height)
        public static let rotationDegrees = Column(CodingKeys.rotationDegrees)
        public static let zIndex = Column(CodingKeys.zIndex)
        public static let fillColorHex = Column(CodingKeys.fillColorHex)
        public static let strokeColorHex = Column(CodingKeys.strokeColorHex)
        public static let strokeWidth = Column(CodingKeys.strokeWidth)
        public static let cornerRadius = Column(CodingKeys.cornerRadius)
        public static let title = Column(CodingKeys.title)
        public static let summarySnippet = Column(CodingKeys.summarySnippet)
        public static let markdownContent = Column(CodingKeys.markdownContent)
        public static let mediaAssetKey = Column(CodingKeys.mediaAssetKey)
        public static let metadataJson = Column(CodingKeys.metadataJson)
        public static let createdAt = Column(CodingKeys.createdAt)
        public static let updatedAt = Column(CodingKeys.updatedAt)
    }
}

public enum CanvasUndoCommand: Equatable, Sendable {
    case itemAdded(item: CanvasItem)
    case itemDeleted(item: CanvasItem)
    case itemMoved(id: String, oldX: Double, oldY: Double, newX: Double, newY: Double)
    case itemResized(id: String, oldWidth: Double, oldHeight: Double, newWidth: Double, newHeight: Double)
}
