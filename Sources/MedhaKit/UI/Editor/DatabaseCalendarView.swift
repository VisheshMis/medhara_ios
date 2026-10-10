import SwiftUI

public struct DatabaseCalendarView: View {
    @ObservedObject public var store: BlockStore
    public let database: NotionDatabase

    @State private var selectedMonth: Date = Date()

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

    private var dateProperty: DatabaseProperty? {
        properties.first(where: { $0.type == .date }) ??
        properties.first(where: { $0.type == .createdTime })
    }

    private var titleProperty: DatabaseProperty? {
        properties.first(where: { $0.type == .title })
    }

    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Month Header Controls
            HStack {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)

                Text(monthYearString(for: selectedMonth))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(MedhaTheme.Colors.textPrimary)

                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)

                Button("Today") {
                    selectedMonth = Date()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)

                Spacer()

                if let dateProp = dateProperty {
                    Text("Mapped to: \(dateProp.name)")
                        .font(.system(size: 10))
                        .foregroundColor(MedhaTheme.Colors.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            // Day of Week Header
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(MedhaTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)

            // Month Days Grid
            let days = generateDaysInMonth(for: selectedMonth)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, dayDate in
                    if let date = dayDate {
                        calendarDayCell(date: date)
                    } else {
                        Color.clear
                            .frame(height: 70)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private func calendarDayCell(date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let matchingRecords = recordsForDay(date: date)

        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 10, weight: isToday ? .bold : .medium))
                    .foregroundColor(isToday ? .white : MedhaTheme.Colors.textPrimary)
                    .frame(width: 18, height: 18)
                    .background(isToday ? MedhaTheme.Colors.accent : Color.clear)
                    .clipShape(Circle())
                Spacer()
            }

            // Record Chips in Day
            ForEach(matchingRecords.prefix(2)) { rec in
                let titleVal = titleProperty != nil ? (store.activeDatabaseCellValues[rec.id]?[titleProperty!.id]?.valueText ?? "Task") : "Task"
                Text(titleVal.isEmpty ? "Task" : titleVal)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(MedhaTheme.Colors.accent)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MedhaTheme.Colors.accent.opacity(0.12))
                    .cornerRadius(3)
            }

            if matchingRecords.count > 2 {
                Text("+\(matchingRecords.count - 2) more")
                    .font(.system(size: 8))
                    .foregroundColor(MedhaTheme.Colors.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(4)
        .frame(height: 70)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
        .cornerRadius(6)
        .border(Color(NSColor.separatorColor).opacity(0.4), width: 0.5)
    }

    private func recordsForDay(date: Date) -> [DatabaseRecord] {
        records.filter { rec in
            guard let dateProp = dateProperty else { return false }
            let cell = store.activeDatabaseCellValues[rec.id]?[dateProp.id]
            let recordDate = cell?.valueDate ?? rec.createdAt
            return calendar.isDate(recordDate, inSameDayAs: date)
        }
    }

    private func changeMonth(by amount: Int) {
        if let newDate = calendar.date(byAdding: .month, value: amount, to: selectedMonth) {
            selectedMonth = newDate
        }
    }

    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func generateDaysInMonth(for date: Date) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return [] }
        let firstDay = monthInterval.start
        let weekdayOfFirst = calendar.component(.weekday, from: firstDay) // 1 = Sunday

        var days: [Date?] = Array(repeating: nil, count: weekdayOfFirst - 1)

        let range = calendar.range(of: .day, in: .month, for: date)!
        for day in range {
            if let dayDate = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(dayDate)
            }
        }
        return days
    }
}
