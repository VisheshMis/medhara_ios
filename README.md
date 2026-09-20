# Medha (मेधा) — Spatial PKM & Cognitive Retention Engine

[![Platform: macOS 14.0+](https://img.shields.io/badge/platform-macOS%2014.0%2B-blue?logo=apple)](https://www.apple.com/macos/)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift)](https://swift.org)
[![FSRS 4.5](https://img.shields.io/badge/Spaced%20Repetition-FSRS--4.5-green)](https://github.com/open-spaced-repetition/fsrs4anki)
[![Local AI](https://img.shields.io/badge/AI-100%25%20Offline%20Local%20AI%20%28%3C4GB%20RAM%29-purple)](#5--dual-mode-ai-cloud--100-offline-local-ai)
[![Test Suite](https://img.shields.io/badge/tests-27%20passed-brightgreen)](#-automated-testing--verification)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

> **मेधा (Medha)** — *Sanskrit for intellect, capacity for profound comprehension, and the power of indelible memory.*

**Medha** is a high-performance, offline-first Personal Knowledge Management (PKM) and cognitive retention platform built natively for macOS with Swift, SwiftUI, and AppKit. It unifies **hierarchical block-based note-taking**, **interactive knowledge graphs**, **2D spatial Memory Palaces (Method of Loci)**, and **state-of-the-art FSRS-4.5 spaced repetition**, augmented by **dual-mode AI** (Cloud & 100% Offline Local AI with free encyclopedic Wikipedia grounding).

---

## 📑 Table of Contents
- [✨ Core Feature Suite](#-core-feature-suite)
  - [1. 🗂️ Hierarchical Block Notes & PKM](#1-️-hierarchical-block-notes--pkm)
  - [2. 🕸️ Interactive Knowledge Graph (Global & Local)](#2-️-interactive-knowledge-graph-global--local)
  - [3. 🏛️ 2D Spatial Memory Palace & Method of Loci](#3-️-2d-spatial-memory-palace--method-of-loci)
  - [4. 🧠 FSRS-4.5 Spaced Repetition (Flashcards)](#4--fsrs-45-spaced-repetition-flashcards)
  - [5. 🤖 Dual-Mode AI (Cloud & 100% Offline Local AI)](#5--dual-mode-ai-cloud--100-offline-local-ai)
  - [6. 🌐 Free Online Wikipedia Knowledge Grounding](#6--free-online-wikipedia-knowledge-grounding)
  - [7. ⏱️ Integrated Focus Timer (Pomodoro)](#7-️-integrated-focus-timer-pomodoro)
- [⌨️ Keyboard Shortcuts](#️-keyboard-shortcuts)
- [🏗️ Technical Architecture & Stack](#️-technical-architecture--stack)
- [📂 Project Structure](#-project-structure)
- [🧪 Automated Testing & Verification (27 Suites)](#-automated-testing--verification-27-suites)
- [🚀 Building & Running](#-building--running)
- [📖 Documentation Links](#-documentation-links)
- [📄 License](#-license)

---

## ✨ Core Feature Suite

### 1. 🗂️ Hierarchical Block Notes & PKM
- **Block-Based Architecture**: Complete granular block system including Document Title, Heading 1 (`#`), Heading 2 (`##`), Heading 3 (`###`), Paragraph, Bullet Lists (with auto-indentation and newline continuation), To-Do Task Lists (with interactive checkboxes), Code Blocks, Quotes, Callouts, and Block References (`((b-...))`).
- **Keystroke Isolation & Focus Stability**: Zero input lag and flicker-free typing. Keystrokes update in-memory published properties directly without round-trip database reloads. Title focus remains anchored with dedicated `@FocusState` management.
- **Bi-Directional Linking (`[[WikiLink]]`)**: Create associative links between notes on the fly. The SQLite `doc_link` index automatically tracks inbound and outbound connections without altering document hierarchy.
- **Transclusion Block References**: Embed any block from any note with `((blockId))`. Updates to source blocks reflect instantly everywhere.
- **Document Tree Sidebar**: Clean folder-based document tree with drag-and-drop nesting, parent-child breadcrumbs, and recursive cascading deletion.
- **Quick Views & Filters**: Instantly switch between `All Notes`, `Recent`, `Favorites`, `To-Do Tasks`, and custom Notebooks.
- **Fast Full-Text Search (FTS5)**: Millisecond search queries across tens of thousands of notes and blocks using SQLite FTS5 with BM25 ranking.
- **Export Formats**: One-click export to clean GitHub-flavored Markdown or structured JSON (`⌘E`).

---

### 2. 🕸️ Interactive Knowledge Graph (Global & Local)
- **GPU-Accelerated Canvas**: Built with SwiftUI `Canvas` (CoreGraphics / Metal backend), capable of rendering 1,000+ nodes and edges at **60–120 FPS** with zero DOM or View tree overhead.
- **1-Click View Presets**:
  - `[Links Only] (Default)`: Visualizes associative wiki-links and block references (`LINKS_TO`).
  - `[Tree Only]`: Visualizes folder and notebook parent-child hierarchy (`CONTAINS`).
  - `[Blended]`: Renders both layers simultaneously. `CONTAINS` edges display as dashed, dimmer purple lines (`[4, 4]`), while `LINKS_TO` edges display as solid green lines.
- **Dynamic Level of Detail (LOD)**: Text labels automatically hide below `0.65x` zoom for panoramic graph views and appear smoothly when zooming in or hovering.
- **Degree-Scaled Vertex Sizing**: Vertices dynamically scale with degree (`inDegree + outDegree`), clamped between `6pt` and `26pt` so hubs never dominate the screen.
- **Unresolved Ghost Links**: Unwritten `[[Future Notes]]` appear as smaller, dashed outline circles (`radius 5.5`). Clicking an unresolved node prompts you to create the document immediately.
- **Orphan Node Filtering**: Toggle to hide or show isolated documents with zero links (hidden by default).
- **Hover Spotlight**: Hovering any vertex highlights it and all immediate 1st-degree neighbors while dimming the rest of the network to 14% opacity.
- **Interactive Physics Engine**:
  - Pure Swift 2D force-directed layout with Coulomb repulsion, Hooke spring attraction, center gravity, and velocity damping.
  - **Cooling Alpha (0% CPU at Rest)**: Alpha decays each frame until reaching rest (`alpha < 0.002`). When idle, simulation consumes **0% CPU and battery**.
  - **Pinning**: Drag any node to pin it in place (`isPinned = true`); double-click to unpin.
  - Double-click empty canvas to reset camera and re-center.
- **Persisted Layout Sliders**: Adjust Repel Force, Link Attraction, Rest Distance, Center Gravity, and Pause/Resume (saved in `UserDefaults`).
- **Priority-Ordered Color Rules**: Assign node colors by Top-Level Ancestor/Folder (8-color harmonious palette), by `#tag` (e.g. `#neuro`, `#memory`), or by title query.
- **Inspector Local Graph Panel**: Scoped to the currently active note with **1-Hop**, **2-Hop**, and **3-Hop** BFS depth control, featuring directional arrowheads (`→` Outbound green, `←` Inbound cyan).

---

### 3. 🏛️ 2D Spatial Memory Palace & Method of Loci
- **Multi-Photo Spatial Canvas**: Place multiple high-resolution interior and exterior photos within an infinite 2D zoomable and pannable spatial canvas.
- **Sequential Loci Pathways**: Anchor knowledge pins in sequential order with numbered badges and connecting visual pathway lines across canvas photos.
- **Interactive Walk Mode**:
  - Smooth camera auto-panning that centers and zooms directly onto each active locus pin.
  - Pulsing radar beacon and locus badge highlighting the current step.
  - Active recall retrieval prompt: *"Can you recall the knowledge or flashcard anchored at this locus?"*
  - Reveal direct anchored knowledge with self-assessment checkmarks (`Remembered`, `Needed Clue`, `Forgot`).
  - Integrated flashcard testing with flip-to-reveal and live FSRS rating buttons.
  - Confetti walk completion celebration screen with retention summaries.
- **Safe Local Asset Storage**: Palace photos are safely copied and managed in the local app support repository to prevent broken file paths.

---

### 4. 🧠 FSRS-4.5 Spaced Repetition (Flashcards)
- **Modern FSRS-4.5 Algorithm**: Implements the Free Spaced Repetition Scheduler modeling Memory Stability ($S$), Difficulty ($D$), and Retrievability ($R$), vastly outperforming legacy SM-2.
- **Topic Decks & Automatic Note Grouping**: Organize cards into dedicated decks with custom colors and icons, or automatically review cards grouped by their parent note hierarchy.
- **4-Button Review Cycle**: `Again` (1), `Hard` (2), `Good` (3), `Easy` (4) with live real-time scheduled interval previews (e.g. `10m`, `1.2d`, `4.8d`, `12.5d`).
- **AI Socratic Tutor Evaluation**: Socratic grading assistant that asks guided questions, assesses understanding, and suggests optimal recall ratings.

---

### 5. 🤖 Dual-Mode AI (Cloud & 100% Offline Local AI)
- **100% Offline Local AI (< 4 GB RAM)**:
  - Run compact open-weight models locally on your Mac using [Ollama](https://ollama.com), LM Studio, or llama.cpp.
  - Default model: **`qwen2.5:1.5b`** (~980 MB, runs in < 2 GB RAM with Metal GPU acceleration).
  - Also supports `llama3.2:1b`, `llama3.2:3b`, `smollm2:1.7b`, and `mistral:7b`.
  - Zero cloud API keys required, zero subscription fees, and complete offline privacy.
- **Cloud AI Providers**: Seamless support for Google Gemini (`gemini-3.6-flash`, `gemini-2.5-flash`, `gemini-1.5-flash`) and OpenAI (`gpt-4o-mini`, `gpt-4o`).
- **Dual Independent Configuration**:
  - Use separate models/providers for **Flashcards AI** (Socratic recall) vs. **Notes AI** (downward outline hierarchy and document generation).
  - Example: Use free local Ollama for flashcards while using Gemini for long-form note research.
- **Step-by-step Setup Guide**: Read [`LOCAL_AI_SETUP.md`](LOCAL_AI_SETUP.md).

---

### 6. 🌐 Free Online Wikipedia Knowledge Grounding
- **Real-Time Fact Injection**: Built-in `WikipediaService` queries Wikipedia's public REST API on the fly for keywords in your notes or cards.
- **Supercharges Lightweight Models**: Injects authoritative encyclopedic ground truth into the local AI prompt, completely eliminating hallucinations in 1B and 1.5B models without requiring an API key.
- **Graceful Offline Fallback**: If internet is unavailable, Medha automatically falls back to pure local inference without interruptions.

---

### 7. ⏱️ Integrated Focus Timer (Pomodoro)
- **Top-Left Persistent Widget**: Elegant Pomodoro focus timer with animated progress rings and state transitions.
- **State Machine**: Seamless switching between Focus (25m), Short Break (5m), and Long Break (15m).
- **Always Accessible**: Visible at the top of the navigation sidebar across all application modes.

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action | Scope |
| :--- | :--- | :--- |
| `⌘ N` | Create New Note | Global |
| `⇧ ⌘ N` | Create New Notebook | Global |
| `⌘ K` | Open Spotlight Search & Command Palette | Global |
| `⌘ I` | Toggle Right Inspector Panel | Global |
| `⌘ G` | Toggle Knowledge Graph View | Global |
| `⌘ E` | Export Current Note (Markdown / JSON) | Notes Editor |
| `/` | Open Slash Command Block Menu | Notes Editor |
| `((` | Insert Block Reference / Embed | Notes Editor |
| `[[` | Insert Bi-Directional WikiLink | Notes Editor |
| `Double Click Node` | Unpin Vertex in Graph View | Graph Canvas |
| `Double Click Background` | Re-center & Zoom-to-Fit Camera | Graph Canvas |

---

## 🏗️ Technical Architecture & Stack

```
+---------------------------------------------------------------------------------+
|                                Medha Application                                |
|  +-------------------+  +--------------------+  +----------------------------+  |
|  |   Notes Editor    |  |  Knowledge Graph   |  |   Memory Palace & Canvas   |  |
|  | (Block PKM / FTS) |  | (Force Sim Canvas) |  |   (2D Spatial Loci Walk)   |  |
|  +-------------------+  +--------------------+  +----------------------------+  |
|  +---------------------------------------------------------------------------+  |
|  |                 MedhaKit Domain Services & UI Components                  |  |
|  |  - BlockStore (State & Queries)      - ForceSimulation (Cooling Alpha)   |  |
|  |  - FSRSScheduler (v4.5 Model)         - AISocraticService (Dual Engine)  |  |
|  |  - WikipediaService (Grounding)       - PalaceAssetStorage (Local Files) |  |
|  +---------------------------------------------------------------------------+  |
|  +---------------------------------------------------------------------------+  |
|  |                        Storage & Database Engine                          |  |
|  |  - GRDB.swift with SQLite 3.45+       - WAL Mode (High Concurrency)       |  |
|  |  - FTS5 Full-Text Search Engine       - Indexed doc_link Graph Relations  |  |
|  +---------------------------------------------------------------------------+  |
+---------------------------------------------------------------------------------+
```

- **Framework**: Swift 5.9+ / SwiftUI / AppKit integration
- **Persistence**: SQLite with [GRDB.swift](https://github.com/groue/GRDB.swift) (WAL mode, foreign key enforcement, automatic schema migrations)
- **Search**: SQLite FTS5 virtual tables with Porter stemmer and BM25 relevance ranking
- **Rendering**: GPU-accelerated immediate mode `Canvas` for Graph and vast `GeometryReader` spatial transforms for 2D Memory Palace
- **Memory Scheduling**: FSRS-4.5 (Free Spaced Repetition Scheduler) with 4-state rating matrices

---

## 📂 Project Structure

```
medharara/
├── Package.swift                             # Swift Package Manager manifest
├── README.md                                 # Main repository showcase
├── LOCAL_AI_SETUP.md                         # Detailed Local AI & Ollama setup guide
├── Medha.app/                                # Compiled macOS universal release application
│   └── Contents/MacOS/Medha                  # Native binary executable
├── Sources/
│   ├── MedhaApp/
│   │   └── MedhaApp.swift                    # Application entrypoint, menu commands, shortcuts
│   ├── MedhaKit/
│   │   ├── Database/                         # GRDB DatabaseManager, migrations, seeders
│   │   ├── Models/                           # Block, DocLink, Flashcard, Palace, GraphModels
│   │   ├── Services/                         # BlockStore, ForceSimulation, AISocratic, FSRS, Wikipedia
│   │   └── UI/
│   │       ├── Editor/                       # BlockEditor, BlockRow, SlashMenu, NotesAIAssistant
│   │       ├── Flashcards/                   # FlashcardManager, AISettingsSheet
│   │       ├── Graph/                        # GlobalGraphView, GraphCanvasView, GraphControlsSheet
│   │       ├── Inspector/                    # InspectorView, Outline, Backlinks, LocalGraphView
│   │       ├── MemoryPalace/                 # MemoryPalaceView, Multi-photo 2D canvas, Walk mode
│   │       └── Navigation/                   # SidebarView, DocumentTreeView, MainSplitView
│   └── MedhaTestRunner/
│       └── main.swift                        # 27 automated integration test suites
```

---

## 🧪 Automated Testing & Verification (27 Suites)

Medha contains a comprehensive test runner verifying all architectural layers with zero dependencies on mock UI delays:

```bash
swift run MedhaTestRunner
```

### Verified Test Suites:
1. `testDatabaseInitializationAndSeeding`: SQLite schema setup, WAL mode, foreign key integrity.
2. `testBlockCRUDOperations`: Block creation, indentation, hierarchy assignment, and sort orders.
3. `testTaskBlockToggle`: Interactive to-do checkmarks and persistence.
4. `testFTS5Search`: Millisecond BM25 full-text queries across document blocks.
5. `testBlockReferencesAndBacklinks`: Bi-directional transclusion index and backlinks discovery.
6. `testOutlineGeneration`: Dynamic heading hierarchy extraction (H1–H3).
7. `testDocumentHierarchyAndTree`: Parent-child folder nesting and breadcrumb traversal.
8. `testDocumentAncestryBreadcrumbs`: Root-to-leaf path resolution.
9. `testTreeExpansionAndFilter`: Folder expansion states and text filtering.
10. `testRecursiveCascadeDeletion`: Safe recursive deletion of sub-trees without orphaned rows.
11. `testDiskDatabaseAndSeededHierarchy`: Multi-session disk persistence and SQLite stability.
12. `testFocusTimerStateCycle`: Pomodoro cycle transitions and countdown tick accuracy.
13. `testFSRSScheduler`: FSRS-4.5 interval calculation, stability, and difficulty curves.
14. `testFlashcardsInHierarchyAndStore`: Card generation scoped to note hierarchies.
15. `testMemoryPalaceAnd2DLoci`: Spatial loci placement, coordinate math, and persistence.
16. `testLinksAreNotHierarchyConstraint`: Structural separation of `LINKS_TO` directed graph vs `CONTAINS` tree.
17. `testMultiPhotoPalaceAndLocusAnchors`: Multi-photo 2D canvas positioning and locus route sequencing.
18. `testVastSpatialCanvasAndAssetStorage`: Safe local asset copying and high-resolution photo bounds.
19. `testFlashcardDecksAndNoteGrouping`: Custom decks and note-grouped default decks.
20. `testMockNotesDecksAndMemoryPalaces`: Default study retention seeder validation.
21. `testAISocraticEvaluationAndSettings`: Multi-provider AI configuration and key verification.
22. `testNotesAIDownwardHierarchyAndDualConfiguration`: Downward note outline synthesis and dual configs.
23. `testLocalAIAndWikipediaGrounding`: Ollama endpoint validation, Wikipedia grounding prompt injection.
24. `testBulletListFormattingAndMultilineCollision`: Text line spacing and multiline collision prevention.
25. `testNoteTitleFocusStability`: Keystroke isolation and stable title focus without cursor shifts.
26. `testCalloutExclusionInAIGeneration`: Clean outline generation without redundant callout boxes.
27. `testGraphViewAndPhysicsEngine`: Indexed graph reads, `LINKS_TO` vs `CONTAINS` layer separation, unresolved ghost nodes, orphan filtering, local graph multi-hop BFS directionality, and cooling alpha physics rest.

---

## 🚀 Building & Running

### Prerequisites
- macOS 14.0 (Sonoma) or later
- Xcode 15.0+ or Command Line Tools (`xcode-select --install`)
- Swift 5.9+

### Build from Source
```bash
# Clone the repository
git clone https://github.com/VisheshMis/medhara_ios.git
cd medhara_ios

# Build optimized release binary
swift build -c release

# Run Medha
swift run -c release Medha
```

### Pre-Compiled macOS Application
You can directly launch the compiled release application bundle:
```bash
open Medha.app
```

---

## 📖 Documentation Links

- [Local AI Setup & Ollama Guide](LOCAL_AI_SETUP.md)
- [FSRS Spaced Repetition Scheduling Algorithm](https://github.com/open-spaced-repetition/fsrs4anki)
- [GRDB.swift SQLite Documentation](https://github.com/groue/GRDB.swift)

---

## 📄 License

Distributed under the **MIT License**. See `LICENSE` for more information.
