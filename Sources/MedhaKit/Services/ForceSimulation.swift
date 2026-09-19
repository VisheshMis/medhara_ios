import Foundation
import CoreGraphics
import SwiftUI

public final class ForceSimulationNode: Identifiable, @unchecked Sendable {
    public let id: String
    public var x: Double
    public var y: Double
    public var vx: Double = 0.0
    public var vy: Double = 0.0
    public var isPinned: Bool = false
    public var radius: Double

    public init(id: String, x: Double, y: Double, radius: Double = 10.0, isPinned: Bool = false) {
        self.id = id
        self.x = x
        self.y = y
        self.radius = radius
        self.isPinned = isPinned
    }

    public var point: CGPoint {
        CGPoint(x: x, y: y)
    }
}

public struct ForceSimulationEdge: Sendable {
    public let sourceId: String
    public let targetId: String
    public let type: GraphEdgeType

    public init(sourceId: String, targetId: String, type: GraphEdgeType = .linksTo) {
        self.sourceId = sourceId
        self.targetId = targetId
        self.type = type
    }
}

@MainActor
public final class ForceSimulation: ObservableObject {
    @Published public private(set) var nodes: [String: ForceSimulationNode] = [:]
    @Published public private(set) var edges: [ForceSimulationEdge] = []
    @Published public var config: GraphPhysicsConfig {
        didSet {
            config.save()
            restart(targetAlpha: 0.4)
        }
    }

    @Published public private(set) var alpha: Double = 1.0
    @Published public private(set) var isAtRest: Bool = false

    public var center: CGPoint = .zero
    public var alphaMin: Double = 0.002
    public var alphaDecay: Double = 0.022
    private var maxVelocity: Double = 35.0

    public init(config: GraphPhysicsConfig = GraphPhysicsConfig.load()) {
        self.config = config
    }

    public func setNetwork(
        nodes newNodes: [GraphNode],
        edges newEdges: [GraphEdge],
        center: CGPoint,
        preserveExistingPositions: Bool = true
    ) {
        self.center = center
        var updatedNodes: [String: ForceSimulationNode] = [:]

        let count = Double(max(1, newNodes.count))
        let initialRadius = min(center.x, center.y) * 0.55

        for (index, gNode) in newNodes.enumerated() {
            if preserveExistingPositions, let existing = self.nodes[gNode.id] {
                existing.radius = Double(gNode.radius)
                updatedNodes[gNode.id] = existing
            } else {
                // Circular layout around center
                let angle = (Double(index) / count) * 2.0 * Double.pi
                let jitter = Double.random(in: -15.0...15.0)
                let r = initialRadius + jitter
                let px = center.x + r * cos(angle)
                let py = center.y + r * sin(angle)
                updatedNodes[gNode.id] = ForceSimulationNode(
                    id: gNode.id,
                    x: px,
                    y: py,
                    radius: Double(gNode.radius)
                )
            }
        }

        self.nodes = updatedNodes
        self.edges = newEdges.map { ForceSimulationEdge(sourceId: $0.sourceId, targetId: $0.targetId, type: $0.type) }
        restart(targetAlpha: preserveExistingPositions ? 0.4 : 1.0)
    }

    public func restart(targetAlpha: Double = 0.5) {
        guard !config.isFrozen else { return }
        self.alpha = max(self.alpha, targetAlpha)
        self.isAtRest = false
    }

    public func toggleFreeze() {
        config.isFrozen.toggle()
        if !config.isFrozen {
            restart(targetAlpha: 0.6)
        }
    }

    public func dragNode(id: String, to newPosition: CGPoint) {
        guard let node = nodes[id] else { return }
        node.x = Double(newPosition.x)
        node.y = Double(newPosition.y)
        node.vx = 0
        node.vy = 0
        node.isPinned = true
        restart(targetAlpha: 0.3)
    }

    public func unpinNode(id: String) {
        guard let node = nodes[id] else { return }
        node.isPinned = false
        restart(targetAlpha: 0.4)
    }

