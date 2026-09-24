# Medha (मेधा) — Spatial PKM & Cognitive Retention Engine

[![Platform: macOS 14.0+](https://img.shields.io/badge/platform-macOS%2014.0%2B-blue?logo=apple)](https://www.apple.com/macos/)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift)](https://swift.org)
[![Spaced Repetition: FSRS-4.5](https://img.shields.io/badge/Spaced%20Repetition-FSRS--4.5-green)](https://github.com/open-spaced-repetition/fsrs4anki)
[![Local AI: 100% Offline](https://img.shields.io/badge/AI-100%25%20Offline%20Local%20AI%20%28%3C4GB%20RAM%29-purple)](#5--dual-mode-ai-cloud--100-offline-local-ai)
[![Free Study Grounding](https://img.shields.io/badge/Grounding-Wikipedia%20%7C%20OpenAlex%20%7C%20Europe%20PMC%20%7C%20Wiktionary-teal)](#6--multi-source-free-academic-grounding-0-api-keys)
[![Test Suite: 28 Passed](https://img.shields.io/badge/tests-28%20passed-brightgreen)](#-automated-testing--verification-28-suites)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

> **मेधा (Medha)** — *Sanskrit for intellect, capacity for profound comprehension, and the power of indelible memory.*

**Medha** is an offline-first, native macOS Personal Knowledge Management (PKM) and cognitive retention platform. Crafted in Swift, SwiftUI, and AppKit with Metal-accelerated graphics, Medha closes the loop between **knowledge acquisition**, **associative comprehension**, and **lifelong memory consolidation**.

It seamlessly unifies **hierarchical block notes**, **GPU-accelerated knowledge graphs**, the ancient **2D spatial Method of Loci (Memory Palace)**, and **state-of-the-art FSRS-4.5 spaced repetition**, supercharged by **dual-mode AI** (Cloud & 100% Offline Local AI with multi-source academic grounding across Wikipedia, OpenAlex, Europe PMC, and Wiktionary).

---

## 📑 Table of Contents
- [🌟 The Cognitive Memory Architecture](#-the-cognitive-memory-architecture)
- [✨ Core Feature Suite](#-core-feature-suite)
  - [1. 🗂️ Refined Hierarchical Block Notes & PKM](#1-️-refined-hierarchical-block-notes--pkm)
  - [2. 🧠 3D Spaced Repetition (FSRS-4.5)](#2--3d-spaced-repetition-fsrs-45)
  - [3. 🏛️ 2D Spatial Memory Palace & Walk Mode (Method of Loci)](#3-️-2d-spatial-memory-palace--walk-mode-method-of-loci)
  - [4. 🕸️ GPU-Accelerated Knowledge Graph (Global & Local)](#4-️-gpu-accelerated-knowledge-graph-global--local)
  - [5. 🤖 Dual-Mode AI (Cloud & 100% Offline Local AI)](#5--dual-mode-ai-cloud--100-offline-local-ai)
  - [6. 🌐 Multi-Source Free Academic Grounding (0 API Keys)](#6--multi-source-free-academic-grounding-0-api-keys)
  - [7. ⏱️ Integrated Pomodoro Focus Engine](#7-️-integrated-pomodoro-focus-engine)
- [⌨️ Keyboard Shortcuts](#️-keyboard-shortcuts)
- [🏗️ Technical Architecture & Stack](#️-technical-architecture--stack)
- [📂 Project Structure](#-project-structure)
- [🧪 Automated Testing & Verification (28 Suites)](#-automated-testing--verification-28-suites)
- [🚀 Building & Running](#-building--running)
- [📖 Documentation Links](#-documentation-links)
- [📄 License](#-license)

---

## 🌟 The Cognitive Memory Architecture

Most PKM applications function as passive digital filing cabinets—notes are written once and forgotten. Medha is engineered around active cognitive pipelines:

```
[ Active Intake ]          [ Knowledge Synthesis ]         [ Long-Term Consolidation ]
+-------------------+      +-----------------------+       +-------------------------+
| Hierarchical      | ---> | GPU Knowledge Graph   | ----> | 2D Spatial Memory Palace|
| Block Notes       | <--- | (Bi-directional links)| <---  | (Method of Loci Walk)   |
+-------------------+      +-----------------------+       +-------------------------+
          |                                                             |
          +---------------------> [ FSRS-4.5 ] <------------------------+
                                  [ Flashcards ]
                                (3D Flip & Spaced Repetition)
```

1. **Intake & Capture**: Draft in an ergonomic, distraction-free block editor with living folder headers and instant full-text search.
2. **Associative Synthesis**: Traverse dense concepts in a 60–120 FPS force-directed knowledge graph with blended tree and wiki-link views.
3. **Spatial Encoding**: Anchor complex knowledge nodes and flashcards to physical loci across multi-photo spatial canvases using the ancient Method of Loci.
4. **Active Recall**: Review with FSRS-4.5 spaced repetition featuring 3D perspective flip cards, live interval previews, and offline AI Socratic questioning.

---

## ✨ Core Feature Suite

### 1. 🗂️ Refined Hierarchical Block Notes & PKM

- **Living Folder Command-Hub Header**: Every document opens with an informative metadata scrim showing its parent notebook path, child sub-page count, word count, estimated reading time, and attached active flashcards.
- **Centered 740pt Typographic Measure**: Notes are rendered within an optimal reading column (`maxWidth: 740pt`) with breathing room, eliminating horizontal eye strain on large macOS displays while keeping inspector tools docked.
- **Granular Block-Based Engine**: Complete block system supporting Document Title, Heading 1 (`#`), Heading 2 (`##`), Heading 3 (`###`), Paragraphs, Bullet Lists, Interactive To-Dos, Code Blocks, Quotes, Callouts, and Transclusion Embeds.
- **Caret & Keystroke Continuity**:
  - Seamless boundary traversal: Pressing `↑` at the top of a block jumps the cursor to the previous block; pressing `↓` at the end jumps forward.
  - Smart backspace handling: Pressing backspace at column 0 in a list downgrades the bullet to a regular paragraph before merging with the preceding block.
- **Zero-Lag Typing Isolation**: Keystrokes update in-memory published properties instantly without triggering round-trip database reloads or cursor jumps.
- **Bi-Directional Linking (`[[WikiLink]]`)**: Create spontaneous conceptual webs. The underlying SQLite `doc_link` index maintains inbound and outbound relationships without disrupting notebook trees.
- **Block Transclusion (`((b-uuid))`):** Embed any block from any document into your notes. Editing the source updates all transcluded views in real time.
- **Fast Full-Text Search (FTS5)**: Millisecond queries across tens of thousands of notes and blocks using SQLite FTS5 with BM25 relevance ranking.
- **One-Click Export**: Export notes to clean GitHub-Flavored Markdown or structured JSON (`⌘E`).

---

### 2. 🧠 3D Spaced Repetition (FSRS-4.5)

- **Modern FSRS-4.5 Scheduler**: Implements the Free Spaced Repetition Scheduler modeling memory Stability ($S$), Difficulty ($D$), and Retrievability ($R$), vastly reducing review fatigue compared to legacy SM-2.
- **True 3D Perspective Card Flip**: Beautiful spring-animated 3D flip card (`rotation3DEffect`, perspective 0.6) for tactile, enjoyable review sessions.
- **Real-Time Interval Preview Chips**: The 4 review buttons (`Again`, `Hard`, `Good`, `Easy`) display their dynamic next scheduled dates (e.g. `10m`, `1.2d`, `4.8d`, `12.5d`) calculated by FSRS in real time.
- **Single-Key Review Ergonomics**:
  - `Space`: Flip card to reveal answer or advance.
  - `1`, `2`, `3`, `4`: Instantly select review ratings.
- **Gradient Progress HUD**: Subtle, colorful progress bar across the top of the deck tracking completed cards vs. remaining due cards.
- **AI Socratic Tutor with Auto-Focus**: In Socratic mode, Medha automatically focuses the student's answer textfield (`@FocusState`), evaluates answers against card context, and suggests rating grades.
- **Deck & Note Grouping**: Study dedicated subject decks or automatically review cards grouped by parent document notebooks.

---

### 3. 🏛️ 2D Spatial Memory Palace & Walk Mode (Method of Loci)

- **Multi-Photo Infinite 2D Canvas**: Import multiple high-resolution photos of real-world spaces (homes, campuses, art galleries, architecture) into a vast, zoomable, pannable 2D canvas.
- **Sequential Loci Pathways**: Place numbered locus pins onto architectural landmarks and link them into sequential memory journeys with visual pathway lines.
- **Cinematic Spring Camera Navigation**: Walk Mode glides smoothly between loci using `.interactiveSpring(response: 0.45, dampingFraction: 0.86)` physics, auto-centering and framing each pin without jarring cuts.
- **Frosted Glass Pin Callouts**: Loci pins feature `.ultraThinMaterial` frosted glass scrims with pulsing radar beacons indicating the active step in your journey.
- **Floating Walk HUD Pill**: Sleek bottom control pill with arrow navigation shortcuts (`←`, `→`, `Space`, `Esc`) and a direct **"Jump to Source Note"** button.
- **Integrated Active Recall & Flashcard Testing**: Practice retrieving anchored concepts directly at each locus, rate your recall (`Remembered`, `Needed Clue`, `Forgot`), and complete review sessions with celebratory confetti.
- **Safe Local Asset Storage**: All palace photos are safely managed inside the app's local support directory to prevent broken paths.

---

### 4. 🕸️ GPU-Accelerated Knowledge Graph (Global & Local)

- **Metal / SwiftUI Immediate-Mode Canvas**: Renders 1,000+ nodes and edges at **60–120 FPS** with zero DOM overhead.
- **1-Click Layer Presets**:
  - `[Links Only] (Default)`: Visualizes associative wiki-links and block references (`LINKS_TO`).
  - `[Tree Only]`: Visualizes folder and notebook parent-child hierarchy (`CONTAINS`).
  - `[Blended]`: Renders both layers simultaneously. `CONTAINS` edges display as dashed, dimmer purple lines (`[4, 4]`), while `LINKS_TO` edges display as solid green lines.
- **Cooling Alpha Physics (0% CPU at Rest)**: 2D force simulation with Coulomb repulsion, Hooke spring attraction, and velocity damping. Alpha automatically decays to rest (`alpha < 0.002`), consuming **0% CPU and 0% battery** when idle.
- **Dynamic Level of Detail (LOD)**: Text labels smoothly hide below `0.65x` zoom for panoramic graph views and appear when zooming or hovering.
- **Degree-Scaled Vertex Sizing**: Node radius scales gracefully with degree (`inDegree + outDegree`), clamped between `6pt` and `26pt`.
- **Ghost Links for Future Notes**: Unwritten `[[Future Notes]]` appear as dashed outline nodes. Clicking them creates the note immediately.
- **Inspector Local Graph Panel**: Scoped to the currently open note with **1-Hop**, **2-Hop**, and **3-Hop** BFS depth control and directional arrowheads (`→` Outbound green, `←` Inbound cyan).

---

### 5. 🤖 Dual-Mode AI (Cloud & 100% Offline Local AI)

- **100% Offline Local AI (<4 GB RAM)**:
  - Run compact open-weight models locally on macOS via [Ollama](https://ollama.com), LM Studio, or llama.cpp.
  - **Recommended Default**: **`qwen2.5:1.5b`** (~980 MB, runs in <2 GB RAM with Metal GPU acceleration).
  - Also supports `deepseek-r1:1.5b`, `llama3.2:1b`, `llama3.2:3b`, `smollm2:1.7b`, and `mistral:7b`.
  - Zero cloud API keys required, zero subscription fees, and complete offline data privacy.
- **Reasoning Model Support (DeepSeek-R1 / QwQ)**:
  - Distilled reasoning models output chain-of-thought `<think>...</think>` tokens.
  - Medha features automatic regex sanitization that parses reasoning thoughts away, extracting pristine structured JSON outlines and Socratic dialogues.
- **Cloud Providers**: Native support for Google Gemini (`gemini-2.5-flash`, `gemini-1.5-flash`) and OpenAI (`gpt-4o-mini`, `gpt-4o`).
- **Independent Dual Configuration**: Run Local AI for flashcard Socratic tutoring while using Cloud AI for notes synthesis, or run 100% local across both.

---

### 6. 🌐 Multi-Source Free Academic Grounding (0 API Keys)

Small local language models (1B–3B parameters) can occasionally hallucinate specific facts. Medha solves this by pairing local inference with **Free Online Academic Grounding**, querying public research APIs on the fly without any API keys or subscriptions:

| Source | Coverage | Content Grounded |
| :--- | :--- | :--- |
| 🌐 **Wikipedia** | Global Encyclopedia | Broad conceptual foundations and historical context |
| 🎓 **OpenAlex & CrossRef** | 250M+ Academic Papers | STEM, CS, Mathematics, and Humanities research with inverted-index abstract reconstruction |
| 🧬 **Europe PMC** | PubMed & Life Sciences | Biomedical, clinical, neuroscience, and pharmacology abstracts |
| 📖 **Wiktionary** | Academic Lexicon | Precise terminology definitions, grammatical parts of speech, and etymology |

- **Parameter-Aware Context Budgeting**: For 1.5B–3B models, Medha automatically budgets extracts to ~400–500 concise characters per source, keeping prompts dense and preventing small models from losing attention. For 7B+ models, richer abstracts and citations are injected.
- **Parallel Query Execution**: All enabled sources are fetched concurrently via Swift `withTaskGroup`.
- **Graceful Offline Fallback**: If internet is disconnected, Medha automatically falls back to offline model inference without interruptions.

---

### 7. ⏱️ Integrated Pomodoro Focus Engine

- **Always-Accessible Header Widget**: Persistent timer ring at the top of the sidebar.
- **Preset Cycles**: Focus (25m), Short Break (5m), and Long Break (15m).
- **Distraction-Free**: Visual countdown animations that keep you in flow without leaving your workspace.

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action | Scope |
| :--- | :--- | :--- |
| `⌘ N` | Create New Note | Global |
| `⇧ ⌘ N` | Create New Notebook | Global |
| `⌘ K` | Open Command Palette / Global Search | Global |
| `⌘ I` | Toggle Right Inspector Panel | Global |
| `⌘ G` | Open Knowledge Graph Canvas | Global |
| `⌘ E` | Export Current Note (Markdown / JSON) | Notes Editor |
| `/` | Trigger Slash Block Command Menu | Notes Editor |
| `((` | Insert Block Transclusion Embed | Notes Editor |
| `[[` | Insert Bi-Directional WikiLink | Notes Editor |
| `↑ / ↓` | Jump Cursor to Previous / Next Block | Notes Editor |
| `Space` | Flip Card / Next Locus | Flashcards & Palace |
| `1, 2, 3, 4` | Rate Card (`Again`, `Hard`, `Good`, `Easy`) | Flashcards |
| `← / →` | Step Backward / Forward in Loci Route | Memory Palace |
| `Double Click Node` | Pin / Unpin Vertex in Graph | Graph Canvas |
| `Double Click Canvas`| Reset Zoom & Re-center Camera | Graph Canvas |

---

## 🏗️ Technical Architecture & Stack

```
+-----------------------------------------------------------------------------------------+
|                                    Medha Application                                    |
|  +--------------------+  +----------------------+  +---------------------------------+  |
|  |    Notes Editor    |  |   Knowledge Graph    |  |     Memory Palace & Canvas      |  |
|  |  (Block PKM / FTS) |  | (Force Sim Canvas)   |  |     (2D Spatial Loci Walk)      |  |
|  +--------------------+  +----------------------+  +---------------------------------+  |
|  +-----------------------------------------------------------------------------------+  |
|  |                       MedhaKit Domain Services & Protocols                        |  |
|  |  - BlockStore (State & Queries)          - ForceSimulation (Cooling Alpha 0% CPU) |  |
|  |  - FSRSScheduler (v4.5 Memory Model)     - AISocraticService (Dual Engine Router) |  |
|  |  - StudyKnowledgeService (Multi-Source)  - PalaceAssetStorage (Local Image Repo)  |  |
|  |    * Wikipedia, OpenAlex, Europe PMC, Wiktionary Grounding Fetchers               |  |
|  +-----------------------------------------------------------------------------------+  |
|  +-----------------------------------------------------------------------------------+  |
|  |                             Persistence & Storage Layer                           |  |
|  |  - GRDB.swift with SQLite 3.45+           - WAL Mode (High Concurrency)            |  |
|  |  - FTS5 Full-Text Search Engine           - Indexed doc_link Graph Relationships  |  |
|  +-----------------------------------------------------------------------------------+  |
+-----------------------------------------------------------------------------------------+
```

- **Languages & Frameworks**: Swift 5.9+, SwiftUI, AppKit native macOS integration
- **Database**: SQLite 3.45+ via [GRDB.swift](https://github.com/groue/GRDB.swift) (WAL mode, foreign key cascade integrity, automatic migrations)
- **Search Engine**: SQLite FTS5 virtual tables with Porter stemming and BM25 ranking
- **Rendering**: GPU immediate-mode `Canvas` on Metal backend for graph; vast spatial matrix transforms for 2D Memory Palace
- **Memory Science**: FSRS-4.5 (Free Spaced Repetition Scheduler) state machine

---

## 📂 Project Structure

```
medharara/
├── Package.swift                             # Swift Package Manager manifest
├── README.md                                 # Main repository documentation & showcase
├── LOCAL_AI_SETUP.md                         # Detailed Local AI & Ollama setup guide
├── Medhara_Complete_Presentation_Flow.pdf    # Full technical & product presentation deck
├── Medha.app/                                # Compiled macOS universal release application
│   └── Contents/MacOS/Medha                  # Native binary executable
├── Sources/
│   ├── MedhaApp/
│   │   └── MedhaApp.swift                    # Application entrypoint, menu commands, shortcuts
│   ├── MedhaKit/
│   │   ├── Database/                         # GRDB DatabaseManager, schema migrations, seeders
│   │   ├── Models/                           # Block, DocLink, Flashcard, Palace, GraphModels
│   │   ├── Services/                         # BlockStore, ForceSimulation, AISocratic, FSRS,
│   │   │                                     # WikipediaService, StudyKnowledgeService
│   │   └── UI/
│   │       ├── Editor/                       # BlockEditor, BlockRow, SlashMenu, NotesAIAssistant
│   │       ├── Flashcards/                   # FlashcardManager, 3D flip card, AISettingsSheet
│   │       ├── Graph/                        # GlobalGraphView, GraphCanvasView, GraphControlsSheet
│   │       ├── Inspector/                    # InspectorView, Outline, Backlinks, LocalGraphView
│   │       ├── MemoryPalace/                 # MemoryPalaceView, Multi-photo 2D canvas, Walk mode
│   │       └── Navigation/                   # SidebarView, DocumentTreeView, MainSplitView
│   └── MedhaTestRunner/
│       └── main.swift                        # 28 automated integration test suites
```

---

## 🧪 Automated Testing & Verification (28 Suites)

Medha is verified by an extensive, non-mocked integration test runner ensuring rock-solid database integrity, rendering performance, and algorithmic accuracy:

```bash
swift run MedhaTestRunner < /dev/null
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
27. `testGraphViewAndPhysicsEngine`: Indexed graph reads, layer separation, ghost nodes, orphan filtering, BFS local graph hops, and cooling alpha physics rest.
28. `testHybridStudyGroundingAndReasoningSanitization`: OpenAlex inverted index abstract decoding, Europe PMC biomedical search, Wiktionary lexical definitions, multi-source parallel fetch, parameter-aware budget limits, and DeepSeek-R1 / QwQ `<think>` tag sanitization.

---

## 🚀 Building & Running

### Prerequisites
- macOS 14.0 (Sonoma) or macOS 15.0+ (Sequoia)
- Xcode 15.0+ or Apple Command Line Tools (`xcode-select --install`)
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

- [Local AI & Multi-Source Grounding Setup Guide](LOCAL_AI_SETUP.md)
- [Complete Product & Technical Presentation Deck (PDF)](Medhara_Complete_Presentation_Flow.pdf)
- [FSRS Spaced Repetition Scheduling Algorithm](https://github.com/open-spaced-repetition/fsrs4anki)
- [GRDB.swift SQLite Documentation](https://github.com/groue/GRDB.swift)

---

## 📄 License

Distributed under the **MIT License**. See `LICENSE` for more information.
