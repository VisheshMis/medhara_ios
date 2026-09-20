/**
 * ==============================================================================
 * MEDHARA ECOSYSTEM & TECHNOLOGY STACK (9:16 VERTICAL COMPACT CARD)
 * ==============================================================================
 * 
 * Generates an editable, compact 9:16 vertical architecture card matching the
 * authentic design of the reference diagram (media_1789899060091.png).
 * 
 * Key Features:
 * - Strict 9:16 aspect ratio box (220 pt wide x 391 pt high).
 * - Tightly grouped elements optimized for vertical space (e.g. mobile, stories, sidebars).
 * - Real authentic high-res PNG logos (TypeScript, Swift, Apple, PWA, Chrome, Android, Rust, SQLite, Wikipedia, Gemini, GitHub).
 * - 5 Tiers with dotted horizontal & vertical dividers:
 *     1. Languages & Clients (Swift 6, TypeScript | macOS Desktop, Web PWA)
 *     2. Client Platforms (Android, iOS, Rust/WASM, Chrome Extension)
 *     3. Protocols & APIs (Direct SQLite IPC, MCP Protocol, Wikipedia API, Gemini AI)
 *     4. Storage & Persistence (2x3 grid: SQLite FTS5, medhara.db, history.db, asset_vault, blocktree.db, .md Docs)
 *     5. Cognitive Engines (Row 1: Block Editor, Knowledge Tree, ForceSim-2D; Row 2: Memory Palace, Dejavu Sync, FSRS-4.5, 27 Tests)
 * - 100% native vector shapes and live editable text in Google Slides.
 * 
 * HOW TO RUN:
 * 1. Open your Google Slides presentation (widescreen 16:9 or vertical 9:16).
 * 2. Go to Extensions > Apps Script.
 * 3. Paste this code and click Run > createMedharaEcosystem9x16Card().
 * ==============================================================================
 */

