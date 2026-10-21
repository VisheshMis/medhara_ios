// Medha Windows Desktop — Database Gallery View Renderer
// Displays collection cards with cover previews, property tags, and progress bars.

class GalleryRenderer {
    constructor(collection, view, store, options = {}) {
        this.collection = collection;
        this.view = view;
        this.store = store;
        this.onRowClick = options.onRowClick || null;
    }

    render() {
        const container = document.createElement('div');
        container.className = 'notion-gallery-view-container';

        const cardSize = (this.view.format && this.view.format.cardSize) || 'medium';
        const cardGrid = document.createElement('div');
        cardGrid.className = `notion-gallery-grid size-${cardSize}`;

        const rows = this.collection.rows || [];

        rows.forEach(row => {
            const card = document.createElement('div');
            card.className = 'notion-gallery-card';
            card.dataset.id = row.id;

            const props = row.properties || {};
            const title = props.title || props.name || 'Untitled';
            const coverUrl = props.cover || props.image || null;
            const status = props.status || null;
            const progress = props.progress !== undefined ? parseInt(props.progress, 10) : null;
            const category = props.category || props.subject || null;

            // 1. Cover Image (if present)
            let coverHtml = '';
            if (coverUrl) {
                coverHtml = `
                    <div class="gallery-card-cover">
                        <img src="${coverUrl}" alt="${title}" loading="lazy" />
                    </div>
                `;
            } else {
                coverHtml = `
                    <div class="gallery-card-cover placeholder-cover">
                        <span class="cover-icon">🌿</span>
                    </div>
                `;
            }

            // 2. Card Content
            let badgesHtml = '';
            if (category) {
                badgesHtml += `<span class="prop-badge category-badge">${category}</span>`;
            }
            if (status) {
                const statusClass = status.toLowerCase().replace(/\s+/g, '-');
                badgesHtml += `<span class="prop-badge status-${statusClass}">${status}</span>`;
            }

            // 3. Progress Bar (if present)
            let progressHtml = '';
            if (progress !== null && !isNaN(progress)) {
                progressHtml = `
                    <div class="gallery-progress-bar-wrap" title="${progress}% complete">
                        <div class="gallery-progress-track">
                            <div class="gallery-progress-fill" style="width: ${Math.min(100, Math.max(0, progress))}%;"></div>
                        </div>
                        <span class="gallery-progress-pct">${progress}%</span>
                    </div>
                `;
            }

            card.innerHTML = `
                ${coverHtml}
                <div class="gallery-card-body">
                    <div class="gallery-card-title">${title}</div>
                    ${badgesHtml ? `<div class="gallery-card-badges">${badgesHtml}</div>` : ''}
                    ${progressHtml}
                </div>
            `;

            card.addEventListener('click', () => {
                if (typeof this.onRowClick === 'function') {
                    this.onRowClick(row);
                } else if (row.docId) {
                    this.store.selectDocument(row.docId);
                }
            });

            cardGrid.appendChild(card);
        });

        // "+ New card" button
        const newCardBtn = document.createElement('div');
        newCardBtn.className = 'notion-gallery-card add-card-btn';
        newCardBtn.innerHTML = `
            <div class="add-card-content">
                <span class="add-card-plus">+</span>
                <span>New</span>
            </div>
        `;
        newCardBtn.addEventListener('click', async () => {
            const title = prompt('Card Title:', 'New Subject');
            if (title) {
                await this.store.saveCollectionRow(this.collection.id, {
                    title: title.trim(),
                    status: 'In-Progress',
                    progress: 25
                });
                await this.store.loadCollection(this.collection.id);
            }
        });
        cardGrid.appendChild(newCardBtn);

        container.appendChild(cardGrid);
        return container;
    }
}

if (typeof window !== 'undefined') {
    window.GalleryRenderer = GalleryRenderer;
}
