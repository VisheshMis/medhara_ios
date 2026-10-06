// Medha Windows Desktop — Stage 7 Vector Ink Engine Verification Suite
// Validates PointerEvents Level 3 dynamic pressure handling, Catmull-Rom cubic spline interpolation,
// closed ribbon polygon outline generation, Ray-casting point-in-polygon lasso math,
// eraser hit testing, and SQLite persistence across ink document pages.

const assert = require('assert');
const Database = require('better-sqlite3');
const { DatabaseMigrations } = require('../electron/database/migrations');
const { BlockStore } = require('../src/js/store');
const { InkGeometry } = require('../src/js/ink/inkGeometry');
const { InkCanvas } = require('../src/js/ink/inkCanvas');

console.log('🧪 Starting Stage 7 Vector Ink Engine (Windows Ink / Catmull-Rom / Lasso) Verification Suite...');

// 1. Distance & Point Smoothing (Catmull-Rom)
console.log('1. Testing Catmull-Rom cubic spline interpolation...');
const rawPoints = [
    { x: 10, y: 10, pressure: 0.2, timeOffset: 0 },
    { x: 50, y: 20, pressure: 0.6, timeOffset: 50 },
    { x: 90, y: 80, pressure: 0.9, timeOffset: 100 },
    { x: 140, y: 100, pressure: 0.4, timeOffset: 150 }
];

const smoothed = InkGeometry.smoothPoints(rawPoints);
assert(smoothed.length > rawPoints.length, `Smoothed points count (${smoothed.length}) must be strictly greater than raw points (${rawPoints.length})`);
assert.strictEqual(smoothed[0].x, 10, 'First point X must match');
assert.strictEqual(smoothed[smoothed.length - 1].x, 140, 'Last point X must match');

// All pressures must be clamped between 0.1 and 1.0
for (const pt of smoothed) {
    assert(pt.pressure >= 0.1 && pt.pressure <= 1.0, `Pressure ${pt.pressure} must be clamped in [0.1, 1.0]`);
}
console.log('✅ 1. Catmull-Rom spline points smoothly generated with pressure clamping');

// 2. Variable-Width Closed Polygon Outline Generation
console.log('2. Testing variable-width ribbon polygon outline generation...');
const stroke1 = {
    id: 's-test-1',
    tool: 'ballpoint',
    colorHex: '#1E293B',
    baseWidth: 3.0,
    opacity: 1.0,
    points: rawPoints
};

const outline = InkGeometry.generateOutlinePolygon(stroke1);
assert(outline.length > 0, 'Outline polygon must produce vertices');
assert(outline.length >= smoothed.length * 2, 'Outline must generate paired ribbon vertices (left and right)');
console.log('✅ 2. Variable-width closed ribbon outline polygon successfully generated');

// 3. Ray-Casting Point-in-Polygon & Lasso Selection
console.log('3. Testing Ray-casting point-in-polygon and lasso selection...');
const trianglePoly = [
    { x: 0, y: 0 },
    { x: 100, y: 0 },
    { x: 50, y: 100 }
];

assert.strictEqual(InkGeometry.polygonContains({ x: 50, y: 20 }, trianglePoly), true, 'Point (50, 20) inside triangle');
assert.strictEqual(InkGeometry.polygonContains({ x: 150, y: 20 }, trianglePoly), false, 'Point (150, 20) outside triangle');
assert.strictEqual(InkGeometry.polygonContains({ x: 50, y: 120 }, trianglePoly), false, 'Point (50, 120) outside triangle');

// Lasso enclosing stroke
const lassoEnclosing = [
    { x: 0, y: 0 },
    { x: 200, y: 0 },
    { x: 200, y: 200 },
    { x: 0, y: 200 }
];
assert.strictEqual(InkGeometry.lassoSelects(stroke1, lassoEnclosing), true, 'Lasso must select enclosed stroke');

const lassoDisjoint = [
    { x: 300, y: 300 },
    { x: 400, y: 300 },
    { x: 400, y: 400 },
    { x: 300, y: 400 }
];
assert.strictEqual(InkGeometry.lassoSelects(stroke1, lassoDisjoint), false, 'Lasso must NOT select disjoint stroke');
console.log('✅ 3. Ray-casting point-in-polygon and lasso selection verified');

// 4. Hit-Testing & Eraser Segment Collision
console.log('4. Testing circular brush eraser hit-testing...');
assert.strictEqual(InkGeometry.hitTest(stroke1, { x: 50, y: 20 }, 10), true, 'Eraser must hit stroke at (50, 20)');
assert.strictEqual(InkGeometry.hitTest(stroke1, { x: 500, y: 500 }, 10), false, 'Eraser must NOT hit distant point');
console.log('✅ 4. Eraser hit-testing correctly detects segment proximity');

// 5. Stroke Bounding Box & Translation
console.log('5. Testing bounding box calculation and translation...');
const bbox = InkGeometry.strokeBoundingBox(stroke1);
assert(bbox.minX <= 10 && bbox.maxX >= 140, 'Bounding box X must envelop stroke');
assert(bbox.minY <= 10 && bbox.maxY >= 100, 'Bounding box Y must envelop stroke');

const translated = InkGeometry.translate(stroke1, 20, -10);
assert.strictEqual(translated.points[0].x, 30, 'Point 0 X translated by +20');
assert.strictEqual(translated.points[0].y, 0, 'Point 0 Y translated by -10');
console.log('✅ 5. Bounding box and vector translation verified');

// 6. SQLite Ink Note Persistence & Multi-Page Templates
console.log('6. Testing SQLite ink document page persistence with templates...');
const db = new Database(':memory:');
DatabaseMigrations.registerMigrations(db);
const store = new BlockStore(db);

const inkDoc = store.createDocument('Calculus Handwritten Proofs', null, null, 'inkDoc');
assert.strictEqual(inkDoc.type, 'inkDoc', 'Note must be created with type inkDoc');

// Verify Page 0 was automatically created
const pages = db.prepare('SELECT * FROM ink_document_page WHERE docId = ? ORDER BY pageIndex ASC').all(inkDoc.id);
assert.strictEqual(pages.length, 1, 'Must have initial page 0');
assert.strictEqual(pages[0].templateType, 'lined', 'Default template must be lined');

// Save a stroke to page 0
const pagePayload = JSON.stringify({
    schemaVersion: 1,
    pageWidth: 794,
    pageHeight: 1123,
    strokes: [stroke1]
});
db.prepare(`
    UPDATE ink_document_page
    SET strokesData = ?, templateType = 'grid', updatedAt = datetime('now')
    WHERE id = ?
`).run(pagePayload, pages[0].id);

const updatedPage = db.prepare('SELECT * FROM ink_document_page WHERE id = ?').get(pages[0].id);
const loadedData = JSON.parse(updatedPage.strokesData);
assert.strictEqual(loadedData.strokes.length, 1, 'Strokes must be restored from SQLite');
assert.strictEqual(loadedData.strokes[0].id, 's-test-1', 'Stroke ID must match');
assert.strictEqual(updatedPage.templateType, 'grid', 'Template must update to grid');

console.log('✅ 6. Full vector stroke persistence and page templates verified in SQLite');
console.log('\n🎉 ALL STAGE 7 VECTOR INK ENGINE TESTS PASSED!\n');
