// Medha Windows Desktop — Stage 11 Import/Export & Windows Packaging Verification Suite
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const os = require('os');
const Database = require('better-sqlite3');
const AdmZip = require('adm-zip');
const fzstd = require('fzstd');
const { AnkiImporter } = require('../electron/services/ankiImporter');
const { ExportService } = require('../electron/services/exportService');
const { DatabaseMigrations } = require('../electron/database/migrations');

console.log('🧪 Starting Stage 11: Import/Export (Anki .apkg, Markdown, SVG) & Packaging Suite...\n');

let passedTests = 0;

function test(name, fn) {
    try {
        fn();
        console.log(`  ✅ ${name}`);
        passedTests++;
    } catch (err) {
        console.error(`  ❌ ${name}`);
        console.error(err);
        process.exit(1);
    }
}

// 1. Test HTML stripping and Cloze Deletion Parsing
test('AnkiImporter: HTML stripping cleans tags and converts entities', () => {
    const raw = '<div><b>Distributed</b>&nbsp;Consensus</div><br><p>Raft &amp; Paxos</p><li>Fast</li>';
    const clean = AnkiImporter.stripHTML(raw);
    assert(clean.includes('Distributed Consensus'));
    assert(clean.includes('Raft & Paxos'));
    assert(clean.includes('• Fast'));
    assert(!clean.includes('<div>'));
    assert(!clean.includes('&nbsp;'));
});

test('AnkiImporter: Cloze Deletions parse ordinal card targets accurately', () => {
    const clozeText = 'The {{c1::Byzantine Generals::protocol}} problem was introduced in {{c2::1982}}.';
    
    // Card ord 0 (c1)
    const card1 = AnkiImporter.parseClozeDeletions(clozeText, 0);
    assert(card1 !== null, 'Card 1 should be parsed');
    assert.strictEqual(card1.front, 'The [...protocol] problem was introduced in 1982.');
    assert.strictEqual(card1.back, 'Byzantine Generals');

    // Card ord 1 (c2)
    const card2 = AnkiImporter.parseClozeDeletions(clozeText, 1);
    assert(card2 !== null, 'Card 2 should be parsed');
    assert.strictEqual(card2.front, 'The Byzantine Generals problem was introduced in [...].');
    assert.strictEqual(card2.back, '1982');

    // Card ord 2 (c3 does not exist)
    const card3 = AnkiImporter.parseClozeDeletions(clozeText, 2);
    assert.strictEqual(card3, null, 'Card 3 does not exist and should return null');
});

// 2. Test End-to-End Anki Package (.apkg) Extraction & SQLite Ingestion
test('AnkiImporter: Ingests synthetic .apkg into Medha SQLite database', () => {
    const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'medha-anki-test-'));
    const targetDbPath = path.join(tempDir, 'medha_target.db');
    const ankiDbPath = path.join(tempDir, 'collection.anki2');
    const apkgPath = path.join(tempDir, 'test_deck.apkg');

    try {
        // Create Medha target database with current migrations
        const targetDb = new Database(targetDbPath);
        DatabaseMigrations.registerMigrations(targetDb);

        // Create synthetic Anki SQLite database
        const ankiDb = new Database(ankiDbPath);
        ankiDb.exec(`
            CREATE TABLE col (id integer primary key, decks text, models text);
            CREATE TABLE notes (id integer primary key, mid integer, flds text, tags text);
            CREATE TABLE cards (id integer primary key, nid integer, did integer, ord integer);
        `);

        // Insert deck metadata
        const decksJson = JSON.stringify({
            "101": { id: 101, name: "Advanced Computer Science" }
        });
        ankiDb.prepare("INSERT INTO col (id, decks, models) VALUES (1, ?, '{}')").run(decksJson);

        // Insert notes and cards (Field separator is \x1f)
        const note1Fields = "What is Amdahl's Law?\x1fSpeedup is limited by the serial portion of the program.";
        ankiDb.prepare('INSERT INTO notes (id, mid, flds, tags) VALUES (1001, 1, ?, ?)').run(note1Fields, 'os parallel');
        ankiDb.prepare('INSERT INTO cards (id, nid, did, ord) VALUES (5001, 1001, 101, 0)').run();

        const note2Cloze = "{{c1::Linearizability}} is the strongest safety property for concurrent objects.\x1f";
        ankiDb.prepare('INSERT INTO notes (id, mid, flds, tags) VALUES (1002, 1, ?, ?)').run(note2Cloze, 'concurrency');
        ankiDb.prepare('INSERT INTO cards (id, nid, did, ord) VALUES (5002, 1002, 101, 0)').run();

        ankiDb.close();

        // Pack into .apkg (ZIP archive)
        const zip = new AdmZip();
        zip.addLocalFile(ankiDbPath);
        zip.writeZip(apkgPath);

        // Run AnkiImporter
        const result = AnkiImporter.importPackage(apkgPath, targetDb, 'doc-test', 'nb-test');
        assert.strictEqual(result.importedCardCount, 2);
        assert.strictEqual(result.createdDeckCount, 1);

        // Verify SQLite target database contents
        const importedDeck = targetDb.prepare('SELECT * FROM deck WHERE id = ?').get('deck-anki-101');
        assert(importedDeck, 'Imported deck must exist in database');
        assert.strictEqual(importedDeck.name, 'Advanced Computer Science');

        const importedCards = targetDb.prepare('SELECT * FROM flashcard WHERE deckId = ? ORDER BY id ASC').all('deck-anki-101');
        assert.strictEqual(importedCards.length, 2);
        assert(importedCards[0].front.includes("Amdahl's Law"), `Expected front to contain Amdahl's Law, got: ${importedCards[0].front}`);
        assert(importedCards[1].front.includes('[...] is the strongest safety property'));
        assert.strictEqual(importedCards[1].back, 'Linearizability');

        targetDb.close();
    } finally {
        fs.rmSync(tempDir, { recursive: true, force: true });
    }
});

