// Medha Windows Desktop — Block PKM Editor Engine
// 100% faithful port of BlockEditorView.swift & BlockRowView.swift
// Features 740px measure, caret continuity, slash command menu, [[WikiLinks]], and ((transclusion))

class BlockEditorEngine {
    constructor(containerElement, store, options = {}) {
        this.container = containerElement;
        this.store = store;
        this.slashMenu = null;
        this.activeSlashBlockId = null;

        this.onDocSelected = options.onDocSelected || null;

        this.initSlashMenu();
    }

    initSlashMenu() {
        this.slashMenu = document.createElement('div');
        this.slashMenu.className = 'slash-menu';
        document.body.appendChild(this.slashMenu);

        const items = [
            { type: 'heading1', label: 'Heading 1', icon: 'H1' },
            { type: 'heading2', label: 'Heading 2', icon: 'H2' },
            { type: 'heading3', label: 'Heading 3', icon: 'H3' },
            { type: 'paragraph', label: 'Paragraph', icon: '¶' },
            { type: 'bulletList', label: 'Bullet List', icon: '•' },
            { type: 'taskList', label: 'To-Do Task', icon: '☑' },
            { type: 'codeBlock', label: 'Code Block', icon: '</>' },
            { type: 'quote', label: 'Quote', icon: '❞' },
            { type: 'callout', label: 'Callout Note', icon: '💡' }
        ];

        for (const it of items) {
            const row = document.createElement('div');
            row.className = 'slash-item';
            row.innerHTML = `<span class="slash-item-icon">${it.icon}</span><span>${it.label}</span>`;
            row.addEventListener('click', () => {
                if (this.activeSlashBlockId) {
                    this.store.convertBlockType(this.activeSlashBlockId, it.type);
                    this.hideSlashMenu();
                    this.renderBlocks();
                }
            });
            this.slashMenu.appendChild(row);
        }
    }

    showSlashMenu(x, y, blockId) {
        this.activeSlashBlockId = blockId;
        this.slashMenu.style.left = `${Math.min(window.innerWidth - 280, x)}px`;
        this.slashMenu.style.top = `${Math.min(window.innerHeight - 300, y + 20)}px`;
        this.slashMenu.style.display = 'block';
    }

    hideSlashMenu() {
        this.slashMenu.style.display = 'none';
        this.activeSlashBlockId = null;
    }

    formatContent(raw) {
        if (!raw) return '';
        // 1. WikiLinks [[Title]]
        let formatted = raw.replace(/\[\[(.*?)\]\]/g, (match, title) => {
            return `<span class="wikilink-badge" data-title="${title}">${title}</span>`;
        });
        // 2. Transclusions ((b-uuid))
        formatted = formatted.replace(/\(\((.*?)\)\)/g, (match, refId) => {
            const target = this.store.blocks.find(b => b.id === refId);
            return `<span class="blockref-pill" data-ref="${refId}">${target ? target.content : `[Block ${refId.slice(0, 6)}]`}</span>`;
        });
        return formatted;
    }

