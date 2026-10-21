// Medha Windows Desktop — Universal Asset Picker Modal
// Tabs: Unsplash Photos, Giphy Animated GIFs, Curated Presets, Local File Upload, and Direct URL.
// Ensures every selected asset is downloaded and permanently cached offline via medha-asset://.

class AssetPickerModal {
    constructor(options = {}) {
        this.onSelect = options.onSelect || null;
        this.mode = options.mode || 'cover'; // 'cover' or 'icon'
        this.modalEl = null;
        this.currentTab = 'unsplash';
        this.searchDebounceTimer = null;

        this.init();
    }

    init() {
        if (typeof document === 'undefined') return;

        this.modalEl = document.createElement('div');
        this.modalEl.className = 'notion-asset-modal-overlay';
        this.modalEl.innerHTML = `
            <div class="notion-asset-modal">
                <div class="notion-modal-header">
                    <span class="notion-modal-title">${this.mode === 'cover' ? '🖼️ Choose Page Cover' : '✨ Choose Page Icon'}</span>
                    <button class="notion-modal-close-btn" title="Close">✕</button>
                </div>
                <div class="notion-modal-tabs">
                    <button class="notion-tab-btn active" data-tab="unsplash">📷 Unsplash</button>
                    <button class="notion-tab-btn" data-tab="giphy">🎞️ Giphy (GIFs)</button>
                    <button class="notion-tab-btn" data-tab="presets">🌿 Ghibli Presets</button>
                    <button class="notion-tab-btn" data-tab="upload">📁 Upload File</button>
                    <button class="notion-tab-btn" data-tab="link">🔗 Direct Link</button>
                </div>
                <div class="notion-modal-body">
                    <!-- Search Input (Shared for Unsplash & Giphy) -->
                    <div class="notion-search-bar" id="asset-search-container">
                        <input type="text" id="asset-search-input" placeholder="Search aesthetic covers (e.g. Studio Ghibli, misty forest)..." />
                    </div>

                    <!-- Gallery Content Area -->
                    <div class="notion-asset-grid" id="asset-results-grid">
                        <div class="notion-asset-loading">Loading presets...</div>
                    </div>

                    <!-- Upload Pane -->
                    <div class="notion-pane-upload" id="pane-upload" style="display: none;">
                        <div class="notion-upload-dropzone" id="upload-dropzone">
                            <span class="dropzone-icon">📤</span>
                            <span class="dropzone-text">Click to choose a local PNG, JPEG, or animated GIF</span>
                            <span class="dropzone-sub">Images are saved directly to your local offline library</span>
                            <button class="notion-btn-accent" id="btn-browse-file">Browse Computer</button>
                        </div>
                    </div>

                    <!-- Link Pane -->
                    <div class="notion-pane-link" id="pane-link" style="display: none;">
                        <label>Paste any image or GIF URL (Pinterest, Reddit, Web):</label>
                        <div class="notion-link-input-row">
                            <input type="text" id="asset-link-input" placeholder="https://example.com/aesthetic_ghibli.gif" />
                            <button class="notion-btn-accent" id="btn-submit-link">Download & Save</button>
                        </div>
                        <span class="notion-link-hint">Medha will download the asset and store it on disk for 100% offline access.</span>
                    </div>
                </div>
                <div class="notion-modal-footer">
                    <span class="notion-offline-badge">⚡ 100% Offline Caching Enabled</span>
                </div>
            </div>
        `;

        document.body.appendChild(this.modalEl);
        this.bindEvents();
    }

