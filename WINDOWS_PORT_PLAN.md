# Medha Windows Port — Multi-Stage Implementation Plan

This document defines the strict, phased engineering roadmap to port **Medha** (Cognitive Retention Engine & Spatial PKM) from macOS (Swift/GRDB) to Windows (Electron + TypeScript/Node.js + `better-sqlite3`).

To prevent AI agent context drift and broken builds, **each stage is an isolated vertical slice** with mandatory automated test gates. No phase may begin until the preceding phase’s automated verification suite passes with 0 failures.

---

## 🏛️ Guiding Rules for Agent Execution

1. **Test-First Verification Gate**: Every stage has automated CLI verification tests (`npm test` / Node test runner). A stage is NOT finished until tests execute and pass in the terminal.
2. **Explicit Contracts Over Stubs**: Never introduce dummy UI mockups without the backing database schema and IPC handlers in place.
3. **No Monolithic Leaps**: Work strictly on the current stage. Do not jump ahead to "wire everything together".
4. **Platform Parity**: Windows-specific features (Windows Ink / PointerEvents Level 3, Win32 paths, Direct3D canvas acceleration, high-DPI scaling) must be respected.

---

## 📋 Comprehensive 12-Stage Phased Roadmap

```
Stage 0: Architecture & Toolchain Scaffold
   │
   ▼
Stage 1: Core SQLite Schema, FTS5 & Database Manager
   │
   ▼
Stage 2: FSRS-4.5 Spaced Repetition Mathematical Engine
   │
   ▼
Stage 3: Secure Electron Main & Type-Safe IPC Bridge
   │
   ▼
Stage 4: Flashcards & Study Review Flow (UI Vertical Slice)
   │
   ▼
Stage 5: Block PKM Engine & Bi-Directional WikiLinks
   │
   ▼
Stage 6: Hierarchical Block Editor UI & FTS5 Search Command Bar
   │
   ▼
Stage 7: Vector Ink Engine (Windows Ink / Stylus & Catmull-Rom)
   │
   ▼
Stage 8: 2D Spatial Memory Palace & Walk Mode
   │
   ▼
Stage 9: Force-Directed Knowledge Graph (Alpha Cooling Simulation)
   │
   ▼
Stage 10: Local AI Services (Ollama / Socratic Tutor / AutoNote Pipeline)
   │
   ▼
Stage 11: Import/Export (Anki .apkg, Markdown, SVG) & Polish
```

---

### Stage 0: Architecture, Clean-Slate Workspace & Toolchain
- **Objective**: Establish a clean repository structure, dependency locks, and automated test runner.
- **Scope**:
  - Set up a clean `desktop/` directory with modern TypeScript/Node.js tooling.
  - Install core runtime dependencies: `better-sqlite3`, `electron`, `dotenv`.
  - Install build & testing tools: `typescript`, `esbuild` / `vite` (or clean bundler), `vitest` / Node native test runner.
  - Configure `tsconfig.json` with strict mode enabled (`"strict": true`).
- **Deliverables**:
  - `package.json` with clear scripts: `build`, `test`, `start`.
  - `npm test` runs and passes a basic smoke test.
- **Verification Gate**:
  - `npm run test` exits code `0`.
  - Electron launches in headless/mock mode without uncaught exceptions.

---

