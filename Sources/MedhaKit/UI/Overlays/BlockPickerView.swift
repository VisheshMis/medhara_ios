import SwiftUI

public struct BlockPickerView: View {
    @ObservedObject public var store: BlockStore
    @Binding public var isPresented: Bool
    @State private var query: String = ""

    private var results: [SearchResult] {
        store.search(query: query.isEmpty ? "a" : query)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "link.badge.plus")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 15))
                Text("Select Block to Reference")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)

            Divider()

            // Filter
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                TextField("Search block content...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .padding(10)

            Divider()

            // Blocks List
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(results) { res in
                        Button(action: {
                            if let pendingId = store.blockPendingRefId {
                                store.setBlockRef(id: pendingId, targetId: res.blockId)
                            }
                            isPresented = false
                        }) {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: res.blockType.systemIcon)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 16)
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(res.docTitle)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.secondary)

                                    Text(res.rawContent.isEmpty ? "(Empty)" : res.rawContent)
                                        .font(.system(size: 12))
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .cornerRadius(4)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 280)
        }
        .frame(width: 460)
        .background(.ultraThickMaterial)
        .cornerRadius(10)
        .shadow(radius: 20)
    }
}
