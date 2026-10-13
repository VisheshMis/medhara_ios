import SwiftUI
import AppKit

public struct MathEquationBlockView: View {
    @ObservedObject public var store: BlockStore
    public let block: Block
    public let isFocused: Bool
    public var onCommitReturn: () -> Void = {}
    public var onDeleteEmpty: () -> Void = {}

    @State private var isEditing: Bool = false
    @FocusState private var isInputFocused: Bool

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isEditing || isFocused || block.content.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "function")
                            .font(.system(size: 11))
                            .foregroundColor(.purple)
                        Text("TeX Equation")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.purple)
                        Spacer()
                        Button("Done") {
                            isEditing = false
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                    }

                    TextField("e.g. E = mc^2 or \\int_{0}^{\\infty} x^2 dx", text: Binding(
                        get: { block.content },
                        set: { store.updateBlockContent(id: block.id, content: $0) }
                    ))
                    .font(.system(size: 12, design: .monospaced))
                    .textFieldStyle(.plain)
                    .focused($isInputFocused)
                    .onSubmit {
                        isEditing = false
                        onCommitReturn()
                    }
                }
                .padding(8)
                .background(Color.purple.opacity(0.08))
                .cornerRadius(6)
            } else {
                // Rendered Equation Container
                HStack {
                    Spacer()
                    Text(block.content)
                        .font(.system(size: 16, weight: .medium, design: .serif))
                        .italic()
                        .foregroundColor(MedhaTheme.Colors.textPrimary)
                    Spacer()
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(6)
                .contentShape(Rectangle())
                .onTapGesture {
                    isEditing = true
                    isInputFocused = true
                }
            }
        }
    }
}
