// Medha Windows Desktop — Database Calendar View Renderer
// Displays full monthly/weekly calendar grid, plots scheduled cards, and supports date navigation.

class CalendarRenderer {
    constructor(collection, view, store, options = {}) {
        this.collection = collection;
        this.view = view;
        this.store = store;
        this.currentDate = new Date();
        this.onRowClick = options.onRowClick || null;
    }

    render() {
        const container = document.createElement('div');
        container.className = 'notion-calendar-view-container';

        const year = this.currentDate.getFullYear();
        const month = this.currentDate.getMonth();
        const monthNames = [
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'
        ];

        // 1. Navigation Header
        const header = document.createElement('div');
        header.className = 'notion-calendar-header';
        header.innerHTML = `
            <div class="calendar-title-group">
                <span class="calendar-month-title">${monthNames[month]} ${year}</span>
            </div>
            <div class="calendar-nav-controls">
                <button class="cal-nav-btn" id="cal-prev" title="Previous Month">‹</button>
                <button class="cal-today-btn" id="cal-today">Today</button>
                <button class="cal-nav-btn" id="cal-next" title="Next Month">›</button>
            </div>
        `;

        header.querySelector('#cal-prev').addEventListener('click', () => {
            this.currentDate.setMonth(this.currentDate.getMonth() - 1);
            this.store.notify('collection_loaded', this.collection);
        });

        header.querySelector('#cal-next').addEventListener('click', () => {
            this.currentDate.setMonth(this.currentDate.getMonth() + 1);
            this.store.notify('collection_loaded', this.collection);
        });

        header.querySelector('#cal-today').addEventListener('click', () => {
            this.currentDate = new Date();
            this.store.notify('collection_loaded', this.collection);
        });

        container.appendChild(header);

        // 2. Days of week header
        const daysRow = document.createElement('div');
        daysRow.className = 'notion-calendar-days-row';
        ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].forEach(d => {
            const dCell = document.createElement('div');
            dCell.className = 'cal-day-header';
            dCell.textContent = d;
            daysRow.appendChild(dCell);
        });
        container.appendChild(daysRow);

        // 3. Month Grid
        const grid = document.createElement('div');
        grid.className = 'notion-calendar-grid';

        const firstDayIndex = new Date(year, month, 1).getDay();
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        const daysInPrevMonth = new Date(year, month, 0).getDate();

        const today = new Date();
        const isCurrentMonth = today.getFullYear() === year && today.getMonth() === month;

        // Group rows by date (YYYY-MM-DD)
        const dateItemMap = {};
        (this.collection.rows || []).forEach(r => {
            const d = (r.properties && (r.properties.dueDate || r.properties.date)) || null;
            if (d) {
                const parsed = new Date(d);
                if (!isNaN(parsed.getTime())) {
                    const key = `${parsed.getFullYear()}-${String(parsed.getMonth() + 1).padStart(2, '0')}-${String(parsed.getDate()).padStart(2, '0')}`;
                    if (!dateItemMap[key]) dateItemMap[key] = [];
                    dateItemMap[key].push(r);
                }
            }
        });

        // Total 35 or 42 cells
        const totalCells = (firstDayIndex + daysInMonth > 35) ? 42 : 35;

        for (let i = 0; i < totalCells; i++) {
            const cell = document.createElement('div');
            cell.className = 'cal-cell';

            let cellDateNum = 0;
            let cellDateKey = '';
            let isCurrent = false;

            if (i < firstDayIndex) {
                // Prev month
                cellDateNum = daysInPrevMonth - (firstDayIndex - 1 - i);
                cell.classList.add('other-month');
            } else if (i >= firstDayIndex + daysInMonth) {
                // Next month
                cellDateNum = i - (firstDayIndex + daysInMonth) + 1;
                cell.classList.add('other-month');
            } else {
                // Current month
                cellDateNum = i - firstDayIndex + 1;
                cellDateKey = `${year}-${String(month + 1).padStart(2, '0')}-${String(cellDateNum).padStart(2, '0')}`;
                if (isCurrentMonth && cellDateNum === today.getDate()) {
                    isCurrent = true;
                    cell.classList.add('today');
                }
            }

            const dayNumEl = document.createElement('div');
            dayNumEl.className = 'cal-day-num';
            dayNumEl.innerHTML = isCurrent ? `<span class="today-circle">${cellDateNum}</span>` : `<span>${cellDateNum}</span>`;
            cell.appendChild(dayNumEl);

            // Render events for this date
            const events = dateItemMap[cellDateKey] || [];
            if (events.length > 0) {
                const eventWrap = document.createElement('div');
                eventWrap.className = 'cal-events-wrap';
                events.forEach(item => {
                    const pill = document.createElement('div');
                    pill.className = 'cal-event-pill';
                    const props = item.properties || {};
                    const title = props.title || props.name || 'Untitled';
                    const status = props.status || '';
                    if (status) pill.classList.add(`status-${status.toLowerCase().replace(/\s+/g, '-')}`);
                    pill.textContent = title;
                    pill.title = `${title} (${status})`;
                    pill.addEventListener('click', (e) => {
                        e.stopPropagation();
                        if (typeof this.onRowClick === 'function') this.onRowClick(item);
                    });
                    eventWrap.appendChild(pill);
                });
                cell.appendChild(eventWrap);
            }

            // Quick add on click
            if (cellDateKey) {
                cell.addEventListener('click', async () => {
                    const taskName = prompt(`Schedule task for ${cellDateKey}:`);
                    if (taskName) {
                        await this.store.saveCollectionRow(this.collection.id, {
                            title: taskName.trim(),
                            dueDate: cellDateKey,
                            status: 'Not started',
                            priority: 'Medium'
                        });
                        await this.store.loadCollection(this.collection.id);
                    }
                });
            }

            grid.appendChild(cell);
        }

        container.appendChild(grid);
        return container;
    }
}

if (typeof window !== 'undefined') {
    window.CalendarRenderer = CalendarRenderer;
}
