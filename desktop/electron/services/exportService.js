// Medha Windows Desktop — Export Service
// Generates Markdown, structured JSON, and lossless Vector SVG

class ExportService {
    static exportToMarkdown(doc, blocks) {
        let lines = [];
        lines.push(`# ${doc.content || 'Untitled Note'}`);
        lines.push('');

        for (const block of blocks) {
            const indentLevel = block.parentId && block.parentId !== doc.id ? '    ' : '';
            switch (block.type) {
                case 'doc':
                case 'inkDoc':
                    continue;
                case 'heading1':
                    lines.push(`\n# ${block.content}\n`);
                    break;
                case 'heading2':
                    lines.push(`\n## ${block.content}\n`);
                    break;
                case 'heading3':
                    lines.push(`\n### ${block.content}\n`);
                    break;
                case 'paragraph':
                    lines.push(`${indentLevel}${block.content}`);
                    lines.push('');
                    break;
                case 'bulletList':
                    lines.push(`${indentLevel}- ${block.content}`);
                    break;
                case 'taskList': {
                    const check = block.isCompleted ? 'x' : ' ';
                    lines.push(`${indentLevel}- [${check}] ${block.content}`);
                    break;
                }
                case 'codeBlock':
                    lines.push(`\`\`\`\n${block.content}\n\`\`\`\n`);
                    break;
                case 'quote':
                    lines.push(`> ${block.content}\n`);
                    break;
                case 'callout':
                    lines.push(`> [!NOTE]\n> ${block.content}\n`);
                    break;
                case 'blockRef':
                    if (block.refTargetId) {
                        lines.push(`${indentLevel}((${block.refTargetId}))`);
                    }
                    break;
                default:
                    lines.push(`${indentLevel}${block.content}`);
            }
        }
        return lines.join('\n');
    }

    static exportToJSON(doc, blocks) {
        return JSON.stringify({ document: doc, blocks }, null, 2);
    }

    static exportInkToSVG(pagePayload, pageWidth = 794, pageHeight = 1123) {
        let svg = `<?xml version="1.0" encoding="UTF-8"?>\n`;
        svg += `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${pageWidth} ${pageHeight}" width="${pageWidth}" height="${pageHeight}">\n`;
        svg += `  <rect width="100%" height="100%" fill="#FFFFFF" />\n`;

        const strokes = pagePayload.strokes || [];
        for (const s of strokes) {
            if (!s.points || s.points.length === 0) continue;
            const pts = s.points;
            let d = `M ${pts[0].x.toFixed(1)} ${pts[0].y.toFixed(1)}`;
            for (let i = 1; i < pts.length; i++) {
                d += ` L ${pts[i].x.toFixed(1)} ${pts[i].y.toFixed(1)}`;
            }
            const color = s.colorHex || '#1E293B';
            const width = s.baseWidth || 2.5;
            const opacity = s.opacity != null ? s.opacity : (s.tool === 'highlighter' ? 0.35 : 1.0);

            svg += `  <path d="${d}" stroke="${color}" stroke-width="${width}" stroke-linecap="round" stroke-linejoin="round" fill="none" opacity="${opacity}" />\n`;
        }

        svg += `</svg>\n`;
        return svg;
    }
}

module.exports = { ExportService };
