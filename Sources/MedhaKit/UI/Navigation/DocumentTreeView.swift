import SwiftUI

public struct DocumentRowView: View {
    public let node: DocTreeNode
    public let isSelected: Bool
    public let isExpanded: Bool
    public let onSelect: () -> Void
    public let onToggleExpand: () -> Void
    public let onNewSubnote: () -> Void
    public var onNewInkSubnote: (() -> Void)? = nil
    public let onDelete: () -> Void
    public var onOpenAI: (() -> Void)? = nil

    @State private var isHovered: Bool = false

    private var nodeIcon: String {
        if node.hasChildren {
            return isExpanded ? "folder.fill" : "folder"
        }
        if node.doc.isInkDocument {
            return "pencil.tip"
        }
        return "doc.text"
    }

    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                // Indentation based on tree depth with subtle guideline
                if node.level > 0 {
                    HStack(spacing: 0) {
                        ForEach(0..<node.level, id: \.self) { _ in
                            Rectangle()
                                .fill(MedhaTheme.Colors.borderHairline)
                                .frame(width: 1)
                                .padding(.horizontal, 6)
                        }
                    }
                }

                // Disclosure Chevron for notes with sub-notes
                if node.hasChildren {
                    Button(action: onToggleExpand) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(MedhaTheme.Colors.textTertiary)
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
                Image(systemName: nodeIcon)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(isSelected ? MedhaTheme.Colors.notesAccent : (node.doc.isInkDocument ? MedhaTheme.Colors.cardLearn : MedhaTheme.Colors.textTertiary))
                    .font(.system(size: 12))
                    .frame(width: 14)

                // Document Title
                Text(node.doc.content.isEmpty ? (node.doc.isInkDocument ? "Untitled Ink Note" : "Untitled Note") : node.doc.content)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? MedhaTheme.Colors.textPrimary : MedhaTheme.Colors.textSecondary)
                    .lineLimit(1)

                Spacer()

                // Sub-note count badge if children exist
                if node.hasChildren {
                    Text("\(node.children.count)")
                        .font(MedhaTheme.Typography.monoCounter)
                        .foregroundColor(MedhaTheme.Colors.textTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(MedhaTheme.Colors.bgSurface)
                        .clipShape(Capsule(style: .continuous))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(MedhaTheme.Colors.borderHairline, lineWidth: 1)
                        )
                }

                // Quick Add Sub-note Button on Hover / Selection
                if isHovered || isSelected {
                    Button(action: onNewSubnote) {
                        Image(systemName: "plus")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(MedhaTheme.Colors.textSecondary)
                            .frame(width: 18, height: 18)
                            .background(MedhaTheme.Colors.bgSurface)
                            .clipShape(RoundedRectangle(cornerRadius: MedhaTheme.Radius.micro, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: MedhaTheme.Radius.micro, style: .continuous)
                                    .stroke(MedhaTheme.Colors.borderHairline, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Add Sub-note")
                }
            }
            .medhaRow(isSelected: isSelected, tint: MedhaTheme.Colors.notesAccent)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button(action: {
                onSelect()
                NotificationCenter.default.post(name: NSNotification.Name("TriggerFillNote"), object: node.doc.id)
            }) {
                Label("Fill Note Content & Citations (AI)", systemImage: "sparkles")
            }
            Divider()
            Button(action: {
                onSelect()
                onOpenAI?()
            }) {
                Label("Generate Downward Notes (AI)", systemImage: "point.3.filled.connected.trianglepath.dotted")
            }
            Divider()
            Button("New Sub-note") { onNewSubnote() }
            Button(action: {
                if let onNewInk = onNewInkSubnote {
                    onNewInk()
                } else {
                    onNewSubnote()
                }
            }) {
                Label("New Ink Sub-note", systemImage: "pencil.tip")
            }
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
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(MedhaTheme.Colors.textPrimary)
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
                        .foregroundColor(MedhaTheme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .help(store.expandedDocIds.isEmpty ? "Expand All Notes" : "Collapse All Notes")

                // New Root Document Button
                Button(action: {
                    store.createDocument()
                }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(MedhaTheme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .help("New Note (⌘N)")

                // New Root Ink Document Button
                Button(action: {
                    store.promptCreateInkDocument()
                }) {
                    Image(systemName: "pencil.tip")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(MedhaTheme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .help("New Handwritten Note (⌃⌘N)")

                // Hide Notes Tab Button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.isDocumentTreeVisible = false
                    }
                }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(MedhaTheme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Hide Notes Tab")
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Local Filter Field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(MedhaTheme.Colors.textTertiary)
                    .font(.system(size: 11))
                TextField("Filter notes & sub-notes...", text: $searchFilter)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchFilter.isEmpty {
                    Button(action: { searchFilter = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(MedhaTheme.Colors.textTertiary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(MedhaTheme.Colors.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: MedhaTheme.Radius.small, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: MedhaTheme.Radius.small, style: .continuous)
                    .stroke(MedhaTheme.Colors.borderHairline, lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()
                .opacity(0.4)

            // Hierarchical Document Tree List
            if displayedTreeNodes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 26))
                        .foregroundColor(MedhaTheme.Colors.textTertiary.opacity(0.5))
                    Text(searchFilter.isEmpty ? "No Notes in Notebook" : "No Matching Notes")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(MedhaTheme.Colors.textTertiary)
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
                                onNewInkSubnote: { store.promptCreateInkDocument(notebookId: node.doc.notebookId, parentDocId: node.doc.id) },
                                onDelete: { store.deleteDocument(docId: node.doc.id) },
                                onOpenAI: { store.isNotesAIAssistantPresented = true }
                            )
                        }
                    }
                    .padding(6)
                }
            }
        }
        .background(MedhaTheme.Colors.bgSurface.opacity(0.4))
    }
}
