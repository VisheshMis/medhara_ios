// Medha Windows Desktop — Main Application Orchestrator
// Connects UI, engines, and shortcuts with 100% feature parity to macOS Medha

let BlockStore, fsrs, Rating, BlockEditorEngine, InkCanvas, PalaceCanvas, KnowledgeGraphEngine, AutoNotePipeline, FocusTimerManager, ExportService;

if (typeof require !== 'undefined') {
    ({ BlockStore } = require('./store'));
    ({ fsrs, Rating } = require('./flashcards/fsrs'));
    ({ BlockEditorEngine } = require('./editor/blockEngine'));
    ({ InkCanvas } = require('./ink/inkCanvas'));
    ({ PalaceCanvas } = require('./palace/palaceCanvas'));
    ({ KnowledgeGraphEngine } = require('./graph/graphPhysics'));
    ({ AutoNotePipeline } = require('./ai/autoNotePipeline'));
    ({ FocusTimerManager } = require('./timer/focusTimer'));
    ({ ExportService } = require('./exportService'));
} else if (typeof window !== 'undefined' && window.__MedhaModules) {
    ({ BlockStore, fsrs, Rating, BlockEditorEngine, InkCanvas, PalaceCanvas, KnowledgeGraphEngine, AutoNotePipeline, FocusTimerManager, ExportService } = window.__MedhaModules);
}

class MedhaDesktopApp {
    constructor() {
        this.store = new BlockStore();
        this.timerManager = new FocusTimerManager();
        this.autoNote = new AutoNotePipeline(this.store);

        this.activeView = 'editor'; // 'editor' | 'flashcards' | 'graph' | 'palace'
        this.editorEngine = null;
        this.inkCanvas = null;
        this.palaceCanvas = null;
        this.graphEngine = null;

        // Flashcards state
        this.currentCardIndex = 0;
        this.isCardFlipped = false;
        this.dueCards = [];

        // Panels state
        this.isDocTreeVisible = true;
        this.isInspectorVisible = false;
        this.isAIAssistantVisible = false;
    }

    async init() {
        this.bindWindowControls();
        this.bindKeyboardShortcuts();
        this.initTimer();

        await this.store.load();

        this.initUI();
        this.bindNavigationTabs();
        this.initCommandPalette();

        this.store.subscribe((event) => {
            if (event === 'load' || event === 'tree_changed') {
                this.renderDocTree();
                this.renderSidebarNotebooks();
                if (this.activeView === 'graph' && this.graphEngine) {
                    this.graphEngine.updateData(this.store.documents);
                }
            } else if (event === 'doc_selected') {
                this.renderActiveDocument();
            } else if (event === 'blocks_loaded') {
                if (this.activeView === 'editor' && this.editorEngine) {
                    this.editorEngine.renderBlocks();
                }
            }
        });

        this.renderSidebarNotebooks();
        this.renderDocTree();
        this.renderActiveDocument();
    }

    bindWindowControls() {
        // macOS Traffic Lights
        document.getElementById('tl-close')?.addEventListener('click', () => {
            if (window.electronAPI) window.electronAPI.close();
        });
        document.getElementById('tl-minimize')?.addEventListener('click', () => {
            if (window.electronAPI) window.electronAPI.minimize();
        });
        document.getElementById('tl-maximize')?.addEventListener('click', () => {
            if (window.electronAPI) window.electronAPI.maximize();
        });

        // Windows 11 style buttons (if toggled)
        document.getElementById('win-close')?.addEventListener('click', () => {
            if (window.electronAPI) window.electronAPI.close();
        });
        document.getElementById('win-minimize')?.addEventListener('click', () => {
            if (window.electronAPI) window.electronAPI.minimize();
        });
        document.getElementById('win-maximize')?.addEventListener('click', () => {
            if (window.electronAPI) window.electronAPI.maximize();
        });
    }

