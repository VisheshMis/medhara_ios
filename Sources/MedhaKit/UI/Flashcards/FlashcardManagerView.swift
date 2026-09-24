import SwiftUI
import AppKit


public struct FlashcardManagerView: View {
    @ObservedObject public var store: BlockStore
    @State private var isStudyModeActive: Bool = false
    @State private var isAddCardSheetPresented: Bool = false
    @State private var isCreateDeckSheetPresented: Bool = false
    @State private var isAISettingsSheetPresented: Bool = false
    @State private var filterSelection: FlashcardFilter = .all
    @State private var searchQuery: String = ""
    @State private var notesViewMode: NotesDeckViewMode = .folders

    public enum FlashcardFilter: String, CaseIterable, Identifiable {
        case all = "All Cards"
        case due = "Due for Review"
        case newCards = "New"
        case learning = "Learning"
        case review = "Mastered"

        public var id: String { rawValue }
    }

    public enum NotesDeckViewMode: String, CaseIterable, Identifiable {
        case folders = "Grouped by Note Folder"
        case flat = "Flat Card List"

        public var id: String { rawValue }
    }

    public init(store: BlockStore) {
        self.store = store
    }

    private var currentDeck: Deck? {
        store.selectedDeck
    }

    private var isNotesDeckSelected: Bool {
        store.selectedDeckId == (store.defaultNotesDeck?.id ?? Deck.notesDefaultId)
    }

    private var isAllCardsSelected: Bool {
        store.selectedDeckId == nil || store.selectedDeckId == "all"
    }

    private var deckCards: [Flashcard] {
        store.flashcards(forDeck: store.selectedDeckId)
    }

