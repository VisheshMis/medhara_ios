import SwiftUI
import AppKit

public struct MemoryPalaceView: View {
    @ObservedObject public var store: BlockStore

    // Canvas Navigation & Zoom
    @State private var canvasOffset: CGSize = .zero
    @State private var canvasScale: CGFloat = 1.0
    @State private var lastDragTranslation: CGSize = .zero

    // Photo Node Dragging on Canvas
    @State private var draggingPhotoId: String? = nil
    @State private var dragOffset: CGSize = .zero

    // Walk Mode & Locus Focus
    @State private var isWalkModeActive: Bool = false
    @State private var walkStepIndex: Int = 0
    @State private var walkCardIndex: Int = 0
    @State private var isWalkAnswerRevealed: Bool = false
    @State private var isAnchorRevealed: Bool = false
    @State private var isWalkCompleted: Bool = false
    @State private var canvasViewportSize: CGSize = .zero

    // Sheets & Selection
    @State private var selectedLocus: PalaceLocus? = nil
    @State private var editingLocus: PalaceLocus? = nil
    @State private var isAddPalaceSheetPresented: Bool = false
    @State private var isAddPhotoSheetPresented: Bool = false

    public init(store: BlockStore) {
        self.store = store
    }

    private var currentPalace: MemoryPalace? {
        store.selectedPalace
    }

    private var sortedPhotos: [PalacePhoto] {
        store.palacePhotos.sorted(by: { $0.orderIndex < $1.orderIndex })
    }

    private var sortedLoci: [PalaceLocus] {
        store.loci.sorted(by: { $0.orderIndex < $1.orderIndex })
    }

    public var body: some View {
        HSplitView {
            // MARK: - Left Column: Palaces, Photos & Loci Journey
            VStack(spacing: 0) {
                // Palace Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MEMORY PALACES")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        if let palace = currentPalace {
                            Text(palace.name)
                                .font(.system(size: 14, weight: .bold))
                                .lineLimit(1)
                        }
                    }
                    Spacer()

                    Button(action: { isAddPalaceSheetPresented = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .help("Create New Memory Palace")
                }
                .padding(12)
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                // Palaces Picker & Add Photo
                HStack(spacing: 8) {
                    Picker("", selection: Binding(
                        get: { store.selectedPalaceId ?? "" },
                        set: { store.selectPalace(id: $0) }
                    )) {
                        ForEach(store.memoryPalaces) { p in
                            Text(p.name).tag(p.id)
                        }
                    }
                    .labelsHidden()

                    Button(action: { isAddPhotoSheetPresented = true }) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .help("Add Photo / Scene to Canvas")
                }
                .padding(10)

                Divider()

                // Photos / Scenes Strip
                if !sortedPhotos.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("PHOTOS ON CANVAS (\(sortedPhotos.count))")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()

                            Button(action: { isAddPhotoSheetPresented = true }) {
                                HStack(spacing: 2) {
                                    Image(systemName: "plus")
                                    Text("Add")
                                }
                                .font(.system(size: 10, weight: .semibold))
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 6)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Array(sortedPhotos.enumerated()), id: \.element.id) { idx, photo in
                                    Button(action: {
                                        store.selectPhoto(id: photo.id)
                                        centerCameraOnPhoto(photo, viewportSize: canvasViewportSize)
                                    }) {
                                        HStack(spacing: 4) {
                                            Text("\(idx + 1)")
                                                .font(.system(size: 9, weight: .bold))
                                                .frame(width: 16, height: 16)
                                                .background(store.activePhotoId == photo.id ? Color.accentColor : Color.secondary.opacity(0.3))
                                                .foregroundColor(.white)
                                                .clipShape(Circle())
                                            Text(photo.name)
                                                .font(.system(size: 11, weight: .medium))
                                                .lineLimit(1)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(store.activePhotoId == photo.id ? Color.accentColor.opacity(0.12) : Color(NSColor.controlBackgroundColor))
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.bottom, 6)
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.3))

                    Divider()
                }

