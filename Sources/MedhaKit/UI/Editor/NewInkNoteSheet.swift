import SwiftUI

public struct NewInkNoteSheet: View {
    @ObservedObject public var store: BlockStore
    public let notebookId: String?
    public let parentDocId: String?
    public let onDismiss: () -> Void

    @State private var title: String = ""
    @State private var selectedCanvasMode: InkCanvasMode = .a4Pages
    @State private var selectedTemplate: InkTemplateType = .lined

    public init(
        store: BlockStore,
        notebookId: String? = nil,
        parentDocId: String? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.store = store
        self.notebookId = notebookId
        self.parentDocId = parentDocId
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "pencil.tip")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("New Handwritten Note")
                        .font(.system(size: 17, weight: .bold))
                    Text("Choose your canvas layout and starting template")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            // Note Title Input
            VStack(alignment: .leading, spacing: 6) {
                Text("Note Title")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                TextField("Untitled Handwritten Note", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
            }

            // Canvas Format Picker (3 Cards)
            VStack(alignment: .leading, spacing: 8) {
                Text("Canvas Format")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                VStack(spacing: 10) {
                    ForEach(InkCanvasMode.allCases, id: \.rawValue) { mode in
                        canvasModeCard(mode)
                    }
                }
            }

            // Paper Template Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Background Template")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 10) {
                    ForEach(InkTemplateType.allCases, id: \.rawValue) { tmpl in
                        templateOptionButton(tmpl)
                    }
                }
            }

            Divider()
                .padding(.top, 4)

            // Action Buttons
            HStack(spacing: 12) {
                Spacer()

                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Create Note") {
                    createNote()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func canvasModeCard(_ mode: InkCanvasMode) -> some View {
        let isSelected = selectedCanvasMode == mode
        return Button(action: {
            selectedCanvasMode = mode
        }) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
                        .frame(width: 36, height: 36)
                    Image(systemName: mode.systemIcon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(mode.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.accentColor)
                        }
                    }

                    Text(mode.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.06) : Color(NSColor.controlBackgroundColor).opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.15), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func templateOptionButton(_ tmpl: InkTemplateType) -> some View {
        let isSelected = selectedTemplate == tmpl
        return Button(action: {
            selectedTemplate = tmpl
        }) {
            VStack(spacing: 6) {
                Image(systemName: tmpl.systemIcon)
                    .font(.system(size: 14))
                Text(tmpl.displayName)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.15), lineWidth: isSelected ? 1.5 : 1)
            )
            .foregroundColor(isSelected ? .accentColor : .primary)
        }
        .buttonStyle(.plain)
    }

    private func createNote() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteTitle = cleanTitle.isEmpty ? "Untitled Handwritten Note" : cleanTitle
        store.createInkDocument(
            title: noteTitle,
            notebookId: notebookId,
            parentDocId: parentDocId,
            templateType: selectedTemplate,
            canvasMode: selectedCanvasMode
        )
        onDismiss()
    }
}
