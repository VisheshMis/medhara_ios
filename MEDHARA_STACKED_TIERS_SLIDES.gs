/**
 * ==============================================================================
 * MEDHARA STACKED ARCHITECTURE CARDS (VERTICAL & EXPANSIVE TIERS)
 * ==============================================================================
 * 
 * Generates an editable, high-impact stacked card diagram matching the exact
 * design of the reference image (media_1789900175535.png).
 * 
 * Includes 2 Functions:
 * 1. createMedharaStackedCards9x16(): Compact vertical 9:16 card stack (ideal for
 *    mobile, story slides, sidebar components, or standalone vertical layouts).
 * 2. createMedharaStackedCardsWidescreen(): Expansive full-width slide layout
 *    utilizing the full 16:9 widescreen canvas.
 * 
 * Key Features:
 * - 5 Stacked rounded container cards with themed colored borders:
 *     1. PROGRAMMING LANGUAGES (Purple border & </> code badge)
 *     2. CLIENT PLATFORMS (Royal Blue border & dual-device badge)
 *     3. NETWORK & API INTERFACES (Teal/Steel border & network badge)
 *     4. DATABASES & PERSISTENCE (Slate Blue border & database badge)
 *     5. FRAMEWORKS & ECOSYSTEM ENGINES (Indigo border & cognitive engine badge)
 * - Highlights current live native macOS implementation vs planned Web PWA.
 * - Bold key entities with subtle parenthetical technical specifications.
 * - 100% native vector shapes and live editable text in Google Slides.
 * 
 * HOW TO RUN:
 * 1. Open your Google Slides presentation.
 * 2. Go to Extensions > Apps Script.
 * 3. Paste this code and select Run > createMedharaStackedCards9x16().
 * ==============================================================================
 */

/**
 * Creates the exact vertical stacked card architecture matching the reference image.
 * Uses a 9:16 aspect ratio box centered on a standard widescreen slide.
 */
