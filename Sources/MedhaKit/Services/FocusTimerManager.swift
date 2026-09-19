import Foundation
import Combine
import AppKit

public enum FocusTimerPhase: String, CaseIterable, Sendable {
    case focus = "Focus Session"
    case beepAndPause = "Audio Beep & Pause"
    case microBreak = "Micro-Break"
    case resetInterval = "Cycle Reset"

    public var defaultDuration: Int {
        switch self {
        case .focus: return 600         // 10 minutes
        case .beepAndPause: return 2     // 2 seconds
        case .microBreak: return 30      // 30 seconds
        case .resetInterval: return 10   // 10 seconds
        }
    }

    public var badgeLabel: String {
        switch self {
        case .focus: return "FOCUS 10m"
        case .beepAndPause: return "PAUSE 2s"
        case .microBreak: return "REST 30s"
        case .resetInterval: return "CYCLE 10s"
        }
    }

    public var icon: String {
        switch self {
        case .focus: return "timer"
        case .beepAndPause: return "bell.badge.fill"
        case .microBreak: return "cup.and.saucer.fill"
        case .resetInterval: return "arrow.triangle.2.circlepath"
        }
    }
}

@MainActor
public final class FocusTimerManager: ObservableObject {
    @Published public var currentPhase: FocusTimerPhase = .focus
    @Published public var remainingSeconds: Int = FocusTimerPhase.focus.defaultDuration
    @Published public var isRunning: Bool = false
    @Published public var isMuted: Bool = false
    @Published public var cycleCount: Int = 0

    private var cancellableTimer: AnyCancellable?

    public init() {
        self.remainingSeconds = currentPhase.defaultDuration
    }

    public var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public func togglePlayPause() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true

        cancellableTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    public func pause() {
        isRunning = false
        cancellableTimer?.cancel()
        cancellableTimer = nil
    }

    public func reset() {
        pause()
        currentPhase = .focus
        remainingSeconds = FocusTimerPhase.focus.defaultDuration
    }

    public func skipToNextPhase() {
        advanceToNextPhase()
    }

    public func toggleMute() {
        isMuted.toggle()
    }

    public func tick() {
        if remainingSeconds > 1 {
            remainingSeconds -= 1
        } else {
            // Reached 0 for current phase!
            handlePhaseCompletion()
        }
    }

    private func handlePhaseCompletion() {
        switch currentPhase {
        case .focus:
            // Reached 0: beep twice, pause for 2 seconds
            playTwoBeeps()
            currentPhase = .beepAndPause
            remainingSeconds = FocusTimerPhase.beepAndPause.defaultDuration

        case .beepAndPause:
            // 2s pause finished: count down 30s
            currentPhase = .microBreak
            remainingSeconds = FocusTimerPhase.microBreak.defaultDuration

        case .microBreak:
            // 30s finished: count down 10s
            currentPhase = .resetInterval
            remainingSeconds = FocusTimerPhase.resetInterval.defaultDuration

        case .resetInterval:
            // 10s finished: repeat cycle back to 10m
            cycleCount += 1
            currentPhase = .focus
            remainingSeconds = FocusTimerPhase.focus.defaultDuration
        }
    }

    private func advanceToNextPhase() {
        handlePhaseCompletion()
    }

    private func playTwoBeeps() {
        guard !isMuted else { return }
        // First beep
        NSSound.beep()

        // Second beep after 250ms
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self, !self.isMuted else { return }
            NSSound.beep()
        }
    }
}
