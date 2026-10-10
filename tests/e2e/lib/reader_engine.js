/**
 * Medha Hierarchical Document Reader & Parser Engine
 * Implements tree hierarchy computation, fold/toggle filtering,
 * indent level calculations (20dp * depth), and WikiLink/blockRef extraction.
 */

class ReaderEngine {
  /**
   * Builds an ordered list of blocks with calculated depths and visibility flags.
   */
  static buildBlockTree(blocks, rootDocId) {
    const blockMap = new Map();
    blocks.forEach(b => blockMap.set(b.id, { ...b }));

    // Calculate depths
    function computeDepth(blockId, visited = new Set()) {
      if (visited.has(blockId)) return 0; // Prevent infinite cycle
      visited.add(blockId);

      const block = blockMap.get(blockId);
      if (!block) return 0;
      if (!block.parentId || block.parentId === block.id || block.id === rootDocId) {
        return 0;
      }
      if (block.parentId === rootDocId) {
        return 1;
      }
      const parentDepth = computeDepth(block.parentId, visited);
      return parentDepth + 1;
    }

    blocks.forEach(b => {
      const depth = computeDepth(b.id);
      const entry = blockMap.get(b.id);
      entry.depth = depth;
      entry.indentDp = depth * 20;
    });

    // Determine collapsed state: find all collapsed block IDs
    const collapsedIds = new Set(
      blocks.filter(b => b.isCollapsed === 1 || b.isCollapsed === true).map(b => b.id)
    );

    // Helper: is block an indirect descendant of any collapsed block
    function isHiddenByCollapse(blockId) {
      const visited = new Set();
      let curr = blockMap.get(blockId);
      while (curr && curr.parentId && curr.parentId !== rootDocId) {
        if (visited.has(curr.id)) return false;
        visited.add(curr.id);
        if (collapsedIds.has(curr.parentId)) {
          return true;
        }
        curr = blockMap.get(curr.parentId);
      }
      return false;
    }

    // Sort by sortOrder ASC
    const sorted = Array.from(blockMap.values()).sort((a, b) => (a.sortOrder || 0) - (b.sortOrder || 0));

    // Visible blocks exclude those whose parent or ancestor is collapsed
    const visibleBlocks = sorted.filter(b => !isHiddenByCollapse(b.id));

    return {
      allBlocks: sorted,
      visibleBlocks,
    };
  }

  /**
   * Extracts WikiLinks [[Target]] from content.
   */
  static extractWikiLinks(content) {
    if (!content) return [];
    const regex = /\[\[(.*?)\]\]/g;
    const matches = [];
    let match;
    while ((match = regex.exec(content)) !== null) {
      matches.push(match[1].trim());
    }
    return matches;
  }

  /**
   * Extracts block references ((blockId)) from content.
   */
  static extractBlockRefs(content) {
    if (!content) return [];
    const regex = /\(\(([a-zA-Z0-9_-]+)\)\)/g;
    const matches = [];
    let match;
    while ((match = regex.exec(content)) !== null) {
      matches.push(match[1].trim());
    }
    return matches;
  }

  /**
   * Basic markdown inline tokens parser for reader rendering.
   */
  static parseMarkdownInline(text) {
    if (!text) return [];
    const tokens = [];

    // Check for bold, italic, code
    const hasBold = /\*\*(.*?)\*\*/.test(text);
    const hasItalic = /\*(.*?)\*/.test(text);
    const hasCode = /`(.*?)`/.test(text);
    const isTask = /^\[([ xX])\]\s+(.*)/.test(text);

    return {
      raw: text,
      hasBold,
      hasItalic,
      hasCode,
      isTask,
      isTaskCompleted: /^\[[xX]\]/.test(text),
    };
  }
}

module.exports = {
  ReaderEngine,
};
