function createMedharaTechStackSlide() {
  var presentation = SlidesApp.getActivePresentation();
  var slide = presentation.appendSlide(SlidesApp.PredefinedLayout.BLANK);
  
  // Slide dimensions: Standard 16:9 widescreen (720 x 405 pt)
  var slideW = 720;
  var slideH = 405;
  var leftMargin = 16;
  var usableW = slideW - 2 * leftMargin; // 688 pt
  
  // Helper: Create rounded rectangle box
  function makeBox(l, t, w, h, bgHex, borderHex) {
    var shape = slide.insertShape(SlidesApp.ShapeType.ROUND_RECTANGLE, l, t, w, h);
    shape.getFill().setSolidFill(bgHex);
    shape.getBorder().getLineFill().setSolidFill(borderHex);
    shape.getBorder().setWeight(1.1);
    return shape;
  }

  // Helper: Create small badge
  function makeBadge(text, l, t, w, h, bgHex, textHex) {
    var b = makeBox(l, t, w, h, bgHex, bgHex);
    b.getText().setText(text);
    b.getText().getTextStyle().setFontSize(4.6).setBold(true).setForegroundColor(textHex);
    b.getText().getParagraphStyle().setParagraphAlignment(SlidesApp.ParagraphAlignment.CENTER);
    return b;
  }

  // ==============================================================================
  // TOP TITLE PILL BADGE
  // ==============================================================================
  var titleBadge = makeBox(200, 6, 320, 18, "#1E3A8A", "#172554");
  var tbText = titleBadge.getText();
  tbText.setText("MEDHARA — ECOSYSTEM & TECHNOLOGY STACK");
  tbText.getTextStyle().setFontSize(8.5).setBold(true).setForegroundColor("#FFFFFF");
  tbText.getParagraphStyle().setParagraphAlignment(SlidesApp.ParagraphAlignment.CENTER);

  // Layout parameters for 5 horizontal tiers
  var startY = 28;
  var rowH = 68;
  var rowGap = 7;
  var colW = 166;
  var colGap = 8;

  // ------------------------------------------------------------------------------
  // TIER DATA: 5 Tiers x 4 Columns
  // ------------------------------------------------------------------------------
  var tiers = [
    {
      label: "1. CLIENTS & PLATFORMS",
      color: "#4338CA",
      items: [
        { icon: "💻", title: "macOS Desktop", badge: "LIVE NOW", badgeBg: "#DCFCE7", badgeFg: "#166534", sub: "SwiftUI & AppKit\n• 120 FPS Metal GPU Canvas\n• In-process SQLite concurrency", bg: "#FAF5FF", border: "#7C3AED" },
        { icon: "🌐", title: "Web PWA", badge: "PLANNED", badgeBg: "#DBEAFE", badgeFg: "#1E40AF", sub: "Next.js / Vite SPA\n• WebGL Canvas acceleration\n• WebGPU local AI inference", bg: "#F0F9FF", border: "#0284C7" },
        { icon: "📱", title: "iOS / iPadOS", badge: "PLANNED", badgeBg: "#DBEAFE", badgeFg: "#1E40AF", sub: "Universal SwiftUI Target\n• Apple Pencil spatial drawing\n• Mobile touch palace radar", bg: "#F0FDF4", border: "#16A34A" },
        { icon: "⚡", title: "Web Clipper", badge: "PLANNED", badgeBg: "#FEF3C7", badgeFg: "#92400E", sub: "Chrome / Safari Extension\n• 1-click note capture\n• Wikipedia instant import", bg: "#FFF7ED", border: "#EA580C" }
      ]
    },
    {
      label: "2. PROGRAMMING LANGUAGES & RUNTIMES",
      color: "#0369A1",
      items: [
        { icon: "🟠", title: "Swift 6 & Metal", badge: "macOS Native", badgeBg: "#FFEDD5", badgeFg: "#9A3412", sub: "Strict concurrency (Actors)\n• Zero garbage collection lag\n• Direct Apple Silicon GPU calls", bg: "#FFF7ED", border: "#EA580C" },
        { icon: "🔷", title: "TypeScript & React", badge: "Web PWA", badgeBg: "#DBEAFE", badgeFg: "#1E40AF", sub: "Strict type contracts\n• Virtual DOM reactive state\n• Cross-browser consistency", bg: "#EFF6FF", border: "#2563EB" },
        { icon: "⚙️", title: "Rust & WASM", badge: "Web PWA", badgeBg: "#FEF3C7", badgeFg: "#92400E", sub: "WebAssembly SQLite engine\n• High-speed graph physics\n• Memory-safe sandboxing", bg: "#FFFBEB", border: "#D97706" },
        { icon: "🦙", title: "Ollama & WebGPU", badge: "Cross-Platform", badgeBg: "#F3E8FF", badgeFg: "#6B21A8", sub: "Localhost :11434 daemon\n• Qwen 2.5 1.5B (< 4 GB RAM)\n• 100% offline $0 inference", bg: "#FAF5FF", border: "#7C3AED" }
      ]
    },
    {
      label: "3. PROTOCOLS & INTEGRATION INTERFACES",
      color: "#0F766E",
      items: [
        { icon: "⚡", title: "Direct SQLite IPC", badge: "macOS Native", badgeBg: "#FFEDD5", badgeFg: "#9A3412", sub: "Zero-copy GRDB pointers\n• Sub-1ms query execution\n• In-process memory mapped", bg: "#F0F9FF", border: "#0284C7" },
        { icon: "📁", title: "WASM OPFS Bridge", badge: "Web PWA", badgeBg: "#DBEAFE", badgeFg: "#1E40AF", sub: "Origin Private File System\n• Bypasses slow IndexedDB\n• High-speed multithreaded I/O", bg: "#F0FDF4", border: "#059669" },
        { icon: "🔌", title: "MCP Agent Protocol", badge: "Standard", badgeBg: "#F3E8FF", badgeFg: "#6B21A8", sub: "Model Context Protocol (MCP)\n• Stdio & SSE tool endpoints\n• AI agent orchestration", bg: "#FAF5FF", border: "#6D28D9" },
        { icon: "📚", title: "Wikipedia REST API", badge: "Public API", badgeBg: "#E2E8F0", badgeFg: "#334155", sub: "Open encyclopedic endpoints\n• Live fact-grounding context\n• 0% AI hallucination rate", bg: "#F8FAFC", border: "#475569" }
      ]
    },
    {
      label: "4. STORAGE, PERSISTENCE & SCHEMAS",
      color: "#B45309",
      items: [
        { icon: "🗄️", title: "SQLite WAL Engine", badge: "Core DB", badgeBg: "#DBEAFE", badgeFg: "#1E40AF", sub: "Write-Ahead Logging (WAL)\n• FTS5 BM25 Porter-stem search\n• Instant search across 100k+ notes", bg: "#F0F9FF", border: "#0284C7" },
        { icon: "📊", title: "Domain Relational DB", badge: "medhara.db", badgeBg: "#FEF3C7", badgeFg: "#92400E", sub: "Normalized entity tables:\n• 'block', 'doc_link', 'deck'\n• Parent-child tree hierarchy", bg: "#FFFBEB", border: "#D97706" },
        { icon: "🧠", title: "Cognitive State DB", badge: "flashcards.db", badgeBg: "#DCFCE7", badgeFg: "#166534", sub: "FSRS-4.5 state machine:\n• Stability (S) & Difficulty (D)\n• Interval history tracking", bg: "#F0FDF4", border: "#16A34A" },
        { icon: "🖼️", title: "Sandboxed Asset Vault", badge: "Local Vault", badgeBg: "#E2E8F0", badgeFg: "#334155", sub: "Multi-photo palace storage\n• SVG coordinate overlays\n• Zero cloud upload telemetry", bg: "#F8FAFC", border: "#64748B" }
      ]
    },
    {
      label: "5. CORE COGNITIVE ENGINES & MODULES",
      color: "#15803D",
      items: [
        { icon: "📈", title: "FSRS-4.5 Scheduler", badge: "Cognitive Core", badgeBg: "#DBEAFE", badgeFg: "#1E40AF", sub: "Modern DSR state machine\n• 90% retention targeting\n• 40% less review time than SM-2", bg: "#F0F9FF", border: "#0284C7" },
        { icon: "🕸️", title: "ForceSim-2D GPU", badge: "Graph Engine", badgeBg: "#F3E8FF", badgeFg: "#6B21A8", sub: "Barnes-Hut quadtree repulsion\n• Hooke spring bi-directional links\n• Cooling alpha (0% idle CPU)", bg: "#FAF5FF", border: "#7C3AED" },
        { icon: "🏛️", title: "2D Memory Palace", badge: "Spatial Loci", badgeBg: "#DCFCE7", badgeFg: "#166534", sub: "Multi-photo coordinate engine\n• Sequential route walk & radar\n• 2-3x higher visual recall", bg: "#F0FDF4", border: "#16A34A" },
        { icon: "🧪", title: "27 Test Suites", badge: "100% Passing", badgeBg: "#DCFCE7", badgeFg: "#166534", sub: "Automated regression tests\n• FSRS, Graph physics & IPC\n• Bullet-proof architecture", bg: "#ECFDF5", border: "#059669" }
      ]
    }
  ];

  for (var r = 0; r < tiers.length; r++) {
    var tData = tiers[r];
    var curY = startY + r * (rowH + rowGap);
    
    // Tier category label
    var catLbl = slide.insertTextBox(tData.label, leftMargin, curY - 1, 300, 11);
    catLbl.getText().getTextStyle().setFontSize(5.8).setBold(true).setForegroundColor(tData.color);

    // 4 Column Items
    for (var c = 0; c < tData.items.length; c++) {
      var item = tData.items[c];
      var itemX = leftMargin + c * (colW + colGap);
      var itemY = curY + 11;
      var boxH = rowH - 12;

      // Base card
      var card = makeBox(itemX, itemY, colW, boxH, item.bg, item.border);

      // Icon & Title Line
      var tBox = slide.insertTextBox(item.icon + " " + item.title, itemX + 4, itemY + 2, colW - 54, 13);
      tBox.getText().getTextStyle().setFontSize(6.2).setBold(true).setForegroundColor("#0F172A");

      // Badge on top right of card
      makeBadge(item.badge, itemX + colW - 48, itemY + 3, 44, 10, item.badgeBg, item.badgeFg);

      // Subtitle / Description points
      var descBox = slide.insertTextBox(item.sub, itemX + 4, itemY + 15, colW - 8, 36);
      descBox.getText().getTextStyle().setFontSize(4.8).setForegroundColor("#334155");
    }

    // Dotted separator line between tiers
    if (r < tiers.length - 1) {
      var divY = curY + rowH + 2.5;
      var div = slide.insertLine(SlidesApp.LineCategory.STRAIGHT, leftMargin, divY, leftMargin + usableW, divY);
      div.getLineFill().setSolidFill("#CBD5E1");
      div.setWeight(0.8);
      div.setDashStyle(SlidesApp.DashStyle.DOT);
    }
  }
}
