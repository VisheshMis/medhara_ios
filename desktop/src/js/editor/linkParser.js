// Medha Windows Desktop — Link & WikiLink Parsing Service
// 100% faithful port of LinkParser.swift
// Extracts ((b-uuid)) block transclusions and [[WikiLinks]]

const LinkParser = {
    blockRefRegex: /\(\((b-[a-zA-Z0-9\-]+)\)\)/g,
    wikiLinkRegex: /\[\[(.*?)\]\]/g,

    extractBlockRefs(text) {
        if (!text) return [];
        const refs = [];
        const regex = new RegExp(this.blockRefRegex.source, 'g');
        let match;
        while ((match = regex.exec(text)) !== null) {
            refs.push({
                id: match[1],
                blockId: match[1],
                index: match.index
            });
        }
        return refs;
    },

    extractWikiLinks(text) {
        if (!text) return [];
        const links = [];
        const regex = new RegExp(this.wikiLinkRegex.source, 'g');
        let match;
        while ((match = regex.exec(text)) !== null) {
            const rawTarget = match[1].trim();
            if (rawTarget.length > 0) {
                links.push({
                    id: `${rawTarget}-${match.index}`,
                    target: rawTarget,
                    index: match.index
                });
            }
        }
        return links;
    },

    containsBlockRef(text, targetId) {
        if (!text || !targetId) return false;
        return text.includes(`((${targetId}))`);
    },

    containsWikiLink(text, target) {
        if (!text || !target) return false;
        return text.includes(`[[${target}]]`);
    }
};

if (typeof module !== 'undefined') {
    module.exports = { LinkParser };
}
