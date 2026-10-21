// Medha Web — Main Application Controller & View Orchestrator
// Connects UI events to reactive Store, FSRS engine, Knowledge Graph, and AI Services.

import { store } from './store.js';
import { fsrs, Rating } from './fsrs.js';
import { aiService, AIProvider } from './aiService.js';
import { KnowledgeGraphView } from './graph.js';
import { StudyGroundingSource, SourceMetadata } from './studySources.js';
import { LinkParser } from './linkParser.js';

class MedhaApp {
    constructor() {
        this.activeView = 'editor'; // 'editor' | 'flashcards' | 'graph'
        this.graphView = null;
        this.currentCardIndex = 0;
        this.isCardFlipped = false;
        this.isLocallyMutatingBlocks = false;

        // Grounding selection for AI notes assistant
        this.selectedSources = [...aiService.enabledSources];

        this.initDOMElements();
        this.bindEvents();
    }

    async start() {
        await store.load();
        this.renderDocumentTree();
        this.renderEditor();
        this.renderFlashcards();
        this.initGraph();
        this.renderAISources();

        store.subscribe((event, payload) => {
            if (event === 'load' || event === 'tree_changed') {
                this.renderDocumentTree();
                this.updateGraph();
                this.renderInspector();
            } else if (event === 'doc_selected') {
                this.updateDocumentTreeActiveSelection();
                if (this.activeView === 'editor') this.renderEditor();
                if (this.activeView === 'graph') this.updateGraph();
                this.renderInspector();
            } else if (event === 'title_changed') {
                this.updateSidebarTitle(payload.docId, payload.title);
                this.renderInspector();
            } else if (event === 'blocks_structure_changed') {
                if (this.activeView === 'editor' && !this.isLocallyMutatingBlocks) {
                    this.renderEditor();
                }
                this.renderInspector();
            } else if (event === 'flashcards_changed') {
                if (this.activeView === 'flashcards') this.renderFlashcards();
                if (this.activeView === 'editor') this.renderAttachedFlashcards(store.currentDoc);
            }
        });
    }


    initDOMElements() {
        // Tabs
        this.tabEditor = document.getElementById('tab-editor');
        this.tabFlashcards = document.getElementById('tab-flashcards');
        this.tabGraph = document.getElementById('tab-graph');

        // Containers
        this.viewEditor = document.getElementById('view-editor');
        this.viewFlashcards = document.getElementById('view-flashcards');
        this.viewGraph = document.getElementById('view-graph');

        // Sidebar & Editor
        this.treeContainer = document.getElementById('doc-tree');
        this.btnNewDoc = document.getElementById('btn-new-doc');
        this.docTitleInput = document.getElementById('doc-title-input');
        this.blocksList = document.getElementById('blocks-list');

        // Flashcards
        this.flipCard = document.getElementById('flip-card');
        this.cardFront = document.getElementById('card-front');
        this.cardBack = document.getElementById('card-back');
        this.cardHint = document.getElementById('card-hint');
        this.cardBadge = document.getElementById('card-badge');
        this.reviewControls = document.getElementById('review-controls');
        this.socraticBox = document.getElementById('socratic-box');
        this.socraticInput = document.getElementById('socratic-input');
        this.btnSocraticSubmit = document.getElementById('btn-socratic-submit');
        this.socraticFeedback = document.getElementById('socratic-feedback');
        this.btnNewCard = document.getElementById('btn-new-card');

        // Knowledge Graph
        this.graphCanvas = document.getElementById('graph-canvas');

        // AI Panel
        this.aiPanel = document.getElementById('ai-panel');
        this.btnToggleAI = document.getElementById('btn-toggle-ai');
        this.btnCloseAI = document.getElementById('btn-close-ai');
        this.aiSourcesList = document.getElementById('ai-sources-list');
        this.btnGenerateHierarchy = document.getElementById('btn-generate-hierarchy');
        this.aiStatus = document.getElementById('ai-status');

        // Settings Modal
        this.btnSettings = document.getElementById('btn-settings');
        this.settingsModal = document.getElementById('settings-modal');
        this.btnSaveSettings = document.getElementById('btn-save-settings');
        this.btnCloseSettings = document.getElementById('btn-close-settings');
        this.btnCancelSettings = document.getElementById('btn-cancel-settings');
        this.settingProvider = document.getElementById('setting-provider');
        this.settingEndpoint = document.getElementById('setting-endpoint');
        this.settingModel = document.getElementById('setting-model');
        this.settingApiKey = document.getElementById('setting-apikey');
        this.btnTestConnection = document.getElementById('btn-test-connection');
        this.connectionResult = document.getElementById('connection-result');
        this.btnToggleKey = document.getElementById('btn-toggle-key');
        this.groupLocalEndpoint = document.getElementById('group-local-endpoint');
        this.groupApiKey = document.getElementById('group-api-key');

        // macOS Breadcrumbs & Meta
        this.breadcrumbDocTitle = document.getElementById('breadcrumb-doc-title');
        this.breadcrumbPath = document.getElementById('breadcrumb-path');
        this.breadcrumbRoot = document.getElementById('breadcrumb-root');
        this.btnAddSubnoteHeader = document.getElementById('btn-add-subnote-header');
        this.editorMetaInfo = document.getElementById('editor-meta-info');

        // Living Folder Hub, Subfolders Gallery, Attached Flashcards
        this.livingFolderHub = document.getElementById('living-folder-hub');
        this.subfoldersGallery = document.getElementById('subfolders-gallery');
        this.attachedFlashcardsSection = document.getElementById('attached-flashcards-section');

        // Tree Search Input
        this.treeSearchInput = document.getElementById('tree-search-input');

        // Document Inspector Panel (4 tabs)
        this.inspectorPanel = document.getElementById('inspector-panel');
        this.btnToggleInspector = document.getElementById('btn-toggle-inspector');
        this.btnCloseInspector = document.getElementById('btn-close-inspector');
        this.inspectorContent = document.getElementById('inspector-content');
        this.inspectorTabBtns = document.querySelectorAll('.inspector-tab-btn');
        this.selectedInspectorTab = 'outline';
        this.localGraphDepth = 1;
        this.localGraphIncludeTree = false;

        // Active Popover Menus
        this.activeGutterMenu = null;
        this.activeSlashMenu = null;

        // Due Badges
        this.dueBadge = document.getElementById('due-badge');
        this.sidebarDueBadge = document.getElementById('sidebar-due-badge');

        // Focus Timer
        this.focusTimerPill = document.getElementById('focus-timer-pill');
        this.timerDisplay = document.getElementById('timer-display');

        // Spotlight Search (⌘K)
        this.btnSearchTrigger = document.getElementById('btn-search-trigger');
        this.searchModal = document.getElementById('search-modal');
        this.paletteInput = document.getElementById('palette-input');
        this.paletteResults = document.getElementById('palette-results');

        // Sidebar Navigation
        this.navNotes = document.getElementById('nav-notes');
        this.navFlashcards = document.getElementById('nav-flashcards');
        this.navGraph = document.getElementById('nav-graph');
    }


