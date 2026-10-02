import Foundation

// MARK: - Insertion Order
public enum DeckInsertionOrder: String, CaseIterable, Identifiable, Codable, Sendable {
    case sequential = "Sequential (order added)"
    case random = "Random"

    public var id: String { rawValue }
}

// MARK: - Leech Action
public enum DeckLeechAction: String, CaseIterable, Identifiable, Codable, Sendable {
    case tagOnly = "Tag Only"
    case suspend = "Suspend Card"

    public var id: String { rawValue }
}

// MARK: - New Card Gather Order
public enum NewCardGatherOrder: String, CaseIterable, Identifiable, Codable, Sendable {
    case deck = "Deck Position"
    case ascending = "Ascending Position"
    case descending = "Descending Position"
    case random = "Random"

    public var id: String { rawValue }
}

// MARK: - New Card Sort Order
public enum NewCardSortOrder: String, CaseIterable, Identifiable, Codable, Sendable {
    case cardType = "Card Type"
    case orderAdded = "Order Added"
    case orderGathered = "Order Gathered"

    public var id: String { rawValue }
}

// MARK: - New / Review Order
public enum NewReviewOrder: String, CaseIterable, Identifiable, Codable, Sendable {
    case beforeReviews = "Show Before Reviews"
    case afterReviews = "Show After Reviews"
    case mixWithReviews = "Mix With Reviews"

    public var id: String { rawValue }
}

// MARK: - Interday Learning / Review Order
public enum InterdayOrder: String, CaseIterable, Identifiable, Codable, Sendable {
    case beforeReviews = "Show Before Reviews"
    case afterReviews = "Show After Reviews"

    public var id: String { rawValue }
}

// MARK: - Review Sort Order
public enum ReviewSortOrder: String, CaseIterable, Identifiable, Codable, Sendable {
    case dueDate = "Due Date"
    case deck = "Deck"
    case random = "Random"

    public var id: String { rawValue }
}

// MARK: - Comprehensive Deck Options
public struct DeckOptions: Codable, Equatable, Sendable {
    // 1. Daily Limits
    public var maxNewCardsPerDay: Int
    public var maxReviewsPerDay: Int

    // 2. New Cards
    public var learningSteps: String // e.g. "1m 10m"
    public var insertionOrder: DeckInsertionOrder

    // 3. Lapses
    public var relearningSteps: String // e.g. "10m"
    public var leechThreshold: Int // e.g. 8
    public var leechAction: DeckLeechAction

    // 4. Display Order
    public var newCardGatherOrder: NewCardGatherOrder
    public var newCardSortOrder: NewCardSortOrder
    public var newReviewOrder: NewReviewOrder
    public var interdayOrder: InterdayOrder
    public var reviewSortOrder: ReviewSortOrder

    // 5. FSRS Settings
    public var desiredRetention: Double // e.g. 0.90 (90%)
    public var maximumInterval: Int // e.g. 36500 (days)
    public var historicalRetention: Double

    public init(
        maxNewCardsPerDay: Int = 20,
        maxReviewsPerDay: Int = 200,
        learningSteps: String = "1m 10m",
        insertionOrder: DeckInsertionOrder = .sequential,
        relearningSteps: String = "10m",
        leechThreshold: Int = 8,
        leechAction: DeckLeechAction = .tagOnly,
        newCardGatherOrder: NewCardGatherOrder = .deck,
        newCardSortOrder: NewCardSortOrder = .orderAdded,
        newReviewOrder: NewReviewOrder = .afterReviews,
        interdayOrder: InterdayOrder = .beforeReviews,
        reviewSortOrder: ReviewSortOrder = .dueDate,
        desiredRetention: Double = 0.90,
        maximumInterval: Int = 36500,
        historicalRetention: Double = 0.90
    ) {
        self.maxNewCardsPerDay = maxNewCardsPerDay
        self.maxReviewsPerDay = maxReviewsPerDay
        self.learningSteps = learningSteps
        self.insertionOrder = insertionOrder
        self.relearningSteps = relearningSteps
        self.leechThreshold = leechThreshold
        self.leechAction = leechAction
        self.newCardGatherOrder = newCardGatherOrder
        self.newCardSortOrder = newCardSortOrder
        self.newReviewOrder = newReviewOrder
        self.interdayOrder = interdayOrder
        self.reviewSortOrder = reviewSortOrder
        self.desiredRetention = desiredRetention
        self.maximumInterval = maximumInterval
        self.historicalRetention = historicalRetention
    }
}

// MARK: - Deck Options Preset
public struct DeckOptionsPreset: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var isDefault: Bool
    public var options: DeckOptions

    public init(
        id: String = UUID().uuidString.lowercased(),
        name: String,
        isDefault: Bool = false,
        options: DeckOptions = DeckOptions()
    ) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.options = options
    }

    public static let defaultPresetId = "preset-default"
}

// MARK: - Presets Store / Manager
public final class DeckOptionsManager: ObservableObject {
    public static let shared = DeckOptionsManager()

    private let userDefaultsKey = "MedhaDeckOptionsPresets_v1"

    @Published public var presets: [DeckOptionsPreset] = []

    public init() {
        loadPresets()
    }

    public var defaultPreset: DeckOptionsPreset {
        presets.first(where: { $0.isDefault }) ?? presets.first ?? DeckOptionsPreset(
            id: DeckOptionsPreset.defaultPresetId,
            name: "Default",
            isDefault: true,
            options: DeckOptions()
        )
    }

    public func preset(withId id: String?) -> DeckOptionsPreset {
        guard let id = id else { return defaultPreset }
        return presets.first(where: { $0.id == id }) ?? defaultPreset
    }

    public func options(forDeck deck: Deck?) -> DeckOptions {
        preset(withId: deck?.presetId).options
    }

    public func savePreset(_ preset: DeckOptionsPreset) {
        if let idx = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[idx] = preset
        } else {
            presets.append(preset)
        }
        persist()
    }

    public func createPreset(name: String, basedOn: DeckOptions = DeckOptions()) -> DeckOptionsPreset {
        let newPreset = DeckOptionsPreset(
            id: "preset-\(UUID().uuidString.prefix(8).lowercased())",
            name: name,
            isDefault: false,
            options: basedOn
        )
        presets.append(newPreset)
        persist()
        return newPreset
    }

    public func deletePreset(id: String) {
        // Cannot delete default preset
        guard let p = presets.first(where: { $0.id == id }), !p.isDefault else { return }
        presets.removeAll(where: { $0.id == id })
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(presets)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Failed to save deck option presets: \(error)")
        }
    }

    private func loadPresets() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            do {
                let decoded = try JSONDecoder().decode([DeckOptionsPreset].self, from: data)
                if !decoded.isEmpty {
                    self.presets = decoded
                    return
                }
            } catch {
                print("Failed to decode saved deck options presets: \(error)")
            }
        }

        // Seed with Default preset
        let def = DeckOptionsPreset(
            id: DeckOptionsPreset.defaultPresetId,
            name: "Default",
            isDefault: true,
            options: DeckOptions()
        )
        self.presets = [def]
        persist()
    }
}
