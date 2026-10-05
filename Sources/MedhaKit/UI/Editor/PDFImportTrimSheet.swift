import SwiftUI
import AppKit

public struct PDFImportTrimSheet: View {
    public let sourceURL: URL
    public let totalPages: Int
    public let onImport: (Int, Int) -> Void
    public let onCancel: () -> Void

    @State private var startPage: Int = 1
    @State private var endPage: Int = 1
    @State private var importAll: Bool = true

    public init(
        sourceURL: URL,
        totalPages: Int,
        onImport: @escaping (Int, Int) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.sourceURL = sourceURL
        self.totalPages = totalPages
        self.onImport = onImport
        self.onCancel = onCancel
        _startPage = State(initialValue: 1)
        _endPage = State(initialValue: max(1, totalPages))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "doc.viewfinder.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Import PDF to Handwritten Canvas")
                        .font(.system(size: 15, weight: .bold))
                    Text(sourceURL.lastPathComponent)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Divider()

            // Page Information Badge
            HStack {
                Text("Total Document Pages:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("\(totalPages)")
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)

            // Range Selection Mode
            VStack(alignment: .leading, spacing: 12) {
                Text("Select Pages to Import")
                    .font(.system(size: 13, weight: .semibold))

                // Option 1: Import All
                Button(action: {
                    importAll = true
                    startPage = 1
                    endPage = totalPages
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: importAll ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(importAll ? .accentColor : .secondary)
                        Text("Import entire PDF (Pages 1 to \(totalPages))")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.plain)

                // Option 2: Trim / Custom Page Range
                Button(action: {
                    importAll = false
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: !importAll ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(!importAll ? .accentColor : .secondary)
                        Text("Trim PDF to custom page range:")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.plain)

                // Custom Range Inputs
                if !importAll {
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Text("From:")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Stepper(value: $startPage, in: 1...max(1, endPage)) {
                                Text("\(startPage)")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .frame(width: 36)
                            }
                        }

                        HStack(spacing: 6) {
                            Text("To:")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Stepper(value: $endPage, in: startPage...max(1, totalPages)) {
                                Text("\(endPage)")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .frame(width: 36)
                            }
                        }

                        Text("(\(max(1, endPage - startPage + 1)) page\(endPage - startPage == 0 ? "" : "s"))")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 24)
                }
            }

            Text("The selected pages will be saved into the document's local assets. You can write, annotate, draw, and erase on top of them seamlessly.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineSpacing(2)

            Spacer()

            // Action Buttons
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Import \(importAll ? "\(totalPages)" : "\(max(1, endPage - startPage + 1))") Page\(totalPages > 1 ? "s" : "")") {
                    let s = importAll ? 1 : startPage
                    let e = importAll ? totalPages : endPage
                    onImport(s, e)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440, height: 350)
    }
}