    bindKeyboardShortcuts() {
        window.addEventListener('keydown', (e) => {
            const isCtrl = e.ctrlKey || e.metaKey;

            // Global Shortcuts
            if (isCtrl && e.key === 'n' && !e.shiftKey) {
                e.preventDefault();
                this.store.createDocument('New Note');
            } else if (isCtrl && e.key === 'N' && e.shiftKey) {
                e.preventDefault();
                this.store.execute(
                    'INSERT INTO notebook (id, name, icon, sortOrder) VALUES (?, ?, "folder", ?)',
                    [`nb-${Date.now()}`, 'New Notebook', this.store.notebooks.length]
                );
                this.store.load();
            } else if (isCtrl && e.key === 'k') {
                e.preventDefault();
                this.openCommandPalette();
            } else if (isCtrl && e.key === 'i') {
                e.preventDefault();
                this.toggleInspector();
            } else if (isCtrl && e.key === 'g') {
                e.preventDefault();
                this.switchView(this.activeView === 'graph' ? 'editor' : 'graph');
            } else if (isCtrl && e.key === 'e') {
                e.preventDefault();
                this.exportCurrentNote();
            }

            // Flashcards Shortcuts
            if (this.activeView === 'flashcards') {
                if (e.key === ' ') {
                    e.preventDefault();
                    this.toggleCardFlip();
                } else if (['1', '2', '3', '4'].includes(e.key) && this.isCardFlipped) {
                    e.preventDefault();
                    this.rateCurrentCard(parseInt(e.key, 10));
                }
            }

            // Memory Palace Shortcuts
            if (this.activeView === 'palace' && this.palaceCanvas && this.palaceCanvas.isWalkMode) {
                if (e.key === 'ArrowRight' || e.key === ' ') {
                    e.preventDefault();
                    this.palaceCanvas.nextWalkStep(this.store.loci, this.store.palacePhotos);
                } else if (e.key === 'ArrowLeft') {
                    e.preventDefault();
                    this.palaceCanvas.prevWalkStep(this.store.loci, this.store.palacePhotos);
                } else if (e.key === 'Escape') {
                    e.preventDefault();
                    this.palaceCanvas.exitWalkMode();
                    document.getElementById('walk-hud').style.display = 'none';
                }
            }
        });
    }

    initTimer() {
        const timerPill = document.getElementById('focus-timer-pill');
        const timerText = document.getElementById('timer-display');

        this.timerManager.subscribe((mgr) => {
            if (timerText) timerText.textContent = mgr.formattedTime;
            if (timerPill) {
                timerPill.classList.toggle('paused', !mgr.isRunning);
                timerPill.title = `${mgr.badgeLabel} (Click to toggle)`;
            }
        });

        timerPill?.addEventListener('click', () => {
            this.timerManager.togglePlayPause();
        });
    }

    bindNavigationTabs() {
        const tabs = [
            { id: 'tab-editor', view: 'editor' },
            { id: 'tab-flashcards', view: 'flashcards' },
            { id: 'tab-graph', view: 'graph' },
            { id: 'tab-palace', view: 'palace' }
        ];

        for (const t of tabs) {
            document.getElementById(t.id)?.addEventListener('click', () => {
                this.switchView(t.view);
            });
        }

        // Sidebar Navigation Items
        document.getElementById('nav-notes')?.addEventListener('click', () => this.switchView('editor'));
        document.getElementById('nav-flashcards')?.addEventListener('click', () => this.switchView('flashcards'));
        document.getElementById('nav-graph')?.addEventListener('click', () => this.switchView('graph'));
        document.getElementById('nav-palace')?.addEventListener('click', () => this.switchView('palace'));

        // Toggle tree / inspector / AI
        document.getElementById('btn-toggle-tree')?.addEventListener('click', () => this.toggleDocTree());
        document.getElementById('btn-toggle-inspector')?.addEventListener('click', () => this.toggleInspector());
        document.getElementById('btn-toggle-ai')?.addEventListener('click', () => this.toggleAIAssistant());
        document.getElementById('btn-import-anki')?.addEventListener('click', () => this.importAnkiDeck());
        document.getElementById('btn-new-ink')?.addEventListener('click', () => {
            this.store.createDocument('New Ink Note', null, null, 'inkDoc');
        });
    }

