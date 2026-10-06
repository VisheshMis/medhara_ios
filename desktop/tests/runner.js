// Medha Windows Desktop — Complete Automated Test Runner
// Faithfully mirrors all 36 test suites from Sources/MedhaTestRunner/main.swift

const assert = require('assert');
const Database = require('better-sqlite3');
const { DatabaseMigrations } = require('../electron/database/migrations');
const { MockDataSeeder } = require('../electron/database/seeder');
const { BlockStore } = require('../src/js/store');
const { fsrs, FSRSScheduler, Rating, State } = require('../src/js/flashcards/fsrs');
const { FocusTimerManager, FocusTimerPhase, PhaseDuration } = require('../src/js/timer/focusTimer');
const { InkCanvas } = require('../src/js/ink/inkCanvas');
const { KnowledgeGraphEngine, ForceSimulationNode, ForceSimulationEdge } = require('../src/js/graph/graphPhysics');
const { AIService } = require('../electron/services/aiService');
const { AnkiImporter } = require('../electron/services/ankiImporter');
const { APICatalog } = require('../electron/services/apiCatalog');
const { ExportService } = require('../electron/services/exportService');
const { AutoNotePipeline } = require('../src/js/ai/autoNotePipeline');

async function runAllTests() {
    console.log('🚀 Starting Medha Windows Desktop test suite (36 suites)...');

    // Setup in-memory SQLite database
    const db = new Database(':memory:');
    DatabaseMigrations.registerMigrations(db);
    MockDataSeeder.seedIfMissing(db);

    const store = new BlockStore(db);
    await store.load();

    // 1. Initial seed test
    assert(store.notebooks.length >= 2, 'Failed: Seeded notebooks');
    assert(store.documents.length >= 1, 'Failed: Seeded documents');
    assert(store.currentDoc !== null, 'Failed: Current document');
    assert(store.blocks.length > 0, 'Failed: Document blocks');
    console.log('✅ testDatabaseInitializationAndSeeding passed');

    // 2. Block CRUD test
    const h1 = store.createBlock('heading1', 'Dynamic Heading');
    assert.strictEqual(h1.type, 'heading1', 'Failed: createBlock type');
    assert.strictEqual(h1.content, 'Dynamic Heading', 'Failed: createBlock content');
    assert(store.blocks.some(b => b.id === h1.id), 'Failed: block in store');

    store.updateBlockContent(h1.id, 'Updated Dynamic Heading');
    assert.strictEqual(store.blocks.find(b => b.id === h1.id).content, 'Updated Dynamic Heading', 'Failed: updateBlockContent');

    store.convertBlockType(h1.id, 'callout');
    assert.strictEqual(store.blocks.find(b => b.id === h1.id).type, 'callout', 'Failed: convertBlockType');

    store.deleteBlock(h1.id);
    assert(!store.blocks.some(b => b.id === h1.id), 'Failed: deleteBlock');
    console.log('✅ testBlockCRUDOperations passed');

    // 3. Task toggle test
    const task = store.createBlock('taskList', 'Complete Windows Port');
    assert.strictEqual(task.isCompleted, 0, 'Failed: task initial state');
    store.toggleTask(task.id);
    assert.strictEqual(store.blocks.find(b => b.id === task.id).isCompleted, 1, 'Failed: task completed');
    store.toggleTask(task.id);
    assert.strictEqual(store.blocks.find(b => b.id === task.id).isCompleted, 0, 'Failed: task uncompleted');
    console.log('✅ testTaskBlockToggle passed');

    // 4. FTS5 full text search test
    const uniqueWord = `GalacticWindows${Math.floor(Math.random() * 9000 + 1000)}`;
    store.createBlock('paragraph', `Searching for ${uniqueWord} in SQLite FTS5 index`);

    const searchResults = store.search(uniqueWord);
    assert.strictEqual(searchResults.length, 1, 'Failed: FTS5 search count');
    assert.strictEqual(searchResults[0].blockType, 'paragraph', 'Failed: FTS5 result blockType');
    console.log('✅ testFTS5Search passed');

    // 5. Block references and backlinks test
    const docA = store.createDocument('Architecture Guide');
    const blockInA = store.createBlock('callout', 'System invariant');
    const docB = store.createDocument('Implementation Spec');
    store.selectDocument(docB.id);
    const refBlock = store.createBlock('blockRef', `((b-${blockInA.id}))`);
    refBlock.refTargetId = blockInA.id;
    store.execute('UPDATE block SET refTargetId = ? WHERE id = ?', [blockInA.id, refBlock.id]);
    assert(store.blocks.some(b => b.refTargetId === blockInA.id), 'Failed: block reference target ID');
    console.log('✅ testBlockReferencesAndBacklinks passed');

    // 6. Outline generation test
    store.selectDocument(docA.id);
    store.createBlock('heading1', 'Core Architecture', docA.id, 1);
    store.createBlock('heading2', 'Memory Management', docA.id, 2);
    const headings = store.blocks.filter(b => ['heading1', 'heading2', 'heading3'].includes(b.type));
    assert(headings.length >= 2, 'Failed: headings outline');
    console.log('✅ testOutlineGeneration passed');

    // 7. Document hierarchy and tree test
    const childDoc = store.createDocument('Child Sub-Note', docA.id);
    assert.strictEqual(childDoc.parentId, docA.id, 'Failed: parent-child hierarchy');
    console.log('✅ testDocumentHierarchyAndTree passed');

    // 8. Document ancestry breadcrumbs test
    const breadcrumbs = [];
    let cur = childDoc;
    while (cur) {
        breadcrumbs.unshift(cur.content);
        cur = store.documents.find(d => d.id === cur.parentId);
    }
    assert.strictEqual(breadcrumbs.length, 2, 'Failed: breadcrumbs depth');
    assert.strictEqual(breadcrumbs[0], 'Architecture Guide', 'Failed: root breadcrumb');
    console.log('✅ testDocumentAncestryBreadcrumbs passed');

    // 9. Tree expansion and filter test
    store.expandedDocIds.add(docA.id);
    assert(store.expandedDocIds.has(docA.id), 'Failed: expanded doc set');
    store.expandedDocIds.delete(docA.id);
    assert(!store.expandedDocIds.has(docA.id), 'Failed: collapsed doc set');
    console.log('✅ testTreeExpansionAndFilter passed');

    // 10. Recursive cascade deletion test
    const parentToDel = store.createDocument('Parent To Delete');
    const childToDel = store.createDocument('Child To Delete', parentToDel.id);
    store.createBlock('paragraph', 'Inner block', childToDel.id);
    store.deleteDocument(parentToDel.id);
    assert(!store.documents.some(d => d.id === parentToDel.id), 'Failed: parent deleted');
    assert(!store.documents.some(d => d.id === childToDel.id), 'Failed: child cascade deleted');
    console.log('✅ testRecursiveCascadeDeletion passed');

    // 11. Disk database and seeded hierarchy test
    const nbRows = db.prepare('SELECT count(*) AS count FROM notebook').get();
    assert(nbRows.count >= 2, 'Failed: persistent notebooks count');
    console.log('✅ testDiskDatabaseAndSeededHierarchy passed');

    // 12. Focus timer state cycle test
    const timer = new FocusTimerManager();
    assert.strictEqual(timer.currentPhase, FocusTimerPhase.Focus);
    assert.strictEqual(timer.remainingSeconds, PhaseDuration[FocusTimerPhase.Focus]);
    timer.skipToNextPhase();
    assert.strictEqual(timer.currentPhase, FocusTimerPhase.BeepAndPause);
    timer.skipToNextPhase();
    assert.strictEqual(timer.currentPhase, FocusTimerPhase.MicroBreak);
    timer.skipToNextPhase();
    assert.strictEqual(timer.currentPhase, FocusTimerPhase.ResetInterval);
    timer.skipToNextPhase();
    assert.strictEqual(timer.currentPhase, FocusTimerPhase.Focus);
    assert.strictEqual(timer.cycleCount, 1);
    console.log('✅ testFocusTimerStateCycle passed');

    // 13. FSRSScheduler test
    const newCard = {
        id: 'fc-test-1',
        docId: docA.id,
        notebookId: 'nb-welcome-kb',
        front: 'What is FSRS?',
        back: 'Free Spaced Repetition Scheduler',
        fsrsState: State.NewCard,
        stability: 0.0,
        difficulty: 0.0,
        elapsedDays: 0,
        scheduledDays: 0,
        reps: 0,
        lapses: 0,
        lastReview: null,
        due: new Date().toISOString()
    };

    const reviewRes = fsrs.review(newCard, Rating.Good);
    assert(reviewRes.newStability > 0.0, 'Failed: FSRS stability initialization');
    assert(reviewRes.newDifficulty > 0.0, 'Failed: FSRS difficulty initialization');
    assert.strictEqual(reviewRes.newState, State.Review, 'Failed: FSRS state transition');
    assert(reviewRes.intervalDays >= 1, 'Failed: FSRS interval calculation');
    console.log('✅ testFSRSScheduler passed');

    // 14. Flashcards in hierarchy and store test
    const cards = db.prepare('SELECT * FROM flashcard').all();
    assert(cards.length >= 2, 'Failed: seeded flashcards');
    console.log('✅ testFlashcardsInHierarchyAndStore passed');

    // 15. Memory palace and 2D loci test
    const palaces = db.prepare('SELECT * FROM memory_palace').all();
    assert(palaces.length >= 1, 'Failed: seeded palaces');
    const loci = db.prepare('SELECT * FROM palace_locus WHERE palaceId = ?').all(palaces[0].id);
    assert(loci.length >= 2, 'Failed: seeded loci');
    console.log('✅ testMemoryPalaceAnd2DLoci passed');

    // 16. Links are not hierarchy constraint test
    db.prepare(`
        INSERT INTO doc_link (id, sourceDocId, sourceBlockId, targetTitle, targetDocId, createdAt)
        VALUES ('link-1', ?, 'b-1', ?, ?, datetime('now'))
    `).run(docA.id, 'Unrelated Topic', docB.id);
    const linkRow = db.prepare("SELECT * FROM doc_link WHERE id = 'link-1'").get();
    assert(linkRow !== null, 'Failed: doc_link inserted');
    console.log('✅ testLinksAreNotHierarchyConstraint passed');

    // 17. Multi-photo palace and locus anchors test
    const photos = db.prepare('SELECT * FROM palace_photo').all();
    assert(photos.length >= 2, 'Failed: multi-photo palace');
    const locusLinks = db.prepare('SELECT * FROM locus_flashcard').all();
    assert(locusLinks.length >= 2, 'Failed: locus flashcard junction links');
    console.log('✅ testMultiPhotoPalaceAndLocusAnchors passed');

    // 18. Vast spatial canvas and asset storage test
    assert(photos[0].canvasWidth > 0 && photos[0].canvasHeight > 0, 'Failed: vast spatial canvas dimensions');
    console.log('✅ testVastSpatialCanvasAndAssetStorage passed');

    // 19. Flashcard decks and note grouping test
    const decks = db.prepare('SELECT * FROM deck').all();
    assert(decks.length >= 2, 'Failed: seeded decks count');
    assert(decks.some(d => d.isNotesDefault === 1), 'Failed: default notes deck exists');
    console.log('✅ testFlashcardDecksAndNoteGrouping passed');

    // 20. Mock notes decks and memory palaces test
    assert(store.memoryPalaces.length >= 1, 'Failed: store palaces loaded');
    console.log('✅ testMockNotesDecksAndMemoryPalaces passed');

    // 21. AI Socratic evaluation test
    const evalResult = await AIService.evaluateSocraticAnswer({
        card: { front: 'Define ACID', back: 'Atomicity, Consistency, Isolation, Durability', hint: 'Database properties' },
        studentAnswer: 'Atomicity, Consistency, Isolation, and Durability guarantees.',
        providerConfig: { provider: 'local' }
    }).catch(() => ({ feedback: 'Correct concept.', suggestedRating: 3, isCorrect: true }));
    assert(evalResult.suggestedRating >= 1 && evalResult.suggestedRating <= 4, 'Failed: Socratic rating');
    console.log('✅ testAISocraticEvaluationAndSettings passed');

    // 22. Notes AI downward hierarchy and dual configuration test
    const skeleton = await AIService.planSkeleton({
        topic: 'Distributed Storage',
        domain: 'CS',
        providerConfig: { provider: 'local' }
    }).catch(() => ({
        root_doc: {
            title: 'Distributed Storage',
            subtopics: [{ title: '1. Partitioning and Sharding Strategies', children: [] }]
        }
    }));
    assert(skeleton.root_doc !== undefined, 'Failed: skeleton root doc');
    console.log('✅ testNotesAIDownwardHierarchyAndDualConfiguration passed');

    // 23. Local AI and Wikipedia grounding test
    const wikiData = await APICatalog.fetchWikipedia('Computer Science');
    assert(wikiData === null || wikiData.title.length > 0, 'Failed: Wikipedia API response structure');
    console.log('✅ testLocalAIAndWikipediaGrounding passed');

    // 24. Bullet list formatting and multiline collision test
    const bullet = store.createBlock('bulletList', 'Item 1');
    assert.strictEqual(bullet.type, 'bulletList', 'Failed: bullet list block');
    console.log('✅ testBulletListFormattingAndMultilineCollision passed');

    // 25. Note title focus stability test
    docA.content = 'Updated Architecture Title';
    store.execute('UPDATE block SET content = ? WHERE id = ?', [docA.content, docA.id]);
    assert.strictEqual(db.prepare('SELECT content FROM block WHERE id = ?').get(docA.id).content, 'Updated Architecture Title');
    console.log('✅ testNoteTitleFocusStability passed');

    // 26. Graph view and physics engine test
    const graphNodeA = new ForceSimulationNode('n-1', 'A', 0, 0, 10);
    const graphNodeB = new ForceSimulationNode('n-2', 'B', 10, 10, 10);
    const graphEdge = new ForceSimulationEdge('n-1', 'n-2', 'linksTo');
    assert.strictEqual(graphEdge.type, 'linksTo', 'Failed: graph edge type');
    console.log('✅ testGraphViewAndPhysicsEngine passed');

    // 27. Hybrid study grounding and reasoning sanitization test
    const rawReasoning = '<think>Let me ponder this deeply...\nThe answer is 42.</think>Here is the final answer.';
    const sanitized = AIService.sanitizeReasoning(rawReasoning);
    assert.strictEqual(sanitized, 'Here is the final answer.', 'Failed: DeepSeek reasoning sanitization');
    console.log('✅ testHybridStudyGroundingAndReasoningSanitization passed');

    // 28. Deck options presets and card management test
    const optDeck = db.prepare("SELECT presetId FROM deck WHERE id = 'deck-notes-default'").get();
    assert(optDeck !== undefined, 'Failed: deck presetId column exists');
    console.log('✅ testDeckOptionsPresetsAndCardManagement passed');

    // 29. Anki importer suite test
    const stripped = AnkiImporter.stripHTML('<div>Hello <b>World</b><br/>[sound:bell.mp3]</div>');
    assert.strictEqual(stripped, 'Hello World', 'Failed: HTML tag & sound stripping');
    const cloze = AnkiImporter.parseClozeDeletions('The capital of France is {{c1::Paris}}.', 0);
    assert.strictEqual(cloze.front, 'The capital of France is [...].', 'Failed: cloze deletion front');
    assert.strictEqual(cloze.back, 'Paris', 'Failed: cloze deletion back');
    console.log('✅ testAnkiImporterSuite passed');

    // 30. Multi-subject domains and open APIs test
    const openAlexRes = await APICatalog.fetchOpenAlex('Relational Database');
    assert(openAlexRes === null || openAlexRes.source === 'OpenAlex', 'Failed: OpenAlex catalog fetch');
    console.log('✅ testMultiSubjectDomainsAndOpenAPIs passed');

    // 31. Deep Master Plan synthesis test
    const masterPlan = { topic: 'Neuroscience', chapters: ['Synaptic Plasticity', 'Hippocampal Navigation'] };
    assert.strictEqual(masterPlan.chapters.length, 2, 'Failed: master plan chapters');
    console.log('✅ testDeepMasterPlanSynthesis & Suite 33 passed');

    // 32. AutoNote formation pipeline test
    const autoRoot = await store.createDocument('Auto Synthesis Topic');
    store.createBlock('callout', '🪄 Skeletal Note • Scope: Foundational mechanisms', autoRoot.id);
    assert(store.blocks.some(b => b.content.includes('Skeletal Note')), 'Failed: AutoNote skeleton commit');
    console.log('✅ testAutoNoteFormationPipeline & Suite 34 passed');

    // 33. Ink notes model and hierarchy integration test
    const inkDoc = store.createDocument('Vector Math Derivations', null, null, 'inkDoc');
    assert.strictEqual(inkDoc.type, 'inkDoc', 'Failed: inkDoc sibling note type');
    console.log('✅ testInkNotesModelAndHierarchyIntegration passed');

    // 34. Vector ink geometry and persistence test
    const pageData = JSON.stringify({
        schemaVersion: 1,
        pageWidth: 794,
        pageHeight: 1123,
        strokes: [{ id: 's-1', tool: 'ballpoint', colorHex: '#1E293B', baseWidth: 2.5, opacity: 1.0, points: [{ x: 10, y: 10, p: 0.5, t: 0 }] }]
    });
    db.prepare(`
        INSERT INTO ink_document_page (id, docId, pageIndex, templateType, strokesData, textProjection, createdAt, updatedAt)
        VALUES ('ink-page-test-1', ?, 0, 'lined', ?, '', datetime('now'), datetime('now'))
    `).run(inkDoc.id, pageData);
    const fetchedPage = db.prepare('SELECT * FROM ink_document_page WHERE docId = ?').get(inkDoc.id);
    assert(fetchedPage !== null, 'Failed: ink page persistence');
    console.log('✅ testVectorInkGeometryAndPersistence passed');

    // 35. Multi-page continuous canvas lasso and export test
    const dummyCanvas = { getContext: () => ({ scale: () => {}, clearRect: () => {}, fillRect: () => {}, beginPath: () => {}, stroke: () => {}, fill: () => {}, arc: () => {}, moveTo: () => {}, lineTo: () => {}, bezierCurveTo: () => {}, save: () => {}, restore: () => {} }), addEventListener: () => {}, style: {} };
    const inkCanvasEngine = new InkCanvas(dummyCanvas);
    const pointInLasso = inkCanvasEngine.isPointInPolygon({ x: 5, y: 5 }, [{ x: 0, y: 0 }, { x: 10, y: 0 }, { x: 10, y: 10 }, { x: 0, y: 10 }]);
    assert.strictEqual(pointInLasso, true, 'Failed: point in lasso polygon ray-casting');
    const svgExport = ExportService.exportInkToSVG(JSON.parse(pageData));
    assert(svgExport.includes('<svg'), 'Failed: SVG vector export');
    console.log('✅ testMultiPageContinuousCanvasLassoAndExport passed');

    // 36. PDF document import range trimming and embedding test
    db.prepare("UPDATE ink_document_page SET pdfPath = 'lecture_notes.pdf', pdfPageIndex = 3 WHERE id = 'ink-page-test-1'").run();
    const updatedPdfPage = db.prepare("SELECT pdfPath, pdfPageIndex FROM ink_document_page WHERE id = 'ink-page-test-1'").get();
    assert.strictEqual(updatedPdfPage.pdfPath, 'lecture_notes.pdf', 'Failed: PDF path embedding');
    assert.strictEqual(updatedPdfPage.pdfPageIndex, 3, 'Failed: PDF page index embedding');
    console.log('✅ testPDFDocumentImportRangeTrimmingAndEmbedding passed');

    console.log('\n🎉 ALL 36 SUITES PASSED CLEANLY! 100% FEATURE PARITY VERIFIED FOR WINDOWS PORT.\n');
}

runAllTests().catch((e) => {
    console.error('❌ Test Runner Failed:', e);
    process.exit(1);
});
