import Foundation
import GRDB

public enum InkTemplateType: String, Codable, CaseIterable, Sendable {
    case blank
    case lined
    case grid
    case dotGrid
    case cornell
    case multiColumn
    case squared
    case staves

    public var displayName: String {
        switch self {
        case .blank: return "Blank"
        case .lined: return "Lined / Ruled"
        case .grid: return "Grid"
        case .dotGrid: return "Dot Grid"
        case .cornell: return "Cornell Notes"
        case .multiColumn: return "2-Column"
        case .squared: return "Engineering 5mm"
        case .staves: return "Music Staves"
        }
    }

    public var systemIcon: String {
        switch self {
        case .blank: return "square"
        case .lined: return "line.3.horizontal"
        case .grid: return "squareshape.split.3x3"
        case .dotGrid: return "circle.grid.3x3"
        case .cornell: return "newspaper"
        case .multiColumn: return "square.split.2x1"
        case .squared: return "squareshape.split.2x2"
        case .staves: return "music.note.list"
        }
    }
}

public struct InkDocumentPage: Identifiable, Codable, FetchableRecord, PersistableRecord, Equatable, Sendable {
    public var id: String             // "inkpage-\(docId)-\(pageIndex)"
    public var docId: String          // References Block.id (where type == .inkDoc)
    public var pageIndex: Int         // 0-indexed page order
    public var templateType: InkTemplateType
    public var strokesData: String    // Serialized JSON vector payload
    public var textProjection: String? // Reserved for future OCR
    public var pdfPath: String?       // Relative filename or absolute path in DocumentAssets
    public var pdfPageIndex: Int?     // 1-based page number in the trimmed PDF
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String? = nil,
        docId: String,
        pageIndex: Int,
        templateType: InkTemplateType = .lined,
        strokesData: String = "{\"schemaVersion\":1,\"pageWidth\":794.0,\"pageHeight\":1123.0,\"strokes\":[]}",
        textProjection: String? = nil,
        pdfPath: String? = nil,
        pdfPageIndex: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id ?? InkDocumentPage.generateId(docId: docId, pageIndex: pageIndex)
        self.docId = docId
        self.pageIndex = pageIndex
        self.templateType = templateType
        self.strokesData = strokesData
        self.textProjection = textProjection
        self.pdfPath = pdfPath
        self.pdfPageIndex = pdfPageIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func generateId(docId: String, pageIndex: Int) -> String {
        "inkpage-\(docId)-\(pageIndex)"
    }
}

extension InkDocumentPage {
    public static let databaseTableName = "ink_document_page"

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let docId = Column(CodingKeys.docId)
        public static let pageIndex = Column(CodingKeys.pageIndex)
        public static let templateType = Column(CodingKeys.templateType)
        public static let strokesData = Column(CodingKeys.strokesData)
        public static let textProjection = Column(CodingKeys.textProjection)
        public static let pdfPath = Column(CodingKeys.pdfPath)
        public static let pdfPageIndex = Column(CodingKeys.pdfPageIndex)
        public static let createdAt = Column(CodingKeys.createdAt)
        public static let updatedAt = Column(CodingKeys.updatedAt)
    }
}
