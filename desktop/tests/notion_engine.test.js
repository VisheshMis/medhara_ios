// Medha Windows Desktop — Notion Engine Test Suite
// Verifies Migration v14, Page Metadata, Asset Caching, Sub-Pages, Columns & Database Views

const assert = require('assert');
const path = require('path');
const fs = require('fs');
const Database = require('better-sqlite3');
const { DatabaseMigrations } = require('../electron/database/migrations');
const { BlockStore } = require('../src/js/store');
const { AssetService } = require('../electron/services/assetService');

async function runNotionEngineTests() {
    console.log('🧪 Starting Notion Engine Parity & Offline Asset Test Suite...');

    // 1. Setup in-memory SQLite database and apply migrations
    const db = new Database(':memory:');
    DatabaseMigrations.registerMigrations(db);

    const store = new BlockStore(db);
    // Seed initial notebook & doc for testing
    db.exec(`
        INSERT INTO notebook (id, name, icon, sortOrder) VALUES ('nb-1', 'Main Notebook', 'book', 0);
        INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, isCompleted, createdAt, updatedAt)
        VALUES ('doc-root', 'doc-root', NULL, 'doc', 'Root Page', 0, 0, datetime('now'), datetime('now'));
    `);

    await store.load();
    store.selectedDocId = 'doc-root';
    store.currentDoc = store.documents.find(d => d.id === 'doc-root');

    // --- TEST 1: Schema Verification ---
    const tables = db.prepare("SELECT name FROM sqlite_master WHERE type='table'").all().map(r => r.name);
    assert(tables.includes('page_metadata'), 'page_metadata table must exist');
    assert(tables.includes('database_collection'), 'database_collection table must exist');
    assert(tables.includes('database_row'), 'database_row table must exist');
    assert(tables.includes('database_view'), 'database_view table must exist');
    assert(tables.includes('asset_cache'), 'asset_cache table must exist');

    const blockCols = db.prepare("PRAGMA table_info(block)").all().map(c => c.name);
    assert(blockCols.includes('columnRatio'), 'block.columnRatio must exist');
    assert(blockCols.includes('subPageDocId'), 'block.subPageDocId must exist');
    assert(blockCols.includes('databaseViewId'), 'block.databaseViewId must exist');
    console.log('✅ 1. Migration v14 Schema & Block Extensions Verified');

    // --- TEST 2: Page Metadata CRUD & Repositioning ---
    await store.savePageMetadata({
        id: 'doc-root',
        coverUrl: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb',
        coverY: 0.72,
        iconType: 'emoji',
        iconValue: '🌿',
        fontFamily: 'mono',
        isSmallText: 1,
        isFullWidth: 1,
        isLocked: 0
    });

    const meta = await store.loadPageMetadata('doc-root');
    assert.strictEqual(meta.coverY, 0.72, 'coverY must be preserved');
    assert.strictEqual(meta.iconValue, '🌿', 'iconValue must be preserved');
    assert.strictEqual(meta.fontFamily, 'mono', 'fontFamily must be mono');
    assert.strictEqual(meta.isSmallText, 1, 'isSmallText must be true');
    assert.strictEqual(meta.isFullWidth, 1, 'isFullWidth must be true');
    console.log('✅ 2. Page Metadata, Repositioning Y% & Typography Persistence Verified');

    // --- TEST 3: Sub-Page Block Creation & Hierarchy Navigation ---
    const subPageBlock = store.createSubPageBlock('Biology: Cellular Respiration');
    assert(subPageBlock !== null, 'Sub-page block must be created');
    assert.strictEqual(subPageBlock.type, 'page', 'Block type must be page');
    assert(subPageBlock.subPageDocId, 'Must reference child subPageDocId');

    const childDoc = store.documents.find(d => d.id === subPageBlock.subPageDocId);
    assert(childDoc, 'Child document must exist in store.documents');
    assert.strictEqual(childDoc.content, 'Biology: Cellular Respiration', 'Child document title must match');

    const childMeta = await store.loadPageMetadata(childDoc.id);
    assert(childMeta !== null, 'Child document must have default metadata');
    assert.strictEqual(childMeta.coverY, 0.5, 'Default coverY must be 0.5');
    console.log('✅ 3. Sub-Page Block (/page) & Child Document Hierarchy Verified');

    // --- TEST 4: Multi-Column Layout Creation ---
    const colList = store.createColumnList(3);
    assert(colList !== null, 'Column list block must be created');
    assert.strictEqual(colList.type, 'column_list', 'Block type must be column_list');

    const childCols = store.blocks.filter(b => b.parentId === colList.id && b.type === 'column');
    assert.strictEqual(childCols.length, 3, 'Must create 3 child column blocks');
    assert(Math.abs(childCols[0].columnRatio - (1 / 3)) < 0.01, 'Column ratio must be 1/3');
    console.log('✅ 4. Multi-Column Layout (column_list & columns) Verified');

    // --- TEST 5: Database Collections & Views Engine ---
    const colId = 'col-subjects-1';
    const schema = {
        title: { name: 'Name', type: 'title' },
        status: { name: 'Status', type: 'select' },
        priority: { name: 'Priority', type: 'select' },
        progress: { name: 'Progress', type: 'number' }
    };

    await store.saveCollection(colId, 'Subjects Master', schema, 'doc-root');

    const row1 = await store.saveCollectionRow(colId, { title: 'Mathematics', status: 'In-Progress', priority: 'High', progress: 75 });
    const row2 = await store.saveCollectionRow(colId, { title: 'Physics', status: 'In-Progress', priority: 'Medium', progress: 50 });
    const row3 = await store.saveCollectionRow(colId, { title: 'Chemistry', status: 'Completed', priority: 'Low', progress: 100 });

    await store.saveCollectionView('view-gallery-1', colId, 'Gallery View', 'gallery', {}, [], { cardSize: 'medium' });
    await store.saveCollectionView('view-board-1', colId, 'Kanban View', 'board');
    await store.saveCollectionView('view-calendar-1', colId, 'Calendar View', 'calendar');
    await store.saveCollectionView('view-table-1', colId, 'Table View', 'table');

    const loadedCol = await store.loadCollection(colId);
    assert.strictEqual(loadedCol.name, 'Subjects Master', 'Collection name must match');
    assert.strictEqual(loadedCol.rows.length, 3, 'Collection must have 3 rows');
    assert.strictEqual(loadedCol.views.length, 4, 'Collection must have 4 views (Gallery, Board, Calendar, Table)');
    assert.strictEqual(loadedCol.rows[0].properties.title, 'Mathematics');
    assert.strictEqual(loadedCol.rows[0].properties.progress, 75);

    // Test row deletion
    await store.deleteCollectionRow(loadedCol.rows[2].id);
    const updatedCol = await store.loadCollection(colId);
    assert.strictEqual(updatedCol.rows.length, 2, 'Row must be deleted');
    console.log('✅ 5. Relational Database Collections & 4-View Projections Verified');

    // --- TEST 6: Offline Asset Cache Service ---
    const testAssetsDir = path.join(__dirname, 'temp_assets_test');
    if (fs.existsSync(testAssetsDir)) fs.rmSync(testAssetsDir, { recursive: true, force: true });
    fs.mkdirSync(testAssetsDir, { recursive: true });

    const assetService = new AssetService({ queryOne: (s, p) => db.prepare(s).get(...p), run: (s, p) => db.prepare(s).run(...p) }, testAssetsDir);

    const testBuffer = Buffer.from('FAKE_PNG_BINARY_CONTENT_FOR_OFFLINE_CACHE');
    const cachedAsset = await assetService.cacheAssetFromBuffer(testBuffer, 'image/png', 'upload', 'test_banner.png');

    assert(cachedAsset.hash, 'Hash must be generated');
    assert(cachedAsset.assetUrl.startsWith('medha-asset://'), 'Asset URL must use custom scheme');
    assert(fs.existsSync(cachedAsset.localPath), 'File must exist on disk in offline store');

    // Verify lookup from cache
    const assetRow = assetService.getAsset(cachedAsset.hash);
    assert(assetRow !== null, 'Asset record must exist in SQLite asset_cache table');
    assert.strictEqual(assetRow.mimeType, 'image/png', 'Mime type must be image/png');

    // Test Curated Presets
    const presets = assetService.getCuratedPhotoPresets();
    assert(presets.length >= 5, 'Curated aesthetic presets must have at least 5 photos');
    const gifPresets = assetService.getCuratedGifPresets();
    assert(gifPresets.length >= 3, 'Curated GIF presets must have at least 3 GIFs');

    // Cleanup temp dir
    fs.rmSync(testAssetsDir, { recursive: true, force: true });
    console.log('✅ 6. 100% Offline Asset Cache, Disk Storage & Protocol Verified');

    console.log('\n🎉 ALL 6 NOTION ENGINE TEST SUITES PASSED FLAWLESSLY!\n');
}

runNotionEngineTests().catch(err => {
    console.error('❌ Notion Engine test failed:', err);
    process.exit(1);
});
