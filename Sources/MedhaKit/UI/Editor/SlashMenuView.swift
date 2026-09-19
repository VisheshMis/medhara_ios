import SwiftUI

public struct SlashMenuView: View {
    @ObservedObject public var store: BlockStore
    public let blockId: String
    public let onDismiss: () -> Void

    @State private var filterText: String = ""

    private struct AISlashItem: Identifiable {
        let id: String
        let title: String
        let icon: String
        let subtitle: String
        let mode: NotesGenerationMode?
    }

    private let aiItems: [AISlashItem] = [
        AISlashItem(
            id: "ai-assistant",
            title: "AI Assistant",
            icon: "sparkles",
            subtitle: "Open Notes AI sidebar",
            mode: nil
        ),
        AISlashItem(
            id: "ai-expand",
            title: "Expand Subtopics (AI)",
            icon: "arrow.turn.right.down",
            subtitle: "Downward child subtopics",
            mode: .expandSubtopics
        ),
        AISlashItem(
            id: "ai-split",
            title: "Summarize & Split (AI)",
            icon: "scissors",
            subtitle: "Split note into modular sub-notes",
            mode: .summarizeAndSplit
        )
    ]

    private var filteredAIItems: [AISlashItem] {
        if filterText.isEmpty { return aiItems }
        return aiItems.filter {
            $0.title.localizedCaseInsensitiveContains(filterText) ||
            $0.subtitle.localizedCaseInsensitiveContains(filterText) ||
            $0.id.localizedCaseInsensitiveContains(filterText)
        }
    }

    private var filteredTypes: [BlockType] {
        let types = BlockType.allCases.filter { $0 != .doc }
        if filterText.isEmpty { return types }
        return types.filter { $0.displayName.localizedCaseInsensitiveContains(filterText) }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                TextField("Filter commands or blocks...", text: $filterText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(5)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    // AI Commands Section
                    if !filteredAIItems.isEmpty {
                        Text("AI ASSISTANT")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.top, 2)

                        ForEach(filteredAIItems) { item in
                            Button(action: {
                                cleanSlashFromBlock()
                                store.isNotesAIAssistantPresented = true
                                onDismiss()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: item.icon)
                                        .frame(width: 16)
                                        .foregroundColor(.purple)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(item.title)
                                            .font(.system(size: 12, weight: .medium))
                                        Text(item.subtitle)
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .cornerRadius(4)
                        }

                        Divider()
                            .padding(.vertical, 2)
                    }

                    // Standard Block Types Section
                    if !filteredTypes.isEmpty {
                        Text("BLOCK TYPES")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.top, 2)

                        ForEach(filteredTypes, id: \.self) { type in
                            Button(action: {
                                store.convertBlockType(id: blockId, to: type)
                                cleanSlashFromBlock()
                                if type == .blockRef {
                                    store.blockPendingRefId = blockId
                                    store.isBlockPickerPresented = true
                                }
                                onDismiss()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: type.systemIcon)
                                        .frame(width: 16)
                                        .foregroundColor(.accentColor)
                                    Text(type.displayName)
                                        .font(.system(size: 12))
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .cornerRadius(4)
                        }
                    }
                }
            }
            .frame(maxHeight: 260)
        }
        .padding(8)
        .frame(width: 230)
    }

    private func cleanSlashFromBlock() {
        if let block = store.getBlock(id: blockId) {
            if block.content.hasSuffix("/") {
                let cleaned = String(block.content.dropLast())
                store.updateBlockContent(id: blockId, content: cleaned)
            } else if block.content.contains("/") {
                // If slash was followed by query text like "/ai"
                if let lastSlashIndex = block.content.lastIndex(of: "/") {
                    let cleaned = String(block.content[..<lastSlashIndex])
                    store.updateBlockContent(id: blockId, content: cleaned)
                }
            }
        }
    }
}
