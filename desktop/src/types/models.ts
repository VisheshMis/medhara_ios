// Types mirroring Swift models in Sources/MedhaKit/Models/
export type BlockType =
  | 'doc'
  | 'paragraph'
  | 'heading1'
  | 'heading2'
  | 'heading3'
  | 'bulletList'
  | 'numberedList'
  | 'taskList'
  | 'quote'
  | 'callout'
  | 'codeBlock'
  | 'divider'
  | 'toggle'
  | 'table'
  | 'mathEquation'
  | 'subPage'
  | 'database'
  | 'inkDoc';

export interface Block {
  id: string;
  rootDocId: string;
  parentId: string | null;
  type: BlockType;
  content: string;
  sortOrder: number;
  isCompleted?: number | null;
  refTargetId?: string | null;
  isCollapsed?: number | null;
  icon?: string | null;
  colorTint?: string | null;
  verifiedAt?: string | null;
  verifiedExpiresAt?: string | null;
  verifiedBy?: string | null;
  isLocked?: number | null;
  pinnedPropertiesData?: string | null;
  canvasMode?: string | null;
  createdAt: string;
  updatedAt: string;
  notebookId?: string | null;
}

export interface Notebook {
  id: string;
  name: string;
  colorHex: string;
  icon: string;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
}

export interface Flashcard {
  id: string;
  docId: string;
  notebookId: string | null;
  deckId: string | null;
  front: string;
  back: string;
  cardType?: number;
  imagePath?: string | null;
  occlusionMasksData?: string | null;
  activeMaskId?: string | null;
  occlusionMode?: number;
  stability: number;
  difficulty: number;
  elapsedDays: number;
  scheduledDays: number;
  reps: number;
  lapses: number;
  fsrsState: number;
  lastReview: string | null;
  due: string;
  isSuspended: number;
  createdAt: string;
  updatedAt: string;
}

export interface Deck {
  id: string;
  name: string;
  description?: string;
  colorHex: string;
  icon: string;
  isNotesDefault: number;
  createdAt: string;
  updatedAt: string;
}

export interface TableBlockPayload {
  rows: string[][];
  hasHeaderRow: boolean;
  hasHeaderCol: boolean;
}

export interface NotionDatabase {
  id: string;
  rootDocId: string;
  title: string;
  description?: string;
  icon?: string;
  createdAt: string;
  updatedAt: string;
}

export interface NotionProperty {
  id: string;
  databaseId: string;
  name: string;
  type: 'title' | 'text' | 'number' | 'select' | 'multiSelect' | 'date' | 'checkbox' | 'relation';
  configJson?: string;
  sortOrder: number;
}
