import SwiftUI
import AppKit

public struct CardBrowserView: View {
    @ObservedObject public var store: BlockStore
    public let onReturnToDecks: () -> Void

    // Filter Selection
    @State private var selectedFilter: BrowserFilter = .all
    @State private var selectedDeckFilterId: String? = nil
    @State private var searchQuery: String = ""
    @State private var sortOption: CardSortOption = .front
    @State private var sortAscending: Bool = true

    // Selected Card for Inspector
    @State private var selectedCardId: String? = nil
    @State private var isAddCardSheetPresented: Bool = false
    @State private var cardToDelete: Flashcard? = nil
    @State private var isDeleteAlertPresented: Bool = false

    // Live Card Editing draft
    @State private var draftFront: String = ""
    @State private var draftBack: String = ""
    @State private var draftHint: String = ""
    @State private var draftDeckId: String = ""
    @State private var hasUnsavedEdits: Bool = false

    public enum BrowserFilter: String, CaseIterable, Identifiable {
        case all = "All Cards"
        case due = "Due for Review"
        case newCards = "New"
        case learning = "Learning"
        case review = "Mastered"
        case suspended = "Suspended"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .all: return "rectangle.stack"
            case .due: return "clock.badge.checkmark"
            case .newCards: return "sparkles"
            case .learning: return "brain.head.profile"
            case .review: return "checkmark.seal.fill"
            case .suspended: return "pause.circle.fill"
            }
        }

        public var color: Color {
            switch self {
            case .all: return .secondary
            case .due: return .green
            case .newCards: return .blue
            case .learning: return .orange
            case .review: return .purple
            case .suspended: return .yellow
            }
        }
    }

    public enum CardSortOption: String, CaseIterable, Identifiable {
        case front = "Question"
        case due = "Due Date"
        case reps = "Reps"
        case state = "State"
        case stability = "Stability"

        public var id: String { rawValue }
    }

    public init(store: BlockStore, initialDeckId: String? = nil, onReturnToDecks: @escaping () -> Void) {
        self.store = store
        self._selectedDeckFilterId = State(initialValue: initialDeckId)
        self.onReturnToDecks = onReturnToDecks
    }

    private var allCards: [Flashcard] {
        store.flashcards
    }

    private var filteredCards: [Flashcard] {
        var list = allCards

        // 1. Deck Filter
        if let deckId = selectedDeckFilterId {
            if deckId == store.defaultNotesDeck?.id || deckId == Deck.notesDefaultId {
                list = list.filter { $0.deckId == deckId || ($0.deckId == nil && !$0.docId.isEmpty) }
            } else {
                list = list.filter { $0.deckId == deckId }
            }
        }

        // 2. Status Filter
        switch selectedFilter {
        case .all:
            break
        case .due:
            list = list.filter { $0.isDue }
        case .newCards:
            list = list.filter { $0.fsrsState == .newCard && !$0.isEffectivelySuspended }
        case .learning:
            list = list.filter { ($0.fsrsState == .learning || $0.fsrsState == .relearning) && !$0.isEffectivelySuspended }
        case .review:
            list = list.filter { $0.fsrsState == .review && !$0.isEffectivelySuspended }
        case .suspended:
            list = list.filter { $0.isEffectivelySuspended }
        }

        // 3. Search Query
        let query = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            list = list.filter {
                $0.front.lowercased().contains(query) ||
                $0.back.lowercased().contains(query) ||
                ($0.hint?.lowercased().contains(query) ?? false)
            }
        }

        // 4. Sorting
        list.sort { a, b in
            switch sortOption {
            case .front:
                return sortAscending ? a.front.localizedCaseInsensitiveCompare(b.front) == .orderedAscending
                                     : a.front.localizedCaseInsensitiveCompare(b.front) == .orderedDescending
            case .due:
                return sortAscending ? a.due < b.due : a.due > b.due
            case .reps:
                return sortAscending ? a.reps < b.reps : a.reps > b.reps
            case .state:
                return sortAscending ? a.fsrsState.rawValue < b.fsrsState.rawValue : a.fsrsState.rawValue > b.fsrsState.rawValue
            case .stability:
                return sortAscending ? a.stability < b.stability : a.stability > b.stability
            }
        }

        return list
    }

    private var selectedCard: Flashcard? {
        guard let id = selectedCardId else { return nil }
        return store.flashcards.first(where: { $0.id == id })
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Navigation & Action Bar
            topToolbar

            Divider()

            // 3-Pane Browser Layout
            HSplitView {
                // Pane 1: Filter Tree Sidebar
                filterSidebarView
                    .frame(minWidth: 200, idealWidth: 230, maxWidth: 280)

                // Pane 2: Card Table
                cardTablePaneView
                    .frame(minWidth: 380, idealWidth: 460, maxWidth: .infinity)

                // Pane 3: Card Inspector & Live Editor
                cardInspectorPaneView
                    .frame(minWidth: 320, idealWidth: 360, maxWidth: 440)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $isAddCardSheetPresented) {
            AddFlashcardSheet(
                store: store,
                isPresented: $isAddCardSheetPresented,
                preselectedDeckId: selectedDeckFilterId
            )
        }
        .alert("Delete Flashcard", isPresented: $isDeleteAlertPresented, presenting: cardToDelete) { card in
            Button("Delete", role: .destructive) {
                store.deleteFlashcard(id: card.id)
                if selectedCardId == card.id {
                    selectedCardId = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { card in
            Text("Are you sure you want to permanently delete this card? This action cannot be undone.")
        }
        .onAppear {
            if selectedCardId == nil, let first = filteredCards.first {
                selectCard(first)
            }
        }
    }

    // MARK: - Top Toolbar
    private var topToolbar: some View {
        HStack(spacing: 12) {
            Button(action: onReturnToDecks) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                    Text("Decks")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Divider().frame(height: 18)

            // Search Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                TextField("Search cards in collection (front, back, hint)...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .frame(maxWidth: 420)

            // Count Pill
            Text("\(filteredCards.count) cards")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)

            Spacer()

            // Sort Menu
            Menu {
                Picker("Sort Field", selection: $sortOption) {
                    ForEach(CardSortOption.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                Divider()
                Button(action: { sortAscending.toggle() }) {
                    Label(sortAscending ? "Ascending" : "Descending", systemImage: sortAscending ? "arrow.up" : "arrow.down")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text("Sort: \(sortOption.rawValue)")
                }
                .font(.system(size: 11))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 140)

            // Add Card
            Button(action: { isAddCardSheetPresented = true }) {
                Label("Add Card", systemImage: "plus")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Pane 1: Filter Sidebar
    private var filterSidebarView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Section 1: Quick Status Filters
                VStack(alignment: .leading, spacing: 4) {
                    Text("STATUS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)

                    ForEach(BrowserFilter.allCases) { filter in
                        let count = countForFilter(filter)
                        Button(action: {
                            selectedFilter = filter
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: filter.icon)
                                    .foregroundColor(filter.color)
                                    .font(.system(size: 12))
                                    .frame(width: 16)

                                Text(filter.rawValue)
                                    .font(.system(size: 12, weight: selectedFilter == filter ? .semibold : .regular))
                                    .foregroundColor(selectedFilter == filter ? .primary : .secondary)

                                Spacer()

                                Text("\(count)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(selectedFilter == filter ? Color.accentColor.opacity(0.12) : Color.clear)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                // Section 2: Decks Filter
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("DECKS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        if selectedDeckFilterId != nil {
                            Button("Clear") {
                                selectedDeckFilterId = nil
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.horizontal, 8)

                    // All Decks
                    Button(action: { selectedDeckFilterId = nil }) {
                        HStack(spacing: 8) {
                            Image(systemName: "folder")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .frame(width: 16)

                            Text("All Decks")
                                .font(.system(size: 12, weight: selectedDeckFilterId == nil ? .semibold : .regular))
                                .foregroundColor(selectedDeckFilterId == nil ? .primary : .secondary)

                            Spacer()

                            Text("\(allCards.count)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(selectedDeckFilterId == nil ? Color.accentColor.opacity(0.12) : Color.clear)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    // Notes & Documents
                    let notesDeckId = store.defaultNotesDeck?.id ?? Deck.notesDefaultId
                    let notesCardsCount = store.flashcards(forDeck: notesDeckId).count
                    deckFilterRow(
                        id: notesDeckId,
                        name: "Notes & Documents",
                        icon: "note.text",
                        colorHex: "#3B82F6",
                        count: notesCardsCount
                    )

                    // Custom Decks
                    let customDecks = store.decks.filter { !$0.isNotesDefault }
                    ForEach(customDecks) { deck in
                        let count = store.flashcards(forDeck: deck.id).count
                        deckFilterRow(
                            id: deck.id,
                            name: deck.name,
                            icon: deck.icon,
                            colorHex: deck.colorHex,
                            count: count
                        )
                    }
                }
            }
            .padding(12)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
    }

    private func deckFilterRow(id: String, name: String, icon: String, colorHex: String, count: Int) -> some View {
        let isSelected = selectedDeckFilterId == id
        return Button(action: {
            selectedDeckFilterId = id
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hexString: colorHex))
                    .frame(width: 16)

                Text(name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)

                Spacer()

                Text("\(count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func countForFilter(_ filter: BrowserFilter) -> Int {
        switch filter {
        case .all:
            return allCards.count
        case .due:
            return allCards.filter { $0.isDue }.count
        case .newCards:
            return allCards.filter { $0.fsrsState == .newCard && !$0.isEffectivelySuspended }.count
        case .learning:
            return allCards.filter { ($0.fsrsState == .learning || $0.fsrsState == .relearning) && !$0.isEffectivelySuspended }.count
        case .review:
            return allCards.filter { $0.fsrsState == .review && !$0.isEffectivelySuspended }.count
        case .suspended:
            return allCards.filter { $0.isEffectivelySuspended }.count
        }
    }

    // MARK: - Pane 2: Card Table
    private var cardTablePaneView: some View {
        VStack(spacing: 0) {
            // Table Header Bar
            HStack(spacing: 8) {
                Text("QUESTION / FRONT")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("DECK")
                    .frame(width: 110, alignment: .leading)
                Text("STATE")
                    .frame(width: 75, alignment: .center)
                Text("DUE")
                    .frame(width: 80, alignment: .trailing)
                Text("REPS")
                    .frame(width: 45, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.7))

            Divider()

            // Card List Rows
            if filteredCards.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No cards match current filter")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("Try clearing your search query or selecting 'All Cards'.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.8))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(filteredCards) { card in
                                cardRow(card)
                                    .id(card.id)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }

    private func cardRow(_ card: Flashcard) -> some View {
        let isSelected = selectedCardId == card.id
        let deckName = store.deck(withId: card.deckId)?.name ?? "Notes & Documents"

        return Button(action: {
            selectCard(card)
        }) {
            HStack(spacing: 8) {
                // Front / Prompt preview
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.front.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    if let hint = card.hint, !hint.isEmpty {
                        Text("💡 \(hint)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Deck Name Pill
                Text(deckName)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: 110, alignment: .leading)

                // Status Badge
                statusBadge(card)
                    .frame(width: 75, alignment: .center)

                // Due date
                Text(dueLabel(for: card))
                    .font(.system(size: 10, weight: card.isDue ? .bold : .regular))
                    .foregroundColor(card.isDue ? .green : .secondary)
                    .frame(width: 80, alignment: .trailing)

                // Reps
                Text("\(card.reps)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 45, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Reset Progress (Mark New)") {
                store.resetFlashcardProgress(id: card.id)
                if selectedCardId == card.id { selectCard(card) }
            }

            Button(card.isEffectivelySuspended ? "Unsuspend Card" : "Suspend Card") {
                store.toggleSuspendFlashcard(id: card.id)
                if selectedCardId == card.id { selectCard(card) }
            }

            Divider()

            Button(role: .destructive, action: {
                cardToDelete = card
                isDeleteAlertPresented = true
            }) {
                Label("Delete Card", systemImage: "trash")
            }
        }
    }

    private func statusBadge(_ card: Flashcard) -> some View {
        if card.isEffectivelySuspended {
            return AnyView(
                Text("Suspended")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.15))
                    .cornerRadius(4)
            )
        }

        switch card.fsrsState {
        case .newCard:
            return AnyView(
                Text("New")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(4)
            )
        case .learning, .relearning:
            return AnyView(
                Text("Learning")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(4)
            )
        case .review:
            return AnyView(
                Text("Mastered")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.15))
                    .cornerRadius(4)
            )
        }
    }

    private func dueLabel(for card: Flashcard) -> String {
        if card.isEffectivelySuspended { return "Suspended" }
        if card.fsrsState == .newCard { return "New" }
        if card.isDue { return "Due" }

        let days = Calendar.current.dateComponents([.day], from: Date(), to: card.due).day ?? 0
        if days <= 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "In \(days)d"
    }

    // MARK: - Pane 3: Card Inspector & Live Editor
    private var cardInspectorPaneView: some View {
        VStack(spacing: 0) {
            if let card = selectedCard {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        // Inspector Header
                        HStack {
                            Text("CARD INSPECTOR")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            if hasUnsavedEdits {
                                Button("Save Changes") {
                                    saveCardEdits()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }

                        // Target Deck Picker
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Deck Assignment")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)

                            Picker("", selection: $draftDeckId) {
                                Text("Notes & Documents").tag(Deck.notesDefaultId)
                                ForEach(store.decks.filter { !$0.isNotesDefault }) { d in
                                    Text(d.name).tag(d.id)
                                }
                            }
                            .onChange(of: draftDeckId) { newDeck in
                                store.moveFlashcard(id: card.id, toDeckId: newDeck)
                            }
                        }
                        .padding(10)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)

                        // Front Text Field
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Front (Prompt / Question)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)

                            TextEditor(text: $draftFront)
                                .font(.system(size: 12))
                                .frame(height: 70)
                                .padding(4)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(6)
                                .onChange(of: draftFront) { _ in hasUnsavedEdits = true }
                        }

                        // Back Text Field
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Back (Answer / Explanation)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)

                            TextEditor(text: $draftBack)
                                .font(.system(size: 12))
                                .frame(height: 90)
                                .padding(4)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(6)
                                .onChange(of: draftBack) { _ in hasUnsavedEdits = true }
                        }

                        // Hint Text Field
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hint (Optional)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)

                            TextField("Optional memory cue...", text: $draftHint)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                                .onChange(of: draftHint) { _ in hasUnsavedEdits = true }
                        }

                        Divider()

                        // FSRS Learning Metrics Card
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .foregroundColor(.accentColor)
                                Text("FSRS Spaced Repetition Metrics")
                                    .font(.system(size: 11, weight: .bold))
                            }

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                metricItem(label: "State", value: card.fsrsState.displayName)
                                metricItem(label: "Stability (S)", value: String(format: "%.1f days", card.stability))
                                metricItem(label: "Difficulty (D)", value: String(format: "%.1f / 10", card.difficulty))
                                metricItem(label: "Scheduled", value: "\(card.scheduledDays) days")
                                metricItem(label: "Reps / Lapses", value: "\(card.reps) / \(card.lapses)")
                                metricItem(label: "Next Due", value: formattedDate(card.due))
                            }
                        }
                        .padding(12)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)

                        Divider()

                        // Card Actions
                        VStack(spacing: 8) {
                            Button(action: {
                                store.resetFlashcardProgress(id: card.id)
                                selectCard(card)
                            }) {
                                Label("Reset Progress (Mark New)", systemImage: "arrow.counterclockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button(action: {
                                store.toggleSuspendFlashcard(id: card.id)
                                selectCard(card)
                            }) {
                                Label(card.isEffectivelySuspended ? "Unsuspend Card" : "Suspend Card", systemImage: card.isEffectivelySuspended ? "play.circle" : "pause.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button(role: .destructive, action: {
                                cardToDelete = card
                                isDeleteAlertPresented = true
                            }) {
                                Label("Delete Card", systemImage: "trash")
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(14)
                }
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("Select a Card")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("Click on any card in the table to inspect details, edit fields, and track FSRS metrics.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Spacer()
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }

    private func metricItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(4)
    }

    private func selectCard(_ card: Flashcard) {
        if hasUnsavedEdits {
            saveCardEdits()
        }
        selectedCardId = card.id
        draftFront = card.front
        draftBack = card.back
        draftHint = card.hint ?? ""
        draftDeckId = card.deckId ?? Deck.notesDefaultId
        hasUnsavedEdits = false
    }

    private func saveCardEdits() {
        guard let card = selectedCard else { return }
        var updated = card
        updated.front = draftFront
        updated.back = draftBack
        updated.hint = draftHint.isEmpty ? nil : draftHint
        updated.deckId = draftDeckId
        updated.updatedAt = Date()
        store.updateFlashcard(updated)
        hasUnsavedEdits = false
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
