// Medha Windows Desktop — Browser ES Modules Compatibility Entry
// Re-exports all components cleanly for browser or bundler environments

import { BlockStore } from './store.js';
import { fsrs, Rating } from './flashcards/fsrs.js';
import { BlockEditorEngine } from './editor/blockEngine.js';
import { InkCanvas } from './ink/inkCanvas.js';
import { PalaceCanvas } from './palace/palaceCanvas.js';
import { KnowledgeGraphEngine } from './graph/graphPhysics.js';
import { AutoNotePipeline } from './ai/autoNotePipeline.js';
import { FocusTimerManager } from './timer/focusTimer.js';
import { ExportService } from './exportService.js';
import { LinkParser } from './editor/linkParser.js';
import { InkGeometry } from './ink/inkGeometry.js';

export {
    BlockStore,
    fsrs,
    Rating,
    BlockEditorEngine,
    InkCanvas,
    InkGeometry,
    PalaceCanvas,
    KnowledgeGraphEngine,
    AutoNotePipeline,
    FocusTimerManager,
    ExportService,
    LinkParser
};
