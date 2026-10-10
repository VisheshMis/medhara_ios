# Medhara Canvas Engine: Unified Infinite Canvas, Inking, Flowcharts & Universal Linking

> **Authoritative Technical & User Guide**  
> **Platform:** macOS Native (Swift 6, SwiftUI, AppKit, CoreGraphics, AVFoundation, PDFKit, GRDB SQLite)  
> **Verified Status:** 100% Native Architecture, Zero External Heavy Dependencies, Verified by 48/48 Test Suites

---

## 📑 Master Table of Contents

1. [Architectural Foundation & Canvas Philosophy](#1-architectural-foundation--canvas-philosophy)
2. [Canvas Operating Modes & Spatial Geometry](#2-canvas-operating-modes--spatial-geometry)
   - 2.1 Three Canvas Modes (A4 Pages, Infinite Long Sheet, Vast 2D Infinite Space)
   - 2.2 Mathematical Coordinate Space & Viewport Transformations
   - 2.3 Canvas Background Templates & Infinite Tiling
   - 2.4 High-Performance Pan, Zoom & Trackpad Physics
3. [Vector Inking Engine & Drawing Tool Suite](#3-vector-inking-engine--drawing-tool-suite)
   - 3.1 Vector Stroke Mathematical Model & JSON Representation
   - 3.2 Pen Tools: Ballpoint, Calligraphy / Fountain, Highlighter
   - 3.3 Eraser, Lasso Selection & Spatial Manipulation
   - 3.4 Catmull-Rom Spline Interpolation & Polygon Outline Smoothing
   - 3.5 Stroke Palettes, Thickness, Pressure Dynamics & 50-Step Undo/Redo
4. [Flowchart Shapes & Diagramming Engine](#4-flowchart-shapes--diagramming-engine)
   - 4.1 Flowchart Shape Primitives (Rectangle, Rounded Rect, Diamond, Ellipse, Group)
   - 4.2 Four-Cardinal Magnetic Snapping (North, East, South, West)
   - 4.3 Direct Hit-Testing, Selection Bounds & Resizing Handles
5. [Smart Dynamic Connectors & Routing Algorithms](#5-smart-dynamic-connectors--routing-algorithms)
   - 5.1 90° Manhattan Orthogonal Step Routing
   - 5.2 Smooth Cubic Bezier Splines with Outward Normal Vectors
   - 5.3 Vector Arrowheads, Endpoint Embellishments & Inline Label Pills
6. [Multi-Media Ingestion & Asset Storage Pipeline](#6-multi-media-ingestion--asset-storage-pipeline)
   - 6.1 Sandboxed Storage Architecture (`Application Support/Medha/CanvasAssets/`)
   - 6.2 Supported Media Formats (Images, Video AVPlayer, Audio Waveforms, PDFKit Pages)
   - 6.3 Drag-and-Drop Ingestion & Clipboard Pasting
7. [Universal Note Link Anchors & PKM Bi-Directional Graph Sync](#7-universal-note-link-anchors--pkm-bi-directional-graph-sync)
   - 7.1 Linking Any Canvas Item to Any Workspace Note (`linkedNoteDocId`)
   - 7.2 Visual Link Anchor Badges & Instant Jump Navigation
   - 7.3 PKM Graph Integration (`DocLink` Bi-directional Synchronization)
8. [Semantic Level-of-Detail (LOD) Zoom Rendering](#8-semantic-level-of-detail-lod-zoom-rendering)
   - 8.1 Macro Panoramic View (`zoom < 0.35`)
   - 8.2 Medium Flowchart View (`0.35 <= zoom < 1.0`)
   - 8.3 Deep Detail View (`zoom >= 1.0`)
9. [User Interface & Floating macOS Glass Toolbar](#9-user-interface--floating-macos-glass-toolbar)
   - 9.1 Translucent Frosted Glass Capsule (`CanvasUnifiedFloatingToolbar`)
   - 9.2 Tool Switching, Keyboard Shortcuts & Minimap Spatial Navigation
10. [Database Schema & GRDB Persistence Architecture](#10-database-schema--grdb-persistence-architecture)
    - 10.1 Schema Migrations (`v8_ink_notes` & `v17_unified_infinite_canvas`)
    - 10.2 Cascade Safety, Foreign Keys & Dirty State Debouncing

---

## 1. Architectural Foundation & Canvas Philosophy

Medhara’s canvas engine is engineered around four core tenets:

1. **Absolute Portability & True Vector Fidelity:**  
   Unlike systems relying on platform-locked frameworks (such as Apple’s `PencilKit`), Medhara’s canvas models, geometry calculators, and stroke pipelines are written in platform-neutral Swift. Every stroke, shape, and connection is stored as scalable vector math rather than flattened raster images, maintaining pin-sharp resolution from $0.02\times$ macro overviews up to $20.0\times$ microscopic zoom.

2. **Unified Spatial Coexistence:**  
   Handwritten vector ink, structured flowchart diagrams, multimedia assets, and relational note cards live in the exact same infinite spatial plane. Users can sketch handwritten math proofs beside imported PDF textbook pages, connect them with smart orthogonal flowchart arrows to diamond decision nodes, and anchor them directly to Markdown knowledge documents.

3. **Sub-8ms Hardware-Accelerated Rendering:**  
   The rendering architecture splits the canvas into a high-speed active gesture layer and a dirty-rect background compositor. CoreGraphics, Metal, and Quartz drawing ensure fluid 60–120 FPS trackpad gestures (pinch-to-zoom, two-finger pan, spacebar drag) without stutter.

4. **Zero-Lock-in SQLite / GRDB Persistence:**  
   All canvas entities (`canvas_items`, `canvas_connectors`, `ink_document_page`) are persisted directly into Medhara’s local SQLite database with transactional ACID guarantees, cascade deletion, and debounced autosave.

---

## 2. Canvas Operating Modes & Spatial Geometry

### 2.1 Three Canvas Modes
Medhara allows each note document to configure its spatial format via `canvasMode`:

| Canvas Mode | Storage Enum | Coordinate System | Intended Cognitive Use Case |
| :--- | :--- | :--- | :--- |
| **A4 Discrete Pages** | `.a4Pages` | Fixed width ($794\,\text{pt}$), fixed height ($1123\,\text{pt}$), stacked vertically with visible page breaks. | Formal lecture notes, homework problem sets, paginated book summaries, export to printable PDF. |
| **Infinite Long Sheet** | `.infiniteVertical` | Fixed width ($794\,\text{pt}$), dynamic unbounded vertical growth ($Y \ge 0$). | Continuous lecture scribbles, linear derivations, chronologically streaming journal entries. |
| **Vast 2D Infinite Space** | `.infinite2D` | Unbounded Cartesian plane in all four quadrants $(-\infty < X, Y < +\infty)$. | System architecture diagrams, conceptual clustering, mind-maps, multi-subject synthesis boards. |

### 2.2 Mathematical Coordinate Space & Viewport Transformations
The canvas engine maintains a strict separation between **Screen / View Coordinates** (points within the macOS `NSView`) and **Canvas Coordinates** (absolute points on the infinite plane).

#### Forward Transformation (Canvas $\to$ Screen):
$$\begin{pmatrix} X_{\text{screen}} \\ Y_{\text{screen}} \end{pmatrix} = \begin{pmatrix} (X_{\text{canvas}} \times \text{zoom}) + \text{panOffsetX} \\ (Y_{\text{canvas}} \times \text{zoom}) + \text{panOffsetY} \end{pmatrix}$$

#### Inverse Transformation (Screen $\to$ Canvas):
$$\begin{pmatrix} X_{\text{canvas}} \\ Y_{\text{canvas}} \end{pmatrix} = \begin{pmatrix} \frac{X_{\text{screen}} - \text{panOffsetX}}{\text{zoom}} \\ \frac{Y_{\text{screen}} - \text{panOffsetY}}{\text{zoom}} \end{pmatrix}$$

When the user performs a pinch-to-zoom gesture centered around a cursor position $P_{\text{screen}}$, the pan offset is dynamically compensated so that the canvas point under the cursor remains invariant:
$$\text{panOffsetX}_{\text{new}} = P_{\text{screen}.x} - \left( \frac{P_{\text{screen}.x} - \text{panOffsetX}_{\text{old}}}{\text{zoom}_{\text{old}}} \right) \times \text{zoom}_{\text{new}}$$

### 2.3 Canvas Background Templates & Infinite Tiling
All three canvas modes support 4 built-in background raster/vector templates:
- **Blank (`blank`)**: Clean, minimalist white / dark-mode background.
- **Lined / Ruled (`lined`)**: Horizontal baseline guides spaced at $28\,\text{pt}$ intervals with optional margin rule.
- **Grid (`grid`)**: Orthogonal Cartesian graph grid with $20\,\text{pt} \times 20\,\text{pt}$ cells.
- **Dot Grid (`dotGrid`)**: Architectural dot matrix with dots spaced at $20\,\text{pt}$ intervals, rendered with sub-pixel antialiasing.

In **Vast 2D Infinite Space**, the background grid automatically tiles infinitely across visible viewport bounds, rendering only the cells currently intersected by the screen viewport rect (`visibleRect`).

### 2.4 High-Performance Pan, Zoom & Trackpad Physics
- **Zoom Spectrum:** Unrestricted scaling from **$0.02\times$ (2% panoramic macro view)** up to **$20.0\times$ (2000% microscopic precision)**.
- **Gestures:**
  - **Pinch-to-Zoom**: Native macOS `magnify(with:)` event handler with cursor-anchored focus.
  - **Two-Finger Pan**: Smooth trackpad scroll gesture tracking (`scrollWheel(with:)`).
  - **Hand Tool / Spacebar Drag**: Holding `Space` or selecting the Hand Tool switches the cursor to `openHand` / `closedHand` and translates the viewport without creating strokes.
  - **Zoom Presets**: Instant shortcuts for $25\%$, $50\%$, $100\%$ (`Cmd+0`), $200\%$, **Fit Width** (`Cmd+9`), and **Fit All Content**.


---

## 3. Vector Inking Engine & Drawing Tool Suite

Medhara’s inking engine is engineered for low latency, natural tactile stylus response, and cross-platform mathematical purity.

### 3.1 Vector Stroke Mathematical Model & JSON Representation
Every handwritten mark on the canvas is represented as an `InkStroke` consisting of a sequence of timestamped, pressure-calibrated points:

```swift
public struct InkPoint: Codable, Equatable, Sendable {
    public var x: Double          // Canvas X coordinate
    public var y: Double          // Canvas Y coordinate
    public var p: Double          // Normalized pressure [0.0 ... 1.0]
    public var t: Double          // Offset time in seconds from stroke start
}

public struct InkStroke: Identifiable, Codable, Equatable, Sendable {
    public var id: String         // Unique stroke ID ("s-\(UUID())")
    public var tool: InkTool      // .ballpoint, .calligraphy, .highlighter
    public var colorHex: String   // e.g. "#1E293B", "#3B82F6", "#F59E0B"
    public var baseWidth: Double  // Base stroke width in canvas points
    public var opacity: Double    // Stroke alpha [0.0 ... 1.0]
    public var points: [InkPoint] // Array of sampled input vertices
}
```

Strokes serialize into a clean, portable JSON format stored in the `ink_document_page.strokesData` column:

```json
{
  "schemaVersion": 1,
  "pageWidth": 794.0,
  "pageHeight": 1123.0,
  "strokes": [
    {
      "id": "s-8b9a1e-45",
      "tool": "ballpoint",
      "colorHex": "#1E293B",
      "baseWidth": 2.5,
      "opacity": 1.0,
      "points": [
        {"x": 120.5, "y": 240.2, "p": 0.52, "t": 0.0},
        {"x": 121.2, "y": 242.0, "p": 0.60, "t": 0.016},
        {"x": 122.8, "y": 245.1, "p": 0.65, "t": 0.032}
      ]
    }
  ]
}
```

### 3.2 Pen Tools
Medhara features 5 primary drawing and inking tools:

| Tool | Icon Shortcut | Visual Behavior & Dynamics | Blending & Layering |
| :--- | :--- | :--- | :--- |
| **Ballpoint Pen** | `P` | Standard uniform ballpoint with subtle pressure variation ($0.8 \times$ to $1.2 \times$ base width). Ideal for quick handwritten lecture notes and mathematical equations. | `.sourceOver` normal composition |
| **Calligraphy / Fountain Pen** | `F` | Dynamic chisel-tip simulation. Stroke width varies significantly with drawing velocity and trajectory angle, producing elegant flourish and thick-thin stroke variation. | `.sourceOver` normal composition |
| **Highlighter** | `H` | Wide, semi-transparent highlighter ($12.0\,\text{pt}$ to $28.0\,\text{pt}$ base width, $0.35$ opacity). Designed for marking textbook text and lecture summaries. | **Multiply Blend Mode**: Rendered underneath dark ink strokes so text remains completely legible. |
| **Stroke Eraser** | `E` | Instant vector collision eraser. Touching any part of a stroke deletes the entire stroke atomically. | Vector elimination |
| **Lasso Selection** | `L` | Freeform polygon boundary selector. Allows encircling strokes to move, rescale, recolor, or delete them en masse. | Vector spatial clustering |

### 3.3 Dynamic Pressure & Velocity Curves
On macOS, input events arrive via trackpads, mice, and external drawing tablets (Wacom, Huion, iPad Sidecar):
- **Graphic Tablets & Apple Pencil (via Sidecar):** Reads native tablet pressure directly from `NSEvent.pressure` $[0.0, 1.0]$ and tilt angle.
- **Trackpad & Mouse Simulation:** When hardware pressure is unavailable (pressure is $0.0$), the engine computes instantaneous drawing velocity:
  $$v = \frac{\sqrt{(x_k - x_{k-1})^2 + (y_k - y_{k-1})^2}}{t_k - t_{k-1}}$$
  Dynamic pressure is synthesized inversely proportional to velocity (rapid movement yields thinner strokes, slow deliberate movement yields fuller strokes), faithfully recreating the physical tactile sensation of a real fountain pen.

### 3.4 Catmull-Rom Spline Interpolation & Polygon Outline Smoothing
Raw digitizer input samples are sparse and polygonal. Medhara transforms jagged points into fluid curves using centripetal Catmull-Rom spline interpolation:
1. For every four consecutive control points $P_0, P_1, P_2, P_3$, cubic spline segments are evaluated at uniform parametric intervals.
2. Normals are computed along the curve tangent vector to generate variable-width polygon vertex pairs:
   $$\vec{n}(t) = \left( -y'(t), x'(t) \right) / \|\vec{v}(t)\|$$
3. Rounded endcaps and bezier miter joins are generated at segment transitions to ensure zero visual cracking or gaps under high zoom magnification ($20\times$).

### 3.5 Stroke Palettes, Thickness & 50-Step Undo/Redo
- **Color Palettes:** Quick access to standard ink colors (Slate `#1E293B`, Indigo `#3B82F6`, Emerald `#10B981`, Amber `#F59E0B`, Crimson `#EF4444`, Violet `#8B5CF6`) plus full macOS system color picker.
- **Width Presets:** Fine ($1.0\,\text{pt}$), Medium ($2.5\,\text{pt}$), Thick ($5.0\,\text{pt}$), Marker ($12.0\,\text{pt}$), Broad ($24.0\,\text{pt}$).
- **Transactional Undo / Redo:** Full 50-level command stack tracking stroke additions, stroke deletions, lasso relocations, and property adjustments.
- **Autosave Safety:** Debounced 500ms background commit to SQLite ensures zero lag during active drawing and zero data loss on application close.


---

## 4. Flowchart Shapes & Diagramming Engine

Medhara’s diagramming engine elevates the canvas into a structured system architecture and thought mapping suite.

```
       +---------------+
       |   Rectangle   | (Process / Task)
       +-------+-------+
               |
               v
       +-------+-------+
      /                 \
     <      Diamond      > (Decision / Condition)
      \                 /
       +-------+-------+
               |
               v
       (    Ellipse    ) (Terminal / State)
```

### 4.1 Flowchart Shape Primitives
All flowchart shapes are modeled as `CanvasItem` records with `itemType == .shape` and a concrete `shapeType`:

| Shape Type | Enum Case | Standard Semantic Meaning | Vector Path Geometry |
| :--- | :--- | :--- | :--- |
| **Rectangle** | `.rectangle` | Process, task step, system module, or component block. | Sharp 90° vector polygon (`CGPath.addRect`). |
| **Rounded Rectangle** | `.roundedRectangle` | Event, sub-process, or soft component card. | Rounded rectangular path with configurable `cornerRadius` (`12.0\,\text{pt}` default). |
| **Diamond** | `.diamond` | Decision branch, boolean conditional check, or filter node. | Symmetric rhomboid connecting $(x + w/2, y)$, $(x + w, y + h/2)$, $(x + w/2, y + h)$, and $(x, y + h/2)$. |
| **Ellipse / Circle** | `.ellipse` | Start/end terminal states, entry points, or state machine nodes. | Bounded ellipse (`CGPath.addEllipse(in:)`). |
| **Container Group** | `.containerGroup` | Visual clustering bounding box grouping related nodes into subsystems or swimlanes. | Dashed border outline with tinted background wash. |

### 4.2 Four-Cardinal Magnetic Snapping
Every shape dynamically exposes **4 Cardinal Magnetic Anchor Ports**:
- **North (Top):** $\left( x + \frac{w}{2}, y \right)$ with outward normal $(0, -1)$
- **East (Right):** $\left( x + w, y + \frac{h}{2} \right)$ with outward normal $(1, 0)$
- **South (Bottom):** $\left( x + \frac{w}{2}, y + h \right)$ with outward normal $(0, 1)$
- **West (Left):** $\left( x, y + \frac{h}{2} \right)$ with outward normal $(-1, 0)$

When creating or dragging a connector wire, cursor proximity within a **$16\,\text{pt}$ magnetic snap radius** automatically pulls the connection endpoint to the exact cardinal anchor and highlights the port with a glowing magnetic ring.

### 4.3 Direct Hit-Testing, Selection Bounds & Resizing Handles
- **Hit-Testing:** Point-in-polygon and path distance calculation accurately detects clicks on shape fills, borders, or text areas.
- **Selection Visuals:** Selected shapes display an accented macOS selection border with 8 cardinal and diagonal resize handles (NW, N, NE, E, SE, S, SW, W).
- **Z-Index Layering:** Canvas items support full depth ordering (`zIndex: Int`) with one-click **Bring to Front** and **Send to Back** commands.

---

## 5. Smart Dynamic Connectors & Routing Algorithms

Connectors are modeled via `CanvasConnector` and dynamically recalculate their vector paths as shapes are moved or resized.

```swift
public struct CanvasConnector: Identifiable, Codable, FetchableRecord, PersistableRecord, Equatable, Sendable {
    public var id: String                   // "conn-\(UUID())"
    public var canvasDocId: String          // Parent canvas document
    public var sourceItemId: String         // Source CanvasItem ID
    public var targetItemId: String         // Target CanvasItem ID
    public var sourceCardinal: CardinalDirection // .north, .east, .south, .west
    public var targetCardinal: CardinalDirection // .north, .east, .south, .west
    public var routingType: ConnectorRoutingType // .orthogonal, .curved
    public var startStyle: ConnectorTerminalStyle // .none, .arrow, .dot
    public var endStyle: ConnectorTerminalStyle   // .arrow
    public var strokeColorHex: String       // e.g. "#64748B"
    public var strokeWidth: Double          // e.g. 2.0
    public var labelText: String?           // Inline label pill (e.g. "Yes", "No")
}
```

### 5.1 90° Manhattan Orthogonal Step Routing
Implemented in `CanvasRoutingService.computeOrthogonalPath(from:fromCardinal:to:toCardinal:)`:
1. **Exit & Entry Stubs:** The wire extends perpendicularly outward from the source port by a minimum offset ($24\,\text{pt}$) along the source cardinal normal vector.
2. **Intermediate Manhattan Steps:**
   - If the source and target are directly opposite, a single midpoint step ($Z$-bend) is generated.
   - If the ports are at right angles or face obstacles, a two-bend step ($S$-bend) is calculated to guarantee clean 90-degree corners with zero acute angles.
3. **Corner Rounding:** Corners feature subtle $6\,\text{pt}$ fillets (`addArc(tangent1End:tangent2End:radius:)`) for modern architectural diagramming aesthetics.

```
       [Source Shape]
             | (stub)
             +--------+
                      | (Manhattan Step)
                      +--------> [Target Shape]
```

### 5.2 Smooth Cubic Bezier Splines
Implemented in `CanvasRoutingService.computeCurvedPath(from:fromCardinal:to:toCardinal:)`:
- Computes outward tangent control points $C_1$ and $C_2$ based on distance and cardinal normals:
  $$C_1 = P_{\text{start}} + \vec{n}_{\text{source}} \times \max\left( 40, \frac{\|P_{\text{target}} - P_{\text{start}}\|}{2.5} \right)$$
  $$C_2 = P_{\text{end}} + \vec{n}_{\text{target}} \times \max\left( 40, \frac{\|P_{\text{target}} - P_{\text{start}}\|}{2.5} \right)$$
- Evaluates the cubic Bezier curve:
  $$B(t) = (1-t)^3 P_{\text{start}} + 3(1-t)^2 t C_1 + 3(1-t) t^2 C_2 + t^3 P_{\text{end}}$$
- Produces organic, non-intersecting curved arrows ideal for conceptual mind-maps and knowledge webs.

### 5.3 Vector Arrowheads & Inline Label Pills
- **Arrowhead Terminals:** Vector polygons calculated from the tangent angle at the terminal end ($t = 1.0$). Supports solid triangular arrowheads, hollow chevrons, and circular dots.
- **Inline Editable Label Pills:** Centered along the connector path’s midpoint:
  - Renders a semi-transparent frosted background capsule pill.
  - Displays user-defined semantic labels (e.g., `"Yes"`, `"No"`, `"True"`, `"False"`, `"Next"`).
  - Double-clicking the pill triggers inline text editing.

---

## 6. Multi-Media Ingestion & Asset Storage Pipeline

Medha allows embedding rich media assets directly into the infinite spatial plane via `CanvasAssetStorage`.

### 6.1 Sandboxed Local Storage Architecture
- **Directory Path:** `~/Library/Application Support/Medha/CanvasAssets/`
- **File Integrity:** Imported assets are copied locally, assigned deterministic UUID keys (`asset-{UUID}.{ext}`), and referenced safely in `CanvasItem.mediaAssetKey`.
- **Memory Safety:** In-memory `NSCache` handles decoded raster images to prevent RAM ballooning during rapid pan/zoom navigation.

### 6.2 Supported Media Formats
1. **Images (PNG, JPEG, HEIC, WebP, GIF):**
   - Direct CoreGraphics rasterization with high-DPI Retina support.
   - Preserves native aspect ratio while providing corner resize handles.
2. **Videos (MP4, MOV):**
   - Automatically generates a high-resolution poster frame thumbnail using `AVAssetImageGenerator` during ingestion.
   - Extracts duration metadata and displays video timestamp badges.
   - Embedded lightweight playback on user interaction.
3. **Audio (MP3, M4A, WAV):**
   - Extracts audio track duration and displays an interactive playback bar.
   - Generates synthetic 32-bar visual audio waveforms (`CanvasAssetStorage.generateWaveformPeaks(for:count:)`).
4. **PDF Documents (PDFKit):**
   - Embeds native multi-page or single-page PDF extracts directly into the infinite canvas.
   - Enables native text selection, copying, and freehand ink annotation over PDF textbook sheets.

### 6.3 Drag-and-Drop Ingestion & Clipboard Pasting
- **Drag & Drop:** Dragging any image, video, audio file, or PDF from the macOS Finder directly onto `InkCanvasViewportNSView` automatically ingests the file, calculates canvas-relative drop coordinates via inverse transform, and instantiates the proper `CanvasItem`.
- **Clipboard Paste:** Pressing `Cmd+V` with copied image data or file URLs creates an item centered at the current viewport view center.

---

## 7. Universal Note Link Anchors & PKM Bi-Directional Graph Sync

Every object in the infinite canvas is a first-class citizen of Medhara’s Personal Knowledge Management (PKM) graph.

### 7.1 Universal Note Linking (`linkedNoteDocId`)
Any canvas item—flowchart shape, photo, audio memo, or text block—can anchor directly to any note document in the workspace:
- Stored on `CanvasItem.linkedNoteDocId`.
- Provides an optional `linkAnchorLabel` for contextual titling.

### 7.2 Visual Link Anchor Badges & Instant Jump Navigation
- **Distinctive Badge:** Linked items display an accented anchor pill icon (`link.circle.fill`) in their top-right corner.
- **One-Click Jump:** Clicking the badge immediately opens the referenced note in the Medhara editor (`onSelectReferencedNote(noteDocId)`).

### 7.3 PKM Graph Integration (`DocLink` Bi-Directional Sync)
Whenever a canvas item links to a document, `BlockStore` automatically registers a bidirectional link record in the SQLite `doc_links` table:
- **Global Knowledge Graph:** The relationship appears in the 3D / 2D Knowledge Graph view as a first-class directed connection.
- **Backlinks Panel:** The target note’s Inspector automatically lists the parent canvas and specific shape in its Backlinks section.

---

## 8. Semantic Level-of-Detail (LOD) Zoom Rendering

To maintain a consistent **60–120 FPS** frame rate when viewing boards with thousands of shapes, connectors, and media assets, Medhara employs a **3-Tier Semantic Level-of-Detail (LOD)** rendering engine:

```
[Macro View: zoom < 0.35]
      High-contrast silhouettes, wireframe boundaries, connector flows.
                     |
                     v
[Medium Flowchart View: 0.35 <= zoom < 1.0]
      Icons, bold titles, 2-line snippets, media thumbnails, link badges.
                     |
                     v
[Deep Detail View: zoom >= 1.0]
      Full markdown typography, interactive audio waveforms, rich controls.
```

### 8.1 Macro Panoramic View (`zoom < 0.35`)
- Designed for high-altitude architectural overviews.
- Renders high-contrast silhouette vector shapes, primary wireframe paths, and high-level section titles.
- Interior fine text, waveform bars, and media controls are omitted, eliminating rendering bottlenecks.

### 8.2 Medium Flowchart View (`0.35 <= zoom < 1.0`)
- Standard viewing mode for diagram navigation.
- Renders shape category icons, bold item titles, 2-line preview snippets, cached media raster thumbnails, and PKM link badges.

### 8.3 Deep Detail View (`zoom >= 1.0`)
- Deep focus and editing mode.
- Renders full formatted Markdown typography, interactive media controls, 32-bar audio waveforms, and dense node notes.

---

## 9. User Interface & Floating macOS Glass Toolbar

### 9.1 Translucent Frosted Glass Capsule (`CanvasUnifiedFloatingToolbar`)
A sleek, floating glass capsule toolbar rests at the bottom center of the canvas viewport, utilizing native macOS vibrancy (`NSVisualEffectView` HUD style):

```
+-----------------------------------------------------------------------------------------+
| [✋ Hand] | [✏️ Pen] | [🔷 Shapes ▾] | [⚡ Connector ▾] | [🔤 Text] | [🖼️ Media] | [🔗 Note] |
+-----------------------------------------------------------------------------------------+
```

1. **[✋ Hand / Pan Tool]:** Spacebar / free navigation mode without drawing.
2. **[✏️ Pen / Ink Tool]:** Quick-toggle to vector inking mode.
3. **[🔷 Shapes Dropdown]:** One-click insertion of Rectangles, Rounded Rects, Diamonds, Ellipses, or Container Groups.
4. **[⚡ Smart Connector Tool]:** Toggle connector wiring mode between **Orthogonal (90°)** and **Curved Bezier**.
5. **[🔤 Text Block]:** Inserts a floating rich-text / markdown card.
6. **[🖼️ Media Upload]:** Native file dialog to ingest images, videos, audio, or PDFs.
7. **[🔗 Note Link Card]:** Quick fuzzy search to embed an existing note as an interactive canvas card.

### 9.2 Keyboard Shortcuts & Spatial Navigation
- `H`: Select Hand Tool
- `P`: Select Ballpoint Pen
- `F`: Select Fountain / Calligraphy Pen
- `E`: Select Stroke Eraser
- `L`: Select Lasso Selection
- `Cmd + 0`: Reset zoom to 100%
- `Cmd + 9`: Zoom to Fit Width
- `Space + Drag`: Instant temporary pan drag

---

## 10. Database Schema & GRDB Persistence Architecture

All canvas data is persisted within SQLite using GRDB migrations with full foreign-key constraints and cascade deletion.

### 10.1 Schema Definition (`v17_unified_infinite_canvas`)

```sql
-- Canvas Items Table
CREATE TABLE canvas_items (
    id TEXT PRIMARY KEY,
    canvasDocId TEXT NOT NULL REFERENCES block(id) ON DELETE CASCADE,
    itemType TEXT NOT NULL,
    x REAL NOT NULL,
    y REAL NOT NULL,
    width REAL NOT NULL,
    height REAL NOT NULL,
    rotationDegrees REAL NOT NULL DEFAULT 0.0,
    zIndex INTEGER NOT NULL DEFAULT 0,
    linkedNoteDocId TEXT REFERENCES block(id) ON DELETE SET NULL,
    linkAnchorLabel TEXT,
    shapeType TEXT,
    fillColorHex TEXT,
    strokeColorHex TEXT,
    strokeWidth REAL NOT NULL DEFAULT 2.0,
    cornerRadius REAL NOT NULL DEFAULT 0.0,
    title TEXT,
    summarySnippet TEXT,
    markdownContent TEXT,
    mediaAssetKey TEXT,
    createdAt DATETIME NOT NULL,
    updatedAt DATETIME NOT NULL
);

CREATE INDEX idx_canvas_items_docId ON canvas_items(canvasDocId);
CREATE INDEX idx_canvas_items_linkedNoteDocId ON canvas_items(linkedNoteDocId);

-- Canvas Connectors Table
CREATE TABLE canvas_connectors (
    id TEXT PRIMARY KEY,
    canvasDocId TEXT NOT NULL REFERENCES block(id) ON DELETE CASCADE,
    sourceItemId TEXT NOT NULL REFERENCES canvas_items(id) ON DELETE CASCADE,
    targetItemId TEXT NOT NULL REFERENCES canvas_items(id) ON DELETE CASCADE,
    sourceCardinal TEXT NOT NULL DEFAULT 'east',
    targetCardinal TEXT NOT NULL DEFAULT 'west',
    routingType TEXT NOT NULL DEFAULT 'orthogonal',
    startStyle TEXT NOT NULL DEFAULT 'none',
    endStyle TEXT NOT NULL DEFAULT 'arrow',
    strokeColorHex TEXT NOT NULL DEFAULT '#64748B',
    strokeWidth REAL NOT NULL DEFAULT 2.0,
    labelText TEXT,
    createdAt DATETIME NOT NULL,
    updatedAt DATETIME NOT NULL
);

CREATE INDEX idx_canvas_conn_docId ON canvas_connectors(canvasDocId);
CREATE INDEX idx_canvas_conn_source ON canvas_connectors(sourceItemId);
CREATE INDEX idx_canvas_conn_target ON canvas_connectors(targetItemId);
```

### 10.2 Cascade Safety & Foreign Keys
- Deleting a parent document note (`canvasDocId`) automatically cascades and cleans up all associated `canvas_items` and `canvas_connectors`.
- Deleting a `CanvasItem` cascades and cleans up any attached `canvas_connectors` automatically via SQLite foreign keys.
- Deleting a referenced note (`linkedNoteDocId`) sets the link pointer to `NULL` without deleting the canvas shape itself.

---

## 11. Verification & Testing Reference

All canvas features are formally tested and verified in `Sources/MedhaTestRunner/main.swift`:
- **Suite 35:** Handwritten (Ink) Notes Integration & Persistence
- **Suite 36:** Vector Ink Engine Geometry & Stroke Persistence
- **Suite 37:** Multi-Page Canvas, Lasso & Vector Export
- **Suite 38:** PDF Document Import, Range Trimming & Embedding
- **Suite 40:** Multi-Mode Ink Canvas & Flexible Zoom Navigation
- **Suite 43:** Canvas Note Cards & Vast 2D Space
- **Suite 46:** Interactive Spatial PDF Pages, Resizing, Cropping & Native Text Selection
- **Suite 48:** Unified Infinite Canvas Suite (CRUD for items and connectors, cardinal snapping, routing algorithms, media asset ingestion, waveform generation, semantic LOD tiers, and PKM link anchors)

Run the full verification suite anytime using:
```bash
swift run MedhaTestRunner
```