function createMedharaStackedCards9x16() {
  var presentation = SlidesApp.getActivePresentation();
  var slide = presentation.appendSlide(SlidesApp.PredefinedLayout.BLANK);

  // 9:16 Aspect Ratio Box Geometry (centered on 720 x 405 pt slide)
  var cardW = 236;
  var cardLeft = (720 - cardW) / 2; // 242 pt
  var startY = 7;
  var gap = 5.5;

  // 5 Tiers Data
  var tiers = [
    {
      title: "PROGRAMMING LANGUAGES",
      titleColor: "#1E1B4B",
      borderColor: "#8B5CF6",
      bgColor: "#FAF5FF",
      badgeText: "</>",
      badgeBg: "#7C3AED",
      badgeFg: "#FFFFFF",
      h: 58,
      bullets: [
        { term: "TypeScript", detail: "Frontend & Web PWA" },
        { term: "Swift 6", detail: "macOS Native Kernel & Actors" },
        { term: "Rust & WASM", detail: "Planned Browser Engine" },
        { term: "Metal MSL", detail: "macOS GPU Graphics Shaders" }
      ]
    },
    {
      title: "CLIENT PLATFORMS",
      titleColor: "#1D4ED8",
      borderColor: "#2563EB",
      bgColor: "#F0F9FF",
      badgeText: "💻📱",
      badgeBg: "#0284C7",
      badgeFg: "#FFFFFF",
      h: 68,
      bullets: [
        { term: "macOS Desktop", detail: "LIVE: Native AppKit & Metal" },
        { term: "Web Browser", detail: "PLAN: PWA, WebGL & OPFS" },
        { term: "Android", detail: "PLAN: Offline Mobile PWA" },
        { term: "iOS / iPadOS", detail: "PLAN: Touch Loci & Pencil" },
        { term: "Chrome Extension", detail: "External Web Clipper" }
      ]
    },
    {
      title: "NETWORK & API INTERFACES",
      titleColor: "#0F172A",
      borderColor: "#0284C7",
      bgColor: "#F0FDFA",
      badgeText: "🌐☁️",
      badgeBg: "#0D9488",
      badgeFg: "#FFFFFF",
      h: 68,
      bullets: [
        { term: "Direct SQLite IPC", detail: "Sub-1ms GRDB In-Process" },
        { term: "MCP API", detail: "Model Context Protocol Tools" },
        { term: "Wikipedia REST API", detail: "Live Fact Grounding" },
        { term: "Google Gemini AI", detail: "Cloud Flash LLM Fallback" },
        { term: "Localhost Ollama", detail: ":11434 Offline Local LLM" }
      ]
    },
    {
      title: "DATABASES & PERSISTENCE",
      titleColor: "#0F172A",
      borderColor: "#3B82F6",
      bgColor: "#F8FAFC",
      badgeText: "🗄️",
      badgeBg: "#3B82F6",
      badgeFg: "#FFFFFF",
      h: 78,
      bullets: [
        { term: "SQLite DBs", detail: "with FTS5 BM25 Indexing" },
        { term: "medhara.db", detail: "Core Entity Blocks & Graph" },
        { term: "history.db", detail: "FSRS-4.5 Spaced Repetition" },
        { term: "asset_vault", detail: "Palace Photos & Coordinates" },
        { term: "blocktree.db", detail: "Parent-Child Hierarchy Tree" },
        { term: "Markdown Documents", detail: ".md Files & WikiLinks" }
      ]
    },
    {
      title: "FRAMEWORKS & ECOSYSTEM ENGINES",
      titleColor: "#1E1B4B",
      borderColor: "#4338CA",
      bgColor: "#EEF2FF",
      badgeText: "🧠⚙️",
      badgeBg: "#4338CA",
      badgeFg: "#FFFFFF",
      h: 89,
      bullets: [
        { term: "Block Editor", detail: "Bi-directional WikiLinks UI" },
        { term: "Knowledge Tree", detail: "Syllabus Hierarchy Outliner" },
        { term: "ForceSim-2D", detail: "Barnes-Hut GPU Graph Engine" },
        { term: "Memory Palace", detail: "2D Multi-Photo Spatial Loci" },
        { term: "Dejavu Sync", detail: "Local-First CRDT State Sync" },
        { term: "FSRS-4.5", detail: "Spaced Repetition Scheduler" },
        { term: "27 Test Suites", detail: "Automated CI Regression Suite" }
      ]
    }
  ];

  var curY = startY;

  for (var i = 0; i < tiers.length; i++) {
    var t = tiers[i];
    var cardH = t.h;

    // 1. Base Container Card
    var card = slide.insertShape(SlidesApp.ShapeType.ROUND_RECTANGLE, cardLeft, curY, cardW, cardH);
    card.getFill().setSolidFill(t.bgColor);
    card.getBorder().getLineFill().setSolidFill(t.borderColor);
    card.getBorder().setWeight(1.4);

    // 2. Overlapping Top-Left Badge Icon (matches reference image style)
    var badgeW = 28;
    var badgeH = 26;
    var badge = slide.insertShape(SlidesApp.ShapeType.ROUND_RECTANGLE, cardLeft - 5, curY - 2, badgeW, badgeH);
    badge.getFill().setSolidFill(t.badgeBg);
    badge.getBorder().getLineFill().setSolidFill(t.borderColor);
    badge.getBorder().setWeight(1.0);
    var bText = badge.getText();
    bText.setText(t.badgeText);
    bText.getTextStyle().setFontSize(9).setBold(true).setForegroundColor(t.badgeFg);
    badge.getText().getParagraphStyle().setParagraphAlignment(SlidesApp.ParagraphAlignment.CENTER);

    // 3. Section Title
    var titleLeft = cardLeft + 28;
    var titleW = cardW - 32;
    var titleBox = slide.insertTextBox(t.title, titleLeft, curY + 4, titleW, 14);
    var tt = titleBox.getText();
    tt.getTextStyle().setFontSize(6.8).setBold(true).setForegroundColor(t.titleColor);

    // 4. Bullets Content
    var bulletStr = "";
    for (var b = 0; b < t.bullets.length; b++) {
      bulletStr += "  •  " + t.bullets[b].term + " (" + t.bullets[b].detail + ")" + (b < t.bullets.length - 1 ? "\n" : "");
    }

    var bulletBox = slide.insertTextBox(bulletStr, cardLeft + 30, curY + 16, cardW - 36, cardH - 18);
    var bt = bulletBox.getText();
    bt.getTextStyle().setFontSize(5.2).setForegroundColor("#334155");

    // Bold the terms
    for (var b = 0; b < t.bullets.length; b++) {
      var matches = bt.find(t.bullets[b].term);
      for (var m = 0; m < matches.length; m++) {
        matches[m].getTextStyle().setBold(true).setForegroundColor("#0F172A");
      }
    }

    curY += cardH + gap;
  }
}

