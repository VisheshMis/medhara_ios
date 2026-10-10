# Medha macOS: Complete Feature Specification & Reference

> **Comprehensive feature inventory extracted directly from the native macOS implementation (`Sources/MedhaKit/`, `Sources/MedhaApp/`, and verified by 48/48 test suites in `MedhaTestRunner`).**

---

## 📑 Table of Contents

1. [Architectural Overview & Design System](#1-architectural-overview--design-system)
2. [Hierarchical Document & Block PKM Engine](#2-hierarchical-document--block-pkm-engine)
3. [Vector Ink Notes, Multi-Mode Canvas & PDF Engine](#3-vector-ink-notes-multi-mode-canvas--pdf-engine)
4. [Spaced Repetition Flashcards (FSRS-4.5) & Image Occlusion](#4-spaced-repetition-flashcards-fsrs-45--image-occlusion)
5. [Anki Ecosystem Compatibility (.apkg Importer)](#5-anki-ecosystem-compatibility-apkg-importer)
6. [2D Spatial Memory Palace & Walk Mode (Method of Loci)](#6-2d-spatial-memory-palace--walk-mode-method-of-loci)
7. [GPU-Accelerated Knowledge Graph (Global & Local)](#7-gpu-accelerated-knowledge-graph-global--local)
8. [2-Step Auto-Note Formation Pipeline (P1–P11)](#8-2-step-auto-note-formation-pipeline-p1p11)
9. [Deep Master Plan Curriculum Generator](#9-deep-master-plan-curriculum-generator)
10. [Academic Open APIs & Hybrid Grounding Catalog](#10-academic-open-apis--hybrid-grounding-catalog)
11. [Dual-Mode AI Engine (Cloud & Local Offline Ollama)](#11-dual-mode-ai-engine-cloud--local-offline-ollama)
12. [Focus Timer & Productivity Lifecycle](#12-focus-timer--productivity-lifecycle)
13. [Inspector, Outlines, Backlinks & Search](#13-inspector-outlines-backlinks--search)
14. [Command Palette & Keyboard Navigation](#14-command-palette--keyboard-navigation)
15. [Data Persistence, Schema Migrations & Storage](#15-data-persistence-schema-migrations--storage)
16. [Notion-Grade Relational PKM & Database Blocks (Tiers 1 & 2)](#16-notion-grade-relational-pkm--database-blocks-tiers-1--2)
17. [Unified Infinite Canvas, Flowchart Shapes & Multi-Media Pipeline](#17-unified-infinite-canvas-flowchart-shapes--multi-media-pipeline)

---

## 1. Architectural Overview & Design System

### 1.1 Visual Language & macOS Vibrancy
- **Frosted Glass Vibrancy (`NSVisualEffectView`)**: Uses macOS `.sidebar`, `.headerView`, and `.hudWindow` blended materials with dynamic dark/light mode switching.
- **Three-Column Flexible Navigation**:
  1. **Primary Sidebar**: Collapsible navigation with Notebooks, Decks, Memory Palaces, Global Graph, and Search.
  2. **Document Outline & Tree Column**: Multi-level hierarchical folder and sub-note navigator with real-time expand/collapse states.
  3. **Canvas / Editor Work Area**: Contextual workspace adapting to Block Notes, Ink Notes, 3D Flashcards, 2D Palaces, or Knowledge Graph.
  4. **Right Inspector Panel (Collapsible)**: Document metadata, Backlinks, Document Outline, and Local Mini-Graph.
- **Typographic Measure**:
  - Main text column constrained to an optimal **740px** reading measure for maximum cognitive retention and minimal eye fatigue.
  - Centered horizontal alignment with smooth margins that dynamically resize on wider monitors.
- **Micro-Interactions**:
  - 3D CSS / AppKit matrix perspective flip animations on flashcard reveal.
  - Smooth spring damping physics for Memory Palace camera transitions.
  - Cooling alpha dampening for knowledge graph physics.

---

## 2. Hierarchical Document & Block PKM Engine

### 2.1 Infinite Nested Document Hierarchy
- **Sub-Notes & Trees**: Every document can serve as a parent container for infinite sub-notes (`parentDocId`).
- **Auto-Expansion**: Creating a child document automatically expands parent nodes in the navigation tree.
- **Breadcrumb Ancestry**: Top-of-page breadcrumb navigation (`Root > Folder > Sub-note > Deep Leaf`) with one-click upward navigation.
- **Tree Filtering**: Real-time substring filter across all nested titles while retaining tree hierarchy.
- **Recursive Cascade Deletion**: Deleting a parent document cascades safely to all child documents, blocks, and associated references.

### 2.2 Granular Block Architecture
Every document is composed of individually addressable blocks with unique UUIDs (`b-uuid`):
- **Supported Block Types**:
  - `paragraph`: Standard body prose with inline markdown support.
  - `heading1`: Section header (`# ` prefix shortcut).
  - `heading2`: Subsection header (`## ` prefix shortcut).
  - `heading3`: Sub-subsection header (`### ` prefix shortcut).
  - `bulletList`: Unordered bullet item (`- ` or `* ` prefix shortcut) with bullet indentation.
  - `numberedList`: Ordered numbered item (`1. ` prefix shortcut).
  - `taskList`: Checkbox todo item (`[] ` prefix shortcut) with interactive completion toggle (`isCompleted`).
  - `quote`: Blockquote styling with colored left accent line (`> ` prefix shortcut).
  - `code`: Monospace syntax block with copy button and language metadata.
  - `callout`: Highlighted container box with customizable icon/emoji and background tint.
  - `divider`: Horizontal separator rule (`---` shortcut).
  - `blockRef`: Live transclusion block referencing any external block across the entire database.

### 2.3 Inline Parsing & Hypertext Linkage
- **Slash Commands (`/`)**: Floating popup menu triggered by typing `/` on an empty line, allowing quick conversion to any block type.
- **WikiLinks (`[[Document Title]]`)**: Real-time cross-document hyperlinking with autocomplete picker.
- **Block Transclusion (`((block-id))` / `blockRef`)**: Dynamic mirror blocks that render and reflect live target block content; clicking jumps to the source.
- **Markdown Round-Trip Import / Export**:
  - Export current note to clean, portable standard Markdown.
  - Import external Markdown files into structured block hierarchies without data loss.

---

## 3. Vector Ink Notes, Multi-Mode Canvas & PDF Engine

### 3.1 Three Flexible Canvas Modes (`canvasMode` in Block / Document Settings)
Users can seamlessly switch between three distinct canvas layouts per note:
1. **A4 Discrete Pages (`a4Pages`)**: Fixed paginated sheets with realistic page break dividers, page numbers, and discrete page bounds. Ideal for structured coursework, printing, and standardized lecture notes.
2. **Infinite Vertical Roll (`infiniteVertical`)**: Continuous downward-flowing paper roll with dynamic height auto-expansion as strokes are added. Maintains standard horizontal reading width with unbounded downward continuity.
3. **Vast 2D Infinite Space (`infinite2D`)**: Boundless 2-dimensional spatial whiteboard allowing pan and zoom in all directions $(X, Y)$ without artificial boundaries. Perfect for freeform mind-mapping, visual brainstorming, concept clustering, and expansive architecture diagrams.

### 3.2 High-Velocity Spatial Navigation & Ultra-Wide Zoom
- **Deep Zoom Spectrum**: Smooth zooming from **`0.02x` (2% panoramic macro view)** up to **`20.0x` (2000% microscopic precision)**.
- **Quick Preset Dropdown**: Integrated zoom picker toolbar featuring presets: `5%`, `10%`, `25%`, `50%`, `75%`, `100%`, `150%`, `200%`, `300%`, `500%`, `1000%`, plus **Fit Width** and **Fit Content** automations.
- **Hardware-Accelerated Trackpad & Mouse Interaction**: Pinch-to-zoom (`magnifyWithEvent`), Option-scroll wheel zoom, and two-finger pan gesture tracking with spring-damped responsiveness.
- **Fullscreen Focus Mode**: Clean distraction-free view hiding sidebars, status bars, and inspectors while retaining floating pen, highlighter, eraser, and color toolbars.

### 3.3 Drag-and-Drop Integrated Note Cards on Canvas (`CanvasNoteCard`)
- **Native Document Tree Drag & Drop**:
  - Any text note or document in the left `DocumentTreeView` can be dragged directly onto the drawing canvas (`infinite2D` or `infiniteVertical`).
  - Drop location coordinates are dynamically translated through pan offset and zoom scale into exact canvas-space coordinates (`canvasPointFrom(viewPoint:)`).
- **Interactive Embedded Note Cards**:
  - Automatically instantiates and displays a movable card widget (default size 320 × 180 pt) directly on the drawing plane.
  - Features an elegant frosted drop shadow, document icon, title, snippet preview of note content, and close/dismiss button (`✕`).
  - **Repositioning**: Click and drag the card header to move it anywhere across the canvas.
  - **Direct Note Jump**: Double-click the card header to navigate directly to that full document in the editor.
  - **Layered Drawing**: Vector ink strokes, highlighters, and annotations can be drawn directly over or around note cards.
  - **SQLite Persistence**: Stored in `canvas_note_card` table via GRDB migration `v14_canvas_note_cards`, ensuring card coordinates, dimensions, and removals survive application restarts.

### 3.4 Continuous Multi-Page Vector Canvas & Styling
- **Stylus & Pressure Sensitivity**:
  - Apple Pencil (via Sidecar/iPad) and stylus pointer event support with dynamic stroke width modulation based on pressure.
  - **Catmull-Rom Cubic Spline Interpolation**: Real-time smoothing turning raw pointer coordinates into fluid, organic ink paths.
- **Pen & Tool Suite**:
  - **Pen**: Solid vector strokes with pressure variance.
  - **Highlighter**: Semi-transparent vector strokes with blend mode preservation.
  - **Eraser**: Stroke-level vector eraser and point-erase detection.
  - **Lasso Tool**: Arbitrary vector polygon lasso with ray-casting point-in-polygon containment detection to select, translate, and re-color groups of strokes.
- **4 Paper Template Styles**:
  1. `blank`: Pure clean white/dark canvas.
  2. `ruled`: Lined horizontal notebook paper with adjustable rule height.
  3. `grid`: Math/graph paper grid.
  4. `dotGrid`: Subtle bullet journaling dot matrix.

### 3.5 PDF Import, Trimming & Embedding
- **Custom Page Range Trimming**: Select specific page intervals (e.g., `1-5`, `12`, `18-24`) to eliminate unnecessary textbook fluff.
- **Embedded PDF Rendering**: High-DPI background page rendering with vector ink layers persisted directly on top.
- **Full Vector Export**:
  - Export ink documents as layered, multi-page vector **PDFs**.
  - High-resolution **PNG** raster export with optional transparent backgrounds.

---

## 4. Spaced Repetition Flashcards (FSRS-4.5) & Image Occlusion

### 4.1 State-of-the-Art FSRS-4.5 Algorithm
- **17-Weight Mathematical Formula**: Replaces legacy SM-2 (Anki default) with Free Spaced Repetition Scheduler 4.5.
- **Memory Metric Tracking**:
  - **Stability ($S$)**: Time required for memory retention to drop from 100% to 90%.
  - **Difficulty ($D$)**: Inherent complexity of the card, scaled from 1.0 to 10.0.
  - **Retrievability ($R$)**: Probability of successfully recalling the card at current elapsed time.
- **Rating Choices**: `Again` (1), `Hard` (2), `Good` (3), `Easy` (4) with real-time interval prediction chips shown on the review buttons.

### 4.2 3D Card Review Stage
- **Hardware-Accelerated 3D Flip**: Flip between card front and back using 3D perspective transform animations.
- **Keyboard Shortcuts**: `Space` to flip, `1`-`4` for rapid rating input.
- **Deck Customization & Presets**:
  - Per-deck configuration for desired retention rate (default 90%).
  - Maximum review intervals, learning steps, and daily new card limits.
  - Deck grouping by parent folder, notebook, or standalone custom tags.

### 4.3 Image Occlusion Flashcards
- **Visual Anatomy / Diagram Testing**: Import high-resolution diagrams and photos.
- **Mask Tooling**: Draw rectangular or polygon occlusions over labels, definitions, or structures.
- **Hide All / Reveal One Mode**: Reviewing an occlusion card masks all labels while highlighting the active question label in accent color.
- **Persistent Asset Storage**: Automatic image optimization and disk asset caching in application support.

---

## 5. Anki Ecosystem Compatibility (.apkg Importer)

- **Direct `.apkg` Package Decompression**: Native archive extraction without third-party tool dependencies.
- **Database Support**:
  - Legacy SQLite `.anki2` database schema support.
  - Modern `.anki21` database schema support featuring native **Zstandard (`zstd`) decompression**.
- **Cloze Deletion Parsing**: Automatically converts Anki `{{c1::answer}}` cloze syntax into interactive Medha flashcards.
- **HTML Sanitization**: Cleans Anki HTML formatting, stripping bloated CSS while preserving bold, italics, code snippets, and embedded media references.

---

## 6. 2D Spatial Memory Palace & Walk Mode (Method of Loci)

### 6.1 Infinite 2D Spatial Canvas
- **Multi-Photo Architectural Foundations**: Assign background photos of real or conceptual spaces (e.g., salons, libraries, courtyards, campus halls).
- **Vast Coordinate Space**: Pan and zoom across a high-resolution 2D coordinate plane.
- **Loci Pin Anchoring**: Place numbered locus pins (`Locus 1`, `Locus 2`, `...`) directly onto architectural features in the image.
- **Sequential Pathway Lines**: Visual bezier path connecting loci in deliberate memorization sequence.

### 6.2 Flashcard & Note Transclusion on Loci
- Every locus pin is linked to a specific Flashcard, Concept, or Block Note.
- Hovering or clicking reveals the attached knowledge item in a popover or inline modal.

### 6.3 First-Person Walk Mode
- **Cinematic Spring Camera Navigation**: Step through the palace locus-by-locus using `Arrow Keys` or `Next/Prev` buttons.
- Camera smoothly pans and zooms directly to the active locus with spring-damped easing curves.
- Ideal for rehearsal and mental recall before examinations.

---

## 7. GPU-Accelerated Knowledge Graph (Global & Local)

### 7.1 Real-Time Force Simulation
- **Barnes-Hut / Coulomb Force Model**: Repulsion between all nodes with spring tension along connecting links.
- **Cooling Alpha Physics**:
  - Alpha parameter cools from `1.0` down to `0.0` over ~300 iterations.
  - **0% CPU at rest**: Once equilibrium is achieved, the animation loop completely shuts off to conserve battery and CPU resources.
- **Degree-Based Node Scaling**: Node diameter dynamically scales based on link connectivity (hub documents appear larger).

### 7.2 Three Filtering Presets
1. **Links Only**: Displays solely explicit `[[WikiLinks]]` created by the user.
2. **Tree Only**: Visualizes the hierarchical parent-child document directory tree.
3. **Blended (Default)**: Combines structural hierarchy and semantic cross-references with distinct link color coding.

### 7.3 Global vs. Local Mini-Graph
- **Global Graph View**: Full-screen interactive view of your entire second brain.
- **Local Inspector Graph**: 2-hop neighborhood graph embedded in the right inspector, updating in real-time as you switch active documents.

---

## 8. 2-Step Auto-Note Formation Pipeline (P1–P11)

An automated cognitive pipeline that transforms unstructured thoughts or raw source materials into polished master notes:

1. **Phase 1: Raw Concept Extraction**: Scans user input, isolates core propositions, removes conversational fluff.
2. **Phase 2: Academic Verification**: Queries open academic APIs for empirical backing, definitions, and citations.
3. **Phase 3: Hierarchical Outlining**: Builds logical H1, H2, and H3 structural scaffolding.
4. **Phase 4: Block Assembly**: Maps sections into granular Medha blocks (`paragraph`, `callout`, `code`, `bulletList`).
5. **Phase 5: Key Takeaways & Callouts**: Injects summary callout blocks with critical memory hooks.
6. **Phase 6: Automatic Flashcard Synthesis**: Derives 3–5 high-yield FSRS flashcards from key definitions.
7. **Phase 7: Loci Anchor Recommendations**: Identifies vivid spatial imagery suitable for Memory Palace loci placement.
8. **Phase 8: WikiLink Auto-Discovery**: Cross-references existing documents in your database to insert `[[WikiLinks]]`.
9. **Phase 9: Socratic Self-Test Questions**: Generates inquiry questions placed at the foot of the document.
10. **Phase 10: FTS5 Indexing**: Flushes all synthesized content into the SQLite FTS5 search index.
11. **Phase 11: Graph Node Insertion**: Links the new document into the global knowledge graph with weighted edges.

---

## 9. Deep Master Plan Curriculum Generator

- **Automated Multi-Week Study Syllabi**: Provide a high-level goal (e.g., *"Master Advanced Immunology in 6 Weeks"*), and Medha generates a complete structured curriculum.
- **Sub-Note Hierarchy Generation**: Creates a master parent document with nested sub-notes for each week, module, and day.
- **Grounded Learning Objectives**: Each sub-note is prepopulated with reading objectives, open API references, and pre-generated review flashcard decks.

---

## 10. Academic Open APIs & Hybrid Grounding Catalog

Medha connects to **8+ major academic repositories without requiring user API keys**:

| Repository / API | Subject Domain | Data Provided |
| :--- | :--- | :--- |
| **OpenAlex** | Universal Science & Humanities | 250M+ scholarly works, citation counts, concept graphs |
| **PubMed (NCBI E-Utilities)** | Medicine & Life Sciences | Peer-reviewed biomedical abstracts, PMIDs, clinical trials |
| **arXiv** | Physics, Mathematics, CS, AI | Pre-print manuscripts, TeX equations, primary author papers |
| **Europe PMC** | Molecular Biology & Biotech | Open-access biomedical articles and European grant data |
| **Semantic Scholar** | Computer Science & Neurobiology | AI-derived influence citations, TLDR summaries |
| **Crossref** | Interdisciplinary Publishing | Official DOI registry metadata, journal publication dates |
| **Wikidata / Wikipedia API** | General Knowledge & History | Structured ontological entities, foundational summaries |
| **ChEMBL / PubChem** | Chemistry & Pharmacology | Bioactive molecules, compound properties, drug mechanisms |

- **Fallback & Caching**: All external academic lookups are cached locally in SQLite to guarantee offline availability once retrieved.

---

## 11. Dual-Mode AI Engine (Cloud & Local Offline Ollama)

### 11.1 Zero-Cloud 100% Offline Mode (Ollama)
- Direct HTTP integration with local Ollama instances (`http://127.0.0.1:11434`).
- Optimized for lightweight small language models requiring **<4 GB RAM** (e.g., `llama3.2:1b`, `qwen2.5:1.5b`, `phi3:mini`).
- Guarantees zero private note data ever leaves your computer.

### 11.2 Multi-Cloud Provider Support
- Supported providers: **Groq**, **Google Gemini**, **OpenAI**.
- **Per-Provider Isolated API Key Management**: Store separate API keys securely; switch providers instantly without re-entry.
- **DeepSeek `<think>` Sanitization**: Automatically detects, extracts, or strips `<think>...</think>` internal reasoning tags from modern reasoning models to keep notes clean.
- **Socratic Tutor Dialog**: Interactive sidecar chat allowing students to be interrogated on note concepts with constructive feedback.

---

## 12. Focus Timer & Productivity Lifecycle

### 12.1 Apple Watch-Inspired Pomodoro Focus Clock
- **Top-Left Status Bar & Sidebar Widget**: Integrated focus clock visible throughout all editor and canvas modes (`TopLeftTimerView`).
- **Circular Progress Ring**: Fluid circular countdown arc rendered with `MedhaTheme` linear gradient with live pulse animations while running.
- **Configurable Duration Presets & Custom Options**:
  - `Study Duration`:
    - `10m`: Rapid sprint / Micro-focus (default).
    - `15m`: Quick revision.
    - `25m`: Standard Pomodoro technique.
    - `45m`: Deep work session.
    - `60m`: Lecture / Exam simulation block.
  - `Relax / Break Duration`:
    - `30s`: Micro-Break eye rest.
    - `5m`: Standard Pomodoro rest.
    - `10m`: Extended rest interval.
    - `15m`: Long rejuvenation break.
  - `Custom Study & Relax Options`: Steppers and direct configuration within the Right Sidecar Panel (`FocusStatsPanel`) allowing arbitrary study and break minutes/seconds.
- **Cycle Flow & Audio Cues**:
  1. `Focus Session` (active study tracking with custom duration).
  2. `Audio Beep & Pause` (2s double-tone chime, muted via button).
  3. `Micro-Break / Rest` (custom relax time).
  4. `Cycle Reset` (10s transition to next interval).

### 12.2 Persistent Study Statistics Engine (`FocusStatsService` & GRDB `focus_session`)
- **Granular Session Logging**: Every focused second is automatically tracked and persisted in SQLite (`v12_focus_sessions` migration) with foreign document linkage (`docId`), completion status, and timestamps.
- **Real-Time Aggregations**:
  - **Today Total**: Accumulated focused minutes vs. user-configured daily study goal (30m, 45m, 60m, 90m, 120m, 180m).
  - **This Week Total**: 7-day breakdown (Mon–Sun) with interactive bar distribution chart, daily average focus time, and today's highlighted bar.
  - **This Month Total**: Cumulative monthly study hours, active study days count, and daily average per active day.

### 12.3 Medha Activity Rings & Right Sidecar Panel (`FocusStatsPanel` & `⌘⇧T`)
- **Concentric Activity Rings View (`MedhaActivityRingsView`)**:
  - **Outer Ring**: Daily Study Goal — *Royal Violet / Indigo Gradient* (`#7C6CFF` → `#4C9AFF`).
  - **Middle Ring**: Weekly Focus Progress — *Vibrant Notes Blue* (`#3B82F6`).
  - **Inner Ring**: Consistency & Session Count — *Emerald Retention Green* (`#10B981`).
- **Integrated Right Sidecar Panel**: Opens seamlessly docked on the right side of the main workspace rather than as an intrusive modal, fully coordinating with the AI Assistant and Inspector panels.
- **Inline Custom Steppers**: Instant customization of Study Time and Relax Time with live feedback and presets.
- **Recent Study Session Logs**: Real-time chronological audit trail of completed and active sessions with timestamps and durations.


---

## 13. Inspector, Outlines, Backlinks & Search

### 13.1 Inspector Tabs
- **Document Info**: Word count, character count, block count, creation date, and last modified timestamp.
- **Document Outline**: Live Table of Contents generated from H1, H2, and H3 blocks; clicking any entry scrolls the editor directly to that block.
- **Backlinks Panel**: Full list of external documents that reference the current note via `[[WikiLinks]]` or `((blockRef))` transclusions.
- **Local Graph**: Interactive 2-hop visual graph of the current note and its immediate neighbors.

### 13.2 SQLite FTS5 Full-Text Search
- Tokenized SQLite **FTS5** virtual table with **BM25** relevance ranking.
- Sub-millisecond search across tens of thousands of blocks.
- Real-time highlight matches showing snippet context around matching keywords.

---

## 14. Command Palette & Keyboard Navigation

- **Global Command Palette (`⌘K` / `Ctrl+K`)**:
  - Search any document, flashcard deck, or memory palace by title.
  - Trigger global actions: Create Note, Start Review, Open Graph, Toggle Timer.
- **Editor Hotkeys**:
  - `Enter`: Split/create next block.
  - `Backspace` on empty block: Remove block and focus previous.
  - `/`: Open Slash block type picker menu.
  - `⌘B` / `⌘I` / `⌘K`: Inline Bold, Italic, Link formatting.
- **Flashcard Review Hotkeys**:
  - `Space`: Reveal card answer.
  - `1`: Rate *Again*.
  - `2`: Rate *Hard*.
  - `3`: Rate *Good*.
  - `4`: Rate *Easy*.

---

## 15. Data Persistence, Schema Migrations & Storage

### 15.1 SQLite & GRDB Storage Architecture
- Powered by native SQLite via **GRDB** (macOS) and **better-sqlite3 / sql.js** (Windows).
- **14 Schema Migrations (v1–v14)**:
  - `v1`: Base Notebooks, Documents, Blocks, and FTS5 index.
  - `v2`: Document Hierarchy (`parentDocId`, `isExpanded`, `sortOrder`).
  - `v3`: FSRS-4.5 Flashcards and Decks schema.
  - `v4`: Memory Palaces, Loci coordinates, and anchor references.
  - `v5`: Cross-document links and graph edge weightings.
  - `v6`: Deck options, learning steps, and retention parameters.
  - `v7`: Focus sessions and daily study tracking.
  - `v8`: Vector Ink strokes, points, pages, and template settings.
  - `v9`: Ink page PDF import and trimmed page attachments.
  - `v10`: Image occlusion flashcards, masks, and occlusion review modes.
  - `v11`: Ink canvas modes (`a4Pages`, `infiniteVertical`, `infinite2D`).
  - `v12`: Pomodoro focus sessions and study analytics logging.
  - `v13`: Tier 1 Notion primitives (collapsed toggles, icons, color tints, verification badges, egress locking).
  - `v14`: 2D Canvas embedded note cards (`canvas_note_card` coordinates, dimensions, and document linkage).

### 15.2 Local Asset Storage
- Dedicated application directory for binary assets:
  - Memory Palace high-res photographic backdrops (`PalaceAssetStorage`).
  - Image occlusion diagrams and cropped masks (`OcclusionAssetStorage`).
  - Vector ink page thumbnails and PDF document attachments.
- Zero cloud database lock-in: entire user library resides in a single, portable local SQLite file.

---

## 16. Upcoming Notion-Grade Relational PKM & Database Blocks (Tiers 1 & 2 Blueprint)

> **Architectural Addition**: Native macOS and Windows porting specification for high-ROI, offline-first Notion-equivalent features (Tiers 1 & 2) evaluated for zero crash risks, sub-30MB RAM footprint, and instant 60–120 FPS reactivity.

### 16.1 Advanced Block Primitives & Document UI Customization (Tier 1 & 2)
- **`toggle` (Collapsible Disclosure Block)**:
  - Parent block with collapsible chevron disclosure hiding nested child blocks.
  - Stored via `parentId` and `isCollapsed: Bool?` on `Block`.
  - Windows port parity: React state toggle + CSS max-height transition.
- **Collapsible Headings (`heading1`, `heading2`, `heading3`)**:
  - Headings feature an optional disclosure arrow folding all subsequent content until the next sibling/higher heading.
- **Lightweight Tabular Grid Block (`table`)**:
  - Lightweight non-database table container with customizable row and column count.
  - Payload stored as 2D JSON matrix `[[String]]` in `Block.content`.
  - Full keyboard navigation: `Tab` advances to next cell, `Enter` creates a new row.
- **Syntax-Highlighted Code Editor (`code`)**:
  - macOS: Native Tree-sitter / Splash syntax highlighting without WebKit overhead.
  - Windows port: Prism.js / CodeMirror 6 with local themes.
- **Pinned Property Bar**:
  - Horizontal chip strip rendering immediately beneath the document title pinning up to 15 key metadata properties.
  - Horizontal scroll with smooth gradient edge fade.
- **Tabbed Record Layout**:
  - Segmented tab picker partitioning document records into distinct sections (`Overview`, `Specifications`, `Tasks`, `Notes`).
  - Keeps complex documents organized without excessive vertical scrolling.
- **Page Verification**:
  - 30, 90, or 365-day certification intervals with authoritative verification badges.
  - Integrated into SQLite FTS5 search ranking as a relevance multiplier.
- **Document Egress Controls**:
  - One-click read-only toggle preventing accidental modifications or exports.

### 16.2 Schema-Governed Relational Databases & Typed Properties (Tiers 1 & 2)
Databases represent structured collections of records where each record is also a first-class document page.
- **Supported Property Types**:
  - **Scalar**: `title`, `rich_text`, `number` (with currency/percent formats), `checkbox`, `date` (ISO 8601 with optional time & range), `url`, `email`, `phone_number`.
  - **Categorical**: `select` (single colored badge), `multi_select` (multi-tag array), `status` (lifecycle states: To-do, In Progress, Complete).
  - **Identifiers & System**: `unique_id` (auto-increment issue ID, e.g., `MED-101`), `created_time`, `created_by`, `last_edited_time`, `last_edited_by`, `people`.
  - **Relational**:
    - `relation`: Directed foreign key pointers linking records between databases via a dedicated SQLite junction table (`record_relations`).
    - `rollup`: Real-time computed aggregations (`SUM`, `AVG`, `COUNT`, `PERCENT`, `MIN`, `MAX`) calculated via SQL joins across related items.
  - **Files & Attachments (`files`)**: Local sandboxed asset storage with SHA-256 hashes and image thumbnail cards.

### 16.3 Multi-View Database Canvases (Tier 2)
- **Table View**:
  - macOS: Native AppKit `NSTableView` with resizable column dividers, frozen primary column, and bottom aggregation calculation row.
  - Windows port: Virtualized grid (`TanStack Table` / `react-window`) with fixed left column.
- **Board View (Kanban Swimlanes)**:
  - Horizontal swimlane columns grouped by `select`, `status`, or `people` property.
  - Native drag-and-drop: Moving a card updates the corresponding SQLite property and immediately refreshes related views.
- **Gallery View**:
  - Adaptive visual card grid (`LazyVGrid` / CSS Grid) displaying image covers from page attachments or cover URLs.
- **Calendar View**:
  - Monthly and multi-week chronological matrix mapping records by `date` properties with multi-day range spanning.

### 16.4 Native Visual Analytics, Forms & Automations (Tier 2)
- **Visual Chart Engine**:
  - macOS: Hardware-accelerated Apple **Swift Charts** (`import Charts`).
  - Windows port: Canvas/SVG charting via **Recharts** or **Chart.js**.
  - Layouts: Vertical bar, horizontal bar, temporal line chart, donut/sector chart, and KPI number cards with grouping and secondary subgroups.
- **Local Form Intake Sheet**:
  - Schema-driven modal input form allowing rapid data intake directly into connected database schemas.
  - Client-side validation (required flags, email/phone regex, numeric bounds).
  - Conditional branching logic: State-driven question reveal based on antecedent answers.
- **Page & Database Button Blocks**:
  - Clickable action triggers executing pre-configured multi-step workflows (e.g. duplicate template, update status).
- **SQLite Trigger & Action Automations**:
  - Internal event engine listening to database writes (`TransactionObserver`).
  - Evaluates triggers (on create, on status change) and executes actions (mutate property, apply template) with strict recursion depth guards (max depth 5) to prevent infinite loops.

### 16.5 Local AI Intelligence, Link Previews & Security Governance (Tier 2)
- **Inline AI (`/ai` Command & Spacebar Shortcut)**:
  - Contextual drafting, text expansion, tone adjustment, and action-item extraction into to-do lists.
  - macOS: Seamlessly connected to `AISocraticService` (offline Ollama / isolated API keys).
  - Windows port: IPC bridge to local Ollama (`localhost:11434`) or cloud providers.
- **AI Autofill Properties**:
  - Asynchronous background tasks populating database columns on save (`AI Summary`, `AI Key Info`, `Custom AI Prompt`).
- **Link Previews (Unfurling)**:
  - Asynchronous Open Graph scraper caching `og:title`, `og:description`, and `og:image` locally in SQLite.
- **Local Security & Audit Ledger**:
  - AES-GCM database-at-rest encryption via Apple Keychain (macOS) / Windows DPAPI (Windows).
  - Append-only audit table logging record modifications for revision tracking.

---

## 17. Unified Infinite Canvas, Flowchart Shapes & Multi-Media Pipeline

Medha features a hardware-accelerated Unified Infinite Canvas engine that bridges handwritten ink, rich interactive media, flowchart shapes, and dynamic smart connectors seamlessly into the PKM knowledge graph.

### 17.1 Database Schema & Persistence (GRDB Migration v17)
- **`canvas_items` Table**:
  - Stores spatial entities: flowchart shapes (`shape`), raster/vector images (`mediaImage`), video clips (`mediaVideo`), audio recordings (`mediaAudio`), embedded PDF pages (`mediaPDF`), floating text blocks (`textBlock`), and connected note cards (`noteCard`).
  - Spatial coordinates: $(x, y, \text{width}, \text{height}, \text{rotationDegrees}, \text{zIndex})$.
  - Visual styling: `fillColorHex`, `strokeColorHex`, `strokeWidth`, `cornerRadius`.
  - Semantic content: `title`, `summarySnippet`, `markdownContent`, and local `mediaAssetKey`.
  - Foreign key safety: Linked directly to `block(id)` (`canvasDocId`) with `onDelete: .cascade`.
- **`canvas_connectors` Table**:
  - Stores directed relational wires between canvas items with `sourceItemId`, `targetItemId`, `sourceCardinal`, and `targetCardinal` (`north`, `east`, `south`, `west`).
  - Routing algorithms: `orthogonal` (Manhattan 90° stepped paths) and `curved` (smooth cubic Bezier spline routing).
  - Terminal embellishments: `arrow`, `dot`, or `none`.
  - Inline semantic label pills: User-defined text labels (e.g. "Yes", "No", "Next", "Leads to").

### 17.2 Mathematical Routing Engine & Cardinal Snapping (`CanvasRoutingService`)
- **Cardinal Snapping**:
  - Every shape computes 4 magnetic snap anchors at its bounding box edges (Top/North, Right/East, Bottom/South, Left/West).
  - Live cursor proximity automatically pulls connector endpoints to the nearest cardinal anchor.
- **Orthogonal Manhattan Step Routing**:
  - Generates clear, non-overlapping 90-degree step paths with exit/entry stub offsets.
  - Automatically identifies whether an S-bend or Z-bend is required to navigate around shape boundaries.
- **Smooth Cubic Bezier Routing**:
  - Calculates outward normal control vectors based on the originating cardinal side.
  - Generates balanced cubic Bezier curves (`CGContext.addCurve(to:control1:control2:)`) with natural aesthetic curvature.
- **Vector Arrowheads & Inline Label Pills**:
  - Tangent-aligned vector arrowhead polygons at the destination terminal.
  - Centered text pills with rounded background capsules for legible annotations along connector lines.

### 17.3 Native Media Ingestion & Asset Storage (`CanvasAssetStorage`)
- **Local Sandboxed Storage**:
  - Dropped or imported assets are stored securely in `Application Support/Medha/CanvasAssets/`.
  - Deterministic UUID keys with file extension preservation.
- **Universal Multi-Media Ingestion**:
  - **Images**: PNG, JPEG, HEIC, WebP, GIF with high-resolution decoding and in-memory `NSCache` raster caching.
  - **Videos**: MP4, MOV with automatic asynchronous poster frame generation via `AVAssetImageGenerator` and duration detection.
  - **Audio**: MP3, M4A, WAV with duration formatting and synthetic waveform peak generation for visual audio scrubbers.
  - **PDFs**: Full multi-page document rendering via `PDFKit` with spatial page extraction.
- **Drag-and-Drop & Clipboard Paste**:
  - Dropping media files or pasting from the macOS clipboard onto `InkCanvasViewportNSView` immediately ingests the file, calculates canvas-relative dropped coordinates, and creates the corresponding `CanvasItem`.

### 17.4 Hardware-Accelerated 3-Tier Semantic Level-of-Detail (LOD) Zoom Rendering
To ensure fluid 60 FPS rendering across vast boards containing thousands of items, the CoreGraphics viewport implements 3 semantic zoom tiers:
1. **Macro View (`zoom < 0.35`)**:
   - High-contrast silhouette vector representations.
   - Simplified geometric outlines, item titles, and connector wire flows; interior dense text and media controls are omitted to preserve rendering throughput.
2. **Medium Flowchart View (`0.35 <= zoom < 1.0`)**:
   - Shape icons, bold titles, 2-line preview snippets, media raster thumbnails, and PKM link badges.
3. **Deep Detail View (`zoom >= 1.0`)**:
   - Full formatted Markdown typography, interactive media playback indicators, audio waveforms, and detailed node notes.

### 17.5 Universal Note Link Anchors & PKM Bi-Directional Graph Sync
- **Bidirectional Note Anchors**:
  - Any canvas item (shape, media, text block) can be linked to any workspace note via `linkedNoteDocId`.
  - Automatically registers bidirectional `DocLink` entries in Medha's SQLite PKM graph.
- **Visual Link Badges & Instant Jump**:
  - Distinctive link badge indicator rendered on linked items.
  - Clicking the link badge triggers instant navigation to the target document in the workspace.

### 17.6 Translucent Floating macOS Glass Toolbar (`CanvasUnifiedFloatingToolbar`)
- Positioned floating at the bottom center of the canvas with native macOS vibrancy and frosted glass blur.
- Quick-action tools:
  - **Pan / Hand Tool**: Freeform trackpad/mouse navigation without accidental drawing.
  - **Ink / Pen Tool**: Vector Apple Pencil / stylus inking.
  - **Flowchart Shapes**: Quick dropdown to insert Rectangles, Rounded Rectangles, Diamonds (Decision Nodes), Ellipses, or Container Groups.
  - **Smart Connectors**: Toggle connector wiring mode between Orthogonal (90°) and Curved Bezier.
  - **Text Block**: One-click insertion of formatted floating text notes.
  - **Media Upload**: File dialog to import local images, videos, audio, or PDFs.
  - **Link Note Card**: Quick search and insertion of an existing note as an interactive canvas card.

