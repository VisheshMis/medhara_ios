import SwiftUI

public struct DocInfoView: View {
    @ObservedObject public var store: BlockStore
    @State private var showExportAlert: Bool = false
    @State private var exportMessage: String = ""

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let doc = store.currentDoc {
                    // Document Details Section
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DOCUMENT METRICS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        VStack(spacing: 6) {
                            metricRow(title: "Blocks", value: "\(store.blocks.count)")
                            metricRow(title: "Words", value: "\(wordCount(doc: doc))")
                            metricRow(title: "Characters", value: "\(charCount(doc: doc))")
                            metricRow(title: "Headings", value: "\(store.blocks.filter({ $0.isHeading }).count)")
                            metricRow(title: "Tasks", value: "\(store.blocks.filter({ $0.type == .taskList }).count)")
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                        .cornerRadius(6)
                    }

                    // Timestamps Section
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TIMESTAMPS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        VStack(spacing: 6) {
                            metricRow(title: "Created", value: Self.dateFormatter.string(from: doc.createdAt))
                            metricRow(title: "Modified", value: Self.dateFormatter.string(from: doc.updatedAt))
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                        .cornerRadius(6)
                    }

                    // Storage & Architecture Section
                    VStack(alignment: .leading, spacing: 6) {
                        Text("LOCAL STORAGE & PERSISTENCE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Engine")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 11))
                                Spacer()
                                Text("SQLite 3 (WAL + FTS5)")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                            }
                            Divider()
                            HStack {
                                Text("Privacy")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 11))
                                Spacer()
                                Text("100% Local-First")
                                    .foregroundColor(.green)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            Divider()
                            Text("Database Location:")
                                .foregroundColor(.secondary)
                                .font(.system(size: 10))
                            Text("~/Library/Application Support/Medha/medha.sqlite")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                        .cornerRadius(6)
                    }

                    // Export Actions
                    VStack(alignment: .leading, spacing: 6) {
                        Text("EXPORT")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            Button(action: copyMarkdownToPasteboard) {
                                Label("Copy Markdown", systemImage: "doc.text")
                                    .font(.system(size: 11))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button(action: copyJSONToPasteboard) {
                                Label("Copy JSON", systemImage: "curlybraces")
                                    .font(.system(size: 11))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } else {
                    Text("Select a document to inspect.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
        }
        .alert("Export Copied", isPresented: $showExportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportMessage)
        }
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
        }
    }

    private func wordCount(doc: Block) -> Int {
        var count = doc.content.components(separatedBy: .whitespacesAndNewlines).filter({ !$0.isEmpty }).count
        for b in store.blocks {
            count += b.content.components(separatedBy: .whitespacesAndNewlines).filter({ !$0.isEmpty }).count
        }
        return count
    }

    private func charCount(doc: Block) -> Int {
        var count = doc.content.count
        for b in store.blocks {
            count += b.content.count
        }
        return count
    }

    private func copyMarkdownToPasteboard() {
        let md = store.exportCurrentAsMarkdown()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(md, forType: .string)
        exportMessage = "Markdown for '\(store.currentDoc?.content ?? "Document")' copied to pasteboard!"
        showExportAlert = true
    }

    private func copyJSONToPasteboard() {
        let json = store.exportCurrentAsJSON()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(json, forType: .string)
        exportMessage = "Full block JSON tree copied to pasteboard!"
        showExportAlert = true
    }
}
