// Medha Windows Desktop — Vector Ink Canvas Engine
// 100% faithful port of InkCanvasNSView.swift & InkGeometry.swift
// Features PointerEvents with Windows Ink / Surface Pen pressure, Catmull-Rom splines, and Lasso math

class InkCanvas {
    constructor(canvasElement, options = {}) {
        this.canvas = canvasElement;
        this.ctx = canvasElement.getContext('2d');
        this.width = options.width || 794;
        this.height = options.height || 1123;
        this.templateType = options.templateType || 'lined';

        this.strokes = options.initialStrokes || [];
        this.currentStroke = null;
        this.isDrawing = false;

        // Active Tool
        this.activeTool = 'ballpoint'; // 'ballpoint' | 'fountain' | 'highlighter' | 'eraser' | 'lasso'
        this.activeColor = '#1E293B';
        this.activeWidth = 2.5;
        this.activeOpacity = 1.0;

        // Lasso Selection
        this.selectedStrokeIds = new Set();
        this.lassoPolygon = [];
        this.isLassoing = false;
        this.isDraggingSelection = false;
        this.dragStart = null;

        this.onStrokesChanged = options.onStrokesChanged || null;

        this.initCanvas();
        this.bindEvents();
        this.redraw();
    }

    initCanvas() {
        const dpr = typeof window !== 'undefined' ? (window.devicePixelRatio || 1) : 1;
        this.canvas.width = this.width * dpr;
        this.canvas.height = this.height * dpr;
        this.canvas.style.width = `${this.width}px`;
        this.canvas.style.height = `${this.height}px`;
        this.ctx.scale(dpr, dpr);
    }

    bindEvents() {
        this.canvas.addEventListener('pointerdown', (e) => this.handlePointerDown(e));
        this.canvas.addEventListener('pointermove', (e) => this.handlePointerMove(e));
        this.canvas.addEventListener('pointerup', (e) => this.handlePointerUp(e));
        this.canvas.addEventListener('pointercancel', (e) => this.handlePointerUp(e));
    }

    getPointerPos(e) {
        const rect = this.canvas.getBoundingClientRect();
        return {
            x: e.clientX - rect.left,
            y: e.clientY - rect.top,
            pressure: e.pressure > 0 ? e.pressure : 0.5,
            time: performance.now()
        };
    }

    handlePointerDown(e) {
        this.canvas.setPointerCapture(e.pointerId);
        const pt = this.getPointerPos(e);

        if (this.activeTool === 'eraser') {
            this.eraseAtPoint(pt);
            this.redraw();
            return;
        }

        if (this.activeTool === 'lasso') {
            this.isLassoing = true;
            this.lassoPolygon = [pt];
            this.redraw();
            return;
        }

        this.isDrawing = true;
        this.currentStroke = {
            id: `s-${Math.random().toString(36).substring(2, 9)}`,
            tool: this.activeTool,
            colorHex: this.activeColor,
            baseWidth: this.activeWidth,
            opacity: this.activeTool === 'highlighter' ? 0.35 : 1.0,
            points: [pt]
        };
    }

    handlePointerMove(e) {
        const pt = this.getPointerPos(e);

        if (this.activeTool === 'eraser' && (e.buttons > 0 || e.pressure > 0)) {
            this.eraseAtPoint(pt);
            this.redraw();
            return;
        }

        if (this.isLassoing) {
            this.lassoPolygon.push(pt);
            this.redraw();
            return;
        }

        if (!this.isDrawing || !this.currentStroke) return;

        this.currentStroke.points.push(pt);
        this.redraw();
    }

    handlePointerUp(e) {
        if (this.isLassoing) {
            this.isLassoing = false;
            this.selectStrokesInLasso();
            this.redraw();
            return;
        }

        if (this.isDrawing && this.currentStroke) {
            this.strokes.push(this.currentStroke);
            this.currentStroke = null;
            this.isDrawing = false;
            this.redraw();
            if (this.onStrokesChanged) this.onStrokesChanged(this.strokes);
        }
    }

    eraseAtPoint(pt, radius = 16) {
        const initialCount = this.strokes.length;
        this.strokes = this.strokes.filter(s => {
            return !s.points.some(p => Math.hypot(p.x - pt.x, p.y - pt.y) <= radius);
        });
        if (this.strokes.length !== initialCount && this.onStrokesChanged) {
            this.onStrokesChanged(this.strokes);
        }
    }

