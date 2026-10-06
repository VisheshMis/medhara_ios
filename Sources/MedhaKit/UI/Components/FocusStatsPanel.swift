import SwiftUI

public struct FocusStatsPanel: View {
    @ObservedObject public var store: BlockStore
    @ObservedObject public var statsService: FocusStatsService
    @ObservedObject public var timerManager: FocusTimerManager

    @State private var selectedTab: Int = 0 // 0: Today, 1: This Week, 2: This Month
    @State private var customStudyMinutesInput: String = "25"
    @State private var customBreakMinutesInput: String = "5"
    @State private var showSavedToast: Bool = false

    public init(store: BlockStore) {
        self.store = store
        self.statsService = store.focusStatsService
        self.timerManager = store.timerManager
        _customStudyMinutesInput = State(initialValue: "\(store.timerManager.customFocusDuration / 60)")
        _customBreakMinutesInput = State(initialValue: "\(max(1, store.timerManager.customBreakDuration / 60))")
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar with Title and Close Button
            HStack(spacing: 8) {
                Image(systemName: "timer.circle.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(MedhaTheme.Colors.brandGradient)

                Text("Focus & Statistics")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(MedhaTheme.Colors.textPrimary)

                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.isFocusStatsPresented = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(MedhaTheme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Close Panel")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // Custom Duration Configuration (Study & Relax)
                    customDurationSection

                    // Hero Summary: Activity Rings + Key Figures
                    heroRingsSection

                    // Time Window Filter: Today / This Week / This Month
                    Picker("", selection: $selectedTab) {
                        Text("Today").tag(0)
                        Text("This Week").tag(1)
                        Text("This Month").tag(2)
                    }
                    .pickerStyle(.segmented)

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
                .padding(14)
            }
        }
        .frame(minWidth: 280, idealWidth: 320, maxWidth: 360)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            statsService.refreshAll()
            customStudyMinutesInput = "\(timerManager.customFocusDuration / 60)"
            let breakSecs = timerManager.customBreakDuration
            if breakSecs >= 60 {
                customBreakMinutesInput = "\(breakSecs / 60)"
            } else {
                customBreakMinutesInput = "\(breakSecs)s"
            }
        }
    }

