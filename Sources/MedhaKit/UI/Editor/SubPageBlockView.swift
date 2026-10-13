import SwiftUI

public struct SubPageBlockView: View {
    @ObservedObject public var store: BlockStore
    public let block: Block
    public let isFocused: Bool

    @State private var isHovered: Bool = false

    private var targetDocument: Block? {
        guard let targetId = block.subPageDocId else { return nil }
        return store.documents.first(where: { $0.id == targetId }) ?? store.getBlock(id: targetId)
    }

    private var displayTitle: String {
        if let target = targetDocument, !target.content.isEmpty {
            return target.content
        }
        return block.content.isEmpty ? "Untitled Sub-page" : block.content
    }

    public var body: some View {
        Button(action: {
            if let targetId = block.subPageDocId {
                store.selectDocument(id: targetId)
            }
        }) {
            HStack(spacing: 10) {
                // Document Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 28, height: 28)

                    if let icon = targetDocument?.icon, !icon.isEmpty {
                        if icon.count <= 3 && icon.unicodeScalars.first?.properties.isEmoji == true {
                            Text(icon)
                                .font(.system(size: 16))
                        } else {
                            Image(systemName: icon)
                                .font(.system(size: 13))
                                .foregroundColor(.accentColor)
                        }
                    } else {
                        Image(systemName: "doc.text")
                            .font(.system(size: 13))
                            .foregroundColor(.accentColor)
                    }
                }

                // Title & Subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(MedhaTheme.Colors.textPrimary)
                    Text("Sub-page")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered ? Color.accentColor.opacity(0.08) : Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHovered ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
