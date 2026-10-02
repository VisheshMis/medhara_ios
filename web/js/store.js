// Medha Web — Reactive State & Document Store
// Manages documents hierarchy, block editor state, and live flashcard collections.

import { db } from './db.js';
import { LinkParser } from './linkParser.js';

class Store {
    constructor() {
        this.documents = [];
        this.currentDoc = null;
        this.blocks = [];
        this.flashcards = [];
        this.listeners = new Set();

        this.saveTimeout = null;
    }

    subscribe(listener) {
        this.listeners.add(listener);
        return () => this.listeners.delete(listener);
    }

    notify(event = 'change', payload = null) {
        for (const listener of this.listeners) {
            try {
                listener(event, payload);
            } catch (err) {
                console.error('Store listener error:', err);
            }
        }
    }

    async load() {
        await db.seedDemoDataIfEmpty();
        this.documents = await db.getAllDocuments();
        this.flashcards = await db.getAllFlashcards();

        if (this.documents.length > 0) {
            await this.selectDocument(this.documents[0].id);
        }
        this.notify('load');
    }


    async selectDocument(docId) {
        const found = this.documents.find(d => d.id === docId);
        if (!found) return;

        this.currentDoc = found;
        this.blocks = await db.getBlocksForDoc(docId);

        // If no blocks, add an initial empty paragraph
        if (this.blocks.length === 0) {
            const initialBlock = {
                id: 'b-' + Math.random().toString(36).substring(2, 9),
                docId: docId,
                type: 'paragraph',
                content: '',
                isChecked: false,
                sortOrder: 0
            };
            this.blocks = [initialBlock];
            await db.saveBlock(initialBlock);
        }

        this.notify('doc_selected', { doc: found });
    }

    // Create a new child or sibling document
    async createDocument(title = 'Untitled Note', parentId = null) {
        const newDoc = {
            id: 'doc-' + Math.random().toString(36).substring(2, 9),
            title,
            parentId,
            sortOrder: this.documents.length,
            createdAt: Date.now(),
            updatedAt: Date.now()
        };

        await db.saveDocument(newDoc);
        this.documents.push(newDoc);

        const initialBlock = {
            id: 'b-' + Math.random().toString(36).substring(2, 9),
            docId: newDoc.id,
            type: 'paragraph',
            content: '',
            isChecked: false,
            sortOrder: 0
        };
        await db.saveBlock(initialBlock);

        this.notify('tree_changed', { doc: newDoc });
        await this.selectDocument(newDoc.id);
        return newDoc;
    }

    async updateDocTitle(docId, newTitle) {
        const doc = this.documents.find(d => d.id === docId);
        if (!doc) return;
        doc.title = newTitle;
        doc.updatedAt = Date.now();

        clearTimeout(this.titleSaveTimeout);
        this.titleSaveTimeout = setTimeout(() => {
            db.saveDocument(doc);
        }, 300);

        this.notify('title_changed', { docId, title: newTitle });
    }

    async deleteDocument(docId) {
        await db.deleteDocument(docId);
        this.documents = await db.getAllDocuments();
        this.flashcards = await db.getAllFlashcards();

        if (this.currentDoc?.id === docId) {
            if (this.documents.length > 0) {
                await this.selectDocument(this.documents[0].id);
            } else {
                this.currentDoc = null;
                this.blocks = [];
                this.notify('doc_selected', { doc: null });
            }
        }
        this.notify('tree_changed', { deletedId: docId });
    }

    // --- Block Manipulation ---
    updateBlock(blockId, partial) {
        const b = this.blocks.find(x => x.id === blockId);
        if (!b) return;
        Object.assign(b, partial);

        clearTimeout(this.saveTimeout);
        this.saveTimeout = setTimeout(() => {
            db.saveBlock(b);
        }, 300);

        // Notify content change without forcing DOM re-renders
        this.notify('block_content', { blockId, partial });
    }

