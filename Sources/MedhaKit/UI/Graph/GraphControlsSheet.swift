import SwiftUI

public struct GraphControlsSheet: View {
    @ObservedObject public var simulation: ForceSimulation
    @Binding public var groupRules: [GraphGroupRule]
    public var onClose: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var newRuleName: String = ""
    @State private var newRuleTypeSelection: Int = 0 // 0: Top-level Ancestor, 1: Tag, 2: Search Query
    @State private var newRuleValue: String = ""
    @State private var newRuleColorHex: String = "#00E5FF"

    private let presetColors = ["#00E676", "#00E5FF", "#7C4DFF", "#FF9100", "#FF4081", "#FFEA00", "#651FFF", "#00B0FF"]

    public init(
        simulation: ForceSimulation,
        groupRules: Binding<[GraphGroupRule]>,
        onClose: (() -> Void)? = nil
    ) {
        self.simulation = simulation
        self._groupRules = groupRules
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Label("Graph Controls & Rules", systemImage: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button(action: {
                    if let onClose = onClose {
                        onClose()
                    } else {
                        dismiss()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close Controls")
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Physics Section
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("PHYSICS SIMULATION")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button(action: {
                                    simulation.toggleFreeze()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: simulation.config.isFrozen ? "play.fill" : "pause.fill")
                                        Text(simulation.config.isFrozen ? "Resume" : "Pause")
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(simulation.config.isFrozen ? .green : .secondary)
                                .controlSize(.small)
                            }

                            // Quick Preset Buttons
                            VStack(alignment: .leading, spacing: 4) {
                                Text("LAYOUT PRESETS")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.secondary)
                                HStack(spacing: 6) {
                                    Button("Spacious") {
                                        simulation.config.repelForce = -3000.0
                                        simulation.config.linkDistance = 190.0
                                        simulation.config.centerGravity = 0.003
                                        simulation.config.linkForce = 0.045
                                        simulation.wakeAndStep(targetAlpha: 0.95)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)

                                    Button("Balanced") {
                                        simulation.config.repelForce = -1400.0
                                        simulation.config.linkDistance = 130.0
                                        simulation.config.centerGravity = 0.008
                                        simulation.config.linkForce = 0.060
                                        simulation.wakeAndStep(targetAlpha: 0.95)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)

                                    Button("Compact") {
                                        simulation.config.repelForce = -500.0
                                        simulation.config.linkDistance = 75.0
                                        simulation.config.centerGravity = 0.018
                                        simulation.config.linkForce = 0.090
                                        simulation.wakeAndStep(targetAlpha: 0.95)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                }
                            }

                            Divider().padding(.vertical, 2)

                            // Repel Force Slider
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text("Repel Force:")
                                        .font(.system(size: 11, weight: .medium))
                                    Spacer()
                                    Text(String(format: "%.0f", simulation.config.repelForce))
                                        .font(.system(size: 10).monospaced())
                                        .foregroundColor(.secondary)
                                }
                                Slider(
                                    value: Binding(
                                        get: { simulation.config.repelForce },
                                        set: { newVal in
                                            simulation.config.repelForce = newVal
                                            simulation.wakeAndStep(targetAlpha: 0.85)
                                        }
                                    ),
                                    in: -5000...(-200),
                                    step: 50
                                )
                            }

                            // Link Rest Distance Slider
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text("Link Rest Distance:")
                                        .font(.system(size: 11, weight: .medium))
                                    Spacer()
                                    Text(String(format: "%.0f pt", simulation.config.linkDistance))
                                        .font(.system(size: 10).monospaced())
                                        .foregroundColor(.secondary)
                                }
                                Slider(
                                    value: Binding(
                                        get: { simulation.config.linkDistance },
                                        set: { newVal in
                                            simulation.config.linkDistance = newVal
                                            simulation.wakeAndStep(targetAlpha: 0.85)
                                        }
                                    ),
                                    in: 40...350,
                                    step: 10
                                )
                            }

                            // Link Attraction Force Slider
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text("Link Attraction Force:")
                                        .font(.system(size: 11, weight: .medium))
                                    Spacer()
                                    Text(String(format: "%.3f", simulation.config.linkForce))
                                        .font(.system(size: 10).monospaced())
                                        .foregroundColor(.secondary)
                                }
                                Slider(
                                    value: Binding(
                                        get: { simulation.config.linkForce },
                                        set: { newVal in
                                            simulation.config.linkForce = newVal
                                            simulation.wakeAndStep(targetAlpha: 0.85)
                                        }
                                    ),
                                    in: 0.01...0.20,
                                    step: 0.005
                                )
                            }

                            // Center Gravity Slider
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text("Center Gravity:")
                                        .font(.system(size: 11, weight: .medium))
                                    Spacer()
                                    Text(String(format: "%.4f", simulation.config.centerGravity))
                                        .font(.system(size: 10).monospaced())
                                        .foregroundColor(.secondary)
                                }
                                Slider(
                                    value: Binding(
                                        get: { simulation.config.centerGravity },
                                        set: { newVal in
                                            simulation.config.centerGravity = newVal
                                            simulation.wakeAndStep(targetAlpha: 0.85)
                                        }
                                    ),
                                    in: 0.000...0.030,
                                    step: 0.001
                                )
                            }

                            HStack {
                                Button("Reset to Optimal") {
                                    simulation.config = GraphPhysicsConfig()
                                    simulation.config.save()
                                    simulation.wakeAndStep(targetAlpha: 0.95)
                                }
                                .controlSize(.small)

                                Spacer()

                                Button(action: {
                                    simulation.restart(targetAlpha: 0.9)
                                }) {
                                    Label("Re-shake", systemImage: "sparkles")
                                }
                                .controlSize(.small)
                            }
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                    }

                    // Group Coloring Rules Section
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("VERTEX COLOR GROUPING RULES")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)

                            Text("Applied in priority order from top to bottom:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if groupRules.isEmpty {
                                Text("No custom rules defined. Default palette active.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                            } else {
                                ForEach(Array(groupRules.enumerated()), id: \.element.id) { index, rule in
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color(hexString: rule.hexColor))
                                            .frame(width: 12, height: 12)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(rule.name)
                                                .font(.system(size: 12, weight: .semibold))
                                            Text(ruleDescription(rule))
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Button(action: {
                                            groupRules.remove(at: index)
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                                .font(.system(size: 11))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(8)
                                    .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                                    .cornerRadius(6)
                                }
                            }

                            Divider().padding(.vertical, 4)

                            // Add new rule form
                            Text("Add New Group Rule:")
                                .font(.caption.bold())

                            Picker("Rule Type", selection: $newRuleTypeSelection) {
                                Text("Top-Level Folder").tag(0)
                                Text("Tag (#tag)").tag(1)
                                Text("Search Query").tag(2)
                            }
                            .pickerStyle(.segmented)

                            if newRuleTypeSelection == 1 {
                                TextField("Tag (e.g. biology)", text: $newRuleValue)
                                    .textFieldStyle(.roundedBorder)
                            } else if newRuleTypeSelection == 2 {
                                TextField("Title keyword query", text: $newRuleValue)
                                    .textFieldStyle(.roundedBorder)
                            }

                            HStack {
                                Text("Rule Color:")
                                    .font(.caption)
                                ForEach(presetColors, id: \.self) { hex in
                                    Circle()
                                        .fill(Color(hexString: hex))
                                        .frame(width: 16, height: 16)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: newRuleColorHex == hex ? 2 : 0)
                                        )
                                        .onTapGesture {
                                            newRuleColorHex = hex
                                        }
                                }
                            }

                            Button(action: addRule) {
                                Label("Add Group Rule", systemImage: "plus")
                            }
                            .controlSize(.small)
                            .disabled(newRuleTypeSelection != 0 && newRuleValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(18)
        .frame(width: 380, height: 530)
    }

    private func ruleDescription(_ rule: GraphGroupRule) -> String {
        switch rule.ruleType {
        case .topLevelAncestor:
            return "Colored by top-level root document or folder"
        case .tag(let tag):
            return "Matches tag: #\(tag)"
        case .searchQuery(let query):
            return "Matches title query: \"\(query)\""
        }
    }

    private func addRule() {
        let rule: GraphGroupRule
        switch newRuleTypeSelection {
        case 0:
            rule = GraphGroupRule(
                name: "By Top-Level Folder",
                ruleType: .topLevelAncestor,
                hexColor: newRuleColorHex
            )
        case 1:
            let tag = newRuleValue.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            rule = GraphGroupRule(
                name: "Tag: #\(tag)",
                ruleType: .tag(tag),
                hexColor: newRuleColorHex
            )
        case 2:
            let query = newRuleValue.trimmingCharacters(in: .whitespacesAndNewlines)
            rule = GraphGroupRule(
                name: "Query: \"\(query)\"",
                ruleType: .searchQuery(query),
                hexColor: newRuleColorHex
            )
        default:
            return
        }

        groupRules.append(rule)
        newRuleValue = ""
    }
}