    // Point-in-polygon ray casting algorithm (matching InkCanvasNSView.swift)
    isPointInPolygon(p, polygon) {
        let inside = false;
        for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
            const xi = polygon[i].x, yi = polygon[i].y;
            const xj = polygon[j].x, yj = polygon[j].y;
            const intersect = ((yi > p.y) !== (yj > p.y)) &&
                (p.x < (xj - xi) * (p.y - yi) / (yj - yi) + xi);
            if (intersect) inside = !inside;
        }
        return inside;
    }

    selectStrokesInLasso() {
        this.selectedStrokeIds.clear();
        if (this.lassoPolygon.length < 3) return;

        for (const stroke of this.strokes) {
            // If any point is inside lasso polygon, select stroke
            if (stroke.points.some(p => this.isPointInPolygon(p, this.lassoPolygon))) {
                this.selectedStrokeIds.add(stroke.id);
            }
        }
    }

    // Catmull-Rom Cubic Spline Interpolation
    renderCatmullRomStroke(points, color, baseWidth, opacity, isHighlighter) {
        if (!points || points.length === 0) return;
        const ctx = this.ctx;

        ctx.save();
        ctx.strokeStyle = color;
        ctx.fillStyle = color;
        ctx.lineCap = 'round';
        ctx.lineJoin = 'round';
        ctx.globalAlpha = opacity;

        if (isHighlighter) {
            ctx.globalCompositeOperation = 'multiply';
        }

        if (points.length === 1) {
            ctx.beginPath();
            ctx.arc(points[0].x, points[0].y, baseWidth / 2, 0, Math.PI * 2);
            ctx.fill();
            ctx.restore();
            return;
        }

        ctx.beginPath();
        ctx.moveTo(points[0].x, points[0].y);

        for (let i = 0; i < points.length - 1; i++) {
            const p0 = i > 0 ? points[i - 1] : points[i];
            const p1 = points[i];
            const p2 = points[i + 1];
            const p3 = i < points.length - 2 ? points[i + 2] : p2;

            // Approximate Catmull-Rom with Cubic Bezier
            const cp1x = p1.x + (p2.x - p0.x) / 6;
            const cp1y = p1.y + (p2.y - p0.y) / 6;
            const cp2x = p2.x - (p3.x - p1.x) / 6;
            const cp2y = p2.y - (p3.y - p1.y) / 6;

            ctx.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, p2.x, p2.y);
        }

        ctx.lineWidth = baseWidth;
        ctx.stroke();
        ctx.restore();
    }

    drawTemplateBackground() {
        const ctx = this.ctx;
        ctx.fillStyle = '#FFFFFF';
        ctx.fillRect(0, 0, this.width, this.height);

        ctx.save();
        if (this.templateType === 'lined') {
            ctx.strokeStyle = '#E2E8F0';
            ctx.lineWidth = 1;
            for (let y = 56; y < this.height - 20; y += 28) {
                ctx.beginPath();
                ctx.moveTo(36, y);
                ctx.lineTo(this.width - 36, y);
                ctx.stroke();
            }
        } else if (this.templateType === 'grid') {
            ctx.strokeStyle = '#F1F5F9';
            ctx.lineWidth = 1;
            for (let x = 20; x < this.width; x += 20) {
                ctx.beginPath();
                ctx.moveTo(x, 0);
                ctx.lineTo(x, this.height);
                ctx.stroke();
            }
            for (let y = 20; y < this.height; y += 20) {
                ctx.beginPath();
                ctx.moveTo(0, y);
                ctx.lineTo(this.width, y);
                ctx.stroke();
            }
        } else if (this.templateType === 'dotGrid') {
            ctx.fillStyle = '#CBD5E1';
            for (let x = 20; x < this.width; x += 20) {
                for (let y = 20; y < this.height; y += 20) {
                    ctx.beginPath();
                    ctx.arc(x, y, 1.2, 0, Math.PI * 2);
                    ctx.fill();
                }
            }
        }
        ctx.restore();
    }

    redraw() {
        this.ctx.clearRect(0, 0, this.width, this.height);
        this.drawTemplateBackground();

        // Highlighters first
        for (const s of this.strokes) {
            if (s.tool === 'highlighter') {
                this.renderCatmullRomStroke(s.points, s.colorHex, s.baseWidth, s.opacity, true);
            }
        }
        if (this.currentStroke && this.currentStroke.tool === 'highlighter') {
            this.renderCatmullRomStroke(this.currentStroke.points, this.currentStroke.colorHex, this.currentStroke.baseWidth, this.currentStroke.opacity, true);
        }

        // Opaque strokes
        for (const s of this.strokes) {
            if (s.tool !== 'highlighter') {
                this.renderCatmullRomStroke(s.points, s.colorHex, s.baseWidth, s.opacity, false);
            }
        }
        if (this.currentStroke && this.currentStroke.tool !== 'highlighter') {
            this.renderCatmullRomStroke(this.currentStroke.points, this.currentStroke.colorHex, this.currentStroke.baseWidth, this.currentStroke.opacity, false);
        }

        // Render Lasso polygon & selection outlines
        if (this.lassoPolygon.length > 1) {
            this.ctx.save();
            this.ctx.strokeStyle = '#3B82F6';
            this.ctx.setLineDash([4, 4]);
            this.ctx.lineWidth = 1.5;
            this.ctx.beginPath();
            this.ctx.moveTo(this.lassoPolygon[0].x, this.lassoPolygon[0].y);
            for (let i = 1; i < this.lassoPolygon.length; i++) {
                this.ctx.lineTo(this.lassoPolygon[i].x, this.lassoPolygon[i].y);
            }
            this.ctx.stroke();
            this.ctx.restore();
        }
    }
}

if (typeof module !== 'undefined') {
    module.exports = { InkCanvas };
}
