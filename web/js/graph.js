// Medha Web — 2D Interactive Knowledge Graph
// HTML5 Canvas force-directed physics engine with zoom, pan, and click navigation.

export class KnowledgeGraphView {
    constructor(canvas, onSelectDoc) {
        this.canvas = canvas;
        this.ctx = canvas.getContext('2d');
        this.onSelectDoc = onSelectDoc;

        this.nodes = [];
        this.links = [];
        this.nodeMap = new Map();

        // Viewport transform
        this.transform = { x: 0, y: 0, k: 1 };
        this.isDragging = false;
        this.dragNode = null;
        this.dragStart = { x: 0, y: 0 };
        this.hoverNode = null;

        // Physics constants
        this.alpha = 1.0;
        this.alphaMin = 0.005;
        this.alphaDecay = 0.985;
        this.velocityDecay = 0.65;

        this.initEvents();
        this.resize();
        window.addEventListener('resize', () => this.resize());
    }

    resize() {
        const rect = this.canvas.parentElement.getBoundingClientRect();
        this.canvas.width = rect.width * window.devicePixelRatio;
        this.canvas.height = rect.height * window.devicePixelRatio;
        this.ctx.scale(window.devicePixelRatio, window.devicePixelRatio);
        this.width = rect.width;
        this.height = rect.height;
        if (this.transform.x === 0 && this.transform.y === 0) {
            this.transform.x = this.width / 2;
            this.transform.y = this.height / 2;
        }
        this.render();
    }

    setData(documents, activeDocId = null) {
        this.activeDocId = activeDocId;
        const oldPositions = new Map(this.nodes.map(n => [n.id, { x: n.x, y: n.y, vx: n.vx, vy: n.vy }]));

        this.nodes = documents.map((doc, i) => {
            const old = oldPositions.get(doc.id);
            const angle = (i / documents.length) * Math.PI * 2;
            const radius = 120 + Math.random() * 80;
            return {
                id: doc.id,
                title: doc.title || 'Untitled',
                parentId: doc.parentId,
                x: old ? old.x : Math.cos(angle) * radius,
                y: old ? old.y : Math.sin(angle) * radius,
                vx: old ? old.vx : (Math.random() - 0.5) * 2,
                vy: old ? old.vy : (Math.random() - 0.5) * 2,
                radius: doc.id === activeDocId ? 14 : 9,
                isPinned: false
            };
        });

        this.nodeMap = new Map(this.nodes.map(n => [n.id, n]));

        // Generate tree links (parent -> child)
        this.links = [];
        for (const n of this.nodes) {
            if (n.parentId && this.nodeMap.has(n.parentId)) {
                this.links.push({
                    source: this.nodeMap.get(n.parentId),
                    target: n,
                    distance: 75
                });
            }
        }

        this.alpha = 1.0;
        this.startSimulation();
    }

    startSimulation() {
        if (this.animId) cancelAnimationFrame(this.animId);
        const tick = () => {
            if (this.alpha > this.alphaMin) {
                this.stepPhysics();
                this.alpha *= this.alphaDecay;
                this.render();
                this.animId = requestAnimationFrame(tick);
            } else {
                this.render();
            }
        };
        this.animId = requestAnimationFrame(tick);
    }

    wakeUp() {
        this.alpha = Math.max(this.alpha, 0.3);
        this.startSimulation();
    }

    stepPhysics() {
        const repulsion = 1200;
        const n = this.nodes.length;

        // 1. Node-node repulsion
        for (let i = 0; i < n; i++) {
            const a = this.nodes[i];
            for (let j = i + 1; j < n; j++) {
                const b = this.nodes[j];
                const dx = b.x - a.x;
                const dy = b.y - a.y;
                const distSq = dx * dx + dy * dy + 1;
                const dist = Math.sqrt(distSq);
                const force = (repulsion / distSq) * this.alpha;
                const fx = (dx / dist) * force;
                const fy = (dy / dist) * force;

                if (!a.isPinned) { a.vx -= fx; a.vy -= fy; }
                if (!b.isPinned) { b.vx += fx; b.vy += fy; }
            }
        }

        // 2. Link attraction
        for (const link of this.links) {
            const a = link.source;
            const b = link.target;
            const dx = b.x - a.x;
            const dy = b.y - a.y;
            const dist = Math.sqrt(dx * dx + dy * dy) || 1;
            const delta = dist - link.distance;
            const force = delta * 0.05 * this.alpha;
            const fx = (dx / dist) * force;
            const fy = (dy / dist) * force;

            if (!a.isPinned) { a.vx += fx; a.vy += fy; }
            if (!b.isPinned) { b.vx -= fx; b.vy -= fy; }
        }

        // 3. Center gravity & integrate velocity
        for (const node of this.nodes) {
            if (node.isPinned) continue;
            // Gravity toward 0,0
            node.vx -= node.x * 0.008 * this.alpha;
            node.vy -= node.y * 0.008 * this.alpha;

            node.vx *= this.velocityDecay;
            node.vy *= this.velocityDecay;

            node.x += node.vx;
            node.y += node.vy;
        }
    }

