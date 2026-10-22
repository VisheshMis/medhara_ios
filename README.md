<div align="center">
  <h1>Medha (मेधा)</h1>
  <p><strong>Notes, handwriting, and spaced repetition in one native workspace.</strong></p>
  <p>A fast desktop app unifying structured block notes, continuous vector ink, and modern FSRS-4.5 flashcards.</p>

  <p>
    <a href="https://github.com/VisheshMis/medhara_ios/releases/latest/download/Medha-macOS.dmg"><img src="https://img.shields.io/badge/Download-macOS%20(.dmg)-000000?style=for-the-badge&logo=apple&logoColor=white" alt="Download macOS" /></a>
    <a href="https://github.com/VisheshMis/medhara_ios/releases/latest/download/Medha-Setup.exe"><img src="https://img.shields.io/badge/Download-Windows%20(.exe)-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Download Windows" /></a>
    <a href="https://visheshmis.github.io/medhara_ios/"><img src="https://img.shields.io/badge/Website-GitHub%20Pages-8B5CF6?style=for-the-badge" alt="Website" /></a>
    <a href="web/"><img src="https://img.shields.io/badge/Web%20Companion-Launch-06B6D4?style=for-the-badge" alt="Web Companion" /></a>
  </p>

  <p>
    <img src="https://img.shields.io/badge/Platform-macOS%2014%2B%20%7C%20Windows%2010%2B-blue?style=flat-square&logo=apple" alt="Platforms" />
    <img src="https://img.shields.io/badge/SRS-FSRS--4.5-22C55E?style=flat-square" alt="FSRS-4.5" />
    <img src="https://img.shields.io/badge/Swift-5.9%2B-F05138?style=flat-square&logo=swift" alt="Swift" />
    <img src="https://img.shields.io/badge/Storage-SQLite%20WAL-003B57?style=flat-square&logo=sqlite" alt="SQLite" />
    <img src="https://img.shields.io/badge/Tests-37%20Passing-brightgreen?style=flat-square" alt="Tests" />
    <img src="https://img.shields.io/badge/License-MIT-gray.svg?style=flat-square" alt="License" />
  </p>
</div>

---

## What is Medha?

Most students juggle three separate tools to study:
- **Notion or Obsidian** for typing structured notes.
- **Goodnotes** for sketching diagrams and handwriting.
- **Anki** for memorizing flashcards.

Copy-pasting between three different apps creates friction, and notes usually end up forgotten in a folder.

**Medha connects all three inside a single native app:**
1. **Block Notes**: Clean reading column, instant search, and bidirectional links.
2. **Vector Ink**: Smooth digital paper with Apple Pencil / stylus support and lasso selection.
3. **FSRS-4.5 Spaced Repetition**: Modern memory scheduling that cuts review time by 20–30% compared to Anki's 1987 SM-2 algorithm.
4. **Memory Palace (Method of Loci)**: 2D spatial canvas to anchor concepts to visual landmarks.
5. **AI Synthesis & Academic Grounding**: Generate note summaries and cards connected to cloud APIs (OpenAI, Gemini, Groq) and open academic sources (PubMed, arXiv, Wikipedia).

---

## Quick Comparison

| Feature | Medha | Anki | Notion | Goodnotes 6 |
| :--- | :---: | :---: | :---: | :---: |
| **Spaced Repetition** | **Native FSRS-4.5** | SM-2 (1987) | None | None |
| **Block Notes & Links** | **Yes (`[[WikiLinks]]`)** | Primitive | Yes | None |
| **Vector Handwriting** | **Yes (Spline canvas)** | None | None | Yes |
| **Memory Palace (Loci)** | **Yes (2D Walk Mode)** | None | None | None |
| **GPU Knowledge Graph** | **Yes (Metal / 0% idle CPU)** | None | None | None |
| **Anki Deck (.anki2/.anki21) Import** | **Built-in** | Native | None | None |
| **Memory Footprint** | **&lt;50 MB RAM** | ~120 MB | ~1,200 MB | ~350 MB |
| **Cold Start** | **~120 ms** | ~400 ms | ~3,500 ms | ~1,000 ms |
| **License** | **MIT Open Source** | AGPL (Paid iOS) | Subscription | Subscription |

---

## Core Features

### 1. Hierarchical Block Notes
- Centered 740pt reading column with distraction-free typography.
- Headings (H1–H3), lists, to-dos, callouts, and block transclusion (`((embed))`).
- Fast SQLite FTS5 full-text search with BM25 ranking across thousands of notes.
- Export to Markdown or JSON anytime.

