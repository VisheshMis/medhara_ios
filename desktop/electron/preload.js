// Medha Windows Desktop — Preload Context Bridge
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
    // Window controls
    minimize: () => ipcRenderer.send('window-minimize'),
    maximize: () => ipcRenderer.send('window-maximize'),
    close: () => ipcRenderer.send('window-close'),
    isMaximized: () => ipcRenderer.invoke('window-is-maximized'),

    // Database access
    dbQuery: (sql, params) => ipcRenderer.invoke('db-query', { sql, params }),
    dbExecute: (sql, params) => ipcRenderer.invoke('db-execute', { sql, params }),
    dbSearchFTS: (query) => ipcRenderer.invoke('db-search-fts', { query }),

    // Anki Import
    importAnkiPackage: (filePath, defaultDocId, defaultNotebookId) =>
        ipcRenderer.invoke('import-anki-package', { filePath, defaultDocId, defaultNotebookId }),
    openAnkiFileDialog: () => ipcRenderer.invoke('open-anki-file-dialog'),

    // File pickers & Exporters
    openImageFileDialog: () => ipcRenderer.invoke('open-image-file-dialog'),
    openPDFFileDialog: () => ipcRenderer.invoke('open-pdf-file-dialog'),
    saveExportFileDialog: (defaultName, content, ext) =>
        ipcRenderer.invoke('save-export-file-dialog', { defaultName, content, ext }),

    // Academic APIs & AI
    fetchAcademicEvidence: (query, domains) =>
        ipcRenderer.invoke('fetch-academic-evidence', { query, domains }),
    callAI: (config) => ipcRenderer.invoke('call-ai', config),
    evaluateSocratic: (card, answer, config) =>
        ipcRenderer.invoke('evaluate-socratic', { card, answer, config }),
    planSkeleton: (topic, domain, config, evidence) =>
        ipcRenderer.invoke('plan-skeleton', { topic, domain, config, evidence }),
    fillNoteContent: (nodeTitle, scope, depth, config, evidence) =>
        ipcRenderer.invoke('fill-note-content', { nodeTitle, scope, depth, config, evidence })
});
