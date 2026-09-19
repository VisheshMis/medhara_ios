import SwiftUI

public struct GraphControlsSheet: View {
    @ObservedObject public var simulation: ForceSimulation
    @Binding public var groupRules: [GraphGroupRule]
    @Environment(\.dismiss) private var dismiss

    @State private var newRuleName: String = ""
    @State private var newRuleTypeSelection: Int = 0 // 0: Top-level Ancestor, 1: Tag, 2: Search Query
    @State private var newRuleValue: String = ""
    @State private var newRuleColorHex: String = "#00E5FF"

    private let presetColors = ["#00E676", "#00E5FF", "#7C4DFF", "#FF9100", "#FF4081", "#FFEA00", "#651FFF", "#00B0FF"]

    public init(simulation: ForceSimulation, groupRules: Binding<[GraphGroupRule]>) {
        self.simulation = simulation
        self._groupRules = groupRules
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack {
                Label("Graph Controls & Rules", systemImage: "slider.horizontal.3")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Physics Section
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("PHYSICS SIMULATION")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button(simulation.config.isFrozen ? "Resume Simulation" : "Freeze Simulation") {
                                    simulation.toggleFreeze()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(simulation.config.isFrozen ? .green : .orange)
                                .controlSize(.small)
                            }

                            // Repel Force
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Repel Force:")
                                        .font(.subheadline)
                                    Spacer()
                                    Text(String(format: "%.0f", simulation.config.repelForce))
                                        .font(.caption.monospaced())
                                        .foregroundColor(.secondary)
                                }
                                Slider(value: $simulation.config.repelForce, in: -800...(-80), step: 10)
                            }

                            // Link Force
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Link Attraction Force:")
                                        .font(.subheadline)
                                    Spacer()
                                    Text(String(format: "%.3f", simulation.config.linkForce))
                                        .font(.caption.monospaced())
                                        .foregroundColor(.secondary)
                                }
                                Slider(value: $simulation.config.linkForce, in: 0.01...0.25, step: 0.005)
                            }

                            // Link Distance
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Link Rest Distance:")
                                        .font(.subheadline)
                                    Spacer()
                                    Text(String(format: "%.0f pt", simulation.config.linkDistance))
                                        .font(.caption.monospaced())
                                        .foregroundColor(.secondary)
                                }
                                Slider(value: $simulation.config.linkDistance, in: 30...200, step: 5)
                            }

                            // Center Gravity
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Center Gravity:")
                                        .font(.subheadline)
                                    Spacer()
                                    Text(String(format: "%.3f", simulation.config.centerGravity))
                                        .font(.caption.monospaced())
                                        .foregroundColor(.secondary)
                                }
                                Slider(value: $simulation.config.centerGravity, in: 0.005...0.12, step: 0.005)
                            }

                            Button("Reset Physics to Defaults") {
                                simulation.config = GraphPhysicsConfig()
                                simulation.config.save()
                                simulation.restart(targetAlpha: 0.8)
                            }
                            .controlSize(.small)
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
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
