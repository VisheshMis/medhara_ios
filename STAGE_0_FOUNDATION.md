# Stage 0: Architecture, Toolchain & Foundation Scaffold

> **Parent Specification**: [WINDOWS_PORT_PLAN.md](file:///Users/visheshmishra/Downloads/medharara/WINDOWS_PORT_PLAN.md)  
> **Status**: Completed ✅  
> **Target Platform**: Windows 10 / 11 (x64) via Electron + TypeScript + Node.js

---

## 🎯 Stage 0 Objective

Establish a rock-solid, testable, and deterministic foundation for the Windows desktop port of **Medha**.

The primary reason previous agent attempts created a "completely broken app with no features working" is **architectural impedance mismatch**:
1. **The Renderer Crash**: The renderer script (`src/js/app.js`) called Node.js `require()` directly from `<script src="js/app.js"></script>` in the browser, while `nodeIntegration` was disabled in `electron/main.js` (`nodeIntegration: false, contextIsolation: true`). The browser immediately threw an uncaught `ReferenceError: require is not defined`, crashing execution on line 4 before initializing any UI, state, or DOM listeners.
2. **Untested Packaging & Bundling**: There was no module bundler (Vite or esbuild) or ES Module strategy for the renderer, leaving Node CommonJS syntax stranded in a standard HTML document.
3. **No Headless Renderer Verification**: The Node test runner passed backend tests (`node tests/runner.js`), but no automated test ever validated that the renderer script loaded without throwing runtime errors.

Stage 0 eliminates these pitfalls before any feature code is developed.

---

## 🏗️ Core Architecture & Boundaries

```
┌─────────────────────────────────────────────────────────────┐
│                    Windows OS (Win32 / x64)                 │
└──────────────────────────────┬──────────────────────────────┘
                               │
            ┌──────────────────┴──────────────────┐
            ▼                                     ▼
 ┌──────────────────────┐             ┌──────────────────────┐
 │ Electron Main Process│             │  Renderer Process    │
 │ (Node.js Environment)│             │  (Chromium Sandbox)  │
 ├──────────────────────┤             ├──────────────────────┤
 │ • better-sqlite3     │             │ • UI State Machine   │
 │ • SQLite FTS5 Engine │             │ • Virtualized Editor │
 │ • File I/O & Dialogs │             │ • Canvas 2D / WebGL  │
 │ • Ollama / AI Stream │             │ • PointerEvents L3   │
 └──────────┬───────────┘             └──────────┬───────────┘
            │                                    │
            │          IPC ContextBridge         │
            └──────────◄────────────────►────────┘
                        (Preload Bridge)
                  window.medhaAPI / Typed DTOs
```

### Strict Architectural Invariants
1. **Renderer is 100% Web-Standards Compliant**:
   - `nodeIntegration: false` and `contextIsolation: true` are non-negotiable for security and Windows stability.
   - The renderer MUST NEVER call `require()` or Node.js built-ins (`fs`, `path`, `child_process`).
   - All modules in the renderer MUST be bundled (Vite/esbuild) or written as standard ES Modules (`<script type="module">`).
2. **Type-Safe Contract Bridge**:
   - All calls between UI and backend pass through a single, strictly typed bridge (`window.medhaAPI`).
   - Every IPC channel has TypeScript parameter and return types defined in `src/shared/types.ts`.
3. **Windows System Integration**:
   - Frameless titlebar using Windows-native snapping (`WS_THICKFRAME`) or custom drag regions (`-webkit-app-region: drag`).
   - Native Windows Ink / Surface Pen support via W3C `PointerEvent` Level 3 (`e.pressure`, `e.pointerType === 'pen'`).
   - High-DPI and fractional scaling awareness (125%, 150%, 175%, 200%).

---

## 📂 Project Directory Structure

```text
desktop/
├── electron/                   # Electron Main Process & Native Bridges
│   ├── main.ts                 # App lifecycle, window creation, display metrics
│   ├── preload.ts              # contextBridge exposing type-safe window.medhaAPI
│   ├── database/               # Native SQLite layer (better-sqlite3)
│   │   ├── db.ts               # Connection pool, WAL mode, foreign keys
│   │   ├── migrations.ts       # Sequential schema migrations (v1..vN)
│   │   └── seeder.ts           # Demo notebooks, cards, and palaces
│   └── ipc/                    # Modular IPC channel handlers
│       ├── cardsIpc.ts
│       ├── docsIpc.ts
│       ├── palaceIpc.ts
│       └── systemIpc.ts
├── src/                        # Renderer Process (UI, Canvas, State)
│   ├── index.html              # Clean single entry point
│   ├── main.ts                 # Client app bootstrapper
│   ├── shared/                 # Shared TypeScript interfaces & DTOs
│   │   └── types.ts            # Single source of truth for IPC & models
│   ├── styles/                 # Windows dark/light theme, typography, layout
│   └── components/             # Reusable UI views (Editor, Flashcards, Ink, Palace, Graph)
├── tests/                      # Automated Verification Test Suites
│   ├── unit/                   # Algorithm & database unit tests (FSRS, SQLite, Ink)
│   ├── contract/               # IPC contract serialization tests
│   └── smoke/                  # Headless renderer boot & DOM listener smoke tests
├── package.json                # Explicit build, watch, and test scripts
├── tsconfig.json               # Strict TypeScript configuration
└── vite.config.ts              # Lightning-fast renderer bundler
```

---

## 🛠️ Implementation Checklist for Stage 0

- [x] **0.1 Dependency & Toolchain Configuration**:
  - Installed `typescript`, `esbuild`, `@types/node`.
  - Configured `tsconfig.json` with `"strict": true`, `"moduleResolution": "bundler"`.
  - Configured `package.json` scripts (`build:renderer`, `typecheck`, `test:smoke`).
- [x] **0.2 Typed Shared Contract (`src/shared/types.ts`)**:
  - Defined interfaces for all models: `Notebook`, `Document`, `Block`, `Flashcard`, `Deck`, `MemoryPalace`, `Locus`.
  - Defined strict typed contract for `window.medhaAPI`.
- [x] **0.3 Secure Preload & Main Entrypoint**:
  - Preload safely exposes `medhaAPI` (and backwards-compatible `electronAPI`).
  - Added `signalReady` and `getAppPaths` to IPC handlers in `electron/main.js`.
- [x] **0.4 Renderer Bootstrapper with ES Modules & Bundling**:
  - Created `src/js/modules.js` and automated bundle pipeline (`src/js/bundle.js`).
  - Completely eliminated browser-crashing `require()` calls from renderer runtime.
- [x] **0.5 Automated Verification Runner**:
  - Created `tests/smoke.js` launching Electron headlessly and asserting IPC handshake.
  - Verified 100% clean passes for type checking, backend test runner (36/36 suites), and headless Electron smoke test.

---

## 🚦 Automated Stage 0 Verification Gate

To declare Stage 0 complete, run the following automated suite:

```bash
# 1. Type check
npm run typecheck

# 2. Build renderer bundle
npm run build:renderer

# 3. Execute smoke test suite
npm run test:smoke
```

**Success Criteria**:
- `Exit code: 0`
- Zero uncaught exceptions in Chromium console.
- IPC ping/pong verified between renderer and main process.
