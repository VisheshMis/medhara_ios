import React, { useState } from 'react';
import { useBlockStore } from '../../store/useBlockStore';
import { BlockRow } from './BlockRow';
import { PinnedPropertyBar } from './PinnedPropertyBar';
import { SlashMenu } from './SlashMenu';
import { Block, BlockType } from '../../types/models';

export const BlockEditor: React.FC = () => {
  const {
    currentDoc,
    blocks,
    createBlock,
    convertBlockType,
    deleteBlock,
  } = useBlockStore();

  const [slashMenuState, setSlashMenuState] = useState<{
    isOpen: boolean;
    x: number;
    y: number;
    blockId: string | null;
  }>({
    isOpen: false,
    x: 0,
    y: 0,
    blockId: null,
  });

  if (!currentDoc) {
    return (
      <div className="flex-1 flex items-center justify-center text-slate-500 text-sm select-none">
        No document selected. Choose or create a document from the sidebar.
      </div>
    );
  }

  const isLocked = Boolean(currentDoc.isLocked);

  const handleOpenSlashMenu = (x: number, y: number, blockId: string) => {
    setSlashMenuState({ isOpen: true, x, y, blockId });
  };

  const handleSelectSlashType = (type: BlockType) => {
    if (slashMenuState.blockId) {
      convertBlockType(slashMenuState.blockId, type);
    }
    setSlashMenuState({ isOpen: false, x: 0, y: 0, blockId: null });
  };

  const handleEnterAtEnd = async (block: Block) => {
    const newType: BlockType =
      block.type === 'bulletList' || block.type === 'taskList' ? block.type : 'paragraph';
    await createBlock(newType, '', currentDoc.id, block.sortOrder + 1);
  };

  const handleBackspaceEmpty = async (block: Block) => {
    if (block.type !== 'paragraph') {
      await convertBlockType(block.id, 'paragraph');
    } else if (blocks.length > 1) {
      await deleteBlock(block.id);
    }
  };

  // Filter hidden blocks based on collapsed headings and toggles
  const visibleBlocks: Block[] = [];
  let activeHeadingCollapseLevel: number | null = null;

  for (const b of blocks) {
    if (b.type === 'heading1' || b.type === 'heading2' || b.type === 'heading3') {
      const level = parseInt(b.type.replace('heading', ''), 10);
      if (activeHeadingCollapseLevel !== null && level <= activeHeadingCollapseLevel) {
        activeHeadingCollapseLevel = null;
      }
      if (b.isCollapsed) {
        activeHeadingCollapseLevel = level;
      }
      visibleBlocks.push(b);
    } else if (activeHeadingCollapseLevel !== null) {
      // Hidden under collapsed heading
      continue;
    } else {
      visibleBlocks.push(b);
    }
  }

  return (
    <div className="flex-1 overflow-y-auto flex flex-col items-center px-6 py-8 pb-32">
      {/* 740px Strict Typographic Measure from BlockEditorView.swift */}
      <div className="w-full max-w-[740px] flex flex-col">
        {/* Document Title Header */}
        <div className="mb-4">
          <div className="text-xs font-medium text-slate-400 mb-2 select-none">
            Knowledge Base / {currentDoc.content || 'Untitled'}
          </div>
          <input
            type="text"
            disabled={isLocked}
            value={currentDoc.content || ''}
            placeholder="Document Title..."
            onChange={(e) => {
              currentDoc.content = e.target.value;
              (window as any).medhaAPI?.dbExecute('UPDATE block SET content = ? WHERE id = ?', [
                e.target.value,
                currentDoc.id,
              ]);
            }}
            className="w-full bg-transparent text-3xl font-extrabold tracking-tight text-white outline-none placeholder:text-slate-600 mb-2"
          />

          {/* Pinned Property & Governance Bar */}
          <PinnedPropertyBar doc={currentDoc} />

          {/* Locked Read-Only Banner */}
          {isLocked && (
            <div className="flex items-center justify-between px-3 py-2 rounded-lg bg-orange-500/10 border border-orange-500/25 text-xs text-orange-300 select-none mb-3">
              <span>🔒 This document is locked against accidental modifications.</span>
              <span className="font-semibold text-[11px] opacity-80">Read-Only</span>
            </div>
          )}

          {/* Document Metadata Scrim */}
          <div className="flex items-center gap-4 text-xs text-slate-500 select-none">
            <span>📄 {blocks.length} blocks</span>
            <span>⏱️ {Math.max(1, Math.round((blocks.length * 12) / 60))} min read</span>
          </div>
        </div>

        {/* Blocks Render List */}
        <div className="flex flex-col space-y-0.5">
          {visibleBlocks.map((block) => (
            <BlockRow
              key={block.id}
              block={block}
              isLocked={isLocked}
              onOpenSlashMenu={handleOpenSlashMenu}
              onEnterAtEnd={handleEnterAtEnd}
              onBackspaceEmpty={handleBackspaceEmpty}
            />
          ))}
        </div>

        {/* Slash Command Dropdown Menu */}
        {slashMenuState.isOpen && (
          <SlashMenu
            x={slashMenuState.x}
            y={slashMenuState.y}
            onSelect={handleSelectSlashType}
            onClose={() => setSlashMenuState({ isOpen: false, x: 0, y: 0, blockId: null })}
          />
        )}
      </div>
    </div>
  );
};
