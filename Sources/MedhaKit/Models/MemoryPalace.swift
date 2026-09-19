import Foundation
import GRDB

public struct MemoryPalace: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var imagePath: String
    public var imageData: String?        // Optional base64 or vector data for custom/bundled floorplans
    public var description: String?
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = MemoryPalace.generateId(),
        name: String,
        imagePath: String,
        imageData: String? = nil,
        description: String? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.imagePath = imagePath
        self.imageData = imageData
        self.description = description
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func generateId() -> String {
        "mp-\(UUID().uuidString.lowercased())"
    }
}

extension MemoryPalace: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "memory_palace"

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let name = Column(CodingKeys.name)
        public static let imagePath = Column(CodingKeys.imagePath)
        public static let imageData = Column(CodingKeys.imageData)
        public static let description = Column(CodingKeys.description)
        public static let sortOrder = Column(CodingKeys.sortOrder)
        public static let createdAt = Column(CodingKeys.createdAt)
        public static let updatedAt = Column(CodingKeys.updatedAt)
    }
}

public struct PalaceLocus: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var palaceId: String
    public var photoId: String?         // Linked sequential photo/scene in the palace
    public var flashcardId: String?     // Legacy single-flashcard link
    public var docId: String?           // Linked source note/folder
    public var title: String            // Physical locus name (e.g. "Front Porch", "Grand Fireplace")
    public var mnemonic: String?        // Vivid spatial association imagery
    public var anchoredInfo: String?     // Direct anchored information/notes without flashcards
    public var normalizedX: Double      // 0.0 to 1.0 (relative X on 2D image)
    public var normalizedY: Double      // 0.0 to 1.0 (relative Y on 2D image)
    public var orderIndex: Int          // Step sequence in memory palace walk
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = PalaceLocus.generateId(),
        palaceId: String,
        photoId: String? = nil,
        flashcardId: String? = nil,
        docId: String? = nil,
        title: String,
        mnemonic: String? = nil,
        anchoredInfo: String? = nil,
        normalizedX: Double,
        normalizedY: Double,
        orderIndex: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.palaceId = palaceId
        self.photoId = photoId
        self.flashcardId = flashcardId
        self.docId = docId
        self.title = title
        self.mnemonic = mnemonic
        self.anchoredInfo = anchoredInfo
        self.normalizedX = normalizedX
        self.normalizedY = normalizedY
        self.orderIndex = orderIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func generateId() -> String {
        "locus-\(UUID().uuidString.lowercased())"
    }
}

extension PalaceLocus: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "palace_locus"

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let palaceId = Column(CodingKeys.palaceId)
        public static let photoId = Column(CodingKeys.photoId)
        public static let flashcardId = Column(CodingKeys.flashcardId)
        public static let docId = Column(CodingKeys.docId)
        public static let title = Column(CodingKeys.title)
        public static let mnemonic = Column(CodingKeys.mnemonic)
        public static let anchoredInfo = Column(CodingKeys.anchoredInfo)
        public static let normalizedX = Column(CodingKeys.normalizedX)
        public static let normalizedY = Column(CodingKeys.normalizedY)
        public static let orderIndex = Column(CodingKeys.orderIndex)
        public static let createdAt = Column(CodingKeys.createdAt)
        public static let updatedAt = Column(CodingKeys.updatedAt)
    }
}

public struct PalacePhoto: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var palaceId: String
    public var name: String
    public var imagePath: String
    public var imageData: String?
    public var orderIndex: Int
    public var canvasX: Double
    public var canvasY: Double
    public var canvasWidth: Double
    public var canvasHeight: Double
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = PalacePhoto.generateId(),
        palaceId: String,
        name: String,
        imagePath: String,
        imageData: String? = nil,
        orderIndex: Int = 0,
        canvasX: Double = 100.0,
        canvasY: Double = 100.0,
        canvasWidth: Double = 420.0,
        canvasHeight: Double = 280.0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.palaceId = palaceId
        self.name = name
        self.imagePath = imagePath
        self.imageData = imageData
        self.orderIndex = orderIndex
        self.canvasX = canvasX
        self.canvasY = canvasY
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func generateId() -> String {
        "photo-\(UUID().uuidString.lowercased())"
    }
}

extension PalacePhoto: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "palace_photo"

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let palaceId = Column(CodingKeys.palaceId)
        public static let name = Column(CodingKeys.name)
        public static let imagePath = Column(CodingKeys.imagePath)
        public static let imageData = Column(CodingKeys.imageData)
        public static let orderIndex = Column(CodingKeys.orderIndex)
        public static let canvasX = Column(CodingKeys.canvasX)
        public static let canvasY = Column(CodingKeys.canvasY)
        public static let canvasWidth = Column(CodingKeys.canvasWidth)
        public static let canvasHeight = Column(CodingKeys.canvasHeight)
        public static let createdAt = Column(CodingKeys.createdAt)
        public static let updatedAt = Column(CodingKeys.updatedAt)
    }
}

public struct LocusFlashcard: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var locusId: String
    public var flashcardId: String
    public var sortOrder: Int
    public var createdAt: Date

    public init(
        id: String = LocusFlashcard.generateId(),
        locusId: String,
        flashcardId: String,
        sortOrder: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.locusId = locusId
        self.flashcardId = flashcardId
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }

    public static func generateId() -> String {
        "lf-\(UUID().uuidString.lowercased())"
    }
}

extension LocusFlashcard: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "locus_flashcard"

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let locusId = Column(CodingKeys.locusId)
        public static let flashcardId = Column(CodingKeys.flashcardId)
        public static let sortOrder = Column(CodingKeys.sortOrder)
        public static let createdAt = Column(CodingKeys.createdAt)
    }
}

