import SwiftUI
import AppKit

public struct BlockRowView: View {
    @ObservedObject public var store: BlockStore
    public let block: Block
    public let isFirst: Bool
    public let isLast: Bool

    @State private var isHovered: Bool = false
    @State private var isSlashMenuPresented: Bool = false
    @State private var showCopiedBadge: Bool = false
    @State private var isCommentBarPresented: Bool = false
    @State private var commentDraftText: String = ""
    @State private var blockComments: [String] = []

    private var isFocused: Bool {
        store.focusedBlockId == block.id
    }

    private var wordCount: Int {
        block.content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }

    private var charCount: Int {
        block.content.count
    }

    private var formattedLastEdited: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "Today at " + formatter.string(from: block.updatedAt)
    }

    private var indentLevel: CGFloat {
        if let parentId = block.parentId, parentId != store.selectedDocId {
            return 24
        }
        return 0
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 4) {
            // Indentation spacer
            if indentLevel > 0 {
                Spacer()
                    .frame(width: indentLevel)
            }

            // Gutter Handle (⋮⋮)
            Menu {
                // Section: Text Header
                Text("Text")
                    .font(.system(size: 11, weight: .semibold))

                // Turn into > (Screenshot 3)
                Menu("Turn into") {
                    Button(action: { store.convertBlockType(id: block.id, to: .paragraph) }) {
                        HStack {
                            Label("Text", systemImage: "textformat")
                            if block.type == .paragraph { Image(systemName: "checkmark") }
                        }
                    }
                    Button(action: { store.convertBlockType(id: block.id, to: .heading1) }) {
                        HStack {
                            Label("Heading 1", systemImage: "textformat.size.larger")
                            if block.type == .heading1 { Image(systemName: "checkmark") }
                        }
                    }
                    Button(action: { store.convertBlockType(id: block.id, to: .heading2) }) {
                        HStack {
                            Label("Heading 2", systemImage: "textformat.size")
                            if block.type == .heading2 { Image(systemName: "checkmark") }
                        }
                    }
                    Button(action: { store.convertBlockType(id: block.id, to: .heading3) }) {
                        HStack {
                            Label("Heading 3", systemImage: "textformat.size.smaller")
                            if block.type == .heading3 { Image(systemName: "checkmark") }
                        }
                    }
                    Button(action: { store.convertBlockType(id: block.id, to: .bulletList) }) {
                        HStack {
                            Label("Bulleted list", systemImage: "list.bullet")
                            if block.type == .bulletList { Image(systemName: "checkmark") }
                        }
                    }
                    Button(action: { store.convertBlockType(id: block.id, to: .taskList) }) {
                        HStack {
                            Label("To-do list", systemImage: "checkmark.square")
                            if block.type == .taskList { Image(systemName: "checkmark") }
                        }
                    }
                    Button(action: { store.convertBlockType(id: block.id, to: .toggle) }) {
                        HStack {
                            Label("Toggle list", systemImage: "chevron.right")
                            if block.type == .toggle { Image(systemName: "checkmark") }
                        }
                    }
                    Button(action: { store.convertBlockType(id: block.id, to: .codeBlock) }) {
                        HStack {
                            Label("Code", systemImage: "curlybraces")
                            if block.type == .codeBlock { Image(systemName: "checkmark") }
                        }
                    }
                    Button(action: { store.convertBlockType(id: block.id, to: .quote) }) {
                        HStack {
                            Label("Quote", systemImage: "quote.opening")
                            if block.type == .quote { Image(systemName: "checkmark") }
                        }
                    }
                    Button(action: { store.convertBlockType(id: block.id, to: .callout) }) {
                        HStack {
                            Label("Callout", systemImage: "lightbulb.fill")
                            if block.type == .callout { Image(systemName: "checkmark") }
                        }
                    }
                    Button(action: { store.convertBlockType(id: block.id, to: .table) }) {
                        HStack {
                            Label("Table", systemImage: "tablecells")
                            if block.type == .table { Image(systemName: "checkmark") }
                        }
                    }
                }

                // Color > (Screenshot 4)
                Menu("Color") {
                    Text("Text color")
                        .font(.system(size: 10, weight: .bold))
                    Button("Default text") { store.setBlockColorTint(id: block.id, tint: nil) }
                    Button("Gray text") { store.setBlockColorTint(id: block.id, tint: "gray") }
                    Button("Brown text") { store.setBlockColorTint(id: block.id, tint: "brown") }
                    Button("Orange text") { store.setBlockColorTint(id: block.id, tint: "orange") }
                    Button("Yellow text") { store.setBlockColorTint(id: block.id, tint: "yellow") }
                    Button("Green text") { store.setBlockColorTint(id: block.id, tint: "green") }
                    Button("Blue text") { store.setBlockColorTint(id: block.id, tint: "blue") }
                    Button("Purple text") { store.setBlockColorTint(id: block.id, tint: "purple") }
                    Button("Pink text") { store.setBlockColorTint(id: block.id, tint: "pink") }
                    Button("Red text") { store.setBlockColorTint(id: block.id, tint: "red") }

                    Divider()

                    Text("Background color")
                        .font(.system(size: 10, weight: .bold))
                    Button("Default background") { store.setBlockColorTint(id: block.id, tint: nil) }
                    Button("Gray background") { store.setBlockColorTint(id: block.id, tint: "bg-gray") }
                    Button("Brown background") { store.setBlockColorTint(id: block.id, tint: "bg-brown") }
                    Button("Orange background") { store.setBlockColorTint(id: block.id, tint: "bg-orange") }
                    Button("Yellow background") { store.setBlockColorTint(id: block.id, tint: "bg-yellow") }
                    Button("Green background") { store.setBlockColorTint(id: block.id, tint: "bg-green") }
                    Button("Blue background") { store.setBlockColorTint(id: block.id, tint: "bg-blue") }
                    Button("Purple background") { store.setBlockColorTint(id: block.id, tint: "bg-purple") }
                    Button("Pink background") { store.setBlockColorTint(id: block.id, tint: "bg-pink") }
                    Button("Red background") { store.setBlockColorTint(id: block.id, tint: "bg-red") }
                }

                Divider()

                // Actions matching Screenshot 2
                Button(action: copyBlockRef) {
                    HStack {
                        Label("Copy link to block", systemImage: "link")
                        Spacer()
                        Text("⌃⌘L").foregroundColor(.secondary)
                    }
                }

                Button(action: {
                    store.duplicateBlock(id: block.id)
                }) {
                    HStack {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                        Spacer()
                        Text("⌘D").foregroundColor(.secondary)
                    }
                }

                Menu("Move to") {
                    Button("Move Up") { store.moveBlock(id: block.id, direction: .up) }
                        .disabled(isFirst)
                    Button("Move Down") { store.moveBlock(id: block.id, direction: .down) }
                        .disabled(isLast)
                    Divider()
                    Button("Indent") { store.indentBlock(id: block.id) }
                    Button("Outdent") { store.outdentBlock(id: block.id) }
                }

                Button(role: .destructive, action: { store.deleteBlock(id: block.id) }) {
                    HStack {
                        Label("Delete", systemImage: "trash")
                        Spacer()
                        Text("Del").foregroundColor(.secondary)
                    }
                }
                .disabled(store.isCurrentDocLocked)

                Divider()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCommentBarPresented.toggle()
                    }
                }) {
                    HStack {
                        Label("Comment", systemImage: "bubble.left")
                        Spacer()
                        Text("⇧⌘M").foregroundColor(.secondary)
                    }
                }

                Menu("Skills") {
                    Button(action: {
                        let flashcard = Flashcard(
                            docId: block.rootDocId,
                            notebookId: store.currentDoc?.notebookId ?? "nb-default",
                            front: block.content,
                            back: "Extracted from document block",
                            sourceBlockId: block.id
                        )
                        store.createFlashcard(flashcard)
                    }) {
                        Label("Extract Flashcard", systemImage: "rectangle.stack.badge.plus")
                    }

                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(block.content, forType: .string)
                    }) {
                        Label("Copy Plain Text", systemImage: "doc.on.clipboard")
                    }
                }

                Divider()

                // Footer metadata (Screenshot 2)
                Text("Last edited by Vishesh Mishra")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(formattedLastEdited)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text("\(wordCount) words, \(charCount) characters")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            } label: {
                Image(systemName: "circle.grid.2x3.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.8))
                    .frame(width: 18, height: 22)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .frame(width: 18, height: 22)
            .opacity(isHovered || isFocused ? 1.0 : 0.0)
            .allowsHitTesting(isHovered || isFocused)
            .padding(.top, block.type == .heading1 ? 6 : (block.type == .heading2 ? 4 : 2))

            // Main Block Content View + Background Tint & Comments
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 0) {
                    switch block.type {
                    case .doc, .inkDoc:
                        EmptyView()
                    case .heading1, .heading2, .heading3:
                        HeadingBlockView(
                            store: store,
                            block: block,
                            isFocused: isFocused,
                            onCommitReturn: handleCommitReturn,
                            onDeleteEmpty: handleDeleteEmpty,
                            onDeleteAtStart: handleDeleteAtStart,
                            onArrowUp: handleArrowUp,
                            onArrowDown: handleArrowDown
                        )
                    case .paragraph:
                        ParagraphBlockView(
                            store: store,
                            block: block,
                            isFocused: isFocused,
                            onCommitReturn: handleCommitReturn,
                            onDeleteEmpty: handleDeleteEmpty,
                            onDeleteAtStart: handleDeleteAtStart,
                            onTab: { store.indentBlock(id: block.id) },
                            onShiftTab: { store.outdentBlock(id: block.id) },
                            onArrowUp: handleArrowUp,
                            onArrowDown: handleArrowDown,
                            onSlashTrigger: { isSlashMenuPresented = true }
                        )
                        .popover(isPresented: $isSlashMenuPresented, arrowEdge: .bottom) {
                            SlashMenuView(store: store, blockId: block.id) {
                                isSlashMenuPresented = false
                            }
                        }
                    case .taskList:
                        TaskBlockView(
                            store: store,
                            block: block,
                            isFocused: isFocused,
                            onCommitReturn: handleCommitReturn,
                            onDeleteEmpty: handleDeleteEmpty,
                            onDeleteAtStart: handleDeleteAtStart,
                            onTab: { store.indentBlock(id: block.id) },
                            onShiftTab: { store.outdentBlock(id: block.id) },
                            onArrowUp: handleArrowUp,
                            onArrowDown: handleArrowDown
                        )
                    case .bulletList:
                        BulletBlockView(
                            store: store,
                            block: block,
                            isFocused: isFocused,
                            onCommitReturn: handleCommitReturn,
                            onDeleteEmpty: handleDeleteEmpty,
                            onDeleteAtStart: handleDeleteAtStart,
                            onTab: { store.indentBlock(id: block.id) },
                            onShiftTab: { store.outdentBlock(id: block.id) },
                            onArrowUp: handleArrowUp,
                            onArrowDown: handleArrowDown
                        )
                    case .codeBlock:
                        CodeBlockView(
                            store: store,
                            block: block,
                            isFocused: isFocused,
                            onCommitReturn: handleCommitReturn,
                            onDeleteEmpty: handleDeleteEmpty
                        )
                    case .quote:
                        QuoteBlockView(
                            store: store,
                            block: block,
                            isFocused: isFocused,
                            onCommitReturn: handleCommitReturn,
                            onDeleteEmpty: handleDeleteEmpty,
                            onDeleteAtStart: handleDeleteAtStart,
                            onArrowUp: handleArrowUp,
                            onArrowDown: handleArrowDown
                        )
                    case .callout:
                        CalloutBlockView(
                            store: store,
                            block: block,
                            isFocused: isFocused,
                            onCommitReturn: handleCommitReturn,
                            onDeleteEmpty: handleDeleteEmpty,
                            onDeleteAtStart: handleDeleteAtStart
                        )
                    case .blockRef:
                        BlockRefView(store: store, block: block)
                    case .toggle:
                        ToggleBlockView(
                            store: store,
                            block: block,
                            isFocused: isFocused,
                            onCommitReturn: handleCommitReturn,
                            onDeleteEmpty: handleDeleteEmpty,
                            onDeleteAtStart: handleDeleteAtStart,
                            onTab: { store.indentBlock(id: block.id) },
                            onShiftTab: { store.outdentBlock(id: block.id) },
                            onArrowUp: handleArrowUp,
                            onArrowDown: handleArrowDown
                        )
                    case .table:
                        TableBlockView(
                            store: store,
                            block: block,
                            isFocused: isFocused
                        )
                    }
                }
                .padding(.horizontal, block.resolvedBgColor != nil ? 6 : 0)
                .padding(.vertical, block.resolvedBgColor != nil ? 4 : 0)
                .background(
                    Group {
                        if let bg = block.resolvedBgColor {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(bg)
                        }
                    }
                )

                // Inline Comments Bar (Screenshot 5)
                if isCommentBarPresented || !blockComments.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(blockComments, id: \.self) { comment in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Vishesh Mishra")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.secondary)
                                    Text(comment)
                                        .font(.system(size: 11))
                                        .foregroundColor(MedhaTheme.Colors.textPrimary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(4)
                        }

                        if isCommentBarPresented {
                            HStack(spacing: 8) {
                                TextField("Add a comment...", text: $commentDraftText)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12))
                                    .onSubmit {
                                        let trimmed = commentDraftText.trimmingCharacters(in: .whitespacesAndNewlines)
                                        if !trimmed.isEmpty {
                                            blockComments.append(trimmed)
                                            commentDraftText = ""
                                        }
                                    }

                                Image(systemName: "paperclip")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)

                                Image(systemName: "at")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)

                                Button(action: {
                                    let trimmed = commentDraftText.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !trimmed.isEmpty {
                                        blockComments.append(trimmed)
                                        commentDraftText = ""
                                    }
                                }) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)
                                .disabled(commentDraftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.top, 2)
                }
            }

            // Quick feedback badge when copying ref
            if showCopiedBadge {
                Text("Ref Copied!")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(4)
                    .transition(.opacity)
            }
        }
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            // Turn into > (Screenshot 3)
            Menu("Turn into") {
                Button(action: { store.convertBlockType(id: block.id, to: .paragraph) }) {
                    Label("Text", systemImage: "textformat")
                }
                Button(action: { store.convertBlockType(id: block.id, to: .heading1) }) {
                    Label("Heading 1", systemImage: "textformat.size.larger")
                }
                Button(action: { store.convertBlockType(id: block.id, to: .heading2) }) {
                    Label("Heading 2", systemImage: "textformat.size")
                }
                Button(action: { store.convertBlockType(id: block.id, to: .heading3) }) {
                    Label("Heading 3", systemImage: "textformat.size.smaller")
                }
                Button(action: { store.convertBlockType(id: block.id, to: .bulletList) }) {
                    Label("Bulleted list", systemImage: "list.bullet")
                }
                Button(action: { store.convertBlockType(id: block.id, to: .taskList) }) {
                    Label("To-do list", systemImage: "checkmark.square")
                }
                Button(action: { store.convertBlockType(id: block.id, to: .toggle) }) {
                    Label("Toggle list", systemImage: "chevron.right")
                }
                Button(action: { store.convertBlockType(id: block.id, to: .codeBlock) }) {
                    Label("Code", systemImage: "curlybraces")
                }
                Button(action: { store.convertBlockType(id: block.id, to: .quote) }) {
                    Label("Quote", systemImage: "quote.opening")
                }
                Button(action: { store.convertBlockType(id: block.id, to: .callout) }) {
                    Label("Callout", systemImage: "lightbulb.fill")
                }
                Button(action: { store.convertBlockType(id: block.id, to: .table) }) {
                    Label("Table", systemImage: "tablecells")
                }
            }

            // Color > (Screenshot 4)
            Menu("Color") {
                Text("Text color")
                    .font(.system(size: 10, weight: .bold))
                Button("Default text") { store.setBlockColorTint(id: block.id, tint: nil) }
                Button("Gray text") { store.setBlockColorTint(id: block.id, tint: "gray") }
                Button("Brown text") { store.setBlockColorTint(id: block.id, tint: "brown") }
                Button("Orange text") { store.setBlockColorTint(id: block.id, tint: "orange") }
                Button("Yellow text") { store.setBlockColorTint(id: block.id, tint: "yellow") }
                Button("Green text") { store.setBlockColorTint(id: block.id, tint: "green") }
                Button("Blue text") { store.setBlockColorTint(id: block.id, tint: "blue") }
                Button("Purple text") { store.setBlockColorTint(id: block.id, tint: "purple") }
                Button("Pink text") { store.setBlockColorTint(id: block.id, tint: "pink") }
                Button("Red text") { store.setBlockColorTint(id: block.id, tint: "red") }

                Divider()

                Text("Background color")
                    .font(.system(size: 10, weight: .bold))
                Button("Default background") { store.setBlockColorTint(id: block.id, tint: nil) }
                Button("Gray background") { store.setBlockColorTint(id: block.id, tint: "bg-gray") }
                Button("Brown background") { store.setBlockColorTint(id: block.id, tint: "bg-brown") }
                Button("Orange background") { store.setBlockColorTint(id: block.id, tint: "bg-orange") }
                Button("Yellow background") { store.setBlockColorTint(id: block.id, tint: "bg-yellow") }
                Button("Green background") { store.setBlockColorTint(id: block.id, tint: "bg-green") }
                Button("Blue background") { store.setBlockColorTint(id: block.id, tint: "bg-blue") }
                Button("Purple background") { store.setBlockColorTint(id: block.id, tint: "bg-purple") }
                Button("Pink background") { store.setBlockColorTint(id: block.id, tint: "bg-pink") }
                Button("Red background") { store.setBlockColorTint(id: block.id, tint: "bg-red") }
            }

            Divider()

            Button(action: copyBlockRef) {
                Label("Copy link to block", systemImage: "link")
            }

            Button(action: {
                store.duplicateBlock(id: block.id)
            }) {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }

            Button(role: .destructive, action: { store.deleteBlock(id: block.id) }) {
                Label("Delete", systemImage: "trash")
            }
            .disabled(store.isCurrentDocLocked)

            Divider()

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCommentBarPresented.toggle()
                }
            }) {
                Label("Comment", systemImage: "bubble.left")
            }
        }
    }

    private var topPadding: CGFloat {
        switch block.type {
        case .heading1: return 20
        case .heading2: return 16
        case .heading3: return 12
        case .callout: return 5
        default: return 2
        }
    }

    private var bottomPadding: CGFloat {
        switch block.type {
        case .heading1: return 6
        case .heading2: return 5
        case .heading3: return 4
        case .callout: return 6
        default: return 2
        }
    }

    private func copyBlockRef() {
        let refStr = "((\(block.id)))"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(refStr, forType: .string)
        withAnimation {
            showCopiedBadge = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopiedBadge = false
            }
        }
    }

    private func handleCommitReturn() {
        if block.type == .bulletList || block.type == .taskList {
            if block.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                store.convertBlockType(id: block.id, to: .paragraph)
                return
            }
            store.createBlock(after: block, type: block.type, content: "")
            return
        }
        store.createBlock(after: block, type: .paragraph, content: "")
    }

    private func handleDeleteEmpty() {
        if indentLevel > 0 {
            store.outdentBlock(id: block.id)
            return
        }
        if block.type == .bulletList || block.type == .taskList {
            store.convertBlockType(id: block.id, to: .paragraph)
            return
        }
        store.deleteBlock(id: block.id)
    }

    private func handleDeleteAtStart() {
        if indentLevel > 0 {
            store.outdentBlock(id: block.id)
            return
        }
        if block.type != .paragraph {
            store.convertBlockType(id: block.id, to: .paragraph)
            return
        }
        // If it's a paragraph and cursor is at index 0, merge with previous block if index > 0
        if let index = store.blocks.firstIndex(where: { $0.id == block.id }), index > 0 {
            let prevBlock = store.blocks[index - 1]
            let mergedContent = prevBlock.content + block.content
            store.updateBlockContent(id: prevBlock.id, content: mergedContent)
            store.deleteBlock(id: block.id)
            store.focusedBlockId = prevBlock.id
        }
    }

    private func handleArrowUp() {
        if let index = store.blocks.firstIndex(where: { $0.id == block.id }) {
            if index > 0 {
                store.focusedBlockId = store.blocks[index - 1].id
            } else {
                store.focusedBlockId = nil
            }
        }
    }

    private func handleArrowDown() {
        if let index = store.blocks.firstIndex(where: { $0.id == block.id }), index < store.blocks.count - 1 {
            store.focusedBlockId = store.blocks[index + 1].id
        }
    }
}
