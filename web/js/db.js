// Medha Web — IndexedDB Local Vault Storage
// 100% client-side, zero cloud tracking, private offline-first database.

const DB_NAME = 'MedhaWebDB';
const DB_VERSION = 1;

class MedhaDatabase {
    constructor() {
        this.db = null;
        this.isReady = this.init();
    }

    async init() {
        return new Promise((resolve, reject) => {
            const request = indexedDB.open(DB_NAME, DB_VERSION);

            request.onupgradeneeded = (event) => {
                const db = event.target.result;

                // 1. Documents store
                if (!db.objectStoreNames.contains('documents')) {
                    const docStore = db.createObjectStore('documents', { keyPath: 'id' });
                    docStore.createIndex('parentId', 'parentId', { unique: false });
                    docStore.createIndex('updatedAt', 'updatedAt', { unique: false });
                }

                // 2. Blocks store (content blocks inside documents)
                if (!db.objectStoreNames.contains('blocks')) {
                    const blockStore = db.createObjectStore('blocks', { keyPath: 'id' });
                    blockStore.createIndex('docId', 'docId', { unique: false });
                    blockStore.createIndex('sortOrder', 'sortOrder', { unique: false });
                }

                // 3. Flashcards store (FSRS-managed cards)
                if (!db.objectStoreNames.contains('flashcards')) {
                    const cardStore = db.createObjectStore('flashcards', { keyPath: 'id' });
                    cardStore.createIndex('docId', 'docId', { unique: false });
                    cardStore.createIndex('due', 'due', { unique: false });
                }

                // 4. Key-Value Settings
                if (!db.objectStoreNames.contains('settings')) {
                    db.createObjectStore('settings', { keyPath: 'key' });
                }
            };

            request.onsuccess = (event) => {
                this.db = event.target.result;
                resolve(this.db);
            };

            request.onerror = (event) => {
                console.error('IndexedDB open failed:', event.target.error);
                reject(event.target.error);
            };
        });
    }

    // Generic transaction helper
    async tx(storeName, mode, callback) {
        await this.isReady;
        return new Promise((resolve, reject) => {
            const transaction = this.db.transaction([storeName], mode);
            const store = transaction.objectStore(storeName);
            let result;

            transaction.oncomplete = () => resolve(result);
            transaction.onerror = (e) => reject(e.target.error);

            result = callback(store);
        });
    }

    // --- Document CRUD ---
    async getAllDocuments() {
        return this.tx('documents', 'readonly', (store) => {
            return new Promise((resolve) => {
                const req = store.getAll();
                req.onsuccess = () => resolve(req.result || []);
            });
        });
    }

    async saveDocument(doc) {
        doc.updatedAt = Date.now();
        return this.tx('documents', 'readwrite', (store) => {
            store.put(doc);
        });
    }

    async deleteDocument(docId) {
        // Cascading deletion of doc, child docs, blocks, and associated cards
        const allDocs = await this.getAllDocuments();
        const toDeleteIds = new Set([docId]);

        function collectChildren(parent) {
            for (const d of allDocs) {
                if (d.parentId === parent && !toDeleteIds.has(d.id)) {
                    toDeleteIds.add(d.id);
                    collectChildren(d.id);
                }
            }
        }
        collectChildren(docId);

        for (const id of toDeleteIds) {
            await this.tx('documents', 'readwrite', (store) => store.delete(id));
            const blocks = await this.getBlocksForDoc(id);
            for (const b of blocks) {
                await this.tx('blocks', 'readwrite', (store) => store.delete(b.id));
            }
            const cards = await this.getFlashcardsForDoc(id);
            for (const c of cards) {
                await this.tx('flashcards', 'readwrite', (store) => store.delete(c.id));
            }
        }
    }

    // --- Block CRUD ---
    async getAllBlocks() {
        return this.tx('blocks', 'readonly', (store) => {
            return new Promise((resolve) => {
                const req = store.getAll();
                req.onsuccess = () => resolve(req.result || []);
            });
        });
    }

    async getBlocksForDoc(docId) {
        return this.tx('blocks', 'readonly', (store) => {
            return new Promise((resolve) => {
                const index = store.index('docId');
                const req = index.getAll(docId);
                req.onsuccess = () => {
                    const sorted = (req.result || []).sort((a, b) => a.sortOrder - b.sortOrder);
                    resolve(sorted);
                };
            });
        });
    }

    async saveBlock(block) {
        return this.tx('blocks', 'readwrite', (store) => {
            store.put(block);
        });
    }

    async saveBlocks(blocks) {
        await this.isReady;
        return new Promise((resolve, reject) => {
            const transaction = this.db.transaction(['blocks'], 'readwrite');
            const store = transaction.objectStore('blocks');
            blocks.forEach((b) => store.put(b));
            transaction.oncomplete = () => resolve();
            transaction.onerror = (e) => reject(e.target.error);
        });
    }

    async deleteBlock(blockId) {
        return this.tx('blocks', 'readwrite', (store) => {
            store.delete(blockId);
        });
    }

