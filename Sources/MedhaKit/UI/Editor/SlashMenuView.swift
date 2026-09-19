import SwiftUI

public struct SlashMenuView: View {
    @ObservedObject public var store: BlockStore
    public let blockId: String
    public let onDismiss: () -> Void

    @State private var filterText: String = ""

    private var filteredTypes: [BlockType] {
        let types = BlockType.allCases.filter { $0 != .doc }
        if filterText.isEmpty { return types }
        return types.filter { $0.displayName.localizedCaseInsensitiveContains(filterText) }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                TextField("Filter block types...", text: $filterText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(5)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(filteredTypes, id: \.self) { type in
                        Button(action: {
                            store.convertBlockType(id: blockId, to: type)
                            // Clean up trailing slash from block content
                            if let block = store.getBlock(id: blockId), block.content.hasSuffix("/") {
                                let cleaned = String(block.content.dropLast())
                                store.updateBlockContent(id: blockId, content: cleaned)
                            }
                            if type == .blockRef {
                                store.blockPendingRefId = blockId
                                store.isBlockPickerPresented = true
                            }
                            onDismiss()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: type.systemIcon)
                                    .frame(width: 16)
                                    .foregroundColor(.accentColor)
                                Text(type.displayName)
                                    .font(.system(size: 12))
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .cornerRadius(4)
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .padding(8)
        .frame(width: 200)
    }
}
