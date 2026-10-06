// Medha Windows Desktop — Central Reactive State Store
// 100% faithful port of BlockStore.swift with SQLite FTS5 synchronization

class BlockStore {
    constructor(dbAdapter = null) {
        this.db = dbAdapter; // Either Electron IPC or direct SQLite handle

        // State Collections
        this.notebooks = [];
        this.selectedNotebookId = null;

        this.documents = [];
        this.selectedDocId = null;
        this.currentDoc = null;
        this.expandedDocIds = new Set();

        this.blocks = [];
        this.focusedBlockId = null;

        // Flashcards & Decks
        this.flashcards = [];
        this.decks = [];
        this.selectedDeckId = null;

        // Memory Palaces
        this.memoryPalaces = [];
        this.selectedPalaceId = null;
        this.palacePhotos = [];
        this.loci = [];

        // Ink Notes
        this.inkPages = [];
        this.inkUndoStack = [];
        this.inkRedoStack = [];

        // Subscriptions
        this.listeners = [];
    }

    subscribe(fn) {
        this.listeners.push(fn);
        return () => {
            this.listeners = this.listeners.filter(l => l !== fn);
        };
    }

    notify(event, payload = null) {
        for (const fn of this.listeners) {
            try { fn(event, payload); } catch (e) { console.error('Store listener error:', e); }
        }
    }

    async query(sql, params = []) {
        if (this.db) {
            if (typeof this.db.prepare === 'function') {
                return this.db.prepare(sql).all(...params);
            }
            const res = await this.db.query(sql, params);
            return res.data || [];
        } else if (typeof window !== 'undefined' && window.electronAPI) {
            const res = await window.electronAPI.dbQuery(sql, params);
            return res.data || [];
        }
        return [];
    }

    async execute(sql, params = []) {
        if (this.db) {
            if (typeof this.db.prepare === 'function') {
                return this.db.prepare(sql).run(...params);
            }
            return await this.db.execute(sql, params);
        } else if (typeof window !== 'undefined' && window.electronAPI) {
            return await window.electronAPI.dbExecute(sql, params);
        }
        return { changes: 1 };
    }

    async load() {
        this.notebooks = await this.query('SELECT * FROM notebook ORDER BY sortOrder ASC');
        if (this.notebooks.length > 0 && !this.selectedNotebookId) {
            this.selectedNotebookId = this.notebooks[0].id;
        }

        this.decks = await this.query('SELECT * FROM deck ORDER BY isNotesDefault DESC, name ASC');
        this.memoryPalaces = await this.query('SELECT * FROM memory_palace ORDER BY sortOrder ASC');
        if (this.memoryPalaces.length > 0) {
            this.selectedPalaceId = this.memoryPalaces[0].id;
            await this.loadPalaceDetails(this.selectedPalaceId);
        }

        await this.loadDocuments();
        this.notify('load');
    }

    async loadDocuments() {
        this.documents = await this.query(
            "SELECT * FROM block WHERE type IN ('doc', 'inkDoc') ORDER BY sortOrder ASC, createdAt ASC"
        );

        if (this.documents.length > 0 && !this.selectedDocId) {
            this.selectDocument(this.documents[0].id);
        } else if (this.selectedDocId) {
            await this.loadBlocks(this.selectedDocId);
        }
    }

    async selectDocument(docId) {
        this.selectedDocId = docId;
        this.currentDoc = this.documents.find(d => d.id === docId) || null;
        this.blocks = [];
        if (this.currentDoc) {
            if (this.currentDoc.type === 'inkDoc') {
                await this.loadInkPages(docId);
            } else {
                await this.loadBlocks(docId);
            }
        }
        this.notify('doc_selected', { docId });
    }

    async loadBlocks(rootDocId) {
        this.blocks = await this.query(
            'SELECT * FROM block WHERE rootDocId = ? AND id != ? ORDER BY sortOrder ASC, createdAt ASC',
            [rootDocId, rootDocId]
        );
        this.notify('blocks_loaded');
    }

    async loadInkPages(docId) {
        this.inkPages = await this.query(
            'SELECT * FROM ink_document_page WHERE docId = ? ORDER BY pageIndex ASC',
            [docId]
        );
        this.notify('ink_pages_loaded');
    }

