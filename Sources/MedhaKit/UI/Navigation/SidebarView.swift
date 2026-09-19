import SwiftUI

public struct SidebarView: View {
    @ObservedObject public var store: BlockStore
    @State private var isCreatingNotebook: Bool = false
    @State private var newNotebookName: String = ""

    public var body: some View {
        List {
            // Top-Left Recurring Focus Timer Widget
            Section {
                TopLeftTimerView(timerManager: store.timerManager)
                    .listRowInsets(EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6))
            }

            // Spaced Repetition & Memory Palace Section
            Section("STUDY & RETENTION") {
                Button(action: {
                    store.activeMainView = .editor
                    store.selectedNotebookId = nil
                    store.selectedFilter = nil
                    store.isDocumentTreeVisible = true
                    store.loadDocuments()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .foregroundColor(store.activeMainView == .editor && store.selectedNotebookId == nil ? .accentColor : .secondary)
                            .frame(width: 18)
                        Text("Notes & Folders")
                            .font(.system(size: 13, weight: store.activeMainView == .editor && store.selectedNotebookId == nil ? .semibold : .regular))
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(store.activeMainView == .editor && store.selectedNotebookId == nil ? Color.accentColor.opacity(0.15) : Color.clear)

                Button(action: {
                    store.activeMainView = .flashcards
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.on.rectangle.angled")
                            .foregroundColor(store.activeMainView == .flashcards ? .accentColor : .secondary)
                            .frame(width: 18)
                        Text("Flashcards (FSRS)")
                            .font(.system(size: 13, weight: store.activeMainView == .flashcards ? .semibold : .regular))
                        Spacer()

                        let due = store.dueFlashcards.count
                        if due > 0 {
                            Text("\(due)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(store.activeMainView == .flashcards ? Color.accentColor.opacity(0.15) : Color.clear)

                Button(action: {
                    store.activeMainView = .palace
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "building.columns.fill")
                            .foregroundColor(store.activeMainView == .palace ? .accentColor : .secondary)
                            .frame(width: 18)
                        Text("Memory Palace (2D)")
                            .font(.system(size: 13, weight: store.activeMainView == .palace ? .semibold : .regular))
                        Spacer()

                        Text("\(store.loci.count)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(store.activeMainView == .palace ? Color.accentColor.opacity(0.15) : Color.clear)
            }

            // Notebooks Section
            Section {
                ForEach(store.notebooks) { nb in
                    Button(action: {
                        store.activeMainView = .editor
                        store.isDocumentTreeVisible = true
                        store.selectNotebook(id: nb.id)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: nb.icon ?? "book.closed.fill")
                                .foregroundColor(store.activeMainView == .editor && store.selectedNotebookId == nb.id ? .accentColor : .secondary)
                                .frame(width: 18)
                            Text(nb.name)
                                .font(.system(size: 13, weight: store.activeMainView == .editor && store.selectedNotebookId == nb.id ? .semibold : .regular))
                                .lineLimit(1)
                            Spacer()

                            // Document count badge
                            let docCount = store.documents.filter({ $0.notebookId == nb.id }).count
                            Text("\(docCount)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                                .cornerRadius(8)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(store.activeMainView == .editor && store.selectedNotebookId == nb.id ? Color.accentColor.opacity(0.15) : Color.clear)
                    .contextMenu {
                        Button("New Document") {
                            store.createDocument(notebookId: nb.id)
                        }
                        Divider()
                        Button("Delete Notebook", role: .destructive) {
                            store.deleteNotebook(id: nb.id)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("NOTEBOOKS")
                    Spacer()
                    Button(action: { isCreatingNotebook = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $isCreatingNotebook) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("New Notebook")
                                .font(.system(size: 12, weight: .bold))
                            TextField("Notebook name", text: $newNotebookName)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                            HStack {
                                Button("Cancel") {
                                    isCreatingNotebook = false
                                    newNotebookName = ""
                                }
                                Spacer()
                                Button("Create") {
                                    store.createNotebook(name: newNotebookName)
                                    isCreatingNotebook = false
                                    newNotebookName = ""
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(newNotebookName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                        .padding(12)
                        .frame(width: 220)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
                Text("SQLite WAL • FTS5 Active")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
    }
}
