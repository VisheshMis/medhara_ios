import SwiftUI

public struct TopLeftTimerView: View {
    @ObservedObject public var timerManager: FocusTimerManager
    @State private var isHovered: Bool = false

    public init(timerManager: FocusTimerManager) {
        self.timerManager = timerManager
    }

    private var phaseColor: Color {
        switch timerManager.currentPhase {
        case .focus: return .accentColor
        case .beepAndPause: return .red
        case .microBreak: return .green
        case .resetInterval: return .orange
        }
    }

    public var body: some View {
        HStack(spacing: 6) {
            // Animated Status Pulse / Icon
            ZStack {
                Circle()
                    .fill(phaseColor.opacity(timerManager.isRunning ? 0.25 : 0.1))
                    .frame(width: 20, height: 20)

                Image(systemName: timerManager.currentPhase.icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(phaseColor)
            }

            // Monospace Digital Timer & Badge
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(timerManager.formattedTime)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)

                    Text(timerManager.currentPhase.badgeLabel)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(phaseColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(phaseColor.opacity(0.12))
                        .cornerRadius(3)
                }

                if timerManager.cycleCount > 0 {
                    Text("Cycle \(timerManager.cycleCount + 1)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            // Quick Playback Controls
            HStack(spacing: 3) {
                Button(action: {
                    timerManager.togglePlayPause()
                }) {
                    Image(systemName: timerManager.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(timerManager.isRunning ? "Pause (Space)" : "Start 10m Focus Timer")

                Button(action: {
                    timerManager.skipToNextPhase()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 18, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Skip to next phase")

                Button(action: {
                    timerManager.reset()
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 18, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Reset to 10:00")

                Button(action: {
                    timerManager.toggleMute()
                }) {
                    Image(systemName: timerManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(timerManager.isMuted ? .secondary.opacity(0.5) : .secondary)
                        .frame(width: 18, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(timerManager.isMuted ? "Unmute Beeps" : "Mute Beeps")
            }
            .padding(.leading, 2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.85))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(phaseColor.opacity(timerManager.isRunning ? 0.3 : 0.1), lineWidth: 1)
        )
    }
}
