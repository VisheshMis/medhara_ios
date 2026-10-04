# Medhara Handwritten (Ink) Notes — Specification & Decisions Log

**Date:** 2026-10-04  
**Status:** Approved / In Progress  
**Authors:** Antigravity & Engineering Team  

---

## 1. Principles & Portability Mandate

1. **Portability First:** The core data model, stroke geometry, stroke smoothing, and business logic are written in pure platform-neutral Swift. No Apple-only frameworks (e.g. `PencilKit`, `PKDrawing`) may leak into storage models or serialization. When porting to Android and Windows, the core models and math port 1:1, requiring only a platform view/renderer adapter (Skia/Android Canvas on Android, Direct2D/WinUI on Windows).
2. **True Vector Fidelity:** Strokes are stored as vector data (`[x, y, pressure, timeOffset]`, tool, color, base width), never as flattened raster images. Notes remain crisp at all zoom levels, editable, scalable, and exportable.
3. **Hierarchy Integration:** Ink notes live inside the existing Medhara note hierarchy alongside text notes. They support rename, move, delete, nesting, and breadcrumbs.
4. **Pen Feel & Zero Latency:** Live strokes draw at 60–120fps with sub-8ms latency using a two-layer rendering approach. Autosave is debounced and non-blocking to prevent frame stutter.
5. **Codebase Fit:** Fits Medhara's architecture (`GRDB`, SQLite, `@MainActor BlockStore`, SwiftUI / AppKit split).

---

## 2. Complete Decisions Log

1. **Vision & Scope (v1):** Primary use cases are study notes, math derivations, conceptual diagrams, and meeting scribbles. Vector freehand drawing + basic sketches. Shape snapping, floating text boxes, and PDF markup are cleanly deferred to v2+.
2. **Input Devices:** Supported on macOS right now: Trackpad & Mouse (velocity-simulated dynamic pressure) + USB/Bluetooth graphic tablets (Wacom/Huion via standard `NSEvent` tablet pressure & tilt) + iPad Sidecar/Universal Control. Input events are abstracted so touchscreen/stylus on Android/Windows will connect directly.
3. **Canvas Model:** Vertical continuous paged canvas (standard page width e.g., A4/US Letter aspect ratio, vertical scrolling with auto-added pages as drawing extends downward) with 4 background templates: Blank, Lined/Ruled, Grid, and Dot Grid. Clean export to standard multi-page PDF.
4. **Ink Engine Architecture:** Custom platform-neutral Vector Stroke Engine (pure Swift geometry: Catmull-Rom spline smoothing, variable-width polygon outline generation). Rendered via Core Graphics/Metal/SwiftUI Canvas on macOS; 100% portable to Android Canvas/Skia and Windows Direct2D.
5. **Stroke Data Format:** Normalized JSON payload per page with `schemaVersion: 1`, storing strokes with `[x, y, pressure, timeOffset]`, tool type, color hex, and base width. Cleanly versioned, easily parsed, and cross-platform.
6. **Tool Suite & Undo:** Ballpoint Pen (pressure-sensitive), Fountain/Calligraphy Pen (velocity/angle width), Highlighter (semi-transparent multiply blend mode rendered behind ink), Stroke Eraser (deletes entire stroke on collision), and Lasso Selection (select, move, delete strokes). 50-step undo/redo depth.
7. **Mixed Content Strategy:** Clean separation for v1: an Ink Note is a dedicated full-canvas document mode with a title and vector pages. Mixing typed text or embedding ink canvases inside text documents is deferred to v2.
8. **Hierarchy Integration:** First-class sibling note type (`BlockType.inkDoc`). Can reside anywhere in the document tree (root note, child of text note, parent of other notes) with a dedicated pen icon (`pencil.tip`) in the sidebar.
9. **Storage & Autosave:** Dedicated SQLite table `ink_document_page` (keyed by `docId` and `pageIndex`). 500ms debounced autosave on stroke completion + in-memory dirty buffer for zero data loss on unexpected termination.
10. **Search & OCR:** Excluded from v1. Notes are indexed and searched by title; OCR handwriting-to-text is planned for a dedicated future phase.
11. **AI Pipeline:** Ink notes are excluded from the Auto-Generate Note Pipeline until handwriting OCR is available.
12. **Performance & Rendering:** Two-layer render architecture: (1) active live-stroke layer (sub-8ms latency, 120fps direct draw) + (2) off-screen static page bitmap cache (re-rasterized only on stroke commit/erase/zoom change). Viewport culling for off-screen pages. Target: smooth handling of 10,000+ strokes per note.
13. **UX Controls & Dark Mode:** Floating top/dock canvas toolbar with tool selectors, 5 color presets + color picker, 1–24px stroke width slider, page template selector, zoom controls (50%–200%), and keyboard shortcuts (`P`, `H`, `E`, `L`, `Cmd+Z`, `Cmd+Shift+Z`). Full dark mode support.
14. **Export & Import:** Vector paginated PDF export (printable, vector-sharp) and high-res PNG export. Native `.medharaink` JSON bundle export/import.
15. **Testing & Quality Assurance:** Automated geometry/spline tests, serialization round-trip tests, 5,000-stroke synthetic performance stress tests in `MedhaTestRunner`, plus manual tablet/pen feel verification.
16. **Portability Assurance:** Pure platform-neutral data structs (`InkStroke`, `InkPoint`, `InkPage`, `InkTool`) in core `MedhaKit`, separated from AppKit/macOS rendering view components.

