import SwiftUI

public struct OutlineView: View {
    @ObservedObject public var store: BlockStore

    private var outlineItems: [DocOutlineItem] {
        guard let docId = store.selectedDocId else { return [] }
        return store.getOutline(for: docId)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if outlineItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.indent")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No Headings Found")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("Add H1, H2, or H3 blocks to generate a Table of Contents.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(16)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(outlineItems) { item in
                            Button(action: {
                                store.focusedBlockId = item.blockId
                            }) {
                                HStack(spacing: 6) {
                                    if item.level > 1 {
                                        Spacer()
                                            .frame(width: CGFloat((item.level - 1) * 12))
                                    }
                                    Text(item.level == 1 ? "H1" : (item.level == 2 ? "H2" : "H3"))
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(item.level == 1 ? .accentColor : .secondary)
                                        .frame(width: 20, alignment: .leading)

                                    Text(item.title)
                                        .font(.system(size: 12, weight: item.level == 1 ? .semibold : .regular))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .cornerRadius(4)
                        }
                    }
                    .padding(8)
                }
            }
        }
    }
}
