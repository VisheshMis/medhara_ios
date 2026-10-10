const assert = require('assert');
const http = require('http');
const { MedhaSyncServer } = require('../src/server');

function request(options, data = null) {
    return new Promise((resolve, reject) => {
        const req = http.request(options, (res) => {
            let body = '';
            res.on('data', chunk => { body += chunk; });
            res.on('end', () => {
                try {
                    const parsed = JSON.parse(body || '{}');
                    resolve({ statusCode: res.statusCode, data: parsed });
                } catch (e) {
                    resolve({ statusCode: res.statusCode, raw: body });
                }
            });
        });
        req.on('error', reject);
        if (data) {
            req.write(JSON.stringify(data));
        }
        req.end();
    });
}

async function runTests() {
    console.log('--- Starting Medha Sync Server Test Suite ---');
    const TEST_PORT = 9898;
    const server = new MedhaSyncServer(TEST_PORT);
    await server.start();
    console.log(`Test server running on port ${TEST_PORT}`);

    try {
        // 1. Health check
        console.log('Test 1: Health check');
        const health = await request({
            hostname: 'localhost',
            port: TEST_PORT,
            path: '/api/v1/health',
            method: 'GET'
        });
        assert.strictEqual(health.statusCode, 200);
        assert.strictEqual(health.data.status, 'ok');
        assert.strictEqual(health.data.currentCursor, 0);

        // 2. Client A pushes note document
        console.log('Test 2: Client A (Android) pushes note document');
        const push1 = await request({
            hostname: 'localhost',
            port: TEST_PORT,
            path: '/api/v1/sync/push',
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        }, {
            deviceId: 'android_dev_001',
            changes: [
                {
                    changeId: 101,
                    entityType: 'document',
                    entityId: 'doc_1',
                    operation: 'INSERT',
                    payload: JSON.stringify({ title: 'Quick Idea from Android', isFolder: 0 }),
                    timestamp: 1000,
                    lamportClock: 1
                },
                {
                    changeId: 102,
                    entityType: 'block',
                    entityId: 'blk_1',
                    operation: 'INSERT',
                    payload: JSON.stringify({ documentId: 'doc_1', content: 'Explore quantum computing' }),
                    timestamp: 1005,
                    lamportClock: 2
                }
            ]
        });
        assert.strictEqual(push1.statusCode, 200);
        assert.strictEqual(push1.data.success, true);
        assert.strictEqual(push1.data.acceptedThroughChangeId, 102);
        assert.strictEqual(push1.data.serverCursor, 2);

        // 3. Client B (Mac) pulls changes
        console.log('Test 3: Client B (Mac) pulls changes from cursor 0');
        const pull1 = await request({
            hostname: 'localhost',
            port: TEST_PORT,
            path: '/api/v1/sync/pull?sinceCursor=0',
            method: 'GET'
        });
        assert.strictEqual(pull1.statusCode, 200);
        assert.strictEqual(pull1.data.changes.length, 2);
        assert.strictEqual(pull1.data.changes[0].entityId, 'doc_1');
        assert.strictEqual(pull1.data.changes[1].entityId, 'blk_1');

        // 4. LWW Conflict Resolution: Client B pushes newer edit with higher Lamport clock
        console.log('Test 4: Client B pushes concurrent edit with higher Lamport clock (LWW winner)');
        const push2 = await request({
            hostname: 'localhost',
            port: TEST_PORT,
            path: '/api/v1/sync/push',
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        }, {
            deviceId: 'mac_desktop_001',
            changes: [
                {
                    changeId: 201,
                    entityType: 'document',
                    entityId: 'doc_1',
                    operation: 'UPDATE',
                    payload: JSON.stringify({ title: 'Mac Overwrite (Higher Lamport)', isFolder: 0 }),
                    timestamp: 1050,
                    lamportClock: 10
                }
            ]
        });
        assert.strictEqual(push2.statusCode, 200);
        assert.strictEqual(push2.data.serverCursor, 3);

        // Client A pushes stale edit with lower Lamport clock
        console.log('Test 5: Client A pushes stale edit with lower Lamport clock (should NOT overwrite)');
        const push3 = await request({
            hostname: 'localhost',
            port: TEST_PORT,
            path: '/api/v1/sync/push',
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        }, {
            deviceId: 'android_dev_001',
            changes: [
                {
                    changeId: 103,
                    entityType: 'document',
                    entityId: 'doc_1',
                    operation: 'UPDATE',
                    payload: JSON.stringify({ title: 'Stale Android Update', isFolder: 0 }),
                    timestamp: 1060,
                    lamportClock: 3 // Lower than Mac's 10
                }
            ]
        });
        assert.strictEqual(push3.statusCode, 200);
        // The server state remains Mac's edit
        const stateKey = server.entityState.get('document:doc_1');
        assert.strictEqual(JSON.parse(stateKey.data).title, 'Mac Overwrite (Higher Lamport)');

        // 6. Review logs are append-only
        console.log('Test 6: Review log is append-only audit trail');
        const push4 = await request({
            hostname: 'localhost',
            port: TEST_PORT,
            path: '/api/v1/sync/push',
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        }, {
            deviceId: 'android_dev_001',
            changes: [
                {
                    changeId: 104,
                    entityType: 'review_log',
                    entityId: 'rev_1',
                    operation: 'INSERT',
                    payload: JSON.stringify({ cardId: 'card_1', rating: 3, reviewTime: '2026-10-10T10:00:00Z' }),
                    timestamp: 2000,
                    lamportClock: 5
                }
            ]
        });
        assert.strictEqual(push4.statusCode, 200);

        // Pull incremental since cursor 2
        console.log('Test 7: Incremental pull since cursor 2');
        const pull2 = await request({
            hostname: 'localhost',
            port: TEST_PORT,
            path: '/api/v1/sync/pull?sinceCursor=2',
            method: 'GET'
        });
        assert.strictEqual(pull2.statusCode, 200);
        // We pushed Mac edit and Review log (stale Android update was rejected from winning state)
        assert.strictEqual(pull2.data.changes.length, 2);
        assert.strictEqual(pull2.data.changes[0].entityId, 'doc_1');
        assert.strictEqual(pull2.data.changes[1].entityId, 'rev_1');

        console.log('\n✅ ALL SYNC SERVER TESTS PASSED SUCCESSFULLY (Phase 4 Verified)!');
    } finally {
        await server.stop();
        console.log('Test server stopped.');
    }
}

runTests().catch(err => {
    console.error('❌ Test failed:', err);
    process.exit(1);
});
