function createMedharaEcosystemSlide() {
  var presentation = SlidesApp.getActivePresentation();
  var slide = presentation.appendSlide(SlidesApp.PredefinedLayout.BLANK);
  
  // Slide dimensions: Standard 16:9 widescreen (720 x 405 pt)
  var slideW = 720;
  var slideH = 405;
  var leftM = 30;
  var rightM = 30;
  var usableW = slideW - leftM - rightM; // 660 pt
  
  // Helper: Create rounded rectangle shape
  function makeBox(l, t, w, h, bgHex, borderHex) {
    var shape = slide.insertShape(SlidesApp.ShapeType.ROUND_RECTANGLE, l, t, w, h);
    shape.getFill().setSolidFill(bgHex);
    shape.getBorder().getLineFill().setSolidFill(borderHex);
    shape.getBorder().setWeight(1.0);
    return shape;
  }

  // Helper: Create an icon + label element (matches reference image aesthetic)
  function makeIconItem(centerX, topY, iconUrl, fallbackEmoji, labelText, subBadge) {
    var iconSize = 30;
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
      var fb = slide.insertTextBox(fallbackEmoji, iconX - 4, iconY - 4, iconSize + 8, iconSize + 8);
      fb.getText().getTextStyle().setFontSize(20);
      fb.getText().getParagraphStyle().setParagraphAlignment(SlidesApp.ParagraphAlignment.CENTER);
    }

    // Centered label below icon
    var lblW = 100;
    var lbl = slide.insertTextBox(labelText, centerX - lblW / 2, topY + iconSize + 2, lblW, 14);
    var t = lbl.getText();
    t.getTextStyle().setFontSize(6.4).setBold(true).setForegroundColor("#0F172A");
    lbl.getText().getParagraphStyle().setParagraphAlignment(SlidesApp.ParagraphAlignment.CENTER);

    // Optional small subtitle / badge
    if (subBadge) {
      var subLbl = slide.insertTextBox(subBadge, centerX - lblW / 2, topY + iconSize + 15, lblW, 11);
      subLbl.getText().getTextStyle().setFontSize(4.8).setForegroundColor("#64748B");
      subLbl.getText().getParagraphStyle().setParagraphAlignment(SlidesApp.ParagraphAlignment.CENTER);
    }
  }

  // Helper: Dotted horizontal divider line
  function makeHDivider(y) {
    var line = slide.insertLine(SlidesApp.LineCategory.STRAIGHT, leftM, y, leftM + usableW, y);
    line.getLineFill().setSolidFill("#CBD5E1");
    line.setWeight(0.8);
    line.setDashStyle(SlidesApp.DashStyle.DOT);
    return line;
  }

  // ==============================================================================
  // TOP TITLE PILL BADGE
  // ==============================================================================
  var titleBadge = makeBox(220, 6, 280, 20, "#1D4ED8", "#1E40AF");
  var tbText = titleBadge.getText();
  tbText.setText("MEDHARA ECOSYSTEM & TECHNOLOGY");
  tbText.getTextStyle().setFontSize(8.5).setBold(true).setForegroundColor("#FFFFFF");
  tbText.getParagraphStyle().setParagraphAlignment(SlidesApp.ParagraphAlignment.CENTER);

  // ==============================================================================
  // ROW 1: CORE RUNTIMES & CLIENTS (Divided by vertical dotted line)
  // ==============================================================================
  var r1Y = 32;
  var midX = leftM + usableW / 2; // 360

  // Left Side of Row 1: Languages (Swift & TypeScript)
  makeIconItem(leftM + 75, r1Y, "https://upload.wikimedia.org/wikipedia/commons/thumb/9/9d/Swift_logo.svg/120px-Swift_logo.svg.png", "🟠", "Swift 6", "macOS Native Kernel");
  makeIconItem(leftM + 225, r1Y, "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4c/Typescript_logo_2020.svg/120px-Typescript_logo_2020.svg.png", "🔷", "TypeScript", "Web PWA Frontend");

  // Vertical Dotted Divider
  var vDiv = slide.insertLine(SlidesApp.LineCategory.STRAIGHT, midX, r1Y + 2, midX, r1Y + 54);
  vDiv.getLineFill().setSolidFill("#94A3B8");
  vDiv.setWeight(0.9);
  vDiv.setDashStyle(SlidesApp.DashStyle.DOT);

  // Right Side of Row 1: Desktop & Browser
  makeIconItem(midX + 75, r1Y, "https://upload.wikimedia.org/wikipedia/commons/thumb/1/1b/Apple_logo_grey.svg/120px-Apple_logo_grey.svg.png", "💻", "macOS Desktop", "LIVE: Native AppKit/Metal");
  makeIconItem(midX + 225, r1Y, "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d5/Progressive_Web_Apps_Logo.svg/120px-Progressive_Web_Apps_Logo.svg.png", "🌐", "Browser (PWA)", "PLAN: WebGL / OPFS");

  makeHDivider(94);

  // ==============================================================================
  // ROW 2: OPERATING SYSTEMS & CLIENT PLATFORMS (4 Columns)
  // ==============================================================================
  var r2Y = 100;
  var col4W = usableW / 4;
  makeIconItem(leftM + col4W * 0.5, r2Y, "https://upload.wikimedia.org/wikipedia/commons/thumb/6/64/Android_logo_2019_%28stacked%29.svg/120px-Android_logo_2019_%28stacked%29.svg.png", "🤖", "Android", "Planned Mobile PWA");
  makeIconItem(leftM + col4W * 1.5, r2Y, "https://upload.wikimedia.org/wikipedia/commons/thumb/1/1b/Apple_logo_grey.svg/120px-Apple_logo_grey.svg.png", "🍎", "iOS / iPadOS", "Planned Touch Loci");
  makeIconItem(leftM + col4W * 2.5, r2Y, "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d5/Rust_programming_language_black_logo.svg/120px-Rust_programming_language_black_logo.svg.png", "⚙️", "Rust & WASM", "Planned Browser Engine");
  makeIconItem(leftM + col4W * 3.5, r2Y, "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e1/Google_Chrome_icon_%28February_2022%29.svg/120px-Google_Chrome_icon_%28February_2022%29.svg.png", "🧩", "Chrome Extension", "Web Clipper Capture");

  makeHDivider(164);

  // ==============================================================================
  // ROW 3: PROTOCOLS, AGENTS & APIS (4 Columns)
  // ==============================================================================
  var r3Y = 170;
  makeIconItem(leftM + col4W * 0.5, r3Y, null, "⚡", "Direct SQLite IPC", "Sub-1ms GRDB Pointers");
  makeIconItem(leftM + col4W * 1.5, r3Y, "https://upload.wikimedia.org/wikipedia/commons/thumb/f/fe/Model_Context_Protocol_logo.svg/120px-Model_Context_Protocol_logo.svg.png", "🔌", "MCP API", "Anthropic Tool Calling");
  makeIconItem(leftM + col4W * 2.5, r3Y, "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/Wikipedia-logo-v2-en.svg/120px-Wikipedia-logo-v2-en.svg.png", "📚", "Wikipedia REST API", "Live Fact Grounding");
  makeIconItem(leftM + col4W * 3.5, r3Y, "https://upload.wikimedia.org/wikipedia/commons/thumb/8/8a/Google_Gemini_logo.svg/120px-Google_Gemini_logo.svg.png", "☁️", "Cloud AI Fallback", "Gemini 2.5 Flash / GPT-4o");

  makeHDivider(234);

  // ==============================================================================
  // ROW 4: STORAGE & PERSISTENCE (6 Columns)
  // ==============================================================================
  var r4Y = 240;
  var col6W = usableW / 6;
  makeIconItem(leftM + col6W * 0.5, r4Y, "https://upload.wikimedia.org/wikipedia/commons/thumb/3/38/SQLite370.svg/120px-SQLite370.svg.png", "🗄️", "SQLite FTS5", "BM25 Search");
  makeIconItem(leftM + col6W * 1.5, r4Y, null, "📊", "medhara.db", "Blocks & Links");
  makeIconItem(leftM + col6W * 2.5, r4Y, null, "⏱️", "flashcards.db", "FSRS-4.5 State");
  makeIconItem(leftM + col6W * 3.5, r4Y, null, "💼", "asset_vault", "Palace Photos");
  makeIconItem(leftM + col6W * 4.5, r4Y, null, "🌳", "blocktree.db", "Parent Hierarchy");
  makeIconItem(leftM + col6W * 5.5, r4Y, null, "📄", "Markdown Docs", "WikiLinks & Sync");

  makeHDivider(304);

  // ==============================================================================
  // ROW 5: CORE COGNITIVE ENGINES & MODULES (7 Columns)
  // ==============================================================================
  var r5Y = 310;
  var col7W = usableW / 7;
  makeIconItem(leftM + col7W * 0.5, r5Y, null, "✒️", "Block Editor", "SwiftUI / React");
  makeIconItem(leftM + col7W * 1.5, r5Y, null, "📂", "Knowledge Tree", "Syllabus Outline");
  makeIconItem(leftM + col7W * 2.5, r5Y, null, "🕸️", "ForceSim-2D", "Barnes-Hut GPU");
  makeIconItem(leftM + col7W * 3.5, r5Y, null, "🏛️", "Memory Palace", "2D Multi-Photo");
  makeIconItem(leftM + col7W * 4.5, r5Y, null, "🔄", "Dejavu Sync", "Local-First CRDT");
  makeIconItem(leftM + col7W * 5.5, r5Y, null, "📈", "FSRS-4.5 Core", "Spaced Repetition");
  makeIconItem(leftM + col7W * 6.5, r5Y, "https://upload.wikimedia.org/wikipedia/commons/thumb/9/91/Octicons-mark-github.svg/120px-Octicons-mark-github.svg.png", "🧪", "27 Test Suites", "100% Passing");
}
