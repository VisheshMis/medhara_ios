import SwiftUI

public struct BlockEditorView: View {
    @ObservedObject public var store: BlockStore
    @State private var isIconPickerPresented: Bool = false
    @State private var isAddFlashcardPresented: Bool = false

    private let availableIcons = ["doc.text", "brain.head.profile", "lightbulb", "sparkles", "folder", "star", "bookmark", "tag", "checklist", "terminal", "cube"]

    public var body: some View {
        Group {
            if let doc = store.currentDoc {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Document Header
                            VStack(alignment: .leading, spacing: 8) {
                                // Breadcrumbs & Header Actions
                                breadcrumbsView(doc: doc)

                                // Document Title
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    TextField("Untitled Document", text: Binding(
                                        get: { doc.content },
                                        set: { store.renameDocument(docId: doc.id, newTitle: $0) }
                                    ))
                                    .font(.system(size: 28, weight: .bold))
                                    .textFieldStyle(.plain)
                                }
                            }
                            .padding(.bottom, 6)

                            // Nested Subfolders & Documents in this Folder
                            subfoldersGalleryView(doc: doc)

                            Divider()

                            // Continuous Block Stream
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(store.blocks.enumerated()), id: \.element.id) { index, block in
                                    BlockRowView(
                                        store: store,
                                        block: block,
                                        isFirst: index == 0,
                                        isLast: index == store.blocks.count - 1
                                    )
                                    .id(block.id)
                                }
                            }

                            // Clickable bottom buffer to add new block
                            Color.clear
                                .frame(height: 40)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    store.createBlock(type: .paragraph, content: "")
                                }

                            // Flashcards Attached to this Folder / Note
                            flashcardsSectionView(doc: doc)
                        }
                        .padding(.horizontal, 36)
                        .padding(.top, 24)
                        .padding(.bottom, 48)
                    }
                    .onChange(of: store.focusedBlockId) { _, newId in
                        if let id = newId {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                    .sheet(isPresented: $isAddFlashcardPresented) {
                        AddFlashcardSheet(
                            store: store,
                            isPresented: $isAddFlashcardPresented,
                            preselectedDeckId: Deck.notesDefaultId,
                            preselectedDocId: doc.id
                        )
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("No Document Selected")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("Select a document from the tree, or press ⌘N to create a new page.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.8))
                    Button(action: {
                        store.createDocument(title: "Untitled Document")
                    }) {
                        Label("New Document", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }

    private func docWordCount() -> Int {
        var count = store.currentDoc?.content.components(separatedBy: .whitespacesAndNewlines).filter({ !$0.isEmpty }).count ?? 0
        for b in store.blocks {
            count += b.content.components(separatedBy: .whitespacesAndNewlines).filter({ !$0.isEmpty }).count
        }
        return count
    }

    private func breadcrumbsView(doc: Block) -> some View {
        let ancestry = store.getDocAncestry(for: doc.id)

        return HStack(spacing: 5) {
            if let nb = store.notebooks.first(where: { $0.id == doc.notebookId }) {
                Button(action: { store.selectNotebook(id: nb.id) }) {
                    HStack(spacing: 4) {
                        Image(systemName: nb.icon ?? "book.closed.fill")
                            .font(.system(size: 11))
                        Text(nb.name)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }

            ForEach(Array(ancestry.enumerated()), id: \.element.id) { index, ancestor in
                let isLast = index == ancestry.count - 1
                if isLast {
                    Text(ancestor.content.isEmpty ? "Untitled" : ancestor.content)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Button(action: { store.selectDocument(id: ancestor.id) }) {
                        Text(ancestor.content.isEmpty ? "Untitled" : ancestor.content)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }

            Spacer()

            // "+ Sub-note" quick button in editor header
            Button(action: {
                store.createDocument(notebookId: doc.notebookId, parentDocId: doc.id)
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                    Text("Sub-note")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .help("Create a sub-note nested under this document")

            // Word count & block count pill
            HStack(spacing: 6) {
                Text("\(docWordCount()) words")
                Text("•")
                Text("\(store.blocks.count) blocks")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.secondary.opacity(0.8))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(4)
        }
    }

    private func subfoldersGalleryView(doc: Block) -> some View {
        let children = store.getChildDocuments(for: doc.id)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Nested Subfolders & Documents (\(children.count))", systemImage: "folder")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    store.createDocument(notebookId: doc.notebookId, parentDocId: doc.id)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Add Subfolder / Document")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }

            if !children.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 240))], spacing: 8) {
                    ForEach(children) { child in
                        Button(action: {
                            store.selectDocument(id: child.id)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: store.getChildDocuments(for: child.id).isEmpty ? "doc.text" : "folder.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 12))

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(child.content.isEmpty ? "Untitled Note" : child.content)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)

                                    let subCount = store.getChildDocuments(for: child.id).count
                                    if subCount > 0 {
                                        Text("\(subCount) subfolders")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
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
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
        .cornerRadius(8)
    }

    private func flashcardsSectionView(doc: Block) -> some View {
        let cards = store.flashcardsForCurrentDoc

        return VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.top, 16)

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .foregroundColor(.accentColor)
                    Text("FLASHCARDS IN THIS FOLDER (\(cards.count))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Generate from Note button
                Button(action: {
                    generateFlashcardsFromNote(doc: doc)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Extract Cards from Note")
                    }
                    .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                // Add Card button
                Button(action: {
                    isAddFlashcardPresented = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add Card")
                    }
                    .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if cards.isEmpty {
                HStack {
                    Text("No flashcards attached to this folder yet. Extract from note content or add new cards.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                .cornerRadius(6)
            } else {
                VStack(spacing: 6) {
                    ForEach(cards) { card in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.front)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text(card.back)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Text(card.fsrsState.displayName)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.12))
                                .cornerRadius(4)

                            Button(action: {
                                store.deleteFlashcard(id: card.id)
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }

    private func generateFlashcardsFromNote(doc: Block) {
        for block in store.blocks {
            if block.type == .callout && !block.content.isEmpty {
                store.createFlashcard(
                    docId: doc.id,
                    front: "Key Concept: \(doc.content)",
                    back: block.content,
                    sourceBlockId: block.id
                )
            } else if block.isHeading && !block.content.isEmpty {
                if let idx = store.blocks.firstIndex(where: { $0.id == block.id }), idx + 1 < store.blocks.count {
                    let next = store.blocks[idx + 1]
                    if next.type == .paragraph && !next.content.isEmpty {
                        store.createFlashcard(
                            docId: doc.id,
                            front: "What is \(block.content)?",
                            back: next.content,
                            sourceBlockId: next.id
                        )
                    }
                }
            }
        }
    }
}
