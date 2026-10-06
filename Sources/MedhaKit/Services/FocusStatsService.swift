import Foundation
import Combine
import GRDB

public struct DayFocusBucket: Identifiable, Sendable {
    public var id: String { dayLabel }
    public let dayLabel: String      // e.g. "Mon", "Tue", etc.
    public let fullDateString: String // "yyyy-MM-dd"
    public let focusedSeconds: Int
    public let isToday: Bool

    public var focusedMinutes: Double {
        Double(focusedSeconds) / 60.0
    }

    public init(dayLabel: String, fullDateString: String, focusedSeconds: Int, isToday: Bool) {
        self.dayLabel = dayLabel
        self.fullDateString = fullDateString
        self.focusedSeconds = focusedSeconds
        self.isToday = isToday
    }
}

public struct DayFocusStats: Sendable {
    public let totalSeconds: Int
    public let targetMinutes: Int
    public let sessionCount: Int

    public var totalMinutes: Double {
        Double(totalSeconds) / 60.0
    }

    public var progressRatio: Double {
        guard targetMinutes > 0 else { return 0.0 }
        return min(totalMinutes / Double(targetMinutes), 2.0)
    }

    public var formattedDuration: String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

public struct WeekFocusStats: Sendable {
    public let totalSeconds: Int
    public let weeklyTargetMinutes: Int
    public let dailyBuckets: [DayFocusBucket]
    public let averageDailyMinutes: Double

    public var totalMinutes: Double {
        Double(totalSeconds) / 60.0
    }

    public var progressRatio: Double {
        guard weeklyTargetMinutes > 0 else { return 0.0 }
        return min(totalMinutes / Double(weeklyTargetMinutes), 2.0)
    }

    public var formattedDuration: String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

public struct MonthFocusStats: Sendable {
    public let totalSeconds: Int
    public let activeDaysCount: Int
    public let totalDaysInMonth: Int
    public let monthLabel: String

    public var totalMinutes: Double {
        Double(totalSeconds) / 60.0
    }

    public var totalHours: Double {
        Double(totalSeconds) / 3600.0
    }

    public var formattedDuration: String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

@MainActor
public final class FocusStatsService: ObservableObject {
    public static let shared = FocusStatsService()

    private let dbWriter: any DatabaseWriter
    private let targetKey = "Medha_DailyFocusTargetMinutes"

    @Published public var dailyTargetMinutes: Int = 60
    @Published public var todayStats: DayFocusStats = DayFocusStats(totalSeconds: 0, targetMinutes: 60, sessionCount: 0)
    @Published public var weekStats: WeekFocusStats = WeekFocusStats(totalSeconds: 0, weeklyTargetMinutes: 420, dailyBuckets: [], averageDailyMinutes: 0)
    @Published public var monthStats: MonthFocusStats = MonthFocusStats(totalSeconds: 0, activeDaysCount: 0, totalDaysInMonth: 30, monthLabel: "")
    @Published public var recentSessions: [FocusSession] = []

    public init(dbWriter: any DatabaseWriter = DatabaseManager.shared.dbWriter) {
        self.dbWriter = dbWriter
        let savedTarget = UserDefaults.standard.integer(forKey: targetKey)
        self.dailyTargetMinutes = savedTarget > 0 ? savedTarget : 60
        refreshAll()
    }

    public func setDailyTargetMinutes(_ minutes: Int) {
        guard minutes > 0 else { return }
        dailyTargetMinutes = minutes
        UserDefaults.standard.set(minutes, forKey: targetKey)
        refreshAll()
    }

    @discardableResult
    public func recordFocusChunk(seconds: Int, sessionPlanned: Int, docId: String? = nil, isCompleted: Bool = false) -> FocusSession? {
        guard seconds > 0 else { return nil }
        let now = Date()
        let session = FocusSession(
            id: UUID().uuidString,
            durationSeconds: sessionPlanned,
            focusedSeconds: seconds,
            phase: "focus",
            docId: docId,
            createdAt: now,
            completedAt: isCompleted ? now : nil,
            isCompleted: isCompleted
        )

        do {
            try dbWriter.write { db in
                try session.insert(db)
            }
            refreshAll()
            return session
        } catch {
            print("FocusStatsService: Error inserting focus session: \(error)")
            return nil
        }
    }

