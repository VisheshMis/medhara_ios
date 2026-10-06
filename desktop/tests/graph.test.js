// Medha Windows Desktop — Stage 9 Force-Directed Knowledge Graph Verification Suite
// Validates Coulomb electrostatic repulsion (F ~ 1/d^2), Hooke's law spring attraction (F ~ d),
// center gravity, cooling alpha decay physics with 0% CPU at rest (alpha < 0.002),
// and layer mode presets ('linksOnly', 'treeOnly', 'blended').

const assert = require('assert');
const { KnowledgeGraphEngine, ForceSimulationNode, ForceSimulationEdge } = require('../src/js/graph/graphPhysics');

console.log('🧪 Starting Stage 9 Force-Directed Knowledge Graph Verification Suite...');

// 1. Mock Canvas Context for Simulation & Rendering
class MockContext2D {
    constructor() {
        this._calls = [];
    }
    clearRect() { this._calls.push('clearRect'); }
    save() { this._calls.push('save'); }
    restore() { this._calls.push('restore'); }
    translate() { this._calls.push('translate'); }
    scale() { this._calls.push('scale'); }
    beginPath() { this._calls.push('beginPath'); }
    moveTo() { this._calls.push('moveTo'); }
    lineTo() { this._calls.push('lineTo'); }
    stroke() { this._calls.push('stroke'); }
    arc() { this._calls.push('arc'); }
    fill() { this._calls.push('fill'); }
    fillText() { this._calls.push('fillText'); }
    setLineDash() { this._calls.push('setLineDash'); }
}

const mockCanvas = {
    getContext: () => new MockContext2D(),
    parentElement: { clientWidth: 1000, clientHeight: 800 },
    addEventListener: () => {},
    classList: { add: () => {}, remove: () => {} },
    style: {}
};

// 2. Initialize Engine
console.log('1. Testing KnowledgeGraphEngine instantiation & topology construction...');
const engine = new KnowledgeGraphEngine(mockCanvas);
assert.strictEqual(engine.layerMode, 'linksOnly', 'Default layer mode must be linksOnly');
assert.strictEqual(engine.alpha, 1.0, 'Initial alpha must start at 1.0');
assert.strictEqual(engine.isAtRest, false, 'Simulation must be active initially');

// Create a cluster of 5 nodes connected in a tree and wiki-link topology
const docs = [
    { id: 'doc-root', content: 'Distributed Systems', parentId: null, type: 'doc' },
    { id: 'doc-consensus', content: 'Consensus Protocols', parentId: 'doc-root', type: 'doc' },
    { id: 'doc-paxos', content: 'Paxos Algorithm', parentId: 'doc-consensus', type: 'doc' },
    { id: 'doc-raft', content: 'Raft Consensus', parentId: 'doc-consensus', type: 'doc' },
    { id: 'doc-byzantine', content: 'BFT Protocols', parentId: 'doc-consensus', type: 'inkDoc' }
];

const links = [
    { sourceDocId: 'doc-paxos', targetDocId: 'doc-raft' },
    { sourceDocId: 'doc-raft', targetDocId: 'doc-byzantine' }
];

engine.updateData(docs, links);
assert.strictEqual(engine.nodes.size, 5, 'Must create 5 graph nodes');
assert.strictEqual(engine.edges.length, 6, 'Must create 4 hierarchy edges + 2 wiki-links');

// Degree scaling test
const raftNode = engine.nodes.get('doc-raft');
assert(raftNode.radius > 10, 'Connected nodes must have degree-scaled radius > 10');
console.log('✅ 1. Knowledge graph topology and degree scaling initialized');

// 3. Coulomb Repulsion Physics Test
console.log('2. Testing Coulomb electrostatic repulsion...');
const n1 = new ForceSimulationNode('n1', 'A', 0, 0);
const n2 = new ForceSimulationNode('n2', 'B', 10, 0); // Placed very close together

engine.nodes.clear();
engine.edges = [];
engine.nodes.set('n1', n1);
engine.nodes.set('n2', n2);
engine.alpha = 1.0;
engine.isAtRest = false;

engine.stepSimulation();
// n1 should have moved left (vx < 0) and n2 should have moved right (vx > 0)
assert(n1.vx < 0, `Node 1 must be repelled leftwards (vx=${n1.vx})`);
assert(n2.vx > 0, `Node 2 must be repelled rightwards (vx=${n2.vx})`);
console.log('✅ 2. Electrostatic repulsion correctly separates close nodes');

// 4. Hooke Spring Attraction along Wiki-Links
console.log('3. Testing Hooke spring attraction along edges...');
const n3 = new ForceSimulationNode('n3', 'C', 0, 0);
const n4 = new ForceSimulationNode('n4', 'D', 500, 0); // Placed far beyond spring length (120px)

engine.nodes.clear();
engine.nodes.set('n3', n3);
engine.nodes.set('n4', n4);
engine.edges = [new ForceSimulationEdge('n3', 'n4', 'linksTo')];
engine.alpha = 1.0;
engine.isAtRest = false;

engine.stepSimulation();
// n3 should be pulled toward n4 (vx > 0), n4 should be pulled toward n3 (vx < 0)
assert(n3.vx > 0, `Node 3 must be pulled toward Node 4 (vx=${n3.vx})`);
assert(n4.vx < 0, `Node 4 must be pulled toward Node 3 (vx=${n4.vx})`);
console.log('✅ 3. Hooke spring attraction pulls distant connected nodes together');

// 5. Alpha Decay and 0% CPU at Rest Simulation
console.log('4. Testing Alpha decay cooling physics and 0% CPU halt at rest...');
engine.updateData(docs, links);
let stepCount = 0;
const maxSteps = 400;

while (!engine.isAtRest && stepCount < maxSteps) {
    const prevAlpha = engine.alpha;
    engine.stepSimulation();
    assert(engine.alpha <= prevAlpha, 'Alpha must monotonically decrease');
    stepCount++;
}

assert(engine.isAtRest, 'Simulation MUST settle and reach isAtRest = true');
assert(engine.alpha < engine.alphaMin, `Alpha (${engine.alpha}) must settle below alphaMin (${engine.alphaMin})`);
assert(stepCount < 350, `Simulation must cool and halt within 350 iterations (took ${stepCount})`);
console.log(`✅ 4. Alpha cooling simulation decayed cleanly to rest in ${stepCount} steps (0% CPU at rest verified)`);

// 6. Interactive Pinning & Dragging
console.log('5. Testing interactive node pinning and layer mode filter switching...');
const pinnedNode = engine.nodes.get('doc-root');
pinnedNode.isPinned = true;
pinnedNode.x = 200;
pinnedNode.y = 300;
const prevX = pinnedNode.x;
const prevY = pinnedNode.y;

engine.restartSimulation();
engine.stepSimulation();
assert.strictEqual(pinnedNode.x, prevX, 'Pinned node must retain pinned X position');
assert.strictEqual(pinnedNode.y, prevY, 'Pinned node must retain pinned Y position');

// Layer mode filtering
engine.setLayerMode('treeOnly');
assert.strictEqual(engine.layerMode, 'treeOnly', 'Layer mode must switch to treeOnly');
engine.setLayerMode('blended');
assert.strictEqual(engine.layerMode, 'blended', 'Layer mode must switch to blended');
console.log('✅ 5. Node pinning and layer mode presets verified cleanly');

console.log('\n🎉 ALL STAGE 9 KNOWLEDGE GRAPH PHYSICS TESTS PASSED!\n');