    bindEvents() {
        // Tab switching
        this.tabEditor.addEventListener('click', () => this.switchView('editor'));
        this.tabFlashcards.addEventListener('click', () => this.switchView('flashcards'));
        this.tabGraph.addEventListener('click', () => this.switchView('graph'));

        // Document creation & title editing
        this.btnNewDoc.addEventListener('click', async () => {
            const newDoc = await store.createDocument('Untitled Note', null);
            this.switchView('editor');
            setTimeout(() => this.docTitleInput.focus(), 50);
        });

        this.btnAddSubnoteHeader?.addEventListener('click', async () => {
            if (!store.currentDoc) return;
            const newSubDoc = await store.createDocument('Untitled Sub-note', store.currentDoc.id);
            this.switchView('editor');
            setTimeout(() => this.docTitleInput.focus(), 50);
        });

        this.docTitleInput.addEventListener('input', (e) => {
            if (store.currentDoc) {
                store.updateDocTitle(store.currentDoc.id, e.target.value);
            }
        });

        this.docTitleInput.addEventListener('blur', (e) => {
            if (store.currentDoc && e.target.value.trim() === '') {
                e.target.value = 'Untitled Note';
                store.updateDocTitle(store.currentDoc.id, 'Untitled Note');
            }
        });

        // Tree Search Filter
        this.treeSearchInput?.addEventListener('input', (e) => {
            this.renderDocumentTree(e.target.value);
        });

        // Document Inspector Toggle & Tab Switching
        this.btnToggleInspector?.addEventListener('click', () => this.toggleInspector());
        this.btnCloseInspector?.addEventListener('click', () => this.closeInspector());
        this.inspectorTabBtns.forEach(btn => {
            btn.addEventListener('click', (e) => {
                this.switchInspectorTab(e.currentTarget.dataset.tab);
            });
        });

        // Flashcards Flip & Rating
        this.flipCard.addEventListener('click', () => this.toggleCardFlip());

        document.querySelectorAll('.rating-btn').forEach((btn) => {
            btn.addEventListener('click', (e) => {
                const rating = parseInt(e.currentTarget.dataset.rating, 10);
                this.rateActiveCard(rating);
            });
        });

        // Socratic Written Recall
        this.btnSocraticSubmit.addEventListener('click', () => this.submitSocraticAnswer());
        this.socraticInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
                this.submitSocraticAnswer();
            }
        });

        // New Flashcard Modal / Prompt
        this.btnNewCard.addEventListener('click', () => {
            const front = prompt('Enter Flashcard Front (Question):');
            if (!front) return;
            const back = prompt('Enter Flashcard Back (Answer):');
            if (!back) return;
            const hint = prompt('Enter optional hint:') || '';
            store.createFlashcard({ front, back, hint });
        });

        // AI Assistant Toggle
        this.btnToggleAI.addEventListener('click', () => {
            const isOpening = this.aiPanel.classList.contains('collapsed');
            this.aiPanel.classList.toggle('collapsed');
            if (isOpening) {
                this.closeInspector();
            }
        });
        this.btnCloseAI.addEventListener('click', () => {
            this.aiPanel.classList.add('collapsed');
        });

        // Generate Downward Notes
        this.btnGenerateHierarchy.addEventListener('click', () => this.generateNotesHierarchy());

        // Quick source presets
        document.querySelectorAll('.btn-preset').forEach((btn) => {
            btn.addEventListener('click', (e) => {
                const preset = e.target.dataset.preset;
                if (preset === 'all') this.selectedSources = Object.values(StudyGroundingSource);
                else if (preset === 'stem') this.selectedSources = [StudyGroundingSource.Wikipedia, StudyGroundingSource.OpenAlex];
                else if (preset === 'biomed') this.selectedSources = [StudyGroundingSource.Wikipedia, StudyGroundingSource.EuropePMC];
                else if (preset === 'none') this.selectedSources = [];
                this.renderAISources();
            });
        });

        // Sidebar navigation items
        this.navNotes?.addEventListener('click', () => this.switchView('editor'));
        this.navFlashcards?.addEventListener('click', () => this.switchView('flashcards'));
        this.navGraph?.addEventListener('click', () => this.switchView('graph'));

        // Focus Timer Widget
        this.initFocusTimer();

        // Spotlight Search (⌘K)
        this.btnSearchTrigger?.addEventListener('click', () => this.openSearchModal());
        this.paletteInput?.addEventListener('input', (e) => this.filterSearchResults(e.target.value));
        this.searchModal?.addEventListener('click', (e) => {
            if (e.target === this.searchModal) this.closeSearchModal();
        });

        // Settings Modal
        this.btnSettings.addEventListener('click', () => this.openSettingsModal());
        this.btnCloseSettings?.addEventListener('click', () => this.settingsModal.classList.add('hidden'));
        this.btnCancelSettings?.addEventListener('click', () => this.settingsModal.classList.add('hidden'));
        this.btnSaveSettings.addEventListener('click', () => this.saveSettingsModal());
        this.btnTestConnection?.addEventListener('click', () => this.testAIConnection());
        this.settingProvider?.addEventListener('change', () => this.updateProviderVisibility());
        this.btnToggleKey?.addEventListener('click', () => {
            const isPass = this.settingApiKey.type === 'password';
            this.settingApiKey.type = isPass ? 'text' : 'password';
        });

        // Quick Preset Model Chips
        document.querySelectorAll('.preset-model-btn').forEach((btn) => {
            btn.addEventListener('click', (e) => {
                this.settingModel.value = e.currentTarget.dataset.model;
            });
        });

        // Click outside to dismiss menus
        document.addEventListener('click', (e) => {
            if (this.activeGutterMenu && !this.activeGutterMenu.contains(e.target) && !e.target.closest('.block-handle')) {
                this.closeGutterMenu();
            }
            if (this.activeSlashMenu && !this.activeSlashMenu.contains(e.target)) {
                this.closeSlashMenu();
            }
        });

        // Global Keyboard navigation
        window.addEventListener('keydown', (e) => {
            // Inspector shortcut: ⌘I or Ctrl+I
            if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'i') {
                e.preventDefault();
                this.toggleInspector();
                return;
            }

            // Spotlight Search shortcut: ⌘K or Ctrl+K
            if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
                e.preventDefault();
                this.openSearchModal();
                return;
            }

            // Escape to close menus & modals
            if (e.key === 'Escape') {
                if (this.activeGutterMenu) { this.closeGutterMenu(); return; }
                if (this.activeSlashMenu) { this.closeSlashMenu(); return; }
                this.closeSearchModal();
                this.settingsModal.classList.add('hidden');
                return;
            }

            // Space to flip card, 1-4 to rate
            if (this.activeView === 'flashcards' && !document.activeElement.matches('input, textarea, [contenteditable]')) {
                if (e.code === 'Space') {
                    e.preventDefault();
                    this.toggleCardFlip();
                } else if (this.isCardFlipped) {
                    if (e.key === '1') this.rateActiveCard(Rating.Again);
                    if (e.key === '2') this.rateActiveCard(Rating.Hard);
                    if (e.key === '3') this.rateActiveCard(Rating.Good);
                    if (e.key === '4') this.rateActiveCard(Rating.Easy);
                }
            }
        });
    }

    switchView(view) {
        this.activeView = view;
        [this.tabEditor, this.tabFlashcards, this.tabGraph].forEach(t => t?.classList.remove('active'));
        [this.viewEditor, this.viewFlashcards, this.viewGraph].forEach(v => v?.classList.add('hidden'));

        this.navNotes?.classList.toggle('active', view === 'editor');
        this.navFlashcards?.classList.toggle('active', view === 'flashcards');
        this.navGraph?.classList.toggle('active', view === 'graph');

        if (view === 'editor') {
            this.tabEditor?.classList.add('active');
            this.viewEditor?.classList.remove('hidden');
            this.renderEditor();
        } else if (view === 'flashcards') {
            this.tabFlashcards?.classList.add('active');
            this.viewFlashcards?.classList.remove('hidden');
            this.renderFlashcards();
        } else if (view === 'graph') {
            this.tabGraph?.classList.add('active');
            this.viewGraph?.classList.remove('hidden');
            this.updateGraph();
        }
    }


    // =========================================
    // 1. DOCUMENT TREE SIDEBAR
    // =========================================
    renderDocumentTree(filter = '') {
        const roots = store.getDocumentTree(filter);
        this.treeContainer.innerHTML = '';

        if (roots.length === 0) {
            this.treeContainer.innerHTML = filter
                ? `<div style="padding:16px 12px;font-size:11px;color:var(--text-tertiary);text-align:center;">No notes matching "${this.escapeHTML(filter)}"</div>`
                : `<div style="padding:16px 12px;font-size:11px;color:var(--text-tertiary);text-align:center;">No notes in vault. Click "+" to create one.</div>`;
            return;
        }

        const renderNode = (node, depth = 0) => {
            const item = document.createElement('div');
            item.className = `tree-item ${store.currentDoc?.id === node.id ? 'active' : ''}`;
            item.dataset.docId = node.id;
            item.style.paddingLeft = `${10 + depth * 14}px`;

            item.innerHTML = `
                <span class="tree-item-icon">${node.children.length > 0 ? '📁' : '📄'}</span>
                <span class="tree-item-title">${this.escapeHTML(node.title || 'Untitled Note')}</span>
                <button class="btn-icon btn-add-child" title="Add sub-note">+</button>
                <button class="btn-icon btn-del-doc" title="Delete note">×</button>
            `;

            item.addEventListener('click', (e) => {
                if (e.target.classList.contains('btn-add-child')) {
                    e.stopPropagation();
                    store.createDocument('Untitled Sub-note', node.id);
                } else if (e.target.classList.contains('btn-del-doc')) {
                    e.stopPropagation();
                    if (confirm(`Delete "${node.title}" and any subtopics?`)) {
                        store.deleteDocument(node.id);
                    }
                } else {
                    store.selectDocument(node.id);
                    this.switchView('editor');
                }
            });

            this.treeContainer.appendChild(item);
            node.children.forEach(child => renderNode(child, depth + 1));
        };

        roots.forEach(root => renderNode(root, 0));
    }

    updateDocumentTreeActiveSelection() {
        const activeId = store.currentDoc?.id;
        this.treeContainer.querySelectorAll('.tree-item').forEach((item) => {
            item.classList.toggle('active', item.dataset.docId === activeId);
        });
    }

    updateSidebarTitle(docId, title) {
        const item = this.treeContainer.querySelector(`.tree-item[data-doc-id="${docId}"] .tree-item-title`);
        if (item) {
            item.textContent = title.trim() || 'Untitled Note';
        }
    }

    // Metric Calculations
    calculateWordCount() {
        if (!store.currentDoc) return 0;
        let count = (store.currentDoc.title || '').trim().split(/\s+/).filter(Boolean).length;
        for (const b of store.blocks) {
            count += (b.content || '').trim().split(/\s+/).filter(Boolean).length;
        }
        return count;
    }

    calculateCharCount() {
        if (!store.currentDoc) return 0;
        let count = (store.currentDoc.title || '').length;
        for (const b of store.blocks) {
            count += (b.content || '').length;
        }
        return count;
    }

    // =========================================
    // 2. BLOCK EDITOR & LIVING FOLDER HUB
    // =========================================
    renderEditor() {
        if (!store.currentDoc) {
            this.docTitleInput.value = '';
            if (this.breadcrumbDocTitle) this.breadcrumbDocTitle.textContent = 'No Note Selected';
            if (this.editorMetaInfo) this.editorMetaInfo.textContent = '0 blocks';
            if (this.livingFolderHub) this.livingFolderHub.style.display = 'none';
            if (this.subfoldersGallery) this.subfoldersGallery.style.display = 'none';
            if (this.attachedFlashcardsSection) this.attachedFlashcardsSection.style.display = 'none';
            this.blocksList.innerHTML = '<div style="color:var(--text-tertiary);text-align:center;padding:40px;">Select or create a note to begin.</div>';
            return;
        }

        const doc = store.currentDoc;
        this.docTitleInput.value = doc.title || '';

        // 1. Ancestry Breadcrumbs
        this.renderBreadcrumbs(doc);

        // 2. Calculate metrics
        const words = this.calculateWordCount();
        const estReadTime = Math.max(1, Math.ceil(words / 200));
        const blockCount = store.blocks.length;
        if (this.editorMetaInfo) {
            this.editorMetaInfo.textContent = `${words} words • ${blockCount} blocks • Autosaved`;
        }

        // 3. Living Folder Command Hub Status Badges
        this.renderLivingFolderHub(doc, words, estReadTime, blockCount);

        // 4. Nested Subfolders Gallery
        this.renderSubfoldersGallery(doc);

        // 5. Continuous Block Stream
        this.blocksList.innerHTML = '';
        store.blocks.forEach((block, index) => {
            const row = this.createBlockRow(block, index, store.blocks.length);
            this.blocksList.appendChild(row);
        });

        // 6. Attached Flashcards Section
        this.renderAttachedFlashcards(doc);

        // 7. Update Inspector if open
        this.renderInspector();
    }

    renderBreadcrumbs(doc) {
        if (!this.breadcrumbPath) return;
        const ancestry = store.getDocAncestry(doc.id);
        this.breadcrumbPath.innerHTML = '';

        const rootSpan = document.createElement('span');
        rootSpan.className = 'breadcrumb-item';
        rootSpan.textContent = '📁 Vault';
        rootSpan.style.cursor = 'pointer';
        rootSpan.addEventListener('click', () => {
            this.treeSearchInput?.focus();
        });
        this.breadcrumbPath.appendChild(rootSpan);

        ancestry.forEach((ancestor) => {
            const isLast = ancestor.id === doc.id;
            const sep = document.createElement('span');
            sep.className = 'breadcrumb-sep';
            sep.textContent = '›';
            this.breadcrumbPath.appendChild(sep);

            const item = document.createElement('span');
            item.className = isLast ? 'breadcrumb-active' : 'breadcrumb-item';
            item.textContent = ancestor.title || 'Untitled';
            if (!isLast) {
                item.style.cursor = 'pointer';
                item.addEventListener('click', () => {
                    store.selectDocument(ancestor.id);
                    this.switchView('editor');
                });
            } else {
                this.breadcrumbDocTitle = item;
            }
            this.breadcrumbPath.appendChild(item);
        });
    }

    renderLivingFolderHub(doc, words, estReadTime, blockCount) {
        if (!this.livingFolderHub) return;
        const children = store.getChildDocuments(doc.id);
        const cards = store.getFlashcardsForCurrentDoc();

        this.livingFolderHub.innerHTML = `
            <div class="hub-badge" id="hub-badge-subnotes" style="cursor:pointer;" title="Scroll to nested documents">
                <span>${children.length > 0 ? '📁' : '📂'}</span>
                <span>${children.length} Sub-note${children.length === 1 ? '' : 's'}</span>
            </div>
            <div class="hub-badge ${cards.length > 0 ? 'accent' : ''}" id="hub-badge-cards" style="cursor:pointer;" title="Scroll to attached flashcards">
                <span>🗂️</span>
                <span>${cards.length} Card${cards.length === 1 ? '' : 's'}</span>
            </div>
            <div class="hub-badge" title="Estimated reading time">
                <span>⏱️</span>
                <span>~${estReadTime} min read</span>
            </div>
            <div class="hub-badge" title="Word & block count">
                <span>${words} words</span>
                <span>•</span>
                <span>${blockCount} blocks</span>
            </div>
        `;
        this.livingFolderHub.style.display = 'flex';

        // Clicking subnotes badge scrolls to gallery
        document.getElementById('hub-badge-subnotes')?.addEventListener('click', () => {
            if (children.length > 0 && this.subfoldersGallery) {
                this.subfoldersGallery.scrollIntoView({ behavior: 'smooth', block: 'start' });
            } else {
                store.createDocument('Untitled Sub-note', doc.id);
            }
        });

        // Clicking cards badge scrolls to attached flashcards
        document.getElementById('hub-badge-cards')?.addEventListener('click', () => {
            if (this.attachedFlashcardsSection) {
                this.attachedFlashcardsSection.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        });
    }

    renderSubfoldersGallery(doc) {
        if (!this.subfoldersGallery) return;
        const children = store.getChildDocuments(doc.id);
        if (children.length === 0) {
            this.subfoldersGallery.style.display = 'none';
            return;
        }

        let cardsHTML = '';
        children.forEach(child => {
            const subCount = store.getChildDocuments(child.id).length;
            cardsHTML += `
                <div class="subfolder-card" data-doc-id="${child.id}">
                    <span style="font-size:16px;">${subCount > 0 ? '📁' : '📄'}</span>
                    <div style="flex:1;overflow:hidden;">
                        <div style="font-weight:600;font-size:12px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;color:var(--text-primary);">${this.escapeHTML(child.title || 'Untitled Note')}</div>
                        <div style="font-size:10px;color:var(--text-secondary);">${subCount > 0 ? `${subCount} sub-notes` : 'Leaf document'}</div>
                    </div>
                </div>
            `;
        });

        this.subfoldersGallery.innerHTML = `
            <div class="subfolders-gallery-header">
                <span>Nested Subfolders & Documents (${children.length})</span>
                <button class="btn btn-secondary" id="btn-add-subfolder-gallery" style="font-size:10px;padding:2px 8px;">+ Add Subfolder</button>
            </div>
            <div class="subfolders-grid">
                ${cardsHTML}
            </div>
        `;
        this.subfoldersGallery.style.display = 'block';

        this.subfoldersGallery.querySelectorAll('.subfolder-card').forEach(card => {
            card.addEventListener('click', () => {
                store.selectDocument(card.dataset.docId);
                this.switchView('editor');
            });
        });

        document.getElementById('btn-add-subfolder-gallery')?.addEventListener('click', () => {
            store.createDocument('Untitled Sub-note', doc.id);
        });
    }

    renderAttachedFlashcards(doc) {
        if (!this.attachedFlashcardsSection) return;
        if (!doc) {
            this.attachedFlashcardsSection.style.display = 'none';
            return;
        }

        const cards = store.getFlashcardsForCurrentDoc();
        const fStates = ['New', 'Learning', 'Review', 'Relearn'];

        let cardsListHTML = '';
        if (cards.length === 0) {
            cardsListHTML = `
                <div style="font-size:11px;color:var(--text-secondary);padding:14px;background:rgba(255,255,255,0.02);border:1px dashed var(--border-color);border-radius:6px;text-align:center;">
                    No flashcards attached to this note yet. Click "Extract Cards from Note" (AI) or "+ Add Card".
                </div>
            `;
        } else {
            cards.forEach(card => {
                const stateName = fStates[card.state || 0] || 'New';
                cardsListHTML += `
                    <div class="attached-card-row" data-card-id="${card.id}">
                        <div style="flex:1;overflow:hidden;">
                            <div style="font-weight:600;font-size:12px;color:var(--text-primary);">${this.escapeHTML(card.front)}</div>
                            <div style="font-size:11px;color:var(--text-secondary);margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${this.escapeHTML(card.back)}</div>
                        </div>
                        <span style="font-size:9px;font-weight:700;padding:2px 6px;border-radius:4px;background:rgba(124,77,255,0.14);color:var(--accent-purple);">${stateName}</span>
                        <button class="btn-icon btn-del-attached-card" title="Delete card" style="font-size:11px;">🗑️</button>
                    </div>
                `;
            });
        }

        this.attachedFlashcardsSection.innerHTML = `
            <div class="attached-flashcards-header">
                <div style="font-size:11px;font-weight:700;color:var(--text-secondary);text-transform:uppercase;letter-spacing:0.5px;">
                    🗂️ Flashcards in this Note (${cards.length})
                </div>
                <div style="display:flex;gap:6px;">
                    <button id="btn-extract-cards-note" class="btn btn-secondary" style="font-size:11px;padding:3px 8px;">✨ Extract Cards from Note</button>
                    <button id="btn-add-attached-card" class="btn btn-primary" style="font-size:11px;padding:3px 8px;">+ Add Card</button>
                </div>
            </div>
            <div class="attached-cards-list">
                ${cardsListHTML}
            </div>
        `;
        this.attachedFlashcardsSection.style.display = 'block';

        // Extract cards from note with AI
        document.getElementById('btn-extract-cards-note')?.addEventListener('click', () => {
            this.extractFlashcardsFromCurrentNote();
        });

        // Add card
        document.getElementById('btn-add-attached-card')?.addEventListener('click', () => {
            const front = prompt('Enter Flashcard Front (Question):');
            if (!front) return;
            const back = prompt('Enter Flashcard Back (Answer):');
            if (!back) return;
            const hint = prompt('Enter optional hint:') || '';
            store.createFlashcard({ front, back, hint, docId: doc.id });
        });

        // Delete card buttons
        this.attachedFlashcardsSection.querySelectorAll('.btn-del-attached-card').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const row = e.target.closest('.attached-card-row');
                if (row && confirm('Delete this attached flashcard?')) {
                    store.deleteFlashcard(row.dataset.cardId);
                }
            });
        });
    }

    async extractFlashcardsFromCurrentNote() {
        if (!store.currentDoc) return;
        const doc = store.currentDoc;
        const textContent = `${doc.title}\n\n` + store.blocks.map(b => b.content).filter(Boolean).join('\n');
        if (textContent.trim().length < 15) {
            this.showToast('Note needs more content before extracting flashcards.', 'error');
            return;
        }

        this.showToast('Extracting flashcards with AI...', 'info');

        try {
            const prompt = `You are a spaced repetition study assistant. Extract 2 to 4 high-yield flashcards from this study note.
Return ONLY a valid JSON array of objects with keys "front", "back", and optional "hint".
Do not wrap in any extra text, only the raw JSON array.

Note:
${textContent}`;

            const response = await aiService.query(prompt);
            let cleaned = response.trim();
            if (cleaned.startsWith('```json')) cleaned = cleaned.replace(/^```json\s*/, '').replace(/\s*```$/, '');
            else if (cleaned.startsWith('```')) cleaned = cleaned.replace(/^```\s*/, '').replace(/\s*```$/, '');

            const jsonMatch = cleaned.match(/\[[\s\S]*\]/);
            if (!jsonMatch) {
                throw new Error('AI response did not contain a valid JSON array.');
            }

            const parsedCards = JSON.parse(jsonMatch[0]);
            let count = 0;
            for (const c of parsedCards) {
                if (c.front && c.back) {
                    await store.createFlashcard({
                        front: c.front,
                        back: c.back,
                        hint: c.hint || '',
                        docId: doc.id
                    });
                    count++;
                }
            }

            this.showToast(`Extracted ${count} flashcard${count === 1 ? '' : 's'} from note!`, 'success');
            this.renderAttachedFlashcards(doc);
            this.renderLivingFolderHub(doc, this.calculateWordCount(), Math.max(1, Math.ceil(this.calculateWordCount() / 200)), store.blocks.length);
        } catch (err) {
            console.error('Flashcard extraction error:', err);
            this.showToast(`Extraction failed: ${err.message}`, 'error');
        }
    }

    createBlockRow(block, index = 0, totalBlocks = 1) {
        const row = document.createElement('div');
        row.className = `block-row block-${block.type}`;
        row.dataset.blockId = block.id;

        // Indentation
        if (block.indent && block.indent > 0) {
            row.style.paddingLeft = `${block.indent * 22}px`;
        }

        // Gutter handle
        let prefixHTML = '<div class="block-handle" title="Click for options or turn into...">⋮⋮</div>';

        // Type-specific prefixes
        if (block.type === 'bullet' || block.type === 'bulletList') {
            prefixHTML += '<div class="bullet-dot"></div>';
        } else if (block.type === 'task' || block.type === 'taskList') {
            prefixHTML += `<input type="checkbox" class="task-checkbox" ${block.isChecked ? 'checked' : ''} />`;
        } else if (block.type === 'callout') {
            prefixHTML += '<div class="callout-icon">💡</div>';
        }

        // Header for code blocks or block references
        let headerHTML = '';
        if (block.type === 'code' || block.type === 'codeBlock') {
            headerHTML = `
                <div class="code-block-header" style="display:flex;justify-content:space-between;align-items:center;padding:4px 8px;background:rgba(255,255,255,0.04);border-bottom:1px solid var(--border-color);border-radius:4px 4px 0 0;font-size:10px;font-family:var(--font-mono);color:var(--text-secondary);">
                    <span>Swift / Code</span>
                    <button class="btn-copy-code" type="button" style="background:transparent;border:none;color:var(--text-secondary);cursor:pointer;font-size:10px;">Copy</button>
                </div>
            `;
        } else if (block.type === 'blockRef') {
            headerHTML = `
                <div class="block-ref-header" style="display:flex;align-items:center;gap:6px;font-size:10.5px;color:var(--accent-purple);margin-bottom:4px;">
                    <span>🔗 Block Transclusion</span>
                    <span style="font-family:var(--font-mono);font-size:9.5px;color:var(--text-tertiary);">((ref:${(block.refTargetId || block.id).slice(0, 8)}...))</span>
                    <button class="btn-jump-ref btn-icon" style="font-size:10px;margin-left:auto;" title="Jump to reference">↗</button>
                </div>
            `;
        }

        row.innerHTML = `
            ${prefixHTML}
            <div style="flex:1;display:flex;flex-direction:column;min-width:0;">
                ${headerHTML}
                <div class="block-content" contenteditable="true" placeholder="${this.getBlockPlaceholder(block.type)}">${this.escapeHTML(block.content)}</div>
                <div class="inline-pills-row" style="display:none;"></div>
            </div>
        `;

        const handleEl = row.querySelector('.block-handle');
        const contentEl = row.querySelector('.block-content');
        const pillsRow = row.querySelector('.inline-pills-row');

        // Gutter Menu Trigger
        handleEl.addEventListener('click', (e) => {
            e.stopPropagation();
            this.openGutterMenu(block, handleEl, index, totalBlocks);
        });

        // Code Block Copy Button
        const copyBtn = row.querySelector('.btn-copy-code');
        if (copyBtn) {
            copyBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                navigator.clipboard.writeText(block.content || '');
                copyBtn.textContent = 'Copied!';
                setTimeout(() => { copyBtn.textContent = 'Copy'; }, 1500);
            });
        }

        // Block Ref Jump Button
        const jumpRefBtn = row.querySelector('.btn-jump-ref');
        if (jumpRefBtn) {
            jumpRefBtn.addEventListener('click', async (e) => {
                e.stopPropagation();
                const targetId = block.refTargetId || block.id;
                const allBlocks = await db.getAllBlocks();
                const targetBlock = allBlocks.find(b => b.id === targetId);
                if (targetBlock && targetBlock.docId) {
                    store.selectDocument(targetBlock.docId);
                    this.switchView('editor');
                    setTimeout(() => {
                        const targetEl = document.querySelector(`.block-row[data-block-id="${targetBlock.id}"]`);
                        targetEl?.scrollIntoView({ behavior: 'smooth', block: 'center' });
                        targetEl?.classList.add('block-highlight');
                        setTimeout(() => targetEl?.classList.remove('block-highlight'), 1800);
                    }, 100);
                }
            });
        }

        // Task Checkbox
        const checkbox = row.querySelector('.task-checkbox');
        if (checkbox) {
            checkbox.addEventListener('change', () => {
                store.updateBlock(block.id, { isChecked: checkbox.checked });
                row.classList.toggle('task-completed', checkbox.checked);
            });
            if (block.isChecked) row.classList.add('task-completed');
        }

        // Inline WikiLinks & BlockRefs detection
        const updateInlinePills = (text) => {
            const wikiLinks = LinkParser.extractWikiLinks(text);
            const blockRefs = LinkParser.extractBlockRefs(text);

            if (wikiLinks.length === 0 && blockRefs.length === 0) {
                pillsRow.style.display = 'none';
                pillsRow.innerHTML = '';
                return;
            }

            pillsRow.innerHTML = '';
            wikiLinks.forEach(link => {
                const targetDoc = store.documents.find(d => (d.title || '').toLowerCase() === link.target.toLowerCase());
                const pill = document.createElement('button');
                pill.type = 'button';
                if (targetDoc) {
                    pill.className = 'wiki-link-pill';
                    pill.title = `Jump to note [[${targetDoc.title}]]`;
                    pill.innerHTML = `<span>↗</span> <span>${this.escapeHTML(targetDoc.title)}</span>`;
                    pill.addEventListener('click', (e) => {
                        e.stopPropagation();
                        store.selectDocument(targetDoc.id);
                        this.switchView('editor');
                    });
                } else {
                    pill.className = 'wiki-link-pill wiki-link-new';
                    pill.title = `Create note [[${link.target}]] at vault root`;
                    pill.innerHTML = `<span>+</span> <span>${this.escapeHTML(link.target)}</span> <span style="font-size:9px;opacity:0.7;">New</span>`;
                    pill.addEventListener('click', async (e) => {
                        e.stopPropagation();
                        await store.createDocFromWikiLink(link.target);
                        this.switchView('editor');
                    });
                }
                pillsRow.appendChild(pill);
            });

            blockRefs.forEach(ref => {
                const pill = document.createElement('button');
                pill.type = 'button';
                pill.className = 'wiki-link-pill';
                pill.title = `Jump to referenced block ((${ref.blockId}))`;
                pill.innerHTML = `<span>🔗</span> <span>((${ref.blockId.slice(0, 8)}...))</span>`;
                pill.addEventListener('click', async (e) => {
                    e.stopPropagation();
                    const allBlocks = await db.getAllBlocks();
                    const targetBlock = allBlocks.find(b => b.id === ref.blockId);
                    if (targetBlock && targetBlock.docId) {
                        store.selectDocument(targetBlock.docId);
                        this.switchView('editor');
                        setTimeout(() => {
                            const targetEl = document.querySelector(`.block-row[data-block-id="${targetBlock.id}"]`);
                            targetEl?.scrollIntoView({ behavior: 'smooth', block: 'center' });
                            targetEl?.classList.add('block-highlight');
                            setTimeout(() => targetEl?.classList.remove('block-highlight'), 1800);
                        }, 100);
                    }
                });
                pillsRow.appendChild(pill);
            });

            pillsRow.style.display = 'flex';
        };

        // Initialize pills
        updateInlinePills(block.content || '');

        // Content Input Listener
        contentEl.addEventListener('input', () => {
            const text = contentEl.innerText;
            store.updateBlock(block.id, { content: text });
            updateInlinePills(text);

            // Slash command trigger
            if (text === '/' || text.endsWith('\n/') || text.endsWith(' /')) {
                this.openSlashMenu(block, contentEl);
            }
        });

        // Keyboard Navigation
        contentEl.addEventListener('keydown', async (e) => {
            // Tab for indentation
            if (e.key === 'Tab') {
                e.preventDefault();
                if (e.shiftKey) {
                    store.outdentBlock(block.id);
                } else {
                    store.indentBlock(block.id);
                }
                return;
            }

            // Slash trigger when empty
            if (e.key === '/' && contentEl.innerText.trim() === '') {
                setTimeout(() => this.openSlashMenu(block, contentEl), 10);
            }

            // Enter to add next block
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                this.isLocallyMutatingBlocks = true;
                try {
                    const nextType = (block.type === 'taskList' || block.type === 'task')
                        ? 'taskList'
                        : ((block.type === 'bulletList' || block.type === 'bullet') ? 'bulletList' : 'paragraph');
                    const newBlock = await store.insertBlockAfter(block.id, nextType, '');
                    const newRow = this.createBlockRow(newBlock, index + 1, totalBlocks + 1);
                    row.after(newRow);
                    const nextEl = newRow.querySelector('.block-content');
                    if (nextEl) nextEl.focus();
                } finally {
                    this.isLocallyMutatingBlocks = false;
                }
            } else if (e.key === 'Backspace' && contentEl.innerText.trim() === '') {
                if (store.blocks.length > 1) {
                    e.preventDefault();
                    this.isLocallyMutatingBlocks = true;
                    try {
                        const prevRow = row.previousElementSibling;
                        await store.deleteBlock(block.id);
                        row.remove();
                        if (prevRow) {
                            const prevEl = prevRow.querySelector('.block-content');
                            if (prevEl) {
                                prevEl.focus();
                                const range = document.createRange();
                                range.selectNodeContents(prevEl);
                                range.collapse(false);
                                const sel = window.getSelection();
                                sel.removeAllRanges();
                                sel.addRange(range);
                            }
                        }
                    } finally {
                        this.isLocallyMutatingBlocks = false;
                    }
                }
            }
        });

        return row;
    }

    getBlockPlaceholder(type) {
        if (type === 'heading1' || type === 'h1') return 'Heading 1...';
        if (type === 'heading2' || type === 'h2') return 'Heading 2...';
        if (type === 'heading3') return 'Heading 3...';
        if (type === 'quote') return 'Empty quote...';
        if (type === 'callout') return 'Callout insight...';
        if (type === 'codeBlock' || type === 'code') return '// Monospace code snippet...';
        if (type === 'taskList' || type === 'task') return 'To-do item...';
        if (type === 'bulletList' || type === 'bullet') return 'List item...';
        if (type === 'blockRef') return 'Referenced block...';
        return "Type '/' for commands or start writing...";
    }

    // =========================================
    // GUTTER MENU & SLASH COMMAND MENU
    // =========================================
    openGutterMenu(block, handleEl, index, totalBlocks) {
        this.closeGutterMenu();
        this.closeSlashMenu();

        const menu = document.createElement('div');
        menu.className = 'gutter-menu';

        const rect = handleEl.getBoundingClientRect();
        menu.style.top = `${Math.min(window.innerHeight - 320, rect.bottom + 4)}px`;
        menu.style.left = `${Math.max(10, rect.left)}px`;

        const blockTypes = [
            { type: 'paragraph', label: '¶ Paragraph' },
            { type: 'heading1', label: 'H1 Heading 1' },
            { type: 'heading2', label: 'H2 Heading 2' },
            { type: 'heading3', label: 'H3 Heading 3' },
            { type: 'bulletList', label: '• Bullet List' },
            { type: 'taskList', label: '☑️ Task List' },
            { type: 'codeBlock', label: '💻 Code Block' },
            { type: 'quote', label: '❝ Quote' },
            { type: 'callout', label: '💡 Callout' },
            { type: 'blockRef', label: '🔗 Block Reference' }
        ];

        let turnIntoOptions = '';
        blockTypes.forEach(bt => {
            turnIntoOptions += `<button class="gutter-menu-item btn-turn-into" data-type="${bt.type}">${bt.label}</button>`;
        });

        menu.innerHTML = `
            <button class="gutter-menu-item btn-copy-ref">
                <span>📋</span>
                <span>Copy Block Ref ((${block.id.slice(0, 8)}...))</span>
            </button>
            <div class="gutter-menu-divider"></div>
            <div style="font-size:9.5px;font-weight:700;color:var(--text-tertiary);padding:4px 8px;text-transform:uppercase;">Turn Into...</div>
            <div style="max-height:160px;overflow-y:auto;">
                ${turnIntoOptions}
            </div>
            <div class="gutter-menu-divider"></div>
            <button class="gutter-menu-item btn-move-up" ${index === 0 ? 'disabled style="opacity:0.4;cursor:default;"' : ''}>
                <span>⬆️</span> <span>Move Up</span>
            </button>
            <button class="gutter-menu-item btn-move-down" ${index === totalBlocks - 1 ? 'disabled style="opacity:0.4;cursor:default;"' : ''}>
                <span>⬇️</span> <span>Move Down</span>
            </button>
            <button class="gutter-menu-item btn-indent">
                <span>➡️</span> <span>Indent</span>
            </button>
            <button class="gutter-menu-item btn-outdent">
                <span>⬅️</span> <span>Outdent</span>
            </button>
            <div class="gutter-menu-divider"></div>
            <button class="gutter-menu-item btn-del-block" style="color:#FCA5A5;">
                <span>🗑️</span> <span>Delete Block</span>
            </button>
        `;

        menu.querySelector('.btn-copy-ref')?.addEventListener('click', () => {
            navigator.clipboard.writeText(`((${block.id}))`);
            this.showToast('Block reference copied to clipboard!', 'success');
            this.closeGutterMenu();
        });

        menu.querySelectorAll('.btn-turn-into').forEach(btn => {
            btn.addEventListener('click', () => {
                store.convertBlockType(block.id, btn.dataset.type);
                this.closeGutterMenu();
            });
        });

        menu.querySelector('.btn-move-up')?.addEventListener('click', () => {
            if (index > 0) {
                store.moveBlock(block.id, 'up');
                this.closeGutterMenu();
            }
        });

        menu.querySelector('.btn-move-down')?.addEventListener('click', () => {
            if (index < totalBlocks - 1) {
                store.moveBlock(block.id, 'down');
                this.closeGutterMenu();
            }
        });

        menu.querySelector('.btn-indent')?.addEventListener('click', () => {
            store.indentBlock(block.id);
            this.closeGutterMenu();
        });

        menu.querySelector('.btn-outdent')?.addEventListener('click', () => {
            store.outdentBlock(block.id);
            this.closeGutterMenu();
        });

        menu.querySelector('.btn-del-block')?.addEventListener('click', () => {
            store.deleteBlock(block.id);
            this.closeGutterMenu();
        });

        document.body.appendChild(menu);
        this.activeGutterMenu = menu;
    }

    closeGutterMenu() {
        if (this.activeGutterMenu) {
            this.activeGutterMenu.remove();
            this.activeGutterMenu = null;
        }
    }

    openSlashMenu(block, contentEl) {
        this.closeSlashMenu();
        this.closeGutterMenu();

        const menu = document.createElement('div');
        menu.className = 'slash-menu';

        const rect = contentEl.getBoundingClientRect();
        menu.style.top = `${Math.min(window.innerHeight - 350, rect.bottom + 4)}px`;
        menu.style.left = `${Math.min(window.innerWidth - 290, Math.max(10, rect.left))}px`;

        const commands = [
            // AI commands
            { id: 'ai-assistant', section: 'ai', icon: '✨', title: 'AI Assistant', subtitle: 'Open Notes AI sidebar' },
            { id: 'ai-expand', section: 'ai', icon: '🌲', title: 'Expand Subtopics (AI)', subtitle: 'Downward child subtopics' },
            { id: 'ai-split', section: 'ai', icon: '✂️', title: 'Summarize & Split (AI)', subtitle: 'Split note into modular sub-notes' },
            // Block Types
            { id: 'heading1', section: 'blocks', icon: 'H1', title: 'Heading 1', subtitle: 'Big section heading' },
            { id: 'heading2', section: 'blocks', icon: 'H2', title: 'Heading 2', subtitle: 'Medium section heading' },
            { id: 'heading3', section: 'blocks', icon: 'H3', title: 'Heading 3', subtitle: 'Sub-section heading' },
            { id: 'paragraph', section: 'blocks', icon: '¶', title: 'Paragraph', subtitle: 'Plain text block' },
            { id: 'bulletList', section: 'blocks', icon: '•', title: 'Bullet List', subtitle: 'Bulleted bullet point' },
            { id: 'taskList', section: 'blocks', icon: '☑️', title: 'To-do / Task List', subtitle: 'Checkable to-do item' },
            { id: 'codeBlock', section: 'blocks', icon: '💻', title: 'Code Block', subtitle: 'Monospace code container' },
            { id: 'quote', section: 'blocks', icon: '❝', title: 'Quote', subtitle: 'Italic styled quotation' },
            { id: 'callout', section: 'blocks', icon: '💡', title: 'Callout', subtitle: 'Highlighted insight callout' },
            { id: 'blockRef', section: 'blocks', icon: '🔗', title: 'Block Reference', subtitle: 'Transclude another block' }
        ];

        menu.innerHTML = `
            <div class="slash-menu-search">
                <span style="font-size:11px;">🔍</span>
                <input type="text" class="slash-menu-input" placeholder="Filter commands or blocks..." autofocus />
            </div>
            <div class="slash-menu-list"></div>
        `;

        const listEl = menu.querySelector('.slash-menu-list');
        const inputEl = menu.querySelector('.slash-menu-input');

        const cleanSlashFromBlock = () => {
            let text = contentEl.innerText;
            if (text.startsWith('/')) text = text.substring(1);
            else if (text.endsWith('/')) text = text.substring(0, text.length - 1);
            else if (text.endsWith(' /')) text = text.substring(0, text.length - 2);
            contentEl.innerText = text.trim();
            store.updateBlock(block.id, { content: contentEl.innerText });
        };

        const renderItems = (filter = '') => {
            const q = filter.toLowerCase().trim();
            const filtered = commands.filter(c => !q || c.title.toLowerCase().includes(q) || c.subtitle.toLowerCase().includes(q) || c.id.toLowerCase().includes(q));

            listEl.innerHTML = '';
            if (filtered.length === 0) {
                listEl.innerHTML = '<div style="padding:12px;font-size:11px;color:var(--text-tertiary);text-align:center;">No matching commands</div>';
                return;
            }

            const aiItems = filtered.filter(c => c.section === 'ai');
            const blockItems = filtered.filter(c => c.section === 'blocks');

            if (aiItems.length > 0) {
                const h = document.createElement('div');
                h.className = 'slash-section-header';
                h.textContent = 'AI Assistant';
                listEl.appendChild(h);

                aiItems.forEach(item => {
                    const row = document.createElement('div');
                    row.className = 'slash-item';
                    row.innerHTML = `
                        <span class="slash-item-icon">${item.icon}</span>
                        <div>
                            <div class="slash-item-title">${item.title}</div>
                            <div class="slash-item-subtitle">${item.subtitle}</div>
                        </div>
                    `;
                    row.addEventListener('click', () => {
                        cleanSlashFromBlock();
                        this.closeSlashMenu();
                        if (item.id === 'ai-assistant') {
                            this.aiPanel.classList.remove('collapsed');
                            this.closeInspector();
                        } else if (item.id === 'ai-expand') {
                            const sel = document.getElementById('select-hierarchy-mode');
                            if (sel) sel.value = 'expandSubtopics';
                            this.generateNotesHierarchy();
                        } else if (item.id === 'ai-split') {
                            const sel = document.getElementById('select-hierarchy-mode');
                            if (sel) sel.value = 'summarizeAndSplit';
                            this.generateNotesHierarchy();
                        }
                    });
                    listEl.appendChild(row);
                });
            }

            if (blockItems.length > 0) {
                const h = document.createElement('div');
                h.className = 'slash-section-header';
                h.textContent = 'Block Types';
                listEl.appendChild(h);

                blockItems.forEach(item => {
                    const row = document.createElement('div');
                    row.className = 'slash-item';
                    row.innerHTML = `
                        <span class="slash-item-icon">${item.icon}</span>
                        <div>
                            <div class="slash-item-title">${item.title}</div>
                            <div class="slash-item-subtitle">${item.subtitle}</div>
                        </div>
                    `;
                    row.addEventListener('click', () => {
                        cleanSlashFromBlock();
                        store.convertBlockType(block.id, item.id);
                        this.closeSlashMenu();
                    });
                    listEl.appendChild(row);
                });
            }
        };

        renderItems('');

        inputEl.addEventListener('input', (e) => {
            renderItems(e.target.value);
        });

        inputEl.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                this.closeSlashMenu();
                contentEl.focus();
            } else if (e.key === 'Enter') {
                const firstItem = listEl.querySelector('.slash-item');
                if (firstItem) {
                    firstItem.click();
                }
            }
        });

        document.body.appendChild(menu);
        this.activeSlashMenu = menu;
        setTimeout(() => inputEl.focus(), 20);
    }

    closeSlashMenu() {
        if (this.activeSlashMenu) {
            this.activeSlashMenu.remove();
            this.activeSlashMenu = null;
        }
    }

    // =========================================
    // MAC OS 4-TAB INSPECTOR PANEL
    // =========================================
    toggleInspector() {
        if (!this.inspectorPanel) return;
        const isCurrentlyCollapsed = this.inspectorPanel.classList.contains('collapsed');
        if (isCurrentlyCollapsed) {
            this.inspectorPanel.classList.remove('collapsed');
            this.btnToggleInspector?.classList.add('active');
            this.aiPanel?.classList.add('collapsed');
            this.renderInspector();
        } else {
            this.closeInspector();
        }
    }

    closeInspector() {
        if (!this.inspectorPanel) return;
        this.inspectorPanel.classList.add('collapsed');
        this.btnToggleInspector?.classList.remove('active');
    }

    switchInspectorTab(tab) {
        this.selectedInspectorTab = tab;
        this.inspectorTabBtns.forEach(btn => {
            btn.classList.toggle('active', btn.dataset.tab === tab);
        });
        this.renderInspector();
    }

    async renderInspector() {
        if (!this.inspectorContent) return;
        if (this.inspectorPanel?.classList.contains('collapsed')) return;

        if (!store.currentDoc) {
            this.inspectorContent.innerHTML = `
                <div style="padding:40px 16px;text-align:center;color:var(--text-tertiary);font-size:12px;">
                    Select a document to inspect.
                </div>
            `;
            return;
        }

        const doc = store.currentDoc;
        const tab = this.selectedInspectorTab;

        if (tab === 'outline') {
            this.renderInspectorOutline(doc);
        } else if (tab === 'backlinks') {
            await this.renderInspectorBacklinks(doc);
        } else if (tab === 'graph') {
            await this.renderInspectorLocalGraph(doc);
        } else if (tab === 'info') {
            this.renderInspectorInfo(doc);
        }
    }

    renderInspectorOutline(doc) {
        const items = store.getOutline(doc.id);
        if (items.length === 0) {
            this.inspectorContent.innerHTML = `
                <div style="padding:30px 16px;text-align:center;">
                    <div style="font-size:28px;opacity:0.4;margin-bottom:8px;">📑</div>
                    <div style="font-size:12px;font-weight:600;color:var(--text-secondary);margin-bottom:4px;">No Headings Found</div>
                    <div style="font-size:11px;color:var(--text-tertiary);line-height:1.4;">Add H1, H2, or H3 blocks to generate an automatic Table of Contents.</div>
                </div>
            `;
            return;
        }

        let outlineHTML = `
            <div style="font-size:10px;font-weight:700;color:var(--text-tertiary);text-transform:uppercase;margin-bottom:8px;letter-spacing:0.5px;">
                Table of Contents (${items.length})
            </div>
            <div style="display:flex;flex-direction:column;gap:2px;">
        `;

        items.forEach(item => {
            const indent = (item.level - 1) * 12;
            outlineHTML += `
                <div class="outline-item" data-block-id="${item.blockId}" style="padding-left:${indent + 6}px;">
                    <span class="outline-badge">H${item.level}</span>
                    <span style="flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">${this.escapeHTML(item.title)}</span>
                </div>
            `;
        });
        outlineHTML += '</div>';

        this.inspectorContent.innerHTML = outlineHTML;

        this.inspectorContent.querySelectorAll('.outline-item').forEach(el => {
            el.addEventListener('click', () => {
                const targetRow = this.blocksList.querySelector(`.block-row[data-block-id="${el.dataset.blockId}"]`);
                if (targetRow) {
                    targetRow.scrollIntoView({ behavior: 'smooth', block: 'center' });
                    targetRow.classList.add('block-highlight');
                    setTimeout(() => targetRow.classList.remove('block-highlight'), 1800);
                }
            });
        });
    }

    async renderInspectorBacklinks(doc) {
        this.inspectorContent.innerHTML = `
            <div style="padding:20px;text-align:center;color:var(--text-secondary);font-size:11px;">
                <span class="spinner"></span> Scanning vault for references...
            </div>
        `;

        const backlinks = await store.getBacklinks(doc.id);

        if (backlinks.length === 0) {
            this.inspectorContent.innerHTML = `
                <div style="padding:30px 16px;text-align:center;">
                    <div style="font-size:28px;opacity:0.4;margin-bottom:8px;">🔗</div>
                    <div style="font-size:12px;font-weight:600;color:var(--text-secondary);margin-bottom:4px;">No Backlinks Yet</div>
                    <div style="font-size:11px;color:var(--text-tertiary);line-height:1.4;">
                        Link to this document from other notes using <code>[[${this.escapeHTML(doc.title || 'Title')}]]</code> or <code>((block-id))</code> to see references here.
                    </div>
                </div>
            `;
            return;
        }

        let linksHTML = `
            <div style="font-size:10px;font-weight:700;color:var(--text-tertiary);text-transform:uppercase;margin-bottom:8px;letter-spacing:0.5px;">
                ${backlinks.length} Incoming Reference${backlinks.length === 1 ? '' : 's'}
            </div>
            <div style="display:flex;flex-direction:column;gap:6px;">
        `;

        backlinks.forEach(item => {
            const snippet = item.contextSnippet.length > 90 ? item.contextSnippet.slice(0, 90) + '...' : item.contextSnippet;
            linksHTML += `
                <div class="backlink-card" data-doc-id="${item.sourceDocId}" data-block-id="${item.block.id}">
                    <div style="display:flex;align-items:center;gap:6px;margin-bottom:4px;">
                        <span style="font-size:12px;color:var(--accent-purple);">🔗</span>
                        <strong style="font-size:12px;color:var(--text-primary);flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">${this.escapeHTML(item.sourceDocTitle)}</strong>
                        <span class="wiki-link-pill" style="font-size:9px;padding:1px 5px;margin:0;">${item.linkType === 'wikiLink' ? '[[...]]' : '((...))'}</span>
                    </div>
                    <div style="font-size:11px;color:var(--text-secondary);line-height:1.35;font-style:italic;">"${this.escapeHTML(snippet)}"</div>
                </div>
            `;
        });
        linksHTML += '</div>';

        this.inspectorContent.innerHTML = linksHTML;

        this.inspectorContent.querySelectorAll('.backlink-card').forEach(card => {
            card.addEventListener('click', () => {
                store.selectDocument(card.dataset.docId);
                this.switchView('editor');
                setTimeout(() => {
                    const targetEl = document.querySelector(`.block-row[data-block-id="${card.dataset.blockId}"]`);
                    targetEl?.scrollIntoView({ behavior: 'smooth', block: 'center' });
                    targetEl?.classList.add('block-highlight');
                    setTimeout(() => targetEl?.classList.remove('block-highlight'), 1800);
                }, 100);
            });
        });
    }

    async renderInspectorLocalGraph(doc) {
        this.inspectorContent.innerHTML = `
            <div style="display:flex;flex-direction:column;gap:10px;">
                <!-- Header with depth & tree control -->
                <div style="display:flex;align-items:center;justify-content:space-between;">
                    <div style="display:flex;gap:4px;">
                        <button class="chip-btn local-depth-btn ${this.localGraphDepth === 1 ? 'active' : ''}" data-depth="1">1 Hop</button>
                        <button class="chip-btn local-depth-btn ${this.localGraphDepth === 2 ? 'active' : ''}" data-depth="2">2 Hops</button>
                        <button class="chip-btn local-depth-btn ${this.localGraphDepth === 3 ? 'active' : ''}" data-depth="3">3 Hops</button>
                    </div>
                    <label style="display:flex;align-items:center;gap:4px;font-size:10px;color:var(--text-secondary);cursor:pointer;">
                        <input type="checkbox" id="local-toggle-tree" ${this.localGraphIncludeTree ? 'checked' : ''} />
                        Tree
                    </label>
                </div>

                <!-- Legend -->
                <div style="display:flex;gap:12px;font-size:9.5px;color:var(--text-secondary);">
                    <div style="display:flex;align-items:center;gap:4px;">
                        <span style="width:7px;height:7px;border-radius:50%;background:#00E676;display:inline-block;"></span>
                        <span>Outbound →</span>
                    </div>
                    <div style="display:flex;align-items:center;gap:4px;">
                        <span style="width:7px;height:7px;border-radius:50%;background:#00E5FF;display:inline-block;"></span>
                        <span>Inbound ←</span>
                    </div>
                </div>

                <!-- Mini Canvas -->
                <div style="position:relative;width:100%;height:220px;border-radius:6px;overflow:hidden;border:1px solid var(--border-color);background:#0E0F14;">
                    <canvas id="local-graph-canvas" width="280" height="220" style="width:100%;height:100%;"></canvas>
                </div>
            </div>
        `;

        // Bind depth controls
        this.inspectorContent.querySelectorAll('.local-depth-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                this.localGraphDepth = parseInt(e.currentTarget.dataset.depth, 10);
                this.renderInspectorLocalGraph(doc);
            });
        });

        // Bind tree checkbox
        const treeCb = document.getElementById('local-toggle-tree');
        treeCb?.addEventListener('change', () => {
            this.localGraphIncludeTree = treeCb.checked;
            this.renderInspectorLocalGraph(doc);
        });

        // Run Local Graph simulation on canvas
        const canvas = document.getElementById('local-graph-canvas');
        if (!canvas) return;

        const data = await store.getLocalGraphData(doc.id, this.localGraphDepth, this.localGraphIncludeTree);
        const ctx = canvas.getContext('2d');
        const width = canvas.width;
        const height = canvas.height;

        // Position nodes in a radial layout centered on active doc
        const nodes = data.nodes.map((n, i) => {
            if (n.id === doc.id) {
                return { ...n, x: width / 2, y: height / 2, radius: 10, isCenter: true };
            }
            const angle = (i / Math.max(1, data.nodes.length - 1)) * Math.PI * 2;
            const r = 60 + (i % 2) * 25;
            return {
                ...n,
                x: width / 2 + Math.cos(angle) * r,
                y: height / 2 + Math.sin(angle) * r,
                radius: 6,
                isCenter: false
            };
        });

        const nodeMap = new Map(nodes.map(n => [n.id, n]));

        const drawLocalGraph = () => {
            ctx.clearRect(0, 0, width, height);

            // Draw edges
            ctx.lineWidth = 1.2;
            data.edges.forEach(edge => {
                const s = nodeMap.get(edge.sourceId);
                const t = nodeMap.get(edge.targetId);
                if (s && t) {
                    ctx.strokeStyle = edge.type === 'contains'
                        ? 'rgba(124, 77, 255, 0.4)'
                        : (edge.sourceId === doc.id ? '#00E676' : '#00E5FF');
                    ctx.beginPath();
                    ctx.moveTo(s.x, s.y);
                    ctx.lineTo(t.x, t.y);
                    ctx.stroke();
                }
            });

            // Draw nodes
            nodes.forEach(node => {
                if (node.isCenter) {
                    ctx.fillStyle = 'rgba(124, 77, 255, 0.3)';
                    ctx.beginPath();
                    ctx.arc(node.x, node.y, node.radius + 6, 0, Math.PI * 2);
                    ctx.fill();
                }

                ctx.fillStyle = node.isCenter ? '#7C4DFF' : (node.isUnresolved ? '#6B7280' : '#10B981');
                ctx.beginPath();
                ctx.arc(node.x, node.y, node.radius, 0, Math.PI * 2);
                ctx.fill();

                ctx.fillStyle = '#FFF';
                ctx.font = '9px system-ui, sans-serif';
                ctx.textAlign = 'center';
                const label = (node.title || '').slice(0, 14);
                ctx.fillText(label, node.x, node.y + node.radius + 10);
            });
        };

        drawLocalGraph();

        // Click handler to navigate
        canvas.addEventListener('click', (e) => {
            const rect = canvas.getBoundingClientRect();
            const scaleX = canvas.width / rect.width;
            const scaleY = canvas.height / rect.height;
            const x = (e.clientX - rect.left) * scaleX;
            const y = (e.clientY - rect.top) * scaleY;

            for (const n of nodes) {
                const dist = Math.hypot(n.x - x, n.y - y);
                if (dist <= n.radius + 6) {
                    if (!n.isUnresolved) {
                        store.selectDocument(n.id);
                        this.switchView('editor');
                    } else {
                        store.createDocFromWikiLink(n.title);
                        this.switchView('editor');
                    }
                    break;
                }
            }
        });
    }

    renderInspectorInfo(doc) {
        const words = this.calculateWordCount();
        const chars = this.calculateCharCount();
        const headingsCount = store.blocks.filter(b => b.type === 'heading1' || b.type === 'heading2' || b.type === 'heading3' || b.type === 'h1' || b.type === 'h2').length;
        const tasksCount = store.blocks.filter(b => b.type === 'taskList' || b.type === 'task').length;

        const createdStr = doc.createdAt ? new Date(doc.createdAt).toLocaleString() : 'Just now';
        const updatedStr = doc.updatedAt ? new Date(doc.updatedAt).toLocaleString() : 'Just now';

        this.inspectorContent.innerHTML = `
            <div style="display:flex;flex-direction:column;gap:14px;">
                <!-- Document Metrics -->
                <div>
                    <div style="font-size:10px;font-weight:700;color:var(--text-tertiary);text-transform:uppercase;margin-bottom:6px;letter-spacing:0.5px;">Document Metrics</div>
                    <div style="background:var(--bg-card);border:1px solid var(--border-color);border-radius:6px;padding:8px 10px;">
                        <div class="metric-table-row"><span>Blocks</span><strong>${store.blocks.length}</strong></div>
                        <div class="metric-table-row"><span>Words</span><strong>${words}</strong></div>
                        <div class="metric-table-row"><span>Characters</span><strong>${chars}</strong></div>
                        <div class="metric-table-row"><span>Headings</span><strong>${headingsCount}</strong></div>
                        <div class="metric-table-row"><span>Tasks</span><strong>${tasksCount}</strong></div>
                    </div>
                </div>

                <!-- Timestamps -->
                <div>
                    <div style="font-size:10px;font-weight:700;color:var(--text-tertiary);text-transform:uppercase;margin-bottom:6px;letter-spacing:0.5px;">Timestamps</div>
                    <div style="background:var(--bg-card);border:1px solid var(--border-color);border-radius:6px;padding:8px 10px;">
                        <div class="metric-table-row"><span>Created</span><span style="font-size:11px;color:var(--text-secondary);">${createdStr}</span></div>
                        <div class="metric-table-row"><span>Modified</span><span style="font-size:11px;color:var(--text-secondary);">${updatedStr}</span></div>
                    </div>
                </div>

                <!-- Storage & Privacy -->
                <div>
                    <div style="font-size:10px;font-weight:700;color:var(--text-tertiary);text-transform:uppercase;margin-bottom:6px;letter-spacing:0.5px;">Storage & Architecture</div>
                    <div style="background:var(--bg-card);border:1px solid var(--border-color);border-radius:6px;padding:8px 10px;">
                        <div class="metric-table-row"><span>Engine</span><span style="font-family:var(--font-mono);font-size:10.5px;">IndexedDB (ACID)</span></div>
                        <div class="metric-table-row"><span>Privacy</span><span style="color:#10B981;font-weight:600;">100% Local-First</span></div>
                    </div>
                </div>

                <!-- Export Actions -->
                <div>
                    <div style="font-size:10px;font-weight:700;color:var(--text-tertiary);text-transform:uppercase;margin-bottom:6px;letter-spacing:0.5px;">Export Actions</div>
                    <div style="display:flex;gap:8px;">
                        <button id="btn-copy-md" class="btn btn-secondary" style="flex:1;justify-content:center;font-size:11px;">📄 Copy Markdown</button>
                        <button id="btn-copy-json" class="btn btn-secondary" style="flex:1;justify-content:center;font-size:11px;">📦 Copy JSON</button>
                    </div>
                </div>
            </div>
        `;

        document.getElementById('btn-copy-md')?.addEventListener('click', () => {
            const md = store.exportCurrentAsMarkdown();
            navigator.clipboard.writeText(md);
            this.showToast(`Markdown for "${doc.title}" copied!`, 'success');
        });

        document.getElementById('btn-copy-json')?.addEventListener('click', () => {
            const json = store.exportCurrentAsJSON();
            navigator.clipboard.writeText(json);
            this.showToast('Full block JSON tree copied!', 'success');
        });
    }

    // =========================================
    // 3. FLASHCARDS & FSRS REVIEW
    // =========================================
    renderFlashcards() {
        this.updateDueBadges();
        const cards = store.flashcards;
        if (cards.length === 0) {
            this.cardFront.innerText = 'No flashcards in your vault yet.';
            this.cardBack.innerText = '';
            this.cardHint.innerText = 'Click "+ New Flashcard" or generate cards from notes.';
            this.reviewControls.style.display = 'none';
            return;
        }


        if (this.currentCardIndex >= cards.length) {
            this.currentCardIndex = 0;
        }

        const card = cards[this.currentCardIndex];
        this.isCardFlipped = false;
        this.flipCard.classList.remove('flipped');

        this.cardFront.innerText = card.front;
        this.cardBack.innerText = card.back;
        this.cardHint.innerText = card.hint ? `Hint: ${card.hint}` : '';
        this.cardBadge.innerText = `Card ${this.currentCardIndex + 1} of ${cards.length}`;

        // Predict FSRS intervals on buttons
        const intervals = fsrs.predictIntervals(card);
        document.getElementById('int-again').innerText = intervals[Rating.Again];
        document.getElementById('int-hard').innerText = intervals[Rating.Hard];
        document.getElementById('int-good').innerText = intervals[Rating.Good];
        document.getElementById('int-easy').innerText = intervals[Rating.Easy];

        this.reviewControls.style.display = 'flex';
        this.socraticFeedback.innerText = '';
        this.socraticInput.value = '';
    }

    toggleCardFlip() {
        this.isCardFlipped = !this.isCardFlipped;
        this.flipCard.classList.toggle('flipped', this.isCardFlipped);
    }

    async rateActiveCard(rating) {
        const card = store.flashcards[this.currentCardIndex];
        if (!card) return;

        const { updatedCard } = fsrs.review(card, rating);
        await store.saveFlashcard(updatedCard);

        this.currentCardIndex = (this.currentCardIndex + 1) % store.flashcards.length;
        this.renderFlashcards();
    }

    async submitSocraticAnswer() {
        const text = this.socraticInput.value.trim();
        if (!text) return;

        const card = store.flashcards[this.currentCardIndex];
        if (!card) return;

        this.socraticFeedback.innerHTML = '<span style="color:var(--accent-purple);">Socratic AI is thinking...</span>';

        try {
            const evalResult = await aiService.evaluateAnswer({
                question: card.front,
                targetAnswer: card.back,
                hint: card.hint,
                userAnswer: text
            });

            let html = `<strong>Feedback:</strong> ${this.escapeHTML(evalResult.feedback)}<br/>`;
            if (evalResult.counterQuestion) {
                html += `<div style="margin-top:6px; color:var(--accent-amber);">💡 <em>${this.escapeHTML(evalResult.counterQuestion)}</em></div>`;
            }
            this.socraticFeedback.innerHTML = html;

            // Automatically flip to reveal answer
            if (!this.isCardFlipped) this.toggleCardFlip();
        } catch (e) {
            this.socraticFeedback.innerText = 'Evaluation error: ' + e.message;
        }
    }

    // =========================================
    // 4. KNOWLEDGE GRAPH
    // =========================================
    initGraph() {
        if (!this.graphCanvas) return;
        this.graphView = new KnowledgeGraphView(this.graphCanvas, (selectedId) => {
            store.selectDocument(selectedId);
            this.switchView('editor');
        });
        this.updateGraph();
    }

    updateGraph() {
        if (this.graphView) {
            this.graphView.setData(store.documents, store.currentDoc?.id);
        }
    }

    // =========================================
    // 5. AI ASSISTANT & STUDY GROUNDING
    // =========================================
    renderAISources() {
        this.aiSourcesList.innerHTML = '';
        Object.values(StudyGroundingSource).forEach((src) => {
            const meta = SourceMetadata[src];
            const isSelected = this.selectedSources.includes(src);

            const chip = document.createElement('div');
            chip.className = `source-chip ${isSelected ? 'selected' : ''}`;
            chip.innerHTML = `
                <span class="source-chip-icon">${meta.icon}</span>
                <div class="source-chip-text">
                    <div class="source-chip-title">${meta.displayName}</div>
                    <div class="source-chip-desc">${meta.subtitle}</div>
                </div>
                <span>${isSelected ? '✓' : ''}</span>
            `;

            chip.addEventListener('click', () => {
                if (this.selectedSources.includes(src)) {
                    this.selectedSources = this.selectedSources.filter(s => s !== src);
                } else {
                    this.selectedSources.push(src);
                }
                this.renderAISources();
            });

            this.aiSourcesList.appendChild(chip);
        });
    }

    async generateNotesHierarchy() {
        if (!store.currentDoc) {
            this.showToast('Please select or create a note in the vault first.', 'error');
            this.aiStatus.innerHTML = '<span style="color:#F87171;">⚠️ Please select or create a note in the vault first.</span>';
            return;
        }

        const origBtnText = this.btnGenerateHierarchy.innerHTML;
        this.btnGenerateHierarchy.disabled = true;
        this.btnGenerateHierarchy.innerHTML = `<span class="spinner"></span> Generating...`;
        this.aiStatus.innerHTML = '<span style="color:var(--accent-color);">1/2: Grounding with academic sources...</span>';

        const title = store.currentDoc.title || 'Untitled Note';
        const content = store.blocks.map(b => b.content).join('\n');
        const mode = document.getElementById('select-hierarchy-mode')?.value || 'expandSubtopics';

        try {
            const result = await aiService.generateDownwardHierarchy({
                noteTitle: title,
                noteContent: content,
                mode,
                selectedSources: this.selectedSources,
                onProgress: (stepText) => {
                    this.aiStatus.innerHTML = `<span style="color:var(--accent-color);">${this.escapeHTML(stepText)}</span>`;
                }
            });

            this.aiStatus.innerHTML = `<span style="color:#34D399;">✓ Proposing ${(result.items || []).length} downward notes</span>`;
            this.showApprovalModal(result);
        } catch (err) {
            console.error('Hierarchy generation error:', err);
            this.aiStatus.innerHTML = `<span style="color:#F87171; word-break:break-word;">⚠️ Error: ${this.escapeHTML(err.message)}</span>`;
            this.showToast(`Generation Error: ${err.message}`, 'error');
        } finally {
            this.btnGenerateHierarchy.disabled = false;
            this.btnGenerateHierarchy.innerHTML = origBtnText;
        }
    }

    showApprovalModal(result) {
        const modal = document.createElement('div');
        modal.className = 'modal-overlay';

        let itemsHTML = '';
        if (!result.items || result.items.length === 0) {
            itemsHTML = `
                <div style="padding:16px; text-align:center; color:var(--text-secondary);">
                    No downward notes were proposed by the model. Try adding more context to your note or verify your local model.
                </div>
            `;
        } else {
            result.items.forEach((item, idx) => {
                const childCount = (item.children && item.children.length > 0) ? ` (${item.children.length} sub-items)` : '';
                itemsHTML += `
                    <div style="margin-bottom:12px; padding:10px; background:var(--bg-card); border-radius:6px; border:1px solid var(--border-color);">
                        <label style="display:flex; align-items:center; gap:8px; font-weight:600; cursor:pointer;">
                            <input type="checkbox" checked data-idx="${idx}" class="approval-check" />
                            ${this.escapeHTML(item.title)}${childCount}
                        </label>
                        <div style="margin-top:6px; font-size:12px; color:var(--text-secondary); line-height: 1.4;">
                            ${this.escapeHTML(item.blocks?.[0]?.content || item.summary || '')}
                        </div>
                    </div>
                `;
            });
        }

        modal.innerHTML = `
            <div class="modal-card">
                <div class="modal-header">
                    <h3 style="font-size:15px; font-weight:600;">Review Downward Note Hierarchy</h3>
                    <button class="btn-icon btn-close-modal">×</button>
                </div>
                <div class="modal-body">
                    <p style="font-size:12px; color:var(--text-secondary); margin-bottom:12px;">
                        ${this.escapeHTML(result.overview || 'Strict downward hierarchy parented under active note.')}
                    </p>
                    ${itemsHTML}
                </div>
                <div class="modal-footer">
                    <button class="btn btn-secondary btn-close-modal">Cancel</button>
                    ${result.items && result.items.length > 0 ? `<button class="btn btn-primary btn-commit-hierarchy">Commit to Vault</button>` : ''}
                </div>
            </div>
        `;

        const closeModal = () => {
            if (modal.parentNode) modal.parentNode.removeChild(modal);
        };
        modal.querySelectorAll('.btn-close-modal').forEach(b => b.addEventListener('click', closeModal));

        const commitBtn = modal.querySelector('.btn-commit-hierarchy');
        if (commitBtn) {
            commitBtn.addEventListener('click', async () => {
                commitBtn.disabled = true;
                commitBtn.innerHTML = `<span class="spinner"></span> Creating notes...`;

                const checkboxes = modal.querySelectorAll('.approval-check');
                let count = 0;
                for (const cb of checkboxes) {
                    if (cb.checked) {
                        const item = result.items[parseInt(cb.dataset.idx, 10)];
                        await this.commitHierarchyNode(item, store.currentDoc.id);
                        count++;
                    }
                }
                closeModal();
                await store.load();
                this.showToast(`Added ${count} downward note(s) to vault!`, 'success');
            });
        }

        document.body.appendChild(modal);
    }

    async commitHierarchyNode(node, parentId) {
        const childDoc = await store.createDocument(node.title, parentId);
        if (node.blocks && node.blocks.length > 0) {
            const newBlocks = node.blocks.map((b, i) => ({
                id: 'b-' + Math.random().toString(36).substring(2, 9),
                docId: childDoc.id,
                type: b.typeString === 'callout' ? 'callout' : (b.typeString === 'bulletList' ? 'bulletList' : 'paragraph'),
                content: b.content || '',
                isChecked: false,
                sortOrder: i
            }));
            await store.saveBlocks(newBlocks);
        }
        if (node.children && node.children.length > 0) {
            for (const child of node.children) {
                await this.commitHierarchyNode(child, childDoc.id);
            }
        }
    }

    showToast(message, type = 'info') {
        let container = document.getElementById('toast-container');
        if (!container) {
            container = document.createElement('div');
            container.id = 'toast-container';
            container.className = 'medha-toast-container';
            document.body.appendChild(container);
        }

        const toast = document.createElement('div');
        toast.className = `medha-toast toast-${type}`;
        const icon = type === 'success' ? '✓' : (type === 'error' ? '⚠️' : 'ℹ️');
        toast.innerHTML = `<span style="font-weight:700;">${icon}</span><span>${this.escapeHTML(message)}</span>`;

        container.appendChild(toast);

        setTimeout(() => {
            toast.style.opacity = '0';
            toast.style.transform = 'translateY(10px) scale(0.95)';
            setTimeout(() => {
                if (toast.parentNode) toast.parentNode.removeChild(toast);
            }, 300);
        }, 4000);
    }

    // =========================================
    // 6. SETTINGS MODAL & CONNECTION TEST
    // =========================================
    openSettingsModal() {
        this.settingProvider.value = aiService.provider;
        this.settingEndpoint.value = aiService.localEndpoint;
        this.settingModel.value = aiService.model;
        this.settingApiKey.value = aiService.apiKey;
        if (this.connectionResult) {
            this.connectionResult.className = 'connection-status hidden';
            this.connectionResult.innerHTML = '';
        }
        this.updateProviderVisibility();
        this.settingsModal.classList.remove('hidden');
    }

    updateProviderVisibility() {
        const prov = this.settingProvider.value;
        if (this.groupLocalEndpoint) {
            this.groupLocalEndpoint.style.display = (prov === 'local') ? 'block' : 'none';
        }
        const linkGetKey = document.getElementById('link-get-key');
        if (linkGetKey) {
            if (prov === 'groq') {
                linkGetKey.href = 'https://console.groq.com/keys';
                linkGetKey.innerText = 'Get Free Groq Key ↗';
                linkGetKey.style.display = 'inline';
                if (!this.settingModel.value || this.settingModel.value.includes('llama-3.3') || this.settingModel.value.includes('gemini')) {
                    this.settingModel.value = 'qwen/qwen3.8-27b';
                }
            } else if (prov === 'gemini') {
                linkGetKey.href = 'https://aistudio.google.com/app/apikey';
                linkGetKey.innerText = 'Get Gemini Key ↗';
                linkGetKey.style.display = 'inline';
            } else if (prov === 'openai') {
                linkGetKey.href = 'https://platform.openai.com/api-keys';
                linkGetKey.innerText = 'Get OpenAI Key ↗';
                linkGetKey.style.display = 'inline';
            } else {
                linkGetKey.href = 'https://ollama.com';
                linkGetKey.innerText = 'Get Ollama ↗';
                linkGetKey.style.display = 'none';
            }
        }
    }

    async testAIConnection() {
        if (!this.btnTestConnection) return;
        this.btnTestConnection.disabled = true;
        this.btnTestConnection.innerText = 'Testing...';
        this.connectionResult.className = 'connection-status testing';
        this.connectionResult.innerHTML = '<span>⏳</span> Pinging server & inspecting models...';
        this.connectionResult.classList.remove('hidden');

        try {
            const result = await aiService.validateConnection({
                provider: this.settingProvider.value,
                localEndpoint: this.settingEndpoint.value,
                model: this.settingModel.value,
                apiKey: this.settingApiKey.value
            });

            if (result.success) {
                this.connectionResult.className = 'connection-status success';
                let html = `<div><strong>✓ Connected:</strong> ${this.escapeHTML(result.message)}</div>`;
                if (result.models && result.models.length > 0) {
                    html += `<div style="margin-top:6px; font-size:11px; color:#A7F3D0; font-weight:600;">Discovered Models (Click to use):</div><div class="model-chips-row">`;
                    result.models.forEach(m => {
                        const isCurrent = m === this.settingModel.value;
                        html += `<button type="button" class="chip-btn model-pick-btn ${isCurrent ? 'active' : ''}" data-model="${this.escapeHTML(m)}">${this.escapeHTML(m)}</button>`;
                    });
                    html += `</div>`;
                }
                this.connectionResult.innerHTML = html;

                this.connectionResult.querySelectorAll('.model-pick-btn').forEach(btn => {
                    btn.addEventListener('click', (e) => {
                        const chosenModel = e.currentTarget.dataset.model;
                        this.settingModel.value = chosenModel;
                        this.connectionResult.querySelectorAll('.model-pick-btn').forEach(b => b.classList.remove('active'));
                        e.currentTarget.classList.add('active');
                        aiService.saveSettings({ model: chosenModel });
                        this.showToast(`Selected model: ${chosenModel}`, 'success');
                    });
                });
            } else {
                this.connectionResult.className = 'connection-status error';
                this.connectionResult.innerHTML = `<div><strong>⚠️ Connection Failed:</strong> ${this.escapeHTML(result.message)}</div>`;
            }
        } catch (err) {
            this.connectionResult.className = 'connection-status error';
            this.connectionResult.innerHTML = `<div><strong>⚠️ Error:</strong> ${this.escapeHTML(err.message)}</div>`;
        } finally {
            this.btnTestConnection.disabled = false;
            this.btnTestConnection.innerText = '⚡ Test Connection';
        }
    }

    saveSettingsModal() {
        aiService.saveSettings({
            provider: this.settingProvider.value,
            localEndpoint: this.settingEndpoint.value,
            model: this.settingModel.value,
            apiKey: this.settingApiKey.value,
            enabledSources: this.selectedSources
        });
        this.settingsModal.classList.add('hidden');
        this.showToast('Settings saved and applied!', 'success');
    }

    // =========================================
    // 7. MAC OS ENHANCEMENTS: DUE BADGES, TIMER & SPOTLIGHT
    // =========================================
    updateDueBadges() {
        const dueCount = store.flashcards.filter(c => (c.due || 0) <= Date.now()).length;
        if (this.dueBadge) {
            this.dueBadge.textContent = dueCount;
            this.dueBadge.style.display = dueCount > 0 ? 'inline-block' : 'none';
        }
        if (this.sidebarDueBadge) {
            this.sidebarDueBadge.textContent = dueCount;
            this.sidebarDueBadge.style.display = dueCount > 0 ? 'inline-block' : 'none';
        }
    }

    initFocusTimer() {
        this.timerDuration = 25 * 60;
        this.timerRemaining = this.timerDuration;
        this.isTimerRunning = false;
        this.timerInterval = null;

        this.focusTimerPill?.addEventListener('click', () => {
            if (this.isTimerRunning) {
                this.isTimerRunning = false;
                clearInterval(this.timerInterval);
                this.focusTimerPill.classList.remove('running');
            } else {
                this.isTimerRunning = true;
                this.focusTimerPill.classList.add('running');
                this.timerInterval = setInterval(() => {
                    if (this.timerRemaining > 0) {
                        this.timerRemaining--;
                        this.updateTimerDisplay();
                    } else {
                        this.isTimerRunning = false;
                        clearInterval(this.timerInterval);
                        this.focusTimerPill.classList.remove('running');
                        alert('Focus session complete! Take a well-deserved break.');
                        this.timerRemaining = this.timerDuration;
                        this.updateTimerDisplay();
                    }
                }, 1000);
            }
        });
    }

    updateTimerDisplay() {
        const m = Math.floor(this.timerRemaining / 60).toString().padStart(2, '0');
        const s = (this.timerRemaining % 60).toString().padStart(2, '0');
        if (this.timerDisplay) {
            this.timerDisplay.textContent = `${m}:${s}`;
        }
    }

    openSearchModal() {
        if (!this.searchModal) return;
        this.searchModal.classList.remove('hidden');
        if (this.paletteInput) {
            this.paletteInput.value = '';
            setTimeout(() => this.paletteInput.focus(), 50);
        }
        this.filterSearchResults('');
    }

    closeSearchModal() {
        if (this.searchModal) this.searchModal.classList.add('hidden');
    }

    filterSearchResults(query) {
        if (!this.paletteResults) return;
        const q = (query || '').toLowerCase().trim();
        const matched = store.documents.filter(d => {
            if (!q) return true;
            return (d.title || '').toLowerCase().includes(q);
        });

        this.paletteResults.innerHTML = '';
        if (matched.length === 0) {
            this.paletteResults.innerHTML = '<div style="padding:16px;text-align:center;color:var(--text-tertiary);font-size:12px;">No matching notes found</div>';
            return;
        }

        matched.forEach(doc => {
            const item = document.createElement('div');
            item.className = 'palette-item';
            item.innerHTML = `
                <span style="font-size:14px;">📄</span>
                <div style="flex:1;">
                    <div style="font-weight:600; font-size:13px; color:var(--text-primary);">${this.escapeHTML(doc.title || 'Untitled Note')}</div>
                </div>
                <span style="font-size:11px; color:var(--text-tertiary);">Jump ↵</span>
            `;
            item.addEventListener('click', () => {
                store.selectDocument(doc.id);
                this.switchView('editor');
                this.closeSearchModal();
            });
            this.paletteResults.appendChild(item);
        });
    }

    escapeHTML(str) {
        return (str || '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#039;');
    }
}


// Initialize on DOM load
window.addEventListener('DOMContentLoaded', () => {
    const app = new MedhaApp();
    app.start();
    window.medhaApp = app;
});
