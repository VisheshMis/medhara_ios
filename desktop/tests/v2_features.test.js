// Medha Windows Desktop — Tier 1 & Windows v2 Features Unit Tests
// Tests Migration v13, Toggle blocks, Table 2D matrices, Document Locking, Verification workflows, and Pinned Properties

const assert = require('assert');
const Database = require('better-sqlite3');
const { DatabaseMigrations } = require('../electron/database/migrations');
const { MockDataSeeder } = require('../electron/database/seeder');
const { BlockStore } = require('../src/js/store');
const { BlockEditorEngine } = require('../src/js/editor/blockEngine');

async function runV2FeatureTests() {
    console.log('🧪 Starting Windows v2 Features & Fixes Test Suite...');

    const db = new Database(':memory:');
    DatabaseMigrations.registerMigrations(db);
    MockDataSeeder.seedIfMissing(db);

    const store = new BlockStore(db);
    await store.load();

    // 1. Schema Migration v13 Verification
    const blockColumns = db.prepare("PRAGMA table_info(block)").all().map(c => c.name);
    const requiredCols = [
        'isCollapsed', 'icon', 'colorTint', 'verifiedAt',
        'verifiedExpiresAt', 'verifiedBy', 'isLocked', 'pinnedPropertiesData'
    ];
    for (const col of requiredCols) {
        assert(blockColumns.includes(col), `Migration v13 missing column: ${col}`);
    }
    console.log('✅ 1. Migration v13 schema verified with all 8 new columns');

    // 2. Toggle Block Creation, Folding & State Persistence
    const toggleBlock = store.createBlock('toggle', 'Key Concepts Summary');
    assert.strictEqual(toggleBlock.type, 'toggle', 'Toggle block type mismatch');
    assert.strictEqual(toggleBlock.isCollapsed, 0, 'Toggle should initialize expanded');

    const toggledState1 = store.toggleBlockCollapsed(toggleBlock.id);
    assert.strictEqual(toggledState1, 1, 'Toggle state should become 1 (collapsed)');
    
    // Verify persistence in SQLite
    const fetchedToggle = db.prepare('SELECT isCollapsed FROM block WHERE id = ?').get(toggleBlock.id);
    assert.strictEqual(fetchedToggle.isCollapsed, 1, 'Collapsed state not persisted in DB');

    const toggledState2 = store.toggleBlockCollapsed(toggleBlock.id);
    assert.strictEqual(toggledState2, 0, 'Toggle state should become 0 (expanded)');
    console.log('✅ 2. Toggle block creation, folding & SQLite persistence verified');

    // 3. Table Matrix Block 2D Grid & JSON Serialization
    const defaultTablePayload = {
        rows: [
            ['Concept', 'Formula', 'Application'],
            ['Bayes Rule', 'P(A|B) = P(B|A)P(A)/P(B)', 'Posterior Inference'],
            ['Entropy', 'H(X) = -sum p(x) log p(x)', 'Information Theory']
        ],
        hasHeaderRow: true,
        hasHeaderCol: false
    };
    const tableBlock = store.createBlock('table', JSON.stringify(defaultTablePayload));
    assert.strictEqual(tableBlock.type, 'table', 'Table block type mismatch');

    // Verify engine can parse table payload accurately
    const engine = new BlockEditorEngine(null, store);
    const parsed = engine.parseTablePayload(tableBlock.content);
    assert.strictEqual(parsed.rows.length, 3, 'Table row count mismatch');
    assert.strictEqual(parsed.rows[0].length, 3, 'Table col count mismatch');
    assert.strictEqual(parsed.rows[1][0], 'Bayes Rule', 'Cell data mismatch');
    assert.strictEqual(parsed.hasHeaderRow, true, 'Header row flag mismatch');
    console.log('✅ 3. Table block 2D matrix structure & JSON serialization verified');

    // 4. Document Locking (Read-Only Enforcement)
    const testDoc = store.createDocument('Authoritative Thesis', null, null, 'doc');
    assert.strictEqual(testDoc.isLocked || 0, 0, 'Document should initially be unlocked');

    store.setDocumentLock(testDoc.id, true);
    assert.strictEqual(testDoc.isLocked, 1, 'Document should be marked locked in store');

    const fetchedDoc = db.prepare('SELECT isLocked FROM block WHERE id = ?').get(testDoc.id);
    assert.strictEqual(fetchedDoc.isLocked, 1, 'Document locked state not persisted in DB');

    store.setDocumentLock(testDoc.id, false);
    assert.strictEqual(testDoc.isLocked, 0, 'Document should be unlocked');
    console.log('✅ 4. Document lock & read-only toggle persistence verified');

    // 5. Document Verification Badges & Expiration Logic
    store.setDocumentVerification(testDoc.id, 90, 'Dr. Smith');
    assert(testDoc.verifiedAt !== null, 'verifiedAt should be set');
    assert(testDoc.verifiedExpiresAt !== null, 'verifiedExpiresAt should be set');
    assert.strictEqual(testDoc.verifiedBy, 'Dr. Smith', 'verifiedBy mismatch');

    const daysLeft = engine.calculateVerificationDays(testDoc.verifiedExpiresAt);
    assert(daysLeft >= 89 && daysLeft <= 91, `Days remaining calculation mismatch: ${daysLeft}`);

    // Test expired verification calculation
    const pastDate = new Date(Date.now() - 500000).toISOString();
    const expiredDays = engine.calculateVerificationDays(pastDate);
    assert.strictEqual(expiredDays, 0, 'Expired date should return 0 days remaining');
    console.log('✅ 5. Document verification workflows & expiration calculations verified');

    // 6. Pinned Properties Bar Serialization
    const pinnedProps = {
        tags: ['Physics', 'Quantum Mechanics'],
        status: 'In Review',
        priority: 'High'
    };
    store.updatePinnedProperties(testDoc.id, pinnedProps);
    assert.strictEqual(JSON.parse(testDoc.pinnedPropertiesData).status, 'In Review');

    const fetchedPropsDoc = db.prepare('SELECT pinnedPropertiesData FROM block WHERE id = ?').get(testDoc.id);
    assert(fetchedPropsDoc.pinnedPropertiesData.includes('Quantum Mechanics'));
    console.log('✅ 6. Pinned property bar persistence verified');

    // 7. Collapsible Headings Folding Logic
    const h1Block = store.createBlock('heading1', 'Introduction Chapter');
    const p1 = store.createBlock('paragraph', 'Paragraph under H1');
    const h2Block = store.createBlock('heading2', 'Section 1.1');
    const p2 = store.createBlock('paragraph', 'Paragraph under H2');

    store.toggleBlockCollapsed(h1Block.id);
    assert.strictEqual(h1Block.isCollapsed, 1, 'H1 should be collapsed');
    console.log('✅ 7. Collapsible headings folding structure verified');

    console.log('\n🌟 ALL 7 WINDOWS V2 FEATURE SUITES PASSED FLAWLESSLY!\n');
}

runV2FeatureTests().catch((e) => {
    console.error('❌ v2 Features Test Suite Failed:', e);
    process.exit(1);
});