    async insertBlockAfter(afterId, type = 'paragraph', content = '') {
        const idx = this.blocks.findIndex(x => x.id === afterId);
        const newBlock = {
            id: 'b-' + Math.random().toString(36).substring(2, 9),
            docId: this.currentDoc.id,
            type,
            content,
            isChecked: false,
            sortOrder: (idx === -1 ? this.blocks.length : idx + 1)
        };

        if (idx === -1) {
            this.blocks.push(newBlock);
        } else {
            this.blocks.splice(idx + 1, 0, newBlock);
            // Re-index sortOrder
            this.blocks.forEach((b, i) => b.sortOrder = i);
        }

        await db.saveBlocks(this.blocks);
        this.notify('blocks_structure_changed', { newBlock });
        return newBlock;
    }

    async deleteBlock(blockId) {
        if (this.blocks.length <= 1) {
            // Keep at least one empty block
            this.blocks[0].content = '';
            this.blocks[0].type = 'paragraph';
            await db.saveBlock(this.blocks[0]);
            this.notify('blocks_structure_changed', { resetBlock: this.blocks[0] });
            return;
        }

        const idx = this.blocks.findIndex(x => x.id === blockId);
        if (idx !== -1) {
            this.blocks.splice(idx, 1);
            this.blocks.forEach((b, i) => b.sortOrder = i);
            await db.deleteBlock(blockId);
            await db.saveBlocks(this.blocks);
            this.notify('blocks_structure_changed', { deletedId: blockId });
        }
    }

    async convertBlockType(blockId, newType) {
        const b = this.blocks.find(x => x.id === blockId);
        if (!b) return;
        b.type = newType;
        await db.saveBlock(b);
        this.notify('blocks_structure_changed', { convertedBlock: b });
    }

    async moveBlock(blockId, direction) {
        const idx = this.blocks.findIndex(x => x.id === blockId);
        if (idx === -1) return;
        const targetIdx = direction === 'up' ? idx - 1 : idx + 1;
        if (targetIdx < 0 || targetIdx >= this.blocks.length) return;

        const temp = this.blocks[idx];
        this.blocks[idx] = this.blocks[targetIdx];
        this.blocks[targetIdx] = temp;

        this.blocks.forEach((b, i) => b.sortOrder = i);
        await db.saveBlocks(this.blocks);
        this.notify('blocks_structure_changed', { movedBlockId: blockId });
    }

    async indentBlock(blockId) {
        const b = this.blocks.find(x => x.id === blockId);
        if (!b) return;
        b.indent = Math.min((b.indent || 0) + 1, 4);
        await db.saveBlock(b);
        this.notify('blocks_structure_changed', { blockId });
    }

    async outdentBlock(blockId) {
        const b = this.blocks.find(x => x.id === blockId);
        if (!b) return;
        b.indent = Math.max((b.indent || 0) - 1, 0);
        await db.saveBlock(b);
        this.notify('blocks_structure_changed', { blockId });
    }

    // --- Flashcard Store & Creation ---
    async createFlashcard({ front, back, hint = '', docId = null }) {
        const newCard = {
            id: 'card-' + Math.random().toString(36).substring(2, 9),
            docId: docId || this.currentDoc?.id || null,
            front,
            back,
            hint,
            state: 0,
            step: 0,
            stability: 0,
            difficulty: 0,
            due: Date.now(),
            reps: 0,
            lapses: 0,
            lastReview: null
        };
        await db.saveFlashcard(newCard);
        this.flashcards.push(newCard);
        this.notify('flashcards_changed', { newCard });
        return newCard;
    }

    async saveFlashcard(card) {
        await db.saveFlashcard(card);
        const idx = this.flashcards.findIndex(c => c.id === card.id);
        if (idx !== -1) {
            this.flashcards[idx] = card;
        } else {
            this.flashcards.push(card);
        }
        this.notify('flashcards_changed', { card });
    }

    async deleteFlashcard(cardId) {
        await db.deleteFlashcard(cardId);
        this.flashcards = this.flashcards.filter(c => c.id !== cardId);
        this.notify('flashcards_changed', { deletedId: cardId });
    }

    getFlashcardsForCurrentDoc() {
        if (!this.currentDoc) return [];
        return this.flashcards.filter(c => c.docId === this.currentDoc.id);
    }

    // --- Folder & Child Queries ---
    getChildDocuments(docId) {
        return this.documents.filter(d => d.parentId === docId).sort((a, b) => (a.sortOrder || 0) - (b.sortOrder || 0));
    }