    renderBlocks() {
        this.container.innerHTML = '';

        const doc = this.store.currentDoc;
        if (!doc) {
            this.container.innerHTML = '<div style="color: var(--text-muted); padding: 40px;">No document selected.</div>';
            return;
        }

        const measure = document.createElement('div');
        measure.className = 'editor-measure';

        // Document Header Hub
        const hub = document.createElement('div');
        hub.className = 'doc-header-hub';

        const breadcrumbs = document.createElement('div');
        breadcrumbs.className = 'breadcrumbs-trail';
        breadcrumbs.innerHTML = `<span class="breadcrumb-crumb">Knowledge Base</span> <span>/</span> <span class="breadcrumb-crumb">${doc.content}</span>`;
        hub.appendChild(breadcrumbs);

        const titleInput = document.createElement('input');
        titleInput.type = 'text';
        titleInput.className = 'doc-title-input';
        titleInput.value = doc.content || '';
        titleInput.placeholder = 'Document Title...';
        titleInput.addEventListener('input', (e) => {
            doc.content = e.target.value;
            this.store.execute('UPDATE block SET content = ? WHERE id = ?', [doc.content, doc.id]);
            this.store.notify('title_changed', { docId: doc.id, title: doc.content });
        });
        hub.appendChild(titleInput);

        const metadata = document.createElement('div');
        metadata.className = 'doc-metadata-scrim';
        metadata.innerHTML = `
            <span>📄 ${this.store.blocks.length} blocks</span>
            <span>⏱️ ${Math.max(1, Math.round(this.store.blocks.length * 12 / 60))} min read</span>
            <span>🗂️ ${this.store.flashcards.filter(f => f.docId === doc.id).length} cards attached</span>
        `;
        hub.appendChild(metadata);

        measure.appendChild(hub);

        // Blocks List
        const blocksList = document.createElement('div');
        blocksList.className = 'blocks-list';

        for (let i = 0; i < this.store.blocks.length; i++) {
            const block = this.store.blocks[i];
            const row = document.createElement('div');
            row.className = 'block-row';
            row.dataset.id = block.id;
            row.dataset.type = block.type;
            if (block.isCompleted) row.classList.add('completed');

            // Drag handle
            const handle = document.createElement('div');
            handle.className = 'block-handle';
            handle.innerHTML = '⋮⋮';
            row.appendChild(handle);

            // Task Checkbox if taskList
            if (block.type === 'taskList') {
                const cb = document.createElement('input');
                cb.type = 'checkbox';
                cb.className = 'task-checkbox';
                cb.checked = !!block.isCompleted;
                cb.addEventListener('change', () => {
                    this.store.toggleTask(block.id);
                    row.classList.toggle('completed', block.isCompleted);
                });
                row.appendChild(cb);
            }

            // Content Area
            const content = document.createElement('div');
            content.className = 'block-content-area';
            content.contentEditable = 'true';
            content.dataset.placeholder = 'Type / for commands...';
            content.textContent = block.content || '';

            // Keystroke Continuity (Enter, Backspace, Arrows)
            content.addEventListener('keydown', (e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                    e.preventDefault();
                    const newType = block.type === 'bulletList' || block.type === 'taskList' ? block.type : 'paragraph';
                    const newBlock = this.store.createBlock(newType, '', doc.id, block.sortOrder + 1);
                    this.renderBlocks();
                    setTimeout(() => {
                        const nextRow = this.container.querySelector(`.block-row[data-id="${newBlock.id}"] .block-content-area`);
                        if (nextRow) nextRow.focus();
                    }, 10);
                } else if (e.key === 'Backspace' && content.textContent.length === 0) {
                    e.preventDefault();
                    if (block.type !== 'paragraph') {
                        this.store.convertBlockType(block.id, 'paragraph');
                        this.renderBlocks();
                    } else if (this.store.blocks.length > 1) {
                        const prevIdx = Math.max(0, i - 1);
                        const prevBlock = this.store.blocks[prevIdx];
                        this.store.deleteBlock(block.id);
                        this.renderBlocks();
                        setTimeout(() => {
                            const prevRow = this.container.querySelector(`.block-row[data-id="${prevBlock.id}"] .block-content-area`);
                            if (prevRow) prevRow.focus();
                        }, 10);
                    }
                } else if (e.key === 'ArrowUp') {
                    if (i > 0) {
                        e.preventDefault();
                        const prevBlock = this.store.blocks[i - 1];
                        const prevRow = this.container.querySelector(`.block-row[data-id="${prevBlock.id}"] .block-content-area`);
                        if (prevRow) prevRow.focus();
                    }
                } else if (e.key === 'ArrowDown') {
                    if (i < this.store.blocks.length - 1) {
                        e.preventDefault();
                        const nextBlock = this.store.blocks[i + 1];
                        const nextRow = this.container.querySelector(`.block-row[data-id="${nextBlock.id}"] .block-content-area`);
                        if (nextRow) nextRow.focus();
                    }
                } else if (e.key === '/') {
                    const rect = content.getBoundingClientRect();
                    this.showSlashMenu(rect.left, rect.bottom, block.id);
                } else if (e.key === 'Escape') {
                    this.hideSlashMenu();
                }
            });

            content.addEventListener('input', () => {
                this.store.updateBlockContent(block.id, content.textContent);
            });

            row.appendChild(content);
            blocksList.appendChild(row);
        }

        measure.appendChild(blocksList);
        this.container.appendChild(measure);
    }
}

if (typeof module !== 'undefined') {
    module.exports = { BlockEditorEngine };
}