    // MARK: - Custom Study & Relax Timer Configuration
    private var customDurationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TIMER CONFIGURATION")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(MedhaTheme.Colors.textTertiary)
                Spacer()
                if showSavedToast {
                    Text("Saved!")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundColor(MedhaTheme.Colors.success)
                        .transition(.opacity)
                }
            }

            VStack(spacing: 8) {
                // Study Time Stepper & Input
                HStack(spacing: 8) {
                    Label {
                        Text("Study Time")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(MedhaTheme.Colors.textPrimary)
                    } icon: {
                        Image(systemName: "timer")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(MedhaTheme.Colors.accentStart)
                    }

                    Spacer()

                    let currentStudyMins = timerManager.customFocusDuration / 60
                    HStack(spacing: 6) {
                        Button(action: {
                            let next = max(1, currentStudyMins - 5)
                            timerManager.setFocusDuration(minutes: next)
                            triggerToast()
                        }) {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 13))
                                .foregroundColor(MedhaTheme.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)

                        Text("\(currentStudyMins)m")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(MedhaTheme.Colors.accentStart)
                            .frame(minWidth: 38, alignment: .center)

                        Button(action: {
                            let next = min(180, currentStudyMins + 5)
                            timerManager.setFocusDuration(minutes: next)
                            triggerToast()
                        }) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 13))
                                .foregroundColor(MedhaTheme.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(MedhaTheme.Colors.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                // Relax / Break Time Stepper & Input
                HStack(spacing: 8) {
                    Label {
                        Text("Relax Time")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(MedhaTheme.Colors.textPrimary)
                    } icon: {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(MedhaTheme.Colors.success)
                    }

                    Spacer()

                    let breakSecs = timerManager.customBreakDuration
                    HStack(spacing: 6) {
                        Button(action: {
                            if breakSecs <= 60 {
                                let next = max(10, breakSecs - 10)
                                timerManager.setBreakDuration(seconds: next)
                            } else {
                                let nextMins = max(1, (breakSecs / 60) - 1)
                                timerManager.setBreakDuration(minutes: nextMins)
                            }
                            triggerToast()
                        }) {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 13))
                                .foregroundColor(MedhaTheme.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)

                        let displayBreak = breakSecs < 60 ? "\(breakSecs)s" : "\(breakSecs / 60)m"
                        Text(displayBreak)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(MedhaTheme.Colors.success)
                            .frame(minWidth: 38, alignment: .center)

                        Button(action: {
                            if breakSecs < 60 {
                                let next = breakSecs + 15
                                if next >= 60 {
                                    timerManager.setBreakDuration(minutes: 1)
                                } else {
                                    timerManager.setBreakDuration(seconds: next)
                                }
                            } else {
                                let nextMins = min(60, (breakSecs / 60) + 1)
                                timerManager.setBreakDuration(minutes: nextMins)
                            }
                            triggerToast()
                        }) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 13))
                                .foregroundColor(MedhaTheme.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(MedhaTheme.Colors.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                // Quick Preset Pills
                HStack(spacing: 5) {
                    presetButton(title: "10m / 30s", focusMins: 10, breakSecs: 30)
                    presetButton(title: "25m / 5m", focusMins: 25, breakMins: 5)
                    presetButton(title: "45m / 10m", focusMins: 45, breakMins: 10)
                    presetButton(title: "50m / 10m", focusMins: 50, breakMins: 10)
                }
                .padding(.top, 2)
            }
            .padding(10)
            .background(MedhaTheme.Colors.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(MedhaTheme.Colors.borderHairline, lineWidth: 1)
            )
        }
    }

    private func presetButton(title: String, focusMins: Int, breakMins: Int? = nil, breakSecs: Int? = nil) -> some View {
        Button(action: {
            timerManager.setFocusDuration(minutes: focusMins)
            if let bm = breakMins {
                timerManager.setBreakDuration(minutes: bm)
            } else if let bs = breakSecs {
                timerManager.setBreakDuration(seconds: bs)
            }
            triggerToast()
        }) {
            Text(title)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundColor(MedhaTheme.Colors.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(MedhaTheme.Colors.bgElevated)
                .clipShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func triggerToast() {
        withAnimation(.easeInOut(duration: 0.15)) {
            showSavedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showSavedToast = false
            }
        }
    }

    // MARK: - Hero Rings Section
    private var heroRingsSection: some View {
        HStack(spacing: 14) {
            MedhaActivityRingsView(
                dailyProgress: statsService.todayStats.progressRatio,
                weeklyProgress: statsService.weekStats.progressRatio,
                consistencyProgress: min(Double(statsService.todayStats.sessionCount) / 4.0, 1.0),
                size: 88,
                ringThickness: 8
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("TODAY'S FOCUS")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(MedhaTheme.Colors.textTertiary)

                Text(statsService.todayStats.formattedDuration)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(MedhaTheme.Colors.textPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(MedhaTheme.Colors.accentStart)
                            .frame(width: 6, height: 6)
                        Text("\(Int(round(statsService.todayStats.progressRatio * 100)))% of goal")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(MedhaTheme.Colors.accentStart)
                    }

                    HStack(spacing: 5) {
                        Circle()
                            .fill(MedhaTheme.Colors.graphAccent)
                            .frame(width: 6, height: 6)
                        Text("\(statsService.todayStats.sessionCount) sessions")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(MedhaTheme.Colors.graphAccent)
                    }
                }
            }

            Spacer()
        }
        .padding(12)
        .background(MedhaTheme.Colors.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MedhaTheme.Colors.borderHairline, lineWidth: 1)
        )
    }

    // MARK: - Today Detail View
    private var todayDetailView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Day Overview")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(MedhaTheme.Colors.textPrimary)

            HStack(spacing: 8) {
                statCard(
                    title: "Target",
                    value: "\(statsService.dailyTargetMinutes)m",
                    subtitle: "Daily goal",
                    color: MedhaTheme.Colors.accentStart
                )

                statCard(
                    title: "Focus Time",
                    value: statsService.todayStats.formattedDuration,
                    subtitle: "Studied",
                    color: MedhaTheme.Colors.notesAccent
                )

                statCard(
                    title: "Sessions",
                    value: "\(statsService.todayStats.sessionCount)",
                    subtitle: "Intervals",
                    color: MedhaTheme.Colors.graphAccent
                )
            }
        }
    }

    // MARK: - Week Detail View (7-Day Bar Chart)
    private var weekDetailView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("7-Day Distribution")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(MedhaTheme.Colors.textPrimary)
                Spacer()
                Text("Total: \(statsService.weekStats.formattedDuration)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(MedhaTheme.Colors.notesAccent)
            }

            // 7-Day Bar Chart
            HStack(alignment: .bottom, spacing: 6) {
                let maxMinutes = max(60.0, (statsService.weekStats.dailyBuckets.map { $0.focusedMinutes }.max() ?? 60.0))

                ForEach(statsService.weekStats.dailyBuckets) { bucket in
                    VStack(spacing: 4) {
                        Text(bucket.focusedMinutes >= 1 ? "\(Int(bucket.focusedMinutes))m" : "-")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(bucket.isToday ? MedhaTheme.Colors.accentStart : MedhaTheme.Colors.textTertiary)

                        let heightFraction = CGFloat(min(1.0, bucket.focusedMinutes / maxMinutes))
                        let barHeight = max(4.0, heightFraction * 65.0)

                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .fill(
                                bucket.isToday
                                ? LinearGradient(colors: [MedhaTheme.Colors.accentStart, MedhaTheme.Colors.accentEnd], startPoint: .top, endPoint: .bottom)
                                : LinearGradient(colors: [MedhaTheme.Colors.notesAccent.opacity(0.8), MedhaTheme.Colors.notesAccent.opacity(0.4)], startPoint: .top, endPoint: .bottom)
                            )
                            .frame(width: 20, height: barHeight)

                        Text(bucket.dayLabel)
                            .font(.system(size: 9, weight: bucket.isToday ? .bold : .regular))
                            .foregroundColor(bucket.isToday ? MedhaTheme.Colors.textPrimary : MedhaTheme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(MedhaTheme.Colors.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(MedhaTheme.Colors.borderHairline, lineWidth: 1)
            )

            HStack {
                Text("Daily Avg: **\(Int(statsService.weekStats.averageDailyMinutes)) min/day**")
                    .font(.system(size: 10.5))
                    .foregroundColor(MedhaTheme.Colors.textSecondary)
                Spacer()
            }
        }
    }

    // MARK: - Month Detail View
    private var monthDetailView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Month Overview (\(statsService.monthStats.monthLabel))")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(MedhaTheme.Colors.textPrimary)

            HStack(spacing: 8) {
                statCard(
                    title: "Month Total",
                    value: statsService.monthStats.formattedDuration,
                    subtitle: "Focused",
                    color: MedhaTheme.Colors.accentStart
                )

                statCard(
                    title: "Active Days",
                    value: "\(statsService.monthStats.activeDaysCount)/\(statsService.monthStats.totalDaysInMonth)",
                    subtitle: "Days",
                    color: MedhaTheme.Colors.notesAccent
                )

                statCard(
                    title: "Daily Avg",
                    value: "\(Int(statsService.monthStats.totalMinutes / Double(max(1, statsService.monthStats.activeDaysCount))))m",
                    subtitle: "Per active",
                    color: MedhaTheme.Colors.graphAccent
                )
            }
        }
    }

    // MARK: - Target Config Section
    private var targetConfigSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Daily Goal Target")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(MedhaTheme.Colors.textSecondary)

            HStack(spacing: 6) {
                ForEach([30, 45, 60, 90, 120], id: \.self) { mins in
                    Button(action: {
                        statsService.setDailyTargetMinutes(mins)
                    }) {
                        Text("\(mins)m")
                            .font(.system(size: 10, weight: statsService.dailyTargetMinutes == mins ? .bold : .medium))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Study Sessions")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(MedhaTheme.Colors.textPrimary)

            if statsService.recentSessions.isEmpty {
                Text("No study sessions recorded yet.")
                    .font(.system(size: 10.5))
                    .foregroundColor(MedhaTheme.Colors.textTertiary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 5) {
                    ForEach(statsService.recentSessions.prefix(5)) { session in
                        HStack {
                            Circle()
                                .fill(session.isCompleted ? MedhaTheme.Colors.success : MedhaTheme.Colors.accentStart)
                                .frame(width: 5, height: 5)

                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(session.focusedSeconds / 60)m \(session.focusedSeconds % 60)s focused")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(MedhaTheme.Colors.textPrimary)

                                Text(formattedDate(session.createdAt))
                                    .font(.system(size: 9))
                                    .foregroundColor(MedhaTheme.Colors.textTertiary)
                            }

                            Spacer()

                            Text(session.isCompleted ? "Done" : "Logged")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(session.isCompleted ? MedhaTheme.Colors.success : MedhaTheme.Colors.textSecondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(MedhaTheme.Colors.bgElevated)
                                .clipShape(Capsule(style: .continuous))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(MedhaTheme.Colors.bgSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(MedhaTheme.Colors.borderHairline, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private func statCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(MedhaTheme.Colors.textTertiary)

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(subtitle)
                .font(.system(size: 8.5))
                .foregroundColor(MedhaTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(MedhaTheme.Colors.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
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
