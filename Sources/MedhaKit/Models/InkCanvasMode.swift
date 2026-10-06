import Foundation

public enum InkCanvasMode: String, Codable, CaseIterable, Sendable {
    case a4Pages
    case infiniteVertical
    case infinite2D

    public var displayName: String {
        switch self {
        case .a4Pages: return "A4 Pages"
        case .infiniteVertical: return "Infinite Long Sheet"
        case .infinite2D: return "Open Space 2D Infinite"
        }
    }

    public var systemIcon: String {
        switch self {
        case .a4Pages: return "doc.on.doc"
        case .infiniteVertical: return "arrow.up.and.down.square"
        case .infinite2D: return "arrow.up.left.and.down.right.magnifyingglass"
        }
    }

    public var badgeLabel: String {
        switch self {
        case .a4Pages: return "A4 Pages"
        case .infiniteVertical: return "Infinite Long"
        case .infinite2D: return "2D Infinite"
        }
    }

    public var description: String {
        switch self {
        case .a4Pages:
            return "Standard paginated A4 sheets with page cards, ideal for document export and printing."
        case .infiniteVertical:
            return "A continuous vertical scroll sheet that seamlessly grows downward as you write."
        case .infinite2D:
            return "An unbounded 2D canvas with open panning and zooming in every direction."
        }
    }
}
