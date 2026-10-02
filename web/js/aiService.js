// Medha Web — AI Engine & Socratic Service
// Supports Local AI (Ollama/LM Studio), Gemini, and OpenAI with <think> tag stripping for DeepSeek-R1.

import { studySources, StudyGroundingSource } from './studySources.js';

export const AIProvider = {
    Local: 'local',
    Groq: 'groq',
    Gemini: 'gemini',
    OpenAI: 'openai'
};

export class AIService {
    constructor() {
        this.provider = localStorage.getItem('medha_ai_provider') || AIProvider.Local;
        this.localEndpoint = localStorage.getItem('medha_ai_local_endpoint') || 'http://localhost:11434/v1';
        this.model = localStorage.getItem('medha_ai_model') || 'qwen2.5:1.5b';
        this.apiKey = localStorage.getItem('medha_ai_api_key') || '';
        this.enabledSources = JSON.parse(
            localStorage.getItem('medha_ai_study_sources') ||
            JSON.stringify([StudyGroundingSource.Wikipedia, StudyGroundingSource.OpenAlex])
        );
    }

    saveSettings({ provider, localEndpoint, model, apiKey, enabledSources }) {
        if (provider) {
            this.provider = provider;
            localStorage.setItem('medha_ai_provider', provider);
        }
        if (localEndpoint) {
            this.localEndpoint = localEndpoint;
            localStorage.setItem('medha_ai_local_endpoint', localEndpoint);
        }
        if (model) {
            this.model = model;
            localStorage.setItem('medha_ai_model', model);
        }
        if (apiKey !== undefined) {
            this.apiKey = apiKey;
            localStorage.setItem('medha_ai_api_key', apiKey);
        }
        if (enabledSources) {
            this.enabledSources = enabledSources;
            localStorage.setItem('medha_ai_study_sources', JSON.stringify(enabledSources));
        }
    }