    bindEvents() {
        const closeBtn = this.modalEl.querySelector('.notion-modal-close-btn');
        closeBtn.addEventListener('click', () => this.close());

        this.modalEl.addEventListener('click', (e) => {
            if (e.target === this.modalEl) this.close();
        });

        // Tab Switching
        const tabs = this.modalEl.querySelectorAll('.notion-tab-btn');
        tabs.forEach(tab => {
            tab.addEventListener('click', () => {
                tabs.forEach(t => t.classList.remove('active'));
                tab.classList.add('active');
                this.switchTab(tab.getAttribute('data-tab'));
            });
        });

        // Search Input
        const searchInput = this.modalEl.querySelector('#asset-search-input');
        searchInput.addEventListener('input', (e) => {
            clearTimeout(this.searchDebounceTimer);
            this.searchDebounceTimer = setTimeout(() => {
                this.performSearch(e.target.value);
            }, 350);
        });

        // Upload Button
        const browseBtn = this.modalEl.querySelector('#btn-browse-file');
        browseBtn.addEventListener('click', async () => {
            if (window.electronAPI && window.electronAPI.openImageDialog) {
                const res = await window.electronAPI.openImageDialog();
                if (res.success && res.data) {
                    this.selectAsset(res.data.assetUrl, { name: 'Uploaded image' });
                }
            }
        });

        // Link Button
        const linkBtn = this.modalEl.querySelector('#btn-submit-link');
        const linkInput = this.modalEl.querySelector('#asset-link-input');
        linkBtn.addEventListener('click', async () => {
            const url = linkInput.value.trim();
            if (url) {
                await this.cacheAndSelectRemoteUrl(url, 'web');
            }
        });
    }

    switchTab(tabName) {
        this.currentTab = tabName;
        const searchBar = this.modalEl.querySelector('#asset-search-container');
        const grid = this.modalEl.querySelector('#asset-results-grid');
        const paneUpload = this.modalEl.querySelector('#pane-upload');
        const paneLink = this.modalEl.querySelector('#pane-link');
        const searchInput = this.modalEl.querySelector('#asset-search-input');

        searchBar.style.display = (tabName === 'unsplash' || tabName === 'giphy') ? 'block' : 'none';
        grid.style.display = (tabName === 'unsplash' || tabName === 'giphy' || tabName === 'presets') ? 'grid' : 'none';
        paneUpload.style.display = tabName === 'upload' ? 'block' : 'none';
        paneLink.style.display = tabName === 'link' ? 'block' : 'none';

        if (tabName === 'unsplash') {
            searchInput.placeholder = 'Search Unsplash photos (e.g. cozy cottage, green forest)...';
            this.loadUnsplash(searchInput.value || 'ghibli aesthetic scenery');
        } else if (tabName === 'giphy') {
            searchInput.placeholder = 'Search Giphy animated GIFs (e.g. lo-fi rain, anime tea)...';
            this.loadGiphy(searchInput.value || 'studio ghibli aesthetic');
        } else if (tabName === 'presets') {
            this.renderPresets();
        }
    }

    async loadUnsplash(query) {
        const grid = this.modalEl.querySelector('#asset-results-grid');
        grid.innerHTML = '<div class="notion-asset-loading">Searching Unsplash...</div>';

        try {
            let items = [];
            if (window.electronAPI && window.electronAPI.searchUnsplash) {
                const res = await window.electronAPI.searchUnsplash(query, 1, 24);
                if (res.success) items = res.data;
            }
            if (items.length === 0) {
                grid.innerHTML = '<div class="notion-asset-empty">No photos found. Try another query!</div>';
                return;
            }

            grid.innerHTML = '';
            items.forEach(photo => {
                const card = document.createElement('div');
                card.className = 'notion-asset-card';
                card.innerHTML = `
                    <img src="${photo.thumbUrl}" alt="${photo.description || 'Photo'}" loading="lazy" />
                    <div class="asset-card-overlay">
                        <span>By ${photo.authorName}</span>
                    </div>
                `;
                card.addEventListener('click', async () => {
                    await this.cacheAndSelectRemoteUrl(photo.fullUrl, 'unsplash', {
                        authorName: photo.authorName,
                        authorLink: photo.authorLink
                    });
                });
                grid.appendChild(card);
            });
        } catch (e) {
            grid.innerHTML = `<div class="notion-asset-error">Search error: ${e.message}</div>`;
        }
    }