    async loadPalaceDetails(palaceId) {
        this.palacePhotos = await this.query(
            'SELECT * FROM palace_photo WHERE palaceId = ? ORDER BY orderIndex ASC',
            [palaceId]
        );
        this.loci = await this.query(
            'SELECT * FROM palace_locus WHERE palaceId = ? ORDER BY orderIndex ASC',
            [palaceId]
        );
        this.notify('palace_loaded');
    }

    // --- Block CRUD Operations ---
    createBlock(type = 'paragraph', content = '', parentId = null, sortOrder = null) {
        if (!this.selectedDocId) return null;
        const id = `b-${Math.random().toString(36).substring(2, 10)}-${Date.now()}`;
        const now = new Date().toISOString();
        const order = sortOrder != null ? sortOrder : this.blocks.length + 1;

        const newBlock = {
            id,
            rootDocId: this.selectedDocId,
            parentId: parentId || this.selectedDocId,
            type,
            content,
            sortOrder: order,
            isCompleted: type === 'taskList' ? 0 : null,
            refTargetId: null,
            createdAt: now,
            updatedAt: now,
            notebookId: null
        };

        this.execute(`
            INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, isCompleted, refTargetId, createdAt, updatedAt, notebookId)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `, [
            newBlock.id, newBlock.rootDocId, newBlock.parentId, newBlock.type, newBlock.content,
            newBlock.sortOrder, newBlock.isCompleted, newBlock.refTargetId, newBlock.createdAt, newBlock.updatedAt, null
        ]);

        this.blocks.push(newBlock);
        this.syncBlockDocLinks(newBlock);
        this.notify('block_created', newBlock);
        return newBlock;
    }

    updateBlockContent(id, content) {
        const block = this.blocks.find(b => b.id === id);
        if (block) {
            block.content = content;
            block.updatedAt = new Date().toISOString();
            this.execute('UPDATE block SET content = ?, updatedAt = ? WHERE id = ?', [content, block.updatedAt, id]);
            this.syncBlockDocLinks(block);
            this.notify('block_updated', block);
        }
    }

    syncBlockDocLinks(block) {
        if (!block || !block.rootDocId) return;
        // Delete existing links originated from this block
        this.execute('DELETE FROM doc_link WHERE sourceBlockId = ?', [block.id]);

        const wikiLinkRegex = /\[\[(.*?)\]\]/g;
        let match;
        const now = new Date().toISOString();

        while ((match = wikiLinkRegex.exec(block.content || '')) !== null) {
            const targetTitle = match[1].trim();
            if (targetTitle.length > 0) {
                const targetDoc = this.documents.find(d => d.content && d.content.toLowerCase() === targetTitle.toLowerCase());
                const targetDocId = targetDoc ? targetDoc.id : null;
                const linkId = `link-${Math.random().toString(36).substring(2, 9)}`;

                this.execute(`
                    INSERT INTO doc_link (id, sourceDocId, sourceBlockId, targetTitle, targetDocId, createdAt)
                    VALUES (?, ?, ?, ?, ?, ?)
                `, [linkId, block.rootDocId, block.id, targetTitle, targetDocId, now]);
            }
        }
    }

    getBacklinks(docId) {
        const targetDoc = this.documents.find(d => d.id === docId);
        if (!targetDoc) return [];

        if (this.db && typeof this.db.prepare === 'function') {
            return this.db.prepare(`
                SELECT dl.id, dl.sourceDocId, dl.sourceBlockId, dl.targetTitle, dl.createdAt,
                       b.content AS blockContent, doc.content AS sourceDocTitle
                FROM doc_link dl
                JOIN block b ON b.id = dl.sourceBlockId
                JOIN block doc ON doc.id = dl.sourceDocId
                WHERE dl.targetDocId = ? OR dl.targetTitle = ?
            `).all(docId, targetDoc.content);
        }
        return [];
    }

    convertBlockType(id, toType) {
        const block = this.blocks.find(b => b.id === id);
        if (block) {
            block.type = toType;
            if (toType === 'taskList' && block.isCompleted == null) block.isCompleted = 0;
            block.updatedAt = new Date().toISOString();
            this.execute('UPDATE block SET type = ?, isCompleted = ?, updatedAt = ? WHERE id = ?', [toType, block.isCompleted, block.updatedAt, id]);
            this.notify('block_type_converted', block);
        }
    }

