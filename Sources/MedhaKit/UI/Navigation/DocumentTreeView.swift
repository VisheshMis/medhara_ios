import SwiftUI

public struct DocumentRowView: View {
    public let node: DocTreeNode
    public let isSelected: Bool
    public let isExpanded: Bool
    public let onSelect: () -> Void
    public let onToggleExpand: () -> Void
    public let onNewSubnote: () -> Void
    public let onDelete: () -> Void

    @State private var isHovered: Bool = false

    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                // Indentation based on tree depth
                if node.level > 0 {
                    Spacer()
                        .frame(width: CGFloat(node.level * 14))
                }

                // Disclosure Chevron for notes with sub-notes
                if node.hasChildren {
                    Button(action: onToggleExpand) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: 14, height: 14)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()
                        .frame(width: 14)
                }

                // Document Icon
                Image(systemName: node.hasChildren ? (isExpanded ? "folder.fill" : "folder") : "doc.text")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.system(size: 12))
                    .frame(width: 14)

                // Document Title
                Text(node.doc.content.isEmpty ? "Untitled Note" : node.doc.content)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                // Sub-note count badge if children exist
                if node.hasChildren {
                    Text("\(node.children.count)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                        .cornerRadius(4)
                }

                // Quick Add Sub-note Button on Hover / Selection
                if isHovered || isSelected {
                    Button(action: onNewSubnote) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 18, height: 18)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("Add Sub-note")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor.opacity(0.15) : (isHovered ? Color(NSColor.controlBackgroundColor).opacity(0.5) : Color.clear))
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("New Sub-note") { onNewSubnote() }
            if node.hasChildren {
                Button(isExpanded ? "Collapse Sub-notes" : "Expand Sub-notes") { onToggleExpand() }
            }
            Divider()
            Button("Delete Note & Sub-notes", role: .destructive) { onDelete() }
        }
    }
}

public struct DocumentTreeView: View {
    @ObservedObject public var store: BlockStore
    @State private var searchFilter: String = ""

    private var displayedTreeNodes: [DocTreeNode] {
        store.getFilteredDocTree(filter: searchFilter)
    }

    private var sectionTitle: String {
        if let nb = store.notebooks.first(where: { $0.id == store.selectedNotebookId }) {
            return nb.name
        }
        return "Notes & Folders"
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header & Actions
            HStack(spacing: 8) {
                Text(sectionTitle)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                Spacer()

                // Expand / Collapse All button
                Button(action: {
                    if store.expandedDocIds.isEmpty {
                        store.expandAll()
                    } else {
                        store.collapseAll()
                    }
                }) {
                    Image(systemName: store.expandedDocIds.isEmpty ? "chevron.right.2" : "chevron.down.2")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(store.expandedDocIds.isEmpty ? "Expand All Notes" : "Collapse All Notes")

                // New Root Document Button
                Button(action: {
                    store.createDocument()
                }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("New Note (⌘N)")

                // Hide Notes Tab Button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.isDocumentTreeVisible = false
                    }
                }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Hide Notes Tab")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 6)

            // Local Filter Field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                TextField("Filter notes & sub-notes...", text: $searchFilter)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchFilter.isEmpty {
                    Button(action: { searchFilter = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .padding(.horizontal, 10)
            .padding(.bottom, 8)

            Divider()

            // Hierarchical Document Tree List
            if displayedTreeNodes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 26))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(searchFilter.isEmpty ? "No Notes in Notebook" : "No Matching Notes")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    if searchFilter.isEmpty {
                        Button("Create Note") {
                            store.createDocument()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(displayedTreeNodes) { node in
                            DocumentRowView(
                                node: node,
                                isSelected: node.doc.id == store.selectedDocId,
                                isExpanded: store.isDocExpanded(id: node.doc.id),
                                onSelect: { store.selectDocument(id: node.doc.id) },
                                onToggleExpand: { store.toggleDocExpansion(id: node.doc.id) },
                                onNewSubnote: { store.createDocument(notebookId: node.doc.notebookId, parentDocId: node.doc.id) },
                                onDelete: { store.deleteDocument(docId: node.doc.id) }
                            )
                        }
                    }
                    .padding(6)
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }
}