function createMedharaEcosystem9x16Card() {
  var presentation = SlidesApp.getActivePresentation();
  var slide = presentation.appendSlide(SlidesApp.PredefinedLayout.BLANK);

  // Standard 16:9 slide is 720 x 405 pt.
  // 9:16 aspect ratio: 220 pt wide x 391.1 pt high (220 / 391.1 = 0.5625 = 9:16)
  var cardW = 220;
  var cardH = 391;
  
  // Center card on slide (or adjust cardLeft/cardTop to place anywhere)
  var cardLeft = (720 - cardW) / 2; // 250 pt
  var cardTop = (405 - cardH) / 2;   // 7 pt

  // ============================================================================
  // HELPER FUNCTIONS
  // ============================================================================
  
  // Helper: Create rounded rectangle shape
  function makeBox(l, t, w, h, bgHex, borderHex, borderWeight) {
    var shape = slide.insertShape(SlidesApp.ShapeType.ROUND_RECTANGLE, l, t, w, h);
    shape.getFill().setSolidFill(bgHex);
    shape.getBorder().getLineFill().setSolidFill(borderHex);
    shape.getBorder().setWeight(borderWeight || 1.0);
    return shape;
  }

  // Helper: Create a compact icon + label + sub-badge unit
  function makeCompactItem(centerX, topY, iconUrl, fallbackEmoji, labelText, subBadge, iconDim) {
    var iconSize = iconDim || 18;
    var iconX = centerX - iconSize / 2;
    var iconY = topY;
    var imgSuccess = false;

    if (iconUrl) {
      try {
        slide.insertImage(iconUrl, iconX, iconY, iconSize, iconSize);
        imgSuccess = true;
      } catch (e) {
        imgSuccess = false;
      }
    }
    if (!imgSuccess) {
      var fb = slide.insertTextBox(fallbackEmoji, iconX - 4, iconY - 3, iconSize + 8, iconSize + 6);
      fb.getText().getTextStyle().setFontSize(iconSize * 0.75);
      fb.getText().getParagraphStyle().setParagraphAlignment(SlidesApp.ParagraphAlignment.CENTER);
    }

    // Centered label directly below icon
    var lblW = 54;
    var lbl = slide.insertTextBox(labelText, centerX - lblW / 2, topY + iconSize + 1, lblW, 13);
    var t = lbl.getText();
    t.getTextStyle().setFontSize(5.8).setBold(true).setForegroundColor("#0F172A");
    lbl.getText().getParagraphStyle().setParagraphAlignment(SlidesApp.ParagraphAlignment.CENTER);

    // Centered sub-badge / subtitle
    if (subBadge) {
      var subLbl = slide.insertTextBox(subBadge, centerX - lblW / 2, topY + iconSize + 11, lblW, 11);
      var st = subLbl.getText();
      st.getTextStyle().setFontSize(4.4).setForegroundColor("#64748B");
      subLbl.getText().getParagraphStyle().setParagraphAlignment(SlidesApp.ParagraphAlignment.CENTER);
    }
  }

  // Helper: Dotted horizontal divider line inside card
  function makeHDivider(y) {
    var line = slide.insertLine(SlidesApp.LineCategory.STRAIGHT, cardLeft + 10, y, cardLeft + cardW - 10, y);
    line.getLineFill().setSolidFill("#E2E8F0");
    line.setWeight(0.8);
    line.setDashStyle(SlidesApp.DashStyle.DOT);
    return line;
  }

  // ============================================================================
  // CARD CONTAINER (9:16 White Card with Blue Border)
  // ============================================================================
  makeBox(cardLeft, cardTop, cardW, cardH, "#FFFFFF", "#1D4ED8", 1.5);

  // ============================================================================
  // HEADER PILL BADGE
  // ============================================================================
  var pillW = 186;
  var pillH = 20;
  var pillBadge = makeBox(cardLeft + (cardW - pillW) / 2, cardTop + 8, pillW, pillH, "#1D4ED8", "#1E40AF", 1.0);
  var pillText = pillBadge.getText();
  pillText.setText("MEDHARA ECOSYSTEM & TECHNOLOGY");
  pillText.getTextStyle().setFontSize(7.5).setBold(true).setForegroundColor("#FFFFFF");
  pillBadge.getText().getParagraphStyle().setParagraphAlignment(SlidesApp.ParagraphAlignment.CENTER);

  // ============================================================================
  // TIER 1: CORE RUNTIMES & CLIENTS (Split by Vertical Dotted Line)
  // ============================================================================
  var t1Y = cardTop + 34;
  var cardMidX = cardLeft + cardW / 2; // cardLeft + 110

  // Left Side: Languages (TypeScript & Swift 6)
  makeCompactItem(
    cardLeft + 32, t1Y,
    "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4c/Typescript_logo_2020.svg/120px-Typescript_logo_2020.svg.png",
    "🔷", "TypeScript", "Web PWA", 19
  );
  makeCompactItem(
    cardLeft + 82, t1Y,
    "https://upload.wikimedia.org/wikipedia/commons/thumb/9/9d/Swift_logo.svg/120px-Swift_logo.svg.png",
    "🟠", "Swift 6", "macOS Core", 19
  );

  // Vertical Dotted Divider
  var vDiv = slide.insertLine(SlidesApp.LineCategory.STRAIGHT, cardMidX, t1Y + 2, cardMidX, t1Y + 38);
  vDiv.getLineFill().setSolidFill("#94A3B8");
  vDiv.setWeight(0.8);
  vDiv.setDashStyle(SlidesApp.DashStyle.DOT);

  // Right Side: Clients (macOS Desktop & Browser PWA)
  makeCompactItem(
    cardMidX + 28, t1Y,
    "https://upload.wikimedia.org/wikipedia/commons/thumb/1/1b/Apple_logo_grey.svg/120px-Apple_logo_grey.svg.png",
    "💻", "Desktop", "Native macOS", 19
  );
  makeCompactItem(
    cardMidX + 78, t1Y,
    "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d5/Progressive_Web_Apps_Logo.svg/120px-Progressive_Web_Apps_Logo.svg.png",
    "🌐", "Browser", "Web PWA", 19
  );

  makeHDivider(cardTop + 84);

  // ============================================================================
  // TIER 2: OPERATING SYSTEMS & CLIENT PLATFORMS (4 Columns)
  // ============================================================================
  var t2Y = cardTop + 90;
  // 4 items spaced evenly across cardW (centers at ~28, ~82, ~138, ~192)
  makeCompactItem(
    cardLeft + 28, t2Y,
    "https://upload.wikimedia.org/wikipedia/commons/thumb/6/64/Android_logo_2019_%28stacked%29.svg/120px-Android_logo_2019_%28stacked%29.svg.png",
    "🤖", "Android", "Mobile PWA", 18
  );
  makeCompactItem(
    cardLeft + 82, t2Y,
    "https://upload.wikimedia.org/wikipedia/commons/thumb/1/1b/Apple_logo_grey.svg/120px-Apple_logo_grey.svg.png",
    "🍎", "iOS / iPadOS", "Touch Loci", 18
  );
  makeCompactItem(
    cardLeft + 138, t2Y,
    "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d5/Rust_programming_language_black_logo.svg/120px-Rust_programming_language_black_logo.svg.png",
    "⚙️", "Rust & WASM", "Graph Engine", 18
  );
  makeCompactItem(
    cardLeft + 192, t2Y,
    "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e1/Google_Chrome_icon_%28February_2022%29.svg/120px-Google_Chrome_icon_%28February_2022%29.svg.png",
    "🧩", "Chrome Ext", "Web Clipper", 18
  );

  makeHDivider(cardTop + 140);

  // ============================================================================
  // TIER 3: PROTOCOLS, AGENTS & APIS (4 Columns)
  // ============================================================================
  var t3Y = cardTop + 146;
  makeCompactItem(
    cardLeft + 28, t3Y,
    null,
    "⚡", "Direct IPC", "Sub-1ms GRDB", 18
  );
  makeCompactItem(
    cardLeft + 82, t3Y,
    "https://upload.wikimedia.org/wikipedia/commons/thumb/f/fe/Model_Context_Protocol_logo.svg/120px-Model_Context_Protocol_logo.svg.png",
    "🔌", "MCP API", "Anthropic Tool", 18
  );
  makeCompactItem(
    cardLeft + 138, t3Y,
    "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/Wikipedia-logo-v2-en.svg/120px-Wikipedia-logo-v2-en.svg.png",
    "📚", "Wikipedia", "Live Grounding", 18
  );
  makeCompactItem(
    cardLeft + 192, t3Y,
    "https://upload.wikimedia.org/wikipedia/commons/thumb/8/8a/Google_Gemini_logo.svg/120px-Google_Gemini_logo.svg.png",
    "☁️", "Gemini AI", "Flash Fallback", 18
  );

  makeHDivider(cardTop + 196);

  // ============================================================================
  // TIER 4: STORAGE & PERSISTENCE (6 Items in 2 Rows of 3)
  // ============================================================================
  // Row 4a (3 columns, centers at ~38, ~110, ~182)
  var t4aY = cardTop + 202;
  makeCompactItem(
    cardLeft + 38, t4aY,
    "https://upload.wikimedia.org/wikipedia/commons/thumb/3/38/SQLite370.svg/120px-SQLite370.svg.png",
    "🗄️", "SQLite (FTS5)", "BM25 Search", 18
  );
  makeCompactItem(
    cardLeft + 110, t4aY,
    null,
    "📊", "medhara.db", "Blocks & Nodes", 18
  );
  makeCompactItem(
    cardLeft + 182, t4aY,
    null,
    "⏱️", "history.db", "FSRS-4.5 State", 18
  );

  // Row 4b (3 columns, centers at ~38, ~110, ~182)
  var t4bY = cardTop + 242;
  makeCompactItem(
    cardLeft + 38, t4bY,
    null,
    "💼", "asset_vault", "Palace Photos", 18
  );
  makeCompactItem(
    cardLeft + 110, t4bY,
    null,
    "🌳", "blocktree.db", "Outline Hierarchy", 18
  );
  makeCompactItem(
    cardLeft + 182, t4bY,
    null,
    "📄", "Markdown Docs", "WikiLinks & Sync", 18
  );

  makeHDivider(cardTop + 288);

  // ============================================================================
  // TIER 5: COGNITIVE ENGINES & MODULES (7 Items: Row 5a has 3, Row 5b has 4)
  // ============================================================================
  // Row 5a (3 columns, centers at ~38, ~110, ~182)
  var t5aY = cardTop + 294;
  makeCompactItem(
    cardLeft + 38, t5aY,
    null,
    "✒️", "Block Editor", "SwiftUI / React", 18
  );
  makeCompactItem(
    cardLeft + 110, t5aY,
    null,
    "📂", "Knowledge Tree", "Syllabus Graph", 18
  );
  makeCompactItem(
    cardLeft + 182, t5aY,
    null,
    "🕸️", "ForceSim-2D", "Barnes-Hut GPU", 18
  );

  // Row 5b (4 columns, centers at ~28, ~82, ~138, ~192)
  var t5bY = cardTop + 338;
  makeCompactItem(
    cardLeft + 28, t5bY,
    null,
    "🏛️", "Memory Palace", "2D Spatial Loci", 17
  );
  makeCompactItem(
    cardLeft + 82, t5bY,
    null,
    "🔄", "Dejavu Sync", "Local-First CRDT", 17
  );
  makeCompactItem(
    cardLeft + 138, t5bY,
    null,
    "📈", "FSRS-4.5 Core", "Active Spaced Rep", 17
  );
  makeCompactItem(
    cardLeft + 192, t5bY,
    "https://upload.wikimedia.org/wikipedia/commons/thumb/9/91/Octicons-mark-github.svg/120px-Octicons-mark-github.svg.png",
    "🧪", "27 Test Suites", "100% CI Passing", 17
  );
}
