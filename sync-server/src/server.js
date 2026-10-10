/**
 * Medha Sync Server — Lightweight Self-Hosted Delta Synchronization Microservice
 * Standard HTTP & WebSocket server for multi-device sync (Mac, Windows, Android).
 */

const http = require('http');
const { URL } = require('url');

class MedhaSyncServer {
    constructor(port = 8787) {
        this.port = port;
        this.serverLamport = 0;
        this.journal = []; // Ordered array of { cursor, deviceId, entityType, entityId, operation, data, timestamp, lamportClock }
        this.entityState = new Map(); // key: `${entityType}:${entityId}` -> { winningChange, data }
        this.clientCursors = new Map(); // deviceId -> lastAcknowledgedCursor
        this.server = null;
    }

    /**
     * Resolves conflicts according to LWW and immutable review log rules.
     */
    resolveConflict(existingChange, incomingChange) {
        if (!existingChange) return incomingChange;
        if (!incomingChange) return existingChange;

        // Rule 5: review_log is an immutable append-only audit trail
        if (incomingChange.entityType === 'review_log') {
            return incomingChange;
        }

        // Rule 1: Lamport dominance
        if (incomingChange.lamportClock > existingChange.lamportClock) return incomingChange;
        if (existingChange.lamportClock > incomingChange.lamportClock) return existingChange;

        // Rule 2: Wall-clock ISO / epoch timestamp tie-breaker
        const tIn = incomingChange.timestamp || 0;
        const tEx = existingChange.timestamp || 0;
        if (tIn > tEx) return incomingChange;
        if (tEx > tIn) return existingChange;

        // Rule 3: Deterministic deviceId tie-breaker
        if (incomingChange.deviceId > existingChange.deviceId) return incomingChange;
        return existingChange;
    }

    handleHealth() {
        return {
            status: 'ok',
            version: '1.0.0',
            serverTime: Date.now(),
            currentCursor: this.journal.length,
            currentLamport: this.serverLamport,
            activeClients: this.clientCursors.size
        };
    }

    handlePush(body) {
        const { deviceId, changes } = body;
        if (!deviceId) throw new Error('Missing deviceId');
        if (!Array.isArray(changes)) throw new Error('Changes must be an array');

        let highestAcceptedId = 0;

        for (const ch of changes) {
            const clientChangeId = ch.changeId || ch.id || 0;
            const entityType = ch.entityType;
            const entityId = ch.entityId;
            const operation = ch.operation || 'UPDATE';
            const data = ch.payload || ch.data || null;
            const timestamp = ch.timestamp || Date.now();
            const clientLamport = ch.lamportClock || 0;

            this.serverLamport = Math.max(this.serverLamport, clientLamport) + 1;

            const cursor = this.journal.length + 1;
            const stampedChange = {
                cursor,
                deviceId,
                entityType,
                entityId,
                operation,
                data,
                timestamp,
                lamportClock: clientLamport,
                serverLamport: this.serverLamport
            };

            const key = `${entityType}:${entityId}`;
            const existing = this.entityState.get(key);

            if (!existing) {
                this.entityState.set(key, stampedChange);
                this.journal.push(stampedChange);
            } else {
                const winner = this.resolveConflict(existing, stampedChange);
                if (winner === stampedChange) {
                    this.entityState.set(key, stampedChange);
                    this.journal.push(stampedChange);
                }
            }

            highestAcceptedId = Math.max(highestAcceptedId, clientChangeId);
        }

        this.clientCursors.set(deviceId, this.journal.length);

        return {
            success: true,
            acceptedThroughChangeId: highestAcceptedId,
            serverCursor: this.journal.length,
            serverLamport: this.serverLamport
        };
    }

    handlePull(sinceCursor = 0, limit = 250) {
        const cursorNum = parseInt(sinceCursor, 10) || 0;
        const limitNum = Math.min(1000, parseInt(limit, 10) || 250);

        const delta = this.journal.filter(item => item.cursor > cursorNum).slice(0, limitNum);
        const hasMore = this.journal.length > (cursorNum + delta.length);

        return {
            serverCursor: this.journal.length,
            serverLamport: this.serverLamport,
            hasMore,
            changes: delta
        };
    }

    start() {
        return new Promise((resolve, reject) => {
            this.server = http.createServer((req, res) => {
                const parsedUrl = new URL(req.url, `http://localhost:${this.port}`);
                const pathname = parsedUrl.pathname;
                const method = req.method;

                res.setHeader('Content-Type', 'application/json');
                res.setHeader('Access-Control-Allow-Origin', '*');
                res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
                res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Device-Id');

                if (method === 'OPTIONS') {
                    res.writeHead(204);
                    res.end();
                    return;
                }

                if (method === 'GET' && (pathname === '/api/v1/health' || pathname === '/health')) {
                    res.writeHead(200);
                    res.end(JSON.stringify(this.handleHealth()));
                    return;
                }

                if (method === 'GET' && pathname === '/api/v1/sync/pull') {
                    const sinceCursor = parsedUrl.searchParams.get('sinceCursor') || 0;
                    const limit = parsedUrl.searchParams.get('limit') || 250;
                    const result = this.handlePull(sinceCursor, limit);
                    res.writeHead(200);
                    res.end(JSON.stringify(result));
                    return;
                }

                if (method === 'POST' && pathname === '/api/v1/sync/push') {
                    let bodyStr = '';
                    req.on('data', chunk => { bodyStr += chunk; });
                    req.on('end', () => {
                        try {
                            const body = JSON.parse(bodyStr || '{}');
                            const result = this.handlePush(body);
                            res.writeHead(200);
                            res.end(JSON.stringify(result));
                        } catch (err) {
                            res.writeHead(400);
                            res.end(JSON.stringify({ error: err.message }));
                        }
                    });
                    return;
                }

                res.writeHead(404);
                res.end(JSON.stringify({ error: 'Endpoint not found' }));
            });

            this.server.listen(this.port, () => {
                resolve(this.port);
            });
            this.server.on('error', reject);
        });
    }

    stop() {
        return new Promise((resolve) => {
            if (this.server) {
                this.server.close(() => resolve());
            } else {
                resolve();
            }
        });
    }
}

if (require.main === module) {
    const port = process.env.PORT || 8787;
    const server = new MedhaSyncServer(port);
    server.start().then(() => {
        console.log(`🚀 Medha Sync Server running on http://localhost:${port}`);
    });
}

module.exports = { MedhaSyncServer };
