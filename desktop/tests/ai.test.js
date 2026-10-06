// Medha Windows Desktop — Stage 10 AI, Socratic Tutor & AutoNote Pipeline Test Suite
const assert = require('assert');
const { AIService } = require('../electron/services/aiService');
const { APICatalog } = require('../electron/services/apiCatalog');
const { AutoNotePipeline } = require('../src/js/ai/autoNotePipeline');

console.log('🧪 Starting Stage 10: Local AI Services, Socratic Tutor & AutoNote Pipeline Tests...\n');

let passedTests = 0;

function test(name, fn) {
    try {
        fn();
        console.log(`  ✅ ${name}`);
        passedTests++;
    } catch (err) {
        console.error(`  ❌ ${name}`);
        console.error(err);
        process.exit(1);
    }
}

async function asyncTest(name, fn) {
    try {
        await fn();
        console.log(`  ✅ ${name}`);
        passedTests++;
    } catch (err) {
        console.error(`  ❌ ${name}`);
        console.error(err);
        process.exit(1);
    }
}

(async () => {
    // 1. DeepSeek-R1 / QwQ <think> tag sanitization test
    test('AIService: sanitizeReasoning removes <think> reasoning tokens', () => {
        const raw = '<think>\nEvaluating user response...\nLet us verify FSRS principles...\n</think>\n{\n  "isSpotOn": true,\n  "status": "spot_on",\n  "feedback": "Flawless formulation.",\n  "suggestedRating": 4\n}';
        const clean = AIService.sanitizeReasoning(raw);
        assert(!clean.includes('<think>'), 'Should not contain open think tag');
        assert(!clean.includes('</think>'), 'Should not contain close think tag');
        assert(!clean.includes('Evaluating user response'), 'Should not contain thinking tokens');
        const parsed = JSON.parse(clean);
        assert.strictEqual(parsed.isSpotOn, true);
        assert.strictEqual(parsed.suggestedRating, 4);
    });

    test('AIService: sanitizeReasoning extracts JSON from markdown blocks', () => {
        const markdown = '```json\n{\n  "isSpotOn": false,\n  "status": "probing",\n  "feedback": "Close!",\n  "counterQuestion": "What about stability?",\n  "suggestedRating": 2\n}\n```';
        const clean = AIService.sanitizeReasoning(markdown);
        const parsed = JSON.parse(clean);
        assert.strictEqual(parsed.isSpotOn, false);
        assert.strictEqual(parsed.status, 'probing');
        assert.strictEqual(parsed.counterQuestion, 'What about stability?');
    });

    // 2. Socratic Answer Evaluation Rubric
    await asyncTest('AIService: evaluateSocraticAnswer parses valid JSON output', async () => {
        // Stub callProvider
        const origCall = AIService.callProvider;
        AIService.callProvider = async () => {
            return JSON.stringify({
                isSpotOn: true,
                status: 'spot_on',
                feedback: 'Excellent explanation of spaced repetition intervals.',
                counterQuestion: null,
                suggestedRating: 4
            });
        };

        const result = await AIService.evaluateSocraticAnswer({
            card: { front: 'What is FSRS?', back: 'Free Spaced Repetition Scheduler' },
            studentAnswer: 'A modern scheduling algorithm replacing SM-2 using stability and difficulty.',
            providerConfig: { provider: 'local' }
        });

        assert.strictEqual(result.isSpotOn, true);
        assert.strictEqual(result.status, 'spot_on');
        assert.strictEqual(result.suggestedRating, 4);
        assert.strictEqual(result.isCorrect, true);
        assert.strictEqual(result.counterQuestion, null);

        AIService.callProvider = origCall;
    });

    await asyncTest('AIService: evaluateSocraticAnswer graceful fallback when AI returns free-form text', async () => {
        const origCall = AIService.callProvider;
        AIService.callProvider = async () => 'Spot-on! You accurately captured the memory decay dynamics.';

        const result = await AIService.evaluateSocraticAnswer({
            card: { front: 'What is stability in FSRS?', back: 'Days for memory retrievability to drop to 90%' },
            studentAnswer: 'The number of days until recall drops to 90%.',
            providerConfig: { provider: 'local' }
        });

        assert.strictEqual(result.isSpotOn, true);
        assert.strictEqual(result.status, 'spot_on');
        assert.strictEqual(result.suggestedRating, 3);
        assert.strictEqual(result.isCorrect, true);

        AIService.callProvider = origCall;
    });

    // 3. Skeleton Planner
    await asyncTest('AIService: planSkeleton generates structured downward hierarchy', async () => {
        const origCall = AIService.callProvider;
        AIService.callProvider = async () => {
            return JSON.stringify({
                topic: 'Neural Networks',
                root_doc: {
                    title: 'Neural Networks',
                    scope: 'Foundations of Deep Learning',
                    subtopics: [
                        {
                            title: '1. Backpropagation Dynamics',
                            scope: 'Gradient descent and chain rule',
                            children: [
                                { title: '1.1 Automatic Differentiation', scope: 'Tape execution' }
                            ]
                        }
                    ]
                }
            });
        };

        const plan = await AIService.planSkeleton({
            topic: 'Neural Networks',
            domain: 'Machine Learning',
            providerConfig: { provider: 'local' }
        });

        assert.strictEqual(plan.topic, 'Neural Networks');
        assert.strictEqual(plan.root_doc.title, 'Neural Networks');
        assert.strictEqual(plan.root_doc.subtopics.length, 1);
        assert.strictEqual(plan.root_doc.subtopics[0].children.length, 1);

        AIService.callProvider = origCall;
    });

    // 4. Academic Evidence Catalog Open APIs
    await asyncTest('APICatalog: gatherAcademicEvidence aggregates multiple sources without crashing', async () => {
        // Test with Wikipedia and Wiktionary mock/safe timeouts
        const origFetch = APICatalog.fetchWithTimeout;
        APICatalog.fetchWithTimeout = async (url) => {
            if (url.includes('wikipedia')) {
                return {
                    ok: true,
                    json: async () => ({
                        title: 'Spaced Repetition',
                        extract: 'Spaced repetition is an evidence-based learning technique.',
                        content_urls: { desktop: { page: 'https://en.wikipedia.org/wiki/Spaced_repetition' } }
                    })
                };
            }
            if (url.includes('openalex')) {
                return {
                    ok: true,
                    json: async () => ({
                        results: [{
                            title: 'A Stochastic Model of Memory Consolidation',
                            publication_year: 2024,
                            cited_by_count: 42,
                            doi: '10.1038/example',
                            abstract_inverted_index: { 'Memory': [0], 'consolidation': [1], 'curves': [2] }
                        }]
                    })
                };
            }
            return { ok: false };
        };

        const evidence = await APICatalog.gatherAcademicEvidence('Spaced Repetition', ['Wikipedia', 'OpenAlex']);
        assert.strictEqual(evidence.length, 2, 'Should aggregate 2 sources');
        assert.strictEqual(evidence[0].source, 'Wikipedia');
        assert.strictEqual(evidence[1].source, 'OpenAlex');
        assert(evidence[0].extract.includes('evidence-based learning'));
        assert(evidence[1].papers[0].abstract.includes('Memory consolidation curves'));

        APICatalog.fetchWithTimeout = origFetch;
    });

    // 5. AutoNote 2-Step Pipeline Commitment in BlockStore
    await asyncTest('AutoNotePipeline: Step 1 generates skeletal documents & blocks in store', async () => {
        // Mock Store
        const mockStore = {
            documents: [],
            blocks: [],
            createDocument(content, parentDocId = null, notebookId = null, type = 'doc') {
                const doc = { id: `doc-${Date.now()}-${Math.random()}`, content, parentDocId, notebookId, type };
                this.documents.push(doc);
                return doc;
            },
            createBlock(type, content, rootDocId, sortOrder) {
                const blk = { id: `blk-${Date.now()}-${Math.random()}`, type, content, rootDocId, sortOrder };
                this.blocks.push(blk);
                return blk;
            },
            deleteBlock(id) {
                this.blocks = this.blocks.filter(b => b.id !== id);
            }
        };

        const pipeline = new AutoNotePipeline(mockStore);
        const rootDoc = await pipeline.executeStep1Skeleton({ topic: 'Quantum Cryptography' });

        assert(rootDoc, 'Root document should be created');
        assert(mockStore.documents.length >= 5, 'Should create root doc, 2 subtopics, and 4 child docs');
        assert(mockStore.blocks.length >= 10, 'Should create heading and callout blocks for all docs');

        const rootHeading = mockStore.blocks.find(b => b.rootDocId === rootDoc.id && b.type === 'heading1');
        assert(rootHeading, 'Root doc should have heading1 block');
        assert(rootHeading.content.includes('Quantum Cryptography'));

        // Step 2 Fill Content
        await pipeline.executeStep2FillContent({ docId: rootDoc.id, depth: 'Comprehensive' });
        const synthesizedHeadings = mockStore.blocks.filter(b => b.rootDocId === rootDoc.id && (b.type === 'heading2' || b.type === 'heading1'));
        assert(synthesizedHeadings.length >= 2, 'Should synthesize section headings into document');
    });

    console.log(`\n🎉 Stage 10 Test Suite Passed! ${passedTests}/${passedTests} tests successful.`);
})();
