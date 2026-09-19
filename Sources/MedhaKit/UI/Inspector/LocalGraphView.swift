import SwiftUI

public struct LocalGraphView: View {
    @ObservedObject public var store: BlockStore
    @State private var hoveredNodeId: String? = nil

    public var body: some View {
        let (nodes, edges) = store.getGraphData()

        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) * 0.36

            // Compute positions
            let positions = computeNodePositions(nodes: nodes, center: center, radius: radius)

            ZStack {
                Color(NSColor.controlBackgroundColor).opacity(0.3)

                // Edges
                Path { path in
                    for edge in edges {
                        if let start = positions[edge.sourceId], let end = positions[edge.targetId] {
                            path.move(to: start)
                            path.addLine(to: end)
                        }
                    }
                }
                .stroke(Color.accentColor.opacity(0.35), lineWidth: 1.5)

                // Nodes
                ForEach(nodes) { node in
                    if let pos = positions[node.id] {
                        let isSelected = node.id == store.selectedDocId

                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Color.accentColor : Color(NSColor.windowBackgroundColor))
                                    .frame(width: isSelected ? 22 : 16, height: isSelected ? 22 : 16)
                                    .shadow(color: isSelected ? Color.accentColor.opacity(0.5) : Color.black.opacity(0.1), radius: isSelected ? 6 : 2)
                                    .overlay(
                                        Circle()
                                            .stroke(isSelected ? Color.white : Color.accentColor, lineWidth: isSelected ? 2 : 1.5)
                                    )

                                if isSelected {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 6, height: 6)
                                }
                            }

                            Text(node.title)
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .accentColor : .secondary)
                                .lineLimit(1)
                                .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
                                .cornerRadius(3)
                        }
                        .position(pos)
                        .onHover { hovering in
                            hoveredNodeId = hovering ? node.id : nil
                        }
                        .onTapGesture {
                            store.selectDocument(id: node.id)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(8)
    }

    private func computeNodePositions(
        nodes: [GraphNode],
        center: CGPoint,
        radius: CGFloat
    ) -> [String: CGPoint] {
        var positions: [String: CGPoint] = [:]
        guard !nodes.isEmpty else { return positions }

        // Place current document at center
        if let current = nodes.first(where: { $0.id == store.selectedDocId }) {
            positions[current.id] = center
        }

        let otherNodes = nodes.filter { $0.id != store.selectedDocId }
        guard !otherNodes.isEmpty else { return positions }

        let angleStep = (2 * CGFloat.pi) / CGFloat(otherNodes.count)
        for (i, node) in otherNodes.enumerated() {
            let angle = CGFloat(i) * angleStep - CGFloat.pi / 2
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            positions[node.id] = CGPoint(x: x, y: y)
        }

        return positions
    }
}
