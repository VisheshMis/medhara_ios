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
            if !config.isFrozen {
                self.alpha = max(self.alpha, 0.85)
                self.isAtRest = false
            }
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
        let initialRadius = max(180.0, sqrt(count) * 42.0)
        let goldenAngle = Double.pi * (3.0 - sqrt(5.0))

        for (index, gNode) in newNodes.enumerated() {
            if preserveExistingPositions, let existing = self.nodes[gNode.id] {
                existing.radius = Double(gNode.radius)
                updatedNodes[gNode.id] = existing
            } else {
                let theta = Double(index) * goldenAngle
                let r = sqrt(Double(index + 1) / count) * initialRadius
                let px = center.x + r * cos(theta)
                let py = center.y + r * sin(theta)
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

    public func wakeAndStep(targetAlpha: Double = 0.85) {
        if config.isFrozen {
            config.isFrozen = false
        }
        self.alpha = max(self.alpha, targetAlpha)
        self.isAtRest = false
        step()
    }

    public func restart(targetAlpha: Double = 0.5) {
        guard !config.isFrozen else { return }
        self.alpha = max(self.alpha, targetAlpha)
        self.isAtRest = false
    }

    public func toggleFreeze() {
        config.isFrozen.toggle()
        if !config.isFrozen {
            restart(targetAlpha: 0.8)
        }
    }

    public func dragNode(id: String, to newPosition: CGPoint) {
        guard let node = nodes[id] else { return }
        node.x = Double(newPosition.x)
        node.y = Double(newPosition.y)
        node.vx = 0
        node.vy = 0
        node.isPinned = true
        restart(targetAlpha: 0.4)
    }

    public func unpinNode(id: String) {
        guard let node = nodes[id] else { return }
        node.isPinned = false
        restart(targetAlpha: 0.5)
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
        let maxRepelDist = 550.0

        // 1. Many-body Repulsion & Anti-Collision Non-Penetration
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

                // A. Anti-Collision Non-Penetration Spring (stops nodes from ever overlapping)
                let minPadding = (u.radius + v.radius) + 20.0
                if dist < minPadding {
                    let overlap = minPadding - dist
                    let collisionForce = (overlap / minPadding) * 14.0 * currentAlpha
                    let cx = (dx / dist) * collisionForce
                    let cy = (dy / dist) * collisionForce
                    if !u.isPinned {
                        u.vx -= cx
                        u.vy -= cy
                    }
                    if !v.isPinned {
                        v.vx += cx
                        v.vy += cy
                    }
                }

                // B. Coulomb Inverse-Distance Repulsion with smooth distance falloff
                if dist < maxRepelDist {
                    let falloff = 1.0 - (dist / maxRepelDist)
                    let force = (repel / max(dist, 20.0)) * falloff * 0.75
                    let fx = (dx / dist) * force
                    let fy = (dy / dist) * force
                    if !u.isPinned {
                        u.vx += fx
                        u.vy += fy
                    }
                    if !v.isPinned {
                        v.vx += fx
                        v.vy += fy
                    }
                }
            }
        }

        // 2. Spring Attraction / Repulsion along Edges (Hooke's Law with D3 normalized displacement)
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
            let targetD = edge.type == .contains ? (linkD * 1.25) : linkD
            let displacement = dist - targetD
            let force = (displacement / max(dist, 1.0)) * linkF * 55.0
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
        let friction = 0.76
        var maxMoved = 0.0

        for node in nodeList {
            if !node.isPinned {
                // Soft gravity pull towards center (prevents boundless drift)
                let gx = (centerX - node.x) * gravity
                let gy = (centerY - node.y) * gravity
                node.vx += gx
                node.vy += gy

                // Velocity damping
                node.vx *= friction
                node.vy *= friction

                // Clamp velocity to prevent jitter explosions
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
        if alpha < alphaMin || (alpha < 0.04 && maxMoved < 0.05) {
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
