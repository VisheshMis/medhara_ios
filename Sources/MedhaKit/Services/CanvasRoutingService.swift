import Foundation
import CoreGraphics
import AppKit

public struct ConnectorPathResult {
    public let path: CGPath
    public let midPoint: CGPoint
    public let endAngle: CGFloat // Angle in radians for vector arrowhead orientation
}

public enum CanvasRoutingService {

    /// Calculates waypoints and path for a connector based on routing type
    public static func computeRoute(
        from startPt: CGPoint,
        startPort: CanvasPortPosition,
        to endPt: CGPoint,
        endPort: CanvasPortPosition,
        routingType: ConnectorRoutingType
    ) -> ConnectorPathResult {
        switch routingType {
        case .straight:
            let path = CGMutablePath()
            path.move(to: startPt)
            path.addLine(to: endPt)
            let mid = CGPoint(x: (startPt.x + endPt.x) / 2.0, y: (startPt.y + endPt.y) / 2.0)
            let angle = atan2(endPt.y - startPt.y, endPt.x - startPt.x)
            return ConnectorPathResult(path: path, midPoint: mid, endAngle: angle)

        case .curved:
            return computeCurvedRoute(from: startPt, startPort: startPort, to: endPt, endPort: endPort)

        case .orthogonal:
            return computeOrthogonalRoute(from: startPt, startPort: startPort, to: endPt, endPort: endPort)
        }
    }

    /// Cubic Bezier routing with tangent control points extended along normal vectors
    private static func computeCurvedRoute(
        from startPt: CGPoint,
        startPort: CanvasPortPosition,
        to endPt: CGPoint,
        endPort: CanvasPortPosition
    ) -> ConnectorPathResult {
        let dx = endPt.x - startPt.x
        let dy = endPt.y - startPt.y
        let distance = max(40.0, hypot(dx, dy))
        let offset = min(200.0, max(30.0, distance * 0.45))

        let startNormal = startPort.normalVector
        let endNormal = endPort.normalVector

        let cp1 = CGPoint(
            x: startPt.x + startNormal.dx * offset,
            y: startPt.y + startNormal.dy * offset
        )
        let cp2 = CGPoint(
            x: endPt.x + endNormal.dx * offset,
            y: endPt.y + endNormal.dy * offset
        )

        let path = CGMutablePath()
        path.move(to: startPt)
        path.addCurve(to: endPt, control1: cp1, control2: cp2)

        // Evaluate Bezier midpoint at t = 0.5
        // B(0.5) = 0.125*P0 + 0.375*P1 + 0.375*P2 + 0.125*P3
        let midX = 0.125 * startPt.x + 0.375 * cp1.x + 0.375 * cp2.x + 0.125 * endPt.x
        let midY = 0.125 * startPt.y + 0.375 * cp1.y + 0.375 * cp2.y + 0.125 * endPt.y

        // Tangent angle at arrival (cp2 -> endPt)
        let angle = atan2(endPt.y - cp2.y, endPt.x - cp2.x)

        return ConnectorPathResult(path: path, midPoint: CGPoint(x: midX, y: midY), endAngle: angle)
    }

    /// Orthogonal (Manhattan 90°) step routing
    private static func computeOrthogonalRoute(
        from startPt: CGPoint,
        startPort: CanvasPortPosition,
        to endPt: CGPoint,
        endPort: CanvasPortPosition
    ) -> ConnectorPathResult {
        let path = CGMutablePath()
        path.move(to: startPt)

        let stubDistance: CGFloat = 20.0
        let p1 = CGPoint(
            x: startPt.x + startPort.normalVector.dx * stubDistance,
            y: startPt.y + startPort.normalVector.dy * stubDistance
        )
        let p2 = CGPoint(
            x: endPt.x + endPort.normalVector.dx * stubDistance,
            y: endPt.y + endPort.normalVector.dy * stubDistance
        )

        var waypoints: [CGPoint] = [startPt, p1]

        // Connect p1 to p2 using Manhattan steps
        if startPort == .left || startPort == .right {
            if endPort == .left || endPort == .right {
                // Horizontal to Horizontal: Jog horizontally at midpoint
                let midX = (p1.x + p2.x) / 2.0
                waypoints.append(CGPoint(x: midX, y: p1.y))
                waypoints.append(CGPoint(x: midX, y: p2.y))
            } else {
                // Horizontal to Vertical
                waypoints.append(CGPoint(x: p2.x, y: p1.y))
            }
        } else {
            if endPort == .top || endPort == .bottom {
                // Vertical to Vertical: Jog vertically at midpoint
                let midY = (p1.y + p2.y) / 2.0
                waypoints.append(CGPoint(x: p1.x, y: midY))
                waypoints.append(CGPoint(x: p2.x, y: midY))
            } else {
                // Vertical to Horizontal
                waypoints.append(CGPoint(x: p1.x, y: p2.y))
            }
        }

        waypoints.append(p2)
        waypoints.append(endPt)

        // Draw segmented line
        for i in 1..<waypoints.count {
            path.addLine(to: waypoints[i])
        }

        // Center calculation along waypoints
        let midIndex = waypoints.count / 2
        let mid = waypoints[midIndex]

        // Arrival vector angle (last waypoint to endPt)
        let lastSegment = waypoints[waypoints.count - 2]
        let angle = atan2(endPt.y - lastSegment.y, endPt.x - lastSegment.x)

        return ConnectorPathResult(path: path, midPoint: mid, endAngle: angle)
    }

    /// Renders a sharp vector arrowhead pointing at endPt
    public static func drawArrowhead(
        at endPt: CGPoint,
        angle: CGFloat,
        size: CGFloat = 10.0,
        color: NSColor,
        in context: CGContext
    ) {
        context.saveGState()
        context.setFillColor(color.cgColor)

        let arrowLength: CGFloat = size
        let arrowHalfWidth: CGFloat = size * 0.45

        let backX = endPt.x - arrowLength * cos(angle)
        let backY = endPt.y - arrowLength * sin(angle)

        let normalAngle = angle + .pi / 2.0
        let pLeft = CGPoint(
            x: backX + arrowHalfWidth * cos(normalAngle),
            y: backY + arrowHalfWidth * sin(normalAngle)
        )
        let pRight = CGPoint(
            x: backX - arrowHalfWidth * cos(normalAngle),
            y: backY - arrowHalfWidth * sin(normalAngle)
        )

        let arrowPath = CGMutablePath()
        arrowPath.move(to: endPt)
        arrowPath.addLine(to: pLeft)
        arrowPath.addLine(to: pRight)
        arrowPath.closeSubpath()

        context.addPath(arrowPath)
        context.fillPath()
        context.restoreGState()
    }
}