    async validateConnection({ provider, localEndpoint, model, apiKey }) {
        const prov = provider || this.provider;
        const ep = (localEndpoint || this.localEndpoint).trim();
        const key = apiKey !== undefined ? apiKey.trim() : this.apiKey;
        const mdl = model || this.model;

        if (prov === AIProvider.Local) {
            let base = ep.replace(/\/+$/, '');
            if (!base.startsWith('http://') && !base.startsWith('https://')) {
                base = 'http://' + base;
            }
            const rawBase = base.replace(/\/v1$/, '').replace(/\/chat\/completions$/, '').replace(/\/+$/, '');
            const testChatUrl = this.resolveChatCompletionsUrl(base);

            let discoveredModels = [];
            let isConnected = false;
            let errorDetail = '';

            // Try 1: OpenAI compatible /v1/models (LM Studio, Ollama, etc.)
            try {
                const res = await fetch(`${rawBase}/v1/models`, { method: 'GET', signal: AbortSignal.timeout(4000) });
                if (res.ok) {
                    const data = await res.json();
                    if (data.data && Array.isArray(data.data)) {
                        discoveredModels = data.data.map(m => m.id);
                        isConnected = true;
                    }
                }
            } catch (err) {
                errorDetail = err.message || '';
            }

            // Try 2: Native Ollama /api/tags
            if (!isConnected) {
                try {
                    const res = await fetch(`${rawBase}/api/tags`, { method: 'GET', signal: AbortSignal.timeout(4000) });
                    if (res.ok) {
                        const data = await res.json();
                        if (data.models && Array.isArray(data.models)) {
                            discoveredModels = data.models.map(m => m.name || m.model);
                            isConnected = true;
                        }
                    }
                } catch (err) {
                    if (!errorDetail) errorDetail = err.message || '';
                }
            }

            // Try 3: Direct ping to resolved completions endpoint
            if (!isConnected && mdl) {
                try {
                    const res = await fetch(testChatUrl, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({
                            model: mdl,
                            messages: [{ role: 'user', content: 'Ping' }],
                            max_tokens: 2
                        }),
                        signal: AbortSignal.timeout(4000)
                    });
                    if (res.ok || res.status === 400 || res.status === 404) {
                        isConnected = true;
                    }
                } catch (err) {
                    if (!errorDetail) errorDetail = err.message || '';
                }
            }

            if (isConnected) {
                if (discoveredModels.length > 0) {
                    return {
                        success: true,
                        message: `Connected! Discovered ${discoveredModels.length} installed model(s). Endpoint: ${testChatUrl}`,
                        models: discoveredModels
                    };
                } else {
                    return {
                        success: true,
                        message: `Server reachable at ${rawBase}. Endpoint: ${testChatUrl}`,
                        models: []
                    };
                }
            } else {
                return {
                    success: false,
                    message: `Could not connect to ${ep}. Ensure your server is running. If using Ollama, enable CORS via: OLLAMA_ORIGINS="*" ollama serve`,
                    error: errorDetail,
                    models: []
                };
            }
        } else if (prov === AIProvider.Gemini) {
            if (!key) {
                return { success: false, message: 'Google Gemini API key cannot be empty.' };
            }
            const targetModel = mdl.includes('gemini') ? mdl : 'gemini-2.5-flash';
            const url = `https://generativelanguage.googleapis.com/v1beta/models/${targetModel}:generateContent?key=${key}`;
            try {
                const res = await fetch(url, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        contents: [{ parts: [{ text: 'Ping' }] }]
                    }),
                    signal: AbortSignal.timeout(6000)
                });
                if (res.ok) {
                    return { success: true, message: `Key verified successfully with ${targetModel}!` };
                } else {
                    const errText = await res.text();
                    return { success: false, message: `Gemini error (${res.status}): ${errText.slice(0, 140)}` };
                }
            } catch (err) {
                return { success: false, message: `Network error verifying Gemini: ${err.message}` };
            }
        } else if (prov === AIProvider.Groq) {
            if (!key) {
                return { success: false, message: 'Groq API key cannot be empty. Get a free key at console.groq.com/keys' };
            }
            try {
                const res = await fetch('https://api.groq.com/openai/v1/models', {
                    headers: { 'Authorization': `Bearer ${key}` },
                    signal: AbortSignal.timeout(6000)
                });
                if (res.ok) {
                    const data = await res.json();
                    const models = (data.data || [])
                        .map(m => m.id)
                        .filter(id => !id.includes('whisper') && !id.includes('guard') && !id.includes('safeguard') && !id.includes('audio') && !id.includes('tts'));
                    const fallbackModels = ['qwen/qwen3.8-27b', 'openai/gpt-oss-120b', 'openai/gpt-oss-20b', 'allam-2-7b'];
                    return {
                        success: true,
                        message: 'Groq API verified! Fast LPU inference ready.',
                        models: models.length > 0 ? models : fallbackModels
                    };
                } else {
                    const errText = await res.text();
                    return { success: false, message: `Groq error (${res.status}): ${errText.slice(0, 140)}` };
                }
            } catch (err) {
                return { success: false, message: `Network error verifying Groq: ${err.message}` };
            }
        } else if (prov === AIProvider.OpenAI) {
            if (!key) {
                return { success: false, message: 'OpenAI API key cannot be empty.' };
            }
            try {
                const res = await fetch('https://api.openai.com/v1/models', {
                    headers: { 'Authorization': `Bearer ${key}` },
                    signal: AbortSignal.timeout(6000)
                });
                if (res.ok) {
                    const data = await res.json();
                    const models = (data.data || []).map(m => m.id).filter(id => id.includes('gpt'));
                    return { success: true, message: 'OpenAI API key verified successfully!', models };
                } else {
                    const errText = await res.text();
                    return { success: false, message: `OpenAI error (${res.status}): ${errText.slice(0, 140)}` };
                }
            } catch (err) {
                return { success: false, message: `Network error verifying OpenAI: ${err.message}` };
            }
        }

        return { success: false, message: 'Unknown provider.' };
    }


    resolveChatCompletionsUrl(endpoint) {
        let ep = (endpoint || this.localEndpoint || 'http://localhost:11434/v1').trim();
        if (!ep.startsWith('http://') && !ep.startsWith('https://')) {
            ep = 'http://' + ep;
        }
        ep = ep.replace(/\/+$/, '');
        if (ep.endsWith('/chat/completions')) {
            return ep;
        }
        if (ep.endsWith('/v1')) {
            return `${ep}/chat/completions`;
        }
        return `${ep}/v1/chat/completions`;
    }

    isCompactModel(modelName) {
        const m = (modelName || this.model).toLowerCase();
        return m.includes('1b') || m.includes('1.5b') || m.includes('2b') || m.includes('3b');
    }

    // --- Reasoning Tag Stripper (<think> ... </think>) & Resilient JSON Extractor ---
    static sanitizeLLMJSONOutput(rawText) {
        if (!rawText) return '{}';
        let clean = rawText;

        // 1. Strip reasoning blocks from models like DeepSeek-R1 / QwQ (<think> ... </think>)
        clean = clean.replace(/<think>[\s\S]*?<\/think>/gi, '');

        // If unclosed <think> tag
        const thinkStart = clean.indexOf('<think>');
        if (thinkStart !== -1) {
            clean = clean.slice(0, thinkStart);
        }
        clean = clean.trim();

        // 2. Extract content from markdown code fences if present
        const fenceMatch = clean.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
        if (fenceMatch && fenceMatch[1]) {
            clean = fenceMatch[1].trim();
        }

        // 3. Fallback: isolate innermost JSON structure (either { ... } or [ ... ])
        const firstBrace = clean.indexOf('{');
        const firstBracket = clean.indexOf('[');

        let startIndex = -1;
        let endIndex = -1;

        if (firstBrace !== -1 && (firstBracket === -1 || firstBrace < firstBracket)) {
            // Object comes first
            const lastBrace = clean.lastIndexOf('}');
            if (lastBrace > firstBrace) {
                startIndex = firstBrace;
                endIndex = lastBrace + 1;
            }
        } else if (firstBracket !== -1) {
            // Array comes first
            const lastBracket = clean.lastIndexOf(']');
            if (lastBracket > firstBracket) {
                startIndex = firstBracket;
                endIndex = lastBracket + 1;
            }
        }

        if (startIndex !== -1 && endIndex !== -1) {
            clean = clean.slice(startIndex, endIndex);
        }

        // 4. Remove trailing commas before } or ] which compact models frequently emit
        clean = clean.replace(/,\s*([\]}])/g, '$1');

        return clean.trim();
    }

    // Fallback: Parse markdown headings and bullet lists into hierarchical structure
    parseMarkdownHierarchy(rawText, fallbackTitle = 'Current Note') {
        const lines = rawText.split('\n');
        const items = [];
        let currentItem = null;
        let currentBlocks = [];

        const commitCurrent = () => {
            if (currentItem) {
                currentItem.blocks = currentBlocks.length > 0
                    ? currentBlocks
                    : [{ typeString: 'paragraph', content: 'Detailed conceptual overview.' }];
                items.push(currentItem);
                currentItem = null;
                currentBlocks = [];
            }
        };

        for (const rawLine of lines) {
            const line = rawLine.trim();
            if (!line) continue;

            // Check if heading: #, ##, ###, #### or numbered like 1. **Title** or - **Title**
            const headingMatch = line.match(/^(?:#{1,4}\s+|\d+\.\s+\*\*|[\-\*]\s+\*\*)([^\*#]+)\*?/) ||
                                 line.match(/^(?:#{1,4}\s+)(.+)$/) ||
                                 line.match(/^\d+\.\s+(.+)$/);

            if (headingMatch) {
                commitCurrent();
                const title = headingMatch[1].replace(/[:\*]/g, '').trim();
                currentItem = {
                    title: title || 'Subtopic',
                    summary: '',
                    blocks: [],
                    children: []
                };
            } else if (currentItem) {
                currentBlocks.push({
                    typeString: line.startsWith('- ') || line.startsWith('* ') ? 'bulletList' : 'paragraph',
                    content: line.replace(/^[\-\*]\s+/, '')
                });
            }
        }
        commitCurrent();

        if (items.length === 0) {
            items.push({
                title: `${fallbackTitle} — Detailed Concepts`,
                summary: 'Generated concepts',
                blocks: [{ typeString: 'paragraph', content: rawText.slice(0, 500) }],
                children: []
            });
        }

        return {
            rootTitle: fallbackTitle,
            overview: `Generated ${items.length} subtopics parented under ${fallbackTitle}`,
            items
        };
    }

    normalizeHierarchyNodes(rawNodes) {
        if (!Array.isArray(rawNodes)) return [];

        return rawNodes.map((n, idx) => {
            if (typeof n === 'string') {
                return {
                    title: n,
                    summary: '',
                    blocks: [{ typeString: 'paragraph', content: '' }],
                    children: []
                };
            }
            if (!n || typeof n !== 'object') {
                return {
                    title: `Subtopic ${idx + 1}`,
                    summary: '',
                    blocks: [{ typeString: 'paragraph', content: String(n) }],
                    children: []
                };
            }

            const title = n.title || n.name || n.heading || n.topic || `Subtopic ${idx + 1}`;
            const summary = n.summary || n.overview || n.description || '';

            let blocks = [];
            if (Array.isArray(n.blocks) && n.blocks.length > 0) {
                blocks = n.blocks.map(b => {
                    if (typeof b === 'string') return { typeString: 'paragraph', content: b };
                    return {
                        typeString: b.typeString || b.type || 'paragraph',
                        content: b.content || b.text || ''
                    };
                });
            } else if (n.content || n.text || n.description || summary) {
                const text = n.content || n.text || n.description || summary;
                blocks = [{ typeString: 'paragraph', content: text }];
            } else {
                blocks = [{ typeString: 'paragraph', content: 'Detailed conceptual overview.' }];
            }

            const rawChildren = n.children || n.subtopics || n.items || [];
            const children = this.normalizeHierarchyNodes(rawChildren);

            return {
                title,
                summary,
                blocks,
                children
            };
        });
    }

    normalizeHierarchyObject(obj, fallbackTitle) {
        if (Array.isArray(obj)) {
            return {
                rootTitle: fallbackTitle,
                overview: 'Generated hierarchy from notes',
                items: this.normalizeHierarchyNodes(obj)
            };
        }

        if (obj && typeof obj === 'object') {
            const rootTitle = obj.rootTitle || obj.title || fallbackTitle;
            const overview = obj.overview || obj.summary || obj.description || `Structured downward hierarchy parented under ${rootTitle}`;
            const rawItems = obj.items || obj.subtopics || obj.sections || obj.nodes || obj.children || obj.topics || [];
            return {
                rootTitle,
                overview,
                items: this.normalizeHierarchyNodes(Array.isArray(rawItems) ? rawItems : [rawItems])
            };
        }

        return {
            rootTitle: fallbackTitle,
            overview: 'Generated hierarchy',
            items: []
        };
    }

    parseHierarchyResult(rawText, fallbackTitle = 'Current Note') {
        const cleaned = AIService.sanitizeLLMJSONOutput(rawText);
        let parsed = null;

        try {
            parsed = JSON.parse(cleaned);
        } catch (e1) {
            try {
                // Secondary repair attempt: fix unquoted single quotes
                const repaired = cleaned.replace(/'/g, '"');
                parsed = JSON.parse(repaired);
            } catch (e2) {
                console.warn('JSON parsing failed, falling back to markdown hierarchy extraction:', rawText);
                return this.parseMarkdownHierarchy(rawText, fallbackTitle);
            }
        }

        return this.normalizeHierarchyObject(parsed, fallbackTitle);
    }

    // --- Downward Hierarchy Generation ---
    async generateDownwardHierarchy({ noteTitle, noteContent, mode = 'expandSubtopics', customInstruction = null, selectedSources = null, onProgress = null }) {
        const sources = selectedSources || this.enabledSources;
        const isCompact = this.isCompactModel(this.model);

        if (onProgress) onProgress('Consulting academic sources...');

        // Fetch study knowledge
        let groundingSection = '';
        if (sources && sources.length > 0) {
            try {
                const snippets = await studySources.fetchGroundedKnowledge(noteTitle, sources, isCompact);
                if (snippets.length > 0) {
                    groundingSection = '\n### FACTUAL STUDY GROUNDING (VERIFIED KNOWLEDGE)\n';
                    for (const s of snippets) {
                        groundingSection += `[${s.source.toUpperCase()}] ${s.title}\n`;
                        groundingSection += `- Summary: ${s.summary}\n`;
                        if (s.citation) groundingSection += `- Citation: ${s.citation}\n`;
                        if (s.urlString) groundingSection += `- Link: ${s.urlString}\n`;
                        groundingSection += '\n';
                    }
                }
            } catch (srcErr) {
                console.warn('Grounding fetch warning:', srcErr);
            }
        }

        if (onProgress) onProgress(`Generating hierarchy with ${this.model || 'model'}...`);

        const bodyBudget = isCompact ? 1200 : 3500;
        const cleanBody = (noteContent || '').slice(0, bodyBudget);

        const prompt = `### ACTIVE ROOT NOTE
- Title: ${noteTitle}
- Content:
${cleanBody || '(Empty note, please expand from title)'}

### TASK & INSTRUCTION
Action: ${mode === 'summarizeAndSplit' ? 'Analyze content and split into downward modular subtopic notes.' : 'Expand this note into downward subtopics and structured concepts.'}
${customInstruction ? `Focus Area: ${customInstruction}` : ''}
${groundingSection}
Generate a strictly downward hierarchy of child notes parented under "${noteTitle}". Return valid JSON matching this schema:
{
  "overview": "Brief summary sentence of the generated hierarchy",
  "items": [
    {
      "title": "Subtopic Title",
      "blocks": [
        { "typeString": "paragraph", "content": "Concise key concept explanation." }
      ],
      "children": [
        {
          "title": "Sub-subtopic Title",
          "blocks": [
            { "typeString": "paragraph", "content": "Granular details." }
          ],
          "children": []
        }
      ]
    }
  ]
}
IMPORTANT: Output ONLY the raw JSON object. Do not include markdown codeblocks or extra conversation.`;

        const raw = await this.callLLM(prompt, {
            systemPrompt: 'You are Medha Note Architect. You organize knowledge strictly downward into trees of clean modular notes. Output ONLY raw JSON.'
        });

        return this.parseHierarchyResult(raw, noteTitle);
    }

    // --- Socratic Flashcard Evaluation ---
    async evaluateAnswer({ question, targetAnswer, hint, userAnswer }) {
        const isCompact = this.isCompactModel(this.model);
        let effectiveTarget = targetAnswer;

        if (this.enabledSources.length > 0) {
            const snippets = await studySources.fetchGroundedKnowledge(question, this.enabledSources, isCompact);
            if (snippets.length > 0) {
                effectiveTarget += `\n[Verified Grounding: ${snippets.map(s => s.summary).join(' ')}]`;
            }
        }

        const prompt = `Question: "${question}"
Target Answer / Key Concepts: "${effectiveTarget}"
${hint ? `Hint: "${hint}"` : ''}
Student Answer: "${userAnswer}"

Evaluate the student's answer. Output strictly valid JSON conforming to:
{
  "isSpotOn": boolean,
  "status": "spot_on" | "probing",
  "feedback": "Gentle, encouraging explanation pinpointing missing ideas",
  "counterQuestion": "One thought-provoking question to help them realize the missing concept, or null if spot on",
  "suggestedRating": 1 | 2 | 3 | 4
}`;

        const raw = await this.callLLM(prompt, {
            systemPrompt: 'You are Medha Socratic Tutor. Be encouraging, praise correct ideas, and gently probe misconceptions with questions.'
        });

        const cleaned = AIService.sanitizeLLMJSONOutput(raw);
        try {
            return JSON.parse(cleaned);
        } catch (e) {
            return {
                isSpotOn: true,
                status: 'spot_on',
                feedback: 'Good recall attempt.',
                counterQuestion: null,
                suggestedRating: 3
            };
        }
    }

    // --- Unified LLM Dispatcher ---
    async callLLM(userPrompt, { systemPrompt = '' } = {}) {
        if (this.provider === AIProvider.Local) {
            return this.callLocalAI(userPrompt, systemPrompt);
        } else if (this.provider === AIProvider.Groq) {
            return this.callGroq(userPrompt, systemPrompt);
        } else if (this.provider === AIProvider.Gemini) {
            return this.callGemini(userPrompt, systemPrompt);
        } else if (this.provider === AIProvider.OpenAI) {
            return this.callOpenAI(userPrompt, systemPrompt);
        }
        throw new Error('Unknown AI provider');
    }

    async callLocalAI(userPrompt, systemPrompt) {
        const url = this.resolveChatCompletionsUrl(this.localEndpoint);

        const messages = [];
        if (systemPrompt) messages.push({ role: 'system', content: systemPrompt });
        messages.push({ role: 'user', content: userPrompt });

        const payload = {
            model: this.model || 'qwen2.5:1.5b',
            messages,
            temperature: 0.3
        };

        let res;
        try {
            res = await fetch(url, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });
        } catch (fetchErr) {
            throw new Error(`Cannot connect to local AI at ${url}. Check that LM Studio / Ollama is running and CORS is enabled. (Details: ${fetchErr.message})`);
        }

        if (!res.ok) {
            const errText = await res.text();
            throw new Error(`Local AI error (${res.status} from ${url}): ${errText.slice(0, 160)}`);
        }

        const data = await res.json();
        const content = data.choices?.[0]?.message?.content || data.response || '';
        if (!content) {
            throw new Error('Local AI returned an empty response. Verify model is loaded and ready in your local server.');
        }
        return content;
    }

    async callGemini(userPrompt, systemPrompt) {
        if (!this.apiKey) throw new Error('Google Gemini API Key is required.');
        const model = this.model.includes('gemini') ? this.model : 'gemini-2.5-flash';
        const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${this.apiKey}`;

        const payload = {
            contents: [
                {
                    parts: [
                        { text: systemPrompt ? `${systemPrompt}\n\n${userPrompt}` : userPrompt }
                    ]
                }
            ],
            generationConfig: {
                temperature: 0.3
            }
        };

        const res = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        if (!res.ok) {
            const errText = await res.text();
            throw new Error(`Gemini error (${res.status}): ${errText.slice(0, 150)}`);
        }

        const data = await res.json();
        return data.candidates?.[0]?.content?.parts?.[0]?.text || '';
    }

    async callGroq(userPrompt, systemPrompt) {
        if (!this.apiKey) throw new Error('Groq API Key is required. Get a free key at console.groq.com/keys');
        const url = 'https://api.groq.com/openai/v1/chat/completions';

        const messages = [];
        if (systemPrompt) messages.push({ role: 'system', content: systemPrompt });
        messages.push({ role: 'user', content: userPrompt });

        let modelName = this.model;
        if (!modelName || modelName.includes('llama-3.3') || modelName.includes('llama3-8b')) {
            modelName = 'qwen/qwen3.8-27b';
        }

        const payload = {
            model: modelName,
            messages,
            temperature: 0.2
        };

        const res = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${this.apiKey}`
            },
            body: JSON.stringify(payload)
        });

        if (!res.ok) {
            const errText = await res.text();
            throw new Error(`Groq error (${res.status}): ${errText.slice(0, 160)}`);
        }

        const data = await res.json();
        return data.choices?.[0]?.message?.content || '';
    }

    async callOpenAI(userPrompt, systemPrompt) {
        if (!this.apiKey) throw new Error('OpenAI API Key is required.');
        const url = 'https://api.openai.com/v1/chat/completions';

        const messages = [];
        if (systemPrompt) messages.push({ role: 'system', content: systemPrompt });
        messages.push({ role: 'user', content: userPrompt });

        const payload = {
            model: this.model.includes('gpt') ? this.model : 'gpt-4o-mini',
            messages,
            temperature: 0.3
        };

        const res = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${this.apiKey}`
            },
            body: JSON.stringify(payload)
        });

        if (!res.ok) {
            const errText = await res.text();
            throw new Error(`OpenAI error (${res.status}): ${errText.slice(0, 150)}`);
        }

        const data = await res.json();
        return data.choices?.[0]?.message?.content || '';
    }
}

export const aiService = new AIService();
