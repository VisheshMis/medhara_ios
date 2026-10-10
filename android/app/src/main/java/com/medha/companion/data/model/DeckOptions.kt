package com.medha.companion.data.model

import kotlinx.serialization.Serializable
import java.time.Instant
import java.util.UUID

@Serializable
enum class DeckInsertionOrder(val displayName: String, val rawValue: String) {
    SEQUENTIAL("Sequential (order added)", "sequential"),
    RANDOM("Random", "random");

    companion object {
        fun fromValue(value: String): DeckInsertionOrder =
            entries.firstOrNull { it.rawValue.equals(value, ignoreCase = true) } ?: SEQUENTIAL
    }
}

@Serializable
enum class DeckLeechAction(val displayName: String, val rawValue: String) {
    TAG_ONLY("Tag Only", "tagOnly"),
    SUSPEND("Suspend Card", "suspend");

    companion object {
        fun fromValue(value: String): DeckLeechAction =
            entries.firstOrNull { it.rawValue.equals(value, ignoreCase = true) } ?: TAG_ONLY
    }
}

@Serializable
enum class NewCardGatherOrder(val displayName: String, val rawValue: String) {
    DECK("Deck Position", "deck"),
    ASCENDING("Ascending Position", "ascending"),
    DESCENDING("Descending Position", "descending"),
    RANDOM("Random", "random");

    companion object {
        fun fromValue(value: String): NewCardGatherOrder =
            entries.firstOrNull { it.rawValue.equals(value, ignoreCase = true) } ?: DECK
    }
}

@Serializable
enum class NewCardSortOrder(val displayName: String, val rawValue: String) {
    CARD_TYPE("Card Type", "cardType"),
    ORDER_ADDED("Order Added", "orderAdded"),
    ORDER_GATHERED("Order Gathered", "orderGathered");

    companion object {
        fun fromValue(value: String): NewCardSortOrder =
            entries.firstOrNull { it.rawValue.equals(value, ignoreCase = true) } ?: ORDER_ADDED
    }
}

@Serializable
enum class NewReviewOrder(val displayName: String, val rawValue: String) {
    BEFORE_REVIEWS("Show Before Reviews", "beforeReviews"),
    AFTER_REVIEWS("Show After Reviews", "afterReviews"),
    MIX_WITH_REVIEWS("Mix With Reviews", "mixWithReviews");

    companion object {
        fun fromValue(value: String): NewReviewOrder =
            entries.firstOrNull { it.rawValue.equals(value, ignoreCase = true) } ?: AFTER_REVIEWS
    }
}

@Serializable
enum class InterdayOrder(val displayName: String, val rawValue: String) {
    BEFORE_REVIEWS("Show Before Reviews", "beforeReviews"),
    AFTER_REVIEWS("Show After Reviews", "afterReviews");

    companion object {
        fun fromValue(value: String): InterdayOrder =
            entries.firstOrNull { it.rawValue.equals(value, ignoreCase = true) } ?: BEFORE_REVIEWS
    }
}

@Serializable
enum class ReviewSortOrder(val displayName: String, val rawValue: String) {
    DUE_DATE("Due Date", "dueDate"),
    DECK("Deck", "deck"),
    RANDOM("Random", "random");

    companion object {
        fun fromValue(value: String): ReviewSortOrder =
            entries.firstOrNull { it.rawValue.equals(value, ignoreCase = true) } ?: DUE_DATE
    }
}

@Serializable
data class DeckOptions(
    val id: String = generateId(),
    val name: String = "Default",
    val isDefault: Boolean = false,
    val maxNewCardsPerDay: Int = 20,
    val maxReviewsPerDay: Int = 200,
    val learningSteps: String = "1m 10m",
    val insertionOrder: String = "sequential",
    val relearningSteps: String = "10m",
    val leechThreshold: Int = 8,
    val leechAction: String = "tagOnly",
    val newCardGatherOrder: String = "deck",
    val newCardSortOrder: String = "orderAdded",
    val newReviewOrder: String = "afterReviews",
    val interdayOrder: String = "beforeReviews",
    val reviewSortOrder: String = "dueDate",
    val desiredRetention: Double = 0.90,
    val maximumInterval: Int = 36500,
    val historicalRetention: Double = 0.90,
    val createdAt: String = Instant.now().toString(),
    val updatedAt: String = Instant.now().toString()
) {
    val parsedInsertionOrder: DeckInsertionOrder
        get() = DeckInsertionOrder.fromValue(insertionOrder)

    val parsedLeechAction: DeckLeechAction
        get() = DeckLeechAction.fromValue(leechAction)

    val parsedNewCardGatherOrder: NewCardGatherOrder
        get() = NewCardGatherOrder.fromValue(newCardGatherOrder)

    val parsedNewCardSortOrder: NewCardSortOrder
        get() = NewCardSortOrder.fromValue(newCardSortOrder)

    val parsedNewReviewOrder: NewReviewOrder
        get() = NewReviewOrder.fromValue(newReviewOrder)

    val parsedInterdayOrder: InterdayOrder
        get() = InterdayOrder.fromValue(interdayOrder)

    val parsedReviewSortOrder: ReviewSortOrder
        get() = ReviewSortOrder.fromValue(reviewSortOrder)

    companion object {
        const val DEFAULT_PRESET_ID = "preset-default"

        fun generateId(): String = "preset-${UUID.randomUUID().toString().substring(0, 8)}"
    }
}
