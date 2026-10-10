import SwiftUI

public struct DatabaseTableView: View {
    @ObservedObject public var store: BlockStore
    public let database: NotionDatabase

    @State private var isAddPropertySheetPresented: Bool = false
    @State private var newPropertyName: String = ""
    @State private var newPropertyType: DatabasePropertyType = .richText

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

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Database Grid (Horizontal Scrollable Table)
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header Row
                    HStack(spacing: 0) {
                        ForEach(properties) { prop in
                            HStack(spacing: 4) {
                                Image(systemName: prop.type.systemIcon)
                                    .font(.system(size: 10))
                                    .foregroundColor(MedhaTheme.Colors.textSecondary)
                                Text(prop.name)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(MedhaTheme.Colors.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(width: columnWidth(for: prop), alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor))
                            .border(Color(NSColor.separatorColor), width: 0.5)
                        }
                    }

                    // Record Rows
                    if records.isEmpty {
                        HStack {
                            Spacer()
                            Text("No records in this database. Click 'New Record' to add rows.")
                                .font(.system(size: 12))
                                .foregroundColor(MedhaTheme.Colors.textSecondary)
                                .padding(.vertical, 24)
                            Spacer()
                        }
                        .frame(minWidth: totalTableWidth)
                    } else {
                        ForEach(records) { rec in
                            HStack(spacing: 0) {
                                ForEach(properties) { prop in
                                    cellView(record: rec, property: prop)
                                        .frame(width: columnWidth(for: prop), height: 32, alignment: .leading)
                                        .border(Color(NSColor.separatorColor), width: 0.5)
                                }
                            }
                        }
                    }

                    // Calculation / Summary Row
                    HStack(spacing: 0) {
                        ForEach(properties) { prop in
                            summaryCellView(property: prop)
                                .frame(width: columnWidth(for: prop), height: 26, alignment: .leading)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                                .border(Color(NSColor.separatorColor), width: 0.5)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isAddPropertySheetPresented) {
            addPropertySheet
        }
    }

    private func columnWidth(for prop: DatabaseProperty) -> CGFloat {
        switch prop.type {
        case .title: return 200
        case .richText: return 180
        case .number, .uniqueId: return 100
        case .select, .status: return 130
        case .multiSelect: return 160
        case .date, .createdTime, .lastEditedTime: return 130
        case .checkbox: return 80
        case .relation, .rollup: return 140
        default: return 120
        }
    }

    private var totalTableWidth: CGFloat {
        properties.reduce(CGFloat(0)) { $0 + columnWidth(for: $1) }
    }

    // MARK: - Cell Rendering
    @ViewBuilder
    private func cellView(record: DatabaseRecord, property: DatabaseProperty) -> some View {
        let cell = store.activeDatabaseCellValues[record.id]?[property.id]
        
        switch property.type {
        case .checkbox:
            HStack {
                Spacer()
                Button(action: {
                    let currentVal = cell?.valueNumber == 1.0
                    store.updateDatabaseCellValue(
                        recordId: record.id,
                        propertyId: property.id,
                        databaseId: database.id,
                        valueNumber: currentVal ? 0.0 : 1.0
                    )
                }) {
                    Image(systemName: (cell?.valueNumber == 1.0) ? "checkmark.square.fill" : "square")
                        .foregroundColor((cell?.valueNumber == 1.0) ? MedhaTheme.Colors.accent : MedhaTheme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        case .number:
            TextField("0", value: Binding(
                get: { cell?.valueNumber ?? 0.0 },
                set: { newVal in
                    store.updateDatabaseCellValue(
                        recordId: record.id,
                        propertyId: property.id,
                        databaseId: database.id,
                        valueNumber: newVal
                    )
                }
            ), format: .number)
            .textFieldStyle(.plain)
            .font(.system(size: 11))
            .padding(.horizontal, 8)
        case .select, .status:
            let val = cell?.valueText ?? ""
            if val.isEmpty {
                Menu {
                    if let options = property.parsedConfig?.selectOptions {
                        ForEach(options) { opt in
                            Button(opt.name) {
                                store.updateDatabaseCellValue(
                                    recordId: record.id,
                                    propertyId: property.id,
                                    databaseId: database.id,
                                    valueText: opt.name
                                )
                            }
                        }
                    }
                } label: {
                    Text("Select...")
                        .font(.system(size: 10))
                        .foregroundColor(MedhaTheme.Colors.textSecondary)
                }
                .menuStyle(.borderlessButton)
                .padding(.horizontal, 8)
            } else {
                HStack {
                    Text(val)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(4)
                    Spacer()
                }
                .padding(.horizontal, 8)
            }
        case .uniqueId:
            Text(cell?.valueText ?? "\(property.parsedConfig?.uniqueIdConfig?.prefix ?? "ID-")\(record.uniqueSeqNumber ?? 1)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(MedhaTheme.Colors.textSecondary)
                .padding(.horizontal, 8)
        case .rollup:
            let computed = store.databaseService.computeRollup(currentRecordId: record.id, rollupPropertyId: property.id)
            Text(computed != nil ? String(format: "%.1f", computed!) : "–")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(MedhaTheme.Colors.textPrimary)
                .padding(.horizontal, 8)
        default:
            TextField("Empty", text: Binding(
                get: { cell?.valueText ?? "" },
                set: { newVal in
                    store.updateDatabaseCellValue(
                        recordId: record.id,
                        propertyId: property.id,
                        databaseId: database.id,
                        valueText: newVal
                    )
                }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 11))
            .padding(.horizontal, 8)
        }
    }

    // MARK: - Summary / Bottom Calc Cell
    @ViewBuilder
    private func summaryCellView(property: DatabaseProperty) -> some View {
        HStack {
            if property.type == .number {
                let sum = records.reduce(0.0) { acc, rec in
                    let num = store.activeDatabaseCellValues[rec.id]?[property.id]?.valueNumber ?? 0.0
                    return acc + num
                }
                Text("Sum: \(String(format: "%.1f", sum))")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(MedhaTheme.Colors.textSecondary)
            } else if property.type == .title {
                Text("Count: \(records.count)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(MedhaTheme.Colors.textSecondary)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Add Column Sheet
    private var addPropertySheet: some View {
        VStack(spacing: 16) {
            Text("Add Database Column")
                .font(.system(size: 14, weight: .bold))

            TextField("Column Name", text: $newPropertyName)
                .textFieldStyle(.roundedBorder)

            Picker("Property Type", selection: $newPropertyType) {
                ForEach(DatabasePropertyType.allCases, id: \.self) { type in
                    HStack {
                        Image(systemName: type.systemIcon)
                        Text(type.displayName)
                    }
                    .tag(type)
                }
            }

            HStack {
                Button("Cancel") {
                    isAddPropertySheetPresented = false
                }
                Spacer()
                Button("Create Column") {
                    guard !newPropertyName.isEmpty else { return }
                    store.addDatabaseProperty(
                        databaseId: database.id,
                        name: newPropertyName,
                        type: newPropertyType
                    )
                    newPropertyName = ""
                    isAddPropertySheetPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}