                // Loci Stops Journey List
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("LOCI STOPS (\(sortedLoci.count))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        if !sortedLoci.isEmpty {
                            Button(action: {
                                if isWalkModeActive {
                                    withAnimation {
                                        isWalkModeActive = false
                                        isWalkCompleted = false
                                    }
                                } else {
                                    startWalk()
                                }
                            }) {
                                Label(isWalkModeActive ? "Exit Walk" : "Walk Palace", systemImage: isWalkModeActive ? "xmark" : "figure.walk")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .tint(isWalkModeActive ? .red : .accentColor)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    if sortedLoci.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("No Loci Pins Yet")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("Click inside any photo on the canvas to place a memory locus pin.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(16)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(Array(sortedLoci.enumerated()), id: \.element.id) { index, locus in
                                    locusListItemView(index: index, locus: locus)
                                }
                            }
                            .padding(8)
                        }
                    }
                }
            }
            .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))

            // MARK: - Right Column: Vast Spatial Canvas
            VStack(spacing: 0) {
                // Top Canvas Toolbar
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.split.bottomrightquarter")
                            .foregroundColor(.accentColor)
                        Text(currentPalace?.name ?? "Memory Palace")
                            .font(.system(size: 13, weight: .semibold))

                        Text("• \(sortedPhotos.count) Photos • \(sortedLoci.count) Loci")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Zoom Controls
                    HStack(spacing: 4) {
                        Button(action: { canvasScale = max(0.3, canvasScale - 0.15) }) {
                            Image(systemName: "minus.magnifyingglass")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Text("\(Int(canvasScale * 100))%")
                            .font(.system(size: 10, design: .monospaced))
                            .frame(width: 42)

                        Button(action: { canvasScale = min(2.5, canvasScale + 0.15) }) {
                            Image(systemName: "plus.magnifyingglass")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button(action: resetCanvasView) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Reset Canvas View (100%)")
                    }

                    if !sortedLoci.isEmpty {
                        Button(action: {
                            if isWalkModeActive {
                                withAnimation {
                                    isWalkModeActive = false
                                    isWalkCompleted = false
                                }
                            } else {
                                startWalk()
                            }
                        }) {
                            Label(isWalkModeActive ? "Exit Walk" : "Start Walk", systemImage: isWalkModeActive ? "xmark.circle.fill" : "figure.walk")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(isWalkModeActive ? .red : .accentColor)
                    }

                    Button(action: { isAddPhotoSheetPresented = true }) {
                        Label("+ Add Photo", systemImage: "plus")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                // Vast Infinite/Broad 2D Canvas
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        // 1. Interactive 2D Canvas Plane (clipped to viewport)
                        ZStack(alignment: .topLeading) {
                            VastBlueprintGridBackground()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            if !isWalkModeActive {
                                                canvasOffset.width += value.translation.width - lastDragTranslation.width
                                                canvasOffset.height += value.translation.height - lastDragTranslation.height
                                                lastDragTranslation = value.translation
                                            }
                                        }
                                        .onEnded { _ in
                                            lastDragTranslation = .zero
                                        }
                                )

                            ZStack(alignment: .topLeading) {
                                // 1. Inter-Photo Sequential Connector Curves
                                ForEach(0..<max(0, sortedPhotos.count - 1), id: \.self) { idx in
                                    let p1 = sortedPhotos[idx]
                                    let p2 = sortedPhotos[idx + 1]
                                    PhotoConnectorView(
                                        from: p1,
                                        to: p2,
                                        draggingPhotoId: draggingPhotoId,
                                        dragOffset: CGSize(width: dragOffset.width / canvasScale, height: dragOffset.height / canvasScale),
                                        fromIndex: idx + 1,
                                        toIndex: idx + 2
                                    )
                                }

                                // 2. Continuous Loci Journey Line Across Canvas
                                if sortedLoci.count > 1 {
                                    Path { path in
                                        for (i, locus) in sortedLoci.enumerated() {
                                            let pt = locusCanvasPosition(locus)
                                            if i == 0 {
                                                path.move(to: pt)
                                            } else {
                                                path.addLine(to: pt)
                                            }
                                        }
                                    }
                                    .stroke(
                                        Color.accentColor.opacity(0.6),
                                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [8, 5])
                                    )
                                }

                                // 3. Spatial Photo Nodes
                                ForEach(Array(sortedPhotos.enumerated()), id: \.element.id) { idx, photo in
                                    let isDragging = draggingPhotoId == photo.id
                                    let posX = photo.canvasX + (isDragging ? dragOffset.width / canvasScale : 0)
                                    let posY = photo.canvasY + (isDragging ? dragOffset.height / canvasScale : 0)

                                    PalacePhotoCardView(
                                        photo: photo,
                                        index: idx + 1,
                                        totalPhotos: sortedPhotos.count,
                                        store: store,
                                        isWalkModeActive: isWalkModeActive,
                                        walkStepIndex: walkStepIndex,
                                        selectedLocusId: selectedLocus?.id,
                                        onSelectLocus: { locus in
                                            if isWalkModeActive {
                                                if let targetIdx = sortedLoci.firstIndex(where: { $0.id == locus.id }) {
                                                    jumpToWalkStep(targetIdx, viewportSize: canvasViewportSize)
                                                }
                                            } else {
                                                selectedLocus = locus
                                                editingLocus = locus
                                            }
                                        },
                                        onAddLocusAt: { normX, normY in
                                            handlePhotoCanvasClick(photo: photo, normX: normX, normY: normY)
                                        },
                                        onMoveEarlier: {
                                            movePhotoInSequence(photo: photo, direction: -1)
                                        },
                                        onMoveLater: {
                                            movePhotoInSequence(photo: photo, direction: 1)
                                        },
                                        onChangeImage: {
                                            pickUserImage(for: photo)
                                        },
                                        onDeletePhoto: {
                                            store.deletePalacePhoto(id: photo.id)
                                        }
                                    )
                                    .offset(x: posX, y: posY)
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                if !isWalkModeActive {
                                                    draggingPhotoId = photo.id
                                                    dragOffset = value.translation
                                                }
                                            }
                                            .onEnded { value in
                                                if !isWalkModeActive {
                                                    let finalX = max(20, photo.canvasX + value.translation.width / canvasScale)
                                                    let finalY = max(20, photo.canvasY + value.translation.height / canvasScale)
                                                    store.updatePhotoPosition(id: photo.id, x: finalX, y: finalY)
                                                    draggingPhotoId = nil
                                                    dragOffset = .zero
                                                }
                                            }
                                    )
                                }
                            }
                            .frame(width: 6000, height: 6000, alignment: .topLeading)
                            .scaleEffect(canvasScale, anchor: .topLeading)
                            .offset(canvasOffset)
                        }
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                        .clipped()

                        // 2. Fixed Viewport Walk Mode Overlay HUD
                        if isWalkModeActive && !sortedLoci.isEmpty {
                            if !isWalkCompleted && walkStepIndex < sortedLoci.count {
                                walkModeHUDView(locus: sortedLoci[walkStepIndex], total: sortedLoci.count, viewportSize: geo.size)
                                    .padding(.bottom, 20)
                                    .padding(.horizontal, 20)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            } else if isWalkCompleted {
                                walkCompletedView(total: sortedLoci.count, viewportSize: geo.size)
                                    .padding(.bottom, 20)
                                    .padding(.horizontal, 20)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .onAppear {
                        canvasViewportSize = geo.size
                        autoCenterCameraIfPossible(viewportSize: geo.size)
                    }
                    .onChange(of: geo.size) { _, newSize in
                        canvasViewportSize = newSize
                    }
                    .onChange(of: store.selectedPalaceId) { _, _ in
                        autoCenterCameraIfPossible(viewportSize: canvasViewportSize)
                    }
                    .onChange(of: store.palacePhotos.count) { _, newCount in
                        if newCount > 0 && canvasOffset == .zero {
                            autoCenterCameraIfPossible(viewportSize: canvasViewportSize)
                        }
                    }
                }
            }
        }
        .sheet(item: $editingLocus) { locus in
            LocusDetailSheet(store: store, locus: locus, onDismiss: { editingLocus = nil })
        }
        .sheet(isPresented: $isAddPalaceSheetPresented) {
            AddPalaceSheet(store: store, isPresented: $isAddPalaceSheetPresented)
        }
        .sheet(isPresented: $isAddPhotoSheetPresented) {
            AddPhotoSheet(store: store, isPresented: $isAddPhotoSheetPresented, onPhotoAdded: { newPhoto in
                centerCameraOnPhoto(newPhoto, viewportSize: canvasViewportSize)
            })
        }
    }

    private func autoCenterCameraIfPossible(viewportSize: CGSize) {
        let target = store.palacePhotos.first(where: { $0.id == store.activePhotoId }) ?? sortedPhotos.first
        if let target = target {
            DispatchQueue.main.async {
                centerCameraOnPhoto(target, viewportSize: viewportSize)
            }
        }
    }

    private func resetCanvasView() {
        if let target = store.palacePhotos.first(where: { $0.id == store.activePhotoId }) ?? sortedPhotos.first {
            centerCameraOnPhoto(target, viewportSize: canvasViewportSize)
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                canvasScale = 1.0
                canvasOffset = .zero
            }
        }
    }

    private func locusCanvasPosition(_ locus: PalaceLocus) -> CGPoint {
        guard let photo = store.palacePhotos.first(where: { $0.id == locus.photoId }) ?? store.palacePhotos.first else {
            return .zero
        }
        let curDrag = (draggingPhotoId == photo.id) ? CGSize(width: dragOffset.width / canvasScale, height: dragOffset.height / canvasScale) : .zero
        let posX = photo.canvasX + curDrag.width + (locus.normalizedX * photo.canvasWidth)
        let posY = photo.canvasY + curDrag.height + 36 + (locus.normalizedY * photo.canvasHeight)
        return CGPoint(x: posX, y: posY)
    }

    private func handlePhotoCanvasClick(photo: PalacePhoto, normX: Double, normY: Double) {
        guard let palace = currentPalace else { return }
        let count = store.loci.count
        let newLocus = store.addLocus(
            palaceId: palace.id,
            photoId: photo.id,
            title: "Locus \(count + 1)",
            x: normX,
            y: normY
        )
        selectedLocus = newLocus
        editingLocus = newLocus
    }

    private func movePhotoInSequence(photo: PalacePhoto, direction: Int) {
        guard let currentIndex = sortedPhotos.firstIndex(where: { $0.id == photo.id }) else { return }
        let targetIndex = currentIndex + direction
        guard targetIndex >= 0 && targetIndex < sortedPhotos.count else { return }

        var reordered = sortedPhotos
        reordered.swapAt(currentIndex, targetIndex)
        store.reorderPalacePhotos(palaceId: photo.palaceId, photoIds: reordered.map { $0.id })
    }

    private func pickUserImage(for photo: PalacePhoto) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .webP, .image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Choose 2D Photo / Room Image"

        if panel.runModal() == .OK, let url = panel.url {
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                // Safely copy chosen file to project storage folder to prevent accidental deletion
                let safePath = try PalaceAssetStorage.importPhoto(from: url)
                var updated = photo
                updated.imagePath = safePath
                store.updatePalacePhoto(updated)
                centerCameraOnPhoto(updated, viewportSize: canvasViewportSize)
            } catch {
                var updated = photo
                updated.imagePath = url.path
                store.updatePalacePhoto(updated)
                centerCameraOnPhoto(updated, viewportSize: canvasViewportSize)
            }
        }
    }

    // MARK: - Left Column Locus Item
    private func locusListItemView(index: Int, locus: PalaceLocus) -> some View {
        let isWalkActive = isWalkModeActive && index == walkStepIndex
        let isSelected = selectedLocus?.id == locus.id
        let cards = store.getFlashcards(for: locus.id)
        let photoName = store.palacePhotos.first(where: { $0.id == locus.photoId })?.name

        return Button(action: {
            if isWalkModeActive {
                jumpToWalkStep(index, viewportSize: canvasViewportSize)
            } else {
                selectedLocus = locus
                if let pid = locus.photoId {
                    store.selectPhoto(id: pid)
                }
                centerCameraOnLocus(locus, viewportSize: canvasViewportSize)
            }
        }) {
            HStack(spacing: 8) {
                // Pin Index Circle
                ZStack {
                    Circle()
                        .fill(isWalkActive ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                        .frame(width: 22, height: 22)
                    Text("\(index + 1)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isWalkActive ? .white : .primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(locus.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        if let pName = photoName {
                            Text("(\(pName))")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    if let mnemonic = locus.mnemonic, !mnemonic.isEmpty {
                        Text(mnemonic)
                            .font(.system(size: 10).italic())
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    // Direct Anchored Info Badge
                    if let anchor = locus.anchoredInfo, !anchor.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 7))
                            Text(anchor)
                                .font(.system(size: 9))
                                .lineLimit(1)
                        }
                        .foregroundColor(.cyan)
                    }

                    // Multi-Flashcards Indicator
                    if !cards.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.on.rectangle.angled")
                                .font(.system(size: 8))
                            Text("\(cards.count) Card\(cards.count > 1 ? "s" : ""): \(cards.first?.front ?? "")")
                                .font(.system(size: 9))
                                .lineLimit(1)
                        }
                        .foregroundColor(.accentColor)
                    }
                }

                Spacer()

                Button(action: {
                    editingLocus = locus
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Edit Locus Stop Details")

                Button(action: {
                    store.deleteLocus(id: locus.id)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            .background(isWalkActive ? Color.accentColor.opacity(0.15) : (isSelected ? Color(NSColor.controlBackgroundColor) : Color.clear))
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Walk Mode & Active Recall HUD
    private func startWalk() {
        guard !sortedLoci.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            walkStepIndex = 0
            walkCardIndex = 0
            isWalkAnswerRevealed = false
            isAnchorRevealed = false
            isWalkCompleted = false
            isWalkModeActive = true
            selectedLocus = sortedLoci[0]
        }
        centerCameraOnLocus(sortedLoci[0], viewportSize: canvasViewportSize)
    }

    private func jumpToWalkStep(_ index: Int, viewportSize: CGSize) {
        guard index >= 0 && index < sortedLoci.count else { return }
        withAnimation(.easeInOut(duration: 0.5)) {
            walkStepIndex = index
            walkCardIndex = 0
            isWalkAnswerRevealed = false
            isAnchorRevealed = false
            let targetLocus = sortedLoci[index]
            selectedLocus = targetLocus
            centerCameraOnLocus(targetLocus, viewportSize: viewportSize)
        }
    }

    private func advanceWalk(viewportSize: CGSize) {
        if walkStepIndex + 1 < sortedLoci.count {
            jumpToWalkStep(walkStepIndex + 1, viewportSize: viewportSize)
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                isWalkCompleted = true
            }
        }
    }

    private func previousWalk(viewportSize: CGSize) {
        if walkStepIndex > 0 {
            jumpToWalkStep(walkStepIndex - 1, viewportSize: viewportSize)
        }
    }

    private func centerCameraOnLocus(_ locus: PalaceLocus, viewportSize: CGSize) {
        let effectiveViewport = (viewportSize.width > 50 && viewportSize.height > 50) ? viewportSize : CGSize(width: 1200, height: 800)
        let pt = locusCanvasPosition(locus)
        let targetScale: CGFloat = 1.25
        withAnimation(.easeInOut(duration: 0.6)) {
            canvasScale = targetScale
            canvasOffset = CGSize(
                width: (effectiveViewport.width / 2.0) - (pt.x * targetScale),
                height: (effectiveViewport.height * 0.38) - (pt.y * targetScale)
            )
        }
    }

    private func centerCameraOnPhoto(_ photo: PalacePhoto, viewportSize: CGSize) {
        let effectiveViewport = (viewportSize.width > 50 && viewportSize.height > 50) ? viewportSize : CGSize(width: 1200, height: 800)
        let centerX = photo.canvasX + photo.canvasWidth / 2.0
        let centerY = photo.canvasY + (photo.canvasHeight + 36.0) / 2.0
        withAnimation(.easeInOut(duration: 0.55)) {
            canvasScale = 1.0
            canvasOffset = CGSize(
                width: (effectiveViewport.width / 2.0) - centerX,
                height: (effectiveViewport.height / 2.0) - centerY
            )
        }
    }

    // MARK: - Walk Mode HUD
    private func walkModeHUDView(locus: PalaceLocus, total: Int, viewportSize: CGSize) -> some View {
        let attachedCards = store.getFlashcards(for: locus.id)
        let photoName = store.palacePhotos.first(where: { $0.id == locus.photoId })?.name ?? "Scene"
        let isLastStep = walkStepIndex == total - 1

        return VStack(spacing: 12) {
            // 1. Header Bar: Progress & Stop Title
            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 11, weight: .bold))
                    Text("STOP \(walkStepIndex + 1) OF \(total)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.12))
                .cornerRadius(6)

                Text(locus.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text("• in \(photoName)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()

                Button(action: {
                    centerCameraOnLocus(locus, viewportSize: viewportSize)
                }) {
                    Label("Focus Pin", systemImage: "scope")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Re-center camera on this locus pin")

                Button(action: {
                    editingLocus = locus
                }) {
                    Label("Edit Stop", systemImage: "pencil")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Edit this stop's details, mnemonic, or flashcards")

                Button(action: {
                    withAnimation {
                        isWalkModeActive = false
                        isWalkCompleted = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Exit Walk Mode (Esc)")
            }

            // Journey Progress Indicator Track
            HStack(spacing: 4) {
                ForEach(0..<total, id: \.self) { i in
                    Capsule()
                        .fill(i == walkStepIndex ? Color.accentColor : (i < walkStepIndex ? Color.accentColor.opacity(0.4) : Color.secondary.opacity(0.2)))
                        .frame(height: 3)
                }
            }

            // 2. Mnemonic Sensory Imagery Cue
            if let mnemonic = locus.mnemonic, !mnemonic.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.orange)
                        .font(.system(size: 11))
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("MNEMONIC CUE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.orange)
                        Text(mnemonic)
                            .font(.system(size: 12, weight: .medium).italic())
                            .foregroundColor(.primary.opacity(0.9))
                    }
                    Spacer()
                }
                .padding(8)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(6)
            }

            // 3. Prompt To Remember (Active Retrieval Challenge)
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.purple)
                        .font(.system(size: 12))
                    Text("Can you recall the knowledge or flashcard anchored at this locus?")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }

                // Section A: Direct Anchored Knowledge
                if let anchor = locus.anchoredInfo, !anchor.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("ANCHORED KNOWLEDGE", systemImage: "pin.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.cyan)
                            Spacer()

                            if !isAnchorRevealed {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isAnchorRevealed = true
                                    }
                                }) {
                                    Label("Reveal Knowledge", systemImage: "eye.fill")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }

                        if isAnchorRevealed {
                            Text(anchor)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.cyan.opacity(0.12))
                                .cornerRadius(6)

                            HStack(spacing: 8) {
                                Text("Recall Check:")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)

                                Button("✓ Remembered") {}
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .tint(.green)

                                Button("~ Needed Clue") {}
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .tint(.orange)

                                Button("✗ Forgot") {}
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .tint(.red)
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }

                // Section B: Spaced Repetition Flashcard (FSRS)
                if !attachedCards.isEmpty {
                    let currentCard = attachedCards[min(walkCardIndex, attachedCards.count - 1)]

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("FLASHCARD (\(walkCardIndex + 1) OF \(attachedCards.count))", systemImage: "rectangle.on.rectangle.angled")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.accentColor)

                            Spacer()

                            if attachedCards.count > 1 {
                                HStack(spacing: 4) {
                                    Button(action: {
                                        if walkCardIndex > 0 {
                                            walkCardIndex -= 1
                                            isWalkAnswerRevealed = false
                                        }
                                    }) {
                                        Image(systemName: "chevron.left")
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(walkCardIndex <= 0)

                                    Button(action: {
                                        if walkCardIndex < attachedCards.count - 1 {
                                            walkCardIndex += 1
                                            isWalkAnswerRevealed = false
                                        }
                                    }) {
                                        Image(systemName: "chevron.right")
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(walkCardIndex >= attachedCards.count - 1)
                                }
                            }
                        }

                        // Question
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Question:")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(currentCard.front)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                        }

                        // Answer & FSRS Rating
                        if isWalkAnswerRevealed {
                            Divider()
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Answer:")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                Text(currentCard.back)
                                    .font(.system(size: 13))
                                    .foregroundColor(.primary)

                                if let hint = currentCard.hint, !hint.isEmpty {
                                    Text("Hint: \(hint)")
                                        .font(.system(size: 10).italic())
                                        .foregroundColor(.secondary)
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Rate your recall with FSRS:")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)

                                HStack(spacing: 6) {
                                    ForEach(FSRSRating.allCases, id: \.self) { rating in
                                        Button(action: {
                                            _ = store.rateFlashcard(id: currentCard.id, rating: rating)
                                            if walkCardIndex + 1 < attachedCards.count {
                                                walkCardIndex += 1
                                                isWalkAnswerRevealed = false
                                            } else {
                                                advanceWalk(viewportSize: viewportSize)
                                            }
                                        }) {
                                            Text(rating.displayName)
                                                .font(.system(size: 11, weight: .semibold))
                                                .frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        } else {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isWalkAnswerRevealed = true
                                }
                            }) {
                                Label("Reveal Flashcard Answer", systemImage: "lightbulb.fill")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }

                // If neither anchor nor cards exist
                if (locus.anchoredInfo == nil || locus.anchoredInfo!.isEmpty) && attachedCards.isEmpty {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                        Text("No anchored info or flashcard attached yet.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("+ Add Card / Info") {
                            editingLocus = locus
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                }
            }

            // 4. Footer Journey Navigation Bar
            HStack {
                Button(action: {
                    previousWalk(viewportSize: viewportSize)
                }) {
                    Label("Previous Stop", systemImage: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(walkStepIndex <= 0)

                Spacer()

                Button(action: {
                    advanceWalk(viewportSize: viewportSize)
                }) {
                    HStack(spacing: 4) {
                        Text(isLastStep ? "Finish Walk 🎉" : "Next Stop")
                            .font(.system(size: 12, weight: .bold))
                        Image(systemName: isLastStep ? "checkmark" : "chevron.right")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding(16)
        .frame(maxWidth: 580)
        .background(.ultraThickMaterial)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 8)
    }

    // MARK: - Walk Completed View
    private func walkCompletedView(total: Int, viewportSize: CGSize) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 36))
                .foregroundColor(.yellow)

            Text("Palace Walk Complete!")
                .font(.system(size: 18, weight: .bold))

            Text("You visited all \(total) loci in \(currentPalace?.name ?? "this palace").")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button(action: {
                    startWalk()
                }) {
                    Label("Walk Again", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)

                Button(action: {
                    withAnimation {
                        isWalkModeActive = false
                        isWalkCompleted = false
                    }
                }) {
                    Label("Return to Canvas", systemImage: "map")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 6)
        }
        .padding(24)
        .frame(maxWidth: 420)
        .background(.ultraThickMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.4), lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 8)
    }
}

// MARK: - Spatial Photo Node on Vast Canvas
public struct PalacePhotoCardView: View {
    public let photo: PalacePhoto
    public let index: Int
    public let totalPhotos: Int
    @ObservedObject public var store: BlockStore
    public let isWalkModeActive: Bool
    public let walkStepIndex: Int
    public let selectedLocusId: String?
    public let onSelectLocus: (PalaceLocus) -> Void
    public let onAddLocusAt: (Double, Double) -> Void
    public let onMoveEarlier: () -> Void
    public let onMoveLater: () -> Void
    public let onChangeImage: () -> Void
    public let onDeletePhoto: () -> Void

    private var photoLoci: [PalaceLocus] {
        store.loci.filter { locus in
            if let pid = locus.photoId {
                return pid == photo.id
            }
            return store.palacePhotos.first?.id == photo.id
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Card Header Bar
            HStack(spacing: 8) {
                // Sequence Pill
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 20, height: 20)
                    Text("\(index)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }

                Text(photo.name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text("(\(photoLoci.count) pins)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Spacer()

                // Reorder buttons
                HStack(spacing: 2) {
                    Button(action: onMoveEarlier) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 9))
                    }
                    .buttonStyle(.borderless)
                    .disabled(index <= 1)

                    Button(action: onMoveLater) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9))
                    }
                    .buttonStyle(.borderless)
                    .disabled(index >= totalPhotos)
                }

                Button(action: onChangeImage) {
                    Image(systemName: "photo")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .help("Change Photo Image (Safely stored in project)")

                if totalPhotos > 1 {
                    Button(action: onDeletePhoto) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Delete Photo Card")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
            .contentShape(Rectangle())

            Divider()

            // Photo 2D Canvas Image
            ZStack {
                // Photo Background
                photoImageView(path: photo.imagePath, size: CGSize(width: photo.canvasWidth, height: photo.canvasHeight))
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        if !isWalkModeActive {
                            let normX = min(1.0, max(0.0, location.x / photo.canvasWidth))
                            let normY = min(1.0, max(0.0, location.y / photo.canvasHeight))
                            onAddLocusAt(normX, normY)
                        }
                    }

                // Internal Photo Loci Pins
                ForEach(photoLoci) { locus in
                    let sortedAll = store.loci.sorted(by: { $0.orderIndex < $1.orderIndex })
                    let globalIndex = (sortedAll.firstIndex(where: { $0.id == locus.id }) ?? 0) + 1
                    let isCurrentWalk = isWalkModeActive && walkStepIndex < sortedAll.count && sortedAll[walkStepIndex].id == locus.id
                    let isSelected = selectedLocusId == locus.id

                    LocusPinView(
                        index: globalIndex,
                        locus: locus,
                        isHighlighted: isCurrentWalk || isSelected,
                        isWalkTarget: isCurrentWalk
                    )
                    .position(x: locus.normalizedX * photo.canvasWidth, y: locus.normalizedY * photo.canvasHeight)
                    .onTapGesture {
                        onSelectLocus(locus)
                    }
                }
            }
            .frame(width: photo.canvasWidth, height: photo.canvasHeight)
            .clipped()
        }
        .frame(width: photo.canvasWidth)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private func photoImageView(path: String, size: CGSize) -> some View {
        if let nsImage = loadNSImage(from: path) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .clipped()
        } else {
            DefaultBlueprintCanvas(name: photo.name)
                .frame(width: size.width, height: size.height)
        }
    }

    private func loadNSImage(from path: String) -> NSImage? {
        if let resolved = PalaceAssetStorage.resolvePhotoPath(path) {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: resolved)),
               let img = NSImage(data: data) {
                return img
            }
            if let img = NSImage(contentsOfFile: resolved) {
                return img
            }
        }
        if FileManager.default.fileExists(atPath: path) {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let img = NSImage(data: data) {
                return img
            }
            if let img = NSImage(contentsOfFile: path) {
                return img
            }
        }
        if let b64 = photo.imageData,
           let data = Data(base64Encoded: b64),
           let img = NSImage(data: data) {
            return img
        }
        return nil
    }
}