### Stage 1: Core SQLite Schema, FTS5 & Database Manager ✅ (Completed)
- **Objective**: Port the entire GRDB database architecture from [DatabaseMigrations.swift](file:///Users/visheshmishra/Downloads/medharara/Sources/MedhaKit/Database/DatabaseMigrations.swift) to SQLite with zero UI dependencies.
- **Scope**:
  - Implement `DatabaseManager` using `better-sqlite3`.
  - Port tables:
    - `notebook`, `document`, `block`, `doc_link`
    - `deck`, `flashcard`, `review_log`, `deck_options`
    - `palace`, `palace_scene`, `palace_locus`
    - `ink_document_page`, `ink_stroke`
  - Setup FTS5 virtual table for blocks (`block_fts`) with unicode61 tokenizer and automated sync triggers (`AFTER INSERT`, `AFTER UPDATE`, `AFTER DELETE`).
  - Seed initial mock data mirroring [MockDataSeeder.swift](file:///Users/visheshmishra/Downloads/medharara/Sources/MedhaKit/Database/MockDataSeeder.swift).
- **Deliverables**:
  - `src/main/database/db.ts`
  - `src/main/database/migrations.ts`
  - `src/main/database/seeder.ts`
  - `tests/database.test.ts`
- **Verification Gate**:
  - Automated tests verify table creation, foreign key cascade deletes, FTS5 full-text indexing, and BM25 snippet searches.

---

### Stage 2: FSRS-4.5 Spaced Repetition Mathematical Engine ✅ (Completed)
- **Objective**: Port [FSRSScheduler.swift](file:///Users/visheshmishra/Downloads/medharara/Sources/MedhaKit/Services/FSRSScheduler.swift) with exact parameter parity.
- **Scope**:
  - Implement 17-parameter Free Spaced Repetition Schedule (FSRS 4.5):
    - Calculation of initial Stability $S_0(G)$ and Difficulty $D_0(G)$.
    - Next Stability update for recall ($S'_r$) and forget ($S'_f$).
    - Next Difficulty update ($D'$ with mean reversion).
    - Interval calculation from target retrievability ($R = 0.90$).
  - Ratings: `Again` (1), `Hard` (2), `Good` (3), `Easy` (4).
  - Compute due cards, overdue count, and next interval previews.
- **Deliverables**:
  - `src/main/services/fsrsScheduler.ts`
  - `tests/fsrs.test.ts` (unit tests validating stability calculations against Swift benchmarks).
- **Verification Gate**:
  - 100% test coverage for interval calculations matching the Swift reference values.

---

### Stage 3: Secure Electron Main & Type-Safe IPC Bridge ✅ (Completed)
- **Objective**: Build the communication layer between Node.js backend and browser renderer with strict TypeScript contracts.
- **Scope**:
  - Define unified `IpcChannels` and shared DTO types in `src/shared/types.ts`.
  - Implement `src/main/main.ts` with secure settings (`contextIsolation: true`, `nodeIntegration: false`, `sandbox: true`).
  - Implement `src/preload/preload.ts` using `contextBridge.exposeInMainWorld('api', ...)`.
  - Implement IPC handlers for:
    - Flashcards (`getDueCards`, `submitReview`, `createCard`, `getDecks`)
    - Documents & Search (`getDocuments`, `searchFts`)
    - System (`getAppPaths`, `windowControls`)
- **Deliverables**:
  - `src/shared/types.ts`
  - `src/main/ipc/` handlers
  - `src/preload/preload.ts`
  - `tests/ipc-contract.test.ts` (tests verifying all channels respond without hanging or serialization errors).
- **Verification Gate**:
  - Headless test verifies all IPC channels return valid serializable responses.

---

### Stage 4: Flashcards & Study Review Flow (UI Vertical Slice) ✅ (Completed)
- **Objective**: Deliver a fully interactive, end-to-end working Flashcards system in the renderer.
- **Scope**:
  - Build UI layout matching Medha design:
    - Sidebar navigation (Decks, Study, Documents, Graph, Palace, Settings).
    - Deck overview with Due / New / Learning badge counters.
    - 3D tactile Card Flip stage (`rotateY(180deg)` with smooth perspective).
    - Rating bar with 4 interval chips computed in real-time from FSRS-4.5 (`Again`, `Hard`, `Good`, `Easy`).
  - Wire UI to IPC methods: submitting rating writes to SQLite `review_log` and updates `flashcard` stability/difficulty/due date.
  - Keyboard shortcuts (`Space` to flip, `1`, `2`, `3`, `4` to rate).
- **Deliverables**:
  - `src/renderer/components/flashcards/`
  - `src/renderer/state/flashcardStore.ts`
  - E2E / component test verifying card review updates database state.
- **Verification Gate**:
  - A user can study a deck of cards, flip them, rate them, and verify that card intervals update in SQLite.

---

### Stage 5: Block PKM Engine & Bi-Directional WikiLinks ✅ (Completed)
- **Objective**: Port the block-based hierarchical data model from [BlockStore.swift](file:///Users/visheshmishra/Downloads/medharara/Sources/MedhaKit/Services/BlockStore.swift) and [LinkParser.swift](file:///Users/visheshmishra/Downloads/medharara/Sources/MedhaKit/Services/LinkParser.swift).
- **Scope**:
  - 12 Block types: `doc`, `inkDoc`, `heading1`..`heading3`, `paragraph`, `bulletList`, `taskList`, `codeBlock`, `quote`, `callout`, `blockRef`.
  - Real-time `[[WikiLink]]` extraction from block content.
  - Maintain `doc_link` table: source document $\leftrightarrow$ target document links.
  - Calculate backlinks and unlinked mentions.
  - Block transclusion `((block-id))` resolution.
- **Deliverables**:
  - `src/main/services/blockStore.ts`
  - `src/main/services/linkParser.ts`
  - `tests/blockStore.test.ts`
- **Verification Gate**:
  - Tests verify block CRUD, parent-child indentation trees, automatic `[[Link]]` synchronization in `doc_link`, and backlink lookups.

---

### Stage 6: Hierarchical Block Editor UI & FTS5 Search Command Bar ✅ (Completed)
- **Objective**: Build the native block editor and spotlight search palette.
- **Scope**:
  - Typography: 740px measure, clean line heights, native dark/light frosted theme.
  - Slash command menu (`/` triggers block conversion: heading, list, quote, code, math).
  - Keyboard navigation: Arrow Up/Down across block boundaries, Enter to split, Backspace to merge/downgrade.
  - Global Search Palette (`Ctrl + K` / `Cmd + K`):
    - Real-time FTS5 querying with highlighted match snippets.
    - Jump directly to block or document.
- **Deliverables**:
  - `src/renderer/components/editor/`
  - `src/renderer/components/search/CommandPalette.tsx`
- **Verification Gate**:
  - Typing in the editor auto-saves to SQLite; `Ctrl+K` searches match content instantly via FTS5.

---

### Stage 7: Vector Ink Engine (Windows Ink / Stylus & Catmull-Rom)
- **Objective**: Port [InkGeometry.swift](file:///Users/visheshmishra/Downloads/medharara/Sources/MedhaKit/Services/InkGeometry.swift) to HTML5 Canvas with high-precision pointer events.
- **Scope**:
  - Support W3C PointerEvents Level 3 with dynamic pressure (Surface Pen, Wacom, mouse fallback).
  - Catmull-Rom cubic spline interpolation for ultra-smooth strokes.
  - Dynamic polygon outline generation based on velocity and pressure.
  - Multi-page ink canvas with 4 paper patterns: Blank, Lined (28px), Grid (20px), Dot Matrix (20px).
  - Stroke selection lasso with ray-casting point-in-polygon math.
  - Lossless vector stroke persistence in SQLite (`ink_stroke`, `ink_document_page`).
- **Deliverables**:
  - `src/renderer/components/ink/InkCanvas.tsx`
  - `src/renderer/components/ink/inkGeometry.ts`
  - `tests/inkGeometry.test.ts`
- **Verification Gate**:
  - Automated tests verify Catmull-Rom point generation and polygon bounds calculation.
  - Drawing on canvas records points with pressure and persists to SQLite.

---

### Stage 8: 2D Spatial Memory Palace & Walk Mode
- **Objective**: Port the Method of Loci spatial memory system from [MemoryPalace.swift](file:///Users/visheshmishra/Downloads/medharara/Sources/MedhaKit/Models/MemoryPalace.swift).
- **Scope**:
  - Infinite 2D pannable and zoomable photo stage (smooth matrix transform).
  - Place numbered loci pins with normalized coordinates $(x \in [0, 1], y \in [0, 1])$.
  - Associate each locus pin with a study prompt / flashcard.
  - Pathway rendering: spline or line connecting sequential pins.
  - Cinematic **Walk Mode**:
    - Smooth cubic camera interpolation framing each locus pin sequentially.
    - Frosted glass callout overlay with recall prompt and answer reveal.
    - Active recall rating button integrating directly with FSRS scheduler.
- **Deliverables**:
  - `src/renderer/components/palace/PalaceStage.tsx`
  - `src/renderer/components/palace/WalkMode.tsx`
- **Verification Gate**:
  - Creating a palace, adding 3 loci pins, and running Walk Mode triggers camera transitions and records review events.

---

### Stage 9: Force-Directed Knowledge Graph (Alpha Cooling Simulation)
- **Objective**: Port [ForceSimulation.swift](file:///Users/visheshmishra/Downloads/medharara/Sources/MedhaKit/Services/ForceSimulation.swift) to high-performance Canvas 2D / WebGL.
- **Scope**:
  - Graph physics simulation:
    - Coulomb electrostatic repulsion between all nodes ($F \propto 1/d^2$).
    - Hooke spring attraction along wiki link edges ($F \propto d$).
    - Center gravity pull.
  - **Cooling Alpha Physics (0% CPU at Rest)**: Alpha simulation decays over time ($\alpha < 0.002$), halting rendering loop when settled.
  - Graph filters: Links Only, Hierarchy Tree Only, Blended.
  - Interactive drag-and-drop node pinning, zoom/pan, click-to-navigate.
- **Deliverables**:
  - `src/renderer/components/graph/GraphCanvas.tsx`
  - `src/renderer/components/graph/simulation.ts`
  - `tests/simulation.test.ts`
- **Verification Gate**:
  - Unit test verifies alpha decays to zero; simulation loop stops completely when idle (0% CPU).

---

### Stage 10: Local AI Services (Ollama / Socratic Tutor & AutoNote)
- **Objective**: Port [AISocraticService.swift](file:///Users/visheshmishra/Downloads/medharara/Sources/MedhaKit/Services/AISocraticService.swift) and [AutoNotePipelineService.swift](file:///Users/visheshmishra/Downloads/medharara/Sources/MedhaKit/Services/AutoNotePipelineService.swift).
- **Scope**:
  - Local LLM integration via Ollama HTTP API (`http://127.0.0.1:11434`) and optional cloud API fallback.
  - Streaming token responses directly to UI via IPC events.
  - Socratic Tutor Mode: context-aware probing questions based on active note.
  - AutoNote Pipeline: Turn raw text/paste into structured blocks and flashcard candidates.
- **Deliverables**:
  - `src/main/services/aiService.ts`
  - `src/renderer/components/ai/SocraticPanel.tsx`
- **Verification Gate**:
  - Mocked and live Ollama stream test verifying incremental token streaming and JSON schema parsing.

---

### Stage 11: Import/Export (Anki .apkg, Markdown, SVG) & Final Windows Packaging
- **Objective**: Port [AnkiImporter.swift](file:///Users/visheshmishra/Downloads/medharara/Sources/MedhaKit/Services/AnkiImporter.swift) and package the final Windows executable.
- **Scope**:
  - Anki `.apkg` importer: unzip archive, parse internal SQLite `collection.anki2`, extract media, and convert to Medha flashcards.
  - Export: Markdown with frontmatter, Vector Ink SVG export, JSON backup.
  - Windows packaging using `electron-builder`:
    - Portable executable (`.exe`) and NSIS installer.
    - Application icon, Windows title bar styling (Mica/Acrylic effect where supported).
- **Deliverables**:
  - `src/main/services/ankiImporter.ts`
  - `electron-builder.yml`
  - `tests/ankiImporter.test.ts`
- **Verification Gate**:
  - Automated test successfully parses sample Anki package into database cards.
  - `npm run package` builds a runnable Windows binary without packaging errors.

---

## 🚀 Execution Strategy for Each Stage

When working on any stage:
1. **Declare the active stage** (e.g., "Starting Stage 1").
2. **Implement code & unit tests**.
3. **Execute test command** and show proof of green tests.
4. **Update progress checkbox** in this plan.
5. Stop and review before moving to the next stage.
