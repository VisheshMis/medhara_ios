# Medha Web — Local-First Knowledge & Spaced Repetition

A zero-build, zero-dependency, local-first web port of **Medha**, built with modern native ES Modules, HTML5, CSS3, and IndexedDB.

Runs directly in any browser without needing `npm`, `node_modules`, or build toolchains.

---

## 🌟 Key Features

1. **Hierarchical Block Editor**
   - 740px typographic measure mirroring native Medha macOS.
   - Dynamic block types: Headings (H1/H2/H3), Paragraphs, Bullets, Checklists, Callouts, and Code.
   - Full keyboard navigation: `Enter` to spawn next block, `Backspace` to delete empty block and return to previous.

2. **FSRS-4.5 Spaced Repetition Engine**
   - Anki-compatible Free Spaced Repetition Scheduler (`fsrs.js`).
   - Dynamic interval predictions: `Again (1)`, `Hard (2)`, `Good (3)`, `Easy (4)`.
   - Realistic retrievability decay: \( R(t) = (1 + 19 \cdot t / S)^{-0.5} \).
   - 3D perspective flip card stage with keyboard bindings (`Space` to flip, `1-4` to rate).

3. **Hybrid Free Study Grounding**
   - Direct browser fetchers with CORS support:
     - 🌐 **Wikipedia**: Extracts clean encyclopedic summaries.
     - 📚 **OpenAlex**: Scientific paper abstracts and peer-reviewed works (with automatic **CrossRef** fallback for resilient uptime).
     - 🧬 **Europe PMC**: Biomedical open-access research abstracts and findings.
     - 📖 **Wiktionary**: Rigorous etymological and lexical definitions.
   - Quick domain presets: `All`, `STEM`, `BioMed`, or `None`.

4. **Socratic AI & DeepSeek-R1 `<think>` Sanitization**
   - Multi-provider support: Local Ollama / LM Studio (`http://127.0.0.1:11434`), Google Gemini, and OpenAI.
   - Robust reasoning tag sanitization (`<think>...</think>` regex stripping + JSON bracket extraction).
   - Parameter-aware context budgeting: small models (1.5B/3B) receive condensed study snippets (~400 chars) to prevent prompt overflow.
   - User approval modal for generated downward hierarchies before committing to the local vault.

5. **2D Force-Directed Knowledge Graph**
   - Interactive HTML5 Canvas physics engine.
   - Visualizes document hierarchies, active notes, and interconnected nodes.
   - Drag to pan, scroll to zoom, click any node to navigate immediately to that note.

6. **Local-First IndexedDB Persistence**
   - All documents, blocks, flashcard review states, and configuration are persisted locally inside the browser's IndexedDB (`MedhaWebDB`).
   - Automatically pre-seeded on first run with demo notes and flashcards.

---

## 🚀 Running Locally

Because this uses Native ES Modules (`type="module"`), it must be served over HTTP (browsers restrict module loading from raw `file://` URIs).

You can use the built-in Python web server on macOS:

```bash
cd web
python3 -m http.server 8080
```

Then open your browser at:
👉 **[http://localhost:8080](http://localhost:8080)**

---

## 🚢 Deploying to GitHub Pages

1. In your GitHub repository:
   - Go to **Settings** > **Pages**.
   - Under **Build and deployment**:
     - Source: **Deploy from a branch**
     - Branch: `main`
     - Folder: `/` (or configure `/web` with GitHub Actions).
2. If deploying the entire repository, your web port will be accessible at:
   `https://<your-username>.github.io/<repo-name>/web/`
