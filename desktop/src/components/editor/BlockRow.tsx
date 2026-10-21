import React, { useState } from 'react';
import { ChevronRight, ChevronDown, Check, GripVertical, Plus, Minus, Table as TableIcon } from 'lucide-react';
import { Block, BlockType, TableBlockPayload } from '../../types/models';
import { useBlockStore } from '../../store/useBlockStore';

interface BlockRowProps {
  block: Block;
  isLocked: boolean;
  onOpenSlashMenu: (x: number, y: number, blockId: string) => void;
  onEnterAtEnd: (block: Block) => void;
  onBackspaceEmpty: (block: Block) => void;
}

export const BlockRow: React.FC<BlockRowProps> = ({
  block,
  isLocked,
  onOpenSlashMenu,
  onEnterAtEnd,
  onBackspaceEmpty,
}) => {
  const {
    updateBlockContent,
    toggleTask,
    toggleBlockCollapse,
  } = useBlockStore();

  const [isHovered, setIsHovered] = useState(false);

  const isHeading =
    block.type === 'heading1' || block.type === 'heading2' || block.type === 'heading3';
  const isToggle = block.type === 'toggle';

  // Parse Table Payload safely
  const parseTable = (content: string): TableBlockPayload => {
    try {
      if (content.startsWith('{')) {
        const parsed = JSON.parse(content);
        if (Array.isArray(parsed.rows)) return parsed;
      }
    } catch {}
    return {
      rows: [
        ['Column 1', 'Column 2', 'Column 3'],
        ['Data A', 'Data B', 'Data C'],
        ['Data D', 'Data E', 'Data F'],
      ],
      hasHeaderRow: true,
      hasHeaderCol: false,
    };
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLDivElement>) => {
    if (isLocked) return;

    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      onEnterAtEnd(block);
    } else if (e.key === 'Backspace' && (e.currentTarget.textContent || '').length === 0) {
      e.preventDefault();
      onBackspaceEmpty(block);
    } else if (e.key === '/') {
      const rect = e.currentTarget.getBoundingClientRect();
      onOpenSlashMenu(rect.left, rect.bottom, block.id);
    }
  };

  // Render Table Block Matrix
  if (block.type === 'table') {
    const tableData = parseTable(block.content);

    const updateCell = (rIdx: number, cIdx: number, val: string) => {
      const newRows = [...tableData.rows.map((r) => [...r])];
      newRows[rIdx][cIdx] = val;
      updateBlockContent(block.id, JSON.stringify({ ...tableData, rows: newRows }));
    };

    const addRow = () => {
      const colCount = tableData.rows[0]?.length || 3;
      const newRows = [...tableData.rows, new Array(colCount).fill('')];
      updateBlockContent(block.id, JSON.stringify({ ...tableData, rows: newRows }));
    };

    const addCol = () => {
      const newRows = tableData.rows.map((r) => [...r, '']);
      updateBlockContent(block.id, JSON.stringify({ ...tableData, rows: newRows }));
    };

    const removeRow = () => {
      if (tableData.rows.length <= 1) return;
      const newRows = tableData.rows.slice(0, -1);
      updateBlockContent(block.id, JSON.stringify({ ...tableData, rows: newRows }));
    };

    const removeCol = () => {
      if ((tableData.rows[0]?.length || 0) <= 1) return;
      const newRows = tableData.rows.map((r) => r.slice(0, -1));
      updateBlockContent(block.id, JSON.stringify({ ...tableData, rows: newRows }));
    };

    return (
      <div className="my-3 group">
        {!isLocked && (
          <div className="flex items-center justify-between px-3 py-1.5 bg-[#161923] border border-white/[0.08] rounded-t-lg text-xs text-slate-400">
            <div className="flex items-center gap-1.5 font-medium">
              <TableIcon className="w-3.5 h-3.5 text-blue-400" />
              <span>
                {tableData.rows.length} × {tableData.rows[0]?.length || 0} Table
              </span>
            </div>
            <div className="flex items-center gap-1">
              <button
                onClick={addRow}
                className="px-2 py-0.5 rounded bg-white/[0.05] hover:bg-white/[0.1] text-slate-200 transition"
              >
                + Row
              </button>
              <button
                onClick={addCol}
                className="px-2 py-0.5 rounded bg-white/[0.05] hover:bg-white/[0.1] text-slate-200 transition"
              >
                + Col
              </button>
              {tableData.rows.length > 1 && (
                <button
                  onClick={removeRow}
                  className="px-1.5 py-0.5 rounded bg-white/[0.05] hover:bg-white/[0.1] text-slate-400 hover:text-red-400 transition"
                >
                  <Minus className="w-3 h-3" />
                </button>
              )}
              {(tableData.rows[0]?.length || 0) > 1 && (
                <button
                  onClick={removeCol}
                  className="px-1.5 py-0.5 rounded bg-white/[0.05] hover:bg-white/[0.1] text-slate-400 hover:text-red-400 transition"
                >
                  <Minus className="w-3 h-3" />
                </button>
              )}
            </div>
          </div>
        )}

        <div className="overflow-x-auto border border-white/[0.08] rounded-b-lg bg-[#0F1117]">
          <table className="w-full border-collapse text-xs">
            <tbody>
              {tableData.rows.map((row, rIdx) => (
                <tr key={rIdx}>
                  {row.map((cell, cIdx) => {
                    const isHeader = rIdx === 0 && tableData.hasHeaderRow;
                    return (
                      <td
                        key={cIdx}
                        contentEditable={!isLocked}
                        suppressContentEditableWarning
                        onBlur={(e) => updateCell(rIdx, cIdx, e.currentTarget.textContent || '')}
                        className={`p-2 border border-white/[0.06] outline-none min-w-[90px] ${
                          isHeader
                            ? 'bg-blue-600/10 font-semibold text-blue-300'
                            : 'text-slate-200 focus:bg-blue-600/15'
                        }`}
                      >
                        {cell}
                      </td>
                    );
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    );
  }

  // Standard Text / Heading / Toggle / Callout Block Row
  return (
    <div
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
      className="group relative flex items-start gap-2 py-1 min-h-[28px]"
    >
      {/* Drag handle */}
      {!isLocked && (
        <div
          className={`w-4 h-6 flex items-center justify-center text-slate-500 cursor-grab opacity-0 transition ${
            isHovered ? 'opacity-100' : ''
          }`}
        >
          <GripVertical className="w-3.5 h-3.5" />
        </div>
      )}

      {/* Disclosure Chevron for Toggles & Headings */}
      {(isToggle || isHeading) && (
        <button
          onClick={() => toggleBlockCollapse(block.id)}
          className="mt-1 text-slate-400 hover:text-slate-100 transition flex-shrink-0"
          title={block.isCollapsed ? 'Expand section' : 'Collapse section'}
        >
          {block.isCollapsed ? (
            <ChevronRight className="w-4 h-4" />
          ) : (
            <ChevronDown className="w-4 h-4" />
          )}
        </button>
      )}

      {/* Task Checkbox */}
      {block.type === 'taskList' && (
        <button
          disabled={isLocked}
          onClick={() => toggleTask(block.id)}
          className={`mt-1 w-4 h-4 rounded border flex items-center justify-center transition flex-shrink-0 ${
            block.isCompleted
              ? 'bg-blue-600 border-blue-500 text-white'
              : 'border-white/[0.2] hover:border-blue-400'
          }`}
        >
          {Boolean(block.isCompleted) && <Check className="w-3 h-3 stroke-[3]" />}
        </button>
      )}

      {/* Block Content Area */}
      <div
        contentEditable={!isLocked}
        suppressContentEditableWarning
        onInput={(e) => updateBlockContent(block.id, e.currentTarget.textContent || '')}
        onKeyDown={handleKeyDown}
        data-placeholder={
          isToggle
            ? 'Toggle heading...'
            : isHeading
            ? `Heading ${block.type.replace('heading', '')}...`
            : 'Type / for commands...'
        }
        className={`flex-1 outline-none text-slate-100 leading-relaxed break-words whitespace-pre-wrap ${
          block.type === 'heading1'
            ? 'text-2xl font-bold tracking-tight text-white mt-3'
            : block.type === 'heading2'
            ? 'text-xl font-semibold tracking-tight text-white mt-2'
            : block.type === 'heading3'
            ? 'text-lg font-semibold text-slate-100 mt-1'
            : block.type === 'quote'
            ? 'border-l-2 border-purple-500 pl-3 italic text-slate-300'
            : block.type === 'callout'
            ? 'bg-blue-600/10 border border-blue-500/30 p-3 rounded-lg text-blue-200'
            : block.type === 'codeBlock'
            ? 'bg-black/60 border border-white/[0.08] font-mono p-3 rounded-lg text-emerald-400 text-xs'
            : block.type === 'taskList' && block.isCompleted
            ? 'line-through text-slate-500'
            : 'text-sm'
        }`}
      >
        {block.content}
      </div>
    </div>
  );
};
