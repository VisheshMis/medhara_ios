import Foundation
import CoreGraphics

// MARK: - Smart Shape Recognizer & Classifier
public struct CanvasShapeRecognizer: Sendable {

    // MARK: - Configuration
    public struct Config: Sendable {
        public var resampleCount: Int = 64
        public var closedThresholdRatio: CGFloat = 0.26 // gap / totalLength
        public var closedMaxAbsoluteGap: CGFloat = 36.0
        public var lineStraightnessThreshold: CGFloat = 0.88 // chord / length
        public var lineMaxPerpResidualRatio: CGFloat = 0.08
        public var circleAspectRatioMin: CGFloat = 0.80
        public var circleAspectRatioMax: CGFloat = 1.25
        public var ellipseMaxMeanResidual: CGFloat = 0.28
        public var ellipseMaxIndividualResidual: CGFloat = 0.60
        public var polygonMaxMeanResidualRatio: CGFloat = 0.14
        public var axisSnapAngleThresholdDegrees: Double = 8.0

        public static let `default` = Config()
    }

    // MARK: - Recognized Shape Result
    public enum RecognizedShape: Equatable, Sendable {
        case line(start: CGPoint, end: CGPoint)
        case rectangle(rect: CGRect, rotationDegrees: Double)
        case roundedRectangle(rect: CGRect, cornerRadius: CGFloat)
        case diamond(rect: CGRect)
        case ellipse(rect: CGRect)
        case circle(center: CGPoint, radius: CGFloat)
        case triangle(p1: CGPoint, p2: CGPoint, p3: CGPoint, boundingBox: CGRect)
        case polygon(vertices: [CGPoint])

        public var shapeName: String {
            switch self {
            case .line: return "Line"
            case .rectangle: return "Rectangle"
            case .roundedRectangle: return "Rounded Rectangle"
            case .diamond: return "Diamond"
            case .ellipse: return "Ellipse"
            case .circle: return "Circle"
            case .triangle: return "Triangle"
            case .polygon: return "Polygon"
            }
        }

        public var boundingBox: CGRect {
            switch self {
            case .line(let s, let e):
                return CGRect(
                    x: min(s.x, e.x),
                    y: min(s.y, e.y),
                    width: max(1.0, abs(e.x - s.x)),
                    height: max(1.0, abs(e.y - s.y))
                )
            case .rectangle(let r, _), .roundedRectangle(let r, _), .diamond(let r), .ellipse(let r):
                return r
            case .circle(let center, let radius):
                return CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2.0, height: radius * 2.0)
            case .triangle(_, _, _, let bbox):
                return bbox
            case .polygon(let vertices):
                guard let first = vertices.first else { return .zero }
                var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
                for v in vertices {
                    minX = min(minX, v.x)
                    maxX = max(maxX, v.x)
                    minY = min(minY, v.y)
                    maxY = max(maxY, v.y)
                }
                return CGRect(x: minX, y: minY, width: max(1.0, maxX - minX), height: max(1.0, maxY - minY))
            }
        }

