import SwiftUI
import AppKit

public struct ImageOcclusionEditorSheet: View {
    @ObservedObject public var store: BlockStore
    @Binding public var isPresented: Bool
    public var preselectedDeckId: String? = nil
    public var preselectedDocId: String? = nil

    @State private var targetDeckId: String = ""
    @State private var targetDocId: String = ""
    @State private var diagramTitle: String = "Anatomy Diagram"
    @State private var hint: String = ""
    @State private var mode: OcclusionMode = .hideAllRevealOne

    @State private var loadedImage: NSImage? = nil
    @State private var loadedImageFilename: String? = nil
    @State private var masks: [ImageOcclusionMask] = []
    @State private var selectedMaskId: String? = nil
    @State private var editingLabelText: String = ""

    public init(
        store: BlockStore,
        isPresented: Binding<Bool>,
        preselectedDeckId: String? = nil,
        preselectedDocId: String? = nil
    ) {
        self.store = store
        self._isPresented = isPresented
        self.preselectedDeckId = preselectedDeckId
        self.preselectedDocId = preselectedDocId
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Image Occlusion Studio")
                        .font(MedhaTheme.Typography.title)
                        .foregroundColor(MedhaTheme.Colors.textPrimary)
                    Text("Click and drag over labels in diagrams to create active recall occlusion cards")
                        .font(MedhaTheme.Typography.caption)
                        .foregroundColor(MedhaTheme.Colors.textSecondary)
                }

                Spacer()

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(MedhaTheme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(MedhaTheme.Colors.bgSurface)

            Divider()

            // Main Editor Body
            HSplitView {
                // Left: Canvas Workspace
                VStack(spacing: 0) {
                    if let img = loadedImage {
                        ZStack {
                            MedhaTheme.Colors.bgBase
                                .ignoresSafeArea()

                            ImageOcclusionCanvasView(
                                image: img,
                                masks: masks,
                                activeMaskId: nil,
                                mode: mode,
                                isAnswerRevealed: false,
                                isEditable: true,
                                selectedMaskId: selectedMaskId,
                                onSelectMask: { mask in
                                    selectedMaskId = mask.id
                                    editingLabelText = mask.label ?? ""
                                },
                                onAddMask: { newNormRect in
                                    let newMask = ImageOcclusionMask(
                                        x: newNormRect.minX,
                                        y: newNormRect.minY,
                                        width: newNormRect.width,
                                        height: newNormRect.height,
                                        label: "Label \(masks.count + 1)",
                                        orderIndex: masks.count
                                    )
                                    masks.append(newMask)
                                    selectedMaskId = newMask.id
                                    editingLabelText = newMask.label ?? ""
                                },
                                onDeleteMask: { maskId in
                                    masks.removeAll(where: { $0.id == maskId })
                                    if selectedMaskId == maskId {
                                        selectedMaskId = nil
                                    }
                                }
                            )
                            .padding(16)
                        }
                    } else {
                        // Empty State / Image Picker
                        VStack(spacing: 16) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 48))
                                .foregroundColor(MedhaTheme.Colors.accent)

                            Text("Select or Drop a Diagram Image")
                                .font(MedhaTheme.Typography.headline)
                                .foregroundColor(MedhaTheme.Colors.textPrimary)

                            Text("Supports PNG, JPEG, HEIC histology slides, anatomical diagrams, and STEM schematics.")
                                .font(MedhaTheme.Typography.caption)
                                .foregroundColor(MedhaTheme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 320)

                            Button(action: selectImageFromDisk) {
                                Label("Choose Image from Mac...", systemImage: "folder")
                                    .medhaPrimaryButton()
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(MedhaTheme.Colors.bgBase)
                    }

                    // Bottom Canvas Toolbar
                    if loadedImage != nil {
                        HStack(spacing: 12) {
                            Button(action: selectImageFromDisk) {
                                Label("Replace Image", systemImage: "photo")
                                    .font(MedhaTheme.Typography.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Spacer()

                            Text("\(masks.count) Occlusion Mask\(masks.count == 1 ? "" : "s")")
                                .font(MedhaTheme.Typography.roundedBadge)
                                .foregroundColor(MedhaTheme.Colors.textSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(MedhaTheme.Colors.bgSurface)
                        .border(MedhaTheme.Colors.borderHairline, width: 0.5)
                    }
                }
                .frame(minWidth: 440)

                // Right: Settings & Mask Inspector Inspector
                VStack(alignment: .leading, spacing: 16) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Section: Diagram Meta
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Diagram Title")
                                    .font(MedhaTheme.Typography.caption)
                                    .foregroundColor(MedhaTheme.Colors.textSecondary)
                                TextField("e.g. Heart Anatomy & Coronary Vessels", text: $diagramTitle)
                                    .textFieldStyle(.roundedBorder)

                                Text("Hint / Subject")
                                    .font(MedhaTheme.Typography.caption)
                                    .foregroundColor(MedhaTheme.Colors.textSecondary)
                                    .padding(.top, 4)
                                TextField("e.g. Anterior view, cardiology", text: $hint)
                                    .textFieldStyle(.roundedBorder)
                            }

                            // Section: Target Deck
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Target Deck")
                                    .font(MedhaTheme.Typography.caption)
                                    .foregroundColor(MedhaTheme.Colors.textSecondary)

                                Picker("", selection: $targetDeckId) {
                                    let notesId = store.defaultNotesDeck?.id ?? Deck.notesDefaultId
                                    Text("📁 Notes & Documents").tag(notesId)

                                    ForEach(store.decks.filter { !$0.isNotesDefault }) { deck in
                                        Text(deck.name).tag(deck.id)
                                    }
                                }
                                .labelsHidden()
                            }

                            // Section: Occlusion Mode
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Study Mode")
                                    .font(MedhaTheme.Typography.caption)
                                    .foregroundColor(MedhaTheme.Colors.textSecondary)

                                Picker("", selection: $mode) {
                                    Text("Hide All, Reveal One").tag(OcclusionMode.hideAllRevealOne)
                                    Text("Hide One, Reveal One").tag(OcclusionMode.hideOneRevealOne)
                                }
                                .pickerStyle(.segmented)

                                Text(mode == .hideAllRevealOne
                                     ? "Blocks out ALL labels so adjacent labels don't spoil the answer."
                                     : "Leaves other labels visible to provide contextual anatomical landmarks.")
                                    .font(.system(size: 10))
                                    .foregroundColor(MedhaTheme.Colors.textTertiary)
                            }

                            Divider()

                            // Section: Selected Mask Inspector
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Masks (\(masks.count))")
                                        .font(MedhaTheme.Typography.headline)
                                        .foregroundColor(MedhaTheme.Colors.textPrimary)
                                    Spacer()
                                    if !masks.isEmpty {
                                        Button("Clear All") {
                                            masks.removeAll()
                                            selectedMaskId = nil
                                        }
                                        .font(MedhaTheme.Typography.caption)
                                        .buttonStyle(.plain)
                                        .foregroundColor(MedhaTheme.Colors.ratingAgain)
                                    }
                                }

                                if let selId = selectedMaskId, let index = masks.firstIndex(where: { $0.id == selId }) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Selected Mask #\(index + 1) Answer:")
                                            .font(MedhaTheme.Typography.caption)
                                            .foregroundColor(MedhaTheme.Colors.textSecondary)

                                        HStack {
                                            TextField("Answer label", text: $editingLabelText)
                                                .textFieldStyle(.roundedBorder)
                                                .onChange(of: editingLabelText) { _, newVal in
                                                    masks[index].label = newVal
                                                }

                                            Button(action: {
                                                masks.remove(at: index)
                                                selectedMaskId = nil
                                            }) {
                                                Image(systemName: "trash")
                                                    .foregroundColor(MedhaTheme.Colors.ratingAgain)
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                        }
                                    }
                                    .padding(10)
                                    .background(MedhaTheme.Colors.bgElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(MedhaTheme.Colors.accent.opacity(0.4), lineWidth: 1)
                                    )
                                } else {
                                    Text("Click any mask on the diagram or drag to create a new one.")
                                        .font(.system(size: 11))
                                        .foregroundColor(MedhaTheme.Colors.textTertiary)
                                        .padding(.vertical, 4)
                                }

