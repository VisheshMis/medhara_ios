import SwiftUI
import AppKit

public struct GraphCanvasView: View {
    public let nodes: [GraphNode]
    public let edges: [GraphEdge]
    public let filterConfig: GraphFilterConfig
    public let groupRules: [GraphGroupRule]
    public let isLocalGraph: Bool
    public let activeDocId: String?
    public let onNodeSelected: (String) -> Void
    public let onUnresolvedSelected: (String) -> Void
    @ObservedObject public var simulation: ForceSimulation

    // Pan & Zoom Camera State
    @State private var panOffset: CGSize = .zero
    @State private var dragStartPan: CGSize = .zero
    @State private var zoomScale: CGFloat = 1.0
    @State private var hoveredNodeId: String? = nil
    @State private var draggedNodeId: String? = nil
    @State private var mouseLocationInView: CGPoint = .zero

    // Animation / Refresh ticker
    @State private var timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    private let labelZoomThreshold: CGFloat = 0.65

    private let ancestorPalette: [Color] = [
        Color(hexString: "#00E676"), // Neon Green
        Color(hexString: "#00E5FF"), // Bright Cyan
        Color(hexString: "#7C4DFF"), // Vivid Purple
        Color(hexString: "#FF9100"), // Warm Amber
        Color(hexString: "#FF4081"), // Hot Pink
        Color(hexString: "#FFEA00"), // Radiant Yellow
        Color(hexString: "#651FFF"), // Deep Indigo
        Color(hexString: "#00B0FF")  // Sky Blue
    ]

    public init(
        nodes: [GraphNode],
        edges: [GraphEdge],
        filterConfig: GraphFilterConfig = GraphFilterConfig(),
        groupRules: [GraphGroupRule] = [],
        isLocalGraph: Bool = false,
        activeDocId: String? = nil,
        onNodeSelected: @escaping (String) -> Void,
        onUnresolvedSelected: @escaping (String) -> Void = { _ in },
        simulation: ForceSimulation
    ) {
        self.nodes = nodes
        self.edges = edges
        self.filterConfig = filterConfig
        self.groupRules = groupRules
        self.isLocalGraph = isLocalGraph
        self.activeDocId = activeDocId
        self.onNodeSelected = onNodeSelected
        self.onUnresolvedSelected = onUnresolvedSelected
        self.simulation = simulation
    }