// 3. Test Markdown and JSON Exporters
test('ExportService: Markdown and JSON exports maintain document structure', () => {
    const doc = { id: 'doc-123', content: 'Distributed Systems Invariants' };
    const blocks = [
        { id: 'b1', type: 'heading1', content: 'Consensus Guarantees', parentId: null },
        { id: 'b2', type: 'paragraph', content: 'Safety and liveness are fundamental dual invariants.', parentId: null },
        { id: 'b3', type: 'bulletList', content: 'Safety: nothing bad happens', parentId: null },
        { id: 'b4', type: 'bulletList', content: 'Liveness: something good eventually happens', parentId: null },
        { id: 'b5', type: 'taskList', content: 'Implement Paxos protocol', isCompleted: 1, parentId: null },
        { id: 'b6', type: 'codeBlock', content: 'state.commitIndex = Math.max(...)', parentId: null },
        { id: 'b7', type: 'callout', content: 'Important FLP impossibility bound applies in asynchronous models.', parentId: null }
    ];

    const md = ExportService.exportToMarkdown(doc, blocks);
    assert(md.includes('# Distributed Systems Invariants'), 'Should include main document title');
    assert(md.includes('# Consensus Guarantees'), 'Should include heading');
    assert(md.includes('- [x] Implement Paxos protocol'), 'Should format completed task');
    assert(md.includes('```\nstate.commitIndex = Math.max(...)'), 'Should format code block');
    assert(md.includes('> [!NOTE]'), 'Should format callout note');

    const jsonStr = ExportService.exportToJSON(doc, blocks);
    const parsed = JSON.parse(jsonStr);
    assert.strictEqual(parsed.document.id, 'doc-123');
    assert.strictEqual(parsed.blocks.length, 7);
});

// 4. Test Lossless Vector Ink SVG Export
test('ExportService: Vector Ink SVG export produces valid XML and paths', () => {
    const pagePayload = {
        strokes: [
            {
                points: [{ x: 50, y: 50 }, { x: 100, y: 150 }, { x: 200, y: 250 }],
                colorHex: '#3B82F6',
                baseWidth: 3.0,
                tool: 'pen'
            },
            {
                points: [{ x: 300, y: 100 }, { x: 450, y: 100 }],
                colorHex: '#FBBF24',
                baseWidth: 12.0,
                tool: 'highlighter'
            }
        ]
    };

    const svg = ExportService.exportInkToSVG(pagePayload, 794, 1123);
    assert(svg.includes('<?xml version="1.0" encoding="UTF-8"?>'), 'Must include XML declaration');
    assert(svg.includes('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 794 1123"'), 'Must have correct viewport');
    assert(svg.includes('d="M 50.0 50.0 L 100.0 150.0 L 200.0 250.0"'), 'Must render pen path vector');
    assert(svg.includes('opacity="0.35"'), 'Must set highlighter opacity');
    assert(svg.endsWith('</svg>\n'), 'Must close SVG tag cleanly');
});

// 5. Test Windows Packaging Configuration
test('Windows Packaging: package.json build configuration defines required targets', () => {
    const pkg = JSON.parse(fs.readFileSync(path.join(__dirname, '../package.json'), 'utf8'));
    assert(pkg.build, 'Must contain build block');
    assert.strictEqual(pkg.build.appId, 'com.medha.desktop');
    assert.strictEqual(pkg.build.productName, 'Medha');
    assert(pkg.build.win, 'Must have Windows build configuration');
    assert(pkg.build.win.target.includes('nsis'), 'Must target NSIS installer');
    assert(pkg.build.win.target.includes('portable'), 'Must target portable executable');
    assert(pkg.scripts['dist:win'], 'Must have dist:win build script');
});

console.log(`\n🎉 Stage 11 Test Suite Passed! ${passedTests}/${passedTests} tests successful.`);
