import SwiftUI

public struct DatabaseContainerView: View {
    @ObservedObject public var store: BlockStore
    public let database: NotionDatabase

    @State private var isAddPropertySheetPresented: Bool = false
    @State private var newPropertyName: String = ""
    @State private var newPropertyType: DatabasePropertyType = .richText

    @State private var isIntakeFormPresented: Bool = false

    public init(store: BlockStore, database: NotionDatabase) {
        self.store = store
        self.database = database
    }

    private var currentMode: DatabaseViewMode {
        store.getDatabaseViewMode(databaseId: database.id)
    }

    private var records: [DatabaseRecord] {
        store.activeDatabaseRecords
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Master Database Header with Multi-View Canvas Switcher
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: database.icon ?? "tablecells")
                        .foregroundColor(MedhaTheme.Colors.accent)
                        .font(.system(size: 15))
                    Text(database.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(MedhaTheme.Colors.textPrimary)

                    Text("(\(records.count))")
                        .font(.system(size: 11))
                        .foregroundColor(MedhaTheme.Colors.textSecondary)
                }

                // View Mode Tabs (Table | Board | Gallery | Calendar | Analytics)
                Picker("", selection: Binding(
                    get: { currentMode },
                    set: { newMode in store.setDatabaseViewMode(databaseId: database.id, mode: newMode) }
                )) {
                    ForEach(DatabaseViewMode.allCases, id: \.self) { mode in
                        HStack(spacing: 4) {
                            Image(systemName: mode.systemIcon)
                            Text(mode.displayName)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)

                Spacer()

                Button(action: {
                    isIntakeFormPresented = true
                }) {
                    Label("Form Intake", systemImage: "square.and.pencil")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(5)

                Button(action: {
                    isAddPropertySheetPresented = true
                }) {
                    Label("Add Column", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(5)

                Button(action: {
                    store.addDatabaseRecord(databaseId: database.id)
                }) {
                    Label("New Record", systemImage: "plus.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(MedhaTheme.Colors.accent)
                .cornerRadius(5)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.45))

            Divider()

            // Dynamic Canvas View
            Group {
                switch currentMode {
                case .table:
                    DatabaseTableView(store: store, database: database)
                case .board:
                    DatabaseBoardView(store: store, database: database)
                case .gallery:
                    DatabaseGalleryView(store: store, database: database)
                case .calendar:
                    DatabaseCalendarView(store: store, database: database)
                case .chart:
                    DatabaseChartView(store: store, database: database)
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
        .sheet(isPresented: $isAddPropertySheetPresented) {
            addPropertySheet
        }
        .sheet(isPresented: $isIntakeFormPresented) {
            DatabaseIntakeFormSheet(store: store, database: database) {
                isIntakeFormPresented = false
            }
        }
    }

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
