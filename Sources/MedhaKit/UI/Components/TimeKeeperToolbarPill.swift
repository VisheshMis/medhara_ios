import SwiftUI

public struct TimeKeeperToolbarPill: View {
    @ObservedObject public var timerManager: FocusTimerManager
    public var onOpenStats: (() -> Void)? = nil
    public var isCompact: Bool = false

    public init(timerManager: FocusTimerManager, onOpenStats: (() -> Void)? = nil, isCompact: Bool = false) {
        self.timerManager = timerManager
        self.onOpenStats = onOpenStats
        self.isCompact = isCompact
    }

    private var phaseColor: Color {
        switch timerManager.currentPhase {
        case .focus: return MedhaTheme.Colors.accentStart
        case .beepAndPause: return MedhaTheme.Colors.danger
        case .microBreak: return MedhaTheme.Colors.success
        case .resetInterval: return MedhaTheme.Colors.warning
        }
    }

    public var body: some View {
        HStack(spacing: 5) {
            // Circular Countdown Progress Indicator
            ZStack {
                Circle()
                    .stroke(phaseColor.opacity(0.2), lineWidth: 1.5)
                    .frame(width: 16, height: 16)

                Circle()
                    .trim(from: 0, to: CGFloat(timerManager.progressRatio))
                    .stroke(phaseColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 16, height: 16)

                Image(systemName: timerManager.currentPhase.icon)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(phaseColor)
            }

            // Digital Time Text
            Text(timerManager.formattedTime)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(MedhaTheme.Colors.textPrimary)

            // Preset Menu
            Menu {
                Section("Focus Duration") {
                    Button("15 Minutes") { timerManager.setFocusDuration(minutes: 15) }
                    Button("25 Minutes (Pomodoro)") { timerManager.setFocusDuration(minutes: 25) }
                    Button("45 Minutes (Deep Work)") { timerManager.setFocusDuration(minutes: 45) }
                    Button("60 Minutes") { timerManager.setFocusDuration(minutes: 60) }
                }

                Section("Break Duration") {
                    Button("30 Seconds") { timerManager.setBreakDuration(seconds: 30) }
                    Button("5 Minutes") { timerManager.setBreakDuration(minutes: 5) }
                    Button("10 Minutes") { timerManager.setBreakDuration(minutes: 10) }
                }

                if let openStats = onOpenStats {
                    Divider()
                    Button("Study Statistics & Activity...") {
                        openStats()
                    }
                }
            } label: {
                Text(timerManager.currentBadgeLabel)
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundColor(phaseColor)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(phaseColor.opacity(0.12))
                    .clipShape(Capsule(style: .continuous))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Study presets & settings")

            // Play / Pause Toggle
            Button(action: {
                timerManager.togglePlayPause()
            }) {
                Image(systemName: timerManager.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(MedhaTheme.Colors.textSecondary)
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(timerManager.isRunning ? "Pause Focus Timer" : "Start Focus Timer")

            // Reset / Skip on hover or when not compact
            if !isCompact {
                Button(action: {
                    timerManager.reset()
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(MedhaTheme.Colors.textTertiary)
                        .frame(width: 12, height: 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Reset Focus Session")
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(MedhaTheme.Colors.bgSurface.opacity(0.9))
        .clipShape(Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(
                    timerManager.isRunning ? phaseColor.opacity(0.4) : MedhaTheme.Colors.borderHairline,
                    lineWidth: 1
                )
        )
    }
}
