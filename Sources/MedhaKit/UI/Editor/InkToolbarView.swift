import SwiftUI

public struct InkToolbarView: View {
    @ObservedObject public var store: BlockStore

    public let onUndo: () -> Void
    public let onRedo: () -> Void
    public let canUndo: Bool
    public let canRedo: Bool

    private let presetColors = [
        "#1E293B", // Dark Slate / Black
        "#3B82F6", // Modern Blue
        "#EF4444", // Ruby Red
        "#10B981", // Emerald Green
        "#8B5CF6", // Purple
        "#F59E0B"  // Amber / Gold
    ]

    private let strokeWidths: [(label: String, width: Double)] = [
        ("Thin", 1.5),
        ("Medium", 3.0),
        ("Thick", 5.0),
        ("Bold", 8.0)
    ]

    public var body: some View {
        HStack(spacing: 8) {
            // MARK: - Tool Selectors
            HStack(spacing: 2) {
                toolButton(tool: .ballpoint, title: "Pen", icon: "pencil.tip")
                toolButton(tool: .fountain, title: "Fountain", icon: "signature")
                toolButton(tool: .highlighter, title: "Highlighter", icon: "highlighter")
                toolButton(tool: .eraser, title: "Eraser", icon: "eraser")
            }
            .padding(3)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
            .cornerRadius(8)

            Divider()
                .frame(height: 20)

            // MARK: - Color Palette
            HStack(spacing: 4) {
                ForEach(presetColors, id: \.self) { hex in
                    Button(action: {
                        store.activeInkColorHex = hex
                    }) {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle()
                                    .stroke(store.activeInkColorHex.uppercased() == hex.uppercased() ? Color.primary : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }

                // Native Color Picker
                ColorPicker("", selection: Binding(
                    get: { Color(hex: store.activeInkColorHex) },
                    set: { newColor in
                        if let nsColor = NSColor(newColor).usingColorSpace(.sRGB) {
                            store.activeInkColorHex = nsColor.toHex()
                        }
                    }
                ))
                .labelsHidden()
                .frame(width: 24, height: 24)
            }
            .padding(.horizontal, 4)

            Divider()
                .frame(height: 20)

            // MARK: - Stroke Width Menu
            Menu {
                ForEach(strokeWidths, id: \.label) { item in
                    Button(action: {
                        store.activeInkWidth = item.width
                    }) {
                        HStack {
                            Text(item.label)
                            if store.activeInkWidth == item.width {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.primary)
                        .frame(width: max(3, min(14, CGFloat(store.activeInkWidth * 1.5))), height: max(3, min(14, CGFloat(store.activeInkWidth * 1.5))))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Stroke Width")

            Divider()
                .frame(height: 20)

            // MARK: - Template Selector
            Menu {
                ForEach(InkTemplateType.allCases, id: \.rawValue) { template in
                    Button(action: {
                        store.setInkTemplate(template: template)
                    }) {
                        Label(template.displayName, systemImage: template.systemIcon)
                    }
                }
            } label: {
                Image(systemName: store.activeInkTemplate.systemIcon)
                    .font(.system(size: 13))
                    .padding(6)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Page Template")

            Divider()
                .frame(height: 20)

            // MARK: - Undo & Redo
            HStack(spacing: 2) {
                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 12))
                        .padding(6)
                        .foregroundColor(canUndo ? .primary : .secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .disabled(!canUndo)
                .help("Undo (⌘Z)")

                Button(action: onRedo) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 12))
                        .padding(6)
                        .foregroundColor(canRedo ? .primary : .secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .disabled(!canRedo)
                .help("Redo (⇧⌘Z)")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(VisualEffectBlur(material: .popover, blendingMode: .withinWindow))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
    }

    private func toolButton(tool: InkToolType, title: String, icon: String) -> some View {
        Button(action: {
            store.activeInkTool = tool
            store.activeInkWidth = tool.defaultWidth
        }) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(store.activeInkTool == tool ? Color.accentColor : Color.clear)
                .foregroundColor(store.activeInkTool == tool ? .white : .primary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

// MARK: - SwiftUI Color Hex Extension
extension Color {
    public init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)

        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Visual Effect Blur Helper
public struct VisualEffectBlur: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
