// Medha Windows Desktop — Academic Open APIs Catalog (8+ Sources)
// 100% faithful port of AutoNoteAPICatalog.swift & StudyKnowledgeService.swift

class APICatalog {
    static async fetchWithTimeout(url, options = {}, timeoutMs = 8000) {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), timeoutMs);
        try {
            const res = await fetch(url, { ...options, signal: controller.signal });
            clearTimeout(timeout);
            return res;
        } catch (e) {
            clearTimeout(timeout);
            throw e;
        }
    }

    // 1. Wikipedia (Summary, TOC & Outline)
    static async fetchWikipedia(query) {
        try {
            const cleanQuery = encodeURIComponent(query.trim());
            const url = `https://en.wikipedia.org/api/rest_v1/page/summary/${cleanQuery}`;
            const res = await this.fetchWithTimeout(url, {
                headers: { 'User-Agent': 'MedhaDesktop/1.0 (academic knowledge engine)' }
            });
            if (!res.ok) return null;
            const data = await res.json();
            return {
                source: 'Wikipedia',
                title: data.title,
                extract: data.extract ? data.extract.slice(0, 800) : '',
                url: data.content_urls?.desktop?.page || `https://en.wikipedia.org/wiki/${cleanQuery}`
            };
        } catch (e) {
            return null;
        }
    }

    // 2. OpenAlex (250M+ scholarly works & inverted-index abstract reconstruction)
    static async fetchOpenAlex(query) {
        try {
            const clean = encodeURIComponent(query.trim());
            const url = `https://api.openalex.org/works?search=${clean}&per-page=3`;
            const res = await this.fetchWithTimeout(url);
            if (!res.ok) return null;
            const data = await res.json();
            if (!data.results || data.results.length === 0) return null;

            const papers = data.results.map(w => {
                let abstract = '';
                if (w.abstract_inverted_index) {
                    const words = [];
                    for (const [word, positions] of Object.entries(w.abstract_inverted_index)) {
                        for (const pos of positions) {
                            words[pos] = word;
                        }
                    }
                    abstract = words.filter(Boolean).join(' ').slice(0, 500);
                }
                return {
                    title: w.title,
                    year: w.publication_year,
                    citations: w.cited_by_count,
                    doi: w.doi,
                    abstract: abstract || 'Abstract not indexed.'
                };
            });

            return {
                source: 'OpenAlex',
                papers
            };
        } catch (e) {
            return null;
        }
    }

    // 3. CrossRef (DOI Metadata & Scholarly Works)
    static async fetchCrossRef(query) {
        try {
            const clean = encodeURIComponent(query.trim());
            const url = `https://api.crossref.org/works?query=${clean}&rows=3`;
            const res = await this.fetchWithTimeout(url);
            if (!res.ok) return null;
            const data = await res.json();
            const items = data.message?.items || [];
            if (items.length === 0) return null;

            const works = items.map(it => ({
                title: it.title ? it.title[0] : 'Untitled',
                doi: it.DOI,
                publisher: it.publisher,
                year: it.created?.['date-parts']?.[0]?.[0]
            }));

            return { source: 'CrossRef', works };
        } catch (e) {
            return null;
        }
    }

    // 4. PubMed / NCBI (Biomedical & Clinical Trials)
    static async fetchPubMed(query) {
        try {
            const clean = encodeURIComponent(query.trim());
            const esearchUrl = `https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term=${clean}&retmode=json&retmax=3`;
            const searchRes = await this.fetchWithTimeout(esearchUrl);
            if (!searchRes.ok) return null;
            const searchData = await searchRes.json();
            const idList = searchData.esearchresult?.idlist || [];
            if (idList.length === 0) return null;

            const esummaryUrl = `https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=pubmed&id=${idList.join(',')}&retmode=json`;
            const sumRes = await this.fetchWithTimeout(esummaryUrl);
            if (!sumRes.ok) return null;
            const sumData = await sumRes.json();
            const resultObj = sumData.result || {};

            const articles = idList.map(pmid => {
                const doc = resultObj[pmid];
                if (!doc) return null;
                return {
                    pmid,
                    title: doc.title,
                    source: doc.source,
                    pubdate: doc.pubdate
                };
            }).filter(Boolean);

            return { source: 'PubMed', articles };
        } catch (e) {
            return null;
        }
    }

    // 5. Europe PMC (Open-Access Biomedical Excerpts)
    static async fetchEuropePMC(query) {
        try {
            const clean = encodeURIComponent(query.trim());
            const url = `https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=${clean}&format=json&pageSize=3`;
            const res = await this.fetchWithTimeout(url);
            if (!res.ok) return null;
            const data = await res.json();
            const list = data.resultList?.result || [];
            if (list.length === 0) return null;

            const papers = list.map(p => ({
                title: p.title,
                author: p.authorString,
                journal: p.journalTitle,
                year: p.pubYear,
                abstract: p.abstractText ? p.abstractText.slice(0, 400) : ''
            }));

            return { source: 'Europe PMC', papers };
        } catch (e) {
            return null;
        }
    }

    // 6. arXiv (Physics, Math, CS & AI Preprints)
    static async fetchArXiv(query) {
        try {
            const clean = encodeURIComponent(`all:${query.trim()}`);
            const url = `https://export.arxiv.org/api/query?search_query=${clean}&start=0&max_results=3`;
            const res = await this.fetchWithTimeout(url);
            if (!res.ok) return null;
            const xmlText = await res.text();

            // Simple XML regex parsing for zero-dependency parsing
            const entries = [];
            const entryRegex = /<entry>([\s\S]*?)<\/entry>/g;
            let match;
            while ((match = entryRegex.exec(xmlText)) !== null) {
                const entryContent = match[1];
                const titleMatch = /<title>([\s\S]*?)<\/title>/.exec(entryContent);
                const summaryMatch = /<summary>([\s\S]*?)<\/summary>/.exec(entryContent);
                const idMatch = /<id>([\s\S]*?)<\/id>/.exec(entryContent);

                if (titleMatch) {
                    entries.push({
                        title: titleMatch[1].replace(/\s+/g, ' ').trim(),
                        summary: summaryMatch ? summaryMatch[1].replace(/\s+/g, ' ').trim().slice(0, 400) : '',
                        url: idMatch ? idMatch[1].trim() : ''
                    });
                }
            }

            if (entries.length === 0) return null;
            return { source: 'arXiv', preprints: entries };
        } catch (e) {
            return null;
        }
    }

    // 7. Wiktionary (Etymology, Lexical Definitions)
    static async fetchWiktionary(query) {
        try {
            const clean = encodeURIComponent(query.trim().toLowerCase());
            const url = `https://en.wiktionary.org/api/rest_v1/page/definition/${clean}`;
            const res = await this.fetchWithTimeout(url, {
                headers: { 'User-Agent': 'MedhaDesktop/1.0 (academic knowledge engine)' }
            });
            if (!res.ok) return null;
            const data = await res.json();
            const english = data.en || [];
            if (english.length === 0) return null;

            const defs = [];
            for (const item of english.slice(0, 2)) {
                for (const d of (item.definitions || []).slice(0, 2)) {
                    defs.push(`(${item.partOfSpeech}) ${d.definition.replace(/<[^>]+>/g, '')}`);
                }
            }

            return { source: 'Wiktionary', definitions: defs.slice(0, 3) };
        } catch (e) {
            return null;
        }
    }

    // 8. Open Library (Books, Classic Editions)
    static async fetchOpenLibrary(query) {
        try {
            const clean = encodeURIComponent(query.trim());
            const url = `https://openlibrary.org/search.json?q=${clean}&limit=3`;
            const res = await this.fetchWithTimeout(url);
            if (!res.ok) return null;
            const data = await res.json();
            const docs = data.docs || [];
            if (docs.length === 0) return null;

            const books = docs.map(b => ({
                title: b.title,
                author: b.author_name ? b.author_name[0] : 'Unknown',
                year: b.first_publish_year
            }));

            return { source: 'Open Library', books };
        } catch (e) {
            return null;
        }
    }

    // Parallel multi-source query with parameter-aware budgeting
    static async gatherAcademicEvidence(query, domains = ['Wikipedia', 'OpenAlex', 'PubMed', 'arXiv']) {
        const fetchers = [];
        if (domains.includes('Wikipedia')) fetchers.push(this.fetchWikipedia(query));
        if (domains.includes('OpenAlex')) fetchers.push(this.fetchOpenAlex(query));
        if (domains.includes('PubMed')) fetchers.push(this.fetchPubMed(query));
        if (domains.includes('Europe PMC')) fetchers.push(this.fetchEuropePMC(query));
        if (domains.includes('arXiv')) fetchers.push(this.fetchArXiv(query));
        if (domains.includes('Wiktionary')) fetchers.push(this.fetchWiktionary(query));
        if (domains.includes('Open Library')) fetchers.push(this.fetchOpenLibrary(query));
        if (domains.includes('CrossRef')) fetchers.push(this.fetchCrossRef(query));

        const results = await Promise.allSettled(fetchers);
        const evidence = [];

        for (const res of results) {
            if (res.status === 'fulfilled' && res.value) {
                evidence.push(res.value);
            }
        }

        return evidence;
    }
}

module.exports = { APICatalog };
