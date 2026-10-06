// Medha Windows Desktop — Anki Package (.apkg) Importer
// 100% faithful port of AnkiImporter.swift
// Supports legacy SQLite (.anki2) and modern Zstandard-compressed (.anki21, .anki21b) collections.

const fs = require('fs');
const path = require('path');
const os = require('os');
const AdmZip = require('adm-zip');
const fzstd = require('fzstd');
const Database = require('better-sqlite3');

class AnkiImporter {
    static stripHTML(raw) {
        if (!raw) return '';
        let text = raw;
        text = text.replace(/<br\s*\/?>/gi, '\n');
        text = text.replace(/<\/div>/gi, '\n');
        text = text.replace(/<\/p>/gi, '\n\n');
        text = text.replace(/<\/li>/gi, '\n');
        text = text.replace(/<li>/gi, '• ');
        text = text.replace(/\[sound:[^\]]+\]/g, '');
        text = text.replace(/<[^>]+>/g, '');
        text = text
            .replace(/&nbsp;/g, ' ')
            .replace(/&amp;/g, '&')
            .replace(/&lt;/g, '<')
            .replace(/&gt;/g, '>')
            .replace(/&quot;/g, '"')
            .replace(/&#39;/g, "'");
        return text.trim();
    }

    static parseClozeDeletions(text, targetCardOrd) {
        const clozeRegex = /\{\{c(\d+)::([^}]+)\}\}/g;
        let matches = [];
        let match;
        while ((match = clozeRegex.exec(text)) !== null) {
            matches.push({
                full: match[0],
                idx: parseInt(match[1], 10),
                content: match[2]
            });
        }

        if (matches.length === 0) return null;

        const targetIndex = targetCardOrd + 1;
        const hasTarget = matches.some(m => m.idx === targetIndex);
        if (!hasTarget) return null;

        let question = text;
        let answer = '';

        for (const m of matches) {
            const parts = m.content.split('::');
            const hiddenText = parts[0];
            const hint = parts.length > 1 ? parts[1] : null;

            if (m.idx === targetIndex) {
                const replacement = hint ? `[...${hint}]` : '[...]';
                question = question.replace(m.full, replacement);
                answer = hiddenText;
            } else {
                question = question.replace(m.full, hiddenText);
            }
        }

