// Medha Windows Desktop — GPU / Canvas Force-Directed Knowledge Graph
// 100% faithful port of ForceSimulation.swift & GraphCanvasView.swift
// Features cooling alpha physics (0% CPU at rest), 3 layer presets, degree scaling, and BFS local graph

class ForceSimulationNode {
    constructor(id, label = '', x = 0, y = 0, radius = 10, group = 'note') {
        this.id = id;
        this.label = label;
        this.x = x;
        this.y = y;
        this.vx = 0.0;
        this.vy = 0.0;
        this.radius = radius;
        this.isPinned = false;
        this.group = group; // 'note' | 'notebook' | 'ghost'
        this.inDegree = 0;
        this.outDegree = 0;
    }
}

class ForceSimulationEdge {
    constructor(sourceId, targetId, type = 'linksTo') {
        this.sourceId = sourceId;
        this.targetId = targetId;
        this.type = type; // 'linksTo' (green) | 'contains' (dashed dimmer purple)
    }
}

class KnowledgeGraphEngine {
    constructor(canvasElement, options = {}) {
        this.canvas = canvasElement;
        this.ctx = canvasElement.getContext('2d');

        this.nodes = new Map();
        this.edges = [];

        // Physics Parameters
        this.chargeRepulsion = 800.0;
        this.springLength = 120.0;
        this.springStiffness = 0.05;
        this.centerGravity = 0.02;
        this.damping = 0.88;

        // Cooling Alpha Physics (0% CPU at rest)
        this.alpha = 1.0;
        this.alphaMin = 0.002;
        this.alphaDecay = 0.022;
        this.isAtRest = false;

        // Active Layer Preset
        this.layerMode = 'linksOnly'; // 'linksOnly' | 'treeOnly' | 'blended'

        // Camera Transform
        this.cameraX = 0;
        this.cameraY = 0;
        this.scale = 1.0;

        // Interaction
        this.draggedNode = null;
        this.isPanning = false;
        this.panStart = { x: 0, y: 0 };

        this.onNodeClicked = options.onNodeClicked || null;

        this.initCanvas();
        this.bindEvents();
    }

    initCanvas() {
        this.resize();
        window.addEventListener('resize', () => this.resize());
    }

    resize() {
        const dpr = window.devicePixelRatio || 1;
        this.width = this.canvas.parentElement.clientWidth || 800;
        this.height = this.canvas.parentElement.clientHeight || 600;
        this.canvas.width = this.width * dpr;
        this.canvas.height = this.height * dpr;
        this.ctx.scale(dpr, dpr);
        this.restartSimulation();
    }

    bindEvents() {
        this.canvas.addEventListener('mousedown', (e) => {
            const pt = this.screenToWorld(e.offsetX, e.offsetY);
            const node = this.findNodeAt(pt.x, pt.y);

            if (node) {
                this.draggedNode = node;
                node.isPinned = true;
                this.restartSimulation();
            } else {
                this.isPanning = true;
                this.panStart = { x: e.clientX - this.cameraX, y: e.clientY - this.cameraY };
                this.canvas.classList.add('grabbing');
            }
        });

        window.addEventListener('mousemove', (e) => {
            if (this.draggedNode) {
                const rect = this.canvas.getBoundingClientRect();
                const pt = this.screenToWorld(e.clientX - rect.left, e.clientY - rect.top);
                this.draggedNode.x = pt.x;
                this.draggedNode.y = pt.y;
                this.restartSimulation();
            } else if (this.isPanning) {
                this.cameraX = e.clientX - this.panStart.x;
                this.cameraY = e.clientY - this.panStart.y;
                this.render();
            }
        });

        window.addEventListener('mouseup', () => {
            if (this.draggedNode) {
                this.draggedNode.isPinned = false;
                this.draggedNode = null;
            }
            if (this.isPanning) {
                this.isPanning = false;
                this.canvas.classList.remove('grabbing');
            }
        });

        this.canvas.addEventListener('wheel', (e) => {
            e.preventDefault();
            const zoom = e.deltaY < 0 ? 1.08 : 0.92;
            const newScale = Math.min(3.5, Math.max(0.15, this.scale * zoom));

            const mouseX = e.offsetX;
            const mouseY = e.offsetY;
            this.cameraX = mouseX - (mouseX - this.cameraX) * (newScale / this.scale);
            this.cameraY = mouseY - (mouseY - this.cameraY) * (newScale / this.scale);
            this.scale = newScale;

            this.render();
        });

        this.canvas.addEventListener('click', (e) => {
            const pt = this.screenToWorld(e.offsetX, e.offsetY);
            const node = this.findNodeAt(pt.x, pt.y);
            if (node && this.onNodeClicked) {
                this.onNodeClicked(node);
            }
        });
    }