    switchView(viewName) {
        this.activeView = viewName;

        // Update tabs
        document.querySelectorAll('.segment-btn').forEach(b => b.classList.remove('active'));
        document.getElementById(`tab-${viewName}`)?.classList.add('active');

        // Toggle views
        document.getElementById('view-editor').style.display = viewName === 'editor' ? 'flex' : 'none';
        document.getElementById('view-ink').style.display = viewName === 'editor' && this.store.currentDoc?.type === 'inkDoc' ? 'flex' : 'none';
        document.getElementById('view-flashcards').style.display = viewName === 'flashcards' ? 'flex' : 'none';
        document.getElementById('view-graph').style.display = viewName === 'graph' ? 'flex' : 'none';
        document.getElementById('view-palace').style.display = viewName === 'palace' ? 'flex' : 'none';

        if (viewName === 'graph') {
            this.initGraphView();
        } else if (viewName === 'flashcards') {
            this.initFlashcardsView();
        } else if (viewName === 'palace') {
            this.initPalaceView();
        }
    }

    initUI() {
        const editorContainer = document.getElementById('blocks-editor-target');
        if (editorContainer) {
            this.editorEngine = new BlockEditorEngine(editorContainer, this.store);
        }
    }

    renderActiveDocument() {
        const doc = this.store.currentDoc;
        if (!doc) return;

        if (doc.type === 'inkDoc') {
            document.getElementById('blocks-editor-target').style.display = 'none';
            document.getElementById('view-ink').style.display = 'flex';
            this.initInkView(doc);
        } else {
            document.getElementById('view-ink').style.display = 'none';
            document.getElementById('blocks-editor-target').style.display = 'flex';
            if (this.editorEngine) this.editorEngine.renderBlocks();
        }
    }

    renderSidebarNotebooks() {
        const list = document.getElementById('notebooks-list');
        if (!list) return;
        list.innerHTML = '';

        for (const nb of this.store.notebooks) {
            const row = document.createElement('div');
            row.className = `sidebar-item ${this.store.selectedNotebookId === nb.id ? 'active' : ''}`;
            row.innerHTML = `<span class="sidebar-item-icon">📁</span><span>${nb.name}</span>`;
            row.addEventListener('click', () => {
                this.store.selectedNotebookId = nb.id;
                this.renderSidebarNotebooks();
                this.renderDocTree();
            });
            list.appendChild(row);
        }
    }

    renderDocTree() {
        const treeContainer = document.getElementById('tree-content');
        if (!treeContainer) return;
        treeContainer.innerHTML = '';

        const roots = this.store.documents.filter(d => !d.parentId);
        for (const root of roots) {
            this.renderTreeNode(treeContainer, root, 0);
        }
    }

    renderTreeNode(container, doc, depth) {
        const row = document.createElement('div');
        row.className = `tree-node-row ${this.store.selectedDocId === doc.id ? 'active' : ''}`;
        row.style.paddingLeft = `${depth * 14 + 8}px`;

        const isExpanded = this.store.expandedDocIds.has(doc.id);
        const children = this.store.documents.filter(d => d.parentId === doc.id);
        const hasChildren = children.length > 0;

        const arrow = document.createElement('span');
        arrow.className = `node-arrow ${isExpanded ? 'expanded' : ''}`;
        arrow.textContent = hasChildren ? '▶' : '•';
        arrow.addEventListener('click', (e) => {
            e.stopPropagation();
            if (isExpanded) this.store.expandedDocIds.delete(doc.id);
            else this.store.expandedDocIds.add(doc.id);
            this.renderDocTree();
        });
        row.appendChild(arrow);

        const icon = document.createElement('span');
        icon.textContent = doc.type === 'inkDoc' ? '✍️' : '📄';
        row.appendChild(icon);

        const label = document.createElement('span');
        label.textContent = doc.content || 'Untitled';
        row.appendChild(label);

        row.addEventListener('click', () => {
            this.store.selectDocument(doc.id);
            this.renderDocTree();
        });

        container.appendChild(row);

        if (isExpanded && hasChildren) {
            for (const c of children) {
                this.renderTreeNode(container, c, depth + 1);
            }
        }
    }

