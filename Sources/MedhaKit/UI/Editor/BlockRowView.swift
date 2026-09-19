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

    private var isFocused: Bool {
        store.focusedBlockId == block.id
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
            ZStack {
                if isHovered || isFocused {
                    Menu {
                        Button(action: copyBlockRef) {
                            Label("Copy Block Reference ((\(String(block.id.prefix(8)))))...", systemImage: "doc.on.doc")
                        }

                        Menu("Turn Into...") {
                            ForEach(BlockType.allCases.filter { $0 != .doc }, id: \.self) { type in
                                Button(action: {
                                    store.convertBlockType(id: block.id, to: type)
                                    if type == .blockRef {
                                        store.blockPendingRefId = block.id
                                        store.isBlockPickerPresented = true
                                    }
                                }) {
                                    Label(type.displayName, systemImage: type.systemIcon)
                                }
                            }
                        }

                        Divider()

                        Button(action: { store.moveBlock(id: block.id, direction: .up) }) {
                            Label("Move Up", systemImage: "arrow.up")
                        }
                        .disabled(isFirst)

                        Button(action: { store.moveBlock(id: block.id, direction: .down) }) {
                            Label("Move Down", systemImage: "arrow.down")
                        }
                        .disabled(isLast)

                        Button(action: { store.indentBlock(id: block.id) }) {
                            Label("Indent", systemImage: "increase.indent")
                        }

                        Button(action: { store.outdentBlock(id: block.id) }) {
                            Label("Outdent", systemImage: "decrease.indent")
                        }

                        Divider()

                        Button(role: .destructive, action: { store.deleteBlock(id: block.id) }) {
                            Label("Delete Block", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.8))
                            .frame(width: 18, height: 22)
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 18)
                } else {
                    Color.clear
                        .frame(width: 18, height: 22)
                }
            }
            .padding(.top, block.type == .heading1 ? 6 : (block.type == .heading2 ? 4 : 2))

            // Main Block Content View
            VStack(alignment: .leading, spacing: 0) {
                switch block.type {
                case .doc:
                    EmptyView()
                case .heading1, .heading2, .heading3:
                    HeadingBlockView(
                        store: store,
                        block: block,
                        isFocused: isFocused,
                        onCommitReturn: handleCommitReturn,
                        onDeleteEmpty: handleDeleteEmpty,
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
                        onArrowUp: handleArrowUp,
                        onArrowDown: handleArrowDown
                    )
                case .callout:
                    CalloutBlockView(
                        store: store,
                        block: block,
                        isFocused: isFocused,
                        onCommitReturn: handleCommitReturn,
                        onDeleteEmpty: handleDeleteEmpty
                    )
                case .blockRef:
                    BlockRefView(store: store, block: block)
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
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
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

    private func handleArrowUp() {
        if let index = store.blocks.firstIndex(where: { $0.id == block.id }), index > 0 {
            store.focusedBlockId = store.blocks[index - 1].id
        }
    }

    private func handleArrowDown() {
        if let index = store.blocks.firstIndex(where: { $0.id == block.id }), index < store.blocks.count - 1 {
            store.focusedBlockId = store.blocks[index + 1].id
        }
    }
}
