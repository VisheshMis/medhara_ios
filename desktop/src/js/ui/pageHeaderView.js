// Medha Windows Desktop — Notion-Grade Page Header Component
// Features: Repositionable Cover Banner (PNG/JPEG/GIF), Floating Multi-Source Icon Badge,
// Typography switcher (Sans/Serif/Mono), Small-Text & Full-Width layout toggles.

class PageHeaderView {
    constructor(containerElement, store) {
        this.container = containerElement;
        this.store = store;
        this.docId = null;
        this.metadata = null;
        this.isRepositioning = false;
        this.dragStartY = 0;
        this.initialCoverY = 0.5;

        this.init();
    }

    init() {
        if (!this.container) return;

        this.store.subscribe((event, payload) => {
            if (event === 'doc_selected' && payload) {
                this.docId = payload.docId;
                this.render();
            } else if (event === 'metadata_loaded' || event === 'metadata_updated') {
                if (payload && payload.id === this.docId) {
                    this.metadata = payload;
                    this.applyMetadataToDOM();
                }
            }
        });
    }

    async render() {
        if (!this.docId) return;

        this.metadata = await this.store.loadPageMetadata(this.docId);
        const doc = this.store.documents.find(d => d.id === this.docId);
        const title = doc ? doc.content : 'Untitled';

        this.container.innerHTML = `
            <div class="notion-page-header-wrapper" id="notion-header-root">
                <!-- Cover Banner Area -->
                <div class="notion-cover-container ${this.metadata && this.metadata.coverUrl ? 'has-cover' : 'empty-cover'}" id="notion-cover-box">
                    <img class="notion-cover-img" id="notion-cover-img" 
                         src="${(this.metadata && this.metadata.coverUrl) || ''}" 
                         style="--cover-y: ${(this.metadata && this.metadata.coverY) !== undefined ? this.metadata.coverY : 0.5};" 
                         alt="Page cover" />
                    
                    <!-- Cover Actions Hover Toolbar -->
                    <div class="notion-cover-actions" id="notion-cover-actions">
                        <button class="notion-pill-btn" id="btn-change-cover">🖼️ Change cover</button>
                        <button class="notion-pill-btn" id="btn-reposition-cover">↕️ Reposition</button>
                        <button class="notion-pill-btn" id="btn-remove-cover">🗑️ Remove</button>
                    </div>

                    <!-- Reposition Drag Overlay -->
                    <div class="notion-reposition-bar" id="notion-reposition-bar" style="display: none;">
                        <span>Drag image up or down to reposition</span>
                        <div class="reposition-btn-group">
                            <button class="notion-btn-accent" id="btn-save-reposition">Save position</button>
                            <button class="notion-btn-secondary" id="btn-cancel-reposition">Cancel</button>
                        </div>
                    </div>
                </div>

                <!-- Page Meta Toolbar & Action Trigger (Add Cover/Icon when missing) -->
                <div class="notion-page-meta-bar">
                    <div class="notion-quick-add-strip">
                        ${!(this.metadata && this.metadata.coverUrl) ? '<button class="notion-text-btn" id="btn-add-cover">🖼️ Add cover</button>' : ''}
                        ${!(this.metadata && this.metadata.iconValue) ? '<button class="notion-text-btn" id="btn-add-icon">✨ Add icon</button>' : ''}
                    </div>

                    <!-- Page Formatting & Typography Controls -->
                    <div class="notion-page-settings-menu">
                        <select id="select-font-family" class="notion-select-pill" title="Font Style">
                            <option value="default" ${(this.metadata && this.metadata.fontFamily === 'default') ? 'selected' : ''}>Sans-Serif (Default)</option>
                            <option value="serif" ${(this.metadata && this.metadata.fontFamily === 'serif') ? 'selected' : ''}>Serif (Literary)</option>
                            <option value="mono" ${(this.metadata && this.metadata.fontFamily === 'mono') ? 'selected' : ''}>Mono (Typewriter)</option>
                        </select>
                        <button id="btn-toggle-small-text" class="notion-icon-pill ${(this.metadata && this.metadata.isSmallText) ? 'active' : ''}" title="Small Text">
                            <span style="font-size: 11px; font-weight: bold;">A</span>
                        </button>
                        <button id="btn-toggle-full-width" class="notion-icon-pill ${(this.metadata && this.metadata.isFullWidth) ? 'active' : ''}" title="Full Width">
                            <span>↔️</span>
                        </button>
                    </div>
                </div>

                <!-- Floating Icon & Title Anchor -->
                <div class="notion-identity-container">
                    <div class="notion-icon-badge ${(this.metadata && this.metadata.coverUrl) ? 'overlap-cover' : 'inline-icon'}" id="notion-icon-badge" title="Click to change icon">
                        <span class="icon-glyph" id="notion-icon-glyph">${(this.metadata && this.metadata.iconValue) || '📄'}</span>
                    </div>

                    <div class="notion-title-row">
                        <h1 class="notion-page-title" id="notion-page-title" contenteditable="true" spellcheck="false" placeholder="Untitled">${title}</h1>
                    </div>
                </div>
            </div>
        `;

        this.bindDOMEvents();
        this.applyMetadataToDOM();
    }

