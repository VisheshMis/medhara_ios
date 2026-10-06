import SwiftUI

public struct TopLeftTimerView: View {
    @ObservedObject public var timerManager: FocusTimerManager
    @State private var isHovered: Bool = false

    public init(timerManager: FocusTimerManager) {
        self.timerManager = timerManager
    }

    private var phaseColor: Color {
        switch timerManager.currentPhase {
        case .focus: return MedhaTheme.Colors.notesAccent
        case .beepAndPause: return MedhaTheme.Colors.danger
        case .microBreak: return MedhaTheme.Colors.success
        case .resetInterval: return MedhaTheme.Colors.warning
        }
    }

    public var body: some View {
        HStack(spacing: 7) {
            // Animated Status Pulse / Icon with progress ring
            ZStack {
                Circle()
                    .stroke(phaseColor.opacity(0.2), lineWidth: 1.5)
                    .frame(width: 20, height: 20)

                Circle()
                    .fill(phaseColor.opacity(timerManager.isRunning ? 0.2 : 0.08))
                    .frame(width: 20, height: 20)

                Image(systemName: timerManager.currentPhase.icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(phaseColor)
                    .symbolRenderingMode(.hierarchical)
            }

            // Monospace Digital Timer & Badge
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(timerManager.formattedTime)
                        .font(MedhaTheme.Typography.roundedTimer)
                        .foregroundColor(MedhaTheme.Colors.textPrimary)

                    Text(timerManager.currentPhase.badgeLabel)
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundColor(phaseColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(phaseColor.opacity(0.12))
                        .clipShape(Capsule(style: .continuous))
                }

                if timerManager.cycleCount > 0 {
                    Text("Cycle \(timerManager.cycleCount + 1)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(MedhaTheme.Colors.textTertiary)
                }
            }

            // Quick Playback Controls
            HStack(spacing: 2) {
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
                .help(timerManager.isRunning ? "Pause (Space)" : "Start 10m Focus Timer")

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
                .help("Reset to 10:00")

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
