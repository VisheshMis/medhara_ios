import SwiftUI
import AppKit

public struct ToggleBlockView: View {
    @ObservedObject public var store: BlockStore
    public let block: Block
    public let isFocused: Bool
    public let onCommitReturn: () -> Void
    public let onDeleteEmpty: () -> Void
    public var onDeleteAtStart: () -> Void = {}
    public let onTab: () -> Void
    public let onShiftTab: () -> Void
    public let onArrowUp: () -> Void
    public let onArrowDown: () -> Void

    private var isCollapsed: Bool {
        block.isCollapsed ?? false
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 6) {
            // Interactive AppKit Disclosure Chevron
            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    store.toggleBlockCollapse(id: block.id)
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(MedhaTheme.Colors.textSecondary)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    .frame(width: 18, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isCollapsed ? "Expand section" : "Collapse section")
            .padding(.top, 1)

            // Header Text View
            BlockTextViewRepresentable(
                text: Binding(
                    get: { block.content },
                    set: { store.updateBlockContent(id: block.id, content: $0) }
                ),
                isFocused: isFocused,
                font: .systemFont(ofSize: 14 * store.editorZoomLevel, weight: .semibold),
                textColor: .labelColor,
                placeholder: block.type.placeholder,
                onCommitReturn: onCommitReturn,
                onDeleteEmpty: onDeleteEmpty,
                onDeleteAtStart: onDeleteAtStart,
                onTab: onTab,
                onShiftTab: onShiftTab,
                onArrowUp: onArrowUp,
                onArrowDown: onArrowDown,
                onFocus: {
                    store.focusedBlockId = block.id
                },
                onZoomIn: { store.zoomIn() },
                onZoomOut: { store.zoomOut() },
                onResetZoom: { store.resetZoom() }
            )
            .frame(minHeight: 22 * store.editorZoomLevel)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
