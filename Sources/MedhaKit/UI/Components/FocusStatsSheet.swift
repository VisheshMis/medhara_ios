import SwiftUI

public struct FocusStatsSheet: View {
    @ObservedObject public var store: BlockStore
    @ObservedObject public var statsService: FocusStatsService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: Int = 0 // 0: Today, 1: This Week, 2: This Month

    public init(store: BlockStore) {
        self.store = store
        self.statsService = store.focusStatsService
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "timer.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(MedhaTheme.Colors.brandGradient)
                    Text("Focus & Study Statistics")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(MedhaTheme.Colors.textPrimary)
                }

                Spacer()

                Button(action: {
                    store.isFocusStatsPresented = false
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(MedhaTheme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Close (Esc)")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(MedhaTheme.Colors.bgSurface)

            Divider()
                .background(MedhaTheme.Colors.borderHairline)

            // Content Area with Picker
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Hero Summary: Activity Rings + Key Figures
                    heroRingsSection

                    // Segmented Filter: Today / This Week / This Month
                    Picker("", selection: $selectedTab) {
                        Text("Today").tag(0)
                        Text("This Week").tag(1)
                        Text("This Month").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 4)

                    // Tab View Content
                    switch selectedTab {
                    case 0:
                        todayDetailView
                    case 1:
                        weekDetailView
                    default:
                        monthDetailView
                    }

                    // Daily Target Setting
                    targetConfigSection

                    // Recent Sessions Log
                    recentSessionsSection
                }
                .padding(20)
            }
        }
        .frame(width: 520, height: 640)
        .background(MedhaTheme.Colors.bgBase)
        .onAppear {
            statsService.refreshAll()
        }
    }

    // MARK: - Hero Rings Section
    private var heroRingsSection: some View {
        HStack(spacing: 20) {
            MedhaActivityRingsView(
                dailyProgress: statsService.todayStats.progressRatio,
                weeklyProgress: statsService.weekStats.progressRatio,
                consistencyProgress: min(Double(statsService.todayStats.sessionCount) / 4.0, 1.0),
                size: 110,
                ringThickness: 10
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("TODAY'S FOCUS TIME")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(MedhaTheme.Colors.textTertiary)

                Text(statsService.todayStats.formattedDuration)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(MedhaTheme.Colors.textPrimary)

                HStack(spacing: 12) {
                    Label {
                        Text("\(Int(round(statsService.todayStats.progressRatio * 100)))% of goal")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(MedhaTheme.Colors.accentStart)
                    } icon: {
                        Circle()
                            .fill(MedhaTheme.Colors.accentStart)
                            .frame(width: 7, height: 7)
                    }

                    Label {
                        Text("\(statsService.todayStats.sessionCount) sessions")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(MedhaTheme.Colors.graphAccent)
                    } icon: {
                        Circle()
                            .fill(MedhaTheme.Colors.graphAccent)
                            .frame(width: 7, height: 7)
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .background(MedhaTheme.Colors.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MedhaTheme.Colors.borderHairline, lineWidth: 1)
        )
    }

    // MARK: - Today Detail View
    private var todayDetailView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Day Overview")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(MedhaTheme.Colors.textPrimary)

            HStack(spacing: 12) {
                statCard(
                    title: "Goal Target",
                    value: "\(statsService.dailyTargetMinutes)m",
                    subtitle: "Daily focus goal",
                    color: MedhaTheme.Colors.accentStart
                )

                statCard(
                    title: "Focus Time",
                    value: statsService.todayStats.formattedDuration,
                    subtitle: "Actual studied",
                    color: MedhaTheme.Colors.notesAccent
                )

                statCard(
                    title: "Sessions",
                    value: "\(statsService.todayStats.sessionCount)",
                    subtitle: "Focus intervals",
                    color: MedhaTheme.Colors.graphAccent
                )
            }
        }
    }

    // MARK: - Week Detail View (7-Day Bar Chart)
    private var weekDetailView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("7-Day Study Distribution")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(MedhaTheme.Colors.textPrimary)
                Spacer()
                Text("Total: \(statsService.weekStats.formattedDuration)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(MedhaTheme.Colors.notesAccent)
            }

            // 7-Day Bar Chart
            HStack(alignment: .bottom, spacing: 10) {
                let maxMinutes = max(60.0, (statsService.weekStats.dailyBuckets.map { $0.focusedMinutes }.max() ?? 60.0))

                ForEach(statsService.weekStats.dailyBuckets) { bucket in
                    VStack(spacing: 6) {
                        // Numeric minutes label on top
                        Text(bucket.focusedMinutes >= 1 ? "\(Int(bucket.focusedMinutes))m" : "-")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(bucket.isToday ? MedhaTheme.Colors.accentStart : MedhaTheme.Colors.textTertiary)

                        // Bar Capsule
                        let heightFraction = CGFloat(min(1.0, bucket.focusedMinutes / maxMinutes))
                        let barHeight = max(6.0, heightFraction * 90.0)

                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(
                                bucket.isToday
                                ? LinearGradient(colors: [MedhaTheme.Colors.accentStart, MedhaTheme.Colors.accentEnd], startPoint: .top, endPoint: .bottom)
                                : LinearGradient(colors: [MedhaTheme.Colors.notesAccent.opacity(0.8), MedhaTheme.Colors.notesAccent.opacity(0.4)], startPoint: .top, endPoint: .bottom)
                            )
                            .frame(width: 28, height: barHeight)

                        // Day Name
                        Text(bucket.dayLabel)
                            .font(.system(size: 10, weight: bucket.isToday ? .bold : .regular))
                            .foregroundColor(bucket.isToday ? MedhaTheme.Colors.textPrimary : MedhaTheme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(MedhaTheme.Colors.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(MedhaTheme.Colors.borderHairline, lineWidth: 1)
            )

            HStack {
                Text("Daily Average: **\(Int(statsService.weekStats.averageDailyMinutes)) min/day**")
                    .font(.system(size: 11))
                    .foregroundColor(MedhaTheme.Colors.textSecondary)
                Spacer()
            }
        }
    }

    // MARK: - Month Detail View
    private var monthDetailView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Month Overview (\(statsService.monthStats.monthLabel))")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(MedhaTheme.Colors.textPrimary)

            HStack(spacing: 12) {
                statCard(
                    title: "Month Total",
                    value: statsService.monthStats.formattedDuration,
                    subtitle: "Total focused",
                    color: MedhaTheme.Colors.accentStart
                )

                statCard(
                    title: "Active Days",
                    value: "\(statsService.monthStats.activeDaysCount) / \(statsService.monthStats.totalDaysInMonth)",
                    subtitle: "Days studied",
                    color: MedhaTheme.Colors.notesAccent
                )

                statCard(
                    title: "Daily Avg",
                    value: "\(Int(statsService.monthStats.totalMinutes / Double(max(1, statsService.monthStats.activeDaysCount))))m",
                    subtitle: "Per active day",
                    color: MedhaTheme.Colors.graphAccent
                )
            }
        }
    }

    // MARK: - Target Config Section
    private var targetConfigSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Goal")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(MedhaTheme.Colors.textSecondary)

            HStack(spacing: 8) {
                ForEach([30, 45, 60, 90, 120, 180], id: \.self) { mins in
                    Button(action: {
                        statsService.setDailyTargetMinutes(mins)
                    }) {
                        Text("\(mins)m")
                            .font(.system(size: 11, weight: statsService.dailyTargetMinutes == mins ? .bold : .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                statsService.dailyTargetMinutes == mins
                                ? MedhaTheme.Colors.accentStart.opacity(0.18)
                                : MedhaTheme.Colors.bgSurface
                            )
                            .foregroundColor(
                                statsService.dailyTargetMinutes == mins
                                ? MedhaTheme.Colors.accentStart
                                : MedhaTheme.Colors.textSecondary
                            )
                            .clipShape(Capsule(style: .continuous))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(
                                        statsService.dailyTargetMinutes == mins
                                        ? MedhaTheme.Colors.accentStart.opacity(0.5)
                                        : MedhaTheme.Colors.borderHairline,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Recent Sessions Section
    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Study Sessions")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(MedhaTheme.Colors.textPrimary)

            if statsService.recentSessions.isEmpty {
                Text("No study sessions recorded yet. Start the focus timer to track your sessions!")
                    .font(.system(size: 11))
                    .foregroundColor(MedhaTheme.Colors.textTertiary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(statsService.recentSessions) { session in
                        HStack {
                            Circle()
                                .fill(session.isCompleted ? MedhaTheme.Colors.success : MedhaTheme.Colors.accentStart)
                                .frame(width: 6, height: 6)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(session.focusedSeconds / 60)m \(session.focusedSeconds % 60)s focused")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(MedhaTheme.Colors.textPrimary)

                                Text(formattedDate(session.createdAt))
                                    .font(.system(size: 10))
                                    .foregroundColor(MedhaTheme.Colors.textTertiary)
                            }

                            Spacer()

                            Text(session.isCompleted ? "Completed" : "Logged")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(session.isCompleted ? MedhaTheme.Colors.success : MedhaTheme.Colors.textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(MedhaTheme.Colors.bgElevated)
                                .clipShape(Capsule(style: .continuous))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(MedhaTheme.Colors.bgSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(MedhaTheme.Colors.borderHairline, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private func statCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(MedhaTheme.Colors.textTertiary)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(MedhaTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(MedhaTheme.Colors.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(MedhaTheme.Colors.borderHairline, lineWidth: 1)
        )
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
