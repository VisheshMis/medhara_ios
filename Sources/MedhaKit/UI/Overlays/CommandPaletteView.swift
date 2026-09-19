import SwiftUI

public struct CommandPaletteView: View {
    @ObservedObject public var store: BlockStore
    @Binding public var isPresented: Bool
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0

    private var results: [SearchResult] {
        store.search(query: query)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Search Input Header
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)

                TextField("Type a command or search all blocks (FTS5)...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .onSubmit {
                        if !results.isEmpty && selectedIndex < results.count {
                            selectResult(results[selectedIndex])
                        }
                    }

                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Text("ESC to close")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Results List
            if query.isEmpty {
                VStack(spacing: 12) {
                    Text("RECENT DOCUMENTS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.top, 10)

                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(store.documents.prefix(5)) { doc in
                                Button(action: {
                                    store.selectDocument(id: doc.id)
                                    isPresented = false
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "doc.text")
                                            .foregroundColor(.accentColor)
                                        Text(doc.content.isEmpty ? "Untitled Document" : doc.content)
                                            .font(.system(size: 13))
                                        Spacer()
                                        Text("Document")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(maxHeight: 260)
            } else if results.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No results matching '\(query)'")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                            Button(action: {
                                selectResult(result)
                            }) {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: result.blockType.systemIcon)
                                        .foregroundColor(index == selectedIndex ? .white : .accentColor)
                                        .frame(width: 18)
                                        .padding(.top, 2)

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(result.docTitle)
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(index == selectedIndex ? .white.opacity(0.8) : .secondary)
                                            Spacer()
                                            Text(result.blockType.displayName)
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(index == selectedIndex ? .white.opacity(0.7) : .secondary)
                                        }

                                        Text(cleanSnippet(result.snippet))
                                            .font(.system(size: 13))
                                            .foregroundColor(index == selectedIndex ? .white : .primary)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(index == selectedIndex ? Color.accentColor : Color.clear)
                                .cornerRadius(6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 320)
            }
        }
        .frame(width: 540)
        .background(.ultraThickMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.3), radius: 24, x: 0, y: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }

    private func selectResult(_ result: SearchResult) {
        store.selectDocument(id: result.rootDocId)
        store.focusedBlockId = result.blockId
        isPresented = false
    }

    private func cleanSnippet(_ text: String) -> String {
        text.replacingOccurrences(of: "【", with: "")
            .replacingOccurrences(of: "】", with: "")
    }
}
