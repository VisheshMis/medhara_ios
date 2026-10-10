import SwiftUI
import AppKit

public struct CanvasUnifiedFloatingToolbar: View {
    @ObservedObject public var store: BlockStore
    @Binding public var isHandToolActive: Bool
    @Binding public var isConnectorToolActive: Bool
    @Binding public var connectorRoutingMode: ConnectorRoutingType

    // Callbacks to insert items directly into canvas
    public let onInsertShape: (CanvasShapeType) -> Void
    public let onInsertTextBlock: () -> Void
    public let onPromptMediaUpload: () -> Void
    public let onPromptLinkNote: () -> Void

    public init(
        store: BlockStore,
        isHandToolActive: Binding<Bool>,
        isConnectorToolActive: Binding<Bool>,
        connectorRoutingMode: Binding<ConnectorRoutingType>,
        onInsertShape: @escaping (CanvasShapeType) -> Void,
        onInsertTextBlock: @escaping () -> Void,
        onPromptMediaUpload: @escaping () -> Void,
        onPromptLinkNote: @escaping () -> Void
    ) {
        self.store = store
        self._isHandToolActive = isHandToolActive
        self._isConnectorToolActive = isConnectorToolActive
        self._connectorRoutingMode = connectorRoutingMode
        self.onInsertShape = onInsertShape
        self.onInsertTextBlock = onInsertTextBlock
        self.onPromptMediaUpload = onPromptMediaUpload
        self.onPromptLinkNote = onPromptLinkNote
    }

    public var body: some View {
        HStack(spacing: 6) {
            // MARK: - Hand / Pan Tool Toggle
            Button(action: {
                isHandToolActive.toggle()
                if isHandToolActive {
                    isConnectorToolActive = false
                }
            }) {
                Image(systemName: isHandToolActive ? "hand.raised.fill" : "hand.raised")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isHandToolActive ? .accentColor : .primary)
                    .frame(width: 28, height: 28)
                    .background(isHandToolActive ? Color.accentColor.opacity(0.18) : Color.clear)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Pan / Hand Tool (Spacebar)")

            Divider()
                .frame(height: 18)

            // MARK: - Shapes Menu
            Menu {
                Button(action: { onInsertShape(.rectangle) }) {
                    Label("Process Box (Rectangle)", systemImage: "square")
                }
                Button(action: { onInsertShape(.roundedRectangle) }) {
                    Label("Rounded Card", systemImage: "square.fill")
                }
                Button(action: { onInsertShape(.diamond) }) {
                    Label("Decision Node (Diamond)", systemImage: "diamond")
                }
                Button(action: { onInsertShape(.ellipse) }) {
                    Label("Terminator (Circle / Oval)", systemImage: "circle")
                }
                Divider()
                Button(action: { onInsertShape(.group) }) {
                    Label("Container Group Frame", systemImage: "square.dashed")
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "square.on.circle")
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9))
                }
                .foregroundColor(.primary)
                .frame(height: 28)
                .padding(.horizontal, 6)
                .background(Color.clear)
                .cornerRadius(6)
            }
            .menuStyle(.borderlessButton)
            .help("Insert Flowchart & Diagram Shapes")

            // MARK: - Smart Dynamic Connector Tool
            Menu {
                Button(action: {
                    connectorRoutingMode = .orthogonal
                    isConnectorToolActive = true
                    isHandToolActive = false
                }) {
                    HStack {
                        Label("Orthogonal (90° Manhattan)", systemImage: "arrow.turn.down.right")
                        if isConnectorToolActive && connectorRoutingMode == .orthogonal {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Button(action: {
                    connectorRoutingMode = .curved
                    isConnectorToolActive = true
                    isHandToolActive = false
                }) {
                    HStack {
                        Label("Curved (Smooth Bezier)", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                        if isConnectorToolActive && connectorRoutingMode == .curved {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Button(action: {
                    connectorRoutingMode = .straight
                    isConnectorToolActive = true
                    isHandToolActive = false
                }) {
                    HStack {
                        Label("Straight Line", systemImage: "line.diagonal")
                        if isConnectorToolActive && connectorRoutingMode == .straight {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Divider()
                Button(action: {
                    isConnectorToolActive.toggle()
                    if isConnectorToolActive {
                        isHandToolActive = false
                    }
                }) {
                    Text(isConnectorToolActive ? "Deactivate Connector Tool" : "Activate Connector Tool")
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: isConnectorToolActive ? "point.filled.topleft.down.curvedto.point.bottomright.up" : "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isConnectorToolActive ? .accentColor : .primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9))
                }
                .frame(height: 28)
                .padding(.horizontal, 6)
                .background(isConnectorToolActive ? Color.accentColor.opacity(0.18) : Color.clear)
                .cornerRadius(6)
            }
            .menuStyle(.borderlessButton)
            .help("Smart Dynamic Connectors (Click cardinal port and drag to target port)")

            // MARK: - Text Block
            Button(action: onInsertTextBlock) {
                HStack(spacing: 3) {
                    Image(systemName: "text.cursor")
                        .font(.system(size: 13, weight: .medium))
                }
                .frame(width: 28, height: 28)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Insert Rich Text Block")

            // MARK: - Media Upload
            Button(action: onPromptMediaUpload) {
                HStack(spacing: 3) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 13, weight: .medium))
                }
                .frame(width: 28, height: 28)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Import Rich Media (Images, Videos, Audio, PDFs)")

            // MARK: - Link Note Card
            Button(action: onPromptLinkNote) {
                HStack(spacing: 3) {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 13, weight: .medium))
                }
                .frame(width: 28, height: 28)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Universal Note Link (Attach or reference another note on canvas)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.14), radius: 10, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
        )
    }
}