    render() {
        this.ctx.clearRect(0, 0, this.width, this.height);

        this.ctx.save();
        this.ctx.translate(this.transform.x, this.transform.y);
        this.ctx.scale(this.transform.k, this.transform.k);

        // Draw Links
        this.ctx.lineWidth = 1.5;
        for (const link of this.links) {
            const isHighlighted = (this.hoverNode && (link.source === this.hoverNode || link.target === this.hoverNode));
            this.ctx.strokeStyle = isHighlighted ? 'rgba(154, 117, 240, 0.7)' : 'rgba(255, 255, 255, 0.12)';
            this.ctx.beginPath();
            this.ctx.moveTo(link.source.x, link.source.y);
            this.ctx.lineTo(link.target.x, link.target.y);
            this.ctx.stroke();
        }

        // Draw Nodes
        for (const node of this.nodes) {
            const isHover = (node === this.hoverNode);
            const isActive = (node.id === this.activeDocId);

            // Outer glow if active or hovered
            if (isHover || isActive) {
                this.ctx.fillStyle = isActive ? 'rgba(154, 117, 240, 0.25)' : 'rgba(36, 202, 133, 0.25)';
                this.ctx.beginPath();
                this.ctx.arc(node.x, node.y, node.radius + 6, 0, Math.PI * 2);
                this.ctx.fill();
            }

            // Node Circle
            this.ctx.fillStyle = isActive ? '#9A75F0' : (isHover ? '#24CA85' : '#4E5364');
            this.ctx.beginPath();
            this.ctx.arc(node.x, node.y, node.radius, 0, Math.PI * 2);
            this.ctx.fill();

            // Border
            this.ctx.lineWidth = 2;
            this.ctx.strokeStyle = '#18191E';
            this.ctx.stroke();

            // Label
            this.ctx.fillStyle = isHover || isActive ? '#FFFFFF' : '#A0A4B2';
            this.ctx.font = `${isActive ? 'bold 11px' : '10px'} -apple-system, sans-serif`;
            this.ctx.textAlign = 'center';
            this.ctx.fillText(node.title, node.x, node.y + node.radius + 13);
        }

        this.ctx.restore();
    }

    screenToWorld(sx, sy) {
        return {
            x: (sx - this.transform.x) / this.transform.k,
            y: (sy - this.transform.y) / this.transform.k
        };
    }

    findNodeAt(sx, sy) {
        const w = this.screenToWorld(sx, sy);
        for (let i = this.nodes.length - 1; i >= 0; i--) {
            const n = this.nodes[i];
            const dx = n.x - w.x;
            const dy = n.y - w.y;
            if (dx * dx + dy * dy <= (n.radius + 4) * (n.radius + 4)) {
                return n;
            }
        }
        return null;
    }

    initEvents() {
        const canvas = this.canvas;

        canvas.addEventListener('mousedown', (e) => {
            const rect = canvas.getBoundingClientRect();
            const sx = e.clientX - rect.left;
            const sy = e.clientY - rect.top;

            const hit = this.findNodeAt(sx, sy);
            if (hit) {
                this.dragNode = hit;
                hit.isPinned = true;
                this.wakeUp();
            } else {
                this.isDragging = true;
                this.dragStart = { x: sx - this.transform.x, y: sy - this.transform.y };
            }
        });

        window.addEventListener('mousemove', (e) => {
            const rect = canvas.getBoundingClientRect();
            const sx = e.clientX - rect.left;
            const sy = e.clientY - rect.top;

            if (this.dragNode) {
                const w = this.screenToWorld(sx, sy);
                this.dragNode.x = w.x;
                this.dragNode.y = w.y;
                this.dragNode.vx = 0;
                this.dragNode.vy = 0;
                this.wakeUp();
            } else if (this.isDragging) {
                this.transform.x = sx - this.dragStart.x;
                this.transform.y = sy - this.dragStart.y;
                this.render();
            } else {
                // Hover detection
                const hit = this.findNodeAt(sx, sy);
                if (hit !== this.hoverNode) {
                    this.hoverNode = hit;
                    canvas.style.cursor = hit ? 'pointer' : 'default';
                    this.render();
                }
            }
        });

        window.addEventListener('mouseup', (e) => {
            if (this.dragNode) {
                const rect = canvas.getBoundingClientRect();
                const sx = e.clientX - rect.left;
                const sy = e.clientY - rect.top;
                const node = this.dragNode;
                this.dragNode = null;
                node.isPinned = false;

                // If clicked without dragging far, select it
                if (this.onSelectDoc && node) {
                    this.onSelectDoc(node.id);
                }
            }
            this.isDragging = false;
        });

        canvas.addEventListener('wheel', (e) => {
            e.preventDefault();
            const rect = canvas.getBoundingClientRect();
            const sx = e.clientX - rect.left;
            const sy = e.clientY - rect.top;

            const zoomFactor = e.deltaY < 0 ? 1.1 : 0.9;
            const newK = Math.min(Math.max(this.transform.k * zoomFactor, 0.2), 4.0);

            // Zoom centered on cursor
            this.transform.x = sx - (sx - this.transform.x) * (newK / this.transform.k);
            this.transform.y = sy - (sy - this.transform.y) * (newK / this.transform.k);
            this.transform.k = newK;

            this.render();
        }, { passive: false });
    }
}
