import Foundation
import CoreGraphics

// MARK: - Outline Polygon Point
public struct InkOutlinePoint: Equatable, Sendable {
    public let left: CGPoint
    public let right: CGPoint

    public init(left: CGPoint, right: CGPoint) {
        self.left = left
        self.right = right
    }
}

// MARK: - Portable Vector Ink Geometry Engine
public enum InkGeometry {

    /// Distance between two 2D points
    public static func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }

    /// Interpolates smoothed points along a stroke using Catmull-Rom splines
    public static func smoothPoints(from points: [InkPoint]) -> [InkPoint] {
        guard points.count >= 3 else { return points }

        var smoothed: [InkPoint] = []
        smoothed.reserveCapacity(points.count * 3)

        for i in 0..<(points.count - 1) {
            let p0 = i > 0 ? points[i - 1] : points[i]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = (i + 2 < points.count) ? points[i + 2] : p2

            let segDist = distance(CGPoint(x: p1.x, y: p1.y), CGPoint(x: p2.x, y: p2.y))
            let steps = max(2, min(8, Int(segDist / 4.0)))

            for step in 0..<steps {
                let t = Double(step) / Double(steps)
                let t2 = t * t
                let t3 = t2 * t

                // Catmull-Rom formulation
                let f0 = -0.5 * t3 + t2 - 0.5 * t
                let f1 =  1.5 * t3 - 2.5 * t2 + 1.0
                let f2 = -1.5 * t3 + 2.0 * t2 + 0.5 * t
                let f3 =  0.5 * t3 - 0.5 * t2

                let x = f0 * p0.x + f1 * p1.x + f2 * p2.x + f3 * p3.x
                let y = f0 * p0.y + f1 * p1.y + f2 * p2.y + f3 * p3.y
                let pressure = f0 * p0.pressure + f1 * p1.pressure + f2 * p2.pressure + f3 * p3.pressure
                let time = f0 * p0.timeOffset + f1 * p1.timeOffset + f2 * p2.timeOffset + f3 * p3.timeOffset

                smoothed.append(InkPoint(x: x, y: y, pressure: max(0.1, min(1.0, pressure)), timeOffset: time))
            }
        }

        if let last = points.last {
            smoothed.append(last)
        }
        return smoothed
    }

    /// Generates a variable-width closed polygon outline for a stroke
    public static func generateOutlinePath(for stroke: InkStroke) -> CGPath {
        let path = CGMutablePath()
        let pts = stroke.points
        guard !pts.isEmpty else { return path }

        if pts.count == 1 {
            // Single tap dot: draw circle
            let p = pts[0]
            let radius = CGFloat(max(1.0, stroke.baseWidth * p.pressure * 0.5))
            let rect = CGRect(x: CGFloat(p.x) - radius, y: CGFloat(p.y) - radius, width: radius * 2, height: radius * 2)
            path.addEllipse(in: rect)
            return path
        }

        let smoothed = smoothPoints(from: pts)
        guard smoothed.count >= 2 else {
            let p = pts[0]
            let r = CGFloat(stroke.baseWidth * 0.5)
            path.addEllipse(in: CGRect(x: CGFloat(p.x) - r, y: CGFloat(p.y) - r, width: r * 2, height: r * 2))
            return path
        }

        var leftPoints: [CGPoint] = []
        var rightPoints: [CGPoint] = []
        leftPoints.reserveCapacity(smoothed.count)
        rightPoints.reserveCapacity(smoothed.count)

        for i in 0..<smoothed.count {
            let curr = CGPoint(x: smoothed[i].x, y: smoothed[i].y)
            let pressure = CGFloat(smoothed[i].pressure)

            // Determine stroke width based on tool & pressure
            let halfWidth: CGFloat
            switch stroke.tool {
            case .ballpoint:
                halfWidth = max(0.75, (CGFloat(stroke.baseWidth) * 0.5) * (0.4 + 0.6 * pressure))
            case .fountain:
                // Fountain pen: width varies more dynamically
                halfWidth = max(1.0, (CGFloat(stroke.baseWidth) * 0.5) * (0.2 + 0.9 * pressure))
            case .highlighter:
                halfWidth = CGFloat(stroke.baseWidth) * 0.5
            case .eraser, .lasso, .tape:
                halfWidth = CGFloat(stroke.baseWidth) * 0.5
            }

            // Calculate tangent & normal vector
            let normal: CGPoint
            if i == 0 {
                let next = CGPoint(x: smoothed[1].x, y: smoothed[1].y)
                let tangent = normalize(CGPoint(x: next.x - curr.x, y: next.y - curr.y))
                normal = CGPoint(x: -tangent.y, y: tangent.x)
            } else if i == smoothed.count - 1 {
                let prev = CGPoint(x: smoothed[i - 1].x, y: smoothed[i - 1].y)
                let tangent = normalize(CGPoint(x: curr.x - prev.x, y: curr.y - prev.y))
                normal = CGPoint(x: -tangent.y, y: tangent.x)
            } else {
                let prev = CGPoint(x: smoothed[i - 1].x, y: smoothed[i - 1].y)
                let next = CGPoint(x: smoothed[i + 1].x, y: smoothed[i + 1].y)
                let tangent = normalize(CGPoint(x: next.x - prev.x, y: next.y - prev.y))
                normal = CGPoint(x: -tangent.y, y: tangent.x)
            }

            let left = CGPoint(x: curr.x + normal.x * halfWidth, y: curr.y + normal.y * halfWidth)
            let right = CGPoint(x: curr.x - normal.x * halfWidth, y: curr.y - normal.y * halfWidth)

            leftPoints.append(left)
            rightPoints.append(right)
        }

        // Construct closed ribbon path
        if let firstLeft = leftPoints.first {
            path.move(to: firstLeft)
            for i in 1..<leftPoints.count {
                path.addLine(to: leftPoints[i])
            }
            // Cap at the end
            if let lastRight = rightPoints.last {
                path.addLine(to: lastRight)
            }
            // Trace backwards on right side
            for i in (0..<(rightPoints.count - 1)).reversed() {
                path.addLine(to: rightPoints[i])
            }
            path.closeSubpath()
        }

        return path
    }

    /// Check if a test point collides with any stroke segment within eraserRadius
    public static func hitTest(stroke: InkStroke, point: CGPoint, eraserRadius: CGFloat = 16.0) -> Bool {
        let (minX, minY, maxX, maxY) = stroke.boundingRect
        let testRect = CGRect(x: point.x - eraserRadius, y: point.y - eraserRadius, width: eraserRadius * 2, height: eraserRadius * 2)
        let strokeBounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

        guard testRect.intersects(strokeBounds) else { return false }

        let pts = stroke.points
        if pts.count == 1 {
            let p = CGPoint(x: pts[0].x, y: pts[0].y)
            return distance(p, point) <= eraserRadius + CGFloat(stroke.baseWidth * 0.5)
        }

        for i in 0..<(pts.count - 1) {
            let a = CGPoint(x: pts[i].x, y: pts[i].y)
            let b = CGPoint(x: pts[i + 1].x, y: pts[i + 1].y)
            let dist = distanceToSegment(p: point, a: a, b: b)
            if dist <= eraserRadius + CGFloat(stroke.baseWidth * 0.5) {
                return true
            }
        }
        return false
    }

    /// Check if a 2D point lies inside a closed polygon (Ray-casting algorithm)
    public static func polygonContains(point: CGPoint, polygon: [CGPoint]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let pi = polygon[i]
            let pj = polygon[j]
            if ((pi.y > point.y) != (pj.y > point.y)) &&
                (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x) {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    /// Check if a stroke is enclosed or intersects with a lasso selection polygon
    public static func lassoSelects(stroke: InkStroke, polygon: [CGPoint]) -> Bool {
        guard polygon.count >= 3 else { return false }

        // Quick check: if centroid or any point of stroke is inside polygon
        let (minX, minY, maxX, maxY) = stroke.boundingRect
        let mid = CGPoint(x: (minX + maxX) * 0.5, y: (minY + maxY) * 0.5)
        if polygonContains(point: mid, polygon: polygon) {
            return true
        }

        // Check if any point in the stroke lies within the polygon
        for p in stroke.points {
            if polygonContains(point: CGPoint(x: p.x, y: p.y), polygon: polygon) {
                return true
            }
        }
        return false
    }

    /// Translate a stroke by delta (dx, dy)
    public static func translate(stroke: InkStroke, dx: Double, dy: Double) -> InkStroke {
        let newPoints = stroke.points.map { pt in
            InkPoint(x: pt.x + dx, y: pt.y + dy, pressure: pt.pressure, timeOffset: pt.timeOffset)
        }
        return InkStroke(
            id: stroke.id,
            tool: stroke.tool,
            colorHex: stroke.colorHex,
            baseWidth: stroke.baseWidth,
            opacity: stroke.opacity,
            points: newPoints,
            pattern: stroke.pattern,
            isTapeRevealed: stroke.isTapeRevealed,
            shapePrimitive: stroke.shapePrimitive
        )
    }

    private static func distanceToSegment(p: CGPoint, a: CGPoint, b: CGPoint) -> CGFloat {
        let abx = b.x - a.x
        let aby = b.y - a.y
        let apx = p.x - a.x
        let apy = p.y - a.y
        let lenSq = abx * abx + aby * aby
        if lenSq == 0 { return distance(p, a) }

        var t = (apx * abx + apy * aby) / lenSq
        t = max(0.0, min(1.0, t))
        let proj = CGPoint(x: a.x + t * abx, y: a.y + t * aby)
        return distance(p, proj)
    }

    private static func normalize(_ v: CGPoint) -> CGPoint {
        let len = sqrt(v.x * v.x + v.y * v.y)
        if len == 0 { return CGPoint(x: 1, y: 0) }
        return CGPoint(x: v.x / len, y: v.y / len)
    }

    /// Computes the combined bounding box enclosing all strokes
    public static func combinedBoundingBox(for strokes: [InkStroke]) -> CGRect? {
        guard !strokes.isEmpty else { return nil }
        var minX = Double.greatestFiniteMagnitude
        var minY = Double.greatestFiniteMagnitude
        var maxX = -Double.greatestFiniteMagnitude
        var maxY = -Double.greatestFiniteMagnitude
        var hasValidStroke = false

        for stroke in strokes {
            guard !stroke.points.isEmpty else { continue }
            let b = stroke.boundingRect
            minX = min(minX, b.minX)
            minY = min(minY, b.minY)
            maxX = max(maxX, b.maxX)
            maxY = max(maxY, b.maxY)
            hasValidStroke = true
        }

        guard hasValidStroke else { return nil }
        return CGRect(x: minX, y: minY, width: max(1.0, maxX - minX), height: max(1.0, maxY - minY))
    }

    // MARK: - Tier 1: 2D Ruler Math & Proximity Snapping
    /// Snaps a 2D point onto a line defined by lineStart and lineEnd
    public static func projectPointOntoLine(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGPoint {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lenSq = dx * dx + dy * dy
        guard lenSq > 0.0001 else { return lineStart }
        let t = ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / lenSq
        return CGPoint(x: lineStart.x + t * dx, y: lineStart.y + t * dy)
    }

    // MARK: - Tier 1: Draw-and-Hold Shape Recognition
    public enum FittedShape: Equatable {
        case line(start: CGPoint, end: CGPoint)
        case rectangle(CGRect)
        case circle(center: CGPoint, radius: CGFloat)
        case ellipse(CGRect)
        case triangle(p1: CGPoint, p2: CGPoint, p3: CGPoint)

        public var primitiveType: String {
            switch self {
            case .line: return "line"
            case .rectangle: return "rect"
            case .circle: return "circle"
            case .ellipse: return "ellipse"
            case .triangle: return "triangle"
            }
        }
    }

    /// Fits raw stroke points to canonical 2D geometric primitives
    /// Fits raw stroke points to canonical 2D geometric primitives using the smart classifier
    public static func fitPrimitive(from points: [InkPoint]) -> FittedShape? {
        guard let recognized = CanvasShapeRecognizer.recognize(inkPoints: points) else {
            return nil
        }
        switch recognized {
        case .line(let s, let e):
            return .line(start: s, end: e)
        case .rectangle(let r, _), .roundedRectangle(let r, _), .diamond(let r), .polygon:
            return .rectangle(r)
        case .circle(let c, let rad):
            return .circle(center: c, radius: rad)
        case .ellipse(let r):
            return .ellipse(r)
        case .triangle(let p1, let p2, let p3, _):
            return .triangle(p1: p1, p2: p2, p3: p3)
        }
    }

    /// Converts a fitted shape into smooth synthetic InkPoints for rendering & storage
    public static func generatePoints(for shape: FittedShape, basePressure: Double = 0.6) -> [InkPoint] {
        var pts: [InkPoint] = []
        switch shape {
        case .line(let start, let end):
            let steps = 16
            for i in 0...steps {
                let t = Double(i) / Double(steps)
                let x = Double(start.x) + t * Double(end.x - start.x)
                let y = Double(start.y) + t * Double(end.y - start.y)
                pts.append(InkPoint(x: x, y: y, pressure: basePressure, timeOffset: t * 0.2))
            }
        case .circle(let center, let radius):
            let steps = 36
            for i in 0...steps {
                let angle = (Double(i) / Double(steps)) * 2.0 * .pi
                let x = Double(center.x) + Double(radius) * cos(angle)
                let y = Double(center.y) + Double(radius) * sin(angle)
                pts.append(InkPoint(x: x, y: y, pressure: basePressure, timeOffset: Double(i) * 0.01))
            }
        case .rectangle(let rect):
            let corners = [
                CGPoint(x: rect.minX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.minY)
            ]
            for c in 0..<4 {
                let c1 = corners[c]
                let c2 = corners[c+1]
                let segSteps = 8
                for s in 0..<segSteps {
                    let t = Double(s) / Double(segSteps)
                    let x = Double(c1.x) + t * Double(c2.x - c1.x)
                    let y = Double(c1.y) + t * Double(c2.y - c1.y)
                    pts.append(InkPoint(x: x, y: y, pressure: basePressure, timeOffset: Double(c * segSteps + s) * 0.01))
                }
            }
            if let first = pts.first {
                pts.append(InkPoint(x: first.x, y: first.y, pressure: basePressure, timeOffset: 0.35))
            }
        case .ellipse(let rect):
            let steps = 36
            let rx = Double(rect.width) / 2.0
            let ry = Double(rect.height) / 2.0
            let cx = Double(rect.midX)
            let cy = Double(rect.midY)
            for i in 0...steps {
                let angle = (Double(i) / Double(steps)) * 2.0 * .pi
                let x = cx + rx * cos(angle)
                let y = cy + ry * sin(angle)
                pts.append(InkPoint(x: x, y: y, pressure: basePressure, timeOffset: Double(i) * 0.01))
            }
        case .triangle(let p1, let p2, let p3):
            let vertices = [p1, p2, p3, p1]
            for v in 0..<3 {
                let v1 = vertices[v]
                let v2 = vertices[v+1]
                let segSteps = 10
                for s in 0..<segSteps {
                    let t = Double(s) / Double(segSteps)
                    let x = Double(v1.x) + t * Double(v2.x - v1.x)
                    let y = Double(v1.y) + t * Double(v2.y - v1.y)
                    pts.append(InkPoint(x: x, y: y, pressure: basePressure, timeOffset: Double(v * segSteps + s) * 0.01))
                }
            }
            if let first = pts.first {
                pts.append(InkPoint(x: first.x, y: first.y, pressure: basePressure, timeOffset: 0.35))
            }
        }
        return pts
    }
}
