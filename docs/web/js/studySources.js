// Medha Web — Free Study Knowledge Grounding Service
// Connects directly to Wikipedia, OpenAlex/CrossRef, Europe PMC, and Wiktionary from the browser.

export const StudyGroundingSource = {
    Wikipedia: 'wikipedia',
    OpenAlex: 'openalex',
    EuropePMC: 'europepmc',
    Wiktionary: 'wiktionary'
};

export const SourceMetadata = {
    [StudyGroundingSource.Wikipedia]: {
        displayName: 'Wikipedia',
        shortName: 'Wiki',
        subtitle: 'General encyclopedic overview & concepts',
        icon: '🌐'
    },
    [StudyGroundingSource.OpenAlex]: {
        displayName: 'OpenAlex Academic',
        shortName: 'Papers',
        subtitle: '250M+ scholarly research papers (STEM, CS, Math)',
        icon: '🎓'
    },
    [StudyGroundingSource.EuropePMC]: {
        displayName: 'Europe PMC',
        shortName: 'BioMed',
        subtitle: 'Biomedical, clinical, and life sciences research',
        icon: '🧬'
    },
    [StudyGroundingSource.Wiktionary]: {
        displayName: 'Wiktionary',
        shortName: 'Definitions',
        subtitle: 'Precise academic terminology & etymology',
        icon: '📖'
    }
};

class StudyKnowledgeService {
    constructor() {
        this.cache = new Map();
    }

    // Concurrent multi-source fetch
    async fetchGroundedKnowledge(query, sources, isCompact = false) {
        const trimmed = (query || '').trim();
        if (!trimmed || !sources || sources.length === 0) return [];

        try {
            const promises = sources.map((source) => this.fetchSnippet(trimmed, source, isCompact));
            // Ensure overall timeout: finish within 4.0s or proceed with whatever loaded
            const results = await Promise.race([
                Promise.all(promises),
                new Promise(resolve => setTimeout(() => resolve([]), 4000))
            ]);
            return (results || []).filter(Boolean);
        } catch (err) {
            console.warn('[StudyKnowledge] Fetch grounded knowledge failed:', err);
            return [];
        }
    }

    async fetchSnippet(query, source, isCompact = false) {
        const cacheKey = `${source}:${query.toLowerCase().trim()}:${isCompact}`;
        if (this.cache.has(cacheKey)) {
            return this.cache.get(cacheKey);
        }

        let snippet = null;
        try {
            switch (source) {
                case StudyGroundingSource.Wikipedia:
                    snippet = await this.fetchWikipedia(query, isCompact);
                    break;
                case StudyGroundingSource.OpenAlex:
                    snippet = await this.fetchAcademicPapers(query, isCompact);
                    break;
                case StudyGroundingSource.EuropePMC:
                    snippet = await this.fetchEuropePMC(query, isCompact);
                    break;
                case StudyGroundingSource.Wiktionary:
                    snippet = await this.fetchWiktionary(query, isCompact);
                    break;
            }
        } catch (err) {
            console.warn(`[StudyKnowledge] Failed to fetch from ${source}:`, err);
        }

        if (snippet) {
            this.cache.set(cacheKey, snippet);
        }
        return snippet;
    }

    // 1. Wikipedia Summary
    async fetchWikipedia(query, isCompact) {
        try {
            const url = `https://en.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(query)}`;
            const res = await fetch(url, {
                headers: { 'User-Agent': 'MedhaWeb-PKM/1.0' },
                signal: AbortSignal.timeout(3000)
            });
            if (!res.ok) return null;

            const data = await res.json();
            if (!data.extract) return null;

            const budget = isCompact ? 450 : 1100;
            return {
                source: StudyGroundingSource.Wikipedia,
                title: data.title || query,
                summary: data.extract.slice(0, budget),
                urlString: data.content_urls?.desktop?.page || null,
                citation: 'Wikipedia (The Free Encyclopedia)'
            };
        } catch (_) {
            return null;
        }
    }