// MARK: - Inter-Photo Connector Curve & Sequence Badge
public struct PhotoConnectorView: View {
    public let from: PalacePhoto
    public let to: PalacePhoto
    public let draggingPhotoId: String?
    public let dragOffset: CGSize
    public let fromIndex: Int
    public let toIndex: Int

    public var body: some View {
        let p1Drag = (draggingPhotoId == from.id) ? dragOffset : .zero
        let p2Drag = (draggingPhotoId == to.id) ? dragOffset : .zero

        let start = CGPoint(
            x: from.canvasX + p1Drag.width + from.canvasWidth,
            y: from.canvasY + p1Drag.height + (from.canvasHeight + 36) / 2
        )
        let end = CGPoint(
            x: to.canvasX + p2Drag.width,
            y: to.canvasY + p2Drag.height + (to.canvasHeight + 36) / 2
        )
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)

        ZStack {
            Path { path in
                path.move(to: start)
                let c1 = CGPoint(x: start.x + max(40, (end.x - start.x) / 2), y: start.y)
                let c2 = CGPoint(x: end.x - max(40, (end.x - start.x) / 2), y: end.y)
                path.addCurve(to: end, control1: c1, control2: c2)
            }
            .stroke(Color.accentColor.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))

            // Sequence Pill Indicator
            HStack(spacing: 3) {
                Text("\(fromIndex)")
                    .font(.system(size: 8, weight: .bold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 7))
                Text("\(toIndex)")
                    .font(.system(size: 8, weight: .bold))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.ultraThinMaterial)
            .cornerRadius(4)
            .position(mid)
        }
    }
}

