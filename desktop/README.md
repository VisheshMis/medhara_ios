# Medha for Windows — Cognitive Retention Engine & Spatial PKM

An offline-first, native Windows desktop port of **Medha**, preserving the macOS visual aesthetic (frosted glass vibrancy, 740px typographic measure, 3D card flips) with **100% functionality parity**.

---

## 🌟 Key Subsystems & Feature Parity

1. **Hierarchical Block PKM & Full-Text Search (FTS5)**
   - 12 granular block types (`doc`, `inkDoc`, `heading1`–`heading3`, `paragraph`, `bulletList`, `taskList`, `codeBlock`, `quote`, `callout`, `blockRef`).
   - SQLite FTS5 index with `unicode61` tokenizer, real-time synchronization triggers, and BM25 relevance snippets.
   - Bi-directional `[[WikiLinks]]` with `doc_link` database index and block transclusion `((b-uuid))`.
   - Caret boundary navigation (`↑`/`↓`), smart backspace downgrades, and slash command menu (`/`).
   - One-click export to Markdown (`.md`), JSON, and SVG.

2. **Vector Ink Notes (Handwritten)**
   - Continuous multi-page canvas with independent pages.
   - W3C PointerEvents Level 3 with dynamic stylus pressure support for **Windows Ink, Surface Pen, and Wacom**.
   - Catmull-Rom cubic spline interpolation and variable-width polygon outline generation.
   - 4 paper background templates: Blank, Lined (28px rule), Grid (20px graph), Dot Matrix (20px grid).
   - Lasso tool with ray-casting point-in-polygon math to select and translate strokes.
   - Lossless JSON storage in SQLite table `ink_document_page` and SVG vector export.

3. **2D Spatial Memory Palace & Walk Mode (Method of Loci)**
   - Infinite 2D pannable and zoomable photo stage.
   - Place numbered loci pins at normalized coordinates on multi-photo architectural scenes.
   - Sequential journey pathway lines connecting pins.
   - Cinematic Walk Mode: camera auto-framing with cubic spring physics, frosted glass callouts (`backdrop-filter: blur(16px)`), pulsing beacon rings, and active recall testing at each locus.

4. **GPU / Canvas Force-Directed Knowledge Graph**
   - Coulomb electrostatic repulsion, Hooke springs, center gravity, and velocity damping.
   - **Cooling Alpha Physics (0% CPU at Rest)**: Alpha decays to rest (`alpha < 0.002`), consuming **0% CPU / GPU** when idle.
   - 3 layer presets: `Links Only` (default), `Tree Only` (`CONTAINS` dashed dimmer purple), `Blended`.
   - Degree-scaled vertex sizing and dynamic Level-of-Detail (LOD) label hiding at far zoom.

5. **Spaced Repetition Engine (FSRS-4.5) & Anki Importer**
   - Exact 17-parameter FSRS 4.5 mathematical formulation ($S$, $D$, $R$, stabilities, difficulties, review dates).
   - 3D tactile perspective card flip stage (`transform: rotateY(180deg)` with perspective).
   - Live interval preview chips (`Again 10m`, `Hard 1.2d`, `Good 4.8d`, `Easy 12.5d`).
   - Single-key ergonomics: `Space` to flip, `1`, `2`, `3`, `4` to rate.
   - Native Anki Importer (`.apkg`): extracts packages, parses legacy SQLite `.anki2` and decompresses modern `.anki21` / `.anki21b` Zstandard archives, strips HTML, and maps cloze deletions (`{{c1::answer}}`).

6. **2-Step Auto-Note Pipeline & 8+ Academic Open APIs**
   - Step 1: P1 Grounding -> P2 Skeleton Planner -> Instant SQLite disk commit of all skeletal documents.
   - Step 2: In-Node On-Demand Verified Content Fill: P4 Router -> P5 Query Builder -> P6 Evidence Validator -> P7 Note Writer -> P9 QA Gate.
   - Deep Master Plan Curriculum Generator with Wikipedia section outlines.
   - Academic APIs: Wikipedia, OpenAlex, CrossRef, PubMed, Europe PMC, arXiv, Open Library, Wiktionary, Free Dictionary.
   - Dual-Mode AI with per-provider key isolation (Groq, Gemini, OpenAI, and Local Ollama / LM Studio) with DeepSeek-R1 `<think>` sanitization.

7. **Focus Engine & Desktop Shell**
   - Pomodoro Focus timer pill in titlebar (10m Focus -> 2s Beep & Pause -> 30s Micro-Break -> 10s Cycle Reset).
   - Frameless window with macOS traffic lights (🔴 🟡 🟢) or native Windows caption controls.
   - Windows keyboard mappings (`Ctrl+N`, `Ctrl+Shift+N`, `Ctrl+K`, `Ctrl+I`, `Ctrl+G`, `Ctrl+E`).

---

## 🚀 Building & Running

### Prerequisites
- Node.js 18+ (tested on Node v26)
- npm

### 1. Run Automated Test Suite (All 36 Suites)
```bash
cd desktop
npm test
```

### 2. Launch Desktop App Locally
```bash
npm start
```

### 3. Package Windows Installer & Portable Executable
```bash
npm run dist:win
```
Produces:
- `dist/Medha Setup 1.0.0.exe` (NSIS Installer)
- `dist/Medha 1.0.0.exe` (Portable Executable)
