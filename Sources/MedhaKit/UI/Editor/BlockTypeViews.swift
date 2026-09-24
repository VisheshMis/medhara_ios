import SwiftUI
import AppKit

// MARK: - Paragraph with Inline Reference Detection
public struct ParagraphBlockView: View {
    @ObservedObject public var store: BlockStore
    public let block: Block
    public let isFocused: Bool
    public let onCommitReturn: () -> Void
    public let onDeleteEmpty: () -> Void
    public var onDeleteAtStart: () -> Void = {}
    public let onTab: () -> Void
    public let onShiftTab: () -> Void
    public let onArrowUp: () -> Void
    public let onArrowDown: () -> Void
    public let onSlashTrigger: () -> Void

    private var inlineRefs: [LinkParser.InlineRef] {
        LinkParser.extractBlockRefs(from: block.content)
    }

    private var inlineWikiLinks: [LinkParser.WikiLinkRef] {
        LinkParser.extractWikiLinks(from: block.content)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            BlockTextViewRepresentable(
                text: Binding(
                    get: { block.content },
                    set: { store.updateBlockContent(id: block.id, content: $0) }
                ),
                isFocused: isFocused,
                font: .systemFont(ofSize: 14),
                textColor: .labelColor,
                placeholder: block.type.placeholder,
                onCommitReturn: onCommitReturn,
                onDeleteEmpty: onDeleteEmpty,
                onDeleteAtStart: onDeleteAtStart,
                onTab: onTab,
                onShiftTab: onShiftTab,
                onArrowUp: onArrowUp,
                onArrowDown: onArrowDown,
                onSlashTrigger: onSlashTrigger,
                onAutoConvertToBullet: {
                    store.convertBlockType(id: block.id, to: .bulletList)
                },
                onFocus: {
                    store.focusedBlockId = block.id
                }
            )
            .frame(minHeight: 22)
            .fixedSize(horizontal: false, vertical: true)

            if !inlineRefs.isEmpty || !inlineWikiLinks.isEmpty {
                HStack(spacing: 6) {
                    ForEach(inlineWikiLinks) { link in
                        WikiLinkPillView(store: store, wikiLink: link)
                    }
                    ForEach(inlineRefs) { ref in
                        InlineRefPillView(store: store, targetBlockId: ref.blockId)
                    }
                }
                .padding(.top, 2)
            }
        }
    }
}

public struct WikiLinkPillView: View {
    @ObservedObject public var store: BlockStore
    public let wikiLink: LinkParser.WikiLinkRef

    private var resolvedDoc: Block? {
        store.documents.first(where: {
            $0.id == wikiLink.target || $0.content.localizedCaseInsensitiveCompare(wikiLink.target) == .orderedSame
        })
    }

    public var body: some View {
        if let doc = resolvedDoc {
            Button(action: {
                store.selectDocument(id: doc.id)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 9, weight: .bold))
                    Text(doc.content.isEmpty ? "Untitled" : doc.content)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.12))
                .foregroundColor(.accentColor)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Jump to note [[\(doc.content)]]")
        } else {
            Button(action: {
                store.createDocFromUnresolvedLink(title: wikiLink.target)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.dashed")
                        .font(.system(size: 9, weight: .bold))
                    Text(wikiLink.target)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    Text("New")
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 3)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(2)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.08))
                .foregroundColor(.secondary)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3]))
                )
            }
            .buttonStyle(.plain)
            .help("Create note [[\(wikiLink.target)]] at Inbox root")
        }
    }
}

public struct InlineRefPillView: View {
    @ObservedObject public var store: BlockStore
    public let targetBlockId: String

    private var targetBlock: Block? {
        store.getBlock(id: targetBlockId)
    }

    private var displayTitle: String {
        guard let label = targetBlock?.content.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty else {
            return "((ref:\(targetBlockId.prefix(8))))"
        }
        return String(label.prefix(24))
    }

