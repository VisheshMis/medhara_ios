import { create } from 'zustand';
import { Block, Notebook, Flashcard, Deck, BlockType } from '../types/models';

interface BlockStoreState {
  notebooks: Notebook[];
  selectedNotebookId: string | null;
  documents: Block[];
  selectedDocId: string | null;
  currentDoc: Block | null;
  blocks: Block[];
  focusedBlockId: string | null;
  flashcards: Flashcard[];
  decks: Deck[];
  activeView: 'editor' | 'flashcards' | 'graph' | 'palace';
  isLoading: boolean;

  // Actions
  setActiveView: (view: 'editor' | 'flashcards' | 'graph' | 'palace') => void;
  loadInitialData: () => Promise<void>;
  selectDocument: (docId: string) => Promise<void>;
  selectNotebook: (notebookId: string | null) => void;
  createDocument: (title?: string, parentId?: string | null, type?: BlockType) => Promise<Block>;
  deleteDocument: (docId: string) => Promise<void>;
  createBlock: (type?: BlockType, content?: string, parentId?: string | null, sortOrder?: number | null) => Promise<Block | null>;
  updateBlockContent: (id: string, content: string) => Promise<void>;
  convertBlockType: (id: string, toType: BlockType) => Promise<void>;
  deleteBlock: (id: string) => Promise<void>;
  toggleTask: (id: string) => Promise<void>;
  toggleBlockCollapse: (id: string) => Promise<void>;
  setDocumentLock: (docId: string, isLocked: boolean) => Promise<void>;
  setDocumentVerification: (docId: string, days?: number, verifiedBy?: string) => Promise<void>;
  updatePinnedProperties: (docId: string, props: any) => Promise<void>;
}

// Database query helper (delegates to Electron IPC if available)
const queryDb = async (sql: string, params: any[] = []): Promise<any[]> => {
  if (typeof window !== 'undefined' && (window as any).medhaAPI) {
    const res = await (window as any).medhaAPI.dbQuery(sql, params);
    return res.data || [];
  }
  return [];
};

const executeDb = async (sql: string, params: any[] = []): Promise<any> => {
  if (typeof window !== 'undefined' && (window as any).medhaAPI) {
    return await (window as any).medhaAPI.dbExecute(sql, params);
  }
  return null;
};