        public func toCanvasItem(
            canvasDocId: String,
            strokeColorHex: String? = "#3B82F6",
            fillColorHex: String? = "#EFF6FF",
            strokeWidth: Double = 2.0
        ) -> CanvasItem? {
            let bbox = self.boundingBox
            switch self {
            case .line:
                // Lines are typically dynamic connectors or free strokes, but can be represented as items
                return nil
            case .rectangle(let r, let rot):
                return CanvasItem(
                    canvasDocId: canvasDocId,
                    itemType: .shape,
                    shapeType: .rectangle,
                    x: Double(r.minX),
                    y: Double(r.minY),
                    width: Double(r.width),
                    height: Double(r.height),
                    rotationDegrees: rot,
                    fillColorHex: fillColorHex,
                    strokeColorHex: strokeColorHex,
                    strokeWidth: strokeWidth
                )
            case .roundedRectangle(let r, let cr):
                return CanvasItem(
                    canvasDocId: canvasDocId,
                    itemType: .shape,
                    shapeType: .roundedRectangle,
                    x: Double(r.minX),
                    y: Double(r.minY),
                    width: Double(r.width),
                    height: Double(r.height),
                    fillColorHex: fillColorHex,
                    strokeColorHex: strokeColorHex,
                    strokeWidth: strokeWidth,
                    cornerRadius: Double(cr)
                )
            case .diamond(let r):
                return CanvasItem(
                    canvasDocId: canvasDocId,
                    itemType: .shape,
                    shapeType: .diamond,
                    x: Double(r.minX),
                    y: Double(r.minY),
                    width: Double(r.width),
                    height: Double(r.height),
                    fillColorHex: fillColorHex,
                    strokeColorHex: strokeColorHex,
                    strokeWidth: strokeWidth
                )
            case .ellipse(let r):
                return CanvasItem(
                    canvasDocId: canvasDocId,
                    itemType: .shape,
                    shapeType: .ellipse,
                    x: Double(r.minX),
                    y: Double(r.minY),
                    width: Double(r.width),
                    height: Double(r.height),
                    fillColorHex: fillColorHex,
                    strokeColorHex: strokeColorHex,
                    strokeWidth: strokeWidth
                )
            case .circle(let center, let radius):
                let r = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2.0, height: radius * 2.0)
                return CanvasItem(
                    canvasDocId: canvasDocId,
                    itemType: .shape,
                    shapeType: .ellipse,
                    x: Double(r.minX),
                    y: Double(r.minY),
                    width: Double(r.width),
                    height: Double(r.height),
                    fillColorHex: fillColorHex,
                    strokeColorHex: strokeColorHex,
                    strokeWidth: strokeWidth
                )
            case .triangle(_, _, _, let bbox):
                return CanvasItem(
                    canvasDocId: canvasDocId,
                    itemType: .shape,
                    shapeType: .triangle,
                    x: Double(bbox.minX),
                    y: Double(bbox.minY),
                    width: Double(bbox.width),
                    height: Double(bbox.height),
                    fillColorHex: fillColorHex,
                    strokeColorHex: strokeColorHex,
                    strokeWidth: strokeWidth
                )
            case .polygon:
                return CanvasItem(
                    canvasDocId: canvasDocId,
                    itemType: .shape,
                    shapeType: .rectangle,
                    x: Double(bbox.minX),
                    y: Double(bbox.minY),
                    width: Double(bbox.width),
                    height: Double(bbox.height),
                    fillColorHex: fillColorHex,
                    strokeColorHex: strokeColorHex,
                    strokeWidth: strokeWidth
                )
            }
        }

        public func toFittedPoints(basePressure: Double = 0.6) -> [InkPoint] {
            var pts: [InkPoint] = []
            switch self {
            case .line(let s, let e):
                let steps = 16
                for i in 0...steps {
                    let t = Double(i) / Double(steps)
                    let x = Double(s.x) + t * Double(e.x - s.x)
                    let y = Double(s.y) + t * Double(e.y - s.y)
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
            case .ellipse(let rect):
                let steps = 36
                let cx = Double(rect.midX)
                let cy = Double(rect.midY)
                let rx = Double(rect.width) / 2.0
                let ry = Double(rect.height) / 2.0
                for i in 0...steps {
                    let angle = (Double(i) / Double(steps)) * 2.0 * .pi
                    let x = cx + rx * cos(angle)
                    let y = cy + ry * sin(angle)
                    pts.append(InkPoint(x: x, y: y, pressure: basePressure, timeOffset: Double(i) * 0.01))
                }
            case .rectangle(let rect, _), .roundedRectangle(let rect, _):
                let corners = [
                    CGPoint(x: rect.minX, y: rect.minY),
                    CGPoint(x: rect.maxX, y: rect.minY),
                    CGPoint(x: rect.maxX, y: rect.maxY),
                    CGPoint(x: rect.minX, y: rect.maxY),
                    CGPoint(x: rect.minX, y: rect.minY)
                ]
                for c in 0..<4 {
                    let c1 = corners[c], c2 = corners[c+1]
                    for s in 0..<8 {
                        let t = Double(s) / 8.0
                        let x = Double(c1.x) + t * Double(c2.x - c1.x)
                        let y = Double(c1.y) + t * Double(c2.y - c1.y)
                        pts.append(InkPoint(x: x, y: y, pressure: basePressure, timeOffset: 0.01))
                    }
                }
            case .diamond(let rect):
                let corners = [
                    CGPoint(x: rect.midX, y: rect.minY),
                    CGPoint(x: rect.maxX, y: rect.midY),
                    CGPoint(x: rect.midX, y: rect.maxY),
                    CGPoint(x: rect.minX, y: rect.midY),
                    CGPoint(x: rect.midX, y: rect.minY)
                ]
                for c in 0..<4 {
                    let c1 = corners[c], c2 = corners[c+1]
                    for s in 0..<8 {
                        let t = Double(s) / 8.0
                        let x = Double(c1.x) + t * Double(c2.x - c1.x)
                        let y = Double(c1.y) + t * Double(c2.y - c1.y)
                        pts.append(InkPoint(x: x, y: y, pressure: basePressure, timeOffset: 0.01))
                    }
                }
            case .triangle(let p1, let p2, let p3, _):
                let vertices = [p1, p2, p3, p1]
                for c in 0..<3 {
                    let c1 = vertices[c], c2 = vertices[c+1]
                    for s in 0..<10 {
                        let t = Double(s) / 10.0
                        let x = Double(c1.x) + t * Double(c2.x - c1.x)
                        let y = Double(c1.y) + t * Double(c2.y - c1.y)
                        pts.append(InkPoint(x: x, y: y, pressure: basePressure, timeOffset: 0.01))
                    }
                }
            case .polygon(let vertices):
                guard !vertices.isEmpty else { break }
                let closed = vertices + [vertices[0]]
                for c in 0..<vertices.count {
                    let c1 = closed[c], c2 = closed[c+1]
                    for s in 0..<6 {
                        let t = Double(s) / 6.0
                        let x = Double(c1.x) + t * Double(c2.x - c1.x)
                        let y = Double(c1.y) + t * Double(c2.y - c1.y)
                        pts.append(InkPoint(x: x, y: y, pressure: basePressure, timeOffset: 0.01))
                    }
                }
            }
            return pts
        }
    }

    // MARK: - Recognition Pipeline
    public static func recognize(inkPoints: [InkPoint], config: Config = .default) -> RecognizedShape? {
        let pts = inkPoints.map { CGPoint(x: $0.x, y: $0.y) }
        return recognize(points: pts, config: config)
    }

    public static func recognize(points rawPoints: [CGPoint], config: Config = .default) -> RecognizedShape? {
        // Filter duplicate sequential points
        guard rawPoints.count >= 6 else { return nil }
        var filtered: [CGPoint] = [rawPoints[0]]
        for i in 1..<rawPoints.count {
            if distance(rawPoints[i], filtered.last!) > 1.0 {
                filtered.append(rawPoints[i])
            }
        }
        guard filtered.count >= 6 else { return nil }

        let totalLength = pathLength(points: filtered)
        guard totalLength >= 20.0 else { return nil }

        // Resample into equidistant points
        let resampled = resample(points: filtered, count: config.resampleCount)
        guard resampled.count == config.resampleCount else { return nil }

        let start = resampled.first!
        let end = resampled.last!
        let gap = distance(start, end)
        let isClosed = (gap / totalLength <= config.closedThresholdRatio) || (gap <= config.closedMaxAbsoluteGap && totalLength >= 60.0)

        if !isClosed {
            // Test Open Stroke: Straight line
            let chord = distance(start, end)
            let straightness = chord / totalLength
            if straightness >= config.lineStraightnessThreshold {
                let maxPerp = maxDistanceToSegment(points: resampled, s: start, e: end)
                if maxPerp <= max(14.0, config.lineMaxPerpResidualRatio * chord) {
                    var s = start
                    var e = end
                    // Snap to horizontal / vertical if within 6 degrees
                    let dx = e.x - s.x
                    let dy = e.y - s.y
                    let angle = atan2(abs(dy), abs(dx)) * 180.0 / .pi
                    if angle <= 6.0 {
                        e.y = s.y // Horizontal snap
                    } else if abs(angle - 90.0) <= 6.0 {
                        e.x = s.x // Vertical snap
                    }
                    return .line(start: s, end: e)
                }
            }
            // Non-straight open stroke is left as ink
            return nil
        }

        // Closed Stroke Pipeline
        var closedPoints = resampled
        closedPoints[closedPoints.count - 1] = closedPoints[0] // Explicitly close loop

        let bbox = boundingBox(of: closedPoints)
        let diag = hypot(bbox.width, bbox.height)
        guard diag >= 15.0 else { return nil }

        // Corner Detection on Closed Loop
        let corners = findCorners(closedPoints: closedPoints, k: 4, minAngleDegrees: 38.0)

        switch corners.count {
        case 0, 1:
            // Circle or Ellipse candidate
            let center = CGPoint(x: bbox.midX, y: bbox.midY)
            let a = max(5.0, bbox.width / 2.0)
            let b = max(5.0, bbox.height / 2.0)

            let (meanRes, maxRes) = ellipseResiduals(points: closedPoints, center: center, a: a, b: b)
            if meanRes <= config.ellipseMaxMeanResidual && maxRes <= config.ellipseMaxIndividualResidual {
                let aspectRatio = bbox.width / bbox.height
                if aspectRatio >= config.circleAspectRatioMin && aspectRatio <= config.circleAspectRatioMax {
                    let radius = (bbox.width + bbox.height) / 4.0
                    return .circle(center: center, radius: radius)
                } else {
                    return .ellipse(rect: bbox)
                }
            }
            // High residual (e.g. handwriting loop like 'e', 'g', scribble) stays freehand ink
            return nil

        case 3:
            // Triangle candidate
            let v0 = corners[0], v1 = corners[1], v2 = corners[2]
            let meanRes = meanDistanceToPolygon(points: closedPoints, vertices: [v0, v1, v2])
            if meanRes <= config.polygonMaxMeanResidualRatio * diag {
                return .triangle(p1: v0, p2: v1, p3: v2, boundingBox: bbox)
            }
            return nil

        case 4:
            // Quad candidate: Rectangle vs Diamond
            let v = corners
            // Check Diamond alignment: corners should be close to the 4 edge midpoints of bbox
            let topMid = CGPoint(x: bbox.midX, y: bbox.minY)
            let rightMid = CGPoint(x: bbox.maxX, y: bbox.midY)
            let botMid = CGPoint(x: bbox.midX, y: bbox.maxY)
            let leftMid = CGPoint(x: bbox.minX, y: bbox.midY)
            let diamondMids = [topMid, rightMid, botMid, leftMid]

            var diamondScore: CGFloat = 0
            for corner in v {
                let closestMidDist = diamondMids.map { distance(corner, $0) }.min() ?? diag
                diamondScore += closestMidDist
            }
            diamondScore /= 4.0

            let isDiamond = diamondScore <= (0.24 * diag)

            if isDiamond {
                let meanRes = meanDistanceToPolygon(points: closedPoints, vertices: diamondMids)
                if meanRes <= config.polygonMaxMeanResidualRatio * diag {
                    return .diamond(rect: bbox)
                }
            }

            // Test Rectangle
            // Check orientation of the first edge to determine rotation
            let edgeAngle = atan2(v[1].y - v[0].y, v[1].x - v[0].x) * 180.0 / .pi
            var normAngle = edgeAngle.truncatingRemainder(dividingBy: 90.0)
            if normAngle > 45.0 { normAngle -= 90.0 }
            if normAngle < -45.0 { normAngle += 90.0 }

            var rotationDegrees = 0.0
            if abs(normAngle) > config.axisSnapAngleThresholdDegrees {
                rotationDegrees = Double(normAngle)
            }

            let rectEdges = [
                CGPoint(x: bbox.minX, y: bbox.minY),
                CGPoint(x: bbox.maxX, y: bbox.minY),
                CGPoint(x: bbox.maxX, y: bbox.maxY),
                CGPoint(x: bbox.minX, y: bbox.maxY)
            ]
            let meanRes = meanDistanceToPolygon(points: closedPoints, vertices: rectEdges)
            if meanRes <= config.polygonMaxMeanResidualRatio * diag {
                return .rectangle(rect: bbox, rotationDegrees: rotationDegrees)
            }
            return nil

        case 5, 6:
            // Regular Polygon candidate (Pentagon / Hexagon)
            let meanRes = meanDistanceToPolygon(points: closedPoints, vertices: corners)
            if meanRes <= 0.10 * diag {
                return .polygon(vertices: corners)
            }
            return nil

        default:
            // 7+ corners or highly irregular loop -> keep as ink
            return nil
        }
    }

    // MARK: - Mathematical Geometry Utilities
    public static func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        hypot(p1.x - p2.x, p1.y - p2.y)
    }

    public static func pathLength(points: [CGPoint]) -> CGFloat {
        guard points.count >= 2 else { return 0 }
        var sum: CGFloat = 0
        for i in 0..<(points.count - 1) {
            sum += distance(points[i], points[i+1])
        }
        return sum
    }

    public static func boundingBox(of points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in points {
            minX = min(minX, p.x)
            maxX = max(maxX, p.x)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: max(1.0, maxX - minX), height: max(1.0, maxY - minY))
    }

    public static func resample(points: [CGPoint], count: Int) -> [CGPoint] {
        guard points.count >= 2, count >= 2 else { return points }
        let totalLen = pathLength(points: points)
        guard totalLen > 0.001 else { return Array(repeating: points[0], count: count) }

        let interval = totalLen / CGFloat(count - 1)
        var resampled: [CGPoint] = [points[0]]
        var currentDist: CGFloat = 0.0
        var srcIdx = 0

        var currentP = points[0]
        var targetDist = interval

        while resampled.count < count && srcIdx < points.count - 1 {
            let nextP = points[srcIdx + 1]
            let segLen = distance(currentP, nextP)

            if currentDist + segLen >= targetDist {
                let t = (targetDist - currentDist) / segLen
                let newPt = CGPoint(
                    x: currentP.x + t * (nextP.x - currentP.x),
                    y: currentP.y + t * (nextP.y - currentP.y)
                )
                resampled.append(newPt)
                currentP = newPt
                currentDist = targetDist
                targetDist += interval
            } else {
                currentDist += segLen
                currentP = nextP
                srcIdx += 1
            }
        }

        while resampled.count < count {
            resampled.append(points.last!)
        }
        return resampled
    }

    public static func maxDistanceToSegment(points: [CGPoint], s: CGPoint, e: CGPoint) -> CGFloat {
        var maxD: CGFloat = 0
        for p in points {
            let d = distanceToSegment(p, s: s, e: e)
            if d > maxD { maxD = d }
        }
        return maxD
    }

    public static func distanceToSegment(_ p: CGPoint, s: CGPoint, e: CGPoint) -> CGFloat {
        let dx = e.x - s.x, dy = e.y - s.y
        let lenSq = dx * dx + dy * dy
        if lenSq < 0.0001 { return distance(p, s) }
        let t = max(0.0, min(1.0, ((p.x - s.x) * dx + (p.y - s.y) * dy) / lenSq))
        let proj = CGPoint(x: s.x + t * dx, y: s.y + t * dy)
        return distance(p, proj)
    }

    public static func findCorners(closedPoints: [CGPoint], k: Int = 4, minAngleDegrees: CGFloat = 38.0) -> [CGPoint] {
        let n = closedPoints.count
        guard n >= 16 else { return [] }

        var angles: [(index: Int, angle: CGFloat)] = []

        for i in 0..<n {
            let prevIdx = (i - k + n) % n
            let nextIdx = (i + k) % n
            let pPrev = closedPoints[prevIdx]
            let pCurr = closedPoints[i]
            let pNext = closedPoints[nextIdx]

            let vIn = CGPoint(x: pCurr.x - pPrev.x, y: pCurr.y - pPrev.y)
            let vOut = CGPoint(x: pNext.x - pCurr.x, y: pNext.y - pCurr.y)

            let lenIn = hypot(vIn.x, vIn.y)
            let lenOut = hypot(vOut.x, vOut.y)

            if lenIn > 0.001 && lenOut > 0.001 {
                let dot = (vIn.x * vOut.x + vIn.y * vOut.y) / (lenIn * lenOut)
                let clampedDot = max(-1.0, min(1.0, dot))
                let turnAngleRad = acos(clampedDot)
                let turnAngleDeg = turnAngleRad * 180.0 / .pi
                if turnAngleDeg >= minAngleDegrees {
                    angles.append((index: i, angle: turnAngleDeg))
                }
            }
        }

        // Non-maximum suppression across window k
        var corners: [CGPoint] = []
        angles.sort { $0.angle > $1.angle }

        var takenIndices: Set<Int> = []
        for cand in angles {
            var tooClose = false
            for taken in takenIndices {
                let diff = abs(cand.index - taken)
                let cyclicDiff = min(diff, n - diff)
                if cyclicDiff <= k + 1 {
                    tooClose = true
                    break
                }
            }
            if !tooClose {
                takenIndices.insert(cand.index)
            }
        }

        let sortedIndices = takenIndices.sorted()
        for idx in sortedIndices {
            corners.append(closedPoints[idx])
        }
        return corners
    }

    public static func ellipseResiduals(points: [CGPoint], center: CGPoint, a: CGFloat, b: CGFloat) -> (mean: CGFloat, max: CGFloat) {
        guard !points.isEmpty, a > 0.001, b > 0.001 else { return (1.0, 1.0) }
        var sum: CGFloat = 0
        var maxRes: CGFloat = 0
        for p in points {
            let dx = p.x - center.x
            let dy = p.y - center.y
            let eq = sqrt((dx * dx) / (a * a) + (dy * dy) / (b * b))
            let res = abs(eq - 1.0)
            sum += res
            if res > maxRes { maxRes = res }
        }
        return (sum / CGFloat(points.count), maxRes)
    }

    public static func meanDistanceToPolygon(points: [CGPoint], vertices: [CGPoint]) -> CGFloat {
        guard !points.isEmpty, vertices.count >= 2 else { return 1000.0 }
        var totalDist: CGFloat = 0
        let vCount = vertices.count

        for p in points {
            var minEdgeDist = CGFloat.greatestFiniteMagnitude
            for i in 0..<vCount {
                let s = vertices[i]
                let e = vertices[(i + 1) % vCount]
                let d = distanceToSegment(p, s: s, e: e)
                if d < minEdgeDist { minEdgeDist = d }
            }
            totalDist += minEdgeDist
        }
        return totalDist / CGFloat(points.count)
    }
}
