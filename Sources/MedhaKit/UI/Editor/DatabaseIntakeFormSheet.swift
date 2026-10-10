import SwiftUI

public struct DatabaseIntakeFormSheet: View {
    @ObservedObject public var store: BlockStore
    public let database: NotionDatabase
    public let onDismiss: () -> Void

    @State private var textValues: [String: String] = [:]
    @State private var numberValues: [String: Double] = [:]
    @State private var checkboxValues: [String: Bool] = [:]
    @State private var dateValues: [String: Date] = [:]

    public init(store: BlockStore, database: NotionDatabase, onDismiss: @escaping () -> Void) {
        self.store = store
        self.database = database
        self.onDismiss = onDismiss
    }

    private var properties: [DatabaseProperty] {
        store.activeDatabaseProperties
    }

    // Branching condition check: e.g. If status is "Blocked" show an extra notes field
    private var isBlockedSelected: Bool {
        if let statusProp = properties.first(where: { $0.type == .status }) {
            return textValues[statusProp.id]?.lowercased() == "blocked"
        }
        return false
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Sheet Header
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .foregroundColor(MedhaTheme.Colors.accent)
                    .font(.system(size: 16))
                Text("New \(database.title) Record")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(MedhaTheme.Colors.textPrimary)
                Spacer()
                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Form Fields
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(properties) { prop in
                        formFieldView(for: prop)
                    }

                    // Conditional Branching Question
                    if isBlockedSelected {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Blocker Rationale (Conditional Field)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                            TextEditor(text: .constant("Describe the blocker..."))
                                .frame(height: 50)
                                .border(Color.orange.opacity(0.4), width: 1)
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.08))
                        .cornerRadius(6)
                    }
                }
                .padding(16)
            }

            Divider()

            // Sheet Footer Action
            HStack {
                Spacer()
                Button(action: submitForm) {
                    Label("Submit Record", systemImage: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 440, height: 480)
    }

    @ViewBuilder
    private func formFieldView(for prop: DatabaseProperty) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: prop.type.systemIcon)
                    .font(.system(size: 10))
                    .foregroundColor(MedhaTheme.Colors.textSecondary)
                Text(prop.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(MedhaTheme.Colors.textPrimary)
            }

            switch prop.type {
            case .checkbox:
                Toggle("", isOn: Binding(
                    get: { checkboxValues[prop.id] ?? false },
                    set: { checkboxValues[prop.id] = $0 }
                ))
                .toggleStyle(.checkbox)
            case .number:
                TextField("0.0", value: Binding(
                    get: { numberValues[prop.id] ?? 0.0 },
                    set: { numberValues[prop.id] = $0 }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
            case .status, .select:
                let options = prop.parsedConfig?.selectOptions ?? [
                    SelectOption(name: "To-do"),
                    SelectOption(name: "In Progress"),
                    SelectOption(name: "Completed")
                ]
                Picker("", selection: Binding(
                    get: { textValues[prop.id] ?? options.first?.name ?? "" },
                    set: { textValues[prop.id] = $0 }
                )) {
                    ForEach(options) { opt in
                        Text(opt.name).tag(opt.name)
                    }
                }
                .pickerStyle(.menu)
            case .date:
                DatePicker("", selection: Binding(
                    get: { dateValues[prop.id] ?? Date() },
                    set: { dateValues[prop.id] = $0 }
                ), displayedComponents: [.date])
                .datePickerStyle(.compact)
            case .uniqueId, .createdTime, .lastEditedTime, .rollup:
                Text("Auto-generated field")
                    .font(.system(size: 10))
                    .italic()
                    .foregroundColor(MedhaTheme.Colors.textSecondary)
            default:
                TextField("Enter value...", text: Binding(
                    get: { textValues[prop.id] ?? "" },
                    set: { textValues[prop.id] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func submitForm() {
        let rec = store.addDatabaseRecord(databaseId: database.id)

        for prop in properties {
            switch prop.type {
            case .checkbox:
                let val = checkboxValues[prop.id] == true ? 1.0 : 0.0
                store.updateDatabaseCellValue(recordId: rec.id, propertyId: prop.id, databaseId: database.id, valueNumber: val)
            case .number:
                let val = numberValues[prop.id] ?? 0.0
                store.updateDatabaseCellValue(recordId: rec.id, propertyId: prop.id, databaseId: database.id, valueNumber: val)
            case .date:
                let val = dateValues[prop.id] ?? Date()
                store.updateDatabaseCellValue(recordId: rec.id, propertyId: prop.id, databaseId: database.id, valueDate: val)
            case .status, .select, .title, .richText, .url, .email, .phone:
                let val = textValues[prop.id] ?? ""
                if !val.isEmpty {
                    store.updateDatabaseCellValue(recordId: rec.id, propertyId: prop.id, databaseId: database.id, valueText: val)
                }
            default:
                break
            }
        }

        // Trigger recordCreated automation
        store.triggerAutomation(databaseId: database.id, recordId: rec.id, trigger: .recordCreated)

        onDismiss()
    }
}