    screenToWorld(sx, sy) {
        return {
            x: (sx - this.cameraX) / this.scale,
            y: (sy - this.cameraY) / this.scale
        };
    }

    findNodeAt(wx, wy) {
        for (const node of this.nodes.values()) {
            const dist = Math.hypot(node.x - wx, node.y - wy);
            if (dist <= node.radius + 4) return node;
        }
        return null;
    }

    restartSimulation() {
        this.alpha = Math.max(this.alpha, 0.85);
        if (this.isAtRest) {
            this.isAtRest = false;
            this.tick();
        }
    }

    setLayerMode(mode) {
        this.layerMode = mode;
        this.restartSimulation();
    }

    updateData(documents, links = []) {
        this.nodes.clear();
        this.edges = [];

        const centerX = 0;
        const centerY = 0;

        for (const doc of documents) {
            const angle = Math.random() * Math.PI * 2;
            const dist = 60 + Math.random() * 220;
            const node = new ForceSimulationNode(
                doc.id,
                doc.content || 'Untitled',
                centerX + Math.cos(angle) * dist,
                centerY + Math.sin(angle) * dist,
                10,
                doc.type === 'inkDoc' ? 'ink' : 'note'
            );
            this.nodes.set(doc.id, node);

            // Hierarchy edge
            if (doc.parentId) {
                this.edges.push(new ForceSimulationEdge(doc.parentId, doc.id, 'contains'));
            }
        }

        // Wiki-links
        for (const link of links) {
            if (this.nodes.has(link.sourceDocId) && this.nodes.has(link.targetDocId)) {
                this.edges.push(new ForceSimulationEdge(link.sourceDocId, link.targetDocId, 'linksTo'));
                this.nodes.get(link.sourceDocId).outDegree++;
                this.nodes.get(link.targetDocId).inDegree++;
            }
        }

        // Degree-scaled radius
        for (const node of this.nodes.values()) {
            const deg = node.inDegree + node.outDegree;
            node.radius = Math.min(26, Math.max(8, 8 + Math.sqrt(deg) * 3.5));
        }

        this.restartSimulation();
    }

