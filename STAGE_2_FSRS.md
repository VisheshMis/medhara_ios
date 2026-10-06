# Stage 2: FSRS-4.5 Spaced Repetition Mathematical Engine

> **Parent Roadmap**: [WINDOWS_PORT_PLAN.md](file:///Users/visheshmishra/Downloads/medharara/WINDOWS_PORT_PLAN.md)  
> **Status**: Completed ✅  
> **Target Platform**: Windows 10 / 11 (x64) via Node.js & Browser Client

---

## 🎯 Stage 2 Objectives

1. **Exact 17-Parameter Mathematical Parity**:
   - Port all 17 weights and formulas from [FSRSScheduler.swift](file:///Users/visheshmishra/Downloads/medharara/Sources/MedhaKit/Services/FSRSScheduler.swift) with 100% parameter accuracy.
   - Retrievability: $R(t, S) = (1 + 19 \cdot \frac{t}{S})^{-0.5}$.
   - Initial Stabilities: $S_0(G) = \max(0.1, w_{G-1})$ for ratings $G \in \{1, 2, 3, 4\}$.
   - Initial Difficulties: $D_0(G) = \min(10.0, \max(1.0, w_4 - \exp(w_5 \cdot (G - 1)) + 1.0))$.
   - Next Difficulty: $D' = w_7 \cdot D_0(\text{Good}) + (1 - w_7) \cdot (D + \Delta D)$.
   - Recall Stability ($S'_r$) with Hard penalty ($w_{15}$) and Easy bonus ($w_{16}$).
   - Forget Stability ($S'_f$) with difficulty dampening and retrievability rebound.
   - Interval Scheduling: $I = \text{round}\left(\frac{S}{19} \cdot (R_{\text{target}}^{-2} - 1)\right)$.
2. **Preview Intervals Functionality**:
   - Compute real-time next interval previews for Again, Hard, Good, and Easy chips simultaneously without side-effects.
3. **Dedicated Mathematical Verification Suite (`tests/fsrs.test.js`)**:
   - Automated unit tests asserting retention targets, lapse counters, stability transitions, and human-readable formatters.

---

## 🚦 Stage 2 Verification Gate

```bash
# 1. Dedicated FSRS mathematical test suite
npm run test:fsrs

# 2. Complete integration suite
npm test
```
