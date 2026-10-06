// Medha Windows Desktop — AI & Auto-Note Service
// Supports Groq, Google Gemini, OpenAI, and Local Ollama / Self-hosted models.
// Features DeepSeek-R1 <think> regex sanitization and 11-phase Auto-Note formation pipeline.

class AIService {
    static sanitizeReasoning(raw) {
        if (!raw) return '';
        // 1. Strip <think>...</think> chain-of-thought tokens from DeepSeek-R1 / QwQ
        let clean = raw.replace(/<think>[\s\S]*?<\/think>/gi, '').trim();

        // 2. Extract JSON if wrapped in markdown code fence
        const jsonMatch = clean.match(/```(?:json)?\s*([\s\S]*?)\s*```/);
        if (jsonMatch) {
            return jsonMatch[1].trim();
        }
        return clean;
    }

    static async callProvider({ provider, model, apiKey, baseUrl, systemPrompt, userPrompt }) {
        if (provider === 'local') {
            const url = baseUrl || 'http://127.0.0.1:11434/api/generate';
            const res = await fetch(url, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    model: model || 'qwen2.5:1.5b',
                    prompt: `${systemPrompt}\n\nUser:\n${userPrompt}`,
                    stream: false
                })
            });
            if (!res.ok) throw new Error(`Local AI error: ${res.statusText}`);
            const data = await res.json();
            return this.sanitizeReasoning(data.response);
        }

        if (provider === 'gemini') {
            const key = apiKey || process.env.GEMINI_API_KEY;
            const targetModel = model || 'gemini-2.5-flash';
            const url = `https://generativelanguage.googleapis.com/v1beta/models/${targetModel}:generateContent?key=${key}`;
            const res = await fetch(url, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    contents: [{
                        role: 'user',
                        parts: [{ text: `${systemPrompt}\n\n${userPrompt}` }]
                    }]
                })
            });
            if (!res.ok) throw new Error(`Gemini API error: ${res.statusText}`);
            const data = await res.json();
            const text = data.candidates?.[0]?.content?.parts?.[0]?.text || '';
            return this.sanitizeReasoning(text);
        }

        if (provider === 'groq' || provider === 'openai') {
            const endpoint = provider === 'groq'
                ? 'https://api.groq.com/openai/v1/chat/completions'
                : 'https://api.openai.com/v1/chat/completions';
            const defaultModel = provider === 'groq' ? 'qwen/qwen3.8-27b' : 'gpt-4o-mini';

            const res = await fetch(endpoint, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${apiKey}`
                },
                body: JSON.stringify({
                    model: model || defaultModel,
                    messages: [
                        { role: 'system', content: systemPrompt },
                        { role: 'user', content: userPrompt }
                    ],
                    temperature: 0.3
                })
            });
            if (!res.ok) throw new Error(`${provider} API error: ${res.statusText}`);
            const data = await res.json();
            const text = data.choices?.[0]?.message?.content || '';
            return this.sanitizeReasoning(text);
        }

        throw new Error(`Unsupported AI provider: ${provider}`);
    }

    // Socratic answer evaluation
    static async evaluateSocraticAnswer({ card, studentAnswer, providerConfig }) {
        const systemPrompt = `You are an expert Socratic tutor evaluating a student's answer.
Card Front: "${card.front}"
Target Answer: "${card.back}"
Hint: "${card.hint || 'None'}"

Evaluate the student's typed response with constructive, rigorous feedback.
Assess factual accuracy, completeness, and conceptual grasp.
Output JSON format:
{
  "feedback": "...",
  "suggestedRating": 1|2|3|4, // 1: Again, 2: Hard, 3: Good, 4: Easy
  "isCorrect": true|false
}
JSON only.`;

        const userPrompt = `Student's answer: "${studentAnswer}"`;
        const raw = await this.callProvider({
            ...providerConfig,
            systemPrompt,
            userPrompt
        });

        try {
            return JSON.parse(this.sanitizeReasoning(raw));
        } catch (e) {
            return {
                feedback: raw,
                suggestedRating: 3,
                isCorrect: true
            };
        }
    }

    // Phase 2 Skeleton Planner
    static async planSkeleton({ topic, domain, providerConfig, evidence = '' }) {
        const systemPrompt = `You are the SKELETON PLANNER of a 2-step cognitive note synthesis system.
Design a balanced, multi-tier downward hierarchy for topic "${topic}".
Domain: ${domain || 'General Knowledge'}
Academic Evidence Context:
${evidence.slice(0, 1000)}

Enforce STRICT negative constraints:
- Do NOT use generic placeholder headings like "Overview", "Introduction", "Applications", or "Summary".
- Use CONTENT-REPRESENTATIVE headings that state the key insight or mechanism directly.
- Depth should be 2 to 3 tiers.

Output JSON:
{
  "topic": "${topic}",
  "root_doc": {
    "title": "${topic}",
    "scope": "...",
    "subtopics": [
      {
        "title": "1. [Specific Subtopic Title]",
        "scope": "...",
        "children": [
          { "title": "1.1 [Specific Child Title]", "scope": "..." },
          { "title": "1.2 [Specific Child Title]", "scope": "..." }
        ]
      },
      {
        "title": "2. [Specific Subtopic Title]",
        "scope": "...",
        "children": [
          { "title": "2.1 [Specific Child Title]", "scope": "..." }
        ]
      }
    ]
  }
}
JSON only.`;

        const userPrompt = `Generate skeleton for: "${topic}"`;
        const raw = await this.callProvider({
            ...providerConfig,
            systemPrompt,
            userPrompt
        });

        return JSON.parse(this.sanitizeReasoning(raw));
    }

    // Phase 7 Single-Node Note Writer with citations
    static async fillNoteContent({ nodeTitle, scope, depth = 'Working', providerConfig, evidence = '' }) {
        const systemPrompt = `You are the NOTE WRITER of the cognitive retention system.
Synthesize dense, evidence-backed notes for: "${nodeTitle}" (Depth: ${depth}).
Scope: ${scope || 'Comprehensive'}

Academic Evidence Provided:
${evidence.slice(0, 1200)}

Produce structured sections formatted in Markdown:
## Executive Summary
[High-density distillation]

## Core Mechanisms & Detailed Principles
[Deep explanation, formulas, architectural trade-offs]

## Comparative Dimensions
[Contrasts with related paradigms]

## Direct Evidence & Citations
[Citations referencing the evidence provided]

## Critical Verification & Boundary Limits
[Edge cases, potential failure modes, falsification limits]`;

        const userPrompt = `Write full content for: "${nodeTitle}"`;
        return await this.callProvider({
            ...providerConfig,
            systemPrompt,
            userPrompt
        });
    }
}

module.exports = { AIService };
