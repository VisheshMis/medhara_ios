import Foundation

public final class DailyStudyTracker: ObservableObject {
    public static let shared = DailyStudyTracker()

    private let userDefaultsKey = "MedhaDailyStudyTracker_v1"

    public struct DailyRecord: Codable {
        public var dateString: String // "yyyy-MM-dd"
        public var newCardIdsByDeck: [String: [String]] // deckId -> [cardId]
        public var reviewCardIdsByDeck: [String: [String]] // deckId -> [cardId]
        public var extraNewLimitByDeck: [String: Int] // deckId -> bonus new cards today
    }

    @Published public private(set) var currentRecord: DailyRecord

    private init() {
        let today = Self.todayString()
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let record = try? JSONDecoder().decode(DailyRecord.self, from: data),
           record.dateString == today {
            self.currentRecord = record
        } else {
            self.currentRecord = DailyRecord(
                dateString: today,
                newCardIdsByDeck: [:],
                reviewCardIdsByDeck: [:],
                extraNewLimitByDeck: [:]
            )
        }
    }

    public static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }

    private func checkRollover() {
        let today = Self.todayString()
        if currentRecord.dateString != today {
            currentRecord = DailyRecord(
                dateString: today,
                newCardIdsByDeck: [:],
                reviewCardIdsByDeck: [:],
                extraNewLimitByDeck: [:]
            )
            save()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(currentRecord) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    public func newCardsStudiedCount(forDeckId deckId: String) -> Int {
        checkRollover()
        return currentRecord.newCardIdsByDeck[deckId]?.count ?? 0
    }

    public func reviewsStudiedCount(forDeckId deckId: String) -> Int {
        checkRollover()
        return currentRecord.reviewCardIdsByDeck[deckId]?.count ?? 0
    }

    public func extraNewLimit(forDeckId deckId: String) -> Int {
        checkRollover()
        return currentRecord.extraNewLimitByDeck[deckId] ?? 0
    }

    public func increaseTodayNewLimit(forDeckId deckId: String, by count: Int) {
        checkRollover()
        let current = currentRecord.extraNewLimitByDeck[deckId] ?? 0
        currentRecord.extraNewLimitByDeck[deckId] = current + count
        save()
    }

    public func resetToday(forDeckId deckId: String) {
        checkRollover()
        currentRecord.newCardIdsByDeck.removeValue(forKey: deckId)
        currentRecord.reviewCardIdsByDeck.removeValue(forKey: deckId)
        currentRecord.extraNewLimitByDeck.removeValue(forKey: deckId)
        save()
    }

    public func recordCardReviewed(card: Flashcard, deckId: String, wasNew: Bool) {
        checkRollover()
        if wasNew {
            var currentList = currentRecord.newCardIdsByDeck[deckId] ?? []
            if !currentList.contains(card.id) {
                currentList.append(card.id)
                currentRecord.newCardIdsByDeck[deckId] = currentList
                save()
            }
        } else if card.fsrsState == .review {
            var currentList = currentRecord.reviewCardIdsByDeck[deckId] ?? []
            if !currentList.contains(card.id) {
                currentList.append(card.id)
                currentRecord.reviewCardIdsByDeck[deckId] = currentList
                save()
            }
        }
    }

    /// Returns the effective new cards eligible for study today for a given deck, respecting daily limits
    public func effectiveNewCards(
        from allCards: [Flashcard],
        deckId: String,
        options: DeckOptions
    ) -> [Flashcard] {
        checkRollover()
        let availableNew = allCards.filter { $0.fsrsState == .newCard && !$0.isEffectivelySuspended }
        let studiedToday = newCardsStudiedCount(forDeckId: deckId)
        let extraLimit = extraNewLimit(forDeckId: deckId)
        let dailyCap = max(0, options.maxNewCardsPerDay + extraLimit - studiedToday)

        guard dailyCap > 0 else { return [] }

        // Sort new cards according to options
        let sortedNew: [Flashcard]
        switch options.newCardSortOrder {
        case .orderAdded:
            sortedNew = availableNew.sorted { $0.createdAt < $1.createdAt }
        case .cardType:
            sortedNew = availableNew.sorted { $0.front < $1.front }
        case .orderGathered:
            sortedNew = availableNew
        }

        if options.insertionOrder == .random {
            return Array(sortedNew.shuffled().prefix(dailyCap))
        } else {
            return Array(sortedNew.prefix(dailyCap))
        }
    }

    /// Returns the effective review cards eligible for study today for a given deck, respecting review limits
    public func effectiveReviewCards(
        from allCards: [Flashcard],
        deckId: String,
        options: DeckOptions
    ) -> [Flashcard] {
        checkRollover()
        let availableDueReviews = allCards.filter { $0.fsrsState == .review && $0.isDue }
        let studiedToday = reviewsStudiedCount(forDeckId: deckId)
        let dailyCap = max(0, options.maxReviewsPerDay - studiedToday)

        guard dailyCap > 0 else { return [] }

        let sortedReviews: [Flashcard]
        switch options.reviewSortOrder {
        case .dueDate:
            sortedReviews = availableDueReviews.sorted { $0.due < $1.due }
        case .random:
            sortedReviews = availableDueReviews.shuffled()
        case .deck:
            sortedReviews = availableDueReviews
        }

        return Array(sortedReviews.prefix(dailyCap))
    }

    /// Assembles the complete study queue conforming to Anki's display order & daily limits
    public func queueForStudy(
        allCards: [Flashcard],
        deck: Deck?,
        options: DeckOptions
    ) -> [Flashcard] {
        if let targetDeck = deck {
            let deckId = targetDeck.id
            let queuedNew = effectiveNewCards(from: allCards, deckId: deckId, options: options)
            let queuedReviews = effectiveReviewCards(from: allCards, deckId: deckId, options: options)
            let learningCards = allCards.filter {
                ($0.fsrsState == .learning || $0.fsrsState == .relearning) && !$0.isEffectivelySuspended
            }

            var result: [Flashcard] = []
            // Learning cards take precedence
            result.append(contentsOf: learningCards)

            switch options.newReviewOrder {
            case .beforeReviews:
                result.append(contentsOf: queuedNew)
                result.append(contentsOf: queuedReviews)
            case .afterReviews:
                result.append(contentsOf: queuedReviews)
                result.append(contentsOf: queuedNew)
            case .mixWithReviews:
                var rIdx = 0
                var nIdx = 0
                while rIdx < queuedReviews.count || nIdx < queuedNew.count {
                    if rIdx < queuedReviews.count {
                        result.append(queuedReviews[rIdx])
                        rIdx += 1
                    }
                    if nIdx < queuedNew.count {
                        result.append(queuedNew[nIdx])
                        nIdx += 1
                    }
                }
            }

            return result
        } else {
            // Aggregate across all decks with their own options
            let grouped = Dictionary(grouping: allCards, by: { $0.deckId ?? Deck.notesDefaultId })
            var combined: [Flashcard] = []
            for (dId, cards) in grouped {
                let dOptions = DeckOptionsManager.shared.options(forDeck: nil)
                combined.append(contentsOf: queueForStudy(
                    allCards: cards,
                    deck: Deck(id: dId, name: "Deck"),
                    options: dOptions
                ))
            }
            return combined
        }
    }
}