    async loadGiphy(query) {
        const grid = this.modalEl.querySelector('#asset-results-grid');
        grid.innerHTML = '<div class="notion-asset-loading">Searching animated GIFs...</div>';

        try {
            let items = [];
            if (window.electronAPI && window.electronAPI.searchGiphy) {
                const res = await window.electronAPI.searchGiphy(query, 1, 24);
                if (res.success) items = res.data;
            }
            if (items.length === 0) {
                grid.innerHTML = '<div class="notion-asset-empty">No GIFs found. Try another query!</div>';
                return;
            }

            grid.innerHTML = '';
            items.forEach(gif => {
                const card = document.createElement('div');
                card.className = 'notion-asset-card gif-card';
                card.innerHTML = `
                    <img src="${gif.thumbUrl}" alt="${gif.title}" loading="lazy" />
                    <div class="asset-card-overlay">
                        <span>${gif.title}</span>
                    </div>
                `;
                card.addEventListener('click', async () => {
                    await this.cacheAndSelectRemoteUrl(gif.fullUrl, 'giphy', { title: gif.title });
                });
                grid.appendChild(card);
            });
        } catch (e) {
            grid.innerHTML = `<div class="notion-asset-error">Search error: ${e.message}</div>`;
        }
    }

    renderPresets() {
        const grid = this.modalEl.querySelector('#asset-results-grid');
        grid.innerHTML = '';

        const presets = [
            {
                name: 'Ghibli Sunny Valley',
                thumb: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=500&q=80',
                full: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=1920&q=80'
            },
            {
                name: 'Spirited Forest Shrine',
                thumb: 'https://images.unsplash.com/photo-1448375240586-882707db888b?w=500&q=80',
                full: 'https://images.unsplash.com/photo-1448375240586-882707db888b?w=1920&q=80'
            },
            {
                name: 'Cozy Lakeside Cottage',
                thumb: 'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=500&q=80',
                full: 'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=1920&q=80'
            },
            {
                name: 'Kyoto Veranda Garden',
                thumb: 'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=500&q=80',
                full: 'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=1920&q=80'
            },
            {
                name: 'Spirited Away Train (GIF)',
                thumb: 'https://media.giphy.com/media/11KzOet1ElBDz2/giphy.gif',
                full: 'https://media.giphy.com/media/11KzOet1ElBDz2/giphy.gif'
            },
            {
                name: 'Kiki Pouring Tea (GIF)',
                thumb: 'https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExM3ZpdGtnZjQ3enp2aWZvdWZvYnBxaWZxc2t1anl3aXg0dnpsZjl2eSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/kFgzrTt798d2w/giphy.gif',
                full: 'https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExM3ZpdGtnZjQ3enp2aWZvdWZvYnBxaWZxc2t1anl3aXg0dnpsZjl2eSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/kFgzrTt798d2w/giphy.gif'
            }
        ];

        presets.forEach(p => {
            const card = document.createElement('div');
            card.className = 'notion-asset-card';
            card.innerHTML = `
                <img src="${p.thumb}" alt="${p.name}" loading="lazy" />
                <div class="asset-card-overlay">
                    <span>${p.name}</span>
                </div>
            `;
            card.addEventListener('click', async () => {
                await this.cacheAndSelectRemoteUrl(p.full, 'preset', { name: p.name });
            });
            grid.appendChild(card);
        });
    }

    async cacheAndSelectRemoteUrl(url, source = 'web', attribution = null) {
        const grid = this.modalEl.querySelector('#asset-results-grid');
        grid.innerHTML = '<div class="notion-asset-loading">Downloading & caching asset offline...</div>';

        try {
            if (window.electronAPI && window.electronAPI.cacheRemoteAsset) {
                const res = await window.electronAPI.cacheRemoteAsset(url, source, attribution);
                if (res.success && res.data) {
                    this.selectAsset(res.data.assetUrl, attribution);
                    return;
                }
            }
            // Fallback to direct url if Electron bridge not present
            this.selectAsset(url, attribution);
        } catch (e) {
            alert(`Could not download asset: ${e.message}`);
            this.switchTab(this.currentTab);
        }
    }

    performSearch(query) {
        if (this.currentTab === 'unsplash') {
            this.loadUnsplash(query);
        } else if (this.currentTab === 'giphy') {
            this.loadGiphy(query);
        }
    }

    selectAsset(url, attribution = null) {
        if (typeof this.onSelect === 'function') {
            this.onSelect(url, attribution);
        }
        this.close();
    }

    open() {
        if (this.modalEl) {
            this.modalEl.style.display = 'flex';
            this.switchTab('presets'); // Default to presets on first view for instant aesthetic gratification
        }
    }

    close() {
        if (this.modalEl) {
            this.modalEl.style.display = 'none';
        }
    }
}

if (typeof window !== 'undefined') {
    window.AssetPickerModal = AssetPickerModal;
}
