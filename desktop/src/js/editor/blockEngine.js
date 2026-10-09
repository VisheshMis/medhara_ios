// Medha Windows Desktop — Block PKM Editor Engine
// 100% faithful port of BlockEditorView.swift, ToggleBlockView.swift, TableBlockView.swift & PinnedPropertyBarView.swift
// Features: 740px measure, caret continuity, slash command menu, [[WikiLinks]], ((transclusion)),
// Toggle blocks, 2D Table matrix blocks, Collapsible Headings, Document Lock mode, and Authoritative Verification badges.

class BlockEditorEngine {
    constructor(containerElement, store, options = {}) {
        this.container = containerElement;
        this.store = store;
        this.slashMenu = null;
        this.activeSlashBlockId = null;

        this.onDocSelected = options.onDocSelected || null;

        if (typeof document !== 'undefined') {
            this.initSlashMenu();
        }
    }

    initSlashMenu() {
        if (typeof document === 'undefined') return;
        this.slashMenu = document.createElement('div');
        this.slashMenu.className = 'slash-menu';
        document.body.appendChild(this.slashMenu);

        const items = [
            { type: 'heading1', label: 'Heading 1 (Collapsible)', icon: 'H1' },
            { type: 'heading2', label: 'Heading 2 (Collapsible)', icon: 'H2' },
            { type: 'heading3', label: 'Heading 3 (Collapsible)', icon: 'H3' },
            { type: 'paragraph', label: 'Paragraph', icon: '¶' },
            { type: 'toggle', label: 'Toggle List (Foldable)', icon: '▶' },
            { type: 'table', label: 'Table Matrix Grid', icon: '▦' },
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
                    if (it.type === 'table') {
                        // Initialize default table payload if converted to table
                        const defaultTable = {
                            rows: [
                                ['Header 1', 'Header 2', 'Header 3'],
                                ['Cell 1', 'Cell 2', 'Cell 3'],
                                ['Cell 4', 'Cell 5', 'Cell 6']
                            ],
                            hasHeaderRow: true,
                            hasHeaderCol: false
                        };
                        this.store.updateBlockContent(this.activeSlashBlockId, JSON.stringify(defaultTable));
                    }
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

    parseTablePayload(rawContent) {
        try {
            if (rawContent && rawContent.startsWith('{')) {
                const parsed = JSON.parse(rawContent);
                if (Array.isArray(parsed.rows)) return parsed;
            }
        } catch (e) {}

        return {
            rows: [
                ['Column 1', 'Column 2', 'Column 3'],
                ['Value 1', 'Value 2', 'Value 3'],
                ['Value 4', 'Value 5', 'Value 6']
            ],
            hasHeaderRow: true,
            hasHeaderCol: false
        };
    }

    calculateVerificationDays(expiresAtStr) {
        if (!expiresAtStr) return 0;
        const diff = new Date(expiresAtStr).getTime() - Date.now();
        return Math.max(0, Math.ceil(diff / (1000 * 60 * 60 * 24)));
    }

    renderBlocks() {
        this.container.innerHTML = '';

        const doc = this.store.currentDoc;
        if (!doc) {
            this.container.innerHTML = '<div style="color: var(--text-muted); padding: 40px;">No document selected.</div>';
            return;
        }

        const isLocked = !!doc.isLocked;

        const measure = document.createElement('div');
        measure.className = 'editor-measure';

        // Document Header Hub
        const hub = document.createElement('div');
        hub.className = 'doc-header-hub';

        const breadcrumbs = document.createElement('div');
        breadcrumbs.className = 'breadcrumbs-trail';
        breadcrumbs.innerHTML = `<span class="breadcrumb-crumb">Knowledge Base</span> <span>/</span> <span class="breadcrumb-crumb">${doc.content || 'Untitled'}</span>`;
        hub.appendChild(breadcrumbs);

        const titleInput = document.createElement('input');
        titleInput.type = 'text';
        titleInput.className = 'doc-title-input';
        titleInput.value = doc.content || '';
        titleInput.placeholder = 'Document Title...';
        titleInput.disabled = isLocked;
        titleInput.addEventListener('input', (e) => {
            doc.content = e.target.value;
            this.store.execute('UPDATE block SET content = ? WHERE id = ?', [doc.content, doc.id]);
            this.store.notify('title_changed', { docId: doc.id, title: doc.content });
        });
        hub.appendChild(titleInput);

        // Pinned Property & Governance Bar
        const pinnedBar = document.createElement('div');
        pinnedBar.className = 'pinned-property-bar';

        // 1. Verification Pill
        const isVerified = doc.verifiedAt && (!doc.verifiedExpiresAt || new Date(doc.verifiedExpiresAt) > new Date());
        const daysRemaining = this.calculateVerificationDays(doc.verifiedExpiresAt);

        const verifyPill = document.createElement('span');
        verifyPill.className = `governance-pill ${isVerified ? 'verified' : 'unverified'}`;
        verifyPill.innerHTML = isVerified
            ? `<span>✓</span> <span>Verified (${daysRemaining}d)</span>`
            : `<span>🛡️</span> <span>Verify Note</span>`;
        verifyPill.title = isVerified
            ? `Verified by ${doc.verifiedBy || 'Author'} (${daysRemaining} days remaining). Click to renew (90 days).`
            : 'Click to mark as authoritative (90 days)';
        verifyPill.addEventListener('click', () => {
            if (isLocked) return;
            const newDays = isVerified ? 365 : 90;
            this.store.setDocumentVerification(doc.id, newDays, 'Author');
            this.renderBlocks();
        });
        pinnedBar.appendChild(verifyPill);

        // 2. Lock / Read-Only Pill
        const lockPill = document.createElement('span');
        lockPill.className = `governance-pill ${isLocked ? 'locked' : 'unlocked'}`;
        lockPill.innerHTML = isLocked
            ? `<span>🔒</span> <span>Locked (Read-Only)</span>`
            : `<span>🔓</span> <span>Lock Document</span>`;
        lockPill.title = isLocked ? 'Document is locked. Click to unlock.' : 'Click to lock against edits.';
        lockPill.addEventListener('click', () => {
            this.store.setDocumentLock(doc.id, !isLocked);
            this.renderBlocks();
        });
        pinnedBar.appendChild(lockPill);

        hub.appendChild(pinnedBar);

        // Read-Only Banner if Locked
        if (isLocked) {
            const lockBanner = document.createElement('div');
            lockBanner.className = 'editor-locked-banner';
            lockBanner.innerHTML = `
                <span>🔒 This document is locked against accidental modifications.</span>
                <span style="font-size: 11px; opacity: 0.85;">Read-Only Mode</span>
            `;
            hub.appendChild(lockBanner);
        }

        const metadata = document.createElement('div');
        metadata.className = 'doc-metadata-scrim';
        metadata.innerHTML = `
            <span>📄 ${this.store.blocks.length} blocks</span>
            <span>⏱️ ${Math.max(1, Math.round(this.store.blocks.length * 12 / 60))} min read</span>
            <span>🗂️ ${this.store.flashcards.filter(f => f.docId === doc.id).length} cards attached</span>
        `;
        hub.appendChild(metadata);

        measure.appendChild(hub);

        // Blocks List with Collapsible Hierarchy Support
        const blocksList = document.createElement('div');
        blocksList.className = 'blocks-list';

        // Calculate hidden blocks due to collapsed headings or toggles
        const hiddenBlockIds = new Set();
        let activeHeadingCollapseLevel = null;

        for (let idx = 0; idx < this.store.blocks.length; idx++) {
            const b = this.store.blocks[idx];

            // Check if within collapsed heading scope
            if (b.type === 'heading1' || b.type === 'heading2' || b.type === 'heading3') {
                const level = parseInt(b.type.replace('heading', ''), 10);
                if (activeHeadingCollapseLevel !== null) {
                    if (level <= activeHeadingCollapseLevel) {
                        activeHeadingCollapseLevel = null; // Exit collapse scope
                    }
                }
                if (b.isCollapsed) {
                    activeHeadingCollapseLevel = level;
                }
            } else if (activeHeadingCollapseLevel !== null) {
                hiddenBlockIds.add(b.id);
            }
        }

        for (let i = 0; i < this.store.blocks.length; i++) {
            const block = this.store.blocks[i];
            if (hiddenBlockIds.has(block.id)) {
                continue; // Skip hidden blocks
            }

            const row = document.createElement('div');
            row.className = 'block-row';
            row.dataset.id = block.id;
            row.dataset.type = block.type;
            if (block.isCompleted) row.classList.add('completed');

            // Drag handle (hidden if locked)
            if (!isLocked) {
                const handle = document.createElement('div');
                handle.className = 'block-handle';
                handle.innerHTML = '⋮⋮';
                row.appendChild(handle);
            }

            // Disclosure chevron for Toggle & Heading blocks
            const isCollapsible = block.type === 'toggle' || block.type === 'heading1' || block.type === 'heading2' || block.type === 'heading3';
            if (isCollapsible) {
                const chevron = document.createElement('div');
                chevron.className = `block-toggle-btn ${block.isCollapsed ? 'collapsed' : 'expanded'}`;
                chevron.innerHTML = block.isCollapsed ? '▶' : '▼';
                chevron.title = block.isCollapsed ? 'Expand section' : 'Collapse section';
                chevron.addEventListener('click', () => {
                    this.store.toggleBlockCollapsed(block.id);
                    this.renderBlocks();
                });
                row.appendChild(chevron);
            }

            // Task Checkbox if taskList
            if (block.type === 'taskList') {
                const cb = document.createElement('input');
                cb.type = 'checkbox';
                cb.className = 'task-checkbox';
                cb.checked = !!block.isCompleted;
                cb.disabled = isLocked;
                cb.addEventListener('change', () => {
                    this.store.toggleTask(block.id);
                    row.classList.toggle('completed', block.isCompleted);
                });
                row.appendChild(cb);
            }

            // Render Table Matrix Block
            if (block.type === 'table') {
                const tablePayload = this.parseTablePayload(block.content);
                const tableContainer = document.createElement('div');
                tableContainer.className = 'table-block-container';

                if (!isLocked) {
                    const tableToolbar = document.createElement('div');
                    tableToolbar.className = 'table-toolbar';
                    tableToolbar.innerHTML = `
                        <span>▦ ${tablePayload.rows.length} × ${tablePayload.rows[0]?.length || 0} Table</span>
                    `;

                    const actions = document.createElement('div');
                    actions.className = 'table-toolbar-actions';

                    const addRowBtn = document.createElement('button');
                    addRowBtn.className = 'table-btn';
                    addRowBtn.textContent = '+ Row';
                    addRowBtn.addEventListener('click', () => {
                        const colCount = tablePayload.rows[0]?.length || 3;
                        tablePayload.rows.push(new Array(colCount).fill(''));
                        this.store.updateBlockContent(block.id, JSON.stringify(tablePayload));
                        this.renderBlocks();
                    });
                    actions.appendChild(addRowBtn);

                    const addColBtn = document.createElement('button');
                    addColBtn.className = 'table-btn';
                    addColBtn.textContent = '+ Col';
                    addColBtn.addEventListener('click', () => {
                        for (const r of tablePayload.rows) {
                            r.push('');
                        }
                        this.store.updateBlockContent(block.id, JSON.stringify(tablePayload));
                        this.renderBlocks();
                    });
                    actions.appendChild(addColBtn);

                    if (tablePayload.rows.length > 1) {
                        const delRowBtn = document.createElement('button');
                        delRowBtn.className = 'table-btn';
                        delRowBtn.textContent = '- Row';
                        delRowBtn.addEventListener('click', () => {
                            tablePayload.rows.pop();
                            this.store.updateBlockContent(block.id, JSON.stringify(tablePayload));
                            this.renderBlocks();
                        });
                        actions.appendChild(delRowBtn);
                    }

                    if ((tablePayload.rows[0]?.length || 0) > 1) {
                        const delColBtn = document.createElement('button');
                        delColBtn.className = 'table-btn';
                        delColBtn.textContent = '- Col';
                        delColBtn.addEventListener('click', () => {
                            for (const r of tablePayload.rows) {
                                r.pop();
                            }
                            this.store.updateBlockContent(block.id, JSON.stringify(tablePayload));
                            this.renderBlocks();
                        });
                        actions.appendChild(delColBtn);
                    }

                    tableToolbar.appendChild(actions);
                    tableContainer.appendChild(tableToolbar);
                }

                // Table Grid Matrix
                const matrixWrapper = document.createElement('div');
                matrixWrapper.className = 'table-matrix-wrapper';

                const tableGrid = document.createElement('table');
                tableGrid.className = 'table-matrix-grid';

                for (let rIdx = 0; rIdx < tablePayload.rows.length; rIdx++) {
                    const tr = document.createElement('tr');
                    const rowData = tablePayload.rows[rIdx];

                    for (let cIdx = 0; cIdx < rowData.length; cIdx++) {
                        const isHeader = (rIdx === 0 && tablePayload.hasHeaderRow);
                        const cell = document.createElement(isHeader ? 'th' : 'td');
                        cell.className = `table-matrix-cell ${isHeader ? 'header-cell' : ''}`;
                        cell.contentEditable = isLocked ? 'false' : 'true';
                        cell.textContent = rowData[cIdx] || '';

                        if (!isLocked) {
                            cell.addEventListener('input', () => {
                                tablePayload.rows[rIdx][cIdx] = cell.textContent;
                                this.store.updateBlockContent(block.id, JSON.stringify(tablePayload));
                            });
                        }

                        tr.appendChild(cell);
                    }
                    tableGrid.appendChild(tr);
                }

                matrixWrapper.appendChild(tableGrid);
                tableContainer.appendChild(matrixWrapper);
                row.appendChild(tableContainer);
            } else {
                // Content Area for Standard / Toggle / Heading / Code blocks
                const content = document.createElement('div');
                content.className = 'block-content-area';
                content.contentEditable = isLocked ? 'false' : 'true';
                content.dataset.placeholder = block.type === 'toggle' ? 'Toggle heading...' : 'Type / for commands...';
                content.textContent = block.content || '';

                if (!isLocked) {
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
                }

                row.appendChild(content);
            }

            blocksList.appendChild(row);
        }

        measure.appendChild(blocksList);
        this.container.appendChild(measure);
    }
}

if (typeof module !== 'undefined') {
    module.exports = { BlockEditorEngine };
}
