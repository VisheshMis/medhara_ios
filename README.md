# Medha (मेधा)

Medha is a high-performance, offline-first Personal Knowledge Management (PKM) and spatial memory retention platform built with Swift and SwiftUI. It brings together hierarchical block-based note-taking, state-of-the-art FSRS spaced repetition, and 2D spatial Memory Palaces with multi-photo canvas scenes and active recall retrieval.

---

## ✨ Features

### 1. 🗂️ Hierarchical Notes & Outline
- **Tree-structured documents** with recursive cascading deletion and breadcrumb navigation.
- **Bi-directional linking (`[[...]]`)**: Link arbitrary notes without altering document hierarchy.
- **Backlinks & references**: Instant graph connections and reference discovery.
- **SQLite WAL mode & FTS5 full-text search**: Millisecond search queries across tens of thousands of notes and blocks.

### 2. 🧠 FSRS-4.5 Spaced Repetition (Flashcards)
- **Modern Free Spaced Repetition Scheduler (FSRS-4.5)** with stability, difficulty, and retrievability modeling.
- **Card Decks**: Group flashcards by topic or automatically generate decks from note hierarchies.
- **Study sessions**: 4-rating review cycle (`Again`, `Hard`, `Good`, `Easy`) with real-time interval scheduling.
- **Direct Anchors & Flashcards**: Option to attach flashcards or directly anchor facts to memory loci.

### 3. 🏛️ 2D Memory Palace & Spatial Canvas
- **Multi-Photo Canvas**: Place multiple high-resolution photos and scenes within a vast 2D zoomable and pannable spatial canvas.
- **Sequential Loci Routes**: Connect loci with numbered order pins and visual routes across photos.
- **Interactive Walk Mode**:
  - Auto-panning camera that centers and zooms on each locus pin.
  - Pulsing radar beacon on the active locus pin.
  - Active recall retrieval prompt: *"Can you recall the knowledge or flashcard anchored at this locus?"*
  - Reveal direct anchored knowledge with self-assessment checkmarks (`Remembered`, `Needed Clue`, `Forgot`).
  - Integrated flashcard testing with flip-to-reveal and live FSRS rating buttons.
  - Walk completion celebration screen.
- **Safe Asset Storage**: Palace photos are safely stored and managed in the local app support repository.

### 4. 🕸️ Interactive Knowledge Graph View (Global & Local)
- **Global Graph**: High-performance 2D force-directed layout rendered with GPU-accelerated SwiftUI Canvas.
- **Layer Presets**: Switch in one click between `[Links Only]` (associative `LINKS_TO`), `[Tree Only]` (hierarchy `CONTAINS`), or `[Blended]`.
- **Dynamic LOD & Controls**: Level of Detail labels, degree-scaled vertices, live search filter (Dim/Hide), and persisted layout physics.
- **Local Graph Panel**: Scoped to the active note with 1–3 hop depth control and directional arrowheads (inbound vs. outbound).

### 5. 🤖 Dual-Mode AI (Cloud & 100% Offline Local AI)
- **Local AI (< 4 GB RAM)**: Run compact open-weight models (Qwen 2.5 1.5B, Llama 3.2 1B/3B, SmolLM2) locally on your Mac using Ollama, LM Studio, or llama.cpp. Zero cloud fees and complete privacy.
- **Free Wikipedia Knowledge Grounding**: Augments lightweight local models with real-time encyclopedic ground truth without requiring an API key.
- **See [LOCAL_AI_SETUP.md](file:///Users/visheshmishra/Downloads/medharara/LOCAL_AI_SETUP.md)** for step-by-step setup instructions.

### 6. 🧭 Clean 2-Column Sidebar & Focus Timer
- **2-Column Navigation**: Distraction-free interface with a clean left sidebar (Focus Timer, Notes & Folders, Knowledge Graph, Flashcards, Memory Palace, Notebooks).
- **Contextual Notes Tab**: Notes hierarchy outline only displays when editing notes, leaving Flashcards, Graph, and Memory Palace with full-screen width.
- **Built-in Focus Timer**: Pomodoro focus timer widget with visual rings and state transitions.

---

## 🛠️ Architecture & Tech Stack

- **Platform**: macOS 14.0+ (SwiftUI & AppKit integration)
- **Database**: [GRDB.swift](https://github.com/groue/GRDB.swift) with SQLite WAL and FTS5 full-text search extensions.
- **Core Library**: `MedhaKit` (modularized Swift package containing data models, migrations, FSRS engine, force simulation, and UI components).
- **Test Suite**: 27 comprehensive integration test suites in `MedhaTestRunner`.

---

## 🚀 Building & Running

### Requirements
- macOS 14.0 or later
- Xcode 15+ / Swift 5.9+

### Quick Start
```bash
# Build the project
swift build

# Run Medha
swift run Medha

# Run test suites
swift run MedhaTestRunner
```

### Pre-built Application
A pre-compiled macOS release app bundle is available at `Medha.app`.

---

## 📄 License
MIT License.
