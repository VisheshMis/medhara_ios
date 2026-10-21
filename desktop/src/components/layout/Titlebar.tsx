import React from 'react';
import { Minus, Square, X, Timer } from 'lucide-react';
import { useBlockStore } from '../../store/useBlockStore';

export const Titlebar: React.FC = () => {
  const { activeView, setActiveView } = useBlockStore();

  const handleMinimize = () => {
    (window as any).medhaAPI?.minimize();
  };

  const handleMaximize = () => {
    (window as any).medhaAPI?.maximize();
  };

  const handleClose = () => {
    (window as any).medhaAPI?.close();
  };

  return (
    <header className="h-[44px] flex items-center justify-between px-3 bg-[#12151F] border-b border-white/[0.08] select-none drag-region flex-shrink-0 z-50">
      {/* Brand & Left Section */}
      <div className="flex items-center gap-3 no-drag">
        <div className="flex items-center gap-2">
          <img src="assets/logo.png" alt="Medha" className="w-[20px] h-[20px] rounded-md shadow" />
          <span className="font-semibold text-[13px] tracking-tight text-slate-100">Medha</span>
        </div>

        {/* 10m Focus Timer Pill */}
        <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-white/[0.05] border border-white/[0.08] text-xs font-medium text-slate-300 hover:bg-white/[0.08] cursor-pointer transition">
          <Timer className="w-3.5 h-3.5 text-blue-400" />
          <span>10:00</span>
        </div>
      </div>

      {/* Segmented View Switcher (Matches macOS segmented control) */}
      <div className="flex items-center p-0.5 rounded-lg bg-black/40 border border-white/[0.06] text-xs no-drag">
        <button
          onClick={() => setActiveView('editor')}
          className={`flex items-center gap-1.5 px-3 py-1 rounded-md font-medium transition ${
            activeView === 'editor'
              ? 'bg-[#1E2230] text-blue-400 shadow-sm'
              : 'text-slate-400 hover:text-slate-200'
          }`}
        >
          <span>📄</span>
          <span>Notes & Folders</span>
        </button>

        <button
          onClick={() => setActiveView('flashcards')}
          className={`flex items-center gap-1.5 px-3 py-1 rounded-md font-medium transition ${
            activeView === 'flashcards'
              ? 'bg-[#1E2230] text-blue-400 shadow-sm'
              : 'text-slate-400 hover:text-slate-200'
          }`}
        >
          <span>🗂️</span>
          <span>Flashcards</span>
        </button>

        <button
          onClick={() => setActiveView('graph')}
          className={`flex items-center gap-1.5 px-3 py-1 rounded-md font-medium transition ${
            activeView === 'graph'
              ? 'bg-[#1E2230] text-blue-400 shadow-sm'
              : 'text-slate-400 hover:text-slate-200'
          }`}
        >
          <span>🕸️</span>
          <span>Knowledge Graph</span>
        </button>

        <button
          onClick={() => setActiveView('palace')}
          className={`flex items-center gap-1.5 px-3 py-1 rounded-md font-medium transition ${
            activeView === 'palace'
              ? 'bg-[#1E2230] text-blue-400 shadow-sm'
              : 'text-slate-400 hover:text-slate-200'
          }`}
        >
          <span>🏛️</span>
          <span>Memory Palace</span>
        </button>
      </div>

      {/* Windows 11 Native Caption Controls */}
      <div className="flex items-center no-drag -mr-3">
        <button
          onClick={handleMinimize}
          className="w-[44px] h-[44px] flex items-center justify-center text-slate-400 hover:bg-white/[0.08] hover:text-white transition"
          title="Minimize"
        >
          <Minus className="w-3.5 h-3.5" />
        </button>
        <button
          onClick={handleMaximize}
          className="w-[44px] h-[44px] flex items-center justify-center text-slate-400 hover:bg-white/[0.08] hover:text-white transition"
          title="Maximize"
        >
          <Square className="w-3 h-3" />
        </button>
        <button
          onClick={handleClose}
          className="w-[44px] h-[44px] flex items-center justify-center text-slate-400 hover:bg-red-600 hover:text-white transition"
          title="Close"
        >
          <X className="w-4 h-4" />
        </button>
      </div>
    </header>
  );
};
