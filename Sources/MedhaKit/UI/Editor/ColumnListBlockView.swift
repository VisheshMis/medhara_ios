import SwiftUI

public struct ColumnListBlockView: View {
    @ObservedObject public var store: BlockStore
    public let block: Block
    public let isFocused: Bool

    private var childColumns: [Block] {
        store.blocks.filter { $0.parentId == block.id && $0.type == .column }
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 16) {
            if childColumns.isEmpty {
                // If columns haven't been created yet, show default 2 columns
                columnPlaceholder(index: 1)
                columnPlaceholder(index: 2)
            } else {
                ForEach(childColumns) { col in
                    ColumnCellView(store: store, columnBlock: col)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func columnPlaceholder(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Column \(index)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundColor(Color.secondary.opacity(0.3))
                .frame(minHeight: 48)
        }
        .frame(maxWidth: .infinity)
    }
}

public struct ColumnCellView: View {
    @ObservedObject public var store: BlockStore
    public let columnBlock: Block

    private var columnBlocks: [Block] {
        store.blocks.filter { $0.parentId == columnBlock.id }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if columnBlocks.isEmpty {
                Button(action: {
                    let newB = store.createBlock(type: .paragraph, content: "")
                    if let idx = store.blocks.firstIndex(where: { $0.id == newB.id }) {
                        store.blocks[idx].parentId = columnBlock.id
                    }
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add block to column")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            } else {
                ForEach(columnBlocks) { b in
                    BlockRowView(
                        store: store,
                        block: b,
                        isFirst: false,
                        isLast: false
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