// MARK: - Vast Blueprint Grid Canvas Background
public struct VastBlueprintGridBackground: View {
    public var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.10, blue: 0.16)

            Canvas { context, size in
                let w = size.width
                let h = size.height
                let gridSpacing: CGFloat = 40

                var gridPath = Path()
                for x in stride(from: 0, to: w, by: gridSpacing) {
                    gridPath.move(to: CGPoint(x: x, y: 0))
                    gridPath.addLine(to: CGPoint(x: x, y: h))
                }
                for y in stride(from: 0, to: h, by: gridSpacing) {
                    gridPath.move(to: CGPoint(x: 0, y: y))
                    gridPath.addLine(to: CGPoint(x: w, y: y))
                }
                context.stroke(gridPath, with: .color(Color.cyan.opacity(0.08)), lineWidth: 0.5)

                // Large Coordinate Quadrants
                var majorGrid = Path()
                for x in stride(from: 0, to: w, by: gridSpacing * 5) {
                    majorGrid.move(to: CGPoint(x: x, y: 0))
                    majorGrid.addLine(to: CGPoint(x: x, y: h))
                }
                for y in stride(from: 0, to: h, by: gridSpacing * 5) {
                    majorGrid.move(to: CGPoint(x: 0, y: y))
                    majorGrid.addLine(to: CGPoint(x: w, y: y))
                }
                context.stroke(majorGrid, with: .color(Color.cyan.opacity(0.18)), lineWidth: 1.0)
            }
        }
    }
}

