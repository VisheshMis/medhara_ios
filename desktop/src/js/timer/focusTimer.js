// Medha Windows Desktop — Focus Timer Manager
// 100% faithful port of FocusTimerManager.swift
// Implements Focus (600s) -> Beep & Pause (2s) -> Micro-Break (30s) -> Cycle Reset (10s) cycle

const FocusTimerPhase = {
    Focus: 'Focus Session',
    BeepAndPause: 'Audio Beep & Pause',
    MicroBreak: 'Micro-Break',
    ResetInterval: 'Cycle Reset'
};

const PhaseDuration = {
    [FocusTimerPhase.Focus]: 600,       // 10 minutes (600s)
    [FocusTimerPhase.BeepAndPause]: 2,  // 2 seconds
    [FocusTimerPhase.MicroBreak]: 30,   // 30 seconds
    [FocusTimerPhase.ResetInterval]: 10 // 10 seconds
};

class FocusTimerManager {
    constructor() {
        this.currentPhase = FocusTimerPhase.Focus;
        this.remainingSeconds = PhaseDuration[FocusTimerPhase.Focus];
        this.isRunning = false;
        this.isMuted = false;
        this.cycleCount = 0;
        this.timer = null;
        this.listeners = [];
    }

    subscribe(fn) {
        this.listeners.push(fn);
        return () => { this.listeners = this.listeners.filter(l => l !== fn); };
    }

    notify() {
        for (const fn of this.listeners) fn(this);
    }

    get formattedTime() {
        const mins = Math.floor(this.remainingSeconds / 60);
        const secs = this.remainingSeconds % 60;
        return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
    }

    get badgeLabel() {
        switch (this.currentPhase) {
            case FocusTimerPhase.Focus: return 'FOCUS 10m';
            case FocusTimerPhase.BeepAndPause: return 'PAUSE 2s';
            case FocusTimerPhase.MicroBreak: return 'REST 30s';
            case FocusTimerPhase.ResetInterval: return 'CYCLE 10s';
        }
    }

    togglePlayPause() {
        if (this.isRunning) this.pause();
        else this.start();
    }

    start() {
        if (this.isRunning) return;
        this.isRunning = true;
        this.timer = setInterval(() => this.tick(), 1000);
        this.notify();
    }

    pause() {
        this.isRunning = false;
        if (this.timer) {
            clearInterval(this.timer);
            this.timer = null;
        }
        this.notify();
    }

    reset() {
        this.pause();
        this.currentPhase = FocusTimerPhase.Focus;
        this.remainingSeconds = PhaseDuration[FocusTimerPhase.Focus];
        this.notify();
    }

    skipToNextPhase() {
        this.handlePhaseCompletion();
    }

    tick() {
        if (this.remainingSeconds > 1) {
            this.remainingSeconds -= 1;
        } else {
            this.handlePhaseCompletion();
        }
        this.notify();
    }

    handlePhaseCompletion() {
        switch (this.currentPhase) {
            case FocusTimerPhase.Focus:
                this.currentPhase = FocusTimerPhase.BeepAndPause;
                this.remainingSeconds = PhaseDuration[FocusTimerPhase.BeepAndPause];
                break;
            case FocusTimerPhase.BeepAndPause:
                this.currentPhase = FocusTimerPhase.MicroBreak;
                this.remainingSeconds = PhaseDuration[FocusTimerPhase.MicroBreak];
                break;
            case FocusTimerPhase.MicroBreak:
                this.currentPhase = FocusTimerPhase.ResetInterval;
                this.remainingSeconds = PhaseDuration[FocusTimerPhase.ResetInterval];
                break;
            case FocusTimerPhase.ResetInterval:
                this.cycleCount += 1;
                this.currentPhase = FocusTimerPhase.Focus;
                this.remainingSeconds = PhaseDuration[FocusTimerPhase.Focus];
                break;
        }
    }
}

if (typeof module !== 'undefined') {
    module.exports = { FocusTimerManager, FocusTimerPhase, PhaseDuration };
}
