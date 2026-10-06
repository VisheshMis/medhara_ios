// Medha Windows Desktop — Vector Ink Geometry Engine
// 100% faithful port of InkGeometry.swift
// Implements Catmull-Rom cubic spline interpolation, variable-width polygon outline generation,
// ray-casting point-in-polygon lasso math, eraser hit-testing, and bounding box computation.

class InkGeometry {
    /**
     * Distance between two 2D points
     */
    static distance(p1, p2) {
        const dx = p2.x - p1.x;
        const dy = p2.y - p1.y;
        return Math.sqrt(dx * dx + dy * dy);
    }

    /**
     * Interpolates smoothed points along a stroke using Catmull-Rom splines
     * @param {Array<{x: number, y: number, pressure?: number, timeOffset?: number}>} points
     * @returns {Array<{x: number, y: number, pressure: number, timeOffset: number}>}
     */
    static smoothPoints(points) {
        if (!points || points.length < 3) return points || [];

        const smoothed = [];
        for (let i = 0; i < points.length - 1; i++) {
            const p0 = i > 0 ? points[i - 1] : points[i];
            const p1 = points[i];
            const p2 = points[i + 1];
            const p3 = (i + 2 < points.length) ? points[i + 2] : p2;

            const segDist = this.distance(p1, p2);
            const steps = Math.max(2, Math.min(8, Math.floor(segDist / 4.0)));

            const press0 = p0.pressure != null ? p0.pressure : 0.5;
            const press1 = p1.pressure != null ? p1.pressure : 0.5;
            const press2 = p2.pressure != null ? p2.pressure : 0.5;
            const press3 = p3.pressure != null ? p3.pressure : 0.5;

            const t0 = p0.timeOffset || 0;
            const t1 = p1.timeOffset || 0;
            const t2 = p2.timeOffset || 0;
            const t3 = p3.timeOffset || 0;

            for (let step = 0; step < steps; step++) {
                const t = step / steps;
                const t2Val = t * t;
                const t3Val = t2Val * t;

                // Catmull-Rom formulation
                const f0 = -0.5 * t3Val + t2Val - 0.5 * t;
                const f1 =  1.5 * t3Val - 2.5 * t2Val + 1.0;
                const f2 = -1.5 * t3Val + 2.0 * t2Val + 0.5 * t;
                const f3 =  0.5 * t3Val - 0.5 * t2Val;

                const x = f0 * p0.x + f1 * p1.x + f2 * p2.x + f3 * p3.x;
                const y = f0 * p0.y + f1 * p1.y + f2 * p2.y + f3 * p3.y;
                const pressure = f0 * press0 + f1 * press1 + f2 * press2 + f3 * press3;
                const timeOffset = f0 * t0 + f1 * t1 + f2 * t2 + f3 * t3;

                smoothed.push({
                    x,
                    y,
                    pressure: Math.max(0.1, Math.min(1.0, pressure)),
                    timeOffset
                });
            }
        }

        const last = points[points.length - 1];
        smoothed.push({
            x: last.x,
            y: last.y,
            pressure: last.pressure != null ? last.pressure : 0.5,
            timeOffset: last.timeOffset || 0
        });

        return smoothed;
    }

    /**
     * Generates a closed polygon outline ribbon for a stroke with pressure variations
     * @param {Object} stroke
     * @returns {Array<{x: number, y: number}>} Outline polygon vertices
     */
    static generateOutlinePolygon(stroke) {
        const pts = stroke.points || [];
        if (pts.length === 0) return [];

        const baseWidth = stroke.baseWidth || 2.5;
        const tool = stroke.tool || 'ballpoint';

        if (pts.length === 1) {
            const p = pts[0];
            const radius = Math.max(1.0, (baseWidth * (p.pressure || 0.5) * 0.5));
            const circlePts = [];
            const numSteps = 12;
            for (let i = 0; i < numSteps; i++) {
                const theta = (i / numSteps) * Math.PI * 2;
                circlePts.push({
                    x: p.x + Math.cos(theta) * radius,
                    y: p.y + Math.sin(theta) * radius
                });
            }
            return circlePts;
        }

        const smoothed = this.smoothPoints(pts);
        if (smoothed.length < 2) return [];

        const leftPoints = [];
        const rightPoints = [];

        for (let i = 0; i < smoothed.count || i < smoothed.length; i++) {
            const curr = smoothed[i];
            const pressure = curr.pressure != null ? curr.pressure : 0.5;

            let halfWidth;
            switch (tool) {
                case 'ballpoint':
                    halfWidth = Math.max(0.75, (baseWidth * 0.5) * (0.4 + 0.6 * pressure));
                    break;
                case 'fountain':
                    halfWidth = Math.max(1.0, (baseWidth * 0.5) * (0.2 + 0.9 * pressure));
                    break;
                case 'highlighter':
                case 'eraser':
                case 'lasso':
                default:
                    halfWidth = baseWidth * 0.5;
                    break;
            }

            let normal;
            if (i === 0) {
                const next = smoothed[1];
                const tangent = this.normalize({ x: next.x - curr.x, y: next.y - curr.y });
                normal = { x: -tangent.y, y: tangent.x };
            } else if (i === smoothed.length - 1) {
                const prev = smoothed[i - 1];
                const tangent = this.normalize({ x: curr.x - prev.x, y: curr.y - prev.y });
                normal = { x: -tangent.y, y: tangent.x };
            } else {
                const prev = smoothed[i - 1];
                const next = smoothed[i + 1];
                const tangent = this.normalize({ x: next.x - prev.x, y: next.y - prev.y });
                normal = { x: -tangent.y, y: tangent.x };
            }

            leftPoints.push({
                x: curr.x + normal.x * halfWidth,
                y: curr.y + normal.y * halfWidth
            });
            rightPoints.push({
                x: curr.x - normal.x * halfWidth,
                y: curr.y - normal.y * halfWidth
            });
        }

        // Return combined closed outline polygon vertices (left forward, right reversed)
        return leftPoints.concat(rightPoints.reverse());
    }

