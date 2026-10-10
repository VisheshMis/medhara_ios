# Medhara Canvas Enhancement Plan — 5 Phases

> **Scope:** Close the gap between the current Medhara canvas and GoodNotes-class tools: reliable shape snapping, free object manipulation, a cleaner linking UI, layers, and a richer tool palette.
> **Baseline:** `CANVAS_AND_FLOWCHART_SYSTEM_GUIDE.md` (Swift 6, SwiftUI/AppKit, CoreGraphics, GRDB, schema `v17_unified_infinite_canvas`, test Suite 48).

---

## 0. Problem Statement

### Current limitations (observed)

| # | Limitation | Likely area of the codebase |
| :-- | :--- | :--- |
| L1 | Rough hand-drawn shapes don't snap reliably to perfect forms; they often default to circles. | Ink-to-shape recognition (pen/lasso pipeline, `InkStroke` post-processing) |
| L2 | The linking feature shows an awkward page thumbnail pinned to the bottom of the canvas (screenshot: the "PDF Page 2" card sits at the viewport's bottom edge, clipped by the bottom bar). | Linked/embedded page card and its overlay placement in `InkCanvasViewportNSView` |
| L3 | Newly created shapes are anchored to the center and can't be repositioned. | Shape insertion (center placement) and select/drag hit-testing for `CanvasItem` |

### Additional observations from the screenshot

- The floating toolbar sits at the **top** of the canvas, while the guide describes a **bottom-center** capsule. The guide should be reconciled with the real UI (Phase 5).
- A newly created ellipse shows selection handles but its label text is nearly invisible (white-on-light-blue). Default text contrast needs a fix (Phase 3).
- Strokes in the screenshot are plain ink lines, so ink-to-shape is currently a separate action from drawing, with no visible toggle.

### Assumptions

These are inferred from the guide and screenshot, not from reading the source. Each phase starts with a short **discovery task** to confirm them.

- `CanvasItem` already has `x, y, width, height, rotationDegrees, zIndex`, so move, resize, rotate and ordering need UI and interaction work rather than a new data model.
- Connector routing (`CanvasRoutingService`) already supports orthogonal and curved paths, arrowheads and labels. Missing pieces are style options (dash) and a better creation UX.
- Layer lock/hide and grouping need new columns (a `v18` migration).

---

## Roadmap at a Glance

| Phase | Theme | Fixes | Key deliverables | Est. effort |
| :-- | :--- | :--- | :--- | :--- |
| **1** | Foundations: Select, Move & Place | L3 | Reliable select/drag, click-to-place, unified command-based undo/redo, visible text contrast | ~1 week |
| **2** | Smart Shape Recognition & Snapping | L1 | Hold-to-snap recognizer, rectangle/ellipse/triangle/polygon/line/diamond, snap toggle, grid + alignment snapping | ~2 weeks |
| **3** | Object Manipulation | — | 8 resize handles, rotation handle, multi-select, grouping, align/distribute, duplicate/nudge | ~1.5 weeks |
| **4** | Linking & Connector UI | L2 | Inline connector preview, link styles (solid/dashed/arrowheads), port-drag creation, note-link preview, relocated page card | ~1.5 weeks |
| **5** | Layers, Palette, Templates, Export & Polish | — | Layer panel, tool palette expansion, templates, PDF/PNG export, responsive toolbar, docs and test suite | ~2 weeks |

**Dependencies:** 1 → 2, 3 (both need a solid selection/move model) → 4 (connectors need stable shape manipulation) → 5 (layers and export sit on top of everything).

---

## Phase 1 — Foundations: Select, Move & Place

**Goal:** Make every canvas object behave like a first-class, movable object. This unblocks everything else and fixes the "stuck at center" problem (L3).

### 1.1 Discovery (first 1–2 days)
- Trace how shapes are inserted (the Shapes dropdown) and why they land at the viewport/canvas center.
- Trace the mouse-down → drag path in `InkCanvasViewportNSView` for the Select tool. Find out whether drag-to-move is missing, swallowed by another tool state, or defeated by hit-testing (fill vs. border vs. text region).
- Audit which edits flow through the 50-step undo stack and which bypass it.

### 1.2 Deliverables
1. **Drag-to-move for any `CanvasItem`** (shapes, text cards, media, note cards) with the Select tool, using the inverse viewport transform so movement is correct at any zoom.
2. **Place-where-you-point insertion:**
   - Click-to-place: choose a shape, then click the canvas to drop it at that point.
   - Click-drag-to-size: drag out the bounds directly (rubber-band creation).
   - Fallback: insert at viewport center with a small cascading offset so repeated insertions don't stack exactly.
3. **Hit-testing improvements:** filled shapes are hit anywhere inside; unfilled shapes are hit on the border with a tolerance of about 6 screen pixels (zoom-independent); topmost `zIndex` wins on overlap.
4. **Unified command-based undo/redo** for item operations: create, delete, move, resize, restyle, reorder. Each is an `UndoableCommand`; drags coalesce into a single entry on mouse-up.
5. **Contrast fix for default shape labels:** auto-pick text color from the fill's luminance.
6. **Selection feedback:** subtle accent outline (1.5 pt) on hover and a stronger one on selection, as per the UX requirements.

### 1.3 Technical notes
- Moves are applied live in memory and persisted once on mouse-up through the existing debounced (500 ms) GRDB commit. This avoids a write per mouse event.
- Connector endpoints recalculate live during a drag, since `CanvasConnector` is already derived from item ports.
- Keep the move math in a pure Swift struct so it can be unit tested without AppKit.

### 1.4 Acceptance criteria
- A shape can be dragged anywhere in all three canvas modes (A4 pages clamps to the page; infinite modes are unbounded).
- Dragging at 0.02× and at 20× moves the shape exactly with the cursor.
- A whole drag is undone with one `Cmd+Z` and redone with `Cmd+Shift+Z`.
- Connected wires follow the shape during the drag, with no flicker.

### 1.5 Tests (new suite, e.g. Suite 49)
Move math under zoom/pan, hit-test priority, undo/redo coalescing, persistence round-trip after a move.

---

## Phase 2 — Smart Shape Recognition & Snapping

**Goal:** Replace "everything becomes a circle" with a robust recognizer, add a clear toggle, and make perfect shapes snap in a controlled way (L1).

### 2.1 Discovery
- Locate the current recognition path and find why it falls back to a circle (probably a missing or too-permissive classifier, or a threshold that always accepts the ellipse fit).
- Collect a **fixture set** of 40–60 sample strokes (recorded from the real app: rough rectangles, circles, triangles, diamonds, lines, arrows, non-shapes such as handwriting). This becomes the regression corpus.

### 2.2 Recognition pipeline

```
raw InkStroke points
   → resample (uniform spacing, ~64 pts)
   → closedness test (endpoint gap vs. path length)
   → simplify (Ramer–Douglas–Peucker) → corner candidates
   → fit candidates: line · ellipse · rectangle · triangle · diamond · n-gon
   → score each fit (normalized residual) → pick best above a confidence threshold
   → else: leave as freehand ink (never force a shape)
```

Key rules that prevent the circle-default problem:
- **Corner count is decisive:** 3 corners → triangle, 4 → quad (then rectangle vs. diamond by orientation), 5+ → polygon, 0 corners with a good ellipse fit → ellipse.
- **A minimum confidence gate:** if no fit scores well, the stroke stays as ink.
- **Open strokes** are tested for line/arrow only.
- Axis alignment: a rectangle within about 8° of the axes snaps to 0°; otherwise it keeps its angle and becomes a rotated `CanvasItem` (`rotationDegrees`).

### 2.3 Deliverables
1. **Hold-to-snap gesture:** draw a rough shape and hold the pointer still for about 0.5 s; a preview of the perfect shape appears, and releasing commits it (GoodNotes-style).
2. **Shape set:** line, ellipse/circle, rectangle, rounded rectangle, triangle, diamond, and generic polygon (regular if the fit supports it).
3. **Toggle: Freeform ↔ Snap mode,** placed next to the pen tools in the toolbar, with a keyboard shortcut. In Freeform nothing is converted. In Snap, hold-to-snap is enabled.
4. **Snap-to-grid / alignment snapping** for created and moved shapes: the grid uses the existing 20 pt template spacing; smart guides show alignment to other shapes' edges and centers with a 6 pt threshold. A modifier key (hold `Cmd`) temporarily disables snapping.
5. **Result as a real `CanvasItem`:** the recognized shape becomes an editable shape (inheriting the stroke color and width), and the original stroke is removed in the same undo step. `Cmd+Z` right after a snap restores the original ink.

### 2.4 Acceptance criteria
- On the fixture corpus: at least 90% of shapes classified correctly, with **zero** handwriting strokes converted by accident.
- Rough squares never come out as circles; polygons keep the right corner count.
- Toggle state persists across sessions.
- Undo after a snap returns the original stroke exactly.

### 2.5 Tests
Recognizer unit tests against the fixture corpus (pure geometry, no UI), threshold regression tests, snap-guide tests, undo round-trip.

### 2.6 Risks
- **False positives** on handwriting: mitigated by the confidence gate, the hold-to-snap requirement, and the explicit toggle.
- **Tuning time:** keep thresholds in one config struct so they can be adjusted without touching the algorithm.

---

## Phase 3 — Object Manipulation

**Goal:** Full-featured transform controls for single and multiple objects.

### 3.1 Deliverables
1. **Resize handles:** the existing 8 handles made fully functional, with edge-aware cursors. `Shift` locks aspect ratio, `Option` resizes from the center. Minimum size clamp (e.g. 16 pt).
2. **Rotation handle:** a handle above the top edge that writes to `rotationDegrees`. `Shift` snaps to 15° steps, with a small angle readout while rotating. Hit-testing, handles and connector ports must all respect rotation (ports rotate with the shape).
3. **Multi-select:** `Shift`-click to add/remove, marquee (drag-select) on empty canvas, `Cmd+A` to select all. A shared bounding box with group handles transforms all selected items together.
4. **Grouping:** `Cmd+G` / `Cmd+Shift+G`. Groups move, scale and rotate as one; connectors attach to the group's children.
5. **Arrange tools:** align (left/center/right/top/middle/bottom), distribute evenly, bring to front / send to back / forward / backward.
6. **Quick actions:** duplicate (`Cmd+D`), copy/paste (positions pasted items at an offset), nudge with arrow keys (1 pt, `Shift` = 10 pt), delete.
7. **Floating contextual mini-bar** above the selection with the most common actions: color, duplicate, lock, delete, link.

### 3.2 Technical notes
- Introduce a `TransformSession` that captures initial frames of all selected items and applies a single matrix delta each mouse event, so multi-item transforms don't accumulate drift.
- Rotated hit-testing: transform the pointer into the item's local space before testing.
- Group data model (new in the Phase 5 migration, or an early `v18` if needed here): nullable `groupId` on `canvas_items`.

### 3.3 Acceptance criteria
- Resize, rotate and group operations are all single undo steps.
- A rotated shape's connectors stay attached to the visually correct ports.
- Multi-select of 200 items transforms at interactive frame rates (60 FPS target).

### 3.4 Tests
Transform math (resize with aspect lock, rotation about center, group matrix), rotated hit-testing, align/distribute results, undo/redo for each operation.

---

## Phase 4 — Linking & Connector UI

**Goal:** Replace the awkward bottom thumbnail (L2) with an inline, discoverable linking experience and richer connector styles.

### 4.1 Discovery
- Identify what the bottom "PDF Page 2" card actually is: an embedded spatial PDF page item, a link preview overlay, or a docked panel. Decide for each case whether it should be a normal in-canvas item (movable like any other) or a transient popover.

### 4.2 Deliverables
1. **Embedded page cards become normal canvas items.** They live in canvas coordinates, can be moved, resized and layered, and never get pinned to the viewport's bottom edge or hidden under the bottom bar. The viewport insets account for toolbars so nothing renders under them.
2. **Inline connector preview:** while dragging from a port, show the live wire (using the selected routing type) with port highlights and the 16 pt magnetic snap ring on valid targets. A ghost preview of the arrowhead appears at the cursor.
3. **Connector creation UX:** drag from a hover handle on any shape edge; dropping on empty canvas offers a "create shape here" quick menu; clicking a wire selects it and shows a style popover.
4. **Link styles:** solid, dashed, dotted lines; arrowheads (none, arrow, open chevron, dot, diamond) per end; color, width and routing (orthogonal/curved) per connector; editable label pill (already supported, polished with better hit area).
5. **Note-link preview:** hovering the link badge shows a small popover with the note title and a snippet; a click jumps to the note (existing behavior). Link creation uses the fuzzy note picker, available from both the toolbar and the contextual mini-bar.
6. **Connectors for more item types:** allow connecting media, PDF cards and note cards, not only flowchart shapes (verify against the `itemType` support).

### 4.3 Schema changes (`v18`)
Add to `canvas_connectors`: `dashStyle TEXT NOT NULL DEFAULT 'solid'`. Extend the terminal style enum with the new head styles (stored as text, so no further column is needed). Migration must default existing rows to current behavior.

### 4.4 Acceptance criteria
- No UI element is pinned at the viewport bottom that overlaps canvas content or the bottom bar.
- A connector can be created, restyled (dash, heads, color) and relabeled without leaving the canvas.
- Existing canvases open unchanged after the migration.

### 4.5 Tests
Migration test (old rows get defaults), routing with the new styles, terminal geometry for each head type, link-preview data, connector follow-on-move for the new item types.

---

## Phase 5 — Layers, Palette, Templates, Export & Polish

**Goal:** Round out the editing experience and ship it with proper polish, documentation and tests.

### 5.1 Layer management
- **Layer panel** (side popover): list of items in z-order with type icon and name; drag to reorder, per-row **lock** and **hide** toggles, solo/dim others, rename.
- **Schema (`v18`/`v19`):** `canvas_items` gains `isLocked INTEGER NOT NULL DEFAULT 0`, `isHidden INTEGER NOT NULL DEFAULT 0`, `groupId TEXT`, `name TEXT`.
- Locked items can't be selected or moved but still render; hidden items are excluded from rendering, hit-testing and export.
- Ink strokes: decide whether they stay in a dedicated ink layer (above/below shapes) or become orderable. Recommend a **single ink layer** with an explicit "ink above/below shapes" setting first, and orderable strokes later.

### 5.2 Tool palette expansion
- Pens: ballpoint, fountain, **highlighter** (multiply blend), eraser (stroke eraser plus an optional pixel/partial eraser), lasso. Already in the engine; surface them cleanly in the palette.
- **Per-tool settings:** color, width and **opacity** remembered separately for each tool.
- **Color picker:** the 6 preset swatches, recent colors, and the macOS system picker, with an opacity slider.
- **Snap and lock controls** placed adjacent to the toolbar for quick access (snap toggle from Phase 2, lock-selection toggle from the layer system).

### 5.3 Template library
- Ship pre-designed layouts (flowchart starter, mind-map, Kanban columns, Cornell notes, weekly planner, SWOT, system-architecture skeleton).
- Stored as serializable bundles of `CanvasItem` and `CanvasConnector` records (JSON) inserted at the viewport center as a group. Users can **save selection as template**.

### 5.4 Export
- **PDF** (vector-preserving, via CoreGraphics PDF context; A4 mode exports page by page) and **PNG** (selectable scale 1×/2×/4×, transparent or filled background).
- Export scopes: whole canvas, current viewport, or selection. Hidden layers excluded.
- Fidelity test: render the same canvas to PNG at 2× and compare against a golden image with a small tolerance.

### 5.5 Responsive and consistent UI
- The toolbar collapses gracefully on narrow windows (secondary groups move into an overflow menu), and respects safe areas and the bottom bar.
- Consistent selection feedback, hover states and cursor changes across all tools.
- Accessibility: VoiceOver labels on toolbar items and layer rows, full keyboard operability for the snap/lock toggles.
- Dark-mode contrast audit of all canvas chrome and default colors.

### 5.6 Documentation and verification
- Update `CANVAS_AND_FLOWCHART_SYSTEM_GUIDE.md`: new tools, keyboard shortcuts, the schema changes, and a corrected description of the toolbar placement.
- Add the remaining test suites to `MedhaTestRunner`; run the full suite (`swift run MedhaTestRunner`) and confirm all prior suites (35–48) still pass.
- Performance pass on boards with ~2,000 items: confirm the semantic LOD tiers still hold 60 FPS with layers, groups and hidden items.

### 5.7 Acceptance criteria
- Reorder, lock, hide and group survive app restart.
- Exported PDF opens with selectable vector content; PNG matches the on-screen canvas.
- All canvas suites pass; no regression in pan/zoom performance.

---

## Cross-Cutting Concerns

| Area | Policy |
| :--- | :--- |
| **Undo/redo** | Every new operation is a command. A single gesture is a single undo step. |
| **Persistence** | Edits live in memory during a gesture, then commit through the debounced GRDB write. Each schema change is an additive, defaulted migration. |
| **Performance** | No per-mouse-event database writes; hit-testing uses a spatial index once item counts grow; respect the LOD tiers. |
| **Backward compatibility** | Existing canvases open unchanged. New columns have safe defaults. |
| **Testing** | Pure-Swift geometry (recognizer, transforms, routing) is unit tested with fixtures. Each phase adds a numbered suite to `MedhaTestRunner`. |
| **Feature flags** | Ship shape recognition behind the Snap toggle from day one, so risky behavior is always opt-in. |

## Definition of Done (per phase)

1. Discovery notes recorded (what was found, what changed vs. assumptions).
2. Features implemented and manually verified in all three canvas modes.
3. New automated tests added and passing, with all earlier suites still green.
4. Undo/redo and persistence verified for every new operation.
5. Guide updated for any user-visible change.

## Open Questions

1. Should hold-to-snap be the only recognition trigger, or also an explicit "convert to shape" action on a selected stroke or lasso selection?
2. Should grouped items keep individual connectors, or should the group expose its own ports?
3. Are ink strokes meant to be orderable in the layer panel, or is a single ink layer enough for v1?
4. Which export targets matter most first: PDF for printing, or PNG for sharing?
5. Should the toolbar stay at the top (as in the current UI) or return to the bottom-center position described in the guide?