    public func pinNode(id: String, at point: CGPoint? = nil) {
        guard let node = nodes[id] else { return }
        if let point = point {
            node.x = Double(point.x)
            node.y = Double(point.y)
        }
        node.isPinned = true
    }

    public func step() {
        guard !config.isFrozen && !isAtRest else { return }

        let nodeList = Array(nodes.values)
        let n = nodeList.count
        guard n > 0 else {
            isAtRest = true
            return
        }

        let currentAlpha = alpha
        let repel = config.repelForce * currentAlpha
        let linkF = config.linkForce * currentAlpha
        let linkD = config.linkDistance
        let gravity = config.centerGravity * currentAlpha
        let centerX = Double(center.x)
        let centerY = Double(center.y)

        // 1. Many-body Repulsion (Coulomb Law with softening)
        for i in 0..<n {
            let u = nodeList[i]
            for j in (i + 1)..<n {
                let v = nodeList[j]
                var dx = v.x - u.x
                var dy = v.y - u.y
                var distSq = dx * dx + dy * dy
                if distSq < 1.0 {
                    dx = Double.random(in: -1.0...1.0)
                    dy = Double.random(in: -1.0...1.0)
                    distSq = 1.0
                }
                let dist = sqrt(distSq)
                if dist < 850.0 {
                    let force = repel / (distSq + 25.0)
                    let fx = (dx / dist) * force
                    let fy = (dy / dist) * force
                    if !u.isPinned {
                        u.vx += fx
                        u.vy += fy
                    }
                    if !v.isPinned {
                        v.vx -= fx
                        v.vy -= fy
                    }
                }
            }
        }

        // 2. Spring Attraction along Edges (Hooke's Law)
        for edge in edges {
            guard let u = nodes[edge.sourceId], let v = nodes[edge.targetId] else { continue }
            var dx = v.x - u.x
            var dy = v.y - u.y
            var dist = sqrt(dx * dx + dy * dy)
            if dist < 0.1 {
                dx = Double.random(in: -1.0...1.0)
                dy = Double.random(in: -1.0...1.0)
                dist = 0.1
            }
            let targetD = edge.type == .contains ? (linkD * 1.15) : linkD
            let displacement = dist - targetD
            let force = displacement * linkF
            let fx = (dx / dist) * force
            let fy = (dy / dist) * force

            if !u.isPinned {
                u.vx += fx
                u.vy += fy
            }
            if !v.isPinned {
                v.vx -= fx
                v.vy -= fy
            }
        }

        // 3. Center Gravity & Velocity Integration
        let friction = 0.68
        var maxMoved = 0.0

        for node in nodeList {
            if !node.isPinned {
                // Gravity pull towards center
                let gx = (centerX - node.x) * gravity
                let gy = (centerY - node.y) * gravity
                node.vx += gx
                node.vy += gy

                // Velocity damping
                node.vx *= friction
                node.vy *= friction

                // Clamp velocity
                let speed = sqrt(node.vx * node.vx + node.vy * node.vy)
                if speed > maxVelocity {
                    let ratio = maxVelocity / speed
                    node.vx *= ratio
                    node.vy *= ratio
                }

                node.x += node.vx
                node.y += node.vy
                maxMoved = max(maxMoved, speed)
            }
        }

        // 4. Alpha Decay
        alpha *= (1.0 - alphaDecay)
        if alpha < alphaMin || (alpha < 0.05 && maxMoved < 0.04) {
            alpha = 0.0
            isAtRest = true
        }
    }

    public func tickUntilRest(maxTicks: Int = 300) {
        var ticks = 0
        while !isAtRest && ticks < maxTicks {
            step()
            ticks += 1
        }
    }

    public func getPositions() -> [String: CGPoint] {
        var dict: [String: CGPoint] = [:]
        dict.reserveCapacity(nodes.count)
        for (id, node) in nodes {
            dict[id] = node.point
        }
        return dict
    }
}
