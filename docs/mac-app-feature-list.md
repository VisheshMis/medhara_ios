# Medha macOS: Complete Feature Specification & Reference

> **Comprehensive feature inventory extracted directly from the native macOS implementation (`Sources/MedhaKit/`, `Sources/MedhaApp/`, and verified by 36/36 test suites in `MedhaTestRunner`).**

---

## 📑 Table of Contents

1. [Architectural Overview & Design System](#1-architectural-overview--design-system)
2. [Hierarchical Document & Block PKM Engine](#2-hierarchical-document--block-pkm-engine)
3. [Vector Ink Notes & PDF Engine](#3-vector-ink-notes--pdf-engine)
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

## 3. Vector Ink Notes & PDF Engine

### 3.1 Continuous Multi-Page Vector Canvas
- **Continuous Vertical Scroll**: Multi-page vertical layout mimicking an infinite or structured physical notebook.
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

### 3.2 PDF Import, Trimming & Embedding
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
- **Configurable Duration Presets**:
  - `10m`: Rapid sprint / Micro-focus (default).
  - `15m`: Quick revision.
  - `25m`: Standard Pomodoro technique.
  - `45m`: Deep work session.
  - `60m`: Lecture / Exam simulation block.
- **Cycle Flow & Audio Cues**:
  1. `Focus Session` (active study tracking).
  2. `Audio Beep & Pause` (2s double-tone chime, muted via button).
  3. `Micro-Break` (30s restorative eye rest).
  4. `Cycle Reset` (10s transition to next interval).

### 12.2 Persistent Study Statistics Engine (`FocusStatsService` & GRDB `focus_session`)
- **Granular Session Logging**: Every focused second is automatically tracked and persisted in SQLite (`v12_focus_sessions` migration) with foreign document linkage (`docId`), completion status, and timestamps.
- **Real-Time Aggregations**:
  - **Today Total**: Accumulated focused minutes vs. user-configured daily study goal (30m, 45m, 60m, 90m, 120m, 180m).
  - **This Week Total**: 7-day breakdown (Mon–Sun) with interactive bar distribution chart, daily average focus time, and today's highlighted bar.
  - **This Month Total**: Cumulative monthly study hours, active study days count, and daily average per active day.

### 12.3 Medha Activity Rings & Statistics Sheet (`FocusStatsSheet` & `⌘⇧T`)
- **Concentric Activity Rings View (`MedhaActivityRingsView`)**:
  - **Outer Ring**: Daily Study Goal — *Royal Violet / Indigo Gradient* (`#7C6CFF` → `#4C9AFF`).
  - **Middle Ring**: Weekly Focus Progress — *Vibrant Notes Blue* (`#3B82F6`).
  - **Inner Ring**: Consistency & Session Count — *Emerald Retention Green* (`#10B981`).
- **Modal Statistics Dashboard**: Accessible via the Timer Pill's Stats button or global hotkey `⌘⇧T`.
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
- **9 Schema Migrations (v1–v9)**:
  - `v1`: Base Notebooks, Documents, Blocks, and FTS5 index.
  - `v2`: Document Hierarchy (`parentDocId`, `isExpanded`, `sortOrder`).
  - `v3`: FSRS-4.5 Flashcards and Decks schema.
  - `v4`: Memory Palaces, Loci coordinates, and anchor references.
  - `v5`: Cross-document links and graph edge weightings.
  - `v6`: Deck options, learning steps, and retention parameters.
  - `v7`: Focus sessions and daily study tracking.
  - `v8`: Vector Ink strokes, points, pages, and template settings.
  - `v9`: Image occlusion flashcards and custom occlusion masks.

### 15.2 Local Asset Storage
- Dedicated application directory for binary assets:
  - Memory Palace high-res photographic backdrops (`PalaceAssetStorage`).
  - Image occlusion diagrams and cropped masks (`OcclusionAssetStorage`).
  - Vector ink page thumbnails and PDF document attachments.
- Zero cloud database lock-in: entire user library resides in a single, portable local SQLite file.
