import SwiftUI
import AppKit

// MARK: - Color Hex Extension
fileprivate extension Color {
    init(hexString: String) {
        let clean = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch clean.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 59, 130, 246)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

public struct FlashcardManagerView: View {
    @ObservedObject public var store: BlockStore
    @State private var isStudyModeActive: Bool = false
    @State private var isAddCardSheetPresented: Bool = false
    @State private var isCreateDeckSheetPresented: Bool = false
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
    public var deck: Deck? = nil
    public let onDismiss: () -> Void

    @State private var currentIndex: Int = 0
    @State private var isAnswerRevealed: Bool = false
    @State private var sessionCards: [Flashcard] = []

    public init(store: BlockStore, deck: Deck? = nil, onDismiss: @escaping () -> Void) {
        self.store = store
        self.deck = deck
        self.onDismiss = onDismiss
    }

    private var currentCard: Flashcard? {
        guard currentIndex >= 0 && currentIndex < sessionCards.count else { return nil }
        return sessionCards[currentIndex]
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

                Button("Finish") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor))

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
                VStack(spacing: 24) {
                    Spacer()

                    VStack(alignment: .leading, spacing: 16) {
                        // Card Category / Folder
                        if let doc = store.documents.first(where: { $0.id == card.docId }) {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 10))
                                Text(doc.content.isEmpty ? "Folder" : doc.content)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.accentColor)
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

                        if isAnswerRevealed {
                            Divider()
                                .padding(.vertical, 8)

                            // Answer / Back
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ANSWER")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)

                                Text(card.back)
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(28)
                    .frame(maxWidth: 580)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(14)
                    .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )

                    Spacer()

                    // Rating Controls
                    if !isAnswerRevealed {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isAnswerRevealed = true
                            }
                        }) {
                            Text("Show Answer (Space)")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 240, height: 38)
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.space, modifiers: [])
                    } else {
                        // 4 FSRS Rating Buttons
                        let intervals = FSRSScheduler.shared.previewIntervals(card: card)

                        HStack(spacing: 12) {
                            ForEach(FSRSRating.allCases, id: \.self) { rating in
                                Button(action: {
                                    handleRating(rating)
                                }) {
                                    VStack(spacing: 2) {
                                        Text(rating.displayName)
                                            .font(.system(size: 12, weight: .bold))
                                        if let days = intervals[rating] {
                                            Text(days == 1 ? "1 day" : "\(days) days")
                                                .font(.system(size: 10))
                                                .opacity(0.8)
                                        }
                                    }
                                    .frame(minWidth: 80, minHeight: 42)
                                }
                                .buttonStyle(.bordered)
                                .tint(buttonColor(for: rating))
                                .keyboardShortcut(KeyEquivalent(Character("\(rating.rawValue)")), modifiers: [])
                            }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            let deckId = deck?.id
            let due = store.dueFlashcards(forDeck: deckId)
            let all = store.flashcards(forDeck: deckId)
            sessionCards = due.isEmpty ? all : due
            currentIndex = 0
            isAnswerRevealed = false
        }
    }

    private func handleRating(_ rating: FSRSRating) {
        guard let card = currentCard else { return }
        _ = store.rateFlashcard(id: card.id, rating: rating)

        if currentIndex + 1 < sessionCards.count {
            withAnimation(.easeInOut(duration: 0.15)) {
                currentIndex += 1
                isAnswerRevealed = false
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