    getDocAncestry(docId) {
        const ancestry = [];
        let curr = this.documents.find(d => d.id === docId);
        while (curr) {
            ancestry.unshift(curr);
            curr = curr.parentId ? this.documents.find(d => d.id === curr.parentId) : null;
        }
        return ancestry;
    }

    // --- Outline Extraction (H1, H2, H3) ---
    getOutline(docId) {
        const docBlocks = (this.currentDoc?.id === docId) ? this.blocks : [];
        return docBlocks.filter(b => b.type === 'heading1' || b.type === 'heading2' || b.type === 'heading3')
            .map(b => ({
                blockId: b.id,
                title: b.content.trim() || 'Untitled Heading',
                level: b.type === 'heading1' ? 1 : (b.type === 'heading2' ? 2 : 3),
                sortOrder: b.sortOrder
            }));
    }

    // --- Backlinks Query ---
    async getBacklinks(docId) {
        const targetDoc = this.documents.find(d => d.id === docId);
        if (!targetDoc) return [];
        const title = targetDoc.title || '';
        const allBlocks = await db.getAllBlocks();
        const backlinks = [];

        for (const block of allBlocks) {
            if (block.docId === docId) continue; // skip self
            const content = block.content || '';
            const srcDoc = this.documents.find(d => d.id === block.docId);
            if (!srcDoc) continue;

            const isWikiMatch = title && (content.includes(`[[${title}]]`) || content.toLowerCase().includes(`[[${title.toLowerCase()}]]`));
            const isRefMatch = content.includes(`((${docId}))`) || (this.blocks.some(b => content.includes(`((${b.id}))`)));

            if (isWikiMatch || isRefMatch) {
                backlinks.push({
                    block,
                    sourceDocId: srcDoc.id,
                    sourceDocTitle: srcDoc.title || 'Untitled Note',
                    contextSnippet: content,
                    linkType: isWikiMatch ? 'wikiLink' : 'blockRef'
                });
            }
        }
        return backlinks;
    }

    // --- Markdown & JSON Export ---
    exportCurrentAsMarkdown() {
        if (!this.currentDoc) return '';
        const lines = [`# ${this.currentDoc.title || 'Untitled Note'}\n`];
        for (const b of this.blocks) {
            const indent = '  '.repeat(b.indent || 0);
            switch (b.type) {
                case 'heading1': lines.push(`\n# ${b.content}\n`); break;
                case 'heading2': lines.push(`\n## ${b.content}\n`); break;
                case 'heading3': lines.push(`\n### ${b.content}\n`); break;
                case 'bulletList':
                case 'bullet': lines.push(`${indent}- ${b.content}`); break;
                case 'taskList':
                case 'task': lines.push(`${indent}- [${b.isChecked ? 'x' : ' '}] ${b.content}`); break;
                case 'codeBlock': lines.push(`\`\`\`\n${b.content}\n\`\`\`\n`); break;
                case 'quote': lines.push(`> ${b.content}\n`); break;
                case 'callout': lines.push(`> [!NOTE]\n> ${b.content}\n`); break;
                default: lines.push(`${indent}${b.content}\n`); break;
            }
        }
        return lines.join('\n');
    }

    exportCurrentAsJSON() {
        if (!this.currentDoc) return '{}';
        return JSON.stringify({
            document: this.currentDoc,
            blocks: this.blocks
        }, null, 2);
    }

    async createDocFromWikiLink(title) {
        return this.createDocument(title, null);
    }

