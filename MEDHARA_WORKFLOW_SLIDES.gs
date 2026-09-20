function createMedharaWorkflowSlide() {
  var presentation = SlidesApp.getActivePresentation();
  var slide = presentation.appendSlide(SlidesApp.PredefinedLayout.BLANK);
  
  // Dimensions for standard 16:9 widescreen presentation (720 x 405 pt)
  var slideW = 720;
  var slideH = 405;
  var leftMargin = 12;
  
  // Helper: Create rounded rectangle shape using native ROUND_RECTANGLE
  function makeBox(l, t, w, h, bgHex, borderHex) {
    var shape = slide.insertShape(SlidesApp.ShapeType.ROUND_RECTANGLE, l, t, w, h);
    shape.getFill().setSolidFill(bgHex);
    shape.getBorder().getLineFill().setSolidFill(borderHex);
    shape.getBorder().setWeight(1.1);
    return shape;
  }

  // Helper: Create directed line/arrow
  function makeArrow(x1, y1, x2, y2, colorHex, isDashed, isBiDirectional) {
    var line = slide.insertLine(SlidesApp.LineCategory.STRAIGHT, x1, y1, x2, y2);
    line.getLineFill().setSolidFill(colorHex);
    line.setWeight(1.2);
    line.setEndArrow(SlidesApp.ArrowStyle.FILL_ARROW);
    if (isBiDirectional) {
      line.setStartArrow(SlidesApp.ArrowStyle.FILL_ARROW);
    }
    if (isDashed) {
      line.setDashStyle(SlidesApp.DashStyle.DASH);
    }
    return line;
  }

  // Helper: Create label text box
  function makeLabel(text, x, y, w, h, colorHex) {
    var box = slide.insertTextBox(text, x, y, w, h);
    box.getText().getTextStyle().setFontSize(5.2).setBold(true).setForegroundColor(colorHex);
    return box;
  }

  // ==============================================================================
  // TOP TITLE PILL BADGE
  // ==============================================================================
  var titleBadge = makeBox(215, 6, 290, 18, "#4C1D95", "#3B0764");
  var tbText = titleBadge.getText();
  tbText.setText("NOTE-TO-FLASHCARD LEARNING WORKFLOW");
  tbText.getTextStyle().setFontSize(8.5).setBold(true).setForegroundColor("#FFFFFF");
  tbText.getParagraphStyle().setParagraphAlignment(SlidesApp.ParagraphAlignment.CENTER);

  // ==============================================================================
  // SECTION 1: NOTE CREATION & CONVERSION PIPELINE (Top Row: y = 28 to 116 pt)
  // ==============================================================================

  // 1. User Node
  var userBox = makeBox(leftMargin, 38, 44, 48, "#FAF5FF", "#7C3AED");
  userBox.getText().setText("👤\nUSER\nLearner");
  userBox.getText().getTextStyle().setFontSize(5.8).setBold(true).setForegroundColor("#5B21B6");
  var userParas = userBox.getText().getParagraphs();
  for (var up = 0; up < userParas.length; up++) {
    userParas[up].getRange().getParagraphStyle().setParagraphAlignment(SlidesApp.ParagraphAlignment.CENTER);
  }

  // Arrow: User -> Open App
  makeArrow(leftMargin + 44, 62, leftMargin + 52, 62, "#7C3AED", false, false);

  // 2. Open Application Node
  var appBox = makeBox(leftMargin + 52, 35, 68, 54, "#FFFFFF", "#8B5CF6");
  appBox.getText().setText("💻 OPEN APP\n• macOS Native\n• Web PWA (WASM)\nBenefit: 100% offline, zero loading lag");
  appBox.getText().getTextStyle().setFontSize(5.2).setForegroundColor("#1E293B");
  appBox.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#6B21A8");

  // Arrow: Open App -> Create Subject Notes
  makeArrow(leftMargin + 120, 62, leftMargin + 128, 62, "#7C3AED", false, false);

  // 3. Create Subject Notes Container (Lavender)
  var notesBox = makeBox(leftMargin + 128, 27, 344, 70, "#FAF5FF", "#7C3AED");
  var nbTitle = slide.insertTextBox("CREATE HIERARCHICAL KNOWLEDGE TREE (Subject ➔ Chapter ➔ Topics)", leftMargin + 134, 29, 332, 12);
  nbTitle.getText().getTextStyle().setFontSize(6.5).setBold(true).setForegroundColor("#5B21B6");

  // 4 Steps inside Note Container
  var noteSteps = [
    { title: "1. LIST TOPICS", sub: "Outline core syllabus", ben: "Cuts cognitive overload", x: leftMargin + 134 },
    { title: "2. TREE EXPAND", sub: "AI subtopic generation", ben: "10x faster scaffolding", x: leftMargin + 218 },
    { title: "3. DEEP NOTES", sub: "Definitions & [[WikiLinks]]", ben: "Interlinks mental models", x: leftMargin + 302 },
    { title: "4. IN-NOTE AI", sub: "Wikipedia-grounded fact", ben: "0% hallucination risk", x: leftMargin + 386 }
  ];

  for (var i = 0; i < noteSteps.length; i++) {
    var ns = noteSteps[i];
    var sBox = makeBox(ns.x, 43, 80, 48, "#FFFFFF", "#C084FC");
    sBox.getText().setText(ns.title + "\n• " + ns.sub + "\nBenefit: " + ns.ben);
    sBox.getText().getTextStyle().setFontSize(5).setForegroundColor("#1E293B");
    sBox.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#6B21A8");
    if (i < noteSteps.length - 1) {
      makeArrow(ns.x + 80, 67, ns.x + 84, 67, "#7C3AED", false, false);
    }
  }

  // Arrow: Notes Container -> Transformation Stack
  makeArrow(leftMargin + 472, 62, leftMargin + 480, 62, "#7C3AED", false, false);

  // 4. Card Transformation Stack (Right side)
  var trans1 = makeBox(leftMargin + 480, 31, 102, 29, "#FFFFFF", "#A855F7");
  trans1.getText().setText("Concept Isolation\n• Bullet ➔ Concept atom\nBenefit: Micro-learning focus");
  trans1.getText().getTextStyle().setFontSize(4.8).setForegroundColor("#1E293B");
  trans1.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#6B21A8");

  var trans2 = makeBox(leftMargin + 480, 65, 102, 29, "#FFFFFF", "#A855F7");
  trans2.getText().setText("Automated Card Tag\n• 1-to-1 sync with notes\nBenefit: Zero copy-paste work");
  trans2.getText().getTextStyle().setFontSize(4.8).setForegroundColor("#1E293B");
  trans2.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#6B21A8");

  // Vertical arrow between trans1 and trans2
  makeArrow(leftMargin + 531, 60, leftMargin + 531, 65, "#7C3AED", false, false);

  // Arrow: Trans Stack -> 1-Click Conversion Pill
  makeArrow(leftMargin + 582, 62, leftMargin + 590, 62, "#7C3AED", false, false);

  // 5. Single-Click Conversion Pill
  var clickBox = makeBox(leftMargin + 590, 31, 106, 63, "#FFFFFF", "#7C3AED");
  clickBox.getText().setText("⚡ 1-CLICK CONVERT\n• Front: Concept / Prompt\n• Back: Grounded Fact\n• Deck: Grouped by note\nBenefit: Instant study decks; 95% prep time eliminated");
  clickBox.getText().getTextStyle().setFontSize(5).setForegroundColor("#1E293B");
  clickBox.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#5B21A8");

  // ==============================================================================
  // CENTRAL FORK RIBBON (y = 104 to 123 pt)
  // ==============================================================================
  var forkBadge = makeBox(225, 104, 270, 16, "#5B21B6", "#4C1D95");
  var fbText = forkBadge.getText();
  fbText.setText("THREE INTEGRATED COGNITIVE PATHWAYS");
  fbText.getTextStyle().setFontSize(7.5).setBold(true).setForegroundColor("#FFFFFF");
  fbText.getParagraphStyle().setParagraphAlignment(SlidesApp.ParagraphAlignment.CENTER);

  // Downward Fork Arrows to the 3 Columns
  makeArrow(leftMargin + 643, 94, leftMargin + 643, 100, "#7C3AED", false, false); // From clickBox down
  makeArrow(leftMargin + 643, 100, 495, 112, "#7C3AED", false, false); // Into fork ribbon
  
  makeArrow(270, 120, 124, 130, "#0284C7", false, false); // Fork to Col 1
  makeArrow(360, 120, 360, 130, "#16A34A", false, false); // Fork to Col 2
  makeArrow(450, 120, 596, 130, "#D97706", false, false); // Fork to Col 3

  // ==============================================================================
  // SECTION 2: THREE COGNITIVE PATHWAYS (y = 130 to 397 pt)
  // ==============================================================================
  var colW = 224;
  var colGap = 12;
  var col1X = leftMargin;
  var col2X = leftMargin + colW + colGap; // 248
  var col3X = leftMargin + 2 * (colW + colGap); // 484

  // ------------------------------------------------------------------------------
  // PATHWAY 1: STANDARD FSRS-4.5 REVIEW (Sky Blue)
  // ------------------------------------------------------------------------------
  var col1Box = makeBox(col1X, 130, colW, 267, "#F0F9FF", "#0284C7");
  var c1Head = slide.insertTextBox("1. STANDARD FSRS-4.5 REVIEW", col1X + 6, 132, colW - 12, 13);
  c1Head.getText().getTextStyle().setFontSize(7.5).setBold(true).setForegroundColor("#0369A1");
  var c1Sub = slide.insertTextBox("Speed, Spaced Repetition & High-Volume Retention", col1X + 6, 144, colW - 12, 11);
  c1Sub.getText().getTextStyle().setFontSize(5.2).setItalic(true).setForegroundColor("#0284C7");

  var c1Steps = [
    { name: "1. FSRS Due Queue Computation", desc: "Calculates Stability (S), Difficulty (D), Retrievability (R)", ben: "90% retention target with 40% less review time vs Anki SM-2" },
    { name: "2. Prompt & Active Recall", desc: "Front prompt shown; timer runs; user attempts mental recall", ben: "Strengthens neuro-synaptic retrieval pathways before reveal" },
    { name: "3. Rapid Self-Rating (1-4)", desc: "Again, Hard, Good, Easy (< 5 sec per card rapid evaluation)", ben: "Zero AI latency; frictionless high-volume daily reviews" },
    { name: "4. State Machine Interval Update", desc: "FSRS algorithm calculates mathematically optimal next interval", ben: "Flattens Ebbinghaus forgetting curve without over-studying" },
    { name: "5. Interleaved Deck Queueing", desc: "Dynamically interleaves due cards across related subjects", ben: "Prevents contextual blocking; sharpens exam discrimination" }
  ];

  var stepH = 34;
  var stepGap = 6;
  var startY = 158;

  for (var a = 0; a < c1Steps.length; a++) {
    var curY = startY + a * (stepH + stepGap);
    var box = makeBox(col1X + 6, curY, colW - 12, stepH, "#FFFFFF", "#38BDF8");
    box.getText().setText(c1Steps[a].name + "\n• " + c1Steps[a].desc + "\nBenefit: " + c1Steps[a].ben);
    box.getText().getTextStyle().setFontSize(4.9).setForegroundColor("#0F172A");
    box.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#0369A1");
    if (a < c1Steps.length - 1) {
      makeArrow(col1X + colW / 2, curY + stepH, col1X + colW / 2, curY + stepH + stepGap, "#0284C7", false, false);
    }
  }

  var c1Outcome = makeBox(col1X + 6, 362, colW - 12, 28, "#E0F2FE", "#0284C7");
  c1Outcome.getText().setText("🎯 CORE BENEFIT & OUTCOME\n• High-efficiency retention engine (300+ cards/day)\n• 40% fewer reviews needed to maintain 90% memory");
  c1Outcome.getText().getTextStyle().setFontSize(5.2).setForegroundColor("#0C4A6E");
  c1Outcome.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#0369A1");

  // ------------------------------------------------------------------------------
    // ------------------------------------------------------------------------------
  // PATHWAY 2: 2D MEMORY PALACE INTEGRATION (Mint/Emerald Green + Real Photos)
  // ------------------------------------------------------------------------------
  var col2Box = makeBox(col2X, 130, colW, 267, "#F0FDF4", "#16A34A");
  var c2Head = slide.insertTextBox("2. 2D MEMORY PALACE (LOCI)", col2X + 6, 132, colW - 12, 13);
  c2Head.getText().getTextStyle().setFontSize(7.5).setBold(true).setForegroundColor("#15803D");
  var c2Sub = slide.insertTextBox("Visuo-Spatial Encoding & Ancient Method of Loci", col2X + 6, 144, colW - 12, 11);
  c2Sub.getText().getTextStyle().setFontSize(5.2).setItalic(true).setForegroundColor("#16A34A");

  // Helper for Photo Cards with edit icon badge
  function makePhotoCard(x, y, w, h, imgUrl, labelText) {
    var card = makeBox(x, y, w, h, "#FFFFFF", "#16A34A");
    var imgH = h - 13;
    try {
      slide.insertImage(imgUrl, x + 2, y + 2, w - 4, imgH);
    } catch (e) {
      var ph = slide.insertShape(SlidesApp.ShapeType.RECTANGLE, x + 2, y + 2, w - 4, imgH);
      ph.getFill().setSolidFill("#DCFCE7");
      ph.getBorder().setTransparent();
    }
    // Label text below photo
    var lbl = slide.insertTextBox(labelText, x, y + imgH, w, 11);
    lbl.getText().getTextStyle().setFontSize(5.2).setBold(true).setForegroundColor("#15803D");
    lbl.getText().getParagraphStyle().setParagraphAlignment(SlidesApp.ParagraphAlignment.CENTER);

    // Edit pencil badge in corner of image
    var badge = makeBox(x + w - 14, y + imgH - 12, 12, 10, "#FFFFFF", "#16A34A");
    badge.getText().setText("✏️");
    badge.getText().getTextStyle().setFontSize(4.5);
    badge.getText().getParagraphStyle().setParagraphAlignment(SlidesApp.ParagraphAlignment.CENTER);
    return card;
  }

  // 2x2 Photo Grid
  var photoW = 98;
  var photoH = 46;
  var pX1 = col2X + 7;
  var pX2 = col2X + 119;
  var pY1 = 158;
  var pY2 = 210;

  // Photo 1: WINDOWS
  makePhotoCard(pX1, pY1, photoW, photoH, "https://images.unsplash.com/photo-1513694203232-719a280e022f?w=400&auto=format&fit=crop&q=80", "WINDOWS");
  // Photo 2: LEFT WALL
  makePhotoCard(pX2, pY1, photoW, photoH, "https://images.unsplash.com/photo-1513519245088-0e12902e5a38?w=400&auto=format&fit=crop&q=80", "LEFT WALL");
  // Arrow Photo 1 -> Photo 2
  makeArrow(pX1 + photoW, pY1 + photoH / 2, pX2, pY1 + photoH / 2, "#16A34A", false, false);

  // Arrow Photo 2 down to Photo 4
  makeArrow(pX2 + photoW / 2, pY1 + photoH, pX2 + photoW / 2, pY2, "#16A34A", false, false);

  // Photo 3: BALCONY / GALLERY
  makePhotoCard(pX1, pY2, photoW, photoH, "https://images.unsplash.com/photo-1577083552431-6e5fd01aa342?w=400&auto=format&fit=crop&q=80", "BALCONY");
  // Photo 4: LOWER FLOORS / STAIRS
  makePhotoCard(pX2, pY2, photoW, photoH, "https://images.unsplash.com/photo-1505691938895-1758d7feb511?w=400&auto=format&fit=crop&q=80", "LOWER FLOORS");
  // Arrow Photo 3 -> Photo 4
  makeArrow(pX1 + photoW, pY2 + photoH / 2, pX2, pY2 + photoH / 2, "#16A34A", false, false);

  // Arrow from Photo grid down into interaction steps
  makeArrow(col2X + colW / 2, pY2 + photoH, col2X + colW / 2, 264, "#16A34A", false, false);

  // Loci Anchoring & Navigation Steps (Matching original diagram flow)
  var lociRowW = 100;
  var lociRowH = 25;

  // Step A: Associated Cards Appear -> User Prompts
  var lA1 = makeBox(pX1, 264, lociRowW, lociRowH, "#FFFFFF", "#4ADE80");
  lA1.getText().setText("Associated Cards Appear\n• Due cards queued by room");
  lA1.getText().getTextStyle().setFontSize(4.7).setForegroundColor("#0F172A");
  lA1.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#15803D");

  var lA2 = makeBox(pX2, 264, lociRowW, lociRowH, "#FFFFFF", "#4ADE80");
  lA2.getText().setText("User Prompts Questions\n• Active query generation");
  lA2.getText().getTextStyle().setFontSize(4.7).setForegroundColor("#0F172A");
  lA2.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#15803D");
  makeArrow(pX1 + lociRowW, 276, pX2, 276, "#16A34A", false, false);

  // Arrow A2 down to B1
  makeArrow(pX2 + lociRowW / 2, 289, pX1 + lociRowW / 2, 296, "#16A34A", false, false);

  // Step B: Select Location -> System Prompts
  var lB1 = makeBox(pX1, 296, lociRowW, lociRowH, "#FFFFFF", "#4ADE80");
  lB1.getText().setText("User Selects Location\n• Pin to Locus (e.g. Window)");
  lB1.getText().getTextStyle().setFontSize(4.7).setForegroundColor("#0F172A");
  lB1.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#15803D");

  var lB2 = makeBox(pX2, 296, lociRowW, lociRowH, "#FFFFFF", "#4ADE80");
  lB2.getText().setText("System Visual Prompts\n• What kind of info/motif?");
  lB2.getText().getTextStyle().setFontSize(4.7).setForegroundColor("#0F172A");
  lB2.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#15803D");
  makeArrow(pX1 + lociRowW, 308, pX2, 308, "#16A34A", false, false);

  // Arrow B2 down to C1
  makeArrow(pX2 + lociRowW / 2, 321, pX1 + lociRowW / 2, 328, "#16A34A", false, false);

  // Step C: Attach Imagery -> Answers Definition
  var lC1 = makeBox(pX1, 328, lociRowW, lociRowH, "#FFFFFF", "#4ADE80");
  lC1.getText().setText("Attach Vivid Imagery\n• e.g. Window with Dragon");
  lC1.getText().getTextStyle().setFontSize(4.7).setForegroundColor("#0F172A");
  lC1.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#15803D");

  var lC2 = makeBox(pX2, 328, lociRowW, lociRowH, "#FFFFFF", "#4ADE80");
  lC2.getText().setText("User Answers Def\n• Dual-coding active recall");
  lC2.getText().getTextStyle().setFontSize(4.7).setForegroundColor("#0F172A");
  lC2.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#15803D");
  makeArrow(pX1 + lociRowW, 340, pX2, 340, "#16A34A", false, false);

  // Pathway 2 Outcome Box
  var c2Outcome = makeBox(col2X + 6, 359, colW - 12, 31, "#DCFCE7", "#16A34A");
  c2Outcome.getText().setText("🏛️ CORE BENEFIT & OUTCOME\n• 2-3x higher recall for complex structures & legal/medical steps\n• Evolutionarily ancient spatial hippocampus memory prevents mixing facts");
  c2Outcome.getText().getTextStyle().setFontSize(5).setForegroundColor("#14532D");
  c2Outcome.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#15803D");

  // ------------------------------------------------------------------------------
  // PATHWAY 3: SOCRATIC FEYNMAN TECHNIQUE (Warm Amber/Gold)
  // ------------------------------------------------------------------------------
  var col3Box = makeBox(col3X, 130, colW, 267, "#FFFBEB", "#D97706");
  var c3Head = slide.insertTextBox("3. SOCRATIC FEYNMAN TECHNIQUE", col3X + 6, 132, colW - 12, 13);
  c3Head.getText().getTextStyle().setFontSize(7.5).setBold(true).setForegroundColor("#B45309");
  var c3Sub = slide.insertTextBox("Deep Understanding & Metacognitive Gap Discovery", col3X + 6, 144, colW - 12, 11);
  c3Sub.getText().getTextStyle().setFontSize(5.2).setItalic(true).setForegroundColor("#D97706");

  var c3Steps = [
    { name: "1. First-Rep Detection (reps == 0)", desc: "Triggers automatically when encountering newly created card", ben: "Catches misconceptions before bad habits or rote memory form" },
    { name: "2. Plain-English Explanation", desc: "User types answer explaining concept to a complete beginner", ben: "Eliminates illusion of explanatory depth & forces clarity" },
    { name: "3. Dual-Mode AI Socratic Review", desc: "Evaluated by local SLM (Qwen/Llama) + real-time Wikipedia fact", ben: "100% verified factual feedback with zero hallucination risk" },
    { name: "4. Adaptive Socratic Follow-Up", desc: "AI probes weak links, missing nuances, and asks 'Why?'", ben: "Drills into hidden blind spots until understanding is solid" },
    { name: "5. Metacognitive Approval & Release", desc: "Once passed, card graduates into the fast FSRS review rotation", ben: "Guarantees only deeply understood concepts enter memory queue" }
  ];

  for (var c = 0; c < c3Steps.length; c++) {
    var curYc = startY + c * (stepH + stepGap);
    var boxC = makeBox(col3X + 6, curYc, colW - 12, stepH, "#FFFFFF", "#FBBF24");
    boxC.getText().setText(c3Steps[c].name + "\n• " + c3Steps[c].desc + "\nBenefit: " + c3Steps[c].ben);
    boxC.getText().getTextStyle().setFontSize(4.9).setForegroundColor("#0F172A");
    boxC.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#B45309");
    if (c < c3Steps.length - 1) {
      makeArrow(col3X + colW / 2, curYc + stepH, col3X + colW / 2, curYc + stepH + stepGap, "#D97706", false, false);
    }
  }

  var c3Outcome = makeBox(col3X + 6, 362, colW - 12, 28, "#FEF3C7", "#D97706");
  c3Outcome.getText().setText("🧠 CORE BENEFIT & OUTCOME\n• Converts shallow memorization into robust mental models\n• Pinpoints exact cognitive gaps with tailored Socratic feedback");
  c3Outcome.getText().getTextStyle().setFontSize(5.2).setForegroundColor("#78350F");
  c3Outcome.getText().getParagraphs()[0].getRange().getTextStyle().setBold(true).setForegroundColor("#B45309");

  // ==============================================================================
  // CROSS-PATHWAY SYNERGY CONNECTORS (Dashed Lines)
  // ==============================================================================
  // Synergy 1: From FSRS Lapsed Cards -> Feynman Technique
  var syn1 = makeArrow(col1X + colW, 285, col3X, 285, "#64748B", true, false);
  makeLabel("Escalate Lapsed Cards to Feynman ➔", col2X + 10, 276, 160, 10, "#475569");

  // Synergy 2: From Memory Palace Loci Mastery -> FSRS
  var syn2 = makeArrow(col2X, 325, col1X + colW, 325, "#64748B", true, false);
  makeLabel("◄- - Sync Loci Recall into FSRS Stability", col1X + colW - 14, 316, 150, 10, "#475569");
}
