import React, { useEffect } from 'react';
import { Titlebar } from './components/layout/Titlebar';
import { Sidebar } from './components/navigation/Sidebar';
import { BlockEditor } from './components/editor/BlockEditor';
import { DatabaseView } from './components/database/DatabaseView';
import { InkCanvas } from './components/ink/InkCanvas';
import { useBlockStore } from './store/useBlockStore';

export const App: React.FC = () => {
  const { activeView, loadInitialData, currentDoc } = useBlockStore();

  useEffect(() => {
    loadInitialData();
  }, [loadInitialData]);

  return (
    <div className="flex flex-col h-screen w-screen bg-[#0F1117] text-slate-100 overflow-hidden font-sans">
      {/* Windows 11 Native Acrylic Titlebar */}
      <Titlebar />

      {/* Main Body (3-Column Layout) */}
      <div className="flex flex-1 overflow-hidden">
        {/* Left Navigation Sidebar */}
        <Sidebar />

        {/* Workspace Display based on Active View or Doc Type */}
        <main className="flex-1 flex overflow-hidden bg-[#0F1117]">
          {activeView === 'editor' ? (
            currentDoc?.type === 'inkDoc' ? (
              <InkCanvas />
            ) : (
              <BlockEditor />
            )
          ) : activeView === 'flashcards' ? (
            <div className="flex-1 p-8 overflow-y-auto">
              <h2 className="text-xl font-bold text-white mb-4">🗂️ FSRS Spaced Repetition Decks</h2>
              <DatabaseView />
            </div>
          ) : activeView === 'graph' ? (
            <div className="flex-1 flex items-center justify-center text-slate-400">
              <span>🕸️ Interactive Knowledge Graph (Physics Simulation Engine)</span>
            </div>
          ) : (
            <div className="flex-1 flex items-center justify-center text-slate-400">
              <span>🏛️ Spatial Memory Palace Viewport</span>
            </div>
          )}
        </main>
      </div>
    </div>
  );
};