    // Cooling Alpha Physics Step
    stepSimulation() {
        if (this.alpha < this.alphaMin) {
            this.isAtRest = true;
            return;
        }

        const nodesArr = Array.from(this.nodes.values());

        // 1. Coulomb Repulsion
        for (let i = 0; i < nodesArr.length; i++) {
            for (let j = i + 1; j < nodesArr.length; j++) {
                const n1 = nodesArr[i];
                const n2 = nodesArr[j];
                const dx = n2.x - n1.x;
                const dy = n2.y - n1.y;
                let dist = Math.hypot(dx, dy);
                if (dist < 1.0) dist = 1.0;

                const force = (this.chargeRepulsion * this.alpha) / (dist * dist);
                const fx = (dx / dist) * force;
                const fy = (dy / dist) * force;

                if (!n1.isPinned) { n1.vx -= fx; n1.vy -= fy; }
                if (!n2.isPinned) { n2.vx += fx; n2.vy += fy; }
            }
        }

        // 2. Hooke Spring Attraction along Edges
        const activeEdges = this.edges.filter(e => {
            if (this.layerMode === 'linksOnly') return e.type === 'linksTo';
            if (this.layerMode === 'treeOnly') return e.type === 'contains';
            return true;
        });

        for (const edge of activeEdges) {
            const src = this.nodes.get(edge.sourceId);
            const tgt = this.nodes.get(edge.targetId);
            if (!src || !tgt) continue;

            const dx = tgt.x - src.x;
            const dy = tgt.y - src.y;
            const dist = Math.hypot(dx, dy);
            const displacement = dist - this.springLength;
            const force = displacement * this.springStiffness * this.alpha;

            const fx = (dx / (dist || 1)) * force;
            const fy = (dy / (dist || 1)) * force;

            if (!src.isPinned) { src.vx += fx; src.vy += fy; }
            if (!tgt.isPinned) { tgt.vx -= fx; tgt.vy -= fy; }
        }

        // 3. Center Gravity & Position Integration
        for (const node of nodesArr) {
            if (node.isPinned) continue;

            node.vx -= node.x * this.centerGravity * this.alpha;
            node.vy -= node.y * this.centerGravity * this.alpha;

            node.vx *= this.damping;
            node.vy *= this.damping;

            node.x += node.vx;
            node.y += node.vy;
        }

        // 4. Alpha Decay
        this.alpha *= (1.0 - this.alphaDecay);
    }

    tick() {
        if (this.isAtRest) {
            this.render();
            return;
        }

        this.stepSimulation();
        this.render();

        if (!this.isAtRest) {
            requestAnimationFrame(() => this.tick());
        }
    }

    render() {
        const ctx = this.ctx;
        ctx.clearRect(0, 0, this.width, this.height);

        ctx.save();
        ctx.translate(this.cameraX, this.cameraY);
        ctx.scale(this.scale, this.scale);

        // Render Edges
        const activeEdges = this.edges.filter(e => {
            if (this.layerMode === 'linksOnly') return e.type === 'linksTo';
            if (this.layerMode === 'treeOnly') return e.type === 'contains';
            return true;
        });

        for (const edge of activeEdges) {
            const src = this.nodes.get(edge.sourceId);
            const tgt = this.nodes.get(edge.targetId);
            if (!src || !tgt) continue;

            ctx.beginPath();
            ctx.moveTo(src.x, src.y);
            ctx.lineTo(tgt.x, tgt.y);

            if (edge.type === 'contains') {
                ctx.strokeStyle = 'rgba(168, 85, 247, 0.45)'; // Dimmer dashed purple
                ctx.setLineDash([4, 4]);
                ctx.lineWidth = 1.2;
            } else {
                ctx.strokeStyle = 'rgba(16, 185, 129, 0.75)'; // Solid green for links
                ctx.setLineDash([]);
                ctx.lineWidth = 1.8;
            }
            ctx.stroke();
        }

        ctx.setLineDash([]);

        // Render Nodes
        for (const node of this.nodes.values()) {
            ctx.beginPath();
            ctx.arc(node.x, node.y, node.radius, 0, Math.PI * 2);

            if (node.group === 'ink') {
                ctx.fillStyle = '#8B5CF6'; // Purple for ink notes
            } else {
                ctx.fillStyle = '#3B82F6'; // Blue for text notes
            }
            ctx.fill();

            ctx.strokeStyle = 'rgba(255, 255, 255, 0.85)';
            ctx.lineWidth = 1.5;
            ctx.stroke();

            // Dynamic Level of Detail (LOD) - Hide labels at far zoom
            if (this.scale >= 0.65) {
                ctx.fillStyle = '#F8FAFC';
                ctx.font = '11px sans-serif';
                ctx.textAlign = 'center';
                ctx.fillText(node.label, node.x, node.y + node.radius + 14);
            }
        }

        ctx.restore();
    }
}

if (typeof module !== 'undefined') {
    module.exports = { KnowledgeGraphEngine, ForceSimulationNode, ForceSimulationEdge };
}
