# Phase 8: Quick Capture Scratchpad & Flashcard Creator UI

> **Parent Roadmap**: [ANDROID_APP_INTEGRATION_AND_SYNC.md](../../ANDROID_APP_INTEGRATION_AND_SYNC.md)  
> **Target Subsystem**: Mobile Quick Capture Workflow  

---

## 🎯 Phase Objective
Implement zero-friction Quick Capture interfaces in the Android companion app: a global Floating Action Button (FAB) that opens modal bottom sheets for capturing scratchpad text notes (defaulting to an "Inbox" document) or creating quick front/back flashcards, instantly saving them locally and marking them for background sync.

---

## 🚀 Capture Flows & Modals

### 1. Global Floating Action Button (FAB)
- Positioned in bottom-right corner of the main app scaffolding.
- On tap: Expands into two options:
  - 📝 **Quick Note**: Capture an idea or thought into the default Inbox note.
  - 🗂️ **Quick Flashcard**: Add a new flashcard to a selected deck.

---

### 2. Quick Note Bottom Sheet (`QuickNoteSheet.kt`)
- Text field with auto-focus and auto-keyboard presentation.
- Optional dropdown to pick destination notebook (defaults to active notebook or "Inbox").
- "Save" action:
  1. Finds or creates an "Inbox" document in the active notebook.
  2. Inserts a new `block` row with `type = 'paragraph'` or `bullet`.
  3. Triggers CDC logging in `sync_change_log`.
  4. Dismisses sheet with a subtle confirmation snackbar.

---

### 3. Quick Flashcard Bottom Sheet (`QuickCardSheet.kt`)
- Two input fields: **Front (Question)** and **Back (Answer)**.
- Optional hint field.
- Deck selector dropdown.
- "Save & Add Another" button for rapid multi-card batching during lectures or study sessions.
- Saves directly to `flashcard` table with `fsrsState = 0` (New), default stability, and `due = Date()`.

---

## 🧪 Verification Gate
- Capturing a quick note writes directly to SQLite in < 50ms without blocking UI.
- Creating a flashcard immediately reflects in the deck's "New Cards" count badge.
- Both operations properly record rows in `sync_change_log` ready for upload.