// MARK: - Locus Pin View on 2D Canvas
public struct LocusPinView: View {
    public let index: Int
    public let locus: PalaceLocus
    public let isHighlighted: Bool
    public let isWalkTarget: Bool

    @State private var isPulsing: Bool = false

    public var body: some View {
        VStack(spacing: 2) {
            ZStack {
                if isWalkTarget {
                    Circle()
                        .stroke(Color.accentColor.opacity(0.8), lineWidth: 3)
                        .frame(width: isPulsing ? 48 : 32, height: isPulsing ? 48 : 32)
                        .scaleEffect(isPulsing ? 1.15 : 0.95)
                        .opacity(isPulsing ? 0.3 : 0.9)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
                        .onAppear { isPulsing = true }

                    Circle()
                        .fill(Color.accentColor.opacity(0.25))
                        .frame(width: 36, height: 36)
                }

                Circle()
                    .fill(isHighlighted ? Color.accentColor : Color(NSColor.windowBackgroundColor))
                    .frame(width: 24, height: 24)
                    .shadow(color: Color.black.opacity(isHighlighted ? 0.5 : 0.3), radius: isHighlighted ? 5 : 3)
                    .overlay(
                        Circle()
                            .stroke(isHighlighted ? Color.white : Color.accentColor, lineWidth: 2)
                    )

                Text("\(index)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isHighlighted ? .white : .primary)
            }

            Text(locus.title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(.ultraThinMaterial)
                .cornerRadius(3)
        }
    }
}

// MARK: - Built-in Blueprint Vector Canvas Fallback
public struct DefaultBlueprintCanvas: View {
    public let name: String

    public var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.12, blue: 0.20)

            Canvas { context, size in
                let w = size.width
                let h = size.height

                var planPath = Path()
                planPath.addRect(CGRect(x: w * 0.1, y: h * 0.1, width: w * 0.8, height: h * 0.8))
                planPath.addEllipse(in: CGRect(x: w * 0.35, y: h * 0.3, width: w * 0.3, height: h * 0.4))
                planPath.addRect(CGRect(x: w * 0.1, y: h * 0.1, width: w * 0.25, height: h * 0.35))
                planPath.addRect(CGRect(x: w * 0.65, y: h * 0.1, width: w * 0.25, height: h * 0.35))
                planPath.addRect(CGRect(x: w * 0.1, y: h * 0.55, width: w * 0.25, height: h * 0.35))
                planPath.addRect(CGRect(x: w * 0.65, y: h * 0.55, width: w * 0.25, height: h * 0.35))

                context.stroke(planPath, with: .color(Color.cyan.opacity(0.6)), lineWidth: 1.5)
            }

            VStack {
                HStack {
                    Text(name.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.7))
                        .padding(12)
                    Spacer()
                }
                Spacer()
            }
        }
    }
}

