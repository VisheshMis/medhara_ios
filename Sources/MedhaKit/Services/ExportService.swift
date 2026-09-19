import Foundation

public enum ExportService {
    public static func exportToMarkdown(doc: Block, blocks: [Block]) -> String {
        var lines: [String] = []
        lines.append("# \(doc.content)")
        lines.append("")

        for block in blocks {
            let indentLevel = block.parentId != nil && block.parentId != doc.id ? "    " : ""
            switch block.type {
            case .doc:
                continue
            case .heading1:
                lines.append("\n# \(block.content)\n")
            case .heading2:
                lines.append("\n## \(block.content)\n")
            case .heading3:
                lines.append("\n### \(block.content)\n")
            case .paragraph:
                lines.append("\(indentLevel)\(block.content)")
                lines.append("")
            case .bulletList:
                lines.append("\(indentLevel)- \(block.content)")
            case .taskList:
                let check = (block.isCompleted ?? false) ? "x" : " "
                lines.append("\(indentLevel)- [\(check)] \(block.content)")
            case .codeBlock:
                lines.append("```swift\n\(block.content)\n```\n")
            case .quote:
                lines.append("> \(block.content)\n")
            case .callout:
                lines.append("> [!NOTE]\n> \(block.content)\n")
            case .blockRef:
                if let ref = block.refTargetId {
                    lines.append("\(indentLevel)((\(ref)))")
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    public static func exportToJSON(doc: Block, blocks: [Block]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        struct ExportPayload: Codable {
            let document: Block
            let blocks: [Block]
        }
        let payload = ExportPayload(document: doc, blocks: blocks)
        let data = try encoder.encode(payload)
        return String(data: data, encoding: .utf8) ?? ""
    }

    public static func importMarkdown(
        text: String,
        title: String,
        notebookId: String
    ) -> (doc: Block, blocks: [Block]) {
        let now = Date()
        let docId = Block.generateId()
        let doc = Block(
            id: docId,
            rootDocId: docId,
            parentId: nil,
            type: .doc,
            content: title.isEmpty ? "Imported Note" : title,
            sortOrder: 0,
            createdAt: now,
            updatedAt: now,
            notebookId: notebookId
        )

        var blocks: [Block] = []
        let rawLines = text.components(separatedBy: .newlines)
        var order = 1
        var inCodeBlock = false
        var codeAccumulator: [String] = []

        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    // end code block
                    let code = codeAccumulator.joined(separator: "\n")
                    blocks.append(Block(
                        rootDocId: docId,
                        parentId: docId,
                        type: .codeBlock,
                        content: code,
                        sortOrder: order,
                        createdAt: now,
                        updatedAt: now
                    ))
                    order += 1
                    codeAccumulator.removeAll()
                    inCodeBlock = false
                } else {
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                codeAccumulator.append(line)
                continue
            }

            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("### ") {
                let text = String(trimmed.dropFirst(4))
                blocks.append(Block(rootDocId: docId, parentId: docId, type: .heading3, content: text, sortOrder: order, createdAt: now, updatedAt: now))
            } else if trimmed.hasPrefix("## ") {
                let text = String(trimmed.dropFirst(3))
                blocks.append(Block(rootDocId: docId, parentId: docId, type: .heading2, content: text, sortOrder: order, createdAt: now, updatedAt: now))
            } else if trimmed.hasPrefix("# ") {
                let text = String(trimmed.dropFirst(2))
                blocks.append(Block(rootDocId: docId, parentId: docId, type: .heading1, content: text, sortOrder: order, createdAt: now, updatedAt: now))
            } else if trimmed.hasPrefix("- [ ] ") {
                let text = String(trimmed.dropFirst(6))
                blocks.append(Block(rootDocId: docId, parentId: docId, type: .taskList, content: text, sortOrder: order, isCompleted: false, createdAt: now, updatedAt: now))
            } else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
                let text = String(trimmed.dropFirst(6))
                blocks.append(Block(rootDocId: docId, parentId: docId, type: .taskList, content: text, sortOrder: order, isCompleted: true, createdAt: now, updatedAt: now))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let text = String(trimmed.dropFirst(2))
                blocks.append(Block(rootDocId: docId, parentId: docId, type: .bulletList, content: text, sortOrder: order, createdAt: now, updatedAt: now))
            } else if trimmed.hasPrefix("> ") {
                let text = String(trimmed.dropFirst(2))
                blocks.append(Block(rootDocId: docId, parentId: docId, type: .quote, content: text, sortOrder: order, createdAt: now, updatedAt: now))
            } else {
                blocks.append(Block(rootDocId: docId, parentId: docId, type: .paragraph, content: trimmed, sortOrder: order, createdAt: now, updatedAt: now))
            }
            order += 1
        }

        return (doc, blocks)
    }
}