    // --- Vector Ink Note View ---
    initInkView(doc) {
        const pagesCol = document.getElementById('ink-pages-column');
        if (!pagesCol) return;
        pagesCol.innerHTML = '';

        const wrapper = document.createElement('div');
        wrapper.className = 'ink-page-wrapper';

        const canvas = document.createElement('canvas');
        canvas.className = 'ink-page-canvas';
        wrapper.appendChild(canvas);

        const footer = document.createElement('div');
        footer.className = 'ink-page-footer';
        footer.textContent = 'Page 1';
        wrapper.appendChild(footer);

        pagesCol.appendChild(wrapper);

        let initialStrokes = [];
        if (this.store.inkPages.length > 0) {
            try {
                const data = JSON.parse(this.store.inkPages[0].strokesData);
                initialStrokes = data.strokes || [];
            } catch (e) {}
        }

        this.inkCanvas = new InkCanvas(canvas, {
            initialStrokes,
            onStrokesChanged: (strokes) => {
                const payload = JSON.stringify({ schemaVersion: 1, pageWidth: 794, pageHeight: 1123, strokes });
                this.store.execute(`
                    INSERT OR REPLACE INTO ink_document_page (id, docId, pageIndex, templateType, strokesData, textProjection, createdAt, updatedAt)
                    VALUES (?, ?, 0, 'lined', ?, '', datetime('now'), datetime('now'))
                `, [`inkpage-${doc.id}-0`, doc.id, payload]);
            }
        });

        // Dock tools
        document.querySelectorAll('.ink-tool-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('.ink-tool-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                if (this.inkCanvas) this.inkCanvas.activeTool = btn.dataset.tool;
            });
        });
    }

    // --- Flashcards & FSRS-4.5 View ---
    async initFlashcardsView() {
        const api = window.medhaAPI || window.electronAPI;
        if (api && typeof api.getDueCards === 'function') {
            const res = await api.getDueCards();
            this.dueCards = (res && res.data) ? res.data : (Array.isArray(res) ? res : []);
        } else {
            this.dueCards = await this.store.query('SELECT * FROM flashcard WHERE isSuspended = 0 ORDER BY due ASC');
        }

        const badge = document.getElementById('due-badge');
        if (badge) badge.textContent = this.dueCards.length;

        this.currentCardIndex = 0;
        this.renderFlashcardStage();
    }

    renderFlashcardStage() {
        const cardFront = document.getElementById('card-front-text');
        const cardBack = document.getElementById('card-back-text');
        const cardHint = document.getElementById('card-hint-text');
        const inner = document.getElementById('flip-card-inner');

        this.isCardFlipped = false;
        inner?.classList.remove('flipped');

        if (this.dueCards.length === 0) {
            if (cardFront) cardFront.textContent = '🎉 All caught up! No due flashcards.';
            if (cardBack) cardBack.textContent = '';
            document.getElementById('rating-controls').style.display = 'none';
            return;
        }

        const card = this.dueCards[this.currentCardIndex];
        if (cardFront) cardFront.textContent = card.front;
        if (cardBack) cardBack.textContent = card.back;
        if (cardHint) cardHint.textContent = card.hint ? `💡 ${card.hint}` : '';

        // Live Interval Chips Preview
        const preview = fsrs.previewIntervals(card);
        const chipAgain = document.getElementById('chip-again');
        const chipHard = document.getElementById('chip-hard');
        const chipGood = document.getElementById('chip-good');
        const chipEasy = document.getElementById('chip-easy');

        if (chipAgain) chipAgain.textContent = fsrs.formatInterval(0); // 10m immediate
        if (chipHard) chipHard.textContent = fsrs.formatInterval(preview[Rating.Hard]);
        if (chipGood) chipGood.textContent = fsrs.formatInterval(preview[Rating.Good]);
        if (chipEasy) chipEasy.textContent = fsrs.formatInterval(preview[Rating.Easy]);

        document.getElementById('rating-controls').style.display = 'flex';
    }

    toggleCardFlip() {
        this.isCardFlipped = !this.isCardFlipped;
        document.getElementById('flip-card-inner')?.classList.toggle('flipped', this.isCardFlipped);
    }

    async rateCurrentCard(ratingNum) {
        if (this.dueCards.length === 0) return;
        const card = this.dueCards[this.currentCardIndex];
        const api = window.medhaAPI || window.electronAPI;

        if (api && typeof api.submitReview === 'function') {
            const res = await api.submitReview(card.id, ratingNum);
            if (res && res.data) {
                this.dueCards[this.currentCardIndex] = res.data;
            }
        } else {
            const res = fsrs.review(card, ratingNum);
            this.store.execute(`
                UPDATE flashcard
                SET fsrsState = ?, stability = ?, difficulty = ?, elapsedDays = ?, scheduledDays = ?, reps = ?, lapses = ?, lastReview = ?, due = ?, updatedAt = ?
                WHERE id = ?
            `, [
                res.card.fsrsState, res.card.stability, res.card.difficulty, res.card.elapsedDays,
                res.card.scheduledDays, res.card.reps, res.card.lapses, res.card.lastReview,
                res.card.due, res.card.updatedAt, card.id
            ]);
            this.dueCards[this.currentCardIndex] = res.card;
        }

        // Advance to next card
        this.currentCardIndex = (this.currentCardIndex + 1) % this.dueCards.length;
        this.renderFlashcardStage();
    }

    // --- Knowledge Graph View ---
    initGraphView() {
        const canvas = document.getElementById('graph-canvas');
        if (!canvas) return;

        if (!this.graphEngine) {
            this.graphEngine = new KnowledgeGraphEngine(canvas, {
                onNodeClicked: (node) => {
                    this.store.selectDocument(node.id);
                    this.switchView('editor');
                }
            });
        }
        this.graphEngine.updateData(this.store.documents);

        document.querySelectorAll('.graph-layer-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('.graph-layer-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                this.graphEngine.setLayerMode(btn.dataset.mode);
            });
        });
    }

    // --- Memory Palace View ---
    initPalaceView() {
        const stage = document.getElementById('palace-stage');
        const world = document.getElementById('palace-world');
        if (!stage || !world) return;

        if (!this.palaceCanvas) {
            this.palaceCanvas = new PalaceCanvas(stage, world, { store: this.store });
        }

        // Render photo nodes & loci pins
        world.innerHTML = '';
        for (const photo of this.store.palacePhotos) {
            const card = document.createElement('div');
            card.className = 'photo-node-card';
            card.style.left = `${photo.canvasX}px`;
            card.style.top = `${photo.canvasY}px`;
            card.style.width = `${photo.canvasWidth}px`;
            card.style.height = `${photo.canvasHeight}px`;

            const img = document.createElement('div');
            img.className = 'photo-node-img';
            img.style.background = 'linear-gradient(135deg, #1E293B, #0F172A)';
            img.innerHTML = `<div style="padding: 20px; color: var(--text-muted); font-size: 13px;">🏛️ ${photo.name}</div>`;
            card.appendChild(img);

            // Render loci pins on this photo
            const lociOnPhoto = this.store.loci.filter(l => l.photoId === photo.id);
            for (const locus of lociOnPhoto) {
                const pin = document.createElement('div');
                pin.className = 'locus-pin';
                pin.style.left = `${locus.normalizedX * 100}%`;
                pin.style.top = `${locus.normalizedY * 100}%`;
                pin.textContent = locus.orderIndex + 1;
                pin.title = locus.title;
                card.appendChild(pin);
            }

            world.appendChild(card);
        }

        document.getElementById('btn-start-walk')?.addEventListener('click', () => {
            this.palaceCanvas.startWalkMode(this.store.loci, this.store.palacePhotos);
            document.getElementById('walk-hud').style.display = 'flex';
        });
    }

    // --- Anki Importer Trigger ---
    async importAnkiDeck() {
        if (!window.electronAPI) return;
        const apkgPath = await window.electronAPI.openAnkiFileDialog();
        if (!apkgPath) return;

        const res = await window.electronAPI.importAnkiPackage(apkgPath, this.store.selectedDocId, this.store.selectedNotebookId);
        if (res.success) {
            alert(`🎉 ${res.data.details}`);
            await this.store.load();
        } else {
            alert(`Import failed: ${res.error}`);
        }
    }

    // --- Note Exporter ---
    async exportCurrentNote() {
        const doc = this.store.currentDoc;
        if (!doc) return;
        const md = ExportService ? ExportService.exportToMarkdown(doc, this.store.blocks) : '';
        const api = window.medhaAPI || window.electronAPI;
        if (api) {
            await api.saveExportFileDialog(`${doc.content || 'Note'}.md`, md, 'md');
        }
    }

    toggleDocTree() {
        this.isDocTreeVisible = !this.isDocTreeVisible;
        document.getElementById('doc-tree-panel')?.classList.toggle('hidden', !this.isDocTreeVisible);
    }

    toggleInspector() {
        this.isInspectorVisible = !this.isInspectorVisible;
        document.getElementById('inspector-panel')?.classList.toggle('hidden', !this.isInspectorVisible);
    }

    toggleAIAssistant() {
        this.isAIAssistantVisible = !this.isAIAssistantVisible;
        document.getElementById('ai-panel')?.classList.toggle('hidden', !this.isAIAssistantVisible);
    }

    initCommandPalette() {
        const overlay = document.getElementById('command-palette-overlay');
        const input = document.getElementById('palette-search-input');
        const resultsList = document.getElementById('palette-results-list');
        if (!overlay || !input || !resultsList) return;

        this.paletteSelectedIndex = -1;
        this.paletteResults = [];

        // Close on backdrop click
        overlay.addEventListener('click', (e) => {
            if (e.target === overlay) this.closeCommandPalette();
        });

        // Search as you type
        input.addEventListener('input', async (e) => {
            const query = e.target.value.trim();
            await this.performPaletteSearch(query);
        });

        // Keyboard navigation within input
        input.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                e.preventDefault();
                this.closeCommandPalette();
            } else if (e.key === 'ArrowDown') {
                e.preventDefault();
                this.movePaletteSelection(1);
            } else if (e.key === 'ArrowUp') {
                e.preventDefault();
                this.movePaletteSelection(-1);
            } else if (e.key === 'Enter') {
                e.preventDefault();
                if (this.paletteSelectedIndex >= 0 && this.paletteResults[this.paletteSelectedIndex]) {
                    this.selectPaletteResult(this.paletteResults[this.paletteSelectedIndex]);
                } else if (this.paletteResults.length > 0) {
                    this.selectPaletteResult(this.paletteResults[0]);
                }
            }
        });
    }

    openCommandPalette() {
        const overlay = document.getElementById('command-palette-overlay');
        const input = document.getElementById('palette-search-input');
        if (!overlay || !input) return;

        overlay.style.display = 'flex';
        input.value = '';
        input.focus();
        this.paletteSelectedIndex = -1;
        this.paletteResults = [];

        const resultsList = document.getElementById('palette-results-list');
        if (resultsList) {
            resultsList.innerHTML = '<div class="palette-empty-state">Type to search notes and knowledge blocks across all notebooks...</div>';
        }
    }

    closeCommandPalette() {
        const overlay = document.getElementById('command-palette-overlay');
        if (overlay) overlay.style.display = 'none';
        this.paletteSelectedIndex = -1;
    }

    async performPaletteSearch(query) {
        const resultsList = document.getElementById('palette-results-list');
        if (!resultsList) return;

        if (!query) {
            this.paletteResults = [];
            resultsList.innerHTML = '<div class="palette-empty-state">Type to search notes and knowledge blocks across all notebooks...</div>';
            return;
        }

        let hits = [];
        const api = window.medhaAPI || window.electronAPI;
        if (api && typeof api.dbSearchFTS === 'function') {
            const res = await api.dbSearchFTS(query);
            if (res && res.success && Array.isArray(res.data)) {
                hits = res.data;
            }
        }

        if (hits.length === 0 && this.store) {
            hits = this.store.search(query);
        }

        this.paletteResults = hits;
        this.paletteSelectedIndex = hits.length > 0 ? 0 : -1;
        this.renderPaletteResults();
    }

    renderPaletteResults() {
        const resultsList = document.getElementById('palette-results-list');
        if (!resultsList) return;

        if (this.paletteResults.length === 0) {
            resultsList.innerHTML = '<div class="palette-empty-state">No matching notes or blocks found.</div>';
            return;
        }

        resultsList.innerHTML = '';
        this.paletteResults.forEach((item, index) => {
            const row = document.createElement('div');
            row.className = `palette-result-item ${index === this.paletteSelectedIndex ? 'selected' : ''}`;
            row.dataset.index = index;

            const icon = item.type === 'doc' ? '📄' : (item.type === 'heading1' || item.type === 'heading2' ? '📌' : '💬');
            const targetDoc = this.store.documents.find(d => d.id === item.rootDocId);
            const docTitle = targetDoc ? targetDoc.content : (item.rootDocId || 'Note');

            row.innerHTML = `
                <span class="palette-item-icon">${icon}</span>
                <div class="palette-item-body">
                    <div class="palette-item-title">
                        <span>${docTitle}</span>
                        <span class="palette-item-type">${item.type || item.blockType || 'block'}</span>
                    </div>
                    <div class="palette-item-snippet">${item.snippet || item.content || ''}</div>
                </div>
            `;

            row.addEventListener('click', () => {
                this.selectPaletteResult(item);
            });

            resultsList.appendChild(row);
        });

        this.scrollSelectedPaletteItemIntoView();
    }

    movePaletteSelection(delta) {
        if (this.paletteResults.length === 0) return;
        const total = this.paletteResults.length;
        this.paletteSelectedIndex = (this.paletteSelectedIndex + delta + total) % total;

        const items = document.querySelectorAll('.palette-result-item');
        items.forEach((item, idx) => {
            item.classList.toggle('selected', idx === this.paletteSelectedIndex);
        });

        this.scrollSelectedPaletteItemIntoView();
    }

    scrollSelectedPaletteItemIntoView() {
        const selected = document.querySelector('.palette-result-item.selected');
        if (selected) {
            selected.scrollIntoView({ block: 'nearest' });
        }
    }

    selectPaletteResult(item) {
        if (!item) return;
        const targetDocId = item.rootDocId || item.id;
        this.closeCommandPalette();
        this.switchView('editor');
        this.store.selectDocument(targetDocId);
    }
}

// Bootstrap on DOM load
window.addEventListener('DOMContentLoaded', async () => {
    try {
        const app = new MedhaDesktopApp();
        await app.init();
        window.medhaApp = app;

        // Signal to Electron main process that renderer is ready without errors
        const api = window.medhaAPI || window.electronAPI;
        if (api && typeof api.signalReady === 'function') {
            api.signalReady();
        }
        console.log('[Medha] Renderer app successfully initialized.');
    } catch (err) {
        console.error('[Medha] Fatal initialization error in renderer:', err);
    }
});
