import SwiftUI

public struct LocalGraphView: View {
    @ObservedObject public var store: BlockStore
    @StateObject private var simulation = ForceSimulation()
    @State private var depth: Int = 1
    @State private var includeHierarchy: Bool = false

    public init(store: BlockStore) {
        self.store = store
    }

    public var body: some View {
        let activeId = store.selectedDocId ?? ""
        let localData = store.getLocalGraphData(docId: activeId, depth: depth, includeContains: includeHierarchy)

        VStack(spacing: 0) {
            // Header with Depth controls & Inbound/Outbound Legend
            VStack(spacing: 8) {
                HStack {
                    Text("LOCAL GRAPH")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)

                    Spacer()

                    // Depth Control (1 - 3 hops)
                    Picker("Hops", selection: $depth) {
                        Text("1 Hop").tag(1)
                        Text("2 Hops").tag(2)
                        Text("3 Hops").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 155)
                    .controlSize(.mini)
                }

                HStack(spacing: 12) {
                    // Inbound / Outbound Legend
                    HStack(spacing: 4) {
                        Circle().fill(Color(hexString: "#00E676")).frame(width: 7, height: 7)
                        Text("Outbound →").font(.system(size: 9)).foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Circle().fill(Color(hexString: "#00E5FF")).frame(width: 7, height: 7)
                        Text("Inbound ←").font(.system(size: 9)).foregroundColor(.secondary)
                    }

                    Spacer()

                    Toggle(isOn: $includeHierarchy) {
                        Text("Tree").font(.system(size: 9))
                    }
                    .toggleStyle(.button)
                    .controlSize(.mini)
                    .tint(includeHierarchy ? .purple : .secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            if localData.nodes.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("No connections for active note")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Add a [[WikiLink]] or transclusion to link notes.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(20)
            } else {
                // Interactive Embedded Canvas
                GraphCanvasView(
                    nodes: localData.nodes,
                    edges: localData.edges,
                    filterConfig: GraphFilterConfig(showLinks: true, showContains: includeHierarchy, showUnresolved: true, showOrphans: true),
                    groupRules: store.graphGroupRules,
                    isLocalGraph: true,
                    activeDocId: store.selectedDocId,
                    onNodeSelected: { docId in
                        store.selectDocument(id: docId)
                    },
                    onUnresolvedSelected: { title in
                        _ = store.createDocFromUnresolvedLink(title: title, sourceDocId: activeId)
                    },
                    simulation: simulation
                )
            }
        }
        .onChange(of: store.selectedDocId) { _, _ in
            simulation.restart(targetAlpha: 0.8)
        }
        .onChange(of: depth) { _, _ in
            simulation.restart(targetAlpha: 0.9)
        }
    }
}