---

## 3. Data Schema & Serialization

### 3.1 SQLite Migration (`v8_ink_notes`)

```sql
CREATE TABLE ink_document_page (
    id TEXT PRIMARY KEY,               -- e.g. "inkpage-\(docId)-\(pageIndex)"
    docId TEXT NOT NULL,              -- References block(id)
    pageIndex INTEGER NOT NULL,       -- 0-indexed page number
    templateType TEXT NOT NULL,       -- "blank", "lined", "grid", "dotGrid"
    strokesData TEXT NOT NULL,        -- JSON serialized array of InkStroke
    textProjection TEXT,              -- Reserved for future OCR
    createdAt DATETIME NOT NULL,
    updatedAt DATETIME NOT NULL
);

CREATE INDEX idx_ink_page_docId ON ink_document_page(docId);
CREATE INDEX idx_ink_page_doc_idx ON ink_document_page(docId, pageIndex);
```

### 3.2 Vector Stroke JSON Schema (`schemaVersion: 1`)

```json
{
  "schemaVersion": 1,
  "pageWidth": 794.0,
  "pageHeight": 1123.0,
  "strokes": [
    {
      "id": "s-uuid",
      "tool": "ballpoint",
      "colorHex": "#1E293B",
      "baseWidth": 2.5,
      "opacity": 1.0,
      "points": [
        {"x": 120.5, "y": 240.2, "p": 0.52, "t": 0.0},
        {"x": 121.2, "y": 242.0, "p": 0.60, "t": 0.016}
      ]
    }
  ]
}
```

---

## 4. Architecture Diagram

