import React, { useRef, useEffect } from 'react';
import {
  Heading1,
  Heading2,
  Heading3,
  Type,
  List,
  CheckSquare,
  Code,
  Quote,
  Lightbulb,
  Table,
  ChevronRightSquare,
} from 'lucide-react';
import { BlockType } from '../../types/models';

interface SlashMenuProps {
  x: number;
  y: number;
  onSelect: (type: BlockType) => void;
  onClose: () => void;
}

export const SlashMenu: React.FC<SlashMenuProps> = ({ x, y, onSelect, onClose }) => {
  const menuRef = useRef<HTMLDivElement>(null);

  const items: { type: BlockType; label: string; icon: React.ReactNode }[] = [
    { type: 'heading1', label: 'Heading 1 (Collapsible)', icon: <Heading1 className="w-4 h-4 text-blue-400" /> },
    { type: 'heading2', label: 'Heading 2 (Collapsible)', icon: <Heading2 className="w-4 h-4 text-blue-400" /> },
    { type: 'heading3', label: 'Heading 3 (Collapsible)', icon: <Heading3 className="w-4 h-4 text-blue-400" /> },
    { type: 'paragraph', label: 'Paragraph Text', icon: <Type className="w-4 h-4 text-slate-400" /> },
    { type: 'toggle', label: 'Toggle List (Foldable)', icon: <ChevronRightSquare className="w-4 h-4 text-amber-400" /> },
    { type: 'table', label: 'Table Matrix Grid', icon: <Table className="w-4 h-4 text-emerald-400" /> },
    { type: 'bulletList', label: 'Bullet List', icon: <List className="w-4 h-4 text-blue-400" /> },
    { type: 'taskList', label: 'To-Do Task', icon: <CheckSquare className="w-4 h-4 text-purple-400" /> },
    { type: 'codeBlock', label: 'Code Block', icon: <Code className="w-4 h-4 text-emerald-400" /> },
    { type: 'quote', label: 'Quote', icon: <Quote className="w-4 h-4 text-slate-300" /> },
    { type: 'callout', label: 'Callout Note', icon: <Lightbulb className="w-4 h-4 text-yellow-400" /> },
  ];

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        onClose();
      }
    };
    window.addEventListener('mousedown', handleClickOutside);
    return () => window.removeEventListener('mousedown', handleClickOutside);
  }, [onClose]);

  return (
    <div
      ref={menuRef}
      style={{ left: `${Math.min(window.innerWidth - 260, x)}px`, top: `${Math.min(window.innerHeight - 340, y + 10)}px` }}
      className="fixed z-50 w-64 bg-[#161923] border border-white/[0.12] rounded-xl shadow-2xl p-1.5 space-y-0.5 select-none animate-in fade-in zoom-in-95 duration-100"
    >
      <div className="px-2 py-1 text-[10px] font-bold uppercase tracking-wider text-slate-500">
        Basic Blocks
      </div>
      {items.map((item) => (
        <button
          key={item.type}
          onClick={() => onSelect(item.type)}
          className="w-full flex items-center gap-2.5 px-2.5 py-1.5 rounded-lg text-xs font-medium text-slate-200 hover:bg-white/[0.08] hover:text-white transition cursor-pointer text-left"
        >
          {item.icon}
          <span>{item.label}</span>
        </button>
      ))}
    </div>
  );
};
