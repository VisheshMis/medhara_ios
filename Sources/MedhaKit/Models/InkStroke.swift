import Foundation

// MARK: - Ink Tool Type
public enum InkToolType: String, Codable, CaseIterable, Sendable {
    case ballpoint
    case fountain
    case highlighter
    case eraser
    case lasso
    case tape

    public var displayName: String {
        switch self {
        case .ballpoint: return "Pen"
        case .fountain: return "Fountain"
        case .highlighter: return "Highlighter"
        case .eraser: return "Eraser"
        case .lasso: return "Lasso"
        case .tape: return "Tape"
        }
    }

    public var systemIcon: String {
        switch self {
        case .ballpoint: return "pencil.tip"
        case .fountain: return "signature"
        case .highlighter: return "highlighter"
        case .eraser: return "eraser"
        case .lasso: return "lasso"
        case .tape: return "bandage.fill"
        }
    }

    public var defaultWidth: Double {
        switch self {
        case .ballpoint: return 2.5
        case .fountain: return 3.5
        case .highlighter: return 18.0
        case .eraser: return 16.0
        case .lasso: return 1.0
        case .tape: return 28.0
        }
    }
}

// MARK: - Stroke Pattern (Solid, Dashed, Dotted)
public enum StrokePattern: String, Codable, CaseIterable, Sendable {
    case solid
    case dashed
    case dotted
}

// MARK: - Point in Vector Stroke
public struct InkPoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var pressure: Double     // 0.0 to 1.0
    public var timeOffset: Double   // relative seconds from stroke start

    public init(x: Double, y: Double, pressure: Double = 0.5, timeOffset: Double = 0.0) {
        self.x = x
        self.y = y
        self.pressure = pressure
        self.timeOffset = timeOffset
    }
}

// MARK: - Single Vector Stroke
public struct InkStroke: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var tool: InkToolType
    public var colorHex: String
    public var baseWidth: Double
    public var opacity: Double
    public var points: [InkPoint]
    public var pattern: StrokePattern?
    public var isTapeRevealed: Bool?
    public var shapePrimitive: String?

    public init(
        id: String = "s-\(UUID().uuidString.lowercased())",
        tool: InkToolType = .ballpoint,
        colorHex: String = "#1E293B",
        baseWidth: Double = 2.5,
        opacity: Double = 1.0,
        points: [InkPoint] = [],
        pattern: StrokePattern? = .solid,
        isTapeRevealed: Bool? = false,
        shapePrimitive: String? = nil
    ) {
        self.id = id
        self.tool = tool
        self.colorHex = colorHex
        self.baseWidth = baseWidth
        self.opacity = opacity
        self.points = points
        self.pattern = pattern
        self.isTapeRevealed = isTapeRevealed
        self.shapePrimitive = shapePrimitive
    }

    // Bounding Box calculation for collision & viewport culling
    public var boundingRect: (minX: Double, minY: Double, maxX: Double, maxY: Double) {
        guard let first = points.first else {
            return (0, 0, 0, 0)
        }
        var minX = first.x
        var minY = first.y
        var maxX = first.x
        var maxY = first.y
        let pad = baseWidth * 2.0

        for pt in points {
            if pt.x < minX { minX = pt.x }
            if pt.y < minY { minY = pt.y }
            if pt.x > maxX { maxX = pt.x }
            if pt.y > maxY { maxY = pt.y }
        }
        return (minX - pad, minY - pad, maxX + pad, maxY + pad)
    }
}

// MARK: - Page Vector Payload
public struct InkPagePayload: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var pageWidth: Double
    public var pageHeight: Double
    public var strokes: [InkStroke]

    public init(
        schemaVersion: Int = 1,
        pageWidth: Double = 794.0,   // Standard A4 point width (72 dpi)
        pageHeight: Double = 1123.0, // Standard A4 point height
        strokes: [InkStroke] = []
    ) {
        self.schemaVersion = schemaVersion
        self.pageWidth = pageWidth
        self.pageHeight = pageHeight
        self.strokes = strokes
    }

    public static func empty(width: Double = 794.0, height: Double = 1123.0) -> InkPagePayload {
        InkPagePayload(schemaVersion: 1, pageWidth: width, pageHeight: height, strokes: [])
    }

    public func serialize() -> String {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(self), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{\"schemaVersion\":1,\"pageWidth\":\(pageWidth),\"pageHeight\":\(pageHeight),\"strokes\":[]}"
    }

    public static func deserialize(from jsonString: String) -> InkPagePayload {
        guard let data = jsonString.data(using: .utf8) else {
            return .empty()
        }
        let decoder = JSONDecoder()
        if let payload = try? decoder.decode(InkPagePayload.self, from: data) {
            return payload
        }
        return .empty()
    }
}
