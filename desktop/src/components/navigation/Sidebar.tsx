import React from 'react';
import { BookOpen, Folder, FileText, Plus, Trash2, ChevronRight, ChevronDown, PenTool } from 'lucide-react';
import { useBlockStore } from '../../store/useBlockStore';
import { Block } from '../../types/models';

export const Sidebar: React.FC = () => {
  const {
    notebooks,
    selectedNotebookId,
    selectNotebook,
    documents,
    selectedDocId,
    selectDocument,
    createDocument,
    deleteDocument,
  } = useBlockStore();

  const handleCreateNote = async (type: 'doc' | 'inkDoc' = 'doc') => {
    await createDocument(type === 'inkDoc' ? 'Untitled Ink Note' : 'Untitled Note', null, type);
  };

  return (
    <aside className="w-[240px] min-w-[200px] max-w-[300px] bg-[#12151F] border-r border-white/[0.08] flex flex-col flex-shrink-0 select-none">
      {/* Notebooks Section */}
      <div className="p-3 border-b border-white/[0.06]">
        <div className="flex items-center justify-between text-[11px] font-bold uppercase tracking-wider text-slate-400 mb-2">
          <span>Notebooks</span>
        </div>
        <div className="space-y-1">
          {notebooks.map((nb) => (
            <div
              key={nb.id}
              onClick={() => selectNotebook(nb.id)}
              className={`flex items-center gap-2 px-2.5 py-1.5 rounded-lg text-xs font-medium cursor-pointer transition ${
                selectedNotebookId === nb.id
                  ? 'bg-blue-600/20 text-blue-400 font-semibold'
                  : 'text-slate-300 hover:bg-white/[0.05] hover:text-white'
              }`}
            >
              <BookOpen className="w-3.5 h-3.5 text-blue-400" />
              <span className="truncate">{nb.name}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Documents List Header */}
      <div className="px-3 pt-3 pb-1 flex items-center justify-between text-[11px] font-bold uppercase tracking-wider text-slate-400">
        <span>Documents</span>
        <div className="flex items-center gap-1">
          <button
            onClick={() => handleCreateNote('inkDoc')}
            className="p-1 rounded hover:bg-white/[0.08] text-slate-300 hover:text-white transition"
            title="New Hand-drawn / Vector Ink Note"
          >
            <PenTool className="w-3.5 h-3.5 text-purple-400" />
          </button>
          <button
            onClick={() => handleCreateNote('doc')}
            className="p-1 rounded hover:bg-white/[0.08] text-slate-300 hover:text-white transition"
            title="New Markdown / PKM Note"
          >
            <Plus className="w-4 h-4 text-blue-400" />
          </button>
        </div>
      </div>

      {/* Documents Tree / List */}
      <div className="flex-1 overflow-y-auto px-2 py-1 space-y-0.5">
        {documents.map((doc: Block) => (
          <div
            key={doc.id}
            onClick={() => selectDocument(doc.id)}
            className={`group flex items-center justify-between px-2.5 py-1.5 rounded-lg text-xs cursor-pointer transition ${
              selectedDocId === doc.id
                ? 'bg-blue-600/20 text-blue-300 font-medium'
                : 'text-slate-300 hover:bg-white/[0.04] hover:text-white'
            }`}
          >
            <div className="flex items-center gap-2 truncate">
              {doc.type === 'inkDoc' ? (
                <PenTool className="w-3.5 h-3.5 text-purple-400 flex-shrink-0" />
              ) : (
                <FileText className="w-3.5 h-3.5 text-blue-400 flex-shrink-0" />
              )}
              <span className="truncate">{doc.content || 'Untitled Note'}</span>
            </div>

            <button
              onClick={(e) => {
                e.stopPropagation();
                deleteDocument(doc.id);
              }}
              className="opacity-0 group-hover:opacity-100 p-1 hover:text-red-400 transition"
              title="Delete Document"
            >
              <Trash2 className="w-3 h-3" />
            </button>
          </div>
        ))}
      </div>
    </aside>
  );
};
