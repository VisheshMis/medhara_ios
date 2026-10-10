import SwiftUI

public struct DatabaseGalleryView: View {
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

    private var titleProperty: DatabaseProperty? {
        properties.first(where: { $0.type == .title })
    }

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 14)
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if records.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 28))
                            .foregroundColor(MedhaTheme.Colors.textSecondary)
                        Text("No gallery cards yet")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(MedhaTheme.Colors.textSecondary)
                        Button("Create First Card") {
                            store.addDatabaseRecord(databaseId: database.id)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 32)
                    Spacer()
                }
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(records) { rec in
                        galleryCard(record: rec)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }

    @ViewBuilder
    private func galleryCard(record: DatabaseRecord) -> some View {
        let titleVal = titleProperty != nil ? (store.activeDatabaseCellValues[record.id]?[titleProperty!.id]?.valueText ?? "Untitled") : "Untitled"

        VStack(alignment: .leading, spacing: 0) {
            // Card Cover Header
            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 90)

                Image(systemName: database.icon ?? "doc.text.image")
                    .font(.system(size: 26))
                    .foregroundColor(MedhaTheme.Colors.accent.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                // Delete Menu
                Menu {
                    Button(role: .destructive) {
                        store.deleteDatabaseRecord(id: record.id, databaseId: database.id)
                    } label: {
                        Label("Delete Record", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .foregroundColor(Color.black.opacity(0.4))
                        .padding(6)
                }
                .menuStyle(.borderlessButton)
            }

            // Card Body
            VStack(alignment: .leading, spacing: 6) {
                Text(titleVal.isEmpty ? "Untitled" : titleVal)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(MedhaTheme.Colors.textPrimary)
                    .lineLimit(2)

                // Render badges for other non-title properties
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(properties.filter { $0.type != .title }.prefix(3)) { prop in
                        propertyPillRow(record: record, prop: prop)
                    }
                }
                .padding(.top, 2)
            }
            .padding(10)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor).opacity(0.7), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
    }

    @ViewBuilder
    private func propertyPillRow(record: DatabaseRecord, prop: DatabaseProperty) -> some View {
        let cell = store.activeDatabaseCellValues[record.id]?[prop.id]

        HStack(spacing: 4) {
            Image(systemName: prop.type.systemIcon)
                .font(.system(size: 9))
                .foregroundColor(MedhaTheme.Colors.textSecondary)

            Text("\(prop.name):")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(MedhaTheme.Colors.textSecondary)

            if prop.type == .checkbox {
                Image(systemName: (cell?.valueNumber == 1.0) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 9))
                    .foregroundColor((cell?.valueNumber == 1.0) ? .green : .secondary)
            } else if prop.type == .number {
                Text(String(format: "%.1f", cell?.valueNumber ?? 0.0))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(MedhaTheme.Colors.textPrimary)
            } else if prop.type == .status || prop.type == .select {
                Text(cell?.valueText ?? "–")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(3)
            } else {
                Text(cell?.valueText ?? "–")
                    .font(.system(size: 9))
                    .foregroundColor(MedhaTheme.Colors.textPrimary)
                    .lineLimit(1)
            }
        }
    }
}
