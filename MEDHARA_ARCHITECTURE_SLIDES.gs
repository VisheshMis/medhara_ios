// ==============================================================================
// MEDHARA ARCHITECTURE SLIDE GENERATOR FOR GOOGLE SLIDES
// ==============================================================================
// Instructions:
// 1. Open your presentation in Google Slides (https://slides.google.com).
// 2. Go to Extensions > Apps Script.
// 3. Paste this entire code into Code.gs and click Save (Cmd+S / Ctrl+S).
// 4. Click "Run" (▶️).
// 5. Switch back to Google Slides — a complete, fully editable vector architecture
//    diagram with all 18+ directed arrows, colored tiers, badges, and text will appear!
// ==============================================================================

function createMedharaArchitectureSlide() {
  var presentation = SlidesApp.getActivePresentation();
  var slide = presentation.appendSlide(SlidesApp.PredefinedLayout.BLANK);
  
  // Dimensions for standard 16:9 widescreen presentation (720 x 405 pt)
  var leftMargin = 14;
  var mainWidth = 512;
  var sideLeft = 544;
  var sideWidth = 162;
  
  // Helper: Create rounded rectangle shape using native ROUND_RECTANGLE
  function makeBox(l, t, w, h, bgHex, borderHex) {
    var shape = slide.insertShape(SlidesApp.ShapeType.ROUND_RECTANGLE, l, t, w, h);
    shape.getFill().setSolidFill(bgHex);
    shape.getBorder().getLineFill().setSolidFill(borderHex);
    shape.getBorder().setWeight(1.2);
    return shape;
  }

  // Helper: Create directed line/arrow with filled head and styling
  function makeArrow(x1, y1, x2, y2, colorHex, isDashed, isBiDirectional) {
    var line = slide.insertLine(SlidesApp.LineCategory.STRAIGHT, x1, y1, x2, y2);
    line.getLineFill().setSolidFill(colorHex);
    line.setWeight(1.3);
    line.setEndArrow(SlidesApp.ArrowStyle.FILL_ARROW);
    if (isBiDirectional) {
      line.setStartArrow(SlidesApp.ArrowStyle.FILL_ARROW);
    }
    if (isDashed) {
      line.setDashStyle(SlidesApp.DashStyle.DASH);
    }
    return line;
  }

  // Helper: Create small text label
  function makeLabel(text, x, y, w, h, colorHex) {
    var box = slide.insertTextBox(text, x, y, w, h);
    box.getText().getTextStyle().setFontSize(5.2).setBold(true).setForegroundColor(colorHex);
    return box;
  }

  // ==========================================
  // HEADER TITLE
  // ==========================================
  var header = slide.insertTextBox("MEDHARA — Dual-Engine Cognitive Memory Architecture", leftMargin, 5, mainWidth, 15);
  header.getText().getTextStyle().setFontSize(9.5).setBold(true).setForegroundColor("#4C1D95");

  // ==========================================
  // 1. TOP CLIENTS LAYER
  // ==========================================
  var clients = [
    "💻 macOS Native (Swift)",
    "🌐 Web PWA (WASM/GPU)",
    "📱 Mobile (iOS/Android)",
    "📋 iPadOS / Tablet",
    "⚡ Web Clipper Extension"
  ];
  var pillWidth = 98;
  var pillSpacing = 5.5;
  var pillBottom = 39;
  var pillCenters = [];

  for (var i = 0; i < clients.length; i++) {
    var px = leftMargin + i * (pillWidth + pillSpacing);
    var pill = makeBox(px, 21, pillWidth, 18, "#FFFFFF", "#7C3AED");
    var t = pill.getText();
    t.setText(clients[i]);
    t.getTextStyle().setFontSize(6.2).setBold(true).setForegroundColor("#5B21B6");
    pillCenters.push(px + pillWidth / 2);
  }

  // DIRECTED ARROWS: Clients -> Frontend (5 solid vertical arrows)
  var feTop = 50;
  for (var k = 0; k < pillCenters.length; k++) {
    makeArrow(pillCenters[k], pillBottom, pillCenters[k], feTop, "#7C3AED", false, false);
  }

  // ==========================================
  // 2. FRONTEND PRESENTATION LAYER (Purple)
  // ==========================================
  var frontendBox = makeBox(leftMargin, feTop, mainWidth, 79, "#FAF5FF", "#7C3AED");
  var fTitle = slide.insertTextBox("Frontend Layer (SwiftUI on macOS / TypeScript + React on Web PWA)", leftMargin + 6, feTop + 2, 480, 13);
  fTitle.getText().getTextStyle().setFontSize(7.8).setBold(true).setForegroundColor("#5B21B6");
  
  // Frontend Sub-boxes (4 columns)
  var fe1 = makeBox(leftMargin + 6, feTop + 16, 118, 57, "#FFFFFF", "#C084FC");
  fe1.getText().setText("📝 Block Editor & Outline\n• Keystroke-isolated editor\n• H1-H3, bullets, to-do lists\n• Embeds ((b-...)) & [[WikiLinks]]\n• Cascading folder hierarchy");
  fe1.getText().getTextStyle().setFontSize(5.6).setForegroundColor("#1E293B");
  fe1.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#6B21A8");

  var fe2 = makeBox(leftMargin + 128, feTop + 16, 122, 57, "#FFFFFF", "#C084FC");
  fe2.getText().setText("🕸️ GPU Knowledge Graph\n• SwiftUI Canvas / WebGL\n• Presets: [Links|Tree|Blended]\n• Clamped degree-based radius\n• 1-hop hover spotlight & LOD\n• Unresolved ghost targets");
  fe2.getText().getTextStyle().setFontSize(5.6).setForegroundColor("#1E293B");
  fe2.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#6B21A8");

  var fe3 = makeBox(leftMargin + 254, feTop + 16, 124, 57, "#FFFFFF", "#C084FC");
  fe3.getText().setText("🧠 Feynman & FSRS-4.5\n• Socratic Feynman dialog on 1st rep\n• FSRS-4.5 state machine (S, D, R)\n• 4-rating fast interval review\n• Metacognitive gap discovery\n• ⏱️ Focus timer integration");
  fe3.getText().getTextStyle().setFontSize(5.6).setForegroundColor("#1E293B");
  fe3.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#6B21A8");

  var fe4 = makeBox(leftMargin + 382, feTop + 16, 124, 57, "#FFFFFF", "#C084FC");
  fe4.getText().setText("🏛️ 2D Memory Palace\n• Multi-photo spatial canvas\n• Sequential loci route pathing\n• Radar walk & active recall\n• Self-graded loci check\n• 📤 Markdown/JSON export");
  fe4.getText().getTextStyle().setFontSize(5.6).setForegroundColor("#1E293B");
  fe4.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#6B21A8");

  // Internal Arrow in Frontend: Graph -> Feynman
  makeArrow(leftMargin + 250, feTop + 44, leftMargin + 254, feTop + 44, "#7C3AED", false, false);

  // ==========================================
  // DIRECTED ARROWS: Frontend <-> Interfaces / Kernel
  // ==========================================
  var ifTop = 143;
  var feBottom = feTop + 79; // 129
  // Arrow 1: Downward "AI-Feynman Query"
  makeArrow(leftMargin + 310, feBottom, leftMargin + 310, ifTop, "#7C3AED", false, false);
  makeLabel("AI-Feynman Query ↓", leftMargin + 266, feBottom + 1, 80, 11, "#6B21A8");

  // Arrow 2: Upward "AI Critique & Review"
  makeArrow(leftMargin + 360, ifTop, leftMargin + 360, feBottom, "#0284C7", false, false);
  makeLabel("↑ AI Critique", leftMargin + 364, feBottom + 1, 60, 11, "#0369A1");

  // ==========================================
  // 3. INTERFACES LAYER (Slate Gray Strip)
  // ==========================================
  var ifBox = makeBox(leftMargin, ifTop, mainWidth, 22, "#F8FAFC", "#475569");
  var ifTitle = slide.insertTextBox("Interfaces:", leftMargin + 5, ifTop + 2, 58, 12);
  ifTitle.getText().getTextStyle().setFontSize(7).setBold(true).setForegroundColor("#1E293B");
  
  var ifPills = [
    "⚡ Direct SQLite IPC",
    "🌐 WebAssembly OPFS",
    "🔌 REST API (OpenAI)",
    "🖥️ :11434 Localhost",
    "📚 Wikipedia API"
  ];
  var ifWidth = 84;
  for (var j = 0; j < ifPills.length; j++) {
    var p = makeBox(leftMargin + 65 + j * (ifWidth + 4), ifTop + 2, ifWidth, 18, "#FFFFFF", "#64748B");
    p.getText().setText(ifPills[j]);
    p.getText().getTextStyle().setFontSize(5.2).setBold(true).setForegroundColor("#1E293B");
  }

  // ==========================================
  // DIRECTED ARROWS: Interfaces -> Kernel
  // ==========================================
  var ifBottom = ifTop + 22; // 165
  var kTop = 177;
  // Arrow 1: Direct IPC into Tree / Index
  makeArrow(leftMargin + 140, ifBottom, leftMargin + 140, kTop, "#0284C7", false, false);
  makeLabel("Direct IPC ↓", leftMargin + 105, ifBottom + 1, 60, 11, "#0369A1");

  // Arrow 2: FSRS Scheduler Controller
  makeArrow(leftMargin + 335, ifBottom, leftMargin + 335, kTop, "#0284C7", false, false);
  makeLabel("FSRS Scheduler ↓", leftMargin + 340, ifBottom + 1, 75, 11, "#0369A1");

  // ==========================================
  // 4. KERNEL & CORE ENGINE (Sky Blue)
  // ==========================================
  var kernelBox = makeBox(leftMargin, kTop, mainWidth, 121, "#F0F9FF", "#0284C7");
  var kTitle = slide.insertTextBox("Kernel & Core Domain Engine (Swift on macOS / TypeScript + Rust WASM on Web)", leftMargin + 6, kTop + 2, 480, 13);
  kTitle.getText().getTextStyle().setFontSize(7.8).setBold(true).setForegroundColor("#0369A1");

  // Kernel Left Column: Knowledge Tree
  var kLeft = makeBox(leftMargin + 6, kTop + 16, 244, 52, "#FFFFFF", "#38BDF8");
  kLeft.getText().setText("📂 Knowledge Tree & Graph Indexing Engine\n• Hierarchical Knowledge Tree (Subject ➔ Chapter ➔ Topic ➔ Subtopics)\n• Automated AI Downward Outline Generator & In-Note Explainer\n• Bi-directional link parser ([[WikiLinks]]) & transclusion resolver\n• 2D Force-Directed Simulation (0% CPU at rest via Cooling Alpha)");
  kLeft.getText().getTextStyle().setFontSize(5.5).setForegroundColor("#0F172A");
  kLeft.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#0369A1");

  // Kernel Right Column: Review Controllers
  var kRight = makeBox(leftMargin + 258, kTop + 16, 248, 52, "#FFFFFF", "#38BDF8");
  kRight.getText().setText("🧠 Cognitive Retention & Review Controllers\n• Feynman Socratic Controller: tests new cards (reps==0) in plain terms\n• FSRS-4.5 Scheduler: computes Stability (S), Difficulty (D), Retrievability (R)\n• Standard Fast Review Logic: 4-rating intervals without AI delays\n• Memory Palace Walk Controller: visual route pathing & radar beacons");
  kRight.getText().getTextStyle().setFontSize(5.5).setForegroundColor("#0F172A");
  kRight.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#0369A1");

  // Internal Arrow in Kernel: Knowledge Tree -> Review Controllers
  makeArrow(leftMargin + 250, kTop + 42, leftMargin + 258, kTop + 42, "#0284C7", false, false);

  // Kernel Lower Sub-box: Dual-Mode AI & Wikipedia Grounding
  var kAi = makeBox(leftMargin + 6, kTop + 72, 500, 43, "#E0F2FE", "#0284C7");
  kAi.getText().setText("🤖 Dual-Mode AI Engine & Real-Time Wikipedia Grounding Middleware\n• 100% Offline Local AI (< 4 GB RAM): Runs Qwen 2.5 1.5B / Llama 3.2 via Ollama on Mac & WebGPU on browser at $0 cost.\n• Free Online Wikipedia Grounding: Injects real-time encyclopedic facts from Wikipedia REST API to eliminate hallucinations.\n• Optional Cloud Fallback: Native adapters for Google Gemini (Flash) and OpenAI (GPT-4o).");
  kAi.getText().getTextStyle().setFontSize(5.7).setForegroundColor("#0F172A");
  kAi.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#0369A1");

  // Internal Arrow in Kernel: AI Grounding -> Review Controllers
  makeArrow(leftMargin + 382, kTop + 72, leftMargin + 382, kTop + 68, "#0284C7", false, false);

  // ==========================================
  // DIRECTED ARROWS: Kernel -> Workspace & Persistence
  // ==========================================
  var kBottom = kTop + 121; // 298
  var sTop = 312;
  // Arrow 1: Local SQLite Persistence
  makeArrow(leftMargin + 68, kBottom, leftMargin + 68, sTop, "#D97706", false, false);
  makeLabel("Local SQLite WAL ↓", leftMargin + 30, kBottom + 1, 75, 11, "#92400E");

  // Arrow 2: Relational Schema Sync
  makeArrow(leftMargin + 195, kBottom, leftMargin + 195, sTop, "#D97706", false, false);
  makeLabel("Schema Write ↓", leftMargin + 160, kBottom + 1, 70, 11, "#92400E");

  // Arrow 3: FTS5 Full-Text Indexing
  makeArrow(leftMargin + 325, kBottom, leftMargin + 325, sTop, "#D97706", false, false);
  makeLabel("FTS5 Index ↓", leftMargin + 295, kBottom + 1, 60, 11, "#92400E");

  // Arrow 4: Sandboxed Palace Photos & Loci
  makeArrow(leftMargin + 450, kBottom, leftMargin + 450, sTop, "#D97706", false, false);
  makeLabel("Assets Vault ↓", leftMargin + 420, kBottom + 1, 65, 11, "#92400E");

  // ==========================================
  // 5. WORKSPACE & PERSISTENCE (Warm Cream)
  // ==========================================
  var storeBox = makeBox(leftMargin, sTop, mainWidth, 80, "#FFFBEB", "#D97706");
  var sTitle = slide.insertTextBox("Workspace, Storage & Persistence Layer (Local-First Architecture)", leftMargin + 6, sTop + 2, 450, 13);
  sTitle.getText().getTextStyle().setFontSize(7.8).setBold(true).setForegroundColor("#92400E");

  var s1 = makeBox(leftMargin + 6, sTop + 16, 120, 58, "#FFFFFF", "#FBBF24");
  s1.getText().setText("🗄️ SQLite WAL & WASM\n• GRDB SQLite WAL (macOS)\n• SQLite WASM + OPFS (Web)\n• Sub-5ms query response\n• 100% offline-first storage");
  s1.getText().getTextStyle().setFontSize(5.6).setForegroundColor("#451A03");
  s1.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#92400E");

  var s2 = makeBox(leftMargin + 130, sTop + 16, 120, 58, "#FFFFFF", "#FBBF24");
  s2.getText().setText("📊 Relational Schema\n• 'block' & 'doc_link' tables\n• 'flashcard' & 'deck' records\n• 'palace_photo' & 'loci'\n• Parent-child foreign keys");
  s2.getText().getTextStyle().setFontSize(5.6).setForegroundColor("#451A03");
  s2.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#92400E");

  var s3 = makeBox(leftMargin + 254, sTop + 16, 124, 58, "#FFFFFF", "#FBBF24");
  s3.getText().setText("🔎 Full-Text Search (FTS5)\n• SQLite FTS5 virtual tables\n• BM25 Porter-stemmed index\n• Millisecond search across\n  100,000+ notes & blocks");
  s3.getText().getTextStyle().setFontSize(5.6).setForegroundColor("#451A03");
  s3.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#92400E");

  var s4 = makeBox(leftMargin + 382, sTop + 16, 124, 58, "#FFFFFF", "#FBBF24");
  s4.getText().setText("🖼️ Asset Vault & Config\n• Sandboxed Palace photos\n• UserDefaults (macOS)\n• IndexedDB (Web)\n• Physics sliders & color rules");
  s4.getText().getTextStyle().setFontSize(5.6).setForegroundColor("#451A03");
  s4.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#92400E");

  // ==========================================
  // 6. RIGHT SIDEBAR STACK & CONNECTOR ARROWS
  // ==========================================
  // Card 1: External Connectors (Mint Green)
  var c1 = makeBox(sideLeft, 21, sideWidth, 68, "#F0FDF4", "#16A34A");
  c1.getText().setText("🌐 External Connectors\n• Chrome / Safari Web Clipper\n• Wikipedia Open REST API (Live context)\n• Localhost Model Daemon (:11434 Ollama)\n• Zero external tracking / telemetry");
  c1.getText().getTextStyle().setFontSize(5.9).setForegroundColor("#14532D");
  c1.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#16A34A");

  // Dashed connector from Card 1 (External Clipper) down into Interfaces
  var c1MidY = 55;
  var ifMidY = ifTop + 11;
  var seg1 = slide.insertLine(SlidesApp.LineCategory.STRAIGHT, sideLeft, c1MidY, sideLeft - 12, c1MidY);
  seg1.getLineFill().setSolidFill("#16A34A");
  seg1.setWeight(1.3);
  seg1.setDashStyle(SlidesApp.DashStyle.DASH);

  var seg2 = slide.insertLine(SlidesApp.LineCategory.STRAIGHT, sideLeft - 12, c1MidY, sideLeft - 12, ifMidY);
  seg2.getLineFill().setSolidFill("#16A34A");
  seg2.setWeight(1.3);
  seg2.setDashStyle(SlidesApp.DashStyle.DASH);

  var seg3 = slide.insertLine(SlidesApp.LineCategory.STRAIGHT, sideLeft - 12, ifMidY, leftMargin + mainWidth, ifMidY);
  seg3.getLineFill().setSolidFill("#16A34A");
  seg3.setWeight(1.3);
  seg3.setEndArrow(SlidesApp.ArrowStyle.FILL_ARROW);
  seg3.setDashStyle(SlidesApp.DashStyle.DASH);
  makeLabel("Clipper - -►", sideLeft - 20, 92, 55, 10, "#16A34A");

  // Card 2: Cloud Services & Sync (Tan/Amber)
  var c2 = makeBox(sideLeft, 95, sideWidth, 74, "#FFF7ED", "#EA580C");
  c2.getText().setText("☁️ Cloud Services & Sync (Optional)\n• End-to-End Encrypted (E2EE) Sync\n• Peer-to-Peer / WebRTC sync protocols\n• Optional Cloud AI (Gemini / OpenAI)\n• Zero backend database hosting bills ($0)");
  c2.getText().getTextStyle().setFontSize(5.9).setForegroundColor("#7C2D12");
  c2.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#EA580C");

  // Dashed Bi-directional Arrow: Cloud Services <---> Interfaces / Kernel
  var c2MidY = 132;
  var cloudArrow = makeArrow(leftMargin + mainWidth, c2MidY, sideLeft, c2MidY, "#EA580C", true, true);
  makeLabel("◄- -► Sync", sideLeft - 22, c2MidY - 10, 50, 10, "#EA580C");

  // Card 3: Core Open-Source Modules (Sage Green)
  var c3 = makeBox(sideLeft, 175, sideWidth, 120, "#ECFDF5", "#059669");
  c3.getText().setText("⚙️ Core Cognitive Ecosystem\n• FSRS-4.5 Scheduler (State machine)\n• ForceSim-2D (Cooling alpha layout)\n• WikiGround-API (Fact verification)\n• GRDB & SQLite WASM (Local engine)\n• Canvas-GPU (Metal / WebGL rendering)\n• 27 Passing Automated Test Suites");
  c3.getText().getTextStyle().setFontSize(5.9).setForegroundColor("#064E3B");
  c3.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#059669");

  // Dashed Bi-directional Arrow: Core Ecosystem <---> Kernel
  var c3MidY = 235;
  var ecoArrow = makeArrow(leftMargin + mainWidth, c3MidY, sideLeft, c3MidY, "#059669", true, true);
  makeLabel("◄- -► Core", sideLeft - 22, c3MidY - 10, 50, 10, "#059669");

  // Card 4: Legend (Clean White)
  var c4 = makeBox(sideLeft, 303, sideWidth, 89, "#FFFFFF", "#94A3B8");
  c4.getText().setText("📋 Architectural Legend\n──► Solid Arrow: Local synchronous data flow\n- - -► Dashed Arrow: External integration / sync\n• 100% Offline-First: Zero cloud lock-in\n• Native macOS (Live) ➔ Web PWA (Planned)");
  c4.getText().getTextStyle().setFontSize(5.9).setForegroundColor("#1E293B");
  c4.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#0F172A");
}
