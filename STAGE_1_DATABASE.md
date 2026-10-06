# Stage 1: Core SQLite Schema, FTS5 Engine & Database Manager Hardening

> **Parent Roadmap**: [WINDOWS_PORT_PLAN.md](file:///Users/visheshmishra/Downloads/medharara/WINDOWS_PORT_PLAN.md)  
> **Status**: Completed ✅  
> **Target Platform**: Windows 10 / 11 (x64) via Electron & `better-sqlite3`

---

## 🎯 Stage 1 Objectives

Stage 1 locks down the foundation's persistence and search layer before any further UI slices are built:
1. **100% GRDB Parity (Migrations v1 through v11)**:
   - Port migrations `v10` (Image Occlusion Flashcards) and `v11` (Ink Canvas Mode) from [DatabaseMigrations.swift](file:///Users/visheshmishra/Downloads/medharara/Sources/MedhaKit/Database/DatabaseMigrations.swift).
   - Ensure all 11 migrations are strictly idempotent with column checks (`PRAGMA table_info`).
2. **FTS5 Virtual Search Optimization**:
   - `block_fts` virtual table using `unicode61` tokenizer.
   - Real-time triggers (`AFTER INSERT`, `AFTER UPDATE`, `AFTER DELETE`) on `block`.
   - BM25 snippet extraction (`snippet(block_fts, 2, '<b>', '</b>', '...', 24)`).
3. **DatabaseManager API Hardening**:
   - Typed query helpers, transactional execution, and WAL configuration.
4. **Automated Verification Suite (`tests/database.test.js`)**:
   - Comprehensive unit tests covering migration idempotency, cascade deletions, and search queries.

---

## 📋 Schema Migration Inventory (v1 - v11)

| Migration | Purpose | Key Tables / Columns Added |
| :--- | :--- | :--- |
| `v1_initial_schema` | Core block PKM & search | `notebook`, `block`, `block_fts`, sync triggers |
| `v2_flashcards_and_palaces` | Retention & Spatial foundation | `flashcard`, `memory_palace`, `palace_locus` |
| `v3_links_to_graph` | Graph & bi-directional links | `doc_link` |
| `v4_multiphoto_palace_and_locus_anchors` | Multi-scene memory palaces | `palace_photo`, `locus_flashcard`, `palace_locus.photoId` |
| `v5_vast_canvas_photos` | Spatial canvas coordinates | `palace_photo.canvasX`, `canvasY`, `canvasWidth`, `canvasHeight` |
| `v6_flashcard_decks` | Deck organization | `deck`, `flashcard.deckId`, default deck creation |
| `v7_deck_options_and_card_flags` | Preset retention options | `deck.presetId`, `flashcard.isSuspended` |
| `v8_ink_notes` | Vector ink handwritten notes | `ink_document_page` |
| `v9_ink_page_pdf_import` | PDF page background attachments | `ink_document_page.pdfPath`, `pdfPageIndex` |
| `v10_image_occlusion_flashcards` | Medical & diagram occlusion | `flashcard.cardType`, `imagePath`, `occlusionMasksData`, `activeMaskId`, `occlusionMode` |
| `v11_ink_canvas_mode` | Canvas boundary options | `block.canvasMode` (`'a4Pages'` vs `'infinite'`) |

---

## 🚦 Stage 1 Automated Verification Gate

```bash
# 1. Type check shared schema types
npm run typecheck

# 2. Run dedicated Stage 1 database test suite
npm run test:db

# 3. Verify complete suite
npm test
```