        return {
            front: this.stripHTML(question),
            back: this.stripHTML(answer)
        };
    }

    static importPackage(apkgPath, targetDb, defaultDocId = 'doc-dist-sys', defaultNotebookId = 'nb-welcome-kb') {
        if (!fs.existsSync(apkgPath)) {
            throw new Error(`File not found: ${apkgPath}`);
        }

        const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'medha-anki-'));
        try {
            const zip = new AdmZip(apkgPath);
            zip.extractAllTo(tempDir, true);

            let dbFilePath = null;
            let parsedFromModern = false;

            const modernCandidates = ['collection.anki21b', 'collection.anki21'];
            for (const candidate of modernCandidates) {
                const fullCandidate = path.join(tempDir, candidate);
                if (fs.existsSync(fullCandidate)) {
                    const compressedBuf = fs.readFileSync(fullCandidate);
                    // Check if file is zstd compressed (magic bytes: 0x28, 0xB5, 0x2F, 0xFD)
                    if (compressedBuf.length >= 4 &&
                        compressedBuf[0] === 0x28 && compressedBuf[1] === 0xB5 &&
                        compressedBuf[2] === 0x2F && compressedBuf[3] === 0xFD) {
                        const decompressed = fzstd.decompress(new Uint8Array(compressedBuf));
                        const extractedPath = path.join(tempDir, 'collection_decompressed.db');
                        fs.writeFileSync(extractedPath, Buffer.from(decompressed));
                        dbFilePath = extractedPath;
                        parsedFromModern = true;
                        break;
                    } else {
                        dbFilePath = fullCandidate;
                        parsedFromModern = true;
                        break;
                    }
                }
            }

            if (!dbFilePath) {
                const legacyPath = path.join(tempDir, 'collection.anki2');
                if (fs.existsSync(legacyPath)) {
                    dbFilePath = legacyPath;
                }
            }

            if (!dbFilePath) {
                throw new Error('No valid Anki database (collection.anki21 or collection.anki2) found inside the package.');
            }

            const ankiDb = new Database(dbFilePath, { readonly: true });
            try {
                // Read decks
                let deckNames = new Map();
                const colRow = ankiDb.prepare('SELECT decks, models FROM col LIMIT 1').get();
                if (colRow && colRow.decks) {
                    try {
                        const decksObj = JSON.parse(colRow.decks);
                        for (const key of Object.keys(decksObj)) {
                            deckNames.set(parseInt(key, 10), decksObj[key].name || 'Imported Deck');
                        }
                    } catch (e) {
                        console.warn('Failed to parse decks JSON:', e);
                    }
                }

                // Query cards and notes
                const cardsQuery = ankiDb.prepare(`
                    SELECT c.id AS card_id, c.did, c.ord, n.id AS note_id, n.flds, n.tags, n.mid
                    FROM cards c
                    JOIN notes n ON c.nid = n.id
                `);
                const rows = cardsQuery.all();

                let importedCount = 0;
                let createdDecks = new Set();
                const now = new Date().toISOString();

                targetDb.transaction(() => {
                    const insertDeckStmt = targetDb.prepare(`
                        INSERT OR IGNORE INTO deck (id, name, description, colorHex, icon, isNotesDefault, createdAt, updatedAt)
                        VALUES (?, ?, ?, '#10B981', 'rectangle.stack', 0, ?, ?)
                    `);

                    const insertCardStmt = targetDb.prepare(`
                        INSERT OR REPLACE INTO flashcard (
                            id, docId, notebookId, front, back, sourceBlockId, hint,
                            fsrsState, stability, difficulty, elapsedDays, scheduledDays, reps, lapses,
                            lastReview, due, createdAt, updatedAt, deckId, isSuspended
                        )
                        VALUES (?, ?, ?, ?, ?, null, ?, 0, 0.0, 0.0, 0, 0, 0, 0, null, ?, ?, ?, ?, 0)
                    `);

                    for (const row of rows) {
                        const deckName = deckNames.get(row.did) || 'Imported Anki Deck';
                        const deckId = `deck-anki-${row.did}`;

                        if (!createdDecks.has(deckId)) {
                            insertDeckStmt.run(deckId, deckName, `Imported from Anki package: ${path.basename(apkgPath)}`, now, now);
                            createdDecks.add(deckId);
                        }

                        const fields = (row.flds || '').split('\x1f');
                        let front = '';
                        let back = '';

                        if (fields.length >= 2) {
                            front = this.stripHTML(fields[0]);
                            back = this.stripHTML(fields[1]);
                        } else if (fields.length === 1) {
                            front = this.stripHTML(fields[0]);
                            back = 'See front';
                        }

                        // Check cloze deletion
                        const rawFull = row.flds || '';
                        if (rawFull.includes('{{c')) {
                            const cloze = this.parseClozeDeletions(rawFull, row.ord);
                            if (cloze) {
                                front = cloze.front;
                                back = cloze.back;
                            }
                        }

                        if (!front) continue;

                        const cardId = `anki-${row.card_id}`;
                        insertCardStmt.run(
                            cardId,
                            defaultDocId,
                            defaultNotebookId,
                            front,
                            back,
                            row.tags ? `Tags: ${row.tags.trim()}` : null,
                            now,
                            now,
                            now,
                            deckId
                        );
                        importedCount++;
                    }
                })();

                return {
                    importedCardCount: importedCount,
                    createdDeckCount: createdDecks.size,
                    deckNames: Array.from(createdDecks),
                    parsedFromModern,
                    details: `Successfully imported ${importedCount} cards into ${createdDecks.size} decks.`
                };
            } finally {
                ankiDb.close();
            }
        } finally {
            // Clean up temporary extraction directory
            try {
                fs.rmSync(tempDir, { recursive: true, force: true });
            } catch (e) {
                console.warn('Temp cleanup notice:', e);
            }
        }
    }
}

module.exports = { AnkiImporter };