export const useBlockStore = create<BlockStoreState>((set, get) => ({
  notebooks: [],
  selectedNotebookId: null,
  documents: [],
  selectedDocId: null,
  currentDoc: null,
  blocks: [],
  focusedBlockId: null,
  flashcards: [],
  decks: [],
  activeView: 'editor',
  isLoading: false,

  setActiveView: (view) => set({ activeView: view }),

  loadInitialData: async () => {
    set({ isLoading: true });
    try {
      const notebooks = await queryDb('SELECT * FROM notebook ORDER BY sortOrder ASC');
      const documents = await queryDb('SELECT * FROM block WHERE type IN ("doc", "inkDoc") ORDER BY sortOrder ASC, createdAt ASC');
      const decks = await queryDb('SELECT * FROM deck ORDER BY isNotesDefault DESC, createdAt ASC');
      const flashcards = await queryDb('SELECT * FROM flashcard WHERE isSuspended = 0');

      const initialDocId = documents.length > 0 ? documents[0].id : null;
      const initialDoc = documents.length > 0 ? documents[0] : null;

      let blocks: Block[] = [];
      if (initialDocId) {
        blocks = await queryDb(
          'SELECT * FROM block WHERE rootDocId = ? AND id != ? ORDER BY sortOrder ASC, createdAt ASC',
          [initialDocId, initialDocId]
        );
      }

      set({
        notebooks,
        documents,
        decks,
        flashcards,
        selectedDocId: initialDocId,
        currentDoc: initialDoc,
        blocks,
        isLoading: false
      });
    } catch (e) {
      console.error('Error loading initial data:', e);
      set({ isLoading: false });
    }
  },

  selectNotebook: (notebookId) => {
    set({ selectedNotebookId: notebookId });
  },

  selectDocument: async (docId) => {
    const { documents } = get();
    const doc = documents.find((d) => d.id === docId) || null;
    set({ selectedDocId: docId, currentDoc: doc });

    if (docId) {
      const blocks = await queryDb(
        'SELECT * FROM block WHERE rootDocId = ? AND id != ? ORDER BY sortOrder ASC, createdAt ASC',
        [docId, docId]
      );
      set({ blocks });
    }
  },

  createDocument: async (title = 'Untitled Note', parentId = null, type = 'doc') => {
    const { selectedNotebookId, documents } = get();
    const id = `doc-${Math.random().toString(36).substring(2, 9)}`;
    const nb = selectedNotebookId || 'nb-welcome-kb';
    const now = new Date().toISOString();

    const newDoc: Block = {
      id,
      rootDocId: id,
      parentId,
      type,
      content: title,
      sortOrder: documents.length,
      createdAt: now,
      updatedAt: now,
      notebookId: nb,
      isLocked: 0,
    };

    await executeDb(
      `INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, isLocked, createdAt, updatedAt, notebookId)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [id, id, parentId, type, title, newDoc.sortOrder, 0, now, now, nb]
    );

    set({ documents: [...documents, newDoc] });
    await get().selectDocument(id);
    return newDoc;
  },

  deleteDocument: async (docId) => {
    const { documents, selectedDocId } = get();
    await executeDb('DELETE FROM block WHERE rootDocId = ? OR id = ?', [docId, docId]);
    const updated = documents.filter((d) => d.id !== docId && d.parentId !== docId);
    set({ documents: updated });

    if (selectedDocId === docId) {
      const nextDoc = updated.length > 0 ? updated[0] : null;
      if (nextDoc) {
        await get().selectDocument(nextDoc.id);
      } else {
        set({ selectedDocId: null, currentDoc: null, blocks: [] });
      }
    }
  },

  createBlock: async (type = 'paragraph', content = '', parentId = null, sortOrder = null) => {
    const { selectedDocId, blocks } = get();
    if (!selectedDocId) return null;

    const id = `b-${Math.random().toString(36).substring(2, 10)}-${Date.now()}`;
    const now = new Date().toISOString();
    const order = sortOrder != null ? sortOrder : blocks.length + 1;

    const newBlock: Block = {
      id,
      rootDocId: selectedDocId,
      parentId: parentId || selectedDocId,
      type,
      content,
      sortOrder: order,
      isCompleted: type === 'taskList' ? 0 : null,
      isCollapsed: 0,
      createdAt: now,
      updatedAt: now,
    };

    await executeDb(
      `INSERT INTO block (id, rootDocId, parentId, type, content, sortOrder, isCompleted, isCollapsed, createdAt, updatedAt)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [newBlock.id, newBlock.rootDocId, newBlock.parentId, newBlock.type, newBlock.content, newBlock.sortOrder, newBlock.isCompleted, 0, now, now]
    );

    set({ blocks: [...blocks, newBlock] });
    return newBlock;
  },

  updateBlockContent: async (id, content) => {
    const { blocks } = get();
    const now = new Date().toISOString();
    const updated = blocks.map((b) => (b.id === id ? { ...b, content, updatedAt: now } : b));
    set({ blocks: updated });
    await executeDb('UPDATE block SET content = ?, updatedAt = ? WHERE id = ?', [content, now, id]);
  },

  convertBlockType: async (id, toType) => {
    const { blocks } = get();
    const now = new Date().toISOString();
    const updated = blocks.map((b) =>
      b.id === id
        ? {
            ...b,
            type: toType,
            isCompleted: toType === 'taskList' ? 0 : null,
            updatedAt: now,
          }
        : b
    );
    set({ blocks: updated });
    await executeDb('UPDATE block SET type = ?, updatedAt = ? WHERE id = ?', [toType, now, id]);
  },

  deleteBlock: async (id) => {
    const { blocks } = get();
    set({ blocks: blocks.filter((b) => b.id !== id) });
    await executeDb('DELETE FROM block WHERE id = ?', [id]);
  },

  toggleTask: async (id) => {
    const { blocks } = get();
    const block = blocks.find((b) => b.id === id);
    if (!block) return;
    const isCompleted = block.isCompleted ? 0 : 1;
    const now = new Date().toISOString();
    set({
      blocks: blocks.map((b) => (b.id === id ? { ...b, isCompleted, updatedAt: now } : b)),
    });
    await executeDb('UPDATE block SET isCompleted = ?, updatedAt = ? WHERE id = ?', [isCompleted, now, id]);
  },

  toggleBlockCollapse: async (id) => {
    const { blocks } = get();
    const block = blocks.find((b) => b.id === id);
    if (!block) return;
    const isCollapsed = block.isCollapsed ? 0 : 1;
    const now = new Date().toISOString();
    set({
      blocks: blocks.map((b) => (b.id === id ? { ...b, isCollapsed, updatedAt: now } : b)),
    });
    await executeDb('UPDATE block SET isCollapsed = ?, updatedAt = ? WHERE id = ?', [isCollapsed, now, id]);
  },

  setDocumentLock: async (docId, isLocked) => {
    const { documents, currentDoc } = get();
    const val = isLocked ? 1 : 0;
    const now = new Date().toISOString();
    const updatedDocs = documents.map((d) => (d.id === docId ? { ...d, isLocked: val, updatedAt: now } : d));
    set({
      documents: updatedDocs,
      currentDoc: currentDoc && currentDoc.id === docId ? { ...currentDoc, isLocked: val, updatedAt: now } : currentDoc,
    });
    await executeDb('UPDATE block SET isLocked = ?, updatedAt = ? WHERE id = ?', [val, now, docId]);
  },

  setDocumentVerification: async (docId, days = 90, verifiedBy = 'Author') => {
    const { documents, currentDoc } = get();
    const now = new Date();
    const expires = new Date(now.getTime() + days * 24 * 60 * 60 * 1000);
    const nowStr = now.toISOString();
    const expiresStr = expires.toISOString();

    const updatedDocs = documents.map((d) =>
      d.id === docId
        ? { ...d, verifiedAt: nowStr, verifiedExpiresAt: expiresStr, verifiedBy, updatedAt: nowStr }
        : d
    );

    set({
      documents: updatedDocs,
      currentDoc:
        currentDoc && currentDoc.id === docId
          ? { ...currentDoc, verifiedAt: nowStr, verifiedExpiresAt: expiresStr, verifiedBy, updatedAt: nowStr }
          : currentDoc,
    });

    await executeDb(
      'UPDATE block SET verifiedAt = ?, verifiedExpiresAt = ?, verifiedBy = ?, updatedAt = ? WHERE id = ?',
      [nowStr, expiresStr, verifiedBy, nowStr, docId]
    );
  },

  updatePinnedProperties: async (docId, props) => {
    const { documents, currentDoc } = get();
    const jsonStr = typeof props === 'string' ? props : JSON.stringify(props);
    const now = new Date().toISOString();

    const updatedDocs = documents.map((d) =>
      d.id === docId ? { ...d, pinnedPropertiesData: jsonStr, updatedAt: now } : d
    );

    set({
      documents: updatedDocs,
      currentDoc: currentDoc && currentDoc.id === docId ? { ...currentDoc, pinnedPropertiesData: jsonStr, updatedAt: now } : currentDoc,
    });

    await executeDb('UPDATE block SET pinnedPropertiesData = ?, updatedAt = ? WHERE id = ?', [jsonStr, now, docId]);
  },
}));
