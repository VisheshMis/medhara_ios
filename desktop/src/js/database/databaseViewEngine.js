// Medha Windows Desktop — Unified Database View Engine
// Manages multi-view switching (Gallery, Board, Calendar, Table) for collections.

class DatabaseViewEngine {
    constructor(collectionId, store, options = {}) {
        this.collectionId = collectionId;
        this.store = store;
        this.activeViewType = options.initialView || 'gallery'; // 'gallery', 'board', 'calendar', 'table'
        this.container = options.container || null;
        this.collection = null;

        this.init();
    }

    async init() {
        this.collection = await this.store.loadCollection(this.collectionId);
        if (!this.collection) {
            // Seed default aesthetic student collection if new
            await this.seedDefaultCollection();
            this.collection = await this.store.loadCollection(this.collectionId);
        }

        if (this.container) {
            this.render();
        }

        this.store.subscribe((event, payload) => {
            if (event === 'collection_loaded' && payload && payload.id === this.collectionId) {
                this.collection = payload;
                if (this.container) this.render();
            }
        });
    }

    async seedDefaultCollection() {
        const schema = {
            title: { name: 'Name', type: 'title' },
            status: { name: 'Status', type: 'select' },
            priority: { name: 'Priority', type: 'select' },
            dueDate: { name: 'Due Date', type: 'date' },
            estimate: { name: 'Estimate', type: 'text' },
            progress: { name: 'Progress', type: 'number' },
            cover: { name: 'Cover', type: 'file' }
        };

        await this.store.saveCollection(this.collectionId, 'Academic Hub', schema);

        // Seed 3 initial cards matching reference
        await this.store.saveCollectionRow(this.collectionId, {
            title: 'Math: Differential Equations',
            status: 'In-Progress',
            priority: 'High',
            dueDate: '2024-01-14',
            estimate: '1 Hour',
            progress: 65,
            cover: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=600&q=80'
        });

        await this.store.saveCollectionRow(this.collectionId, {
            title: 'Physics: Classical Mechanics',
            status: 'In-Progress',
            priority: 'Medium',
            dueDate: '2024-01-21',
            estimate: '1 Hour',
            progress: 40,
            cover: 'https://images.unsplash.com/photo-1448375240586-882707db888b?w=600&q=80'
        });

        await this.store.saveCollectionRow(this.collectionId, {
            title: 'Biology: Cell Structure & DNA',
            status: 'Not started',
            priority: 'Low',
            dueDate: '2024-02-02',
            estimate: '1 Hour',
            progress: 15,
            cover: 'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=600&q=80'
        });

        // Seed default views
        await this.store.saveCollectionView(`view-gallery-${this.collectionId}`, this.collectionId, 'Gallery', 'gallery', {}, [], { cardSize: 'medium' });
        await this.store.saveCollectionView(`view-board-${this.collectionId}`, this.collectionId, 'Board', 'board');
        await this.store.saveCollectionView(`view-calendar-${this.collectionId}`, this.collectionId, 'Calendar', 'calendar');
        await this.store.saveCollectionView(`view-table-${this.collectionId}`, this.collectionId, 'Table', 'table');
    }

    render() {
        if (!this.container || !this.collection) return;
        this.container.innerHTML = '';

        const wrapper = document.createElement('div');
        wrapper.className = 'notion-database-block-wrapper';

        // 1. Database Header & View Tabs
        const header = document.createElement('div');
        header.className = 'notion-database-header';
        header.innerHTML = `
            <div class="db-title-row">
                <span class="db-title-icon">📚</span>
                <span class="db-title-text">${this.collection.name || 'Database'}</span>
            </div>
            <div class="db-views-tabs">
                <button class="db-view-tab ${this.activeViewType === 'gallery' ? 'active' : ''}" data-view="gallery">🖼️ Gallery</button>
                <button class="db-view-tab ${this.activeViewType === 'board' ? 'active' : ''}" data-view="board">📋 Board</button>
                <button class="db-view-tab ${this.activeViewType === 'calendar' ? 'active' : ''}" data-view="calendar">📅 Calendar</button>
                <button class="db-view-tab ${this.activeViewType === 'table' ? 'active' : ''}" data-view="table">▦ Table</button>
            </div>
        `;

        header.querySelectorAll('.db-view-tab').forEach(tab => {
            tab.addEventListener('click', () => {
                this.activeViewType = tab.getAttribute('data-view');
                this.render();
            });
        });

        wrapper.appendChild(header);

        // 2. Active View Renderer
        const viewBody = document.createElement('div');
        viewBody.className = 'notion-database-view-body';

        const activeViewSpec = (this.collection.views || []).find(v => v.type === this.activeViewType) || {
            type: this.activeViewType,
            format: { cardSize: 'medium' }
        };

        let viewRenderer = null;
        if (this.activeViewType === 'gallery') {
            viewRenderer = new GalleryRenderer(this.collection, activeViewSpec, this.store);
        } else if (this.activeViewType === 'board') {
            viewRenderer = new BoardRenderer(this.collection, activeViewSpec, this.store);
        } else if (this.activeViewType === 'calendar') {
            viewRenderer = new CalendarRenderer(this.collection, activeViewSpec, this.store);
        } else if (this.activeViewType === 'table') {
            viewRenderer = new TableRenderer(this.collection, activeViewSpec, this.store);
        }

        if (viewRenderer) {
            viewBody.appendChild(viewRenderer.render());
        }

        wrapper.appendChild(viewBody);
        this.container.appendChild(wrapper);
    }
}

if (typeof window !== 'undefined') {
    window.DatabaseViewEngine = DatabaseViewEngine;
}
