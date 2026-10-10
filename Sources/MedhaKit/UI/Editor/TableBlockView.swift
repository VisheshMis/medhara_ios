import SwiftUI
import AppKit

public struct TableBlockView: View {
    @ObservedObject public var store: BlockStore
    public let block: Block
    public let isFocused: Bool

    @State private var isHovered: Bool = false

    private var payload: TableBlockPayload {
        block.tablePayload ?? .defaultTable()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            toolbarView
            tableGridView
        }
        .padding(.vertical, 4)
        .onHover { isHovered = $0 }
    }

    private var toolbarView: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "tablecells")
                    .font(.system(size: 11, weight: .semibold))
                Text("\(payload.rows.count) × \(payload.rows.first?.count ?? 0) Table")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundColor(MedhaTheme.Colors.textTertiary)

            Spacer()

            Button(action: toggleHeaderRow) {
                HStack(spacing: 3) {
                    Image(systemName: payload.hasHeaderRow ? "checkmark.square.fill" : "square")
                        .font(.system(size: 10))
                    Text("Header Row")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(payload.hasHeaderRow ? Color.accentColor : MedhaTheme.Colors.textTertiary)
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 12)

            Button(action: addRow) {
                Label("Row", systemImage: "plus")
                    .font(.system(size: 10, weight: .medium))
            }
            .buttonStyle(.borderless)

            Button(action: addColumn) {
                Label("Column", systemImage: "plus")
                    .font(.system(size: 10, weight: .medium))
            }
            .buttonStyle(.borderless)

            if payload.rows.count > 1 {
                Button(action: removeRow) {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.borderless)
            }

            if (payload.rows.first?.count ?? 0) > 1 {
                Button(action: removeColumn) {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(MedhaTheme.Colors.bgSurface.opacity(0.6))
        .cornerRadius(6)
    }

    private var tableGridView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(0..<payload.rows.count, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<(payload.rows[r].count), id: \.self) { c in
                            let isHeader = (r == 0 && payload.hasHeaderRow) || (c == 0 && payload.hasHeaderCol)
                            cellView(r: r, c: c, isHeader: isHeader)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(MedhaTheme.Colors.borderHairline, lineWidth: 1)
            )
        }
    }

    private func cellView(r: Int, c: Int, isHeader: Bool) -> some View {
        TextField(isHeader ? "Header" : "Cell", text: Binding(
            get: {
                guard r < payload.rows.count, c < payload.rows[r].count else { return "" }
                return payload.rows[r][c]
            },
            set: { newValue in
                var updated = payload
                guard r < updated.rows.count, c < updated.rows[r].count else { return }
                updated.rows[r][c] = newValue
                store.updateTableBlock(id: block.id, payload: updated)
            }
        ))
        .textFieldStyle(.plain)
        .font(.system(
            size: 13 * store.editorZoomLevel,
            weight: isHeader ? .semibold : .regular
        ))
        .foregroundColor(isHeader ? MedhaTheme.Colors.textPrimary : Color(NSColor.labelColor))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minWidth: 110, maxWidth: .infinity, alignment: .leading)
        .background(
            isHeader
                ? MedhaTheme.Colors.bgElevated.opacity(0.85)
                : (r % 2 == 1 ? MedhaTheme.Colors.bgSurface.opacity(0.3) : Color.clear)
        )
        .overlay(
            Rectangle()
                .stroke(MedhaTheme.Colors.borderSubtle, lineWidth: 0.5)
        )
    }

    private func addRow() {
        var updated = payload
        let colCount = updated.rows.first?.count ?? 2
        updated.rows.append(Array(repeating: "", count: colCount))
        store.updateTableBlock(id: block.id, payload: updated)
    }

    private func removeRow() {
        var updated = payload
        guard updated.rows.count > 1 else { return }
        updated.rows.removeLast()
        store.updateTableBlock(id: block.id, payload: updated)
    }

    private func addColumn() {
        var updated = payload
        for i in 0..<updated.rows.count {
            updated.rows[i].append("")
        }
        store.updateTableBlock(id: block.id, payload: updated)
    }

    private func removeColumn() {
        var updated = payload
        guard (updated.rows.first?.count ?? 0) > 1 else { return }
        for i in 0..<updated.rows.count {
            updated.rows[i].removeLast()
        }
        store.updateTableBlock(id: block.id, payload: updated)
    }

    private func toggleHeaderRow() {
        var updated = payload
        updated.hasHeaderRow.toggle()
        store.updateTableBlock(id: block.id, payload: updated)
    }
}
