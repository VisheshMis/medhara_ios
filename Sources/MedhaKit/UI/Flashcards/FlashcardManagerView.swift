import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct FlashcardManagerView: View {
    @ObservedObject public var store: BlockStore
    @ObservedObject private var dailyTracker: DailyStudyTracker = DailyStudyTracker.shared
    @ObservedObject private var optionsManager: DeckOptionsManager = DeckOptionsManager.shared

    // Navigation View Mode (Decks vs Browse)
    @State private var viewMode: FlashcardsViewMode = .decks
    @State private var browseInitialDeckId: String? = nil

    // Study Session State
    @State private var isStudyModeActive: Bool = false
    @State private var studyTargetDeck: Deck? = nil

    // Sheets & Modals
    @State private var isAddCardSheetPresented: Bool = false
    @State private var isImageOcclusionSheetPresented: Bool = false
    @State private var isCreateDeckSheetPresented: Bool = false
    @State private var isEditDeckSheetPresented: Bool = false
    @State private var editingDeck: Deck? = nil
    @State private var isDeckOptionsSheetPresented: Bool = false
    @State private var deckOptionsTarget: Deck? = nil
    @State private var isAISettingsSheetPresented: Bool = false

    // Anki Import State
    @State private var isImportingAnki: Bool = false
    @State private var importAlertTitle: String = ""
    @State private var importAlertMessage: String = ""
    @State private var isImportAlertPresented: Bool = false

    // Decks View State
    @State private var isNotesDeckExpanded: Bool = true
    @State private var deckToDelete: Deck? = nil
    @State private var isDeleteDeckAlertPresented: Bool = false

    public enum FlashcardsViewMode: String, CaseIterable, Identifiable {
        case decks = "Decks"
        case browse = "Browse"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .decks: return "rectangle.stack.fill"
            case .browse: return "tablecells"
            }
        }
    }

    public init(store: BlockStore) {
        self.store = store
    }

    // MARK: - Computed Counts for Overview (respecting daily limits)
    private var totalCardsCount: Int {
        store.flashcards.count
    }

    private var cardsGroupedByDeck: [String: [Flashcard]] {
        var dict: [String: [Flashcard]] = [:]
        let notesDeckId = store.defaultNotesDeck?.id ?? Deck.notesDefaultId
        for card in store.flashcards {
            if let deckId = card.deckId {
                dict[deckId, default: []].append(card)
            } else if !card.docId.isEmpty {
                dict[notesDeckId, default: []].append(card)
            }
        }
        return dict
    }

    private var deckStatistics: (newTotal: Int, learnTotal: Int, dueTotal: Int) {
        let grouped = cardsGroupedByDeck
        let notesDeck = store.defaultNotesDeck
        let notesDeckId = notesDeck?.id ?? Deck.notesDefaultId
        let notesCards = grouped[notesDeckId] ?? []
        let notesOpts = optionsManager.options(forDeck: notesDeck)

        var totalNew = dailyTracker.effectiveNewCards(from: notesCards, deckId: notesDeckId, options: notesOpts).count
        var totalDue = dailyTracker.effectiveReviewCards(from: notesCards, deckId: notesDeckId, options: notesOpts).count
        var totalLearn = 0

        for card in store.flashcards where !card.isEffectivelySuspended {
            if card.fsrsState == .learning || card.fsrsState == .relearning {
                totalLearn += 1
            }
        }

        for deck in store.decks {
            let cards = grouped[deck.id] ?? []
            let opts = optionsManager.options(forDeck: deck)
            totalNew += dailyTracker.effectiveNewCards(from: cards, deckId: deck.id, options: opts).count
            totalDue += dailyTracker.effectiveReviewCards(from: cards, deckId: deck.id, options: opts).count
        }

        return (totalNew, totalLearn, totalDue)
    }

    private var totalDueCount: Int {
        deckStatistics.dueTotal
    }

    private var totalNewCount: Int {
        deckStatistics.newTotal
    }

    private var totalLearningCount: Int {
        deckStatistics.learnTotal
    }

    private var totalSessionCardsCount: Int {
        totalNewCount + totalLearningCount + totalDueCount
    }

    public var body: some View {
        Group {
            if isStudyModeActive {
                FlashcardStudySessionView(
                    store: store,
                    deck: studyTargetDeck,
                    onDismiss: { isStudyModeActive = false }
                )
            } else {
                VStack(spacing: 0) {
                    // Top Hub Header
                    topHubNavigationBar

                    Divider()

                    // Main View Content
                    switch viewMode {
                    case .decks:
                        centeredDecksHomeView
                    case .browse:
                        CardBrowserView(
                            store: store,
                            initialDeckId: browseInitialDeckId,
                            onReturnToDecks: { viewMode = .decks }
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $isAddCardSheetPresented) {
            AddFlashcardSheet(
                store: store,
                isPresented: $isAddCardSheetPresented,
                onOpenImageOcclusion: {
                    isAddCardSheetPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isImageOcclusionSheetPresented = true
                    }
                },
                preselectedDeckId: store.selectedDeckId
            )
        }
        .sheet(isPresented: $isImageOcclusionSheetPresented) {
            ImageOcclusionEditorSheet(
                store: store,
                isPresented: $isImageOcclusionSheetPresented,
                preselectedDeckId: store.selectedDeckId
            )
        }
        .sheet(isPresented: $isCreateDeckSheetPresented) {
            CreateDeckSheet(
                store: store,
                isPresented: $isCreateDeckSheetPresented
            )
        }
        .sheet(isPresented: $isEditDeckSheetPresented) {
            if let deck = editingDeck {
                EditDeckSheet(
                    store: store,
                    deck: deck,
                    isPresented: $isEditDeckSheetPresented
                )
            }
        }
        .sheet(isPresented: $isDeckOptionsSheetPresented) {
            DeckOptionsSheet(
                store: store,
                deck: deckOptionsTarget,
                onDismiss: { isDeckOptionsSheetPresented = false }
            )
        }
        .sheet(isPresented: $isAISettingsSheetPresented) {
            AISettingsSheet(onDismiss: { isAISettingsSheetPresented = false })
        }
        .alert("Delete Deck", isPresented: $isDeleteDeckAlertPresented, presenting: deckToDelete) { deck in
            Button("Delete Deck", role: .destructive) {
                store.deleteDeck(id: deck.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: { deck in
            Text("Are you sure you want to delete '\(deck.name)'? Flashcards will automatically be moved to 'Notes & Documents' so no cards are lost.")
        }
        .alert(importAlertTitle, isPresented: $isImportAlertPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importAlertMessage)
        }
        .overlay {
            if isImportingAnki {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView()
                            .scaleEffect(1.3)
                        Text("Importing Anki Deck...")
                            .font(.system(size: 14, weight: .bold))
                        Text("Parsing collection (modern .anki21 / legacy .anki2) & FSRS scheduling...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(26)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                    .shadow(radius: 14)
                }
            }
        }
    }

    // MARK: - Top Hub Navigation Bar
    private var topHubNavigationBar: some View {
        HStack(spacing: 12) {
            // Mode Switcher: Decks vs Browse
            Picker("", selection: $viewMode) {
                ForEach(FlashcardsViewMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 210)

            Spacer()

            // Study All Due Button (Hero Action)
            if totalSessionCardsCount > 0 {
                Button(action: {
                    studyTargetDeck = nil
                    isStudyModeActive = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Study All Due (\(totalSessionCardsCount))")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [MedhaTheme.Colors.cardDue, MedhaTheme.Colors.accentEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule(style: .continuous))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: MedhaTheme.Colors.cardDue.opacity(0.3), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }

            // Add Card
            Button(action: { isAddCardSheetPresented = true }) {
                Label("Add Card", systemImage: "plus")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            // Unified New Deck Menu (Create New Deck or Import Anki .apkg)
            Menu {
                Button(action: { isCreateDeckSheetPresented = true }) {
                    Label("Create New Deck...", systemImage: "folder.badge.plus")
                }

                Divider()

                Button(action: { openAnkiFilePicker() }) {
                    Label("Import Anki Deck (.apkg)...", systemImage: "square.and.arrow.down")
                }
            } label: {
                Label("New Deck", systemImage: "folder.badge.plus")
                    .font(.system(size: 12, weight: .medium))
            }
            .menuStyle(.borderedButton)
            .controlSize(.regular)
            .help("Create a new custom deck or import an Anki collection (.apkg)")

            // Socratic AI Settings
            Button(action: { isAISettingsSheetPresented = true }) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13))
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .help("Configure Socratic AI Recall Assistant & API key")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(MedhaTheme.Colors.bgSurface)
    }

    // MARK: - Centered Decks Home View
    private var centeredDecksHomeView: some View {
        ScrollView {
            HStack {
                Spacer()
                VStack(spacing: 24) {
                    // Header / Stats Banner
                    heroStatsBanner

                    // Main Deck Table Card
                    decksTableCard

                    // Bottom Quick Tip / Socratic notice
                    bottomInfoBar
                }
                .frame(maxWidth: 820)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
        .background(MedhaTheme.Colors.bgBase)
    }

    // MARK: - Hero Stats Banner
    private var heroStatsBanner: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(MedhaTheme.Colors.flashcardsAccent)
                        .font(.system(size: 20, weight: .bold))
                    Text("Spaced Repetition Hub")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(MedhaTheme.Colors.textPrimary)
                }

                Text(totalDueCount > 0 ? "You have \(totalDueCount) flashcard\(totalDueCount == 1 ? "" : "s") ready for optimal FSRS memory consolidation today." : "All caught up! No flashcards currently due for spaced review.")
                    .font(.system(size: 12.5))
                    .foregroundColor(MedhaTheme.Colors.textSecondary)
            }

            Spacer()

            // 3 Stat Tiles (Anki-style: New, Learn, Due)
            HStack(spacing: 12) {
                statPill(label: "New", count: totalNewCount, color: MedhaTheme.Colors.cardNew)
                statPill(label: "Learn", count: totalLearningCount, color: MedhaTheme.Colors.cardLearn)
                statPill(label: "Due", count: totalDueCount, color: MedhaTheme.Colors.cardDue)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: MedhaTheme.Radius.card, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [MedhaTheme.Colors.bgElevated, MedhaTheme.Colors.bgSurface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: MedhaTheme.Radius.card, style: .continuous)
                .stroke(MedhaTheme.Colors.borderHairline, lineWidth: 1)
        )
        .shadow(color: MedhaTheme.Shadows.softLow, radius: 8, x: 0, y: 2)
    }

    private func statPill(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 3) {
            Text("\(count)")
                .font(MedhaTheme.Typography.roundedStatsMedium)
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(MedhaTheme.Colors.textTertiary)
        }
        .frame(minWidth: 58)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: MedhaTheme.Radius.row, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MedhaTheme.Radius.row, style: .continuous)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Main Decks Table Card
    private var decksTableCard: some View {
        let grouped = cardsGroupedByDeck
        let notesDeck = store.defaultNotesDeck
        let notesDeckId = notesDeck?.id ?? Deck.notesDefaultId

        return VStack(spacing: 0) {
            // Table Column Headers
            HStack(spacing: 12) {
                Text("DECK")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(MedhaTheme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("NEW")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(MedhaTheme.Colors.cardNew)
                    .frame(width: 55, alignment: .trailing)

                Text("LEARN")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(MedhaTheme.Colors.cardLearn)
                    .frame(width: 55, alignment: .trailing)

                Text("DUE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(MedhaTheme.Colors.cardDue)
                    .frame(width: 55, alignment: .trailing)

                Image(systemName: "gearshape")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(MedhaTheme.Colors.textTertiary)
                    .frame(width: 36, alignment: .center)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(MedhaTheme.Colors.bgElevated.opacity(0.6))

            Divider()
                .opacity(0.4)

            // 1. Notes & Documents Auto-Grouped Deck Row
            notesDeckRow(notesCards: grouped[notesDeckId] ?? [])

            // 2. Custom Decks
            let customDecks = store.decks.filter { !$0.isNotesDefault }
            ForEach(customDecks) { deck in
                Divider().padding(.horizontal, 14)
                customDeckRow(deck, cards: grouped[deck.id] ?? [])
            }

            if customDecks.isEmpty {
                Divider().padding(.horizontal, 14)
                emptyCustomDecksBanner
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }

    // MARK: - Notes & Documents Deck Row
    private func notesDeckRow(notesCards: [Flashcard]) -> some View {
        let notesDeck = store.defaultNotesDeck
        let notesDeckId = notesDeck?.id ?? Deck.notesDefaultId
        let options = optionsManager.options(forDeck: notesDeck)
        let effectiveNew = dailyTracker.effectiveNewCards(from: notesCards, deckId: notesDeckId, options: options)
        let newCount = effectiveNew.count
        let learnCount = notesCards.filter { ($0.fsrsState == .learning || $0.fsrsState == .relearning) && !$0.isEffectivelySuspended }.count
        let dueCount = dailyTracker.effectiveReviewCards(from: notesCards, deckId: notesDeckId, options: options).count
        let noteGroups = store.noteGroupedFlashcards()

        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Expand / Collapse Chevron Button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isNotesDeckExpanded.toggle()
                    }
                }) {
                    Image(systemName: isNotesDeckExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)

                // Clickable Deck Header to Study
                Button(action: {
                    if !notesCards.isEmpty {
                        studyTargetDeck = store.defaultNotesDeck
                        isStudyModeActive = true
                    }
                }) {
                    HStack(spacing: 10) {
                        // Deck Icon Avatar
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.16))
                                .frame(width: 32, height: 32)
                            Image(systemName: "note.text")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.blue)
                        }

                        // Deck Title & Subtitle
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Notes & Documents")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.primary)
                                Text("AUTO-GROUPED")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Color.blue.opacity(0.12))
                                    .cornerRadius(4)
                            }

                            Text("Auto-generated from notes hierarchy (\(notesCards.count) cards)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // New Count
                Text("\(newCount)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(newCount > 0 ? .blue : .secondary.opacity(0.5))
                    .frame(width: 55, alignment: .trailing)

                // Learn Count
                Text("\(learnCount)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(learnCount > 0 ? .orange : .secondary.opacity(0.5))
                    .frame(width: 55, alignment: .trailing)

                // Due Count
                Text("\(dueCount)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(dueCount > 0 ? .green : .secondary.opacity(0.5))
                    .frame(width: 55, alignment: .trailing)

                // Options Gear Menu (Only Setting Logo, no caret)
                Menu {
                    Button(action: {
                        studyTargetDeck = store.defaultNotesDeck
                        isStudyModeActive = true
                    }) {
                        Label("Study Notes Deck", systemImage: "play.circle")
                    }
                    .disabled(notesCards.isEmpty)

                    Button(action: {
                        browseInitialDeckId = notesDeckId
                        viewMode = .browse
                    }) {
                        Label("Browse Cards in Deck", systemImage: "magnifyingglass")
                    }

                    Divider()

                    Button(action: {
                        deckOptionsTarget = store.defaultNotesDeck
                        isDeckOptionsSheetPresented = true
                    }) {
                        Label("Deck Options...", systemImage: "gearshape")
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 36, alignment: .center)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.clear)

            // Expandable Nested Note Documents
            if isNotesDeckExpanded && !noteGroups.isEmpty {
                VStack(spacing: 0) {
                    ForEach(noteGroups) { group in
                        let docNew = group.cards.filter { $0.fsrsState == .newCard && !$0.isEffectivelySuspended }.count
                        let docLearn = group.cards.filter { ($0.fsrsState == .learning || $0.fsrsState == .relearning) && !$0.isEffectivelySuspended }.count
                        let docDue = group.cards.filter { $0.isDue }.count

                        HStack(spacing: 10) {
                            // Indent indicator
                            Image(systemName: "arrow.turn.down.right")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.5))
                                .padding(.leading, 24)

                            Image(systemName: "doc.text")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            Text(group.doc.content.isEmpty ? "Untitled Note" : group.doc.content)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)

                            Spacer()

                            Text("\(docNew)")
                                .font(.system(size: 11))
                                .foregroundColor(docNew > 0 ? .blue : .secondary.opacity(0.4))
                                .frame(width: 55, alignment: .trailing)

                            Text("\(docLearn)")
                                .font(.system(size: 11))
                                .foregroundColor(docLearn > 0 ? .orange : .secondary.opacity(0.4))
                                .frame(width: 55, alignment: .trailing)

                            Text("\(docDue)")
                                .font(.system(size: 11))
                                .foregroundColor(docDue > 0 ? .green : .secondary.opacity(0.4))
                                .frame(width: 55, alignment: .trailing)

                            Button(action: {
                                store.activeMainView = .editor
                                store.selectDocument(id: group.doc.id)
                            }) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Open note in editor")
                            .frame(width: 36, alignment: .center)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
                    }
                }
            }
        }
    }

    // MARK: - Custom Deck Row
    private func customDeckRow(_ deck: Deck, cards: [Flashcard]) -> some View {
        let options = optionsManager.options(forDeck: deck)
        let effectiveNew = dailyTracker.effectiveNewCards(from: cards, deckId: deck.id, options: options)
        let newCount = effectiveNew.count
        let learnCount = cards.filter { ($0.fsrsState == .learning || $0.fsrsState == .relearning) && !$0.isEffectivelySuspended }.count
        let dueCount = dailyTracker.effectiveReviewCards(from: cards, deckId: deck.id, options: options).count

        return HStack(spacing: 12) {
            // Clickable Deck Header to Study
            Button(action: {
                if !cards.isEmpty {
                    studyTargetDeck = deck
                    isStudyModeActive = true
                }
            }) {
                HStack(spacing: 10) {
                    // Deck Color & Icon Avatar
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hexString: deck.colorHex).opacity(0.18))
                            .frame(width: 32, height: 32)
                        Image(systemName: deck.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hexString: deck.colorHex))
                    }
                    .padding(.leading, 24)

                    // Deck Name & Description
                    VStack(alignment: .leading, spacing: 2) {
                        Text(deck.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        Text(deck.description ?? "\(cards.count) flashcards")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // New Count
            Text("\(newCount)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(newCount > 0 ? .blue : .secondary.opacity(0.5))
                .frame(width: 55, alignment: .trailing)

            // Learn Count
            Text("\(learnCount)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(learnCount > 0 ? .orange : .secondary.opacity(0.5))
                .frame(width: 55, alignment: .trailing)

            // Due Count
            Text("\(dueCount)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(dueCount > 0 ? .green : .secondary.opacity(0.5))
                .frame(width: 55, alignment: .trailing)

            // Gear Options Menu (Only Setting Logo, no caret)
            Menu {
                Button(action: {
                    studyTargetDeck = deck
                    isStudyModeActive = true
                }) {
                    Label("Study Deck", systemImage: "play.circle")
                }
                .disabled(cards.isEmpty)

                Button(action: {
                    browseInitialDeckId = deck.id
                    viewMode = .browse
                }) {
                    Label("Browse Cards in Deck", systemImage: "magnifyingglass")
                }

                Divider()

                Button(action: {
                    deckOptionsTarget = deck
                    isDeckOptionsSheetPresented = true
                }) {
                    Label("Deck Options...", systemImage: "gearshape")
                }

                Button(action: {
                    editingDeck = deck
                    isEditDeckSheetPresented = true
                }) {
                    Label("Edit Deck...", systemImage: "pencil")
                }

                Divider()

                Button(role: .destructive, action: {
                    deckToDelete = deck
                    isDeleteDeckAlertPresented = true
                }) {
                    Label("Delete Deck", systemImage: "trash")
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 36, alignment: .center)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.clear)
    }

    private var emptyCustomDecksBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.rectangle.on.rectangle")
                .foregroundColor(.secondary)
                .font(.system(size: 16))
            Text("No custom decks yet. Create targeted decks or import your Anki (.apkg) collections.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            HStack(spacing: 8) {
                Button("Import Anki (.apkg)") {
                    openAnkiFilePicker()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("+ New Deck") {
                    isCreateDeckSheetPresented = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }

    private var bottomInfoBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundColor(.accentColor)
                .font(.system(size: 13))
            Text("Tip: Click **Browse** in the top navigation to search, filter, and inspect cards with full FSRS stability parameters.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Button("Open Browser") {
                viewMode = .browse
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.accentColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        .cornerRadius(8)
    }

    // MARK: - Anki Import Actions
    private func openAnkiFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            UTType(filenameExtension: "apkg") ?? .data,
            UTType(filenameExtension: "anki21b") ?? .data,
            UTType(filenameExtension: "anki21") ?? .data,
            UTType(filenameExtension: "anki2") ?? .data,
            UTType(filenameExtension: "zip") ?? .zip
        ]
        panel.title = "Import Anki Deck (.apkg)"
        panel.prompt = "Import Deck"

        if panel.runModal() == .OK, let url = panel.url {
            performAnkiImport(from: url)
        }
    }

    private func performAnkiImport(from url: URL) {
        isImportingAnki = true
        Task {
            do {
                let result = try await AnkiImporter.shared.importDeck(from: url, into: store)
                await MainActor.run {
                    isImportingAnki = false
                    importAlertTitle = "Import Successful! 🎉"
                    importAlertMessage = "Imported \(result.importedCardCount) flashcard(s) into: \(result.deckNames.joined(separator: ", "))."
                    isImportAlertPresented = true
                }
            } catch {
                await MainActor.run {
                    isImportingAnki = false
                    importAlertTitle = "Import Failed"
                    importAlertMessage = error.localizedDescription
                    isImportAlertPresented = true
                }
            }
        }
    }
}

// MARK: - Edit Deck Sheet
public struct EditDeckSheet: View {
    @ObservedObject public var store: BlockStore
    public var deck: Deck
    @Binding public var isPresented: Bool

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var selectedColorHex: String = "#3B82F6"
    @State private var selectedIcon: String = "rectangle.stack"

    private let availableColors: [(String, String)] = [
        ("#3B82F6", "Blue"),
        ("#10B981", "Emerald"),
        ("#8B5CF6", "Purple"),
        ("#F59E0B", "Amber"),
        ("#EF4444", "Rose"),
        ("#06B6D4", "Cyan"),
        ("#EC4899", "Pink"),
        ("#64748B", "Slate")
    ]

    private let availableIcons: [String] = [
        "rectangle.stack",
        "brain.head.profile",
        "book.closed",
        "cross.case",
        "stethoscope",
        "atom",
        "function",
        "globe",
        "terminal",
        "chart.bar"
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .foregroundColor(.accentColor)
                    Text("Edit Deck")
                        .font(.system(size: 15, weight: .bold))
                }
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Deck Name")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("Deck Name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Description (Optional)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("Description", text: $description)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Theme Color")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    ForEach(availableColors, id: \.0) { hex, _ in
                        Circle()
                            .fill(Color(hexString: hex))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: selectedColorHex == hex ? 2.5 : 0)
                            )
                            .onTapGesture { selectedColorHex = hex }
                    }
                }
            }

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
                        .onTapGesture { selectedIcon = icon }
                    }
                }
            }

            Divider()

            HStack {
                Button("Cancel") { isPresented = false }
                Spacer()
                Button("Save Changes") {
                    var updated = deck
                    updated.name = name
                    updated.description = description.isEmpty ? nil : description
                    updated.colorHex = selectedColorHex
                    updated.icon = selectedIcon
                    updated.updatedAt = Date()
                    store.updateDeck(updated)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
        .onAppear {
            name = deck.name
            description = deck.description ?? ""
            selectedColorHex = deck.colorHex
            selectedIcon = deck.icon
        }
    }
}

// MARK: - Create Deck Modal Sheet
public struct CreateDeckSheet: View {
    @ObservedObject public var store: BlockStore
    @Binding public var isPresented: Bool

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var selectedColorHex: String = "#3B82F6"
    @State private var selectedIcon: String = "rectangle.stack"

    private let availableColors: [(String, String)] = [
        ("#3B82F6", "Blue"),
        ("#10B981", "Emerald"),
        ("#8B5CF6", "Purple"),
        ("#F59E0B", "Amber"),
        ("#EF4444", "Rose"),
        ("#06B6D4", "Cyan"),
        ("#EC4899", "Pink"),
        ("#64748B", "Slate")
    ]

    private let availableIcons: [String] = [
        "rectangle.stack",
        "brain.head.profile",
        "book.closed",
        "cross.case",
        "stethoscope",
        "atom",
        "function",
        "globe",
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

            VStack(alignment: .leading, spacing: 4) {
                Text("Deck Name")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("e.g. Cognitive Psychology, Algorithms, Anatomy", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Description (Optional)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("e.g. High-yield definitions and algorithmic invariants", text: $description)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Theme Color")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    ForEach(availableColors, id: \.0) { hex, _ in
                        Circle()
                            .fill(Color(hexString: hex))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: selectedColorHex == hex ? 2.5 : 0)
                            )
                            .onTapGesture { selectedColorHex = hex }
                    }
                }
            }

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
                        .onTapGesture { selectedIcon = icon }
                    }
                }
            }

            Divider()

            HStack {
                Button("Cancel") { isPresented = false }
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
    public var onOpenImageOcclusion: (() -> Void)? = nil
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

            // Mode Selector: Standard vs Image Occlusion
            HStack(spacing: 8) {
                Button(action: {}) {
                    Label("Standard (Q & A)", systemImage: "text.bubble")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(MedhaTheme.Colors.accent.opacity(0.15))
                        .foregroundColor(MedhaTheme.Colors.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: {
                    if let onOpen = onOpenImageOcclusion {
                        onOpen()
                    } else {
                        isPresented = false
                    }
                }) {
                    Label("Image Occlusion (STEM & Anatomy)", systemImage: "photo.badge.plus")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(MedhaTheme.Colors.bgElevated)
                        .foregroundColor(MedhaTheme.Colors.textSecondary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 2)

            // Target Deck Selector
            VStack(alignment: .leading, spacing: 4) {
                Text("Target Deck")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                Picker("", selection: $targetDeckId) {
                    let notesId = store.defaultNotesDeck?.id ?? Deck.notesDefaultId
                    Text("📁 Notes & Documents (Auto-grouped)").tag(notesId)

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
                Button("Cancel") { isPresented = false }
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

// MARK: - Flashcard Row View (Legacy compatibility)
public struct FlashcardRowView: View {
    @ObservedObject public var store: BlockStore
    public let card: Flashcard
    public var showFolderBadge: Bool = true

    public var body: some View {
        HStack {
            Text(card.front)
                .font(.system(size: 12))
            Spacer()
        }
        .padding(8)
    }
}

// MARK: - Study Session View
public struct FlashcardStudySessionView: View {
    @ObservedObject public var store: BlockStore
    @ObservedObject public var aiSettings: AISettings = AISettings.shared
    @ObservedObject public var dailyTracker: DailyStudyTracker = DailyStudyTracker.shared
    @ObservedObject public var optionsManager: DeckOptionsManager = DeckOptionsManager.shared
    public var deck: Deck? = nil
    public let onDismiss: () -> Void

    @State private var currentIndex: Int = 0
    @State private var isAnswerRevealed: Bool = false
    @State private var sessionCards: [Flashcard] = []
    @State private var isDeckOptionsSheetPresented: Bool = false

    // AI Socratic State
    @State private var isAISocraticActive: Bool = true
    @State private var isAISettingsSheetPresented: Bool = false
    @State private var writtenAnswer: String = ""
    @State private var dialogueHistory: [AISocraticTurn] = []
    @State private var isAIEvaluating: Bool = false
    @State private var evaluationError: String? = nil
    @State private var latestEvaluation: AISocraticEvaluation? = nil
    @FocusState private var isWrittenInputFocused: Bool
    @State private var keyMonitor: Any? = nil

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
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: deck?.icon ?? "rectangle.stack.fill")
                        .foregroundColor(Color(hexString: deck?.colorHex ?? "#3B82F6"))
                    Text(deck?.name ?? "All Due Cards")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(MedhaTheme.Colors.textPrimary)
                }

                Spacer()

                if !sessionCards.isEmpty {
                    Text("\(currentIndex + 1) of \(sessionCards.count)")
                        .font(MedhaTheme.Typography.roundedBadge)
                        .foregroundColor(MedhaTheme.Colors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(MedhaTheme.Colors.bgSurface)
                        .clipShape(Capsule(style: .continuous))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(MedhaTheme.Colors.borderHairline, lineWidth: 1)
                        )
                }

                Button(action: { isAISettingsSheetPresented = true }) {
                    Image(systemName: "sparkles")
                        .foregroundColor(aiSettings.hasAPIKey ? MedhaTheme.Colors.aiAccent : MedhaTheme.Colors.textTertiary)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("AI Socratic Settings")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(MedhaTheme.Colors.bgSurface)

            // Thin Session Progress Bar
            if !sessionCards.isEmpty {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(MedhaTheme.Colors.borderHairline)
                            .frame(height: 2.5)

                        Rectangle()
                            .fill(MedhaTheme.Colors.brandGradient)
                            .frame(width: geo.size.width * CGFloat(currentIndex + 1) / CGFloat(max(1, sessionCards.count)), height: 2.5)
                            .animation(.easeOut(duration: 0.2), value: currentIndex)
                    }
                }
                .frame(height: 2.5)
            } else {
                Divider()
                    .opacity(0.4)
            }

            if sessionCards.isEmpty {
                emptyOrLimitReachedView
            } else if let card = currentCard {
                ScrollView {
                    VStack(spacing: 20) {
                        // Flashcard Face
                        VStack(spacing: 16) {
                            // Card State Header
                            HStack {
                                Text(card.fsrsState.displayName.uppercased())
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                    .foregroundColor(MedhaTheme.Colors.textTertiary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(MedhaTheme.Colors.bgElevated)
                                    .clipShape(Capsule(style: .continuous))
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(MedhaTheme.Colors.borderHairline, lineWidth: 1)
                                    )

                                Spacer()

                                if let hint = card.hint, !hint.isEmpty {
                                    Text("Hint: \(hint)")
                                        .font(.system(size: 11, design: .serif))
                                        .foregroundColor(MedhaTheme.Colors.textSecondary)
                                }
                            }

                            // Question / Front Face
                            if card.effectiveCardType == .imageOcclusion,
                               let imgPath = card.imagePath,
                               let image = OcclusionAssetStorage.loadImage(for: imgPath) {
                                // Image Occlusion Interactive Diagram
                                VStack(spacing: 12) {
                                    Text(card.front)
                                        .font(MedhaTheme.Typography.headline)
                                        .foregroundColor(MedhaTheme.Colors.textPrimary)

                                    ImageOcclusionCanvasView(
                                        image: image,
                                        masks: card.parsedMasks,
                                        activeMaskId: card.activeMaskId,
                                        mode: card.effectiveOcclusionMode,
                                        isAnswerRevealed: isAnswerRevealed,
                                        isEditable: false
                                    )
                                    .frame(height: 380)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(MedhaTheme.Colors.borderHairline, lineWidth: 1)
                                    )

                                    if !isAnswerRevealed {
                                        Text("Recall the label under the highlighted region")
                                            .font(MedhaTheme.Typography.caption)
                                            .foregroundColor(MedhaTheme.Colors.textSecondary)
                                    }
                                }
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                            } else {
                                // Standard Text Question / Front (New York Serif, generous sizing)
                                Text(card.front)
                                    .font(MedhaTheme.Typography.serifCardQuestion)
                                    .foregroundColor(MedhaTheme.Colors.textPrimary)
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, 28)
                                    .frame(maxWidth: .infinity)
                            }

                            // Revealed Answer or Socratic Area
                            if isAnswerRevealed {
                                Divider()
                                    .opacity(0.4)

                                VStack(spacing: 8) {
                                    Text("ANSWER")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(MedhaTheme.Colors.textTertiary)

                                    Text(card.back)
                                        .font(MedhaTheme.Typography.serifCardAnswer)
                                        .foregroundColor(MedhaTheme.Colors.textPrimary)
                                        .multilineTextAlignment(.center)
                                        .padding(.vertical, 12)
                                }
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                        .padding(28)
                        .background(MedhaTheme.Colors.bgSurface)
                        .clipShape(RoundedRectangle(cornerRadius: MedhaTheme.Radius.card, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: MedhaTheme.Radius.card, style: .continuous)
                                .stroke(MedhaTheme.Colors.borderHairline, lineWidth: 1)
                        )
                        .shadow(color: MedhaTheme.Shadows.softMedium, radius: 14, x: 0, y: 6)
                        .frame(maxWidth: card.effectiveCardType == .imageOcclusion ? 720 : 620)

                        // Socratic Dialogue History (if active)
                        if isSocraticActiveForCurrentCard && !dialogueHistory.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(dialogueHistory) { turn in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text("Your Response (Round \(turn.roundNumber)):")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            if turn.isSpotOn {
                                                Label("Mastered!", systemImage: "checkmark.seal.fill")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.green)
                                            }
                                        }

                                        Text(turn.userAnswer)
                                            .font(.system(size: 12))
                                            .foregroundColor(.primary)

                                        HStack(alignment: .top, spacing: 6) {
                                            Image(systemName: "sparkles")
                                                .foregroundColor(.accentColor)
                                                .font(.system(size: 11))
                                            Text(turn.feedback)
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                        }

                                        if let cq = turn.counterQuestion, !cq.isEmpty {
                                            Text("💡 Probing Question: \(cq)")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                                    .cornerRadius(8)
                                }
                            }
                            .frame(maxWidth: 620)
                        }

                        // Written Recall Input (Socratic Mode)
                        if isSocraticActiveForCurrentCard && !isAnswerRevealed {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Type your written recall:")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }

                                TextEditor(text: $writtenAnswer)
                                    .focused($isWrittenInputFocused)
                                    .font(.system(size: 13))
                                    .frame(height: 70)
                                    .padding(4)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                                    )

                                HStack {
                                    Button("I don't know / Show Answer") {
                                        withAnimation { isAnswerRevealed = true }
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)

                                    Spacer()

                                    Button(action: evaluateWrittenRecall) {
                                        if isAIEvaluating {
                                            ProgressView().scaleEffect(0.6)
                                        } else {
                                            Label("Submit Recall", systemImage: "arrow.up.circle.fill")
                                                .font(.system(size: 11, weight: .semibold))
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    .disabled(writtenAnswer.trimmingCharacters(in: .whitespaces).isEmpty || isAIEvaluating)
                                }
                            }
                            .frame(maxWidth: 620)
                        }
                    }
                    .padding(24)
                }

                Divider()

                // Action Bar (Reveal Answer vs Rate FSRS)
                HStack(spacing: 12) {
                    if !isAnswerRevealed {
                        Button(action: {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                isAnswerRevealed = true
                            }
                        }) {
                            HStack(spacing: 6) {
                                Text("Show Answer")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Space")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            .frame(maxWidth: 280)
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.space, modifiers: [])
                    } else {
                        // 4 FSRS Rating Buttons (Again: 1, Hard: 2, Good: 3 / Space, Easy: 4)
                        ForEach(FSRSRating.allCases, id: \.self) { rating in
                            Button(action: {
                                handleRating(rating)
                            }) {
                                HStack(spacing: 6) {
                                    Text(rating.displayName)
                                        .font(.system(size: 13, weight: .bold))
                                    Text(shortcutBadge(for: rating))
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1.5)
                                        .background(Color.black.opacity(0.2))
                                        .cornerRadius(4)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .foregroundColor(.white)
                                .background(buttonColor(for: rating))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .keyboardShortcut(keyboardShortcut(for: rating), modifiers: [])
                        }

                        // Hidden helper button to ensure Space also triggers Good
                        Button(action: { handleRating(.good) }) {
                            EmptyView()
                        }
                        .keyboardShortcut(.space, modifiers: [])
                        .frame(width: 0, height: 0)
                        .opacity(0)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .sheet(isPresented: $isAISettingsSheetPresented) {
            AISettingsSheet(onDismiss: { isAISettingsSheetPresented = false })
        }
        .sheet(isPresented: $isDeckOptionsSheetPresented) {
            DeckOptionsSheet(
                store: store,
                deck: deck,
                onDismiss: {
                    isDeckOptionsSheetPresented = false
                    loadCards()
                }
            )
        }
        .onAppear {
            loadCards()
            setupKeyMonitor()
        }
        .onDisappear {
            removeKeyMonitor()
        }
    }

    private var emptyOrLimitReachedView: some View {
        let options = optionsManager.options(forDeck: deck)
        let deckId = deck?.id ?? Deck.notesDefaultId
        let allDeckCards = deck != nil ? store.flashcards(forDeck: deckId) : store.flashcards
        let totalNewCardsInDeck = allDeckCards.filter { $0.fsrsState == .newCard && !$0.isEffectivelySuspended }.count
        let studiedToday = dailyTracker.newCardsStudiedCount(forDeckId: deckId)
        let limitReached = (totalNewCardsInDeck > 0 && studiedToday >= options.maxNewCardsPerDay)

        return VStack(spacing: 16) {
            Spacer()
            Image(systemName: limitReached ? "checkmark.seal.fill" : "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text(limitReached ? "Daily Limit Reached! 🎉" : "No Cards Due for Study!")
                .font(.system(size: 18, weight: .bold))
            Text(limitReached
                 ? "You've studied all \(studiedToday) new cards scheduled for today based on your deck limit of \(options.maxNewCardsPerDay) new cards/day. More cards will unlock tomorrow."
                 : "You've mastered all current review cards in this deck according to your spaced repetition schedule.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            if limitReached {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Button("Study +10 More New Cards") {
                            dailyTracker.increaseTodayNewLimit(forDeckId: deckId, by: 10)
                            loadCards()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)

                        Button("Study +20 More") {
                            dailyTracker.increaseTodayNewLimit(forDeckId: deckId, by: 20)
                            loadCards()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }

                    HStack(spacing: 14) {
                        Button(action: { isDeckOptionsSheetPresented = true }) {
                            Label("Edit Deck Options...", systemImage: "gearshape")
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.accentColor)

                        Button("Return to Decks") {
                            onDismiss()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            } else {
                Button("Return to Decks") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
    }

    private func loadCards() {
        let options = optionsManager.options(forDeck: deck)
        if let targetDeck = deck {
            let cards = store.flashcards(forDeck: targetDeck.id)
            sessionCards = dailyTracker.queueForStudy(allCards: cards, deck: targetDeck, options: options)
        } else {
            sessionCards = dailyTracker.queueForStudy(allCards: store.flashcards, deck: nil, options: options)
        }
        currentIndex = 0
        isAnswerRevealed = false
    }

    private func evaluateWrittenRecall() {
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
        let targetDeckId = card.deckId ?? deck?.id ?? Deck.notesDefaultId
        let wasNew = (card.fsrsState == .newCard || card.reps == 0)

        _ = store.rateFlashcard(id: card.id, rating: rating)
        dailyTracker.recordCardReviewed(card: card, deckId: targetDeckId, wasNew: wasNew)

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
        } else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                sessionCards = []
                currentIndex = 0
            }
        }
    }

    private func buttonColor(for rating: FSRSRating) -> Color {
        switch rating {
        case .again: return MedhaTheme.Colors.ratingAgain
        case .hard: return MedhaTheme.Colors.ratingHard
        case .good: return MedhaTheme.Colors.ratingGood
        case .easy: return MedhaTheme.Colors.ratingEasy
        }
    }

    private func shortcutBadge(for rating: FSRSRating) -> String {
        switch rating {
        case .again: return "1"
        case .hard: return "2"
        case .good: return "3 · Space"
        case .easy: return "4"
        }
    }

    private func keyboardShortcut(for rating: FSRSRating) -> KeyEquivalent {
        switch rating {
        case .again: return "1"
        case .hard: return "2"
        case .good: return "3"
        case .easy: return "4"
        }
    }

    private func setupKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Don't intercept when Command or Control shortcuts are pressed
            if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) {
                return event
            }

            // If user is currently typing in the written answer box, let normal typing pass through
            if isWrittenInputFocused {
                return event
            }

            if isAnswerRevealed {
                if let chars = event.charactersIgnoringModifiers {
                    if chars == "1" {
                        handleRating(.again)
                        return nil
                    } else if chars == "2" {
                        handleRating(.hard)
                        return nil
                    } else if chars == "3" || event.keyCode == 49 || chars == " " {
                        handleRating(.good)
                        return nil
                    } else if chars == "4" {
                        handleRating(.easy)
                        return nil
                    }
                }
            } else {
                // Spacebar reveals the answer
                if event.keyCode == 49 || event.characters == " " {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        isAnswerRevealed = true
                    }
                    return nil
                }
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}