                                // List of masks
                                ForEach(Array(masks.enumerated()), id: \.element.id) { idx, mask in
                                    HStack {
                                        Text("#\(idx + 1)")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundColor(MedhaTheme.Colors.textTertiary)
                                            .frame(width: 24)

                                        Text(mask.label?.isEmpty == false ? mask.label! : "Untitled Box")
                                            .font(.system(size: 12))
                                            .foregroundColor(MedhaTheme.Colors.textPrimary)
                                            .lineLimit(1)

                                        Spacer()

                                        Button(action: {
                                            masks.removeAll(where: { $0.id == mask.id })
                                            if selectedMaskId == mask.id { selectedMaskId = nil }
                                        }) {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 10))
                                                .foregroundColor(MedhaTheme.Colors.textTertiary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(selectedMaskId == mask.id ? MedhaTheme.Colors.accent.opacity(0.12) : MedhaTheme.Colors.bgSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .onTapGesture {
                                        selectedMaskId = mask.id
                                        editingLabelText = mask.label ?? ""
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }

                    Spacer()

                    // Action Buttons
                    HStack {
                        Button("Cancel") { isPresented = false }
                            .buttonStyle(.plain)
                            .foregroundColor(MedhaTheme.Colors.textSecondary)

                        Spacer()

                        Button(action: generateOcclusionCards) {
                            Text("Generate \(masks.count) Card\(masks.count == 1 ? "" : "s")")
                                .medhaPrimaryButton()
                        }
                        .buttonStyle(.plain)
                        .disabled(loadedImage == nil || masks.isEmpty || diagramTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(16)
                    .background(MedhaTheme.Colors.bgSurface)
                }
                .frame(width: 280)
                .background(MedhaTheme.Colors.bgElevated)
            }
        }
        .frame(width: 880, height: 620)
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

    private func selectImageFromDisk() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image, .png, .jpeg]

        if panel.runModal() == .OK, let url = panel.url {
            if let img = NSImage(contentsOf: url) {
                // Save to OcclusionAssetStorage
                if let savedFilename = OcclusionAssetStorage.saveImage(img) {
                    self.loadedImage = img
                    self.loadedImageFilename = savedFilename
                } else {
                    self.loadedImage = img
                    self.loadedImageFilename = url.path
                }
            }
        }
    }

    private func generateOcclusionCards() {
        guard let filename = loadedImageFilename, !masks.isEmpty else { return }

        store.createImageOcclusionCards(
            imagePath: filename,
            masks: masks,
            mode: mode,
            deckId: targetDeckId,
            docId: targetDocId.isEmpty ? nil : targetDocId,
            diagramTitle: diagramTitle.trimmingCharacters(in: .whitespaces),
            hint: hint.trimmingCharacters(in: .whitespaces).isEmpty ? nil : hint
        )

        isPresented = false
    }
}
