import SwiftUI

public struct TopLeftTimerView: View {
    @ObservedObject public var timerManager: FocusTimerManager
    public var onOpenStats: (() -> Void)? = nil
    @State private var isHovered: Bool = false

    public init(timerManager: FocusTimerManager, onOpenStats: (() -> Void)? = nil) {
        self.timerManager = timerManager
        self.onOpenStats = onOpenStats
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
        HStack(spacing: 7) {
            // Animated Status Pulse / Icon with Circular Countdown Progress Arc
            ZStack {
                // Background track
                Circle()
                    .stroke(phaseColor.opacity(0.2), lineWidth: 2)
                    .frame(width: 22, height: 22)

                // Circular countdown progress ring
                Circle()
                    .trim(from: 0, to: CGFloat(timerManager.progressRatio))
                    .stroke(
                        LinearGradient(
                            colors: [phaseColor, phaseColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 22, height: 22)

                Circle()
                    .fill(phaseColor.opacity(timerManager.isRunning ? 0.2 : 0.08))
                    .frame(width: 18, height: 18)

                Image(systemName: timerManager.currentPhase.icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(phaseColor)
                    .symbolRenderingMode(.hierarchical)
            }

            // Monospace Digital Timer & Duration Selector Menu
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(timerManager.formattedTime)
                        .font(MedhaTheme.Typography.roundedTimer)
                        .foregroundColor(MedhaTheme.Colors.textPrimary)

                    // Clickable Preset & Custom Options Menu
                    Menu {
                        Section("Study Duration") {
                            Button("10 Minutes (Default)") {
                                timerManager.setFocusDuration(minutes: 10)
                            }
                            Button("15 Minutes") {
                                timerManager.setFocusDuration(minutes: 15)
                            }
                            Button("25 Minutes (Classic Pomodoro)") {
                                timerManager.setFocusDuration(minutes: 25)
                            }
                            Button("45 Minutes (Deep Work)") {
                                timerManager.setFocusDuration(minutes: 45)
                            }
                            Button("60 Minutes (Lecture)") {
                                timerManager.setFocusDuration(minutes: 60)
                            }
                        }

                        Section("Relax / Break Duration") {
                            Button("30 Seconds (Micro-Break)") {
                                timerManager.setBreakDuration(seconds: 30)
                            }
                            Button("5 Minutes (Standard Rest)") {
                                timerManager.setBreakDuration(minutes: 5)
                            }
                            Button("10 Minutes (Long Rest)") {
                                timerManager.setBreakDuration(minutes: 10)
                            }
                            Button("15 Minutes") {
                                timerManager.setBreakDuration(minutes: 15)
                            }
                        }

                        Section("Custom Timing") {
                            Button("Configure Custom Study & Relax...") {
                                onOpenStats?()
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
                    .help("Change study or relax duration")
                }

                if timerManager.cycleCount > 0 {
                    Text("Cycle \(timerManager.cycleCount + 1)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(MedhaTheme.Colors.textTertiary)
                }
            }

            // Controls & Statistics Button
            HStack(spacing: 3) {
                Button(action: {
                    timerManager.togglePlayPause()
                }) {
                    Image(systemName: timerManager.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(MedhaTheme.Colors.textSecondary)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(timerManager.isRunning ? "Pause" : "Start Focus Timer")

                Button(action: {
                    timerManager.skipToNextPhase()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(MedhaTheme.Colors.textTertiary)
                        .frame(width: 16, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Skip to next phase")

                Button(action: {
                    timerManager.reset()
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(MedhaTheme.Colors.textTertiary)
                        .frame(width: 16, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Reset Session")

                Button(action: {
                    timerManager.toggleMute()
                }) {
                    Image(systemName: timerManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(timerManager.isMuted ? MedhaTheme.Colors.textTertiary.opacity(0.4) : MedhaTheme.Colors.textTertiary)
                        .frame(width: 16, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(timerManager.isMuted ? "Unmute Beeps" : "Mute Beeps")

                if let openStats = onOpenStats {
                    Divider()
                        .frame(height: 12)
                        .background(MedhaTheme.Colors.borderHairline)
                        .padding(.horizontal, 1)

                    Button(action: {
                        openStats()
                    }) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundColor(MedhaTheme.Colors.accentStart)
                            .frame(width: 16, height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Study Statistics & Activity Rings (⌘⇧T)")
                }
            }
            .padding(.leading, 1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(MedhaTheme.Colors.bgSurface.opacity(0.85))
        .clipShape(Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(
                    timerManager.isRunning ? phaseColor.opacity(0.35) : MedhaTheme.Colors.borderHairline,
                    lineWidth: 1
                )
        )
    }
}
