import SwiftUI
import AppKit

public struct DeckOptionsSheet: View {
    @ObservedObject public var store: BlockStore
    @ObservedObject public var optionsManager = DeckOptionsManager.shared
    public var deck: Deck?
    public let onDismiss: () -> Void

    @State private var selectedPresetId: String = DeckOptionsPreset.defaultPresetId
    @State private var draftOptions: DeckOptions = DeckOptions()
    @State private var isCreatingNewPreset: Bool = false
    @State private var newPresetName: String = ""
    @State private var isRenamingPreset: Bool = false
    @State private var renamePresetName: String = ""
    @State private var activeTab: OptionsTab = .dailyLimits

    public enum OptionsTab: String, CaseIterable, Identifiable {
        case dailyLimits = "Daily Limits"
        case newCards = "New Cards"
        case lapses = "Lapses"
        case displayOrder = "Display Order"
        case fsrs = "FSRS Parameters"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .dailyLimits: return "clock.badge.checkmark"
            case .newCards: return "sparkles"
            case .lapses: return "arrow.triangle.2.circlepath"
            case .displayOrder: return "arrow.up.arrow.down"
            case .fsrs: return "brain.head.profile"
            }
        }
    }

    public init(store: BlockStore, deck: Deck?, onDismiss: @escaping () -> Void) {
        self.store = store
        self.deck = deck
        self.onDismiss = onDismiss
    }

    private var currentPreset: DeckOptionsPreset {
        optionsManager.preset(withId: selectedPresetId)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(deck == nil ? "Global Deck Options" : "Deck Options: \(deck!.name)")
                        .font(.system(size: 16, weight: .bold))
                    Text("Configure spaced repetition limits, display order, lapses, and FSRS parameters.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Preset Selector Toolbar
            HStack(spacing: 12) {
                Text("Options Preset:")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Picker("", selection: $selectedPresetId) {
                    ForEach(optionsManager.presets) { preset in
                        Text(preset.name + (preset.isDefault ? " (Default)" : "")).tag(preset.id)
                    }
                }
                .frame(width: 200)
                .onChange(of: selectedPresetId) { newId in
                    draftOptions = optionsManager.preset(withId: newId).options
                }

                Button(action: {
                    newPresetName = "Custom Preset \(optionsManager.presets.count + 1)"
                    isCreatingNewPreset = true
                }) {
                    Label("New Preset", systemImage: "plus")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: {
                    renamePresetName = currentPreset.name
                    isRenamingPreset = true
                }) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(currentPreset.isDefault)
                .help("Rename preset")

                if !currentPreset.isDefault {
                    Button(role: .destructive, action: {
                        optionsManager.deletePreset(id: currentPreset.id)
                        selectedPresetId = DeckOptionsPreset.defaultPresetId
                        draftOptions = optionsManager.defaultPreset.options
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Delete preset")
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            // Main Settings Content with Tabs
            HStack(alignment: .top, spacing: 0) {
                // Left Navigation Tabs
                VStack(spacing: 4) {
                    ForEach(OptionsTab.allCases) { tab in
                        Button(action: { activeTab = tab }) {
                            HStack(spacing: 8) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 13))
                                    .foregroundColor(activeTab == tab ? .accentColor : .secondary)
                                    .frame(width: 20)
                                Text(tab.rawValue)
                                    .font(.system(size: 12, weight: activeTab == tab ? .semibold : .regular))
                                    .foregroundColor(activeTab == tab ? .primary : .secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(activeTab == tab ? Color.accentColor.opacity(0.12) : Color.clear)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .frame(width: 175)
                .padding(12)
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                // Active Tab Content Area
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        switch activeTab {
                        case .dailyLimits:
                            dailyLimitsSection
                        case .newCards:
                            newCardsSection
                        case .lapses:
                            lapsesSection
                        case .displayOrder:
                            displayOrderSection
                        case .fsrs:
                            fsrsSection
                        }
                    }
                    .padding(20)
                }
                .background(Color(NSColor.controlBackgroundColor).opacity(0.2))
            }
            .frame(height: 380)

            Divider()

            // Footer
            HStack {
                Button("Reset to Defaults") {
                    draftOptions = DeckOptions()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

                Spacer()

                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Button("Save Preset & Apply") {
                    saveAndApply()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 680, height: 530)
        .onAppear {
            let initialPresetId = deck?.presetId ?? DeckOptionsPreset.defaultPresetId
            selectedPresetId = initialPresetId
            draftOptions = optionsManager.preset(withId: initialPresetId).options
        }
        .sheet(isPresented: $isCreatingNewPreset) {
            newPresetModal
        }
        .sheet(isPresented: $isRenamingPreset) {
            renamePresetModal
        }
    }

    // MARK: - 1. Daily Limits Section
    private var dailyLimitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Daily Limits",
                description: "Set maximum threshold of new cards and reviews to be introduced daily."
            )

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New cards / day")
                            .font(.system(size: 13, weight: .medium))
                        Text("The maximum number of brand new flashcards to introduce each day.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        TextField("", value: $draftOptions.maxNewCardsPerDay, formatter: NumberFormatter())
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                        Stepper("", value: $draftOptions.maxNewCardsPerDay, in: 0...9999)
                            .labelsHidden()
                    }
                }
                .padding(12)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Maximum reviews / day")
                            .font(.system(size: 13, weight: .medium))
                        Text("The upper limit of review cards due for recall in a single day.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        TextField("", value: $draftOptions.maxReviewsPerDay, formatter: NumberFormatter())
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                        Stepper("", value: $draftOptions.maxReviewsPerDay, in: 0...99999)
                            .labelsHidden()
                    }
                }
                .padding(12)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - 2. New Cards Section
    private var newCardsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "New Cards",
                description: "Configure learning progression steps and introduction order for new material."
            )

            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Learning steps")
                            .font(.system(size: 13, weight: .medium))
                        Text("Spaced delays for initial learning, separated by spaces (e.g. '1m 10m').")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    TextField("1m 10m", text: $draftOptions.learningSteps)
                        .frame(width: 140)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(12)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Insertion order")
                            .font(.system(size: 13, weight: .medium))
                        Text("Determines whether new cards appear in sequential order or randomized.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $draftOptions.insertionOrder) {
                        ForEach(DeckInsertionOrder.allCases) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .frame(width: 180)
                }
                .padding(12)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - 3. Lapses Section
    private var lapsesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Lapses & Leech Management",
                description: "Handle cards that were forgotten during review and automate leech management."
            )

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Relearning steps")
                            .font(.system(size: 13, weight: .medium))
                        Text("Steps applied when a reviewed card is forgotten (e.g. '10m').")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    TextField("10m", text: $draftOptions.relearningSteps)
                        .frame(width: 140)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(12)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Leech threshold")
                            .font(.system(size: 13, weight: .medium))
                        Text("Number of lapses before a card is marked as a leech.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Text("\(draftOptions.leechThreshold) lapses")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        Stepper("", value: $draftOptions.leechThreshold, in: 1...50)
                            .labelsHidden()
                    }
                }
                .padding(12)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Leech action")
                            .font(.system(size: 13, weight: .medium))
                        Text("What happens automatically when a card exceeds the leech threshold.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $draftOptions.leechAction) {
                        ForEach(DeckLeechAction.allCases) { action in
                            Text(action.rawValue).tag(action)
                        }
                    }
                    .frame(width: 160)
                }
                .padding(12)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - 4. Display Order Section
    private var displayOrderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Display Order",
                description: "Control the sorting and prioritization sequence of cards during study sessions."
            )

            VStack(spacing: 10) {
                orderRow(
                    title: "New card gather order",
                    subtitle: "How new cards are collected from the deck hierarchy",
                    selection: $draftOptions.newCardGatherOrder,
                    options: NewCardGatherOrder.allCases
                )

                orderRow(
                    title: "New card sort order",
                    subtitle: "How new cards are ordered once gathered",
                    selection: $draftOptions.newCardSortOrder,
                    options: NewCardSortOrder.allCases
                )

                orderRow(
                    title: "New / review order",
                    subtitle: "When new cards appear relative to due review cards",
                    selection: $draftOptions.newReviewOrder,
                    options: NewReviewOrder.allCases
                )

                orderRow(
                    title: "Interday learning / review order",
                    subtitle: "Positioning of learning cards crossing the day boundary",
                    selection: $draftOptions.interdayOrder,
                    options: InterdayOrder.allCases
                )

                orderRow(
                    title: "Review sort order",
                    subtitle: "How due review cards are sorted during the session",
                    selection: $draftOptions.reviewSortOrder,
                    options: ReviewSortOrder.allCases
                )
            }
        }
    }

    // MARK: - 5. FSRS Section
    private var fsrsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Free Spaced Repetition Scheduler (FSRS)",
                description: "Configure FSRS memory retention targets and maximum intervals for this deck."
            )

            VStack(spacing: 14) {
                // Retention Slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Desired Retention")
                                .font(.system(size: 13, weight: .medium))
                            Text("Target probability of successfully recalling a card when due.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(Int(draftOptions.desiredRetention * 100))%")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.12))
                            .cornerRadius(6)
                    }

                    Slider(
                        value: $draftOptions.desiredRetention,
                        in: 0.70...0.97,
                        step: 0.01
                    )
                    .accentColor(.accentColor)

                    HStack {
                        Text("70% (Lighter load)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("90% (Recommended)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.accentColor)
                        Spacer()
                        Text("97% (Strict mastery)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(14)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)

                // Maximum Interval
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Maximum Interval")
                            .font(.system(size: 13, weight: .medium))
                        Text("The maximum number of days a card will be scheduled out.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        TextField("", value: $draftOptions.maximumInterval, formatter: NumberFormatter())
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                        Text("days")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)

                // Algorithm Info Card
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 14))
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Why FSRS?")
                            .font(.system(size: 11, weight: .bold))
                        Text("FSRS dynamically models Memory Stability (S) and Item Difficulty (D) based on real recall history, drastically reducing overall review workload compared to legacy SM-2 while guaranteeing target retention.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .background(Color.blue.opacity(0.08))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Helper Views & Actions
    private func sectionHeader(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
            Text(description)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    private func orderRow<T: Hashable & RawRepresentable & Identifiable>(
        title: String,
        subtitle: String,
        selection: Binding<T>,
        options: [T]
    ) -> some View where T.RawValue == String {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Picker("", selection: selection) {
                ForEach(options) { opt in
                    Text(opt.rawValue).tag(opt)
                }
            }
            .frame(width: 200)
        }
        .padding(10)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(6)
    }

    private func saveAndApply() {
        var preset = currentPreset
        preset.options = draftOptions
        optionsManager.savePreset(preset)

        if let deck = deck {
            store.assignPreset(presetId: preset.id, toDeckId: deck.id)
        }
        onDismiss()
    }

    private var newPresetModal: some View {
        VStack(spacing: 16) {
            Text("Create Options Preset")
                .font(.system(size: 14, weight: .bold))

            TextField("Preset Name", text: $newPresetName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") { isCreatingNewPreset = false }
                Spacer()
                Button("Create") {
                    let created = optionsManager.createPreset(name: newPresetName, basedOn: draftOptions)
                    selectedPresetId = created.id
                    isCreatingNewPreset = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private var renamePresetModal: some View {
        VStack(spacing: 16) {
            Text("Rename Preset")
                .font(.system(size: 14, weight: .bold))

            TextField("Preset Name", text: $renamePresetName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") { isRenamingPreset = false }
                Spacer()
                Button("Rename") {
                    var p = currentPreset
                    p.name = renamePresetName
                    optionsManager.savePreset(p)
                    isRenamingPreset = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(renamePresetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}