    private var filteredCards: [Flashcard] {
        var list = deckCards
        switch filterSelection {
        case .all:
            break
        case .due:
            list = list.filter { $0.isDue }
        case .newCards:
            list = list.filter { $0.fsrsState == .newCard }
        case .learning:
            list = list.filter { $0.fsrsState == .learning || $0.fsrsState == .relearning }
        case .review:
            list = list.filter { $0.fsrsState == .review }
        }

        if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            let q = searchQuery.lowercased()
            list = list.filter {
                $0.front.lowercased().contains(q) ||
                $0.back.lowercased().contains(q) ||
                ($0.hint?.lowercased().contains(q) ?? false)
            }
        }
        return list
    }

    public var body: some View {
        Group {
            if isStudyModeActive {
                FlashcardStudySessionView(
                    store: store,
                    deck: isAllCardsSelected ? nil : currentDeck,
                    onDismiss: { isStudyModeActive = false }
                )
            } else {
                HSplitView {
                    deckSidebarView
                        .frame(minWidth: 230, idealWidth: 260, maxWidth: 320)

                    deckDetailContentView
                        .frame(minWidth: 500, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .sheet(isPresented: $isAddCardSheetPresented) {
            AddFlashcardSheet(
                store: store,
                isPresented: $isAddCardSheetPresented,
                preselectedDeckId: store.selectedDeckId
            )
        }
        .sheet(isPresented: $isCreateDeckSheetPresented) {
            CreateDeckSheet(
                store: store,
                isPresented: $isCreateDeckSheetPresented
            )
        }
        .sheet(isPresented: $isAISettingsSheetPresented) {
            AISettingsSheet(onDismiss: { isAISettingsSheetPresented = false })
        }
    }

    // MARK: - Deck Navigation Sidebar
    private var deckSidebarView: some View {
        VStack(spacing: 0) {
            // Sidebar Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 13))
                    Text("DECKS")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    isCreateDeckSheetPresented = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("New Deck")
                    }
                    .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(spacing: 14) {
                    // System Smart Decks
                    VStack(spacing: 4) {
                        // All Cards
                        deckRow(
                            id: "all",
                            title: "All Flashcards",
                            subtitle: "Global library collection",
                            icon: "rectangle.stack.fill",
                            colorHex: "#6B7280",
                            count: store.flashcards.count,
                            dueCount: store.dueFlashcards.count,
                            isSelected: isAllCardsSelected
                        )

                        // Notes & Documents Deck (Pinned Default)
                        let notesDeckId = store.defaultNotesDeck?.id ?? Deck.notesDefaultId
                        let notesCards = store.flashcards(forDeck: notesDeckId)
                        let notesDue = notesCards.filter { $0.isDue }.count
                        deckRow(
                            id: notesDeckId,
                            title: store.defaultNotesDeck?.name ?? "Notes & Documents",
                            subtitle: "Auto-grouped from notes & folders",
                            icon: store.defaultNotesDeck?.icon ?? "note.text",
                            colorHex: store.defaultNotesDeck?.colorHex ?? "#3B82F6",
                            count: notesCards.count,
                            dueCount: notesDue,
                            isSelected: store.selectedDeckId == notesDeckId
                        )
                    }

                    // Custom Decks Section
                    let customDecks = store.decks.filter { !$0.isNotesDefault }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("CUSTOM DECKS (\(customDecks.count))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 8)

                        if customDecks.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.rectangle.on.rectangle")
                                    .font(.system(size: 24))
                                    .foregroundColor(.secondary.opacity(0.4))
                                Text("No Custom Decks")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text("Click '+ New Deck' above to organize your topics.")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 12)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                            .cornerRadius(8)
                        } else {
                            VStack(spacing: 4) {
                                ForEach(customDecks) { deck in
                                    let cCards = store.flashcards(forDeck: deck.id)
                                    let cDue = cCards.filter { $0.isDue }.count
                                    deckRow(
                                        id: deck.id,
                                        title: deck.name,
                                        subtitle: deck.description,
                                        icon: deck.icon,
                                        colorHex: deck.colorHex,
                                        count: cCards.count,
                                        dueCount: cDue,
                                        isSelected: store.selectedDeckId == deck.id
                                    )
                                    .contextMenu {
                                        Button("Delete Deck", role: .destructive) {
                                            store.deleteDeck(id: deck.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(12)
            }
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
    }

    private func deckRow(
        id: String,
        title: String,
        subtitle: String?,
        icon: String,
        colorHex: String,
        count: Int,
        dueCount: Int,
        isSelected: Bool
    ) -> some View {
        Button(action: {
            store.selectedDeckId = id
        }) {
            HStack(spacing: 10) {
                // Deck Color Avatar & Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hexString: colorHex).opacity(0.18))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hexString: colorHex))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    if let sub = subtitle, !sub.isEmpty {
                        Text(sub)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Count Pill
                Text("\(count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)

                // Due Badge (if any)
                if dueCount > 0 {
                    Text("\(dueCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Deck Detail Main Panel
    private var deckDetailContentView: some View {
        VStack(spacing: 0) {
            // Deck Banner & Actions
            HStack(spacing: 14) {
                // Deck Icon Avatar
                let activeColor = Color(hexString: currentDeck?.colorHex ?? (isNotesDeckSelected ? "#3B82F6" : "#6B7280"))
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(activeColor.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: isAllCardsSelected ? "rectangle.stack.fill" : (currentDeck?.icon ?? (isNotesDeckSelected ? "note.text" : "rectangle.stack")))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(activeColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(isAllCardsSelected ? "All Flashcards" : (currentDeck?.name ?? "Notes & Documents"))
                            .font(.system(size: 18, weight: .bold))

                        if isNotesDeckSelected {
                            Text("AUTO-GROUPED NOTES")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.12))
                                .cornerRadius(4)
                        }
                    }

                    Text(isAllCardsSelected ? "Complete flashcard collection across all folders and custom decks." : (currentDeck?.description ?? "Auto-grouped collection of flashcards generated from the notes and folder hierarchy."))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Stat metrics
                let dCards = deckCards
                let dDue = dCards.filter { $0.isDue }.count
                HStack(spacing: 12) {
                    VStack(alignment: .center, spacing: 2) {
                        Text("\(dCards.count)")
                            .font(.system(size: 14, weight: .bold))
                        Text("Total")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }

                    Divider().frame(height: 24)

                    VStack(alignment: .center, spacing: 2) {
                        Text("\(dDue)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(dDue > 0 ? .red : .green)
                        Text("Due")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                // Study Deck Button
                Button(action: {
                    isStudyModeActive = true
                }) {
                    Label(
                        isAllCardsSelected ? "Study All Cards" : "Study Deck",
                        systemImage: "play.circle.fill"
                    )
                    .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .disabled(dCards.isEmpty)

                // Add Card to Deck Button
                Button(action: {
                    isAddCardSheetPresented = true
                }) {
                    Label("Add Card", systemImage: "plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)

                // AI Socratic Settings Button
                Button(action: {
                    isAISettingsSheetPresented = true
                }) {
                    Label("AI Socratic", systemImage: "sparkles")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .help("Configure Socratic AI written recall & API key")
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Filters & Controls Toolbar
            HStack(spacing: 12) {
                // For Notes Deck: Option to toggle Folders view vs Flat view
                if isNotesDeckSelected {
                    Picker("View Mode", selection: $notesViewMode) {
                        ForEach(NotesDeckViewMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 290)
                }

                // Filter
                Picker("Filter", selection: $filterSelection) {
                    ForEach(FlashcardFilter.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)

                Spacer()

                // Search box
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    TextField("Search deck cards...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .frame(width: 200)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))

            Divider()

            // Content Area
            if isNotesDeckSelected && notesViewMode == .folders && searchQuery.isEmpty && filterSelection == .all {
                notesGroupedFolderView
            } else {
                flatCardListView
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }

    // MARK: - Notes Grouped by Folder View
    private var notesGroupedFolderView: some View {
        let groups = store.noteGroupedFlashcards()
        return ScrollView {
            if groups.isEmpty {
                emptyDeckPlaceholder
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            // Folder Group Header
                            HStack(spacing: 8) {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 13))

                                Text(group.doc.content.isEmpty ? "Untitled Note" : group.doc.content)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.primary)

                                Spacer()

                                Text("\(group.cards.count) cards")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)

                                // Quick navigate to note in editor
                                Button(action: {
                                    store.activeMainView = .editor
                                    store.selectDocument(id: group.doc.id)
                                }) {
                                    HStack(spacing: 4) {
                                        Text("Open Note")
                                        Image(systemName: "arrow.up.right.square")
                                    }
                                    .font(.system(size: 10, weight: .semibold))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                            .cornerRadius(8)

                            // Cards under this note folder
                            VStack(spacing: 6) {
                                ForEach(group.cards) { card in
                                    FlashcardRowView(store: store, card: card, showFolderBadge: false)
                                }
                            }
                            .padding(.leading, 12)
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Flat Card List View
    private var flatCardListView: some View {
        ScrollView {
            if filteredCards.isEmpty {
                emptyDeckPlaceholder
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(filteredCards) { card in
                        FlashcardRowView(store: store, card: card, showFolderBadge: true)
                    }
                }
                .padding(16)
            }
        }
    }

    private var emptyDeckPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.portrait.on.rectangle.portrait.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            Text(searchQuery.isEmpty ? "No Flashcards in this Deck" : "No Matches for '\(searchQuery)'")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            Text(isNotesDeckSelected ? "Extract flashcards from any note or click 'Add Card' to add a card to this note collection." : "Click '+ Add Card' to create cards stored directly inside this deck.")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
            Button("Add First Card to Deck") {
                isAddCardSheetPresented = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Flashcard Row View
public struct FlashcardRowView: View {
    @ObservedObject public var store: BlockStore
    public let card: Flashcard
    public var showFolderBadge: Bool = true

    private var docTitle: String {
        store.documents.first(where: { $0.id == card.docId })?.content ?? "Root Document"
    }

    private var deckName: String {
        if let dId = card.deckId, let deck = store.decks.first(where: { $0.id == dId }) {
            return deck.name
        }
        return "Notes & Documents"
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Folder badge
                if showFolderBadge {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                        Text(docTitle)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
                }

                // Deck badge
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 10))
                    Text(deckName)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundColor(.accentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.08))
                .cornerRadius(4)

                Spacer()

                // FSRS State Badge
                HStack(spacing: 4) {
                    Image(systemName: card.fsrsState.systemIcon)
                        .font(.system(size: 9))
                    Text(card.fsrsState.displayName)
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(stateColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(stateColor.opacity(0.12))
                .cornerRadius(4)

                // Due Date Badge
                Text(card.isDue ? "Due Now" : "Due in \(daysUntilDue)d")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(card.isDue ? .red : .secondary)

                // Delete Menu
                Menu {
                    Button("Delete Card", role: .destructive) {
                        store.deleteFlashcard(id: card.id)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                }
                .menuStyle(.borderlessButton)
            }

            // Card Front (Question)
            Text(card.front)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            // Card Back (Answer)
            Text(card.back)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(3)

            // FSRS Metrics Footer
            HStack(spacing: 12) {
                Text("Stability: \(String(format: "%.1f", card.stability))d")
                Text("Difficulty: \(String(format: "%.1f", card.difficulty))/10")
                Text("Reviews: \(card.reps)")
                if card.lapses > 0 {
                    Text("Lapses: \(card.lapses)")
                        .foregroundColor(.red.opacity(0.8))
                }
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }

    private var stateColor: Color {
        switch card.fsrsState {
        case .newCard: return .purple
        case .learning: return .orange
        case .review: return .green
        case .relearning: return .red
        }
    }

    private var daysUntilDue: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: card.due).day ?? 0)
    }
}

// MARK: - Create Custom Deck Sheet
public struct CreateDeckSheet: View {
    @ObservedObject public var store: BlockStore
    @Binding public var isPresented: Bool

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var selectedColorHex: String = "#6366F1"
    @State private var selectedIcon: String = "rectangle.stack"

    private let availableColors = [
        ("#3B82F6", "Blue"),
        ("#6366F1", "Indigo"),
        ("#8B5CF6", "Purple"),
        ("#EC4899", "Rose"),
        ("#F59E0B", "Amber"),
        ("#10B981", "Emerald"),
        ("#14B8A6", "Teal"),
        ("#6B7280", "Slate")
    ]

    private let availableIcons = [
        "rectangle.stack",
        "brain.head.profile",
        "sparkles",
        "book.closed",
        "cpu",
        "flask",
        "lightbulb",
        "globe.americas",
        "terminal",
        "chart.bar"
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "plus.rectangle.on.rectangle")
                        .foregroundColor(.accentColor)
                    Text("Create New Deck")
                        .font(.system(size: 15, weight: .bold))
                }
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Deck Name
            VStack(alignment: .leading, spacing: 4) {
                Text("Deck Name")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("e.g. Cognitive Psychology, Algorithms, Anatomy", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            // Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Description (Optional)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("e.g. High-yield definitions and algorithmic invariants", text: $description)
                    .textFieldStyle(.roundedBorder)
            }

            // Color Palette
            VStack(alignment: .leading, spacing: 6) {
                Text("Theme Color")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    ForEach(availableColors, id: \.0) { hex, label in
                        Circle()
                            .fill(Color(hexString: hex))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: selectedColorHex == hex ? 2.5 : 0)
                            )
                            .onTapGesture {
                                selectedColorHex = hex
                            }
                    }
                }
            }

            // Icon Picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Deck Icon")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 10) {
                    ForEach(availableIcons, id: \.self) { icon in
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedIcon == icon ? Color(hexString: selectedColorHex).opacity(0.2) : Color(NSColor.controlBackgroundColor))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(hexString: selectedColorHex), lineWidth: selectedIcon == icon ? 2 : 0.5)
                                )

                            Image(systemName: icon)
                                .font(.system(size: 14))
                                .foregroundColor(selectedIcon == icon ? Color(hexString: selectedColorHex) : .secondary)
                        }
                        .onTapGesture {
                            selectedIcon = icon
                        }
                    }
                }
            }

            Divider()

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                Spacer()
                Button("Create Deck") {
                    store.createDeck(
                        name: name,
                        description: description.isEmpty ? nil : description,
                        colorHex: selectedColorHex,
                        icon: selectedIcon
                    )
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}

// MARK: - Add Flashcard Modal Sheet
public struct AddFlashcardSheet: View {
    @ObservedObject public var store: BlockStore
    @Binding public var isPresented: Bool
    public var preselectedDeckId: String? = nil
    public var preselectedDocId: String? = nil

    @State private var targetDeckId: String = ""
    @State private var targetDocId: String = ""
    @State private var front: String = ""
    @State private var back: String = ""
    @State private var hint: String = ""

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("New Flashcard (FSRS)")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Target Deck Selector
            VStack(alignment: .leading, spacing: 4) {
                Text("Target Deck")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                Picker("", selection: $targetDeckId) {
                    // Notes deck
                    let notesId = store.defaultNotesDeck?.id ?? Deck.notesDefaultId
                    Text("📁 Notes & Documents (Auto-grouped)").tag(notesId)

                    // Custom decks
                    ForEach(store.decks.filter { !$0.isNotesDefault }) { deck in
                        Text(deck.name).tag(deck.id)
                    }
                }
                .labelsHidden()
            }

            // Target Note Folder (Shown if Notes Deck is chosen)
            let notesId = store.defaultNotesDeck?.id ?? Deck.notesDefaultId
            if targetDeckId == notesId {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Associated Note / Folder")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    Picker("", selection: $targetDocId) {
                        ForEach(store.documents) { doc in
                            Text(doc.content.isEmpty ? "Untitled Note" : doc.content).tag(doc.id)
                        }
                    }
                    .labelsHidden()
                }
            }

            // Front
            VStack(alignment: .leading, spacing: 4) {
                Text("Front (Prompt / Question)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("e.g. What is the FSRS retrievability formula?", text: $front)
                    .textFieldStyle(.roundedBorder)
            }

            // Back
            VStack(alignment: .leading, spacing: 4) {
                Text("Back (Answer / Explanation)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                TextEditor(text: $back)
                    .font(.system(size: 12))
                    .frame(height: 90)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
            }

            // Hint
            VStack(alignment: .leading, spacing: 4) {
                Text("Hint (Optional)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("e.g. Think about power law vs exponential decay", text: $hint)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                Spacer()
                Button("Create Flashcard") {
                    store.createFlashcard(
                        docId: targetDocId.isEmpty ? nil : targetDocId,
                        deckId: targetDeckId,
                        front: front,
                        back: back,
                        hint: hint.isEmpty ? nil : hint
                    )
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(front.trimmingCharacters(in: .whitespaces).isEmpty || back.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 460)
        .onAppear {
            let notesId = store.defaultNotesDeck?.id ?? Deck.notesDefaultId
            if let preDeck = preselectedDeckId, preDeck != "all" {
                targetDeckId = preDeck
            } else if let activeDeck = store.selectedDeckId, activeDeck != "all" {
                targetDeckId = activeDeck
            } else {
                targetDeckId = notesId
            }

            targetDocId = preselectedDocId ?? store.selectedDocId ?? store.documents.first?.id ?? ""
        }
    }
}

// MARK: - Study Session View
public struct FlashcardStudySessionView: View {
    @ObservedObject public var store: BlockStore
    @ObservedObject public var aiSettings: AISettings = AISettings.shared
    public var deck: Deck? = nil
    public let onDismiss: () -> Void

    @State private var currentIndex: Int = 0
    @State private var isAnswerRevealed: Bool = false
    @State private var sessionCards: [Flashcard] = []

    // AI Socratic State
    @State private var isAISocraticActive: Bool = true
    @State private var isAISettingsSheetPresented: Bool = false
    @State private var writtenAnswer: String = ""
    @State private var dialogueHistory: [AISocraticTurn] = []
    @State private var isAIEvaluating: Bool = false
    @State private var evaluationError: String? = nil
    @State private var latestEvaluation: AISocraticEvaluation? = nil
    @FocusState private var isWrittenInputFocused: Bool

    public init(store: BlockStore, deck: Deck? = nil, onDismiss: @escaping () -> Void) {
        self.store = store
        self.deck = deck
        self.onDismiss = onDismiss
    }

    private var currentCard: Flashcard? {
        guard currentIndex >= 0 && currentIndex < sessionCards.count else { return nil }
        return sessionCards[currentIndex]
    }

    private var isCurrentCardFirstTime: Bool {
        guard let card = currentCard else { return false }
        return card.reps == 0 || card.fsrsState == .newCard
    }

    private var isSocraticActiveForCurrentCard: Bool {
        guard isAISocraticActive && aiSettings.isSocraticEnabled && aiSettings.hasAPIKey else {
            return false
        }
        if aiSettings.newCardsOnly {
            return isCurrentCardFirstTime
        }
        return true
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onDismiss) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Exit Session")
                    }
                    .font(.system(size: 12))
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 2) {
                    Text(deck != nil ? "Studying: \(deck!.name)" : "Global Review Session")
                        .font(.system(size: 12, weight: .bold))

                    if !sessionCards.isEmpty {
                        Text("Card \(currentIndex + 1) of \(sessionCards.count)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // AI Socratic Quick Toggle & Settings
                HStack(spacing: 8) {
                    Button(action: {
                        if !aiSettings.hasAPIKey {
                            isAISettingsSheetPresented = true
                        } else {
                            isAISocraticActive.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .foregroundColor(isAISocraticActive && aiSettings.hasAPIKey ? .purple : .secondary)
                            Text(isAISocraticActive && aiSettings.hasAPIKey ? "AI Tutor: ON" : "AI Tutor: OFF")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(isAISocraticActive && aiSettings.hasAPIKey ? .purple : .secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isAISocraticActive && aiSettings.hasAPIKey ? Color.purple.opacity(0.12) : Color.gray.opacity(0.12))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help(aiSettings.hasAPIKey ? "Toggle Socratic AI written recall" : "Configure API key to enable Socratic AI Tutor")

                    Button(action: { isAISettingsSheetPresented = true }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("AI Socratic Settings & API Key")

                    Button("Finish") {
                        onDismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor))

            // Top Study Progress Bar
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 3)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: sessionCards.isEmpty ? 0 : g.size.width * CGFloat(currentIndex + 1) / CGFloat(sessionCards.count), height: 3)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentIndex)
                }
            }
            .frame(height: 3)

            Divider()

            if sessionCards.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("All Caught Up!")
                        .font(.system(size: 18, weight: .bold))
                    Text("No flashcards are currently due in \(deck?.name ?? "this collection").")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Button("Back to Decks", action: onDismiss)
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let card = currentCard {
                // Interactive Card
                VStack(spacing: 20) {
                    Spacer()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Card Header: Category + Socratic Tag
                            HStack {
                                if let doc = store.documents.first(where: { $0.id == card.docId }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "folder.fill")
                                            .font(.system(size: 10))
                                        Text(doc.content.isEmpty ? "Folder" : doc.content)
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .foregroundColor(.accentColor)
                                }

                                Spacer()

                                if isSocraticActiveForCurrentCard {
                                    HStack(spacing: 4) {
                                        Image(systemName: "sparkles")
                                        Text(isCurrentCardFirstTime ? "First-Time Card (Written Recall)" : "Socratic AI Active")
                                    }
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.purple.opacity(0.12))
                                    .cornerRadius(5)
                                }
                            }

                            // Question / Front
                            Text(card.front)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)

                            if let hint = card.hint, !hint.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "lightbulb")
                                    Text("Hint: \(hint)")
                                }
                                .font(.system(size: 12).italic())
                                .foregroundColor(.orange)
                            }

                            // Socratic Dialogue History
                            if !dialogueHistory.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(dialogueHistory) { turn in
                                        VStack(alignment: .leading, spacing: 5) {
                                            // User Answer
                                            HStack(alignment: .top, spacing: 6) {
                                                Image(systemName: "person.circle.fill")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.secondary)
                                                Text(turn.userAnswer)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.primary)
                                            }
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(NSColor.textBackgroundColor).opacity(0.6))
                                            .cornerRadius(6)

                                            // AI Feedback
                                            HStack(alignment: .top, spacing: 6) {
                                                Image(systemName: "sparkles")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.purple)
                                                Text(turn.feedback)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.primary)
                                            }
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color.purple.opacity(0.08))
                                            .cornerRadius(6)

                                            // Counter-Question Callout
                                            if let cq = turn.counterQuestion, !turn.isSpotOn {
                                                HStack(alignment: .top, spacing: 6) {
                                                    Image(systemName: "brain.head.profile")
                                                        .font(.system(size: 13))
                                                        .foregroundColor(.orange)
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text("SOCRATIC COUNTER-QUESTION")
                                                            .font(.system(size: 9, weight: .bold))
                                                            .foregroundColor(.orange)
                                                        Text(cq)
                                                            .font(.system(size: 12, weight: .semibold))
                                                            .foregroundColor(.primary)
                                                    }
                                                }
                                                .padding(10)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color.orange.opacity(0.12))
                                                .cornerRadius(8)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                                )
                                            }
                                        }
                                    }
                                }
                            }

                            // Socratic Written Input (before answer is revealed)
                            if isSocraticActiveForCurrentCard && !isAnswerRevealed {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(dialogueHistory.isEmpty ? "Type your explanation from memory:" : "Refine your answer addressing the counter-question:")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("⌘ + Enter to submit")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }

                                    TextEditor(text: $writtenAnswer)
                                        .focused($isWrittenInputFocused)
                                        .font(.system(size: 13))
                                        .frame(minHeight: 65, maxHeight: 95)
                                        .padding(4)
                                        .background(Color(NSColor.textBackgroundColor))
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                                        )

                                    if let errorMsg = evaluationError {
                                        HStack(spacing: 6) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.red)
                                            Text(errorMsg)
                                                .font(.system(size: 11))
                                                .foregroundColor(.red)
                                        }
                                    }

                                    HStack(spacing: 12) {
                                        Button(action: submitWrittenAnswer) {
                                            HStack(spacing: 6) {
                                                if isAIEvaluating {
                                                    ProgressView().controlSize(.small)
                                                    Text("Evaluating with AI...")
                                                } else {
                                                    Image(systemName: "sparkles")
                                                    Text(dialogueHistory.isEmpty ? "Evaluate with AI (⌘↵)" : "Reply to AI (⌘↵)")
                                                }
                                            }
                                            .font(.system(size: 12, weight: .semibold))
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .keyboardShortcut(.return, modifiers: [.command])
                                        .disabled(writtenAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAIEvaluating)

                                        Spacer()

                                        Button("Skip AI / Reveal Answer (Space)") {
                                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                                isAnswerRevealed = true
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .keyboardShortcut(.space, modifiers: [])
                                    }
                                }
                                .padding(.top, 4)
                            }

                            // Target Answer Section
                            if isAnswerRevealed {
                                Divider().padding(.vertical, 4)

                                if let eval = latestEvaluation, eval.isSpotOn {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 16))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Spot-On Understanding Verified!")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.green)
                                            Text(eval.feedback)
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if let suggested = eval.suggestedRating,
                                           let rEnum = FSRSRating(rawValue: suggested) {
                                            Text("AI Suggestion: \(rEnum.displayName)")
                                                .font(.system(size: 10, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(Color.green.opacity(0.15))
                                                .foregroundColor(.green)
                                                .cornerRadius(4)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color.green.opacity(0.08))
                                    .cornerRadius(8)
                                }

                                // Answer / Back
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("TARGET ANSWER")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.secondary)

                                    Text(card.back)
                                        .font(.system(size: 15))
                                        .foregroundColor(.primary)
                                }
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                        .padding(26)
                        .rotation3DEffect(.degrees(isAnswerRevealed ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                    }
                    .frame(maxWidth: 620, maxHeight: 520)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(14)
                    .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(latestEvaluation?.isSpotOn == true ? Color.green.opacity(0.5) : Color(NSColor.separatorColor), lineWidth: latestEvaluation?.isSpotOn == true ? 2 : 1)
                    )
                    .rotation3DEffect(
                        .degrees(isAnswerRevealed ? 180 : 0),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )

                    Spacer()

                    // Rating Controls
                    if !isAnswerRevealed {
                        if !isSocraticActiveForCurrentCard {
                            Button(action: {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    isAnswerRevealed = true
                                }
                            }) {
                                Text("Show Answer (Space)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(width: 240, height: 38)
                            }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.space, modifiers: [])
                        }
                    } else {
                        // 4 FSRS Rating Buttons
                        let intervals = FSRSScheduler.shared.previewIntervals(card: card)

                        HStack(spacing: 12) {
                            ForEach(FSRSRating.allCases, id: \.self) { rating in
                                Button(action: {
                                    handleRating(rating)
                                }) {
                                    VStack(spacing: 4) {
                                        HStack(spacing: 4) {
                                            Text("\(rating.rawValue)")
                                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(buttonColor(for: rating).opacity(0.18))
                                                .foregroundColor(buttonColor(for: rating))
                                                .cornerRadius(3)

                                            Text(rating.displayName)
                                                .font(.system(size: 13, weight: .bold))

                                            if latestEvaluation?.suggestedRating == rating.rawValue {
                                                Image(systemName: "sparkles")
                                                    .font(.system(size: 9))
                                                    .foregroundColor(.green)
                                            }
                                        }

                                        if let days = intervals[rating] {
                                            Text(days == 1 ? "1 day" : "\(days) days")
                                                .font(.system(size: 10, weight: .semibold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(buttonColor(for: rating).opacity(0.12))
                                                .foregroundColor(buttonColor(for: rating))
                                                .cornerRadius(4)
                                        }
                                    }
                                    .frame(minWidth: 92, minHeight: 46)
                                }
                                .buttonStyle(.bordered)
                                .tint(buttonColor(for: rating))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(latestEvaluation?.suggestedRating == rating.rawValue ? Color.green : Color.clear, lineWidth: 2)
                                )
                                .keyboardShortcut(KeyEquivalent(Character("\(rating.rawValue)")), modifiers: [])
                            }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $isAISettingsSheetPresented) {
            AISettingsSheet(onDismiss: { isAISettingsSheetPresented = false })
        }
        .onAppear {
            let deckId = deck?.id
            let due = store.dueFlashcards(forDeck: deckId)
            let all = store.flashcards(forDeck: deckId)
            sessionCards = due.isEmpty ? all : due
            currentIndex = 0
            isAnswerRevealed = false
            writtenAnswer = ""
            dialogueHistory = []
            isAIEvaluating = false
            evaluationError = nil
            latestEvaluation = nil
            isAISocraticActive = aiSettings.isSocraticEnabled
            if isSocraticActiveForCurrentCard && !isAnswerRevealed {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isWrittenInputFocused = true
                }
            }
        }
    }

    private func submitWrittenAnswer() {
        guard let card = currentCard else { return }
        let trimmed = writtenAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isAIEvaluating = true
        evaluationError = nil

        Task {
            do {
                let eval = try await AISocraticService.shared.evaluateAnswer(
                    question: card.front,
                    targetAnswer: card.back,
                    hint: card.hint,
                    userAnswer: trimmed,
                    dialogueHistory: dialogueHistory
                )

                await MainActor.run {
                    isAIEvaluating = false
                    latestEvaluation = eval

                    let turn = AISocraticTurn(
                        roundNumber: dialogueHistory.count + 1,
                        userAnswer: trimmed,
                        feedback: eval.feedback,
                        counterQuestion: eval.counterQuestion,
                        isSpotOn: eval.isSpotOn
                    )
                    dialogueHistory.append(turn)
                    writtenAnswer = ""

                    if eval.isSpotOn {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            isAnswerRevealed = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isAIEvaluating = false
                    evaluationError = error.localizedDescription
                }
            }
        }
    }

    private func handleRating(_ rating: FSRSRating) {
        guard let card = currentCard else { return }
        _ = store.rateFlashcard(id: card.id, rating: rating)

        if currentIndex + 1 < sessionCards.count {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                currentIndex += 1
                isAnswerRevealed = false
                writtenAnswer = ""
                dialogueHistory = []
                isAIEvaluating = false
                evaluationError = nil
                latestEvaluation = nil
            }
            if isSocraticActiveForCurrentCard {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isWrittenInputFocused = true
                }
            }
        } else {
            onDismiss()
        }
    }

    private func buttonColor(for rating: FSRSRating) -> Color {
        switch rating {
        case .again: return .red
        case .hard: return .orange
        case .good: return .blue
        case .easy: return .green
        }
    }
}