// MARK: - Locus Detail / Edit Sheet
public struct LocusDetailSheet: View {
    @ObservedObject public var store: BlockStore
    @State public var locus: PalaceLocus
    public let onDismiss: () -> Void

    @State private var selectedExistingCardId: String = ""
    @State private var isCreatingNewCard: Bool = false
    @State private var newCardFront: String = ""
    @State private var newCardBack: String = ""
    @State private var newCardHint: String = ""

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack {
                    Text("Locus Stop Details")
                        .font(.system(size: 15, weight: .bold))
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                // Stop Name
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stop Name / Location")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    TextField("e.g. Grand Colonnade, Fireplace Mantle", text: $locus.title)
                        .textFieldStyle(.roundedBorder)
                }

                // Sequential Photo Assignment
                if !store.palacePhotos.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Photo / Scene on Canvas")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)

                        Picker("", selection: Binding(
                            get: { locus.photoId ?? store.palacePhotos.first?.id ?? "" },
                            set: { locus.photoId = $0 }
                        )) {
                            ForEach(store.palacePhotos) { photo in
                                Text(photo.name).tag(photo.id)
                            }
                        }
                        .labelsHidden()
                    }
                }

                // Mnemonic Imagery
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mnemonic Imagery (Mental Association)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    TextField("e.g. Giant glowing clock balancing on a pillar", text: Binding(
                        get: { locus.mnemonic ?? "" },
                        set: { locus.mnemonic = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                // Direct Anchored Information
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.cyan)
                        Text("Anchor Information Directly (Optional, no flashcard needed)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    TextField("Enter facts, numbers, key notes or concepts anchored to this locus...", text: Binding(
                        get: { locus.anchoredInfo ?? "" },
                        set: { locus.anchoredInfo = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                Divider()

                // Attached Flashcards Section (Multiple Flashcards)
                VStack(alignment: .leading, spacing: 8) {
                    let attachedCards = store.getFlashcards(for: locus.id)

                    HStack {
                        Image(systemName: "rectangle.on.rectangle.angled")
                            .foregroundColor(.accentColor)
                        Text("ATTACHED FLASHCARDS (\(attachedCards.count))")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                    }

                    if attachedCards.isEmpty {
                        Text("No flashcards attached yet. You can anchor information directly above, attach existing cards, or create a new card below.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 2)
                    } else {
                        VStack(spacing: 4) {
                            ForEach(attachedCards) { card in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(card.front)
                                            .font(.system(size: 12, weight: .medium))
                                            .lineLimit(1)
                                        Text(card.back)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Button(action: {
                                        store.detachFlashcard(locusId: locus.id, flashcardId: card.id)
                                    }) {
                                        Image(systemName: "xmark.circle")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Detach Flashcard from this Locus")
                                }
                                .padding(6)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)
                            }
                        }
                    }

                    // Attach Existing Card Dropdown
                    let availableCards = store.flashcards.filter { fc in
                        !attachedCards.contains(where: { $0.id == fc.id })
                    }

                    if !availableCards.isEmpty {
                        HStack(spacing: 8) {
                            Picker("", selection: $selectedExistingCardId) {
                                Text("— Select Existing Flashcard —").tag("")
                                ForEach(availableCards) { c in
                                    Text(c.front).tag(c.id)
                                }
                            }
                            .labelsHidden()

                            Button("Attach") {
                                guard !selectedExistingCardId.isEmpty else { return }
                                store.attachFlashcard(locusId: locus.id, flashcardId: selectedExistingCardId)
                                selectedExistingCardId = ""
                            }
                            .buttonStyle(.bordered)
                            .disabled(selectedExistingCardId.isEmpty)
                        }
                        .padding(.top, 4)
                    }

                    // Create New Flashcard Inline Form
                    VStack(alignment: .leading, spacing: 6) {
                        Button(action: { withAnimation { isCreatingNewCard.toggle() } }) {
                            HStack(spacing: 4) {
                                Image(systemName: isCreatingNewCard ? "chevron.down" : "chevron.right")
                                Image(systemName: "plus.circle.fill")
                                Text("Create New Flashcard Inline")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)

                        if isCreatingNewCard {
                            VStack(alignment: .leading, spacing: 6) {
                                TextField("Flashcard Front / Question", text: $newCardFront)
                                    .textFieldStyle(.roundedBorder)
                                TextField("Flashcard Back / Answer", text: $newCardBack)
                                    .textFieldStyle(.roundedBorder)
                                TextField("Hint (Optional)", text: $newCardHint)
                                    .textFieldStyle(.roundedBorder)

                                HStack {
                                    Spacer()
                                    Button("Save & Attach Flashcard") {
                                        guard !newCardFront.isEmpty, !newCardBack.isEmpty else { return }
                                        _ = store.createAndAttachFlashcard(
                                            locusId: locus.id,
                                            front: newCardFront,
                                            back: newCardBack,
                                            hint: newCardHint.isEmpty ? nil : newCardHint
                                        )
                                        newCardFront = ""
                                        newCardBack = ""
                                        newCardHint = ""
                                        isCreatingNewCard = false
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    .disabled(newCardFront.trimmingCharacters(in: .whitespaces).isEmpty || newCardBack.trimmingCharacters(in: .whitespaces).isEmpty)
                                }
                            }
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(6)
                        }
                    }
                    .padding(.top, 4)
                }

                Divider()

                // Actions Footer
                HStack {
                    Button(role: .destructive, action: {
                        store.deleteLocus(id: locus.id)
                        onDismiss()
                    }) {
                        Text("Delete Pin")
                    }

                    Spacer()

                    Button("Save Locus") {
                        store.updateLocus(locus)
                        onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .frame(width: 480, height: 560)
    }
}

// MARK: - Add Photo Sheet (Safely Copies Photo to Project Directory)
public struct AddPhotoSheet: View {
    @ObservedObject public var store: BlockStore
    @Binding public var isPresented: Bool
    public var onPhotoAdded: ((PalacePhoto) -> Void)? = nil

    @State private var name: String = ""
    @State private var imagePath: String = "bundled:default"
    @State private var previewImage: NSImage? = nil

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add Photo / Scene to Canvas")
                .font(.system(size: 15, weight: .bold))

            VStack(alignment: .leading, spacing: 4) {
                Text("Scene / Room Name")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("e.g. Living Room, Courtyard, Study, Master Balcony", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("2D Photo Image (Safely Copied into Project)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack {
                    Text(imagePath)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Browse Image...") {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [.png, .jpeg, .heic, .webP, .image]
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = false
                        panel.canChooseFiles = true
                        panel.prompt = "Select Photo / Scene"
                        if panel.runModal() == .OK, let url = panel.url {
                            let hasAccess = url.startAccessingSecurityScopedResource()
                            defer {
                                if hasAccess {
                                    url.stopAccessingSecurityScopedResource()
                                }
                            }
                            do {
                                // Safely copy into project folder so deleting original file doesn't break palace
                                let safePath = try PalaceAssetStorage.importPhoto(from: url)
                                imagePath = safePath
                                if let data = try? Data(contentsOf: URL(fileURLWithPath: safePath)),
                                   let img = NSImage(data: data) {
                                    previewImage = img
                                } else {
                                    previewImage = NSImage(contentsOfFile: safePath)
                                }
                            } catch {
                                imagePath = url.path
                                previewImage = NSImage(contentsOfFile: url.path)
                            }
                            if name.trimmingCharacters(in: .whitespaces).isEmpty {
                                let raw = url.deletingPathExtension().lastPathComponent
                                    .replacingOccurrences(of: "_", with: " ")
                                    .replacingOccurrences(of: "-", with: " ")
                                name = raw.capitalized
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            // Real-Time Thumbnail Preview
            if let img = previewImage {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected Image Preview")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .clipped()
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                        )
                }
            }

            HStack {
                Button("Cancel") { isPresented = false }
                Spacer()
                Button("Add to Canvas") {
                    guard let palaceId = store.selectedPalaceId else { return }
                    let newPhoto = store.addPalacePhoto(
                        palaceId: palaceId,
                        name: name,
                        imagePath: imagePath
                    )
                    isPresented = false
                    onPhotoAdded?(newPhoto)
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 440)
    }
}

// MARK: - Add Palace Sheet
public struct AddPalaceSheet: View {
    @ObservedObject public var store: BlockStore
    @Binding public var isPresented: Bool

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var imagePath: String = "bundled:default"

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Create Memory Palace")
                .font(.system(size: 15, weight: .bold))

            VStack(alignment: .leading, spacing: 4) {
                Text("Palace Name")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("e.g. Childhood Home, Modern Loft, University Library", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Description / Journey Theme")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("e.g. Sequential walk from front porch through study", text: $description)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel") { isPresented = false }
                Spacer()
                Button("Create Palace") {
                    store.createMemoryPalace(
                        name: name,
                        imagePath: imagePath,
                        description: description.isEmpty ? nil : description
                    )
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 400)
    }
}