/**
 * Creates an expansive widescreen layout of the 5 tiers across a standard 16:9 slide.
 */
function createMedharaStackedCardsWidescreen() {
  var presentation = SlidesApp.getActivePresentation();
  var slide = presentation.appendSlide(SlidesApp.PredefinedLayout.BLANK);

  // 16:9 Slide Dimensions
  var slideW = 720;
  var slideH = 405;

  // Title Pill
  var pill = slide.insertShape(SlidesApp.ShapeType.ROUND_RECTANGLE, 200, 8, 320, 20);
  pill.getFill().setSolidFill("#1E3A8A");
  pill.getBorder().getLineFill().setSolidFill("#172554");
  pill.getText().setText("MEDHARA — ARCHITECTURAL TIERS & ENGINES");
  pill.getText().getTextStyle().setFontSize(8.5).setBold(true).setForegroundColor("#FFFFFF");
  pill.getText().getParagraphStyle().setParagraphAlignment(SlidesApp.ParagraphAlignment.CENTER);

  // 2 Columns: Left Column (3 Tiers), Right Column (2 Tiers)
  var colW = 328;
  var leftColX = 24;
  var rightColX = 368;

  // Left Column Tiers (Languages, Platforms, Interfaces)
  var leftTiers = [
    {
      title: "1. PROGRAMMING LANGUAGES",
      titleColor: "#1E1B4B", borderColor: "#8B5CF6", bgColor: "#FAF5FF",
      badgeText: "</>", badgeBg: "#7C3AED", badgeFg: "#FFFFFF",
      bullets: [
        { term: "TypeScript", detail: "Frontend UI & Reactive Components (Web PWA)" },
        { term: "Swift 6", detail: "macOS Native Kernel, Swift Concurrency & Actors" },
        { term: "Rust & WASM", detail: "Planned High-Performance Browser Graph Engine" },
        { term: "Metal Shading Language", detail: "macOS 120 FPS Direct GPU Shaders" }
      ]
    },
    {
      title: "2. CLIENT PLATFORMS",
      titleColor: "#1D4ED8", borderColor: "#2563EB", bgColor: "#F0F9FF",
      badgeText: "💻📱", badgeBg: "#0284C7", badgeFg: "#FFFFFF",
      bullets: [
        { term: "macOS Desktop", detail: "LIVE: Native AppKit, Swift & Metal Canvas" },
        { term: "Web Browser", detail: "PLAN: Cross-Browser PWA, WebGL & OPFS" },
        { term: "Android", detail: "PLAN: Offline-First Mobile PWA" },
        { term: "iOS / iPadOS", detail: "PLAN: Touch Spatial Loci & Apple Pencil" },
        { term: "Chrome Extension", detail: "External Note & Web Clipper Capture" }
      ]
    },
    {
      title: "3. NETWORK & API INTERFACES",
      titleColor: "#0F172A", borderColor: "#0284C7", bgColor: "#F0FDFA",
      badgeText: "🌐☁️", badgeBg: "#0D9488", badgeFg: "#FFFFFF",
      bullets: [
        { term: "Direct SQLite IPC", detail: "Sub-1ms GRDB In-Process Shared Pointers" },
        { term: "MCP API", detail: "Anthropic Model Context Protocol Tool Calling" },
        { term: "Wikipedia REST API", detail: "Live Encyclopedic Grounding (0% Hallucination)" },
        { term: "Google Gemini AI", detail: "Cloud Flash LLM Fallback & Vector Embeddings" },
        { term: "Localhost Ollama", detail: ":11434 Offline Local LLM Inference Daemon" }
      ]
    }
  ];

  // Right Column Tiers (Persistence, Engines)
  var rightTiers = [
    {
      title: "4. DATABASES & PERSISTENCE",
      titleColor: "#0F172A", borderColor: "#3B82F6", bgColor: "#F8FAFC",
      badgeText: "🗄️", badgeBg: "#3B82F6", badgeFg: "#FFFFFF",
      bullets: [
        { term: "SQLite WAL Engine", detail: "with FTS5 BM25 Porter-Stemming Search" },
        { term: "medhara.db", detail: "Core Entity Graph, Blocks & Document Nodes" },
        { term: "history.db", detail: "FSRS-4.5 Spaced Repetition Card Review Logs" },
        { term: "asset_vault", detail: "Multi-Photo Memory Palace Assets & Coordinates" },
        { term: "blocktree.db", detail: "Parent-Child Hierarchy Tree Navigation" },
        { term: "Markdown Documents", detail: ".md Files, WikiLinks & Plaintext Portability" }
      ]
    },
    {
      title: "5. FRAMEWORKS & ECOSYSTEM ENGINES",
      titleColor: "#1E1B4B", borderColor: "#4338CA", bgColor: "#EEF2FF",
      badgeText: "🧠⚙️", badgeBg: "#4338CA", badgeFg: "#FFFFFF",
      bullets: [
        { term: "Block Editor", detail: "Bi-directional WikiLinks UI & Markdown Parser" },
        { term: "Knowledge Tree", detail: "Syllabus Hierarchy Outliner & Tree Navigation" },
        { term: "ForceSim-2D", detail: "Barnes-Hut GPU Physics Engine (0% Idle CPU)" },
        { term: "Memory Palace", detail: "2D Multi-Photo Spatial Loci Navigation Engine" },
        { term: "Dejavu Sync", detail: "Local-First CRDT State Synchronization" },
        { term: "FSRS-4.5 Scheduler", detail: "Modern Spaced Repetition (90% Retention Target)" },
        { term: "27 Test Suites", detail: "100% Passing Automated CI Regression Suite" }
      ]
    }
  ];

  function renderColumn(colTiers, colX, startY, totalH) {
    var gap = 8;
    var n = colTiers.length;
    var eachH = (totalH - (n - 1) * gap) / n;

    for (var i = 0; i < n; i++) {
      var t = colTiers[i];
      var y = startY + i * (eachH + gap);

      // Card Box
      var card = slide.insertShape(SlidesApp.ShapeType.ROUND_RECTANGLE, colX, y, colW, eachH);
      card.getFill().setSolidFill(t.bgColor);
      card.getBorder().getLineFill().setSolidFill(t.borderColor);
      card.getBorder().setWeight(1.3);

      // Overlapping Badge
      var b = slide.insertShape(SlidesApp.ShapeType.ROUND_RECTANGLE, colX - 6, y + 2, 28, 24);
      b.getFill().setSolidFill(t.badgeBg);
      b.getBorder().getLineFill().setSolidFill(t.borderColor);
      b.getText().setText(t.badgeText);
      b.getText().getTextStyle().setFontSize(8.5).setBold(true).setForegroundColor(t.badgeFg);
      b.getText().getParagraphStyle().setParagraphAlignment(SlidesApp.ParagraphAlignment.CENTER);

      // Title
      var tb = slide.insertTextBox(t.title, colX + 26, y + 3, colW - 30, 16);
      tb.getText().getTextStyle().setFontSize(7.5).setBold(true).setForegroundColor(t.titleColor);

      // Bullets
      var bulletStr = "";
      for (var j = 0; j < t.bullets.length; j++) {
        bulletStr += "  •  " + t.bullets[j].term + " (" + t.bullets[j].detail + ")" + (j < t.bullets.length - 1 ? "\n" : "");
      }
      var bb = slide.insertTextBox(bulletStr, colX + 28, y + 18, colW - 32, eachH - 20);
      var range = bb.getText();
      range.getTextStyle().setFontSize(5.8).setForegroundColor("#334155");

      for (var j = 0; j < t.bullets.length; j++) {
        var m = range.find(t.bullets[j].term);
        for (var k = 0; k < m.length; k++) {
          m[k].getTextStyle().setBold(true).setForegroundColor("#0F172A");
        }
      }
    }
  }

  // Render both columns
  var contentStartY = 36;
  var contentTotalH = slideH - contentStartY - 12; // 357 pt
  renderColumn(leftTiers, leftColX, contentStartY, contentTotalH);
  renderColumn(rightTiers, rightColX, contentStartY, contentTotalH);
}
