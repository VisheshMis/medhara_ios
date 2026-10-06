# Stage 5: Block PKM Engine & Bi-Directional WikiLinks

> **Parent Roadmap**: [WINDOWS_PORT_PLAN.md](file:///Users/visheshmishra/Downloads/medharara/WINDOWS_PORT_PLAN.md)  
> **Status**: Completed ✅  
> **Target Platform**: Windows 10 / 11 (x64) via SQLite Relational Trees & In-Memory Store

---

## 🎯 Stage 5 Objectives

1. **12 Granular Block Types**:
   - `doc`, `inkDoc`, `heading1`, `heading2`, `heading3`, `paragraph`, `bulletList`, `taskList`, `codeBlock`, `quote`, `callout`, `blockRef`.
   - Full parent-child tree hierarchy support with indentation and order indexing.
2. **WikiLink Parsing Engine (`LinkParser`)**:
   - Dynamic regex extraction for `[[WikiLinks]]` matching [LinkParser.swift](file:///Users/visheshmishra/Downloads/medharara/Sources/MedhaKit/Services/LinkParser.swift).
   - Dynamic regex extraction for block transclusion `((b-uuid))`.
3. **Automatic `doc_link` Table Synchronization**:
   - On block insert and update, links are automatically extracted and indexed into the `doc_link` SQLite table.
   - Target documents are linked via `targetDocId` and `targetTitle`.
4. **Bi-Directional Backlinks Lookups**:
   - `store.getBacklinks(docId)` queries the database to identify all inbound references across documents.
5. **Dedicated Verification Suite (`tests/pkm.test.js`)**:
   - Automated unit tests covering link extraction, block hierarchies, and backlink lookups.

---

## 🚦 Stage 5 Verification Gate

```bash
# 1. Dedicated Block PKM test suite
npm run test:pkm

# 2. Complete integration suite
npm test
```