    public var body: some View {
        Button(action: {
            if let target = targetBlock {
                store.selectDocument(id: target.rootDocId)
                store.focusedBlockId = target.id
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "link")
                    .font(.system(size: 9, weight: .bold))
                Text(displayTitle)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.12))
            .foregroundColor(.accentColor)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Heading Block View
public struct HeadingBlockView: View {
    @ObservedObject public var store: BlockStore
    public let block: Block
    public let isFocused: Bool
    public let onCommitReturn: () -> Void
    public let onDeleteEmpty: () -> Void
    public var onDeleteAtStart: () -> Void = {}
    public let onArrowUp: () -> Void
    public let onArrowDown: () -> Void

    private var headingFont: NSFont {
        switch block.type {
        case .heading1: return .systemFont(ofSize: 22, weight: .bold)
        case .heading2: return .systemFont(ofSize: 18, weight: .bold)
        case .heading3: return .systemFont(ofSize: 15, weight: .semibold)
        default: return .systemFont(ofSize: 14)
        }
    }

    private var minHeight: CGFloat {
        block.type == .heading1 ? 30 : (block.type == .heading2 ? 26 : 22)
    }

    public var body: some View {
        BlockTextViewRepresentable(
            text: Binding(
                get: { block.content },
                set: { store.updateBlockContent(id: block.id, content: $0) }
            ),
            isFocused: isFocused,
            font: headingFont,
            textColor: .labelColor,
            placeholder: block.type.placeholder,
            onCommitReturn: onCommitReturn,
            onDeleteEmpty: onDeleteEmpty,
            onDeleteAtStart: onDeleteAtStart,
            onArrowUp: onArrowUp,
            onArrowDown: onArrowDown,
            onFocus: {
                store.focusedBlockId = block.id
            }
        )
        .frame(minHeight: minHeight)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Task List Block View
public struct TaskBlockView: View {
    @ObservedObject public var store: BlockStore
    public let block: Block
    public let isFocused: Bool
    public let onCommitReturn: () -> Void
    public let onDeleteEmpty: () -> Void
    public var onDeleteAtStart: () -> Void = {}
    public let onTab: () -> Void
    public let onShiftTab: () -> Void
    public let onArrowUp: () -> Void
    public let onArrowDown: () -> Void

    private var isCompleted: Bool {
        block.isCompleted ?? false
    }

    private var cleanBinding: Binding<String> {
        Binding(
            get: {
                var c = block.content
                if c.hasPrefix("- [ ] ") || c.hasPrefix("- [x] ") || c.hasPrefix("[ ] ") || c.hasPrefix("[x] ") {
                    if let range = c.range(of: "] ") {
                        c = String(c[range.upperBound...])
                    }
                }
                return c
            },
            set: { newValue in
                var c = newValue
                if c.hasPrefix("- [ ] ") || c.hasPrefix("- [x] ") || c.hasPrefix("[ ] ") || c.hasPrefix("[x] ") {
                    if let range = c.range(of: "] ") {
                        c = String(c[range.upperBound...])
                    }
                }
                store.updateBlockContent(id: block.id, content: c)
            }
        )
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: {
                store.toggleTask(id: block.id)
            }) {
                Image(systemName: isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundColor(isCompleted ? .accentColor : .secondary)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            BlockTextViewRepresentable(
                text: cleanBinding,
                isFocused: isFocused,
                font: .systemFont(ofSize: 14),
                textColor: isCompleted ? .secondaryLabelColor : .labelColor,
                placeholder: block.type.placeholder,
                onCommitReturn: onCommitReturn,
                onDeleteEmpty: onDeleteEmpty,
                onDeleteAtStart: onDeleteAtStart,
                onTab: onTab,
                onShiftTab: onShiftTab,
                onArrowUp: onArrowUp,
                onArrowDown: onArrowDown,
                onFocus: {
                    store.focusedBlockId = block.id
                }
            )
            .frame(minHeight: 22)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Bullet List Block View
public struct BulletBlockView: View {
    @ObservedObject public var store: BlockStore
    public let block: Block
    public let isFocused: Bool
    public let onCommitReturn: () -> Void
    public let onDeleteEmpty: () -> Void
    public var onDeleteAtStart: () -> Void = {}
    public let onTab: () -> Void
    public let onShiftTab: () -> Void
    public let onArrowUp: () -> Void
    public let onArrowDown: () -> Void

    private var cleanBinding: Binding<String> {
        Binding(
            get: {
                var c = block.content
                if c.hasPrefix("* ") || c.hasPrefix("- ") || c.hasPrefix("• ") {
                    c = String(c.dropFirst(2))
                }
                return c
            },
            set: { newValue in
                var c = newValue
                if c.hasPrefix("* ") || c.hasPrefix("- ") || c.hasPrefix("• ") {
                    c = String(c.dropFirst(2))
                }
                store.updateBlockContent(id: block.id, content: c)
            }
        )
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.secondary.opacity(0.85))
                .frame(width: 5, height: 5)
                .padding(.top, 8)
                .frame(width: 14, alignment: .center)

            BlockTextViewRepresentable(
                text: cleanBinding,
                isFocused: isFocused,
                font: .systemFont(ofSize: 14),
                textColor: .labelColor,
                placeholder: block.type.placeholder,
                onCommitReturn: onCommitReturn,
                onDeleteEmpty: onDeleteEmpty,
                onDeleteAtStart: onDeleteAtStart,
                onTab: onTab,
                onShiftTab: onShiftTab,
                onArrowUp: onArrowUp,
                onArrowDown: onArrowDown,
                onFocus: {
                    store.focusedBlockId = block.id
                }
            )
            .frame(minHeight: 22)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Code Block View
public struct CodeBlockView: View {
    @ObservedObject public var store: BlockStore
    public let block: Block
    public let isFocused: Bool
    public let onCommitReturn: () -> Void
    public let onDeleteEmpty: () -> Void
    @State private var copied: Bool = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Swift / Code")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(block.content, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copied = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied" : "Copy")
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))

            Divider()

            BlockTextViewRepresentable(
                text: Binding(
                    get: { block.content },
                    set: { store.updateBlockContent(id: block.id, content: $0) }
                ),
                isFocused: isFocused,
                font: .monospacedSystemFont(ofSize: 13, weight: .regular),
                textColor: .textColor,
                placeholder: "// Monospace code block...",
                onCommitReturn: onCommitReturn,
                onDeleteEmpty: onDeleteEmpty,
                onFocus: {
                    store.focusedBlockId = block.id
                }
            )
            .padding(10)
            .frame(minHeight: 60)
        }
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
}

// MARK: - Quote Block View
public struct QuoteBlockView: View {
    @ObservedObject public var store: BlockStore
    public let block: Block
    public let isFocused: Bool
    public let onCommitReturn: () -> Void
    public let onDeleteEmpty: () -> Void
    public var onDeleteAtStart: () -> Void = {}
    public let onArrowUp: () -> Void
    public let onArrowDown: () -> Void

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor.opacity(0.8))
                .frame(width: 3)

            BlockTextViewRepresentable(
                text: Binding(
                    get: { block.content },
                    set: { store.updateBlockContent(id: block.id, content: $0) }
                ),
                isFocused: isFocused,
                font: NSFontManager.shared.convert(.systemFont(ofSize: 14), toHaveTrait: .italicFontMask),
                textColor: .secondaryLabelColor,
                placeholder: block.type.placeholder,
                onCommitReturn: onCommitReturn,
                onDeleteEmpty: onDeleteEmpty,
                onDeleteAtStart: onDeleteAtStart,
                onArrowUp: onArrowUp,
                onArrowDown: onArrowDown,
                onFocus: {
                    store.focusedBlockId = block.id
                }
            )
            .frame(minHeight: 22)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Callout Block View
public struct CalloutBlockView: View {
    @ObservedObject public var store: BlockStore
    public let block: Block
    public let isFocused: Bool
    public let onCommitReturn: () -> Void
    public let onDeleteEmpty: () -> Void
    public var onDeleteAtStart: () -> Void = {}

    // Light Neo Green palette
    private let neoGreen = Color(red: 0.16, green: 0.86, blue: 0.53)

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Subtle vertical accent bar on the left
            RoundedRectangle(cornerRadius: 1.5)
                .fill(neoGreen.opacity(0.85))
                .frame(width: 3)
                .padding(.vertical, 2)

            // Refined mini lightbulb badge
            ZStack {
                Circle()
                    .fill(neoGreen.opacity(0.14))
                    .frame(width: 20, height: 20)
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(neoGreen)
            }
            .padding(.top, 2)

            BlockTextViewRepresentable(
                text: Binding(
                    get: { block.content },
                    set: { store.updateBlockContent(id: block.id, content: $0) }
                ),
                isFocused: isFocused,
                font: .systemFont(ofSize: 13.5, weight: .regular),
                textColor: .labelColor,
                placeholder: block.type.placeholder,
                onCommitReturn: onCommitReturn,
                onDeleteEmpty: onDeleteEmpty,
                onDeleteAtStart: onDeleteAtStart,
                onFocus: {
                    store.focusedBlockId = block.id
                }
            )
            .frame(minHeight: 22)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(neoGreen.opacity(0.06))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(neoGreen.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Block Reference (Transclusion) View
public struct BlockRefView: View {
    @ObservedObject public var store: BlockStore
    public let block: Block

    private var targetBlock: Block? {
        guard let refId = block.refTargetId else { return nil }
        return store.getBlock(id: refId)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.accentColor)
                Text("Block Transclusion")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.accentColor)
                if let refId = block.refTargetId {
                    Text("(\(refId.prefix(10))...)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Spacer()

                if let target = targetBlock {
                    Button(action: {
                        store.selectDocument(id: target.rootDocId)
                        store.focusedBlockId = target.id
                    }) {
                        HStack(spacing: 3) {
                            Text("Jump to Source")
                            Image(systemName: "arrow.up.forward.square")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button("Select Target...") {
                        store.blockPendingRefId = block.id
                        store.isBlockPickerPresented = true
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                }
            }

            if let target = targetBlock {
                HStack(spacing: 8) {
                    Image(systemName: target.type.systemIcon)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(target.content.isEmpty ? "(Empty Block)" : target.content)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .lineLimit(4)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(6)
            } else {
                Text("No target block selected. Click 'Select Target...' to link a block.")
                    .font(.system(size: 12)).italic()
                    .foregroundColor(.secondary)
                    .padding(6)
            }
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
    }
}
