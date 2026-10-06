// Medha Windows Desktop — Preload Context Bridge
// Safely exposes strictly typed bridge to the isolated Renderer world
const { contextBridge, ipcRenderer } = require('electron');

const apiBridge = {
    // Window controls
    minimize: () => ipcRenderer.send('window-minimize'),
    maximize: () => ipcRenderer.send('window-maximize'),
    close: () => ipcRenderer.send('window-close'),
    isMaximized: () => ipcRenderer.invoke('window-is-maximized'),

    // Database access
    dbQuery: (sql, params) => ipcRenderer.invoke('db-query', { sql, params }),
    dbExecute: (sql, params) => ipcRenderer.invoke('db-execute', { sql, params }),
    dbSearchFTS: (query) => ipcRenderer.invoke('db-search-fts', { query }),

    // Spaced repetition / Flashcards
    getDueCards: (deckId) => ipcRenderer.invoke('get-due-cards', { deckId }),
    submitReview: (cardId, rating) => ipcRenderer.invoke('submit-review', { cardId, rating }),

    // Anki Import
    importAnkiPackage: (filePath, defaultDocId, defaultNotebookId) =>
        ipcRenderer.invoke('import-anki-package', { filePath, defaultDocId, defaultNotebookId }),
    openAnkiFileDialog: () => ipcRenderer.invoke('open-anki-file-dialog'),

    // File pickers & Exporters
    openImageFileDialog: () => ipcRenderer.invoke('open-image-file-dialog'),
    openPDFFileDialog: () => ipcRenderer.invoke('open-pdf-file-dialog'),
    saveExportFileDialog: (defaultName, content, ext) =>
        ipcRenderer.invoke('save-export-file-dialog', { defaultName, content, ext }),
    getAppPaths: () => ipcRenderer.invoke('get-app-paths'),

    // Academic APIs & AI
    fetchAcademicEvidence: (query, domains) =>
        ipcRenderer.invoke('fetch-academic-evidence', { query, domains }),
    callAI: (config) => ipcRenderer.invoke('call-ai', config),
    evaluateSocratic: (card, answer, config) =>
        ipcRenderer.invoke('evaluate-socratic', { card, answer, config }),
    planSkeleton: (topic, domain, config, evidence) =>
        ipcRenderer.invoke('plan-skeleton', { topic, domain, config, evidence }),
    fillNoteContent: (nodeTitle, scope, depth, config, evidence) =>
        ipcRenderer.invoke('fill-note-content', { nodeTitle, scope, depth, config, evidence }),

    // Signal verification
    signalReady: () => ipcRenderer.send('renderer-ready')
};

// Expose on both medhaAPI (standard) and electronAPI (legacy compatibility)
contextBridge.exposeInMainWorld('medhaAPI', apiBridge);
contextBridge.exposeInMainWorld('electronAPI', apiBridge);
