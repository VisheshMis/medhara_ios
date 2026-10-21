import React, { useState } from 'react';
import { Columns3, Plus, Trash2, Calendar, CheckSquare, Tag } from 'lucide-react';

interface DatabaseRecord {
  id: string;
  title: string;
  status: 'To Do' | 'In Progress' | 'Done';
  priority: 'Low' | 'Medium' | 'High';
  dueDate: string;
}

export const DatabaseView: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'table' | 'board' | 'gallery'>('table');

  const [records, setRecords] = useState<DatabaseRecord[]>([
    { id: 'rec-1', title: 'Neuroscience Foundations', status: 'Done', priority: 'High', dueDate: '2026-10-25' },
    { id: 'rec-2', title: 'FSRS Spaced Repetition Derivation', status: 'In Progress', priority: 'High', dueDate: '2026-10-28' },
    { id: 'rec-3', title: 'Spatial Memory Palace Coordinates', status: 'To Do', priority: 'Medium', dueDate: '2026-11-02' },
  ]);

  const addRecord = () => {
    const newRec: DatabaseRecord = {
      id: `rec-${Date.now()}`,
      title: 'New Database Entry',
      status: 'To Do',
      priority: 'Medium',
      dueDate: new Date().toISOString().split('T')[0],
    };
    setRecords([...records, newRec]);
  };

  const deleteRecord = (id: string) => {
    setRecords(records.filter((r) => r.id !== id));
  };

  return (
    <div className="w-full my-4 border border-white/[0.08] rounded-xl bg-[#12151F] overflow-hidden select-none">
      {/* Notion Database Header Tabs */}
      <div className="flex items-center justify-between px-3 py-2 bg-[#161923] border-b border-white/[0.06] text-xs">
        <div className="flex items-center gap-1">
          <button
            onClick={() => setActiveTab('table')}
            className={`px-2.5 py-1 rounded-md font-medium transition ${
              activeTab === 'table' ? 'bg-blue-600/20 text-blue-400' : 'text-slate-400 hover:text-white'
            }`}
          >
            Table View
          </button>
          <button
            onClick={() => setActiveTab('board')}
            className={`px-2.5 py-1 rounded-md font-medium transition ${
              activeTab === 'board' ? 'bg-blue-600/20 text-blue-400' : 'text-slate-400 hover:text-white'
            }`}
          >
            Board (Kanban)
          </button>
        </div>

        <button
          onClick={addRecord}
          className="flex items-center gap-1 px-2.5 py-1 rounded-md bg-blue-600 text-white font-semibold text-xs hover:bg-blue-500 transition"
        >
          <Plus className="w-3.5 h-3.5" />
          <span>New Record</span>
        </button>
      </div>

      {/* Table Mode */}
      {activeTab === 'table' && (
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs border-collapse">
            <thead>
              <tr className="border-b border-white/[0.06] bg-black/20 text-slate-400 font-semibold">
                <th className="p-2.5 pl-4">Title</th>
                <th className="p-2.5">Status</th>
                <th className="p-2.5">Priority</th>
                <th className="p-2.5">Due Date</th>
                <th className="p-2.5 text-right pr-4">Actions</th>
              </tr>
            </thead>
            <tbody>
              {records.map((rec) => (
                <tr key={rec.id} className="border-b border-white/[0.04] hover:bg-white/[0.02] transition">
                  <td className="p-2.5 pl-4 font-medium text-slate-100">{rec.title}</td>
                  <td className="p-2.5">
                    <span
                      className={`inline-block px-2 py-0.5 rounded-full text-[10px] font-semibold ${
                        rec.status === 'Done'
                          ? 'bg-emerald-500/15 text-emerald-400 border border-emerald-500/30'
                          : rec.status === 'In Progress'
                          ? 'bg-blue-500/15 text-blue-400 border border-blue-500/30'
                          : 'bg-slate-500/15 text-slate-400 border border-slate-500/30'
                      }`}
                    >
                      {rec.status}
                    </span>
                  </td>
                  <td className="p-2.5">
                    <span
                      className={`font-medium ${
                        rec.priority === 'High'
                          ? 'text-red-400'
                          : rec.priority === 'Medium'
                          ? 'text-amber-400'
                          : 'text-slate-400'
                      }`}
                    >
                      {rec.priority}
                    </span>
                  </td>
                  <td className="p-2.5 text-slate-400 font-mono text-[11px]">{rec.dueDate}</td>
                  <td className="p-2.5 text-right pr-4">
                    <button
                      onClick={() => deleteRecord(rec.id)}
                      className="text-slate-500 hover:text-red-400 transition"
                      title="Delete Record"
                    >
                      <Trash2 className="w-3.5 h-3.5 inline" />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Board Mode (Kanban) */}
      {activeTab === 'board' && (
        <div className="grid grid-cols-3 gap-3 p-3 bg-black/20">
          {(['To Do', 'In Progress', 'Done'] as const).map((col) => (
            <div key={col} className="flex flex-col bg-[#161923] rounded-lg p-2.5 border border-white/[0.06]">
              <div className="font-semibold text-xs text-slate-400 mb-2 flex items-center justify-between">
                <span>{col}</span>
                <span className="text-[10px] px-1.5 py-0.5 rounded bg-white/[0.06]">
                  {records.filter((r) => r.status === col).length}
                </span>
              </div>
              <div className="space-y-2">
                {records
                  .filter((r) => r.status === col)
                  .map((r) => (
                    <div
                      key={r.id}
                      className="p-2 rounded-md bg-[#1E2230] border border-white/[0.08] shadow-sm text-xs space-y-1"
                    >
                      <div className="font-medium text-slate-200">{r.title}</div>
                      <div className="flex items-center justify-between text-[10px] text-slate-400">
                        <span>{r.dueDate}</span>
                        <span className={r.priority === 'High' ? 'text-red-400 font-bold' : ''}>
                          {r.priority}
                        </span>
                      </div>
                    </div>
                  ))}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};
