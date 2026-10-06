# Stage 4: Flashcards & Study Review Flow (UI Vertical Slice)

> **Parent Roadmap**: [WINDOWS_PORT_PLAN.md](file:///Users/visheshmishra/Downloads/medharara/WINDOWS_PORT_PLAN.md)  
> **Status**: Completed ✅  
> **Target Platform**: Windows 10 / 11 (x64) via HTML5, CSS3 3D Transforms & SQLite Bridge

---

## 🎯 Stage 4 Objectives

1. **3D Card Flip Stage**:
   - `rotateY(180deg)` with `preserve-3d` and tactile cubic-bezier spring physics (`0.34, 1.56, 0.64, 1`).
   - Seamless front (Question + Active Recall) and back (Answer + Consolidation) faces.
2. **Interactive Rating & Live Interval Chips**:
   - Dynamic chips (`chip-again`, `chip-hard`, `chip-good`, `chip-easy`) reflecting actual FSRS computed intervals.
   - Support for mouse clicks and keyboard hotkeys (`Space` to flip, `1`, `2`, `3`, `4` to submit rating).
3. **End-to-End Persistence**:
   - Reviews update the database through the typed IPC bridge (`submitReview`) or local store.
   - Urgency badge on top navigation tab (`due-badge`) accurately tracks remaining count.
4. **Dedicated Simulation Test (`tests/flashcards.test.js`)**:
   - End-to-end verification of the study flow from initial load to database update.

---

## 🚦 Stage 4 Verification Gate

```bash
# 1. Dedicated Flashcard review test suite
npm run test:flashcards

# 2. Complete integration suite
npm test
```
