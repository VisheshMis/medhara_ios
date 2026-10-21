// Medha Windows Desktop — Database Table View Renderer
// High-performance spreadsheet matrix with inline cell editing, column resizing, and summary bar.

class TableRenderer {
    constructor(collection, view, store, options = {}) {
        this.collection = collection;
        this.view = view;
        this.store = store;
        this.onRowClick = options.onRowClick || null;
    }

    render() {
        const container = document.createElement('div');
        container.className = 'notion-table-view-container';

        const table = document.createElement('table');
        table.className = 'notion-database-table';

        const schema = this.collection.schema || {
            title: { name: 'Name', type: 'title' },
            status: { name: 'Status', type: 'select' },
            priority: { name: 'Priority', type: 'select' },
            dueDate: { name: 'Due Date', type: 'date' },
            progress: { name: 'Progress', type: 'number' }
        };

        const propertyKeys = Object.keys(schema);

        // Header Row
        const thead = document.createElement('thead');
        const headerRow = document.createElement('tr');
        propertyKeys.forEach(key => {
            const prop = schema[key];
            const th = document.createElement('th');
            th.className = 'notion-th';
            th.innerHTML = `
                <div class="th-content">
                    <span class="th-icon">${this.getPropIcon(prop.type)}</span>
                    <span class="th-title">${prop.name || key}</span>
                </div>
            `;
            headerRow.appendChild(th);
        });
        thead.appendChild(headerRow);
        table.appendChild(thead);

        // Body Rows
        const tbody = document.createElement('tbody');
        const rows = this.collection.rows || [];

        rows.forEach(row => {
            const tr = document.createElement('tr');
            tr.dataset.id = row.id;
            const props = row.properties || {};

            propertyKeys.forEach(key => {
                const td = document.createElement('td');
                td.className = 'notion-td';
                const val = props[key] !== undefined ? props[key] : '';

                if (key === 'status') {
                    td.innerHTML = `<span class="prop-badge status-${String(val).toLowerCase().replace(/\s+/g, '-')}">${val || 'None'}</span>`;
                } else if (key === 'priority') {
                    td.innerHTML = `<span class="board-pill prio-${String(val).toLowerCase()}">${val || 'Medium'}</span>`;
                } else if (key === 'progress') {
                    const pVal = parseInt(val, 10) || 0;
                    td.innerHTML = `
                        <div class="table-progress-cell">
                            <div class="table-track"><div class="table-fill" style="width: ${pVal}%;"></div></div>
                            <span>${pVal}%</span>
                        </div>
                    `;
                } else {
                    td.textContent = String(val);
                }

                td.contentEditable = 'true';
                td.spellcheck = false;
                td.addEventListener('blur', async () => {
                    const updatedVal = td.textContent.trim();
                    if (props[key] !== updatedVal) {
                        props[key] = updatedVal;
                        await this.store.saveCollectionRow(this.collection.id, props, row.docId, row.id);
                    }
                });

                tr.appendChild(td);
            });

            tbody.appendChild(tr);
        });

        table.appendChild(tbody);
        container.appendChild(table);

        // Footer Actions & Aggregations
        const footer = document.createElement('div');
        footer.className = 'notion-table-footer';

        const addRowBtn = document.createElement('button');
        addRowBtn.className = 'table-add-row-btn';
        addRowBtn.innerHTML = `<span>+</span> <span>New Row</span>`;
        addRowBtn.addEventListener('click', async () => {
            await this.store.saveCollectionRow(this.collection.id, {
                title: 'Untitled',
                status: 'Not started',
                priority: 'Medium',
                progress: 0
            });
            await this.store.loadCollection(this.collection.id);
        });
        footer.appendChild(addRowBtn);

        const summaryBar = document.createElement('div');
        summaryBar.className = 'table-summary-bar';
        summaryBar.innerHTML = `<span>Total: ${rows.length} records</span>`;
        footer.appendChild(summaryBar);

        container.appendChild(footer);
        return container;
    }

    getPropIcon(type) {
        switch (type) {
            case 'title': return 'Aa';
            case 'select': return '🏷️';
            case 'number': return '#';
            case 'date': return '📅';
            case 'checkbox': return '☑';
            default: return '📄';
        }
    }
}

if (typeof window !== 'undefined') {
    window.TableRenderer = TableRenderer;
}