```
+--------------------------------------------------------------------------+
|                              MedhaApp / UI Layer                         |
|  - DocumentTreeView (shows .inkDoc with pencil icon)                     |
|  - BlockEditorView (switches to InkNoteEditorView when doc.type == .inkDoc)|
|  - InkNoteEditorView (Floating Toolbar, Zoom, Template Picker, Export)   |
+--------------------------------------------------------------------------+
                                     |
                                     v
+--------------------------------------------------------------------------+
|                  Platform Adapter (macOS: AppKit / SwiftUI)              |
|  - InkCanvasView (NSViewRepresentable / Native AppKit NSView)            |
|    * NSEvent tabletPoint & mouseDragged processing (pressure/tilt/velocity)|
|    * Live Stroke Display Layer (120fps direct CoreGraphics / Metal)      |
|    * Static Page Bitmap Cache Layer (Viewport culled)                    |
|  [Android: SurfaceView / Compose Canvas | Windows: WinUI Canvas] (Future)|
+--------------------------------------------------------------------------+
                                     |
                                     v
+--------------------------------------------------------------------------+
|                  Core Vector Engine (Pure Platform-Neutral Swift)         |
|  - InkSpline: Catmull-Rom smoothing & Ramer-Douglas-Peucker simplification |
|  - InkOutline: Variable-width outline generator (pressure + velocity)     |
|  - InkGeometry: Bounding boxes, stroke collision detection (eraser/lasso)  |
|  - InkRendererContext: Abstract canvas drawing commands (DrawPath, Clear) |
+--------------------------------------------------------------------------+
                                     |
                                     v
+--------------------------------------------------------------------------+
|                      State & Persistence Layer (GRDB)                    |
|  - InkStore / BlockStore: Manages active ink document, pages, undo/redo  |
|  - Models: InkDocumentPage, InkStroke, InkPoint, InkTool                 |
|  - SQLite Table: ink_document_page (docId, pageIndex, strokesData, etc.) |
+--------------------------------------------------------------------------+
```

---

## 5. Phased Implementation Plan

- **Phase 1: Model & Hierarchy Integration**
  - Add `BlockType.inkDoc` to `Block.swift`.
  - Create database migration `v8_ink_notes` for `ink_document_page`.
  - Extend `BlockStore` to create, rename, duplicate, and delete ink notes.
  - Route `BlockEditorView` to present ink note UI when `doc.type == .inkDoc`.
  - *Acceptance:* Create an ink note in sidebar, verify pen icon, persistence in SQLite, and reload on app restart.

- **Phase 2: Core Platform-Neutral Vector Ink Engine & Geometry**
  - Pure Swift models: `InkPoint`, `InkStroke`, `InkPage`, `InkTool`.
  - Spline smoothing (Catmull-Rom) and variable-width polygon outline math.
  - Velocity-based dynamic pressure calculation for mouse/trackpad.
  - Automated unit tests in `MedhaTestRunner` for geometry, outlines, and JSON round-tripping.
  - *Acceptance:* All mathematical tests pass; verified zero platform leaks in core models.

- **Phase 3: High-Performance Canvas Rendering & Live Drawing View**
  - `InkCanvasNSView` for low-latency AppKit drawing and tablet events.
  - Two-layer render architecture (live-stroke overlay + static page bitmap cache).
  - Connect drawing strokes to SQLite load/save cycle.
  - *Acceptance:* Drawing produces smooth strokes at 60–120fps, persists across app reloads.

- **Phase 4: Tool Suite, Eraser, Undo/Redo & Floating Toolbar**
  - Implement Ballpoint, Fountain, Highlighter (multiply blend), Stroke Eraser, and Lasso.
  - 50-action undo/redo stack.
  - Floating canvas toolbar (tools, colors, thickness slider, shortcuts `P`, `H`, `E`, `Cmd+Z`).
  - *Acceptance:* Tool switching works; eraser removes strokes on touch; undo/redo behaves accurately.

- **Phase 5: Continuous Paged Canvas, Templates & Zoom/Pan**
  - Vertical continuous page flow (auto-appends new page as content expands).
  - Background templates: Blank, Lined, Grid, Dot Grid.
  - Zoom (50%–200%) and smooth panning with viewport culling.
  - *Acceptance:* Multi-page scrolling is fluid; template toggle renders cleanly; zoom does not blur strokes.

- **Phase 6: Autosave, Export (Vector PDF & PNG) & Polishing**
  - 500ms debounced background autosave with dirty buffer safety.
  - Paginated vector PDF export and high-res PNG export.
  - `.medharaink` bundle export and import.
  - Dark mode contrast and styling support.
  - 5,000-stroke synthetic benchmark in `MedhaTestRunner`.
  - *Acceptance:* Exported vector PDF is sharp and printable; performance benchmark verifies <8ms frame times and <100MB memory.