    public var body: some View {
        GeometryReader { geometry in
            let viewCenter = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let positions = simulation.getPositions()
            let filteredNodes = computeFilteredNodes()
            let neighborSet = computeNeighborSet(for: hoveredNodeId)

            ZStack {
                // High-Performance GPU Canvas
                Canvas { context, size in
                    let canvasCenter = CGPoint(x: size.width / 2, y: size.height / 2)

                    // Coordinate transform for Pan & Zoom
                    context.translateBy(x: canvasCenter.x + panOffset.width, y: canvasCenter.y + panOffset.height)
                    context.scaleBy(x: zoomScale, y: zoomScale)
                    context.translateBy(x: -canvasCenter.x, y: -canvasCenter.y)

                    // 1. Draw Edges
                    for edge in edges {
                        guard let start = positions[edge.sourceId], let end = positions[edge.targetId] else { continue }
                        guard isNodeVisibleInFilter(id: edge.sourceId) && isNodeVisibleInFilter(id: edge.targetId) else { continue }

                        let isConnectedToHover = hoveredNodeId != nil && (edge.sourceId == hoveredNodeId || edge.targetId == hoveredNodeId)
                        let isFaded = hoveredNodeId != nil && !isConnectedToHover

                        if edge.type == .contains {
                            // Hierarchy Tree Edges: Dashed, dimmer, distinct style
                            var path = Path()
                            path.move(to: start)
                            path.addLine(to: end)

                            let strokeStyle = StrokeStyle(
                                lineWidth: isConnectedToHover ? 2.5 : 1.5,
                                dash: [4, 4]
                            )
                            let color = Color(hexString: "#7C4DFF").opacity(isFaded ? 0.08 : (isConnectedToHover ? 0.9 : 0.35))
                            context.stroke(path, with: .color(color), style: strokeStyle)
                        } else {
                            // LINKS_TO Edges: Solid line with optional directional styling
                            var path = Path()
                            path.move(to: start)
                            path.addLine(to: end)

                            let strokeWidth: CGFloat = isConnectedToHover ? 2.2 : (isLocalGraph ? 1.8 : 1.2)
                            let edgeColor: Color

                            if isLocalGraph {
                                if edge.isOutboundFromActive {
                                    edgeColor = Color(hexString: "#00E676").opacity(isFaded ? 0.15 : 0.9) // Outbound green
                                } else if edge.isInboundToActive {
                                    edgeColor = Color(hexString: "#00E5FF").opacity(isFaded ? 0.15 : 0.9) // Inbound cyan
                                } else {
                                    edgeColor = Color.secondary.opacity(isFaded ? 0.08 : 0.4)
                                }
                            } else {
                                edgeColor = Color(hexString: "#00E676").opacity(isFaded ? 0.08 : (isConnectedToHover ? 0.85 : 0.32))
                            }

                            context.stroke(path, with: .color(edgeColor), lineWidth: strokeWidth)

                            // Draw Arrowheads in local graph or when zoomed in
                            if isLocalGraph || zoomScale > 1.2 || isConnectedToHover {
                                drawArrowhead(to: end, from: start, targetRadius: CGFloat(nodes.first(where: { $0.id == edge.targetId })?.radius ?? 10), context: &context, color: edgeColor)
                            }
                        }
                    }

                    // 2. Draw Nodes (Vertices)
                    for node in filteredNodes {
                        guard let pos = positions[node.id] else { continue }

                        let isHovered = (node.id == hoveredNodeId)
                        let isNeighbor = neighborSet.contains(node.id)
                        let isSelected = (node.id == activeDocId)
                        let isHighlighted = isHovered || isNeighbor || isSelected
                        let isFaded = hoveredNodeId != nil && !isHighlighted
                        let isDimmedBySearch = isNodeDimmedBySearch(node: node)

                        let effectiveOpacity: Double = isDimmedBySearch ? 0.12 : (isFaded ? 0.14 : 1.0)
                        let radius = node.radius * (isHovered ? 1.25 : (isSelected ? 1.15 : 1.0))
                        let nodeColor = colorForNode(node).opacity(effectiveOpacity)

                        let rect = CGRect(x: pos.x - radius, y: pos.y - radius, width: radius * 2, height: radius * 2)

                        if node.isUnresolved {
                            // Unresolved target: smaller, hollow/outlined circle
                            var circlePath = Path()
                            circlePath.addEllipse(in: rect)
                            let dashedStroke = StrokeStyle(lineWidth: isHovered ? 2.0 : 1.4, dash: [3, 3])
                            context.stroke(circlePath, with: .color(Color.secondary.opacity(effectiveOpacity * 0.85)), style: dashedStroke)
                        } else {
                            // Resolved document node
                            var circlePath = Path()
                            circlePath.addEllipse(in: rect)
                            context.fill(circlePath, with: .color(nodeColor))

                            if isSelected || isHovered {
                                let strokeColor = isSelected ? Color.white : nodeColor
                                context.stroke(circlePath, with: .color(strokeColor), lineWidth: isSelected ? 2.5 : 1.8)
                            }
                        }

                        // 3. Draw Labels (LOD threshold or highlighted)
                        let shouldDrawLabel = (zoomScale >= labelZoomThreshold || isHighlighted) && !isDimmedBySearch
                        if shouldDrawLabel {
                            let text = Text(node.title)
                                .font(.system(size: isHighlighted ? 11 : 9.5, weight: isHighlighted ? .bold : .medium))
                                .foregroundColor(isHighlighted ? Color.primary : Color.secondary.opacity(effectiveOpacity))

                            let labelPoint = CGPoint(x: pos.x, y: pos.y + radius + 7)
                            context.draw(context.resolve(text), at: labelPoint, anchor: .top)
                        }
                    }
                }
                .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let canvasCenter = viewCenter
                            let touchLocation = value.location

                            if draggedNodeId == nil {
                                // Hit test node under drag start
                                let worldPoint = screenToWorld(touchLocation, canvasCenter: canvasCenter)
                                if let hit = hitTestNode(at: worldPoint, positions: positions, radiusExpansion: 8) {
                                    draggedNodeId = hit.id
                                }
                            }

                            if let id = draggedNodeId {
                                // Drag vertex & pin
                                let worldPoint = screenToWorld(touchLocation, canvasCenter: canvasCenter)
                                simulation.dragNode(id: id, to: worldPoint)
                            } else {
                                // Drag background: Pan camera
                                panOffset = CGSize(
                                    width: dragStartPan.width + value.translation.width,
                                    height: dragStartPan.height + value.translation.height
                                )
                            }
                        }
                        .onEnded { value in
                            if let id = draggedNodeId {
                                // Keep node pinned
                                simulation.pinNode(id: id)
                                draggedNodeId = nil
                            } else {
                                dragStartPan = panOffset
                            }
                        }
                )
                .simultaneousGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            let worldPoint = screenToWorld(mouseLocationInView, canvasCenter: viewCenter)
                            if let hit = hitTestNode(at: worldPoint, positions: positions, radiusExpansion: 8) {
                                // Double click node: unpin!
                                simulation.unpinNode(id: hit.id)
                            } else {
                                // Double click background: reset zoom & pan
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    panOffset = .zero
                                    dragStartPan = .zero
                                    zoomScale = 1.0
                                }
                            }
                        }
                )
                .simultaneousGesture(
                    TapGesture(count: 1)
                        .onEnded {
                            let worldPoint = screenToWorld(mouseLocationInView, canvasCenter: viewCenter)
                            if let hit = hitTestNode(at: worldPoint, positions: positions, radiusExpansion: 8) {
                                if hit.isUnresolved {
                                    onUnresolvedSelected(hit.title)
                                } else {
                                    onNodeSelected(hit.id)
                                }
                            }
                        }
                )
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        mouseLocationInView = location
                        let worldPoint = screenToWorld(location, canvasCenter: viewCenter)
                        if let hit = hitTestNode(at: worldPoint, positions: positions, radiusExpansion: 8) {
                            if hoveredNodeId != hit.id {
                                hoveredNodeId = hit.id
                                NSCursor.pointingHand.push()
                            }
                        } else {
                            if hoveredNodeId != nil {
                                hoveredNodeId = nil
                                NSCursor.pop()
                            }
                        }
                    case .ended:
                        hoveredNodeId = nil
                        draggedNodeId = nil
                    }
                }
            }
            .onAppear {
                simulation.setNetwork(nodes: nodes, edges: edges, center: viewCenter, preserveExistingPositions: false)
            }
            .onChange(of: nodes) { _, newNodes in
                simulation.setNetwork(nodes: newNodes, edges: edges, center: viewCenter, preserveExistingPositions: true)
            }
            .onChange(of: edges) { _, newEdges in
                simulation.setNetwork(nodes: nodes, edges: newEdges, center: viewCenter, preserveExistingPositions: true)
            }
            .onReceive(timer) { _ in
                if !simulation.isAtRest && !simulation.config.isFrozen {
                    simulation.step()
                }
            }
        }
    }

    // MARK: - Filtering & Neighbors
    private func computeFilteredNodes() -> [GraphNode] {
        if filterConfig.filterAction == .hide && !filterConfig.filterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = filterConfig.filterText.lowercased()
            return nodes.filter { node in
                node.title.lowercased().contains(query) ||
                node.tags.contains(where: { $0.lowercased().contains(query) })
            }
        }
        return nodes
    }

    private func isNodeVisibleInFilter(id: String) -> Bool {
        guard filterConfig.filterAction == .hide && !filterConfig.filterText.isEmpty else { return true }
        guard let node = nodes.first(where: { $0.id == id }) else { return false }
        let query = filterConfig.filterText.lowercased()
        return node.title.lowercased().contains(query) || node.tags.contains(where: { $0.lowercased().contains(query) })
    }

    private func isNodeDimmedBySearch(node: GraphNode) -> Bool {
        guard filterConfig.filterAction == .dim else { return false }
        let trimmed = filterConfig.filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let query = trimmed.lowercased()
        let matches = node.title.lowercased().contains(query) || node.tags.contains(where: { $0.lowercased().contains(query) })
        return !matches
    }

    private func computeNeighborSet(for targetId: String?) -> Set<String> {
        guard let targetId = targetId else { return [] }
        var set: Set<String> = []
        for edge in edges {
            if edge.sourceId == targetId {
                set.insert(edge.targetId)
            } else if edge.targetId == targetId {
                set.insert(edge.sourceId)
            }
        }
        return set
    }

    // MARK: - Color Rules in Priority Order
    private func colorForNode(_ node: GraphNode) -> Color {
        for rule in groupRules {
            switch rule.ruleType {
            case .topLevelAncestor:
                let ancestorId = node.topLevelAncestorId ?? node.id
                let hash = abs(ancestorId.hashValue)
                let paletteIndex = hash % ancestorPalette.count
                return ancestorPalette[paletteIndex]

            case .tag(let targetTag):
                let cleanTag = targetTag.replacingOccurrences(of: "#", with: "").lowercased()
                if node.tags.contains(where: { $0.lowercased() == cleanTag }) {
                    return Color(hexString: rule.hexColor)
                }

            case .searchQuery(let query):
                let q = query.lowercased()
                if node.title.lowercased().contains(q) {
                    return Color(hexString: rule.hexColor)
                }
            }
        }

        // Default Neon Green / Accent
        return Color(hexString: "#00E676")
    }

    // MARK: - Coordinate Transformations & Hit-Testing
    private func screenToWorld(_ point: CGPoint, canvasCenter: CGPoint) -> CGPoint {
        let centeredX = point.x - (canvasCenter.x + panOffset.width)
        let centeredY = point.y - (canvasCenter.y + panOffset.height)
        let unscaledX = centeredX / zoomScale
        let unscaledY = centeredY / zoomScale
        return CGPoint(x: unscaledX + canvasCenter.x, y: unscaledY + canvasCenter.y)
    }

    private func hitTestNode(at worldPoint: CGPoint, positions: [String: CGPoint], radiusExpansion: CGFloat = 6) -> GraphNode? {
        for node in nodes {
            guard let pos = positions[node.id] else { continue }
            let r = node.radius + radiusExpansion
            let dx = worldPoint.x - pos.x
            let dy = worldPoint.y - pos.y
            if (dx * dx + dy * dy) <= (r * r) {
                return node
            }
        }
        return nil
    }

    private func drawArrowhead(to tip: CGPoint, from start: CGPoint, targetRadius: CGFloat, context: inout GraphicsContext, color: Color) {
        let dx = tip.x - start.x
        let dy = tip.y - start.y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > targetRadius + 6 else { return }

        let ux = dx / dist
        let uy = dy / dist
        let arrowTip = CGPoint(x: tip.x - ux * (targetRadius + 2), y: tip.y - uy * (targetRadius + 2))
        let arrowLength: CGFloat = 8.0
        let arrowWidth: CGFloat = 5.0

        let base = CGPoint(x: arrowTip.x - ux * arrowLength, y: arrowTip.y - uy * arrowLength)
        let px = -uy
        let py = ux

        let left = CGPoint(x: base.x + px * arrowWidth, y: base.y + py * arrowWidth)
        let right = CGPoint(x: base.x - px * arrowWidth, y: base.y - py * arrowWidth)

        var path = Path()
        path.move(to: arrowTip)
        path.addLine(to: left)
        path.addLine(to: right)
        path.closeSubpath()

        context.fill(path, with: .color(color))
    }
}