    // 2. Academic Papers (OpenAlex with CrossRef Fallback)
    async fetchAcademicPapers(query, isCompact) {
        // Try OpenAlex first
        try {
            const alexUrl = `https://api.openalex.org/works?search=${encodeURIComponent(query)}&per_page=1`;
            const alexRes = await fetch(alexUrl, { signal: AbortSignal.timeout(3000) });
            if (alexRes.ok) {
                const alexData = await alexRes.json();
                const first = alexData.results?.[0];
                if (first && first.title) {
                    let text = '';
                    if (first.abstract_inverted_index) {
                        text = this.reconstructInvertedIndex(first.abstract_inverted_index) || '';
                    } else if (first.concepts?.length) {
                        text = 'Core Research Concepts: ' + first.concepts.slice(0, 4).map(c => c.display_name).join(', ');
                    }
                    if (text) {
                        const budget = isCompact ? 450 : 1100;
                        return {
                            source: StudyGroundingSource.OpenAlex,
                            title: first.title,
                            summary: text.slice(0, budget),
                            urlString: first.doi || null,
                            citation: `OpenAlex Academic (${first.publication_year || 'Scholarly'})`
                        };
                    }
                }
            }
        } catch (_) {}

        // Fallback to CrossRef API
        try {
            const crossUrl = `https://api.crossref.org/works?query=${encodeURIComponent(query)}&rows=1`;
            const crossRes = await fetch(crossUrl, { signal: AbortSignal.timeout(3000) });
            if (!crossRes.ok) return null;

            const crossData = await crossRes.json();
            const item = crossData.message?.items?.[0];
            if (!item || !item.title?.length) return null;

            const title = item.title[0];
            const container = item['container-title']?.[0] || 'Academic Journal';
            const rawAbstract = item.abstract ? this.stripHTML(item.abstract) : `Scholarly paper published in ${container}.`;

            const budget = isCompact ? 450 : 1100;
            return {
                source: StudyGroundingSource.OpenAlex,
                title: title,
                summary: rawAbstract.slice(0, budget),
                urlString: item.DOI ? `https://doi.org/${item.DOI}` : null,
                citation: `CrossRef Academic (${container})`
            };
        } catch (_) {
            return null;
        }
    }

    // 3. Europe PMC (Biomedical & Life Sciences)
    async fetchEuropePMC(query, isCompact) {
        try {
            const url = `https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=${encodeURIComponent(query)}&resultType=core&format=json&pageSize=1`;
            const res = await fetch(url, { signal: AbortSignal.timeout(3000) });
            if (!res.ok) return null;

            const data = await res.json();
            const article = data.resultList?.result?.[0];
            if (!article || !article.title || !article.abstractText) return null;

            const clean = this.stripHTML(article.abstractText);
            const budget = isCompact ? 450 : 1100;

            return {
                source: StudyGroundingSource.EuropePMC,
                title: article.title,
                summary: clean.slice(0, budget),
                urlString: article.doi ? `https://doi.org/${article.doi}` : null,
                citation: `Europe PMC • ${article.journalTitle || 'Life Sciences'}`
            };
        } catch (_) {
            return null;
        }
    }

    // 4. Wiktionary Definitions
    async fetchWiktionary(query, isCompact) {
        try {
            const term = query.trim().split(/\s+/)[0].toLowerCase();
            const url = `https://en.wiktionary.org/api/rest_v1/page/definition/${encodeURIComponent(term)}`;
            const res = await fetch(url, { signal: AbortSignal.timeout(3000) });
            if (!res.ok) return null;

            const data = await res.json();
            const en = data.en?.[0];
            if (!en || !en.definitions?.length) return null;

            const pos = en.partOfSpeech || 'Definition';
            const defs = en.definitions
                .slice(0, 3)
                .map(d => this.stripHTML(d.definition))
                .filter(d => d.length > 0)
                .map(d => '• ' + d);

            if (!defs.length) return null;

            const budget = isCompact ? 350 : 750;
            return {
                source: StudyGroundingSource.Wiktionary,
                title: `${term.charAt(0).toUpperCase() + term.slice(1)} (${pos})`,
                summary: defs.join('\n').slice(0, budget),
                urlString: `https://en.wiktionary.org/wiki/${encodeURIComponent(term)}`,
                citation: 'Wiktionary (Free Academic Lexicon)'
            };
        } catch (_) {
            return null;
        }
    }

    // Helper: Reconstruct inverted index into text
    reconstructInvertedIndex(index) {
        const posMap = [];
        for (const [word, positions] of Object.entries(index)) {
            for (const pos of positions) {
                posMap[pos] = word;
            }
        }
        return posMap.filter(Boolean).join(' ');
    }

    // Helper: Strip HTML tags
    stripHTML(html) {
        const tmp = document.createElement('DIV');
        tmp.innerHTML = html;
        return (tmp.textContent || tmp.innerText || '').trim();
    }
}

export const studySources = new StudyKnowledgeService();
