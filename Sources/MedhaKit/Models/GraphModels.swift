import Foundation
import SwiftUI

public enum GraphEdgeType: String, Codable, Sendable {
    case linksTo = "links_to"
    case contains = "contains"
}

public struct GraphNode: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let isCurrentDoc: Bool
    public let isUnresolved: Bool
    public let parentId: String?
    public let topLevelAncestorId: String?
    public let tags: [String]
    public let blockCount: Int
    public let inDegree: Int
    public let outDegree: Int

    public var degree: Int {
        inDegree + outDegree
    }

    public var radius: CGFloat {
        if isUnresolved {
            return 5.5
        }
        let base: CGFloat = 6.0
        let deg = CGFloat(max(1, degree))
        let scaled = base + sqrt(deg) * 3.2
        return min(26.0, max(6.0, scaled))
    }

    public init(
        id: String,
        title: String,
        isCurrentDoc: Bool = false,
        isUnresolved: Bool = false,
        parentId: String? = nil,
        topLevelAncestorId: String? = nil,
        tags: [String] = [],
        blockCount: Int = 1,
        inDegree: Int = 0,
        outDegree: Int = 0
    ) {
        self.id = id
        self.title = title
        self.isCurrentDoc = isCurrentDoc
        self.isUnresolved = isUnresolved
        self.parentId = parentId
        self.topLevelAncestorId = topLevelAncestorId
        self.tags = tags
        self.blockCount = blockCount
        self.inDegree = inDegree
        self.outDegree = outDegree
    }
}

public struct GraphEdge: Identifiable, Equatable, Hashable, Sendable {
    public var id: String { "\(sourceId)->\(targetId):\(type.rawValue)" }
    public let sourceId: String
    public let targetId: String
    public let type: GraphEdgeType
    public let isInboundToActive: Bool
    public let isOutboundFromActive: Bool

    public init(
        sourceId: String,
        targetId: String,
        type: GraphEdgeType = .linksTo,
        isInboundToActive: Bool = false,
        isOutboundFromActive: Bool = false
    ) {
        self.sourceId = sourceId
        self.targetId = targetId
        self.type = type
        self.isInboundToActive = isInboundToActive
        self.isOutboundFromActive = isOutboundFromActive
    }
}

public enum GraphViewPreset: String, CaseIterable, Identifiable, Sendable {
    case links = "Links"
    case tree = "Tree"
    case blended = "Blended"

    public var id: String { rawValue }
}

public enum GraphFilterAction: String, CaseIterable, Identifiable, Sendable {
    case dim = "Dim"
    case hide = "Hide"

    public var id: String { rawValue }
}

public struct GraphFilterConfig: Equatable, Sendable {
    public var showLinks: Bool
    public var showContains: Bool
    public var showUnresolved: Bool
    public var showOrphans: Bool
    public var filterText: String
    public var filterAction: GraphFilterAction

    public init(
        showLinks: Bool = true,
        showContains: Bool = false,
        showUnresolved: Bool = true,
        showOrphans: Bool = false,
        filterText: String = "",
        filterAction: GraphFilterAction = .dim
    ) {
        self.showLinks = showLinks
        self.showContains = showContains
        self.showUnresolved = showUnresolved
        self.showOrphans = showOrphans
        self.filterText = filterText
        self.filterAction = filterAction
    }
}

public enum GraphGroupRuleType: Equatable, Hashable, Sendable {
    case topLevelAncestor
    case tag(String)
    case searchQuery(String)
}

public struct GraphGroupRule: Identifiable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var ruleType: GraphGroupRuleType
    public var hexColor: String

    public init(
        id: UUID = UUID(),
        name: String,
        ruleType: GraphGroupRuleType,
        hexColor: String
    ) {
        self.id = id
        self.name = name
        self.ruleType = ruleType
        self.hexColor = hexColor
    }
}

public struct GraphPhysicsConfig: Equatable, Sendable {
    public var repelForce: Double
    public var linkForce: Double
    public var linkDistance: Double
    public var centerGravity: Double
    public var isFrozen: Bool

    public static let defaultRepelForce: Double = -360.0
    public static let defaultLinkForce: Double = 0.08
    public static let defaultLinkDistance: Double = 75.0
    public static let defaultCenterGravity: Double = 0.04

    public init(
        repelForce: Double = defaultRepelForce,
        linkForce: Double = defaultLinkForce,
        linkDistance: Double = defaultLinkDistance,
        centerGravity: Double = defaultCenterGravity,
        isFrozen: Bool = false
    ) {
        self.repelForce = repelForce
        self.linkForce = linkForce
        self.linkDistance = linkDistance
        self.centerGravity = centerGravity
        self.isFrozen = isFrozen
    }

    public static func load() -> GraphPhysicsConfig {
        let defaults = UserDefaults.standard
        let repel = defaults.object(forKey: "medha.graph.repelForce") as? Double ?? defaultRepelForce
        let linkF = defaults.object(forKey: "medha.graph.linkForce") as? Double ?? defaultLinkForce
        let linkD = defaults.object(forKey: "medha.graph.linkDistance") as? Double ?? defaultLinkDistance
        let gravity = defaults.object(forKey: "medha.graph.centerGravity") as? Double ?? defaultCenterGravity
        return GraphPhysicsConfig(
            repelForce: repel,
            linkForce: linkF,
            linkDistance: linkD,
            centerGravity: gravity,
            isFrozen: false
        )
    }

    public func save() {
        let defaults = UserDefaults.standard
        defaults.set(repelForce, forKey: "medha.graph.repelForce")
        defaults.set(linkForce, forKey: "medha.graph.linkForce")
        defaults.set(linkDistance, forKey: "medha.graph.linkDistance")
        defaults.set(centerGravity, forKey: "medha.graph.centerGravity")
    }
}

public extension Color {
    init(hexString: String) {
        let clean = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch clean.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 230, 118) // Default neon green
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

