import SwiftUI

public struct InkNoteEditorView: View {
    @ObservedObject public var store: BlockStore
    public let doc: Block

    @State private var currentStrokes: [InkStroke] = []
    @State private var isLoaded: Bool = false

    public init(store: BlockStore, doc: Block) {
        self.store = store
        self.doc = doc
    }

    private var ancestryBreadcrumbsView: some View {
        let ancestry = store.getDocAncestry(for: doc.id)
        return Group {
            if ancestry.count > 1 {
                HStack(spacing: 4) {
                    ForEach(Array(ancestry.dropLast().enumerated()), id: \.element.id) { index, ancestor in
                        Button(action: {
                            store.selectDocument(id: ancestor.id)
                        }) {
                            Text(ancestor.content.isEmpty ? "Untitled Note" : ancestor.content)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)

                        Text("/")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Note Header
            VStack(alignment: .leading, spacing: 8) {
                ancestryBreadcrumbsView

                // Title bar with Ink Note badge & page info
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "pencil.tip")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)

                    TextField("Untitled Handwritten Note", text: Binding(
                        get: { doc.content },
                        set: { store.renameDocument(docId: doc.id, newTitle: $0) }
                    ))
                    .font(.system(size: 24, weight: .bold))
                    .textFieldStyle(.plain)

                    Spacer()

                    // Template & page info badge
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                        Text("\(max(1, store.inkPages.count)) Page\(store.inkPages.count > 1 ? "s" : "")")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Main Interactive Ink Canvas Area
            ZStack(alignment: .top) {
                // Background desk area
                Color(NSColor.windowBackgroundColor)
                    .ignoresSafeArea()

                // Scrollable Page Canvas
                ScrollView([.vertical, .horizontal], showsIndicators: true) {
                    VStack(spacing: 32) {
                        // Continuous A4 Sheet Container
                        InkCanvasRepresentable(
                            docId: doc.id,
                            pageIndex: 0,
                            templateType: store.activeInkTemplate,
                            strokes: currentStrokes,
                            activeTool: store.activeInkTool,
                            activeColorHex: store.activeInkColorHex,
                            activeWidth: store.activeInkWidth,
                            onStrokesChanged: { newStrokes in
                                recordStrokeHistory(newStrokes: newStrokes)
                            }
                        )
                        .frame(width: 794, height: 1123) // Standard A4 Aspect Ratio
                        .background(Color.white)
                        .cornerRadius(4)
                        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
                        .padding(.vertical, 32)
                        .padding(.horizontal, 24)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Floating Dynamic Ink Toolbar
                InkToolbarView(
                    store: store,
                    onUndo: performUndo,
                    onRedo: performRedo,
                    canUndo: !store.inkUndoStack.isEmpty,
                    canRedo: !store.inkRedoStack.isEmpty
                )
                .padding(.top, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            loadInitialStrokes()
        }
        .onChange(of: doc.id) { _, _ in
            loadInitialStrokes()
        }
    }

    private func loadInitialStrokes() {
        if let firstPage = store.inkPages.first {
            let payload = InkPagePayload.deserialize(from: firstPage.strokesData)
            self.currentStrokes = payload.strokes
            self.store.activeInkTemplate = firstPage.templateType
        } else {
            self.currentStrokes = []
        }
        store.inkUndoStack.removeAll()
        store.inkRedoStack.removeAll()
        isLoaded = true
    }

    private func recordStrokeHistory(newStrokes: [InkStroke]) {
        // Push old state to undo stack
        store.inkUndoStack.append(currentStrokes)
        if store.inkUndoStack.count > 50 {
            store.inkUndoStack.removeFirst()
        }
        store.inkRedoStack.removeAll()

        self.currentStrokes = newStrokes

        // Persist to SQLite
        store.saveInkPageStrokes(pageIndex: 0, strokes: newStrokes)
    }

    private func performUndo() {
        guard let prev = store.inkUndoStack.popLast() else { return }
        store.inkRedoStack.append(currentStrokes)
        self.currentStrokes = prev
        store.saveInkPageStrokes(pageIndex: 0, strokes: prev)
    }

    private func performRedo() {
        guard let next = store.inkRedoStack.popLast() else { return }
        store.inkUndoStack.append(currentStrokes)
        self.currentStrokes = next
        store.saveInkPageStrokes(pageIndex: 0, strokes: next)
    }
}
