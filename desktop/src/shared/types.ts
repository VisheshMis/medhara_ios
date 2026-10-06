/**
 * Shared Type Definitions for Medha Windows Desktop
 * Acts as the single source of truth across Electron Main and Renderer
 */

// --- Model Types ---

export interface Notebook {
  id: string;
  name: string;
  colorHex?: string;
  icon?: string;
  createdAt: string;
  updatedAt: string;
}

export interface Document {
  id: string;
  notebookId: string;
  parentId?: string | null;
  title: string;
  isFolder: boolean;
  orderIndex: number;
  createdAt: string;
  updatedAt: string;
}

export type BlockType =
  | 'doc'
  | 'inkDoc'
  | 'heading1'
  | 'heading2'
  | 'heading3'
  | 'paragraph'
  | 'bulletList'
  | 'taskList'
  | 'codeBlock'
  | 'quote'
  | 'callout'
  | 'blockRef';

export interface Block {
  id: string;
  documentId: string;
  parentId?: string | null;
  type: BlockType;
  content: string;
  checked?: boolean;
  orderIndex: number;
  propertiesJson?: string;
  canvasMode?: 'a4Pages' | 'infinite';
  createdAt: string;
  updatedAt: string;
}

export interface InkPoint {
  x: number;
  y: number;
  pressure: number;
  timeOffset: number;
}

export type InkToolType = 'ballpoint' | 'fountain' | 'highlighter' | 'eraser' | 'lasso';

export interface InkStroke {
  id: string;
  tool: InkToolType;
  colorHex: string;
  baseWidth: number;
  opacity: number;
  points: InkPoint[];
}

export interface InkDocumentPage {
  id: string;
  docId: string;
  pageIndex: number;
  templateType: 'blank' | 'lined' | 'grid' | 'dotGrid' | 'dotMatrix';
  strokesData: string;
  textProjection?: string;
  pdfPath?: string | null;
  pdfPageIndex?: number | null;
  createdAt: string;
  updatedAt: string;
}

export interface DocLink {
  id: string;
  sourceDocId: string;
  targetDocId: string;
  sourceBlockId?: string;
  createdAt: string;
}

export interface Deck {
  id: string;
  name: string;
  description?: string;
  createdAt: string;
  updatedAt: string;
}

export interface Flashcard {
  id: string;
  deckId: string;
  documentId?: string | null;
  blockId?: string | null;
  question: string;
  answer: string;
  state: 'new' | 'learning' | 'review' | 'relearning';
  stability: number;
  difficulty: number;
  elapsedDays: number;
  scheduledDays: number;
  reps: number;
  lapses: number;
  lastReview?: string | null;
  due: string;
  cardType?: number; // 0: standard, 1: image occlusion
  imagePath?: string;
  occlusionMasksData?: string;
  activeMaskId?: string;
  occlusionMode?: number; // 1: hide all guess one, 2: hide one guess one
  createdAt: string;
  updatedAt: string;
}

export interface ReviewLog {
  id: string;
  cardId: string;
  rating: 1 | 2 | 3 | 4; // 1: Again, 2: Hard, 3: Good, 4: Easy
  state: string;
  elapsedDays: number;
  scheduledDays: number;
  reviewTime: string;
}

export interface MemoryPalace {
  id: string;
  name: string;
  description?: string;
  backgroundImageUrl?: string;
  createdAt: string;
  updatedAt: string;
}

export interface PalaceLocus {
  id: string;
  palaceId: string;
  orderIndex: number;
  xNormalized: number;
  yNormalized: number;
  title: string;
  content?: string;
  flashcardId?: string | null;
}

// --- IPC Bridge API ---

export interface MedhaAPI {
  // Window controls
  minimize: () => void;
  maximize: () => void;
  close: () => void;
  isMaximized: () => Promise<boolean>;

  // Database operations
  dbQuery: <T = any>(sql: string, params?: any[]) => Promise<T[]>;
  dbExecute: (sql: string, params?: any[]) => Promise<{ changes: number; lastInsertRowid: number | bigint }>;
  dbSearchFTS: (query: string) => Promise<any[]>;

  // Flashcards & Spaced Repetition
  getDueCards: (deckId?: string) => Promise<Flashcard[]>;
  submitReview: (cardId: string, rating: 1 | 2 | 3 | 4) => Promise<Flashcard>;

  // Anki Import
  importAnkiPackage: (filePath: string, defaultDocId?: string, defaultNotebookId?: string) => Promise<{ cardsImported: number }>;
  openAnkiFileDialog: () => Promise<string | null>;

  // System & Export
  openImageFileDialog: () => Promise<string | null>;
  openPDFFileDialog: () => Promise<string | null>;
  saveExportFileDialog: (defaultName: string, content: string, ext: string) => Promise<boolean>;
  getAppPaths: () => Promise<{ userData: string; documents: string }>;

  // Signal ready for verification
  signalReady: () => void;
}

declare global {
  interface Window {
    medhaAPI: MedhaAPI;
    electronAPI?: MedhaAPI; // backwards-compatible alias during transition
  }
}