    toggleTask(id) {
        const block = this.blocks.find(b => b.id === id);
        if (block && block.type === 'taskList') {
            block.isCompleted = block.isCompleted ? 0 : 1;
            block.updatedAt = new Date().toISOString();
            this.execute('UPDATE block SET isCompleted = ?, updatedAt = ? WHERE id = ?', [block.isCompleted, block.updatedAt, id]);
            this.notify('task_toggled', block);
        }
    }

    deleteBlock(id) {
        const idx = this.blocks.findIndex(b => b.id === id);
        if (idx !== -1) {
            this.blocks.splice(idx, 1);
            this.execute('DELETE FROM block WHERE id = ?', [id]);
            this.notify('block_deleted', { id });
        }
    }

    // --- Document & Tree Operations ---
    createDocument(title = 'Untitled Note', parentId = null, notebookId = null, type = 'doc') {
        const id = `doc-${Math.random().toString(36).substring(2, 9)}`;
        const nb = notebookId || this.selectedNotebookId || 'nb-welcome-kb';
        const now = new Date().toISOString();

        const docBlock = {
            id,
            rootDocId: id,
            parentId: parentId || null,
            type,
            content: title,
            sortOrder: this.documents.length,
            isCompleted: null,
            refTargetId: null,
            createdAt: now,
            updatedAt: now,
            notebookId: nb
        };

        this.execute(`
            INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, isCompleted, refTargetId, createdAt, updatedAt, notebookId)
            VALUES (?, ?, ?, ?, ?, ?, null, null, ?, ?, ?)
        `, [id, id, parentId, type, title, docBlock.sortOrder, now, now, nb]);

        this.documents.push(docBlock);

        // If ink document, initialize page 0
        if (type === 'inkDoc') {
            const pageData = JSON.stringify({ schemaVersion: 1, pageWidth: 794, pageHeight: 1123, strokes: [] });
            this.execute(`
                INSERT INTO ink_document_page (id, docId, pageIndex, templateType, strokesData, textProjection, createdAt, updatedAt)
                VALUES (?, ?, 0, 'lined', ?, '', ?, ?)
            `, [`inkpage-${id}-0`, id, pageData, now, now]);
        }

        this.selectDocument(id);
        this.notify('tree_changed');
        return docBlock;
    }

    deleteDocument(docId) {
        // Recursive cascade deletion of document and all child descendants
        const getDescendants = (parentId) => {
            const children = this.documents.filter(d => d.parentId === parentId);
            let res = [...children];
            for (const c of children) {
                res = res.concat(getDescendants(c.id));
            }
            return res;
        };

        const toDelete = [this.documents.find(d => d.id === docId), ...getDescendants(docId)].filter(Boolean);
        const ids = toDelete.map(d => d.id);

        for (const id of ids) {
            this.execute('DELETE FROM block WHERE rootDocId = ? OR id = ?', [id, id]);
            this.execute('DELETE FROM ink_document_page WHERE docId = ?', [id]);
            this.execute('DELETE FROM flashcard WHERE docId = ?', [id]);
        }

        this.documents = this.documents.filter(d => !ids.includes(d.id));
        if (this.selectedDocId && ids.includes(this.selectedDocId)) {
            this.selectedDocId = this.documents.length > 0 ? this.documents[0].id : null;
            this.currentDoc = this.selectedDocId ? this.documents[0] : null;
            if (this.selectedDocId) this.loadBlocks(this.selectedDocId);
        }

        this.notify('tree_changed');
    }

    // --- Full-Text Search (FTS5) ---
    search(query) {
        if (!query || !query.trim()) return [];
        const clean = query.trim().replace(/['"]/g, '');

        if (this.db && typeof this.db.prepare === 'function') {
            const stmt = this.db.prepare(`
                SELECT b.id, b.rootDocId, b.content, b.type AS blockType, snippet(block_fts, 2, '<b>', '</b>', '...', 24) AS snippet
                FROM block_fts f
                JOIN block b ON b.id = f.id
                WHERE block_fts MATCH ?
                LIMIT 25
            `);
            return stmt.all(`${clean}*`);
        }

        // In-memory fallback
        return this.blocks.filter(b => b.content.toLowerCase().includes(clean.toLowerCase())).map(b => ({
            id: b.id,
            rootDocId: b.rootDocId,
            content: b.content,
            blockType: b.type,
            snippet: b.content
        }));
    }
}

if (typeof module !== 'undefined') {
    module.exports = { BlockStore };
}
