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
    @Published public var customFocusDuration: Int = FocusTimerPhase.focus.defaultDuration
    @Published public var customBreakDuration: Int = FocusTimerPhase.microBreak.defaultDuration
    @Published public var isRunning: Bool = false
    @Published public var isMuted: Bool = false
    @Published public var cycleCount: Int = 0

    // Accumulated focus tracking
    public var currentDocId: String? = nil
    private var accumulatedFocusSecondsInSession: Int = 0
    private var uncommittedFocusSeconds: Int = 0
    private var cancellableTimer: AnyCancellable?
    public weak var statsService: FocusStatsService?

    public init(statsService: FocusStatsService? = nil) {
        self.statsService = statsService
        self.remainingSeconds = currentPhase.defaultDuration
        self.customFocusDuration = currentPhase.defaultDuration
        self.customBreakDuration = FocusTimerPhase.microBreak.defaultDuration
    }

    public var progressRatio: Double {
        let total = totalDurationForCurrentPhase
        guard total > 0 else { return 0.0 }
        let elapsed = max(0, total - remainingSeconds)
        return min(max(Double(elapsed) / Double(total), 0.0), 1.0)
    }

    public var totalDurationForCurrentPhase: Int {
        switch currentPhase {
        case .focus: return customFocusDuration
        case .beepAndPause: return FocusTimerPhase.beepAndPause.defaultDuration
        case .microBreak: return customBreakDuration
        case .resetInterval: return FocusTimerPhase.resetInterval.defaultDuration
        }
    }

    public var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public var currentBadgeLabel: String {
        switch currentPhase {
        case .focus:
            let mins = customFocusDuration / 60
            let secs = customFocusDuration % 60
            if secs == 0 {
                return "FOCUS \(mins)m"
            } else {
                return "FOCUS \(mins)m\(secs)s"
            }
        case .beepAndPause:
            return "PAUSE 2s"
        case .microBreak:
            let mins = customBreakDuration / 60
            let secs = customBreakDuration % 60
            if mins > 0 && secs == 0 {
                return "REST \(mins)m"
            } else if mins > 0 {
                return "REST \(mins)m\(secs)s"
            } else {
                return "REST \(secs)s"
            }
        case .resetInterval:
            return "CYCLE 10s"
        }
    }

    public func setFocusDuration(minutes: Int) {
        let newSeconds = max(60, minutes * 60)
        customFocusDuration = newSeconds
        if currentPhase == .focus && !isRunning {
            remainingSeconds = newSeconds
        }
    }

    public func setBreakDuration(minutes: Int) {
        let newSeconds = max(10, minutes * 60)
        customBreakDuration = newSeconds
        if currentPhase == .microBreak && !isRunning {
            remainingSeconds = newSeconds
        }
    }

    public func setBreakDuration(seconds: Int) {
        let newSeconds = max(5, seconds)
        customBreakDuration = newSeconds
        if currentPhase == .microBreak && !isRunning {
            remainingSeconds = newSeconds
        }
    }

    public func setCustomDurations(focusMinutes: Int, breakMinutes: Int) {
        setFocusDuration(minutes: focusMinutes)
        setBreakDuration(minutes: breakMinutes)
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
        flushUncommittedFocus(isCompleted: false)
    }

    public func reset() {
        pause()
        flushUncommittedFocus(isCompleted: false)
        accumulatedFocusSecondsInSession = 0
        currentPhase = .focus
        remainingSeconds = customFocusDuration
    }

    public func skipToNextPhase() {
        advanceToNextPhase()
    }

    public func toggleMute() {
        isMuted.toggle()
    }

    public func tick() {
        if currentPhase == .focus {
            accumulatedFocusSecondsInSession += 1
            uncommittedFocusSeconds += 1
            // Commit incrementally every 10 seconds so stats stay live
            if uncommittedFocusSeconds >= 10 {
                flushUncommittedFocus(isCompleted: false)
            }
        }

        if remainingSeconds > 1 {
            remainingSeconds -= 1
        } else {
            // Reached 0 for current phase!
            handlePhaseCompletion()
        }
    }

    private func flushUncommittedFocus(isCompleted: Bool) {
        guard uncommittedFocusSeconds > 0 else { return }
        let secondsToFlush = uncommittedFocusSeconds
        uncommittedFocusSeconds = 0
        statsService?.recordFocusChunk(
            seconds: secondsToFlush,
            sessionPlanned: customFocusDuration,
            docId: currentDocId,
            isCompleted: isCompleted
        )
    }

    private func handlePhaseCompletion() {
        switch currentPhase {
        case .focus:
            // Flush remaining uncommitted focus seconds and mark completed
            flushUncommittedFocus(isCompleted: true)
            accumulatedFocusSecondsInSession = 0

            // Reached 0: beep twice, pause for 2 seconds
            playTwoBeeps()
            currentPhase = .beepAndPause
            remainingSeconds = FocusTimerPhase.beepAndPause.defaultDuration

        case .beepAndPause:
            // 2s pause finished: count down break/relax duration
            currentPhase = .microBreak
            remainingSeconds = customBreakDuration

        case .microBreak:
            // 30s finished: count down 10s
            currentPhase = .resetInterval
            remainingSeconds = FocusTimerPhase.resetInterval.defaultDuration

        case .resetInterval:
            // 10s finished: repeat cycle back to focus duration
            cycleCount += 1
            currentPhase = .focus
            remainingSeconds = customFocusDuration
        }
    }

    private func advanceToNextPhase() {
        if currentPhase == .focus {
            flushUncommittedFocus(isCompleted: false)
            accumulatedFocusSecondsInSession = 0
        }
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
