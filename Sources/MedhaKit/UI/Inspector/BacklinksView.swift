import SwiftUI

public struct BacklinksView: View {
    @ObservedObject public var store: BlockStore

    private var backlinks: [BacklinkItem] {
        guard let docId = store.selectedDocId else { return [] }
        return store.getBacklinks(for: docId)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if backlinks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No Backlinks Yet")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("Link to this document from other notes using [[Document Title]] or ((block-id)) to see backlinks here.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(16)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(backlinks.count) Incoming Reference\(backlinks.count == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.top, 6)

                        ForEach(backlinks) { item in
                            Button(action: {
                                store.selectDocument(id: item.block.rootDocId)
                                store.focusedBlockId = item.block.id
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 5) {
                                        Image(systemName: item.linkType == .wikiLink ? "link" : "arrow.triangle.branch")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.accentColor)
                                        Text(item.sourceDocTitle)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)

                                        Text(item.linkType == .wikiLink ? "[[...]]" : "((...))")
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.accentColor.opacity(0.12))
                                            .foregroundColor(.accentColor)
                                            .cornerRadius(3)

                                        Spacer()
                                        Image(systemName: "arrow.right.circle")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }

                                    Text(item.contextSnippet)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(8)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                }
            }
        }
    }
}
