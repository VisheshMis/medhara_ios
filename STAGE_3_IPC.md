# Stage 3: Secure Electron Main & Type-Safe IPC Bridge

> **Parent Roadmap**: [WINDOWS_PORT_PLAN.md](file:///Users/visheshmishra/Downloads/medharara/WINDOWS_PORT_PLAN.md)  
> **Status**: Completed ✅  
> **Target Platform**: Windows 10 / 11 (x64) via Electron ContextBridge & IPC Main

---

## 🎯 Stage 3 Objectives

1. **Context-Isolated Bridge Security**:
   - `contextIsolation: true`, `nodeIntegration: false`, and `sandbox: false` (to support better-sqlite3 in main while keeping renderer clean).
   - Unified interface exposed as `window.medhaAPI` (with legacy fallback `window.electronAPI`).
2. **Type-Safe DTOs & Handlers**:
   - `get-due-cards`: Fetches due and new flashcards ordered by urgency.
   - `submit-review`: Atomically updates card stability, difficulty, state, and persists the review event in `review_log`.
   - `db-query` / `db-execute`: Parameterized SQL execution.
   - `db-search-fts`: High-speed FTS5 full-text query with BM25 snippet generation.
   - Window controls (`minimize`, `maximize`, `close`, `isMaximized`).
   - File dialogs (`openAnkiFileDialog`, `openImageFileDialog`, `openPDFFileDialog`, `saveExportFileDialog`).
3. **Automated IPC Verification Suite (`tests/ipc.test.js`)**:
   - Unit tests verifying serialization contracts and atomic updates.

---

## 🚦 Stage 3 Verification Gate

```bash
# 1. Dedicated IPC verification suite
npm run test:ipc

# 2. Complete integration suite
npm test
```