    async getLocalGraphData(docId, depth = 1, includeTree = false) {
        if (!docId) return { nodes: [], edges: [] };
        const allBlocks = await db.getAllBlocks();
        const docMap = new Map(this.documents.map(d => [d.id, d]));
        const targetDoc = docMap.get(docId);
        if (!targetDoc) return { nodes: [], edges: [] };

        const allEdges = [];
        const ghostMap = new Map();
        const ghostNodes = [];

        for (const block of allBlocks) {
            const content = block.content || '';
            const sourceDocId = block.docId;
            if (!sourceDocId) continue;

            const wikiMatches = LinkParser.extractWikiLinks(content);
            for (const wm of wikiMatches) {
                const target = this.documents.find(d => (d.title || '').toLowerCase() === wm.target.toLowerCase());
                if (target) {
                    if (target.id !== sourceDocId) {
                        allEdges.push({ sourceId: sourceDocId, targetId: target.id, type: 'wikiLink' });
                    }
                } else {
                    const ghostKey = wm.target.toLowerCase();
                    let ghostId = ghostMap.get(ghostKey);
                    if (!ghostId) {
                        ghostId = 'unresolved-' + ghostKey;
                        ghostMap.set(ghostKey, ghostId);
                        ghostNodes.push({ id: ghostId, title: wm.target, isUnresolved: true });
                    }
                    allEdges.push({ sourceId: sourceDocId, targetId: ghostId, type: 'wikiLink' });
                }
            }

            const refMatches = LinkParser.extractBlockRefs(content);
            for (const rm of refMatches) {
                const refBlock = allBlocks.find(b => b.id === rm.blockId);
                if (refBlock && refBlock.docId && refBlock.docId !== sourceDocId) {
                    allEdges.push({ sourceId: sourceDocId, targetId: refBlock.docId, type: 'blockRef' });
                }
            }

            if (block.type === 'blockRef' && block.refTargetId) {
                const refBlock = allBlocks.find(b => b.id === block.refTargetId);
                if (refBlock && refBlock.docId && refBlock.docId !== sourceDocId) {
                    allEdges.push({ sourceId: sourceDocId, targetId: refBlock.docId, type: 'blockRef' });
                }
            }
        }

        if (includeTree) {
            for (const doc of this.documents) {
                if (doc.parentId && docMap.has(doc.parentId)) {
                    allEdges.push({ sourceId: doc.parentId, targetId: doc.id, type: 'contains' });
                }
            }
        }

        const adj = new Map();
        for (const e of allEdges) {
            if (!adj.has(e.sourceId)) adj.set(e.sourceId, new Set());
            if (!adj.has(e.targetId)) adj.set(e.targetId, new Set());
            adj.get(e.sourceId).add(e.targetId);
            adj.get(e.targetId).add(e.sourceId);
        }

        const visited = new Set([docId]);
        const queue = [{ id: docId, hop: 0 }];

        while (queue.length > 0) {
            const { id: curr, hop } = queue.shift();
            if (hop < depth) {
                const neighbors = adj.get(curr) || new Set();
                for (const neighbor of neighbors) {
                    if (!visited.has(neighbor)) {
                        visited.add(neighbor);
                        queue.push({ id: neighbor, hop: hop + 1 });
                    }
                }
            }
        }

        const resultNodes = [];
        for (const id of visited) {
            if (docMap.has(id)) {
                const doc = docMap.get(id);
                resultNodes.push({
                    id: doc.id,
                    title: doc.title || 'Untitled Note',
                    parentId: doc.parentId,
                    isCurrentDoc: doc.id === docId,
                    isUnresolved: false
                });
            } else {
                const ghost = ghostNodes.find(g => g.id === id);
                if (ghost) resultNodes.push(ghost);
            }
        }

        const validEdges = allEdges.filter(e => visited.has(e.sourceId) && visited.has(e.targetId));
        return { nodes: resultNodes, edges: validEdges };
    }

    // Get hierarchical document tree
    getDocumentTree(filter = '') {
        const query = (filter || '').toLowerCase().trim();
        const map = new Map();
        const roots = [];

        for (const doc of this.documents) {
            map.set(doc.id, { ...doc, children: [] });
        }

        for (const doc of this.documents) {
            const node = map.get(doc.id);
            if (doc.parentId && map.has(doc.parentId)) {
                map.get(doc.parentId).children.push(node);
            } else {
                roots.push(node);
            }
        }

        if (!query) return roots;

        // Recursive filter
        function filterNodes(nodes) {
            const res = [];
            for (const n of nodes) {
                const titleMatch = (n.title || '').toLowerCase().includes(query);
                const matchingChildren = filterNodes(n.children);
                if (titleMatch || matchingChildren.length > 0) {
                    res.push({ ...n, children: matchingChildren });
                }
            }
            return res;
        }

        return filterNodes(roots);
    }
}

export const store = new Store();
