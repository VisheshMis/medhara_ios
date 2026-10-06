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
                    let isSelected = store.activeMainView == .editor && store.selectedNotebookId == nil
                    HStack(spacing: 9) {
                        Image(systemName: "doc.text")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(MedhaTheme.Colors.notesAccent)
                            .frame(width: 18)
                        Text("Notes & Folders")
                            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? MedhaTheme.Colors.textPrimary : MedhaTheme.Colors.textSecondary)
                        Spacer()
                    }
                    .medhaRow(isSelected: isSelected, tint: MedhaTheme.Colors.notesAccent)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)

                Button(action: {
                    store.activeMainView = .graph
                }) {
                    let isSelected = store.activeMainView == .graph
                    HStack(spacing: 9) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(MedhaTheme.Colors.graphAccent)
                            .frame(width: 18)
                        Text("Knowledge Graph")
                            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? MedhaTheme.Colors.textPrimary : MedhaTheme.Colors.textSecondary)
                        Spacer()
                    }
                    .medhaRow(isSelected: isSelected, tint: MedhaTheme.Colors.graphAccent)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)

                Button(action: {
                    store.activeMainView = .flashcards
                }) {
                    let isSelected = store.activeMainView == .flashcards
                    HStack(spacing: 9) {
                        Image(systemName: "rectangle.on.rectangle.angled")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(MedhaTheme.Colors.flashcardsAccent)
                            .frame(width: 18)
                        Text("Flashcards (FSRS)")
                            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? MedhaTheme.Colors.textPrimary : MedhaTheme.Colors.textSecondary)
                        Spacer()

                        let due = store.dueFlashcards.count
                        if due > 0 {
                            Text("\(due)")
                                .font(MedhaTheme.Typography.monoCounter)
                                .foregroundColor(MedhaTheme.Colors.danger)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(MedhaTheme.Colors.danger.opacity(0.14))
                                .clipShape(Capsule(style: .continuous))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(MedhaTheme.Colors.danger.opacity(0.25), lineWidth: 1)
                                )
                        }
                    }
                    .medhaRow(isSelected: isSelected, tint: MedhaTheme.Colors.flashcardsAccent)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)

                Button(action: {
                    store.activeMainView = .palace
                }) {
                    let isSelected = store.activeMainView == .palace
                    HStack(spacing: 9) {
                        Image(systemName: "building.columns.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(MedhaTheme.Colors.palaceAccent)
                            .frame(width: 18)
                        Text("Memory Palace (2D)")
                            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? MedhaTheme.Colors.textPrimary : MedhaTheme.Colors.textSecondary)
                        Spacer()

                        Text("\(store.loci.count)")
                            .font(MedhaTheme.Typography.monoCounter)
                            .foregroundColor(MedhaTheme.Colors.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(MedhaTheme.Colors.bgSurface)
                            .clipShape(Capsule(style: .continuous))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(MedhaTheme.Colors.borderHairline, lineWidth: 1)
                            )
                    }
                    .medhaRow(isSelected: isSelected, tint: MedhaTheme.Colors.palaceAccent)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
            }

            // Notebooks Section
            Section {
                ForEach(store.notebooks) { nb in
                    Button(action: {
                        store.activeMainView = .editor
                        store.isDocumentTreeVisible = true
                        store.selectNotebook(id: nb.id)
                    }) {
                        let isSelected = store.activeMainView == .editor && store.selectedNotebookId == nb.id
                        HStack(spacing: 9) {
                            Image(systemName: nb.icon ?? "book.closed.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(isSelected ? MedhaTheme.Colors.accent : MedhaTheme.Colors.textTertiary)
                                .frame(width: 18)
                            Text(nb.name)
                                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? MedhaTheme.Colors.textPrimary : MedhaTheme.Colors.textSecondary)
                                .lineLimit(1)
                            Spacer()

                            // Document count badge
                            let docCount = store.documents.filter({ $0.notebookId == nb.id }).count
                            Text("\(docCount)")
                                .font(MedhaTheme.Typography.monoCounter)
                                .foregroundColor(MedhaTheme.Colors.textTertiary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(MedhaTheme.Colors.bgSurface)
                                .clipShape(Capsule(style: .continuous))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(MedhaTheme.Colors.borderHairline, lineWidth: 1)
                                )
                        }
                        .medhaRow(isSelected: isSelected, tint: MedhaTheme.Colors.accent)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
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
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(MedhaTheme.Colors.textTertiary)
                    Spacer()
                    Button(action: { isCreatingNotebook = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(MedhaTheme.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $isCreatingNotebook) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("New Notebook")
                                .font(MedhaTheme.Typography.headline)
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
            HStack(spacing: 7) {
                Circle()
                    .fill(MedhaTheme.Colors.success)
                    .frame(width: 6.5, height: 6.5)
                Text("SQLite WAL • FTS5 Active")
                    .font(MedhaTheme.Typography.micro)
                    .foregroundColor(MedhaTheme.Colors.textTertiary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .overlay(
                Divider().opacity(0.4),
                alignment: .top
            )
        }
    }
}
