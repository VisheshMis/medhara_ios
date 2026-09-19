import SwiftUI

public struct GlobalGraphView: View {
    @ObservedObject public var store: BlockStore
    @StateObject private var simulation = ForceSimulation()
    @State private var isControlsSheetPresented: Bool = false
    @State private var selectedPreset: GraphViewPreset = .links
    @State private var uncreatedTargetTitle: String? = nil

    public init(store: BlockStore) {
        self.store = store
    }

    public var body: some View {
        let graphData = store.getGlobalGraphData(filter: store.graphFilterConfig)

        VStack(spacing: 0) {
            // Top Toolbar Bar
            HStack(spacing: 12) {
                // Search & Filter
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Filter nodes & tags...", text: $store.graphFilterConfig.filterText)
                        .textFieldStyle(.plain)
                        .frame(width: 160)

                    if !store.graphFilterConfig.filterText.isEmpty {
                        Button(action: { store.graphFilterConfig.filterText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)

                // Dim vs Hide Filter Action
                Picker("Filter Action", selection: $store.graphFilterConfig.filterAction) {
                    Text("Dim").tag(GraphFilterAction.dim)
                    Text("Hide").tag(GraphFilterAction.hide)
                }
                .pickerStyle(.segmented)
                .frame(width: 105)
                .controlSize(.small)

                Divider().frame(height: 18)

                // 1-Click View Presets
                Picker("View Preset", selection: $selectedPreset) {
                    ForEach(GraphViewPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 195)
                .controlSize(.small)
                .onChange(of: selectedPreset) { _, preset in
                    applyPreset(preset)
                }

                Divider().frame(height: 18)

                // Toggleable Granular Layers
                Button(action: {
                    store.graphFilterConfig.showContains.toggle()
                    updatePresetFromToggles()
                }) {
                    Label("Tree", systemImage: "folder")
                        .font(.system(size: 11, weight: store.graphFilterConfig.showContains ? .semibold : .regular))
                }
                .buttonStyle(.bordered)
                .tint(store.graphFilterConfig.showContains ? .purple : .secondary)
                .controlSize(.small)
                .help("Toggle CONTAINS Hierarchy Tree layer (dashed lines)")

                Button(action: {
                    store.graphFilterConfig.showUnresolved.toggle()
                }) {
                    Label("Unresolved", systemImage: "circle.dashed")
                        .font(.system(size: 11, weight: store.graphFilterConfig.showUnresolved ? .semibold : .regular))
                }
                .buttonStyle(.bordered)
                .tint(store.graphFilterConfig.showUnresolved ? .blue : .secondary)
                .controlSize(.small)
                .help("Toggle Unresolved Ghost Link targets")

                Button(action: {
                    store.graphFilterConfig.showOrphans.toggle()
                }) {
                    Label("Orphans", systemImage: "circle.slash")
                        .font(.system(size: 11, weight: store.graphFilterConfig.showOrphans ? .semibold : .regular))
                }
                .buttonStyle(.bordered)
                .tint(store.graphFilterConfig.showOrphans ? .green : .secondary)
                .controlSize(.small)
                .help("Toggle Orphan nodes with zero connections")

                Spacer()

                // Simulation Controls & Inspector Popover
                Button(action: {
                    simulation.toggleFreeze()
                }) {
                    Image(systemName: simulation.config.isFrozen ? "play.fill" : "pause.fill")
                        .foregroundColor(simulation.config.isFrozen ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help(simulation.config.isFrozen ? "Resume Simulation" : "Freeze Simulation")

                Button(action: {
                    simulation.restart(targetAlpha: 0.9)
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Re-layout & warm up simulation")

                Button(action: {
                    isControlsSheetPresented.toggle()
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.primary)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Physics & Group Rules Settings")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Main Interactive Graph Canvas
            ZStack(alignment: .bottomLeading) {
                GraphCanvasView(
                    nodes: graphData.nodes,
                    edges: graphData.edges,
                    filterConfig: store.graphFilterConfig,
                    groupRules: store.graphGroupRules,
                    isLocalGraph: false,
                    activeDocId: store.selectedDocId,
                    onNodeSelected: { docId in
                        store.activeMainView = .editor
                        store.selectDocument(id: docId)
                    },
                    onUnresolvedSelected: { title in
                        uncreatedTargetTitle = title
                    },
                    simulation: simulation
                )

                // Bottom Status Bar
                HStack(spacing: 12) {
                    Text("\(graphData.nodes.count) nodes")
                        .font(.caption2.bold())
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(graphData.edges.count) connections")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if simulation.config.isFrozen {
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("PAUSED")
                            .font(.caption2.bold())
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.85))
                .cornerRadius(6)
                .padding(12)
            }
        }
        .sheet(isPresented: $isControlsSheetPresented) {
            GraphControlsSheet(simulation: simulation, groupRules: $store.graphGroupRules)
        }
        .alert(
            "Create Note for \"\(uncreatedTargetTitle ?? "")\"?",
            isPresented: Binding(
                get: { uncreatedTargetTitle != nil },
                set: { if !$0 { uncreatedTargetTitle = nil } }
            )
        ) {
            Button("Create Note") {
                if let title = uncreatedTargetTitle {
                    let newDoc = store.createDocFromUnresolvedLink(title: title, sourceDocId: store.selectedDocId ?? "")
                    uncreatedTargetTitle = nil
                    store.activeMainView = .editor
                    store.selectDocument(id: newDoc.id)
                }
            }
            Button("Cancel", role: .cancel) {
                uncreatedTargetTitle = nil
            }
        } message: {
            Text("This is an unresolved link. Would you like to create a new document with this title?")
        }
    }

    private func applyPreset(_ preset: GraphViewPreset) {
        switch preset {
        case .links:
            store.graphFilterConfig.showLinks = true
            store.graphFilterConfig.showContains = false
        case .tree:
            store.graphFilterConfig.showLinks = false
            store.graphFilterConfig.showContains = true
        case .blended:
            store.graphFilterConfig.showLinks = true
            store.graphFilterConfig.showContains = true
        }
    }

    private func updatePresetFromToggles() {
        if store.graphFilterConfig.showLinks && store.graphFilterConfig.showContains {
            selectedPreset = .blended
        } else if store.graphFilterConfig.showContains && !store.graphFilterConfig.showLinks {
            selectedPreset = .tree
        } else if store.graphFilterConfig.showLinks && !store.graphFilterConfig.showContains {
            selectedPreset = .links
        }
    }
}