    // --- Flashcards CRUD ---
    async getAllFlashcards() {
        return this.tx('flashcards', 'readonly', (store) => {
            return new Promise((resolve) => {
                const req = store.getAll();
                req.onsuccess = () => resolve(req.result || []);
            });
        });
    }

    async getFlashcardsForDoc(docId) {
        return this.tx('flashcards', 'readonly', (store) => {
            return new Promise((resolve) => {
                const index = store.index('docId');
                const req = index.getAll(docId);
                req.onsuccess = () => resolve(req.result || []);
            });
        });
    }

    async saveFlashcard(card) {
        return this.tx('flashcards', 'readwrite', (store) => {
            store.put(card);
        });
    }

    async deleteFlashcard(cardId) {
        return this.tx('flashcards', 'readwrite', (store) => {
            store.delete(cardId);
        });
    }

    // --- Settings Key-Value ---
    async getSetting(key, defaultValue = null) {
        return this.tx('settings', 'readonly', (store) => {
            return new Promise((resolve) => {
                const req = store.get(key);
                req.onsuccess = () => {
                    resolve(req.result !== undefined ? req.result.value : defaultValue);
                };
            });
        });
    }

    async saveSetting(key, value) {
        return this.tx('settings', 'readwrite', (store) => {
            store.put({ key, value });
        });
    }

    // --- Seed Demo Data If Empty ---
    async seedDemoDataIfEmpty() {
        const docs = await this.getAllDocuments();
        if (docs.length > 0) return;

        const rootDoc = {
            id: 'doc-welcome',
            title: 'Welcome to Medha Web 🏛️',
            parentId: null,
            sortOrder: 0,
            createdAt: Date.now(),
            updatedAt: Date.now()
        };
        await this.saveDocument(rootDoc);

        const subDoc = {
            id: 'doc-study-grounding',
            title: 'Free Study Grounding & AI Architecture',
            parentId: 'doc-welcome',
            sortOrder: 0,
            createdAt: Date.now(),
            updatedAt: Date.now()
        };
        await this.saveDocument(subDoc);

        const initialBlocks = [
            { id: 'b-1', docId: 'doc-welcome', type: 'h1', content: 'Medha Web: Local-First Mind Palace', isChecked: false, sortOrder: 0 },
            { id: 'b-2', docId: 'doc-welcome', type: 'callout', content: 'Medha is a hierarchical note-taking and cognitive retention system powered by FSRS spaced repetition and free academic knowledge grounding.', isChecked: false, sortOrder: 1 },
            { id: 'b-3', docId: 'doc-welcome', type: 'paragraph', content: 'Every thought in Medha is structured downward into modular sub-notes. You can review flashcards with our spaced repetition tutor, visualize your ideas in the 2D Knowledge Graph, or synthesize research with AI.', isChecked: false, sortOrder: 2 },
            { id: 'b-4', docId: 'doc-welcome', type: 'h2', content: 'Key Web Features', isChecked: false, sortOrder: 3 },
            { id: 'b-5', docId: 'doc-welcome', type: 'task', content: 'Explore the 3D card flip flashcard interface with FSRS scheduler', isChecked: false, sortOrder: 4 },
            { id: 'b-6', docId: 'doc-welcome', type: 'task', content: 'Switch to the 2D Knowledge Graph tab to see note connections', isChecked: false, sortOrder: 5 },
            { id: 'b-7', docId: 'doc-welcome', type: 'task', content: 'Test free study knowledge grounding across Wikipedia, OpenAlex, and Europe PMC', isChecked: true, sortOrder: 6 }
        ];
        await this.saveBlocks(initialBlocks);

        const initialCards = [
            {
                id: 'card-1',
                docId: 'doc-welcome',
                front: 'What does the FSRS algorithm calculate for every memory flashcard?',
                back: 'FSRS computes Difficulty (D), Stability (S), and Retrievability (R) to predict optimal review intervals with 90% memory retention.',
                hint: 'Three core memory variables: D, S, and R.',
                state: 0, // New
                step: 0,
                stability: 0,
                difficulty: 0,
                due: Date.now(),
                reps: 0,
                lapses: 0,
                lastReview: null
            },
            {
                id: 'card-2',
                docId: 'doc-study-grounding',
                front: 'Why is knowledge grounding crucial for 1.5B parameter local AI models?',
                back: 'Small models fit into 4 GB RAM but lack niche trivia; grounding feeds live factual extracts (e.g. from Wikipedia or OpenAlex) into the prompt to prevent hallucinations without needing high VRAM.',
                hint: 'Compensates for limited world trivia weights.',
                state: 0,
                step: 0,
                stability: 0,
                difficulty: 0,
                due: Date.now(),
                reps: 0,
                lapses: 0,
                lastReview: null
            }
        ];
        for (const c of initialCards) {
            await this.saveFlashcard(c);
        }
    }
}

export const db = new MedhaDatabase();
