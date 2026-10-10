import Foundation
import CoreGraphics
import AppKit

// MARK: - Smart Alignment Guide Model
public struct CanvasAlignmentGuide: Equatable, Sendable {
    public enum Orientation: Equatable, Sendable {
        case horizontal(y: CGFloat, minX: CGFloat, maxX: CGFloat)
        case vertical(x: CGFloat, minY: CGFloat, maxY: CGFloat)
    }

    public var orientation: Orientation

    public init(orientation: Orientation) {
        self.orientation = orientation
    }
}

// MARK: - Smart Alignment & Grid Snapping Engine
public struct CanvasSnappingService: Sendable {

    /// Snaps a candidate rectangle against other canvas items and the 20pt background grid.
    /// Returns the snapped rectangle and active alignment guides to render.
    public static func snap(
        rect: CGRect,
        against items: [CanvasItem],
        excludingItemId: String? = nil,
        gridSize: CGFloat = 20.0,
        threshold: CGFloat = 6.0,
        snapToGrid: Bool = true
    ) -> (rect: CGRect, guides: [CanvasAlignmentGuide]) {
        var snappedRect = rect
        var guides: [CanvasAlignmentGuide] = []

        let otherItems = items.filter { $0.id != excludingItemId }

        // 1. Horizontal Alignment (X coordinates / Vertical Guide Lines)
        var bestDeltaX: CGFloat? = nil
        var bestGuideX: CanvasAlignmentGuide? = nil

        let candXList: [(val: CGFloat, type: String)] = [
            (rect.minX, "min"),
            (rect.midX, "mid"),
            (rect.maxX, "max")
        ]

        for item in otherItems {
            let itemBBox = CGRect(x: item.x, y: item.y, width: item.width, height: item.height)
            let targetXList: [CGFloat] = [itemBBox.minX, itemBBox.midX, itemBBox.maxX]

            for cand in candXList {
                for targetX in targetXList {
                    let diff = targetX - cand.val
                    if abs(diff) <= threshold {
                        if bestDeltaX == nil || abs(diff) < abs(bestDeltaX!) {
                            bestDeltaX = diff
                            let minY = min(rect.minY, itemBBox.minY) - 30.0
                            let maxY = max(rect.maxY, itemBBox.maxY) + 30.0
                            bestGuideX = CanvasAlignmentGuide(orientation: .vertical(x: targetX, minY: minY, maxY: maxY))
                        }
                    }
                }
            }
        }

        if let deltaX = bestDeltaX {
            snappedRect.origin.x += deltaX
            if let g = bestGuideX { guides.append(g) }
        } else if snapToGrid {
            // Fallback: Grid Snap for Left Edge
            let nearestGridX = round(rect.minX / gridSize) * gridSize
            if abs(nearestGridX - rect.minX) <= threshold {
                snappedRect.origin.x = nearestGridX
            }
        }

        // 2. Vertical Alignment (Y coordinates / Horizontal Guide Lines)
        var bestDeltaY: CGFloat? = nil
        var bestGuideY: CanvasAlignmentGuide? = nil

        let candYList: [(val: CGFloat, type: String)] = [
            (rect.minY, "min"),
            (rect.midY, "mid"),
            (rect.maxY, "max")
        ]

        for item in otherItems {
            let itemBBox = CGRect(x: item.x, y: item.y, width: item.width, height: item.height)
            let targetYList: [CGFloat] = [itemBBox.minY, itemBBox.midY, itemBBox.maxY]

            for cand in candYList {
                for targetY in targetYList {
                    let diff = targetY - cand.val
                    if abs(diff) <= threshold {
                        if bestDeltaY == nil || abs(diff) < abs(bestDeltaY!) {
                            bestDeltaY = diff
                            let minX = min(rect.minX, itemBBox.minX) - 30.0
                            let maxX = max(rect.maxX, itemBBox.maxX) + 30.0
                            bestGuideY = CanvasAlignmentGuide(orientation: .horizontal(y: targetY, minX: minX, maxX: maxX))
                        }
                    }
                }
            }
        }

        if let deltaY = bestDeltaY {
            snappedRect.origin.y += deltaY
            if let g = bestGuideY { guides.append(g) }
        } else if snapToGrid {
            // Fallback: Grid Snap for Top Edge
            let nearestGridY = round(rect.minY / gridSize) * gridSize
            if abs(nearestGridY - rect.minY) <= threshold {
                snappedRect.origin.y = nearestGridY
            }
        }

        return (snappedRect, guides)
    }

    /// Renders active alignment guide lines in the viewport CoreGraphics context
    public static func drawGuides(_ guides: [CanvasAlignmentGuide], in context: CGContext, zoomScale: CGFloat) {
        guard !guides.isEmpty else { return }

        context.saveGState()
        context.setStrokeColor(NSColor(calibratedRed: 0.05, green: 0.65, blue: 1.0, alpha: 0.85).cgColor) // Vivid Cyan/Sky Blue
        context.setLineWidth(1.0 / zoomScale)
        let dashes: [CGFloat] = [4.0 / zoomScale, 4.0 / zoomScale]
        context.setLineDash(phase: 0, lengths: dashes)

        for guide in guides {
            context.beginPath()
            switch guide.orientation {
            case .horizontal(let y, let minX, let maxX):
                context.move(to: CGPoint(x: minX, y: y))
                context.addLine(to: CGPoint(x: maxX, y: y))
            case .vertical(let x, let minY, let maxY):
                context.move(to: CGPoint(x: x, y: minY))
                context.addLine(to: CGPoint(x: x, y: maxY))
            }
            context.strokePath()
        }

        context.restoreGState()
    }
}
