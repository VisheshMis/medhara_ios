// Medha Windows Desktop — Main Process
const { app, BrowserWindow, ipcMain, dialog, screen } = require('electron');
const path = require('path');
const fs = require('fs');
const { DatabaseManager } = require('./database/db');
const { AnkiImporter } = require('./services/ankiImporter');
const { APICatalog } = require('./services/apiCatalog');
const { AIService } = require('./services/aiService');
const { ExportService } = require('./services/exportService');

let mainWindow = null;
let dbManager = null;

function createWindow() {
    // Position on active screen with mouse cursor
    const cursor = screen.getCursorScreenPoint();
    const currentDisplay = screen.getDisplayNearestPoint(cursor);
    const { width: screenW, height: screenH } = currentDisplay.workAreaSize;

    const winW = Math.min(1240, screenW - 60);
    const winH = Math.min(840, screenH - 60);

    mainWindow = new BrowserWindow({
        width: winW,
        height: winH,
        minWidth: 860,
        minHeight: 560,
        x: Math.round(currentDisplay.workArea.x + (screenW - winW) / 2),
        y: Math.round(currentDisplay.workArea.y + (screenH - winH) / 2),
        frame: false, // Frameless for macOS vibrancy / custom Windows controls
        titleBarStyle: 'hidden',
        backgroundColor: '#0F172A',
        webPreferences: {
            preload: path.join(__dirname, 'preload.js'),
            nodeIntegration: false,
            contextIsolation: true,
            sandbox: false
        }
    });

    mainWindow.loadFile(path.join(__dirname, '../src/index.html'));

    mainWindow.on('closed', () => {
        mainWindow = null;
    });
}

app.whenReady().then(() => {
    dbManager = new DatabaseManager();
    setupIPC();
    createWindow();

    app.on('activate', () => {
        if (BrowserWindow.getAllWindows().length === 0) createWindow();
    });
});

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') {
        if (dbManager) dbManager.close();
        app.quit();
    }
});

function setupIPC() {
    const db = dbManager.getDatabase();

    // Window controls
    ipcMain.on('window-minimize', () => {
        if (mainWindow) mainWindow.minimize();
    });

    ipcMain.on('window-maximize', () => {
        if (mainWindow) {
            if (mainWindow.isMaximized()) mainWindow.unmaximize();
            else mainWindow.maximize();
        }
    });

    ipcMain.on('window-close', () => {
        if (mainWindow) mainWindow.close();
    });

    ipcMain.handle('window-is-maximized', () => {
        return mainWindow ? mainWindow.isMaximized() : false;
    });

    // Database operations
    ipcMain.handle('db-query', (event, { sql, params }) => {
        try {
            const stmt = db.prepare(sql);
            return { success: true, data: params ? stmt.all(...params) : stmt.all() };
        } catch (e) {
            console.error('db-query error:', e);
            return { success: false, error: e.message };
        }
    });

    ipcMain.handle('db-execute', (event, { sql, params }) => {
        try {
            const stmt = db.prepare(sql);
            const info = params ? stmt.run(...params) : stmt.run();
            return { success: true, info };
        } catch (e) {
            console.error('db-execute error:', e);
            return { success: false, error: e.message };
        }
    });

    ipcMain.handle('db-search-fts', (event, { query }) => {
        try {
            const clean = query.trim().replace(/['"]/g, '');
            if (!clean) return { success: true, data: [] };

            const stmt = db.prepare(`
                SELECT b.id, b.rootDocId, b.content, b.type, snippet(block_fts, 2, '<b>', '</b>', '...', 24) AS snippet
                FROM block_fts f
                JOIN block b ON b.id = f.id
                WHERE block_fts MATCH ?
                LIMIT 25
            `);
            const results = stmt.all(`${clean}*`);
            return { success: true, data: results };
        } catch (e) {
            return { success: false, error: e.message };
        }
    });

    // Anki Importer
    ipcMain.handle('open-anki-file-dialog', async () => {
        const result = await dialog.showOpenDialog(mainWindow, {
            title: 'Select Anki Deck (.apkg)',
            filters: [{ name: 'Anki Package', extensions: ['apkg', 'zip'] }],
            properties: ['openFile']
        });
        if (result.canceled || result.filePaths.length === 0) return null;
        return result.filePaths[0];
    });

    ipcMain.handle('import-anki-package', async (event, { filePath, defaultDocId, defaultNotebookId }) => {
        try {
            const res = AnkiImporter.importPackage(filePath, db, defaultDocId, defaultNotebookId);
            return { success: true, data: res };
        } catch (e) {
            return { success: false, error: e.message };
        }
    });

    // File pickers
    ipcMain.handle('open-image-file-dialog', async () => {
        const result = await dialog.showOpenDialog(mainWindow, {
            title: 'Select Palace Scene Image',
            filters: [{ name: 'Images', extensions: ['jpg', 'jpeg', 'png', 'webp'] }],
            properties: ['openFile']
        });
        if (result.canceled || result.filePaths.length === 0) return null;
        const filePath = result.filePaths[0];
        const data = fs.readFileSync(filePath);
        const base64 = `data:image/${path.extname(filePath).slice(1)};base64,${data.toString('base64')}`;
        return { filePath, base64 };
    });

    ipcMain.handle('open-pdf-file-dialog', async () => {
        const result = await dialog.showOpenDialog(mainWindow, {
            title: 'Select PDF to Import as Ink Scrim',
            filters: [{ name: 'PDF Documents', extensions: ['pdf'] }],
            properties: ['openFile']
        });
        if (result.canceled || result.filePaths.length === 0) return null;
        return result.filePaths[0];
    });

    ipcMain.handle('save-export-file-dialog', async (event, { defaultName, content, ext }) => {
        const result = await dialog.showSaveDialog(mainWindow, {
            title: 'Export File',
            defaultPath: defaultName,
            filters: [{ name: ext.toUpperCase(), extensions: [ext] }]
        });
        if (result.canceled || !result.filePath) return { success: false };
        fs.writeFileSync(result.filePath, content, 'utf8');
        return { success: true, filePath: result.filePath };
    });

    // Academic APIs & AI
    ipcMain.handle('fetch-academic-evidence', async (event, { query, domains }) => {
        const data = await APICatalog.gatherAcademicEvidence(query, domains);
        return { success: true, data };
    });

    ipcMain.handle('call-ai', async (event, config) => {
        try {
            const res = await AIService.callProvider(config);
            return { success: true, data: res };
        } catch (e) {
            return { success: false, error: e.message };
        }
    });

    ipcMain.handle('evaluate-socratic', async (event, { card, answer, config }) => {
        try {
            const res = await AIService.evaluateSocraticAnswer({ card, studentAnswer: answer, providerConfig: config });
            return { success: true, data: res };
        } catch (e) {
            return { success: false, error: e.message };
        }
    });

    ipcMain.handle('plan-skeleton', async (event, { topic, domain, config, evidence }) => {
        try {
            const res = await AIService.planSkeleton({ topic, domain, providerConfig: config, evidence });
            return { success: true, data: res };
        } catch (e) {
            return { success: false, error: e.message };
        }
    });

    ipcMain.handle('fill-note-content', async (event, { nodeTitle, scope, depth, config, evidence }) => {
        try {
            const res = await AIService.fillNoteContent({ nodeTitle, scope, depth, providerConfig: config, evidence });
            return { success: true, data: res };
        } catch (e) {
            return { success: false, error: e.message };
        }
    });
}