### 2. Continuous Vector Ink
- Multi-page infinite canvas with Catmull-Rom cubic spline smoothing.
- Pressure and velocity-sensitive stroke width.
- Freehand lasso selection (translate, resize, re-order strokes).
- Lossless vector storage and SVG export.
- Grid, lined, dot-matrix, and blank paper templates.

### 3. FSRS-4.5 Spaced Repetition & 3D Flashcards
- Replaces legacy SM-2 with FSRS-4.5 (Difficulty, Stability, Retrievability modeling).
- Tactile 3D card flip with real-time interval previews (`Again`, `Hard`, `Good`, `Easy`).
- Directly imports `.anki2` and zstd-compressed `.anki21` decks with zero extra tools.
- Daily retention streaks and review stats.

### 4. 2D Memory Palace (Method of Loci)
- Import photos of rooms, buildings, or campuses into a pannable 2D canvas.
- Place numbered loci pins on landmarks to build visual memory journeys.
- Walk mode with smooth spring camera framing and review card prompts at each stop.

### 5. Metal GPU Knowledge Graph
- Force-directed associative graph rendered via Metal GPU at 60–120 FPS.
- Alpha physics cooling decays to rest (`alpha < 0.002`), consuming 0.0% CPU when idle.
- Filter by links, folder hierarchy, or blended views.

### 6. AI Study Assistant & Cloud API Integration
- Connect your own API keys (OpenAI, Google Gemini, Groq) with per-provider isolation.
- Synthesize topic skeletons, generate flashcard suggestions, and cross-reference open academic sources (PubMed, arXiv, Wikipedia, CrossRef).
- Cleans reasoning tags (`<think>`) from deep-thinking models automatically.

---

## Performance

Built in native Swift 5.9 with AppKit and GRDB.swift SQLite:

- **RAM Footprint**: ~48 MB at rest (Notion runs at ~1,200 MB; Obsidian at ~850 MB).
- **Cold Launch**: Under 120 ms.
- **Search Latency**: &lt;2 ms across 10,000+ blocks via SQLite FTS5.
- **Battery Impact**: Graph physics halts at rest for 0% CPU consumption.

---

## Keyboard Shortcuts

| Shortcut | Action | Scope |
| :--- | :--- | :--- |
| `⌘ N` | New Note | Global |
| `⇧ ⌘ N` | New Notebook | Global |
| `⌘ K` | Quick Search / Command Palette | Global |
| `⌘ G` | Knowledge Graph | Global |
| `⌘ I` | Document Inspector & Backlinks | Global |
| `⌘ E` | Export Note (Markdown/JSON) | Editor |
| `/` | Slash Command Menu | Editor |
| `[[` | Insert WikiLink | Editor |
| `Space` | Flip Card / Next Locus | Flashcards & Palace |
| `1, 2, 3, 4` | Rate Card (`Again`, `Hard`, `Good`, `Easy`) | Flashcards |
| `← / →` | Previous / Next Locus | Memory Palace |

---

## Getting Started

### Pre-Compiled Downloads
- **macOS**: [Download `Medha-macOS.dmg`](https://github.com/VisheshMis/medhara_ios/releases/latest/download/Medha-macOS.dmg) (Apple Silicon & Intel)
- **Windows**: [Download `Medha-Setup.exe`](https://github.com/VisheshMis/medhara_ios/releases/latest/download/Medha-Setup.exe)
- **Web**: Run the browser companion directly in [`web/`](web/) or on the [Live Website](https://visheshmis.github.io/medhara_ios/).

### Build from Source (macOS)
```bash
# Clone the repository
git clone https://github.com/VisheshMis/medhara_ios.git
cd medhara_ios

# Build release binary
swift build -c release

# Run
swift run -c release Medha
```

### Running Tests
Medha includes 37 automated integration test suites testing SQLite storage invariants, FSRS math, and vector geometry:
```bash
swift run MedhaTestRunner
```

---

## Roadmap

- [x] Native Block PKM & `[[WikiLinks]]`
- [x] FSRS-4.5 Scheduler & 3D Flip Review
- [x] Continuous Vector Ink with Catmull-Rom Splines
- [x] 2D Memory Palace Walk Mode
- [x] Anki `.apkg` Importer (`.anki2` and `.anki21` zstd)
- [ ] Lecture Slide & PDF Ingestion (`PDFKit`)
- [ ] Native Image Occlusion for diagram study
- [ ] Exam Cram / Filtered Decks
- [ ] Cloud sync & mobile companion

---

## Community & Contributing

Contributions, issues, and discussions are welcome!
- Open an issue or join [GitHub Discussions](https://github.com/VisheshMis/medhara_ios/discussions).
- Feedback & contact: `vishesh@medha.app`

---

## License

Distributed under the **MIT License**. See `LICENSE` for details.