    /**
     * Ray-casting algorithm: Check if a 2D point lies inside a closed polygon
     */
    static polygonContains(point, polygon) {
        if (!polygon || polygon.length < 3) return false;
        let inside = false;
        let j = polygon.length - 1;
        for (let i = 0; i < polygon.length; i++) {
            const pi = polygon[i];
            const pj = polygon[j];
            if (((pi.y > point.y) !== (pj.y > point.y)) &&
                (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x)) {
                inside = !inside;
            }
            j = i;
        }
        return inside;
    }

    /**
     * Check if a stroke is selected by a lasso polygon
     */
    static lassoSelects(stroke, polygon) {
        if (!polygon || polygon.length < 3 || !stroke || !stroke.points || stroke.points.length === 0) {
            return false;
        }

        // 1. Centroid check
        const bounds = this.strokeBoundingBox(stroke);
        const mid = { x: (bounds.minX + bounds.maxX) * 0.5, y: (bounds.minY + bounds.maxY) * 0.5 };
        if (this.polygonContains(mid, polygon)) {
            return true;
        }

        // 2. Check each point of stroke
        for (const p of stroke.points) {
            if (this.polygonContains(p, polygon)) {
                return true;
            }
        }
        return false;
    }

    /**
     * Hit-test stroke with an eraser circular brush
     */
    static hitTest(stroke, point, eraserRadius = 16.0) {
        const bounds = this.strokeBoundingBox(stroke);
        const testMinX = point.x - eraserRadius;
        const testMaxX = point.x + eraserRadius;
        const testMinY = point.y - eraserRadius;
        const testMaxY = point.y + eraserRadius;

        // Bounding box intersection check
        if (testMaxX < bounds.minX || testMinX > bounds.maxX || testMaxY < bounds.minY || testMinY > bounds.maxY) {
            return false;
        }

        const pts = stroke.points || [];
        if (pts.length === 1) {
            return this.distance(pts[0], point) <= eraserRadius + (stroke.baseWidth || 2.5) * 0.5;
        }

        for (let i = 0; i < pts.length - 1; i++) {
            const dist = this.distanceToSegment(point, pts[i], pts[i + 1]);
            if (dist <= eraserRadius + (stroke.baseWidth || 2.5) * 0.5) {
                return true;
            }
        }
        return false;
    }

    /**
     * Computes the bounding box of a single stroke
     */
    static strokeBoundingBox(stroke) {
        const pts = stroke.points || [];
        if (pts.length === 0) return { minX: 0, minY: 0, maxX: 0, maxY: 0, width: 0, height: 0 };

        let minX = Infinity;
        let minY = Infinity;
        let maxX = -Infinity;
        let maxY = -Infinity;

        const halfWidth = (stroke.baseWidth || 2.5) * 0.5;
        for (const p of pts) {
            if (p.x - halfWidth < minX) minX = p.x - halfWidth;
            if (p.x + halfWidth > maxX) maxX = p.x + halfWidth;
            if (p.y - halfWidth < minY) minY = p.y - halfWidth;
            if (p.y + halfWidth > maxY) maxY = p.y + halfWidth;
        }

        return {
            minX,
            minY,
            maxX,
            maxY,
            width: Math.max(1, maxX - minX),
            height: Math.max(1, maxY - minY)
        };
    }

    /**
     * Computes combined bounding box for an array of strokes
     */
    static combinedBoundingBox(strokes) {
        if (!strokes || strokes.length === 0) return null;

        let minX = Infinity;
        let minY = Infinity;
        let maxX = -Infinity;
        let maxY = -Infinity;
        let hasValid = false;

        for (const stroke of strokes) {
            if (!stroke.points || stroke.points.length === 0) continue;
            const b = this.strokeBoundingBox(stroke);
            if (b.minX < minX) minX = b.minX;
            if (b.minY < minY) minY = b.minY;
            if (b.maxX > maxX) maxX = b.maxX;
            if (b.maxY > maxY) maxY = b.maxY;
            hasValid = true;
        }

        if (!hasValid) return null;
        return {
            minX,
            minY,
            maxX,
            maxY,
            width: Math.max(1, maxX - minX),
            height: Math.max(1, maxY - minY)
        };
    }

    /**
     * Translates a stroke by (dx, dy)
     */
    static translate(stroke, dx, dy) {
        const newPoints = (stroke.points || []).map(p => ({
            x: p.x + dx,
            y: p.y + dy,
            pressure: p.pressure,
            timeOffset: p.timeOffset
        }));

        return {
            ...stroke,
            points: newPoints
        };
    }

    static distanceToSegment(p, a, b) {
        const abx = b.x - a.x;
        const aby = b.y - a.y;
        const apx = p.x - a.x;
        const apy = p.y - a.y;
        const lenSq = abx * abx + aby * aby;
        if (lenSq === 0) return this.distance(p, a);

        let t = (apx * abx + apy * aby) / lenSq;
        t = Math.max(0.0, Math.min(1.0, t));
        const proj = { x: a.x + t * abx, y: a.y + t * aby };
        return this.distance(p, proj);
    }

    static normalize(v) {
        const len = Math.sqrt(v.x * v.x + v.y * v.y);
        if (len === 0) return { x: 1, y: 0 };
        return { x: v.x / len, y: v.y / len };
    }
}

if (typeof module !== 'undefined') {
    module.exports = { InkGeometry };
}
