import SwiftUI

public struct DatabaseBoardView: View {
    @ObservedObject public var store: BlockStore
    public let database: NotionDatabase

    public init(store: BlockStore, database: NotionDatabase) {
        self.store = store
        self.database = database
    }

    private var properties: [DatabaseProperty] {
        store.activeDatabaseProperties
    }

    private var records: [DatabaseRecord] {
        store.activeDatabaseRecords
    }

    // Identify the status or select property to group by
    private var groupingProperty: DatabaseProperty? {
        properties.first(where: { $0.type == .status }) ??
        properties.first(where: { $0.type == .select })
    }

    private var titleProperty: DatabaseProperty? {
        properties.first(where: { $0.type == .title })
    }

    private var columns: [String] {
        if let options = groupingProperty?.parsedConfig?.selectOptions, !options.isEmpty {
            return options.map(\.name)
        }
        return ["To-do", "In Progress", "Completed"]
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let groupProp = groupingProperty {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.3x2")
                        .font(.system(size: 11))
                        .foregroundColor(MedhaTheme.Colors.accent)
                    Text("Grouped by:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(MedhaTheme.Colors.textSecondary)
                    Text(groupProp.name)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(MedhaTheme.Colors.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            // Horizontally scrolling Kanban Swimlanes
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(columns, id: \.self) { columnTitle in
                        swimlaneColumn(title: columnTitle)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Swimlane Column
    @ViewBuilder
    private func swimlaneColumn(title: String) -> some View {
        let matchingRecords = records.filter { rec in
            guard let groupProp = groupingProperty else { return false }
            let cellVal = store.activeDatabaseCellValues[rec.id]?[groupProp.id]?.valueText ?? ""
            if title == "To-do" && cellVal.isEmpty { return true }
            return cellVal.caseInsensitiveCompare(title) == .orderedSame
        }

        VStack(alignment: .leading, spacing: 8) {
            // Column Header
            HStack(spacing: 6) {
                Circle()
                    .fill(columnColor(for: title))
                    .frame(width: 8, height: 8)

                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(MedhaTheme.Colors.textPrimary)

                Text("\(matchingRecords.count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(MedhaTheme.Colors.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                Spacer()

                Button(action: {
                    let newRec = store.addDatabaseRecord(databaseId: database.id)
                    if let groupProp = groupingProperty {
                        store.updateDatabaseCellValue(
                            recordId: newRec.id,
                            propertyId: groupProp.id,
                            databaseId: database.id,
                            valueText: title
                        )
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundColor(MedhaTheme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 2)

            // Cards Stack
            VStack(spacing: 8) {
                ForEach(matchingRecords) { rec in
                    kanbanCard(record: rec)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(width: 240)
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        .cornerRadius(8)
    }

    // MARK: - Kanban Card
    @ViewBuilder
    private func kanbanCard(record: DatabaseRecord) -> some View {
        let titleVal = titleProperty != nil ? (store.activeDatabaseCellValues[record.id]?[titleProperty!.id]?.valueText ?? "Untitled") : "Untitled"

        VStack(alignment: .leading, spacing: 6) {
            Text(titleVal.isEmpty ? "Untitled" : titleVal)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(MedhaTheme.Colors.textPrimary)
                .lineLimit(2)

            // Extra property pills
            HStack(spacing: 6) {
                // Unique ID or Checkbox
                if let idProp = properties.first(where: { $0.type == .uniqueId }) {
                    let key = store.activeDatabaseCellValues[record.id]?[idProp.id]?.valueText ?? "\(idProp.parsedConfig?.uniqueIdConfig?.prefix ?? "ID-")\(record.uniqueSeqNumber ?? 1)"
                    Text(key)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(MedhaTheme.Colors.textSecondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(3)
                }

                if let numProp = properties.first(where: { $0.type == .number }) {
                    let num = store.activeDatabaseCellValues[record.id]?[numProp.id]?.valueNumber ?? 0.0
                    if num > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "number")
                                .font(.system(size: 8))
                            Text(String(format: "%.0f", num))
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(MedhaTheme.Colors.textSecondary)
                    }
                }

                Spacer()

                // Quick Move Menu
                Menu {
                    ForEach(columns, id: \.self) { targetCol in
                        Button("Move to \(targetCol)") {
                            if let groupProp = groupingProperty {
                                store.updateDatabaseCellValue(
                                    recordId: record.id,
                                    propertyId: groupProp.id,
                                    databaseId: database.id,
                                    valueText: targetCol
                                )
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 10))
                        .foregroundColor(MedhaTheme.Colors.textSecondary)
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(6)
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }

    private func columnColor(for title: String) -> Color {
        switch title.lowercased() {
        case "to-do", "todo", "backlog":
            return .gray
        case "in progress", "doing", "active":
            return .blue
        case "completed", "done", "shipped":
            return .green
        default:
            return .purple
        }
    }
}
