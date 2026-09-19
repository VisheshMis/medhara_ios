import Foundation
import GRDB

public enum FSRSState: Int, Codable, CaseIterable, Sendable {
    case newCard = 0
    case learning = 1
    case review = 2
    case relearning = 3

    public var displayName: String {
        switch self {
        case .newCard: return "New"
        case .learning: return "Learning"
        case .review: return "Review"
        case .relearning: return "Relearning"
        }
    }

    public var systemIcon: String {
        switch self {
        case .newCard: return "sparkles"
        case .learning: return "brain.head.profile"
        case .review: return "clock.arrow.circlepath"
        case .relearning: return "exclamationmark.arrow.triangle.2.circlepath"
        }
    }
}

public enum FSRSRating: Int, Codable, CaseIterable, Sendable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4

    public var displayName: String {
        switch self {
        case .again: return "Again"
        case .hard: return "Hard"
        case .good: return "Good"
        case .easy: return "Easy"
        }
    }

    public var colorName: String {
        switch self {
        case .again: return "red"
        case .hard: return "orange"
        case .good: return "blue"
        case .easy: return "green"
        }
    }
}

// MARK: - Flashcard Deck
public struct Deck: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var description: String?
    public var colorHex: String
    public var icon: String
    public var isNotesDefault: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = Deck.generateId(),
        name: String,
        description: String? = nil,
        colorHex: String = "#3B82F6",
        icon: String = "rectangle.stack",
        isNotesDefault: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.colorHex = colorHex
        self.icon = icon
        self.isNotesDefault = isNotesDefault
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func generateId() -> String {
        "deck-\(UUID().uuidString.lowercased())"
    }

    public static let notesDefaultId = "deck-notes-default"
}

// MARK: - GRDB Persistence for Deck
extension Deck: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "deck"

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let name = Column(CodingKeys.name)
        public static let description = Column(CodingKeys.description)
        public static let colorHex = Column(CodingKeys.colorHex)
        public static let icon = Column(CodingKeys.icon)
        public static let isNotesDefault = Column(CodingKeys.isNotesDefault)
        public static let createdAt = Column(CodingKeys.createdAt)
        public static let updatedAt = Column(CodingKeys.updatedAt)
    }
}

public struct Flashcard: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var docId: String              // Preserves document/folder hierarchy
    public var notebookId: String
    public var deckId: String?            // Grouping deck association
    public var front: String              // Question / Prompt
    public var back: String               // Answer / Explanation
    public var sourceBlockId: String?     // Linked atomic block
    public var hint: String?

    // FSRS parameters
    public var fsrsState: FSRSState
    public var stability: Double          // Memory stability in days
    public var difficulty: Double         // Scale from 1.0 (easiest) to 10.0 (hardest)
    public var elapsedDays: Int
    public var scheduledDays: Int
    public var reps: Int
    public var lapses: Int
    public var lastReview: Date?
    public var due: Date
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = Flashcard.generateId(),
        docId: String,
        notebookId: String,
        deckId: String? = nil,
        front: String,
        back: String,
        sourceBlockId: String? = nil,
        hint: String? = nil,
        fsrsState: FSRSState = .newCard,
        stability: Double = 0.0,
        difficulty: Double = 0.0,
        elapsedDays: Int = 0,
        scheduledDays: Int = 0,
        reps: Int = 0,
        lapses: Int = 0,
        lastReview: Date? = nil,
        due: Date = Date(),
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.docId = docId
        self.notebookId = notebookId
        self.deckId = deckId
        self.front = front
        self.back = back
        self.sourceBlockId = sourceBlockId
        self.hint = hint
        self.fsrsState = fsrsState
        self.stability = stability
        self.difficulty = difficulty
        self.elapsedDays = elapsedDays
        self.scheduledDays = scheduledDays
        self.reps = reps
        self.lapses = lapses
        self.lastReview = lastReview
        self.due = due
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func generateId() -> String {
        "fc-\(UUID().uuidString.lowercased())"
    }

    public var isDue: Bool {
        due <= Date()
    }
}

// MARK: - GRDB Persistence
extension Flashcard: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "flashcard"

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let docId = Column(CodingKeys.docId)
        public static let notebookId = Column(CodingKeys.notebookId)
        public static let deckId = Column(CodingKeys.deckId)
        public static let front = Column(CodingKeys.front)
        public static let back = Column(CodingKeys.back)
        public static let sourceBlockId = Column(CodingKeys.sourceBlockId)
        public static let hint = Column(CodingKeys.hint)
        public static let fsrsState = Column(CodingKeys.fsrsState)
        public static let stability = Column(CodingKeys.stability)
        public static let difficulty = Column(CodingKeys.difficulty)
        public static let elapsedDays = Column(CodingKeys.elapsedDays)
        public static let scheduledDays = Column(CodingKeys.scheduledDays)
        public static let reps = Column(CodingKeys.reps)
        public static let lapses = Column(CodingKeys.lapses)
        public static let lastReview = Column(CodingKeys.lastReview)
        public static let due = Column(CodingKeys.due)
        public static let createdAt = Column(CodingKeys.createdAt)
        public static let updatedAt = Column(CodingKeys.updatedAt)
    }
}
