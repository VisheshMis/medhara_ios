// Medha Windows Desktop — Database Board (Kanban) View Renderer
// Displays status columns, drag-and-drop card workflow, priority tags, and dynamic overdue counters.

class BoardRenderer {
    constructor(collection, view, store, options = {}) {
        this.collection = collection;
        this.view = view;
        this.store = store;
        this.onRowClick = options.onRowClick || null;
    }

    calculateOverdueDays(dateStr) {
        if (!dateStr) return null;
        const target = new Date(dateStr);
        if (isNaN(target.getTime())) return null;

        const now = new Date();
        const diffMs = now.getTime() - target.getTime();
        const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
        return diffDays;
    }

    render() {
        const container = document.createElement('div');
        container.className = 'notion-board-view-container';

        const columns = ['Not started', 'In-Progress', 'Completed'];
        const rows = this.collection.rows || [];

        // Group rows by status
        const grouped = {};
        columns.forEach(c => { grouped[c] = []; });

        rows.forEach(row => {
            const status = (row.properties && row.properties.status) || 'Not started';
            if (!grouped[status]) grouped[status] = [];
            grouped[status].push(row);
        });

        const boardGrid = document.createElement('div');
        boardGrid.className = 'notion-board-grid';

        Object.keys(grouped).forEach(colName => {
            const colItems = grouped[colName];
            const colEl = document.createElement('div');
            colEl.className = 'notion-board-column';
            colEl.dataset.status = colName;

            // Column Header
            const colHeader = document.createElement('div');
            colHeader.className = 'notion-board-col-header';
            const statusBadgeClass = `badge-${colName.toLowerCase().replace(/\s+/g, '-')}`;
            colHeader.innerHTML = `
                <div class="col-header-left">
                    <span class="status-dot ${statusBadgeClass}"></span>
                    <span class="col-title">${colName}</span>
                    <span class="col-count">${colItems.length}</span>
                </div>
                <button class="col-add-btn" title="Add item to ${colName}">+</button>
            `;

            const addBtn = colHeader.querySelector('.col-add-btn');
            addBtn.addEventListener('click', async () => {
                const title = prompt(`Add Task to ${colName}:`);
                if (title) {
                    await this.store.saveCollectionRow(this.collection.id, {
                        title: title.trim(),
                        status: colName,
                        priority: 'Medium',
                        estimate: '1 Hour'
                    });
                    await this.store.loadCollection(this.collection.id);
                }
            });

            colEl.appendChild(colHeader);

            // Column Cards Drop Zone
            const cardList = document.createElement('div');
            cardList.className = 'notion-board-card-list';

            // Drag and Drop support
            cardList.addEventListener('dragover', (e) => {
                e.preventDefault();
                colEl.classList.add('drag-over');
            });
            cardList.addEventListener('dragleave', () => {
                colEl.classList.remove('drag-over');
            });
            cardList.addEventListener('drop', async (e) => {
                e.preventDefault();
                colEl.classList.remove('drag-over');
                const rowId = e.dataTransfer.getData('text/plain');
                if (rowId) {
                    const row = rows.find(r => r.id === rowId);
                    if (row && row.properties.status !== colName) {
                        row.properties.status = colName;
                        await this.store.saveCollectionRow(this.collection.id, row.properties, row.docId, row.id);
                        await this.store.loadCollection(this.collection.id);
                    }
                }
            });

            colItems.forEach(row => {
                const card = document.createElement('div');
                card.className = 'notion-board-card';
                card.draggable = true;
                card.dataset.id = row.id;

                const props = row.properties || {};
                const title = props.title || props.name || 'Untitled';
                const priority = props.priority || null;
                const dueDate = props.dueDate || props.date || null;
                const estimate = props.estimate || '1 Hour';
                const overdueDays = this.calculateOverdueDays(dueDate);

                let tagsHtml = '';
                if (props.tag) {
                    tagsHtml += `<span class="board-pill tag-pill">${props.tag}</span>`;
                }
                if (priority) {
                    const prioClass = `prio-${priority.toLowerCase()}`;
                    tagsHtml += `<span class="board-pill ${prioClass}">${priority}</span>`;
                }
                if (estimate) {
                    tagsHtml += `<span class="board-pill time-pill">⏱️ ${estimate}</span>`;
                }
                if (dueDate) {
                    tagsHtml += `<span class="board-pill date-pill">📅 ${dueDate}</span>`;
                }
                if (overdueDays !== null && overdueDays > 0 && props.status !== 'Completed') {
                    tagsHtml += `<span class="board-pill overdue-pill">⚠️ ${overdueDays} days overdue</span>`;
                }

                card.innerHTML = `
                    <div class="board-card-title">${title}</div>
                    ${tagsHtml ? `<div class="board-card-tags">${tagsHtml}</div>` : ''}
                `;

                card.addEventListener('dragstart', (e) => {
                    e.dataTransfer.setData('text/plain', row.id);
                    card.classList.add('dragging');
                });
                card.addEventListener('dragend', () => {
                    card.classList.remove('dragging');
                });

                card.addEventListener('click', () => {
                    if (typeof this.onRowClick === 'function') {
                        this.onRowClick(row);
                    }
                });

                cardList.appendChild(card);
            });

            colEl.appendChild(cardList);
            boardGrid.appendChild(colEl);
        });

        container.appendChild(boardGrid);
        return container;
    }
}

if (typeof window !== 'undefined') {
    window.BoardRenderer = BoardRenderer;
}