    public func refreshAll() {
        let calendar = Calendar.current
        let now = Date()

        do {
            let allSessions: [FocusSession] = try dbWriter.read { db in
                try FocusSession.order(FocusSession.Columns.createdAt.desc).fetchAll(db)
            }
            self.recentSessions = Array(allSessions.prefix(20))

            // 1. Calculate Today's Stats
            let todayStart = calendar.startOfDay(for: now)
            let todaySessions = allSessions.filter { $0.createdAt >= todayStart && $0.createdAt <= now }
            let todaySeconds = todaySessions.reduce(0) { $0 + $1.focusedSeconds }
            let todayCompletedCount = todaySessions.filter { $0.isCompleted }.count
            self.todayStats = DayFocusStats(
                totalSeconds: todaySeconds,
                targetMinutes: dailyTargetMinutes,
                sessionCount: max(todaySessions.count, todayCompletedCount)
            )

            // 2. Calculate This Week's Stats (Monday to Sunday)
            var weekCalendar = Calendar(identifier: .gregorian)
            weekCalendar.firstWeekday = 2 // Monday
            let weekStart = weekCalendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: now).date ?? todayStart

            var buckets: [DayFocusBucket] = []
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEE"
            let fullDateFormatter = DateFormatter()
            fullDateFormatter.dateFormat = "yyyy-MM-dd"

            var totalWeekSec = 0
            for dayOffset in 0..<7 {
                if let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
                    let dayBegin = calendar.startOfDay(for: dayDate)
                    let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayBegin)!
                    let daySessions = allSessions.filter { $0.createdAt >= dayBegin && $0.createdAt < dayEnd }
                    let sec = daySessions.reduce(0) { $0 + $1.focusedSeconds }
                    totalWeekSec += sec
                    let isToday = calendar.isDate(dayDate, inSameDayAs: now)
                    buckets.append(DayFocusBucket(
                        dayLabel: dayFormatter.string(from: dayDate),
                        fullDateString: fullDateFormatter.string(from: dayDate),
                        focusedSeconds: sec,
                        isToday: isToday
                    ))
                }
            }

            let daysElapsedInWeek = max(1, calendar.component(.weekday, from: now) - 1)
            let avgDailyMin = Double(totalWeekSec) / 60.0 / Double(daysElapsedInWeek)

            self.weekStats = WeekFocusStats(
                totalSeconds: totalWeekSec,
                weeklyTargetMinutes: dailyTargetMinutes * 7,
                dailyBuckets: buckets,
                averageDailyMinutes: avgDailyMin
            )

            // 3. Calculate This Month's Stats
            let monthComps = calendar.dateComponents([.year, .month], from: now)
            let monthStart = calendar.date(from: monthComps) ?? todayStart
            let range = calendar.range(of: .day, in: .month, for: now)
            let totalDaysInMonth = range?.count ?? 30

            let monthSessions = allSessions.filter { $0.createdAt >= monthStart && $0.createdAt <= now }
            let totalMonthSec = monthSessions.reduce(0) { $0 + $1.focusedSeconds }

            var activeDays = Set<String>()
            for s in monthSessions {
                activeDays.insert(fullDateFormatter.string(from: s.createdAt))
            }

            let monthNameFormatter = DateFormatter()
            monthNameFormatter.dateFormat = "MMMM"

            self.monthStats = MonthFocusStats(
                totalSeconds: totalMonthSec,
                activeDaysCount: activeDays.count,
                totalDaysInMonth: totalDaysInMonth,
                monthLabel: monthNameFormatter.string(from: now)
            )

        } catch {
            print("FocusStatsService: Error reading focus sessions: \(error)")
        }
    }
}
