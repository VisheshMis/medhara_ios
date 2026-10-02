// Medha Web — Link & Reference Parser
// Mirrors LinkParser.swift for bidirectional [[WikiLinks]] and ((block-refs)).

export class LinkParser {
    static blockRefRegex = /\(\((b-[a-zA-Z0-9\-]+)\)\)/g;
    static wikiLinkRegex = /\[\[(.*?)\]\]/g;

    static extractBlockRefs(text) {
        if (!text) return [];
        const matches = [];
        let match;
        const regex = new RegExp(this.blockRefRegex);
        while ((match = regex.exec(text)) !== null) {
            matches.push({
                blockId: match[1],
                raw: match[0],
                index: match.index
            });
        }
        return matches;
    }

    static extractWikiLinks(text) {
        if (!text) return [];
        const matches = [];
        let match;
        const regex = new RegExp(this.wikiLinkRegex);
        while ((match = regex.exec(text)) !== null) {
            const target = (match[1] || '').trim();
            if (target) {
                matches.push({
                    target,
                    raw: match[0],
                    index: match.index
                });
            }
        }
        return matches;
    }

    static containsBlockRef(text, targetId) {
        return text ? text.includes(`((${targetId}))`) : false;
    }

    static containsWikiLink(text, target) {
        return text ? text.includes(`[[${target}]]`) : false;
    }
}