    bindDOMEvents() {
        // Change Cover Button
        const btnChangeCover = this.container.querySelector('#btn-change-cover');
        const btnAddCover = this.container.querySelector('#btn-add-cover');
        const openCoverPicker = () => {
            const picker = new AssetPickerModal({
                mode: 'cover',
                onSelect: async (assetUrl) => {
                    this.metadata.coverUrl = assetUrl;
                    await this.store.savePageMetadata(this.metadata);
                    this.render();
                }
            });
            picker.open();
        };

        if (btnChangeCover) btnChangeCover.addEventListener('click', openCoverPicker);
        if (btnAddCover) btnAddCover.addEventListener('click', openCoverPicker);

        // Remove Cover
        const btnRemoveCover = this.container.querySelector('#btn-remove-cover');
        if (btnRemoveCover) {
            btnRemoveCover.addEventListener('click', async () => {
                this.metadata.coverUrl = null;
                await this.store.savePageMetadata(this.metadata);
                this.render();
            });
        }

        // Reposition Cover
        const btnReposition = this.container.querySelector('#btn-reposition-cover');
        const coverBox = this.container.querySelector('#notion-cover-box');
        const coverImg = this.container.querySelector('#notion-cover-img');
        const repositionBar = this.container.querySelector('#notion-reposition-bar');
        const btnSaveRepo = this.container.querySelector('#btn-save-reposition');
        const btnCancelRepo = this.container.querySelector('#btn-cancel-reposition');

        if (btnReposition) {
            btnReposition.addEventListener('click', () => {
                this.isRepositioning = true;
                coverBox.classList.add('repositioning');
                repositionBar.style.display = 'flex';
                this.initialCoverY = this.metadata.coverY !== undefined ? this.metadata.coverY : 0.5;
            });
        }

        let isDragging = false;
        if (coverBox) {
            coverBox.addEventListener('mousedown', (e) => {
                if (!this.isRepositioning) return;
                isDragging = true;
                this.dragStartY = e.clientY;
                e.preventDefault();
            });

            window.addEventListener('mousemove', (e) => {
                if (!this.isRepositioning || !isDragging) return;
                const deltaY = e.clientY - this.dragStartY;
                const deltaNormalized = -deltaY / 200; // 200px drag scale
                let newY = Math.max(0, Math.min(1, this.initialCoverY + deltaNormalized));
                coverImg.style.setProperty('--cover-y', newY);
            });

            window.addEventListener('mouseup', () => {
                if (isDragging) {
                    isDragging = false;
                    const computedY = parseFloat(coverImg.style.getPropertyValue('--cover-y')) || 0.5;
                    this.initialCoverY = computedY;
                }
            });
        }

        if (btnSaveRepo) {
            btnSaveRepo.addEventListener('click', async () => {
                this.isRepositioning = false;
                coverBox.classList.remove('repositioning');
                repositionBar.style.display = 'none';
                const finalY = parseFloat(coverImg.style.getPropertyValue('--cover-y')) || 0.5;
                this.metadata.coverY = finalY;
                await this.store.savePageMetadata(this.metadata);
            });
        }

        if (btnCancelRepo) {
            btnCancelRepo.addEventListener('click', () => {
                this.isRepositioning = false;
                coverBox.classList.remove('repositioning');
                repositionBar.style.display = 'none';
                coverImg.style.setProperty('--cover-y', this.metadata.coverY || 0.5);
            });
        }

        // Icon Badge Click -> Change Icon
        const iconBadge = this.container.querySelector('#notion-icon-badge');
        const btnAddIcon = this.container.querySelector('#btn-add-icon');
        const openIconPicker = () => {
            const emojis = ['📄', '🌿', '🐉', '⚔️', '✨', '📚', '☕', '🌌', '💡', '🧪', '🏹', '🏰', '🕰️', '🎨', '🧠'];
            const randomEmoji = emojis[Math.floor(Math.random() * emojis.length)];
            const chosen = prompt('Enter an emoji or icon character:', this.metadata.iconValue || randomEmoji);
            if (chosen) {
                this.metadata.iconValue = chosen.trim();
                this.metadata.iconType = 'emoji';
                this.store.savePageMetadata(this.metadata);
                this.render();
            }
        };

        if (iconBadge) iconBadge.addEventListener('click', openIconPicker);
        if (btnAddIcon) btnAddIcon.addEventListener('click', openIconPicker);

        // Page Title Sync
        const titleEl = this.container.querySelector('#notion-page-title');
        if (titleEl) {
            titleEl.addEventListener('blur', () => {
                const newTitle = titleEl.innerText.trim() || 'Untitled';
                const doc = this.store.documents.find(d => d.id === this.docId);
                if (doc && doc.content !== newTitle) {
                    doc.content = newTitle;
                    this.store.execute('UPDATE block SET content = ? WHERE id = ?', [newTitle, this.docId]);
                    this.store.notify('doc_renamed', { docId: this.docId, title: newTitle });
                }
            });
        }

        // Page Settings & Typography
        const fontSelect = this.container.querySelector('#select-font-family');
        if (fontSelect) {
            fontSelect.addEventListener('change', async (e) => {
                this.metadata.fontFamily = e.target.value;
                await this.store.savePageMetadata(this.metadata);
                this.applyMetadataToDOM();
            });
        }

        const btnSmallText = this.container.querySelector('#btn-toggle-small-text');
        if (btnSmallText) {
            btnSmallText.addEventListener('click', async () => {
                this.metadata.isSmallText = this.metadata.isSmallText ? 0 : 1;
                await this.store.savePageMetadata(this.metadata);
                btnSmallText.classList.toggle('active', !!this.metadata.isSmallText);
                this.applyMetadataToDOM();
            });
        }

        const btnFullWidth = this.container.querySelector('#btn-toggle-full-width');
        if (btnFullWidth) {
            btnFullWidth.addEventListener('click', async () => {
                this.metadata.isFullWidth = this.metadata.isFullWidth ? 0 : 1;
                await this.store.savePageMetadata(this.metadata);
                btnFullWidth.classList.toggle('active', !!this.metadata.isFullWidth);
                this.applyMetadataToDOM();
            });
        }
    }

    applyMetadataToDOM() {
        if (!this.metadata) return;

        const editorRoot = document.querySelector('.editor-scroll-container') || document.querySelector('#editor-view');
        if (!editorRoot) return;

        // Apply Font Family
        editorRoot.classList.remove('font-default', 'font-serif', 'font-mono');
        editorRoot.classList.add(`font-${this.metadata.fontFamily || 'default'}`);

        // Apply Small Text
        if (this.metadata.isSmallText) {
            editorRoot.classList.add('notion-small-text');
        } else {
            editorRoot.classList.remove('notion-small-text');
        }

        // Apply Full Width
        if (this.metadata.isFullWidth) {
            editorRoot.classList.add('notion-full-width');
        } else {
            editorRoot.classList.remove('notion-full-width');
        }
    }
}

if (typeof window !== 'undefined') {
    window.PageHeaderView = PageHeaderView;
}
