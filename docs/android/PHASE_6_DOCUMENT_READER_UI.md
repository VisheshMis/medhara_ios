# Phase 6: Jetpack Compose Document Reader & Search UI

> **Parent Roadmap**: [ANDROID_APP_INTEGRATION_AND_SYNC.md](../../ANDROID_APP_INTEGRATION_AND_SYNC.md)  
> **Target Subsystem**: Mobile Consumption Experience (Note Reader & FTS5 Search)  

---

## 🎯 Phase Objective
Build a lightweight, responsive reading interface in Jetpack Compose (Material 3) for browsing notebooks, navigating documents, reading hierarchical blocks with clean typography, and performing instant full-text searches using SQLite FTS5.

---

## 📱 UI Components & Architecture

### 1. Document Reader Screen (`DocumentReaderScreen.kt`)
- **TopAppBar**: Shows notebook breadcrumb, document title, search icon, and sync status indicator.
- **Hierarchical Block List**: `LazyColumn` rendering blocks based on indentation (`parentId` depth) and block type:
  - `heading1`, `heading2`, `heading3`: Scaled bold typography.
  - `paragraph`: Standard body with inline markdown parsing (bold, italics, code, links).
  - `bullet`, `numbered`: Bullet points with indentation.
  - `todo`: Interactive checkable checkbox (updates `isCompleted` locally and logs mutation).
  - `quote`, `callout`: Tinted container box with left accent border.
  - `code`: Monospace syntax block with background container.

```kotlin
@Composable
fun BlockItem(
    block: Block,
    depth: Int,
    onToggleTodo: (String, Boolean) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = (depth * 16).dp, top = 4.dp, bottom = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        when (block.type) {
            "todo" -> {
                Checkbox(
                    checked = block.isCompleted == 1,
                    onCheckedChange = { isChecked -> onToggleTodo(block.id, isChecked) }
                )
                Text(
                    text = block.content,
                    style = MaterialTheme.typography.bodyLarge,
                    textDecoration = if (block.isCompleted == 1) TextDecoration.LineThrough else null
                )
            }
            "heading1" -> {
                Text(text = block.content, style = MaterialTheme.typography.headlineMedium)
            }
            "heading2" -> {
                Text(text = block.content, style = MaterialTheme.typography.headlineSmall)
            }
            else -> {
                Text(text = block.content, style = MaterialTheme.typography.bodyMedium)
            }
        }
    }
}
```

---

### 2. Instant Search Bar & Results
- Query input triggers an FTS5 query:
  ```sql
  SELECT b.id, b.rootDocId, d.title AS docTitle, snippet(block_fts, 2, '<b>', '</b>', '...', 15) AS matchSnippet
  FROM block_fts
  JOIN block b ON block_fts.id = b.id
  JOIN document d ON b.rootDocId = d.id
  WHERE block_fts MATCH ?
  ORDER BY bm25(block_fts)
  LIMIT 50;
  ```
- Tapping a search result instantly opens the document and scrolls to the matched block.

---

## 🧪 Verification Gate
- Compose preview renders diverse block hierarchies cleanly.
- Tapping todo items updates local state and triggers CDC journal entry.
- FTS5 search queries return results in < 30ms for 10,000 blocks.
