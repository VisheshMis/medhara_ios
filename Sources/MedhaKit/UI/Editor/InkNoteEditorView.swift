import SwiftUI

public struct InkNoteEditorView: View {
    @ObservedObject public var store: BlockStore
    public let doc: Block

    @State private var isTitleFocused: Bool = false

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
                // Breadcrumbs & Parent Path
                ancestryBreadcrumbsView

                // Title bar with Ink Note badge
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

            // Ink Canvas Container (Phase 1 placeholder, Phase 3 connects InkCanvasNSView)
            ZStack {
                Color(NSColor.textBackgroundColor)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(systemName: "pencil.and.scribble")
                        .font(.system(size: 44))
                        .foregroundColor(.orange.opacity(0.8))

                    Text("Handwritten Canvas Ready")
                        .font(.system(size: 16, weight: .semibold))

                    Text("Vector ink engine, multi-page layout, and floating toolbar will connect in subsequent phases.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)

                    HStack(spacing: 12) {
                        Label("\(store.inkPages.first?.templateType.displayName ?? "Lined") Template", systemImage: store.inkPages.first?.templateType.systemIcon ?? "line.3.horizontal")
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)

                        Text("794 × 1123 pt (A4)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
