import SwiftUI
import AppKit

/// Renders an image with occlusion mask rectangles drawn over it.
/// Supports interactive drawing/selection for editor, and study mode masking (active/inactive masks, reveal state).
public struct ImageOcclusionCanvasView: View {
    public let image: NSImage
    public let masks: [ImageOcclusionMask]
    public var activeMaskId: String? = nil
    public var mode: OcclusionMode = .hideAllRevealOne
    public var isAnswerRevealed: Bool = false
    public var isEditable: Bool = false
    public var selectedMaskId: String? = nil

    // Editing callbacks
    public var onSelectMask: ((ImageOcclusionMask) -> Void)? = nil
    public var onAddMask: ((CGRect) -> Void)? = nil
    public var onDeleteMask: ((String) -> Void)? = nil

    @State private var dragStart: CGPoint? = nil
    @State private var currentDragRect: CGRect? = nil

    public init(
        image: NSImage,
        masks: [ImageOcclusionMask],
        activeMaskId: String? = nil,
        mode: OcclusionMode = .hideAllRevealOne,
        isAnswerRevealed: Bool = false,
        isEditable: Bool = false,
        selectedMaskId: String? = nil,
        onSelectMask: ((ImageOcclusionMask) -> Void)? = nil,
        onAddMask: ((CGRect) -> Void)? = nil,
        onDeleteMask: ((String) -> Void)? = nil
    ) {
        self.image = image
        self.masks = masks
        self.activeMaskId = activeMaskId
        self.mode = mode
        self.isAnswerRevealed = isAnswerRevealed
        self.isEditable = isEditable
        self.selectedMaskId = selectedMaskId
        self.onSelectMask = onSelectMask
        self.onAddMask = onAddMask
        self.onDeleteMask = onDeleteMask
    }

    public var body: some View {
        GeometryReader { geo in
            let aspectFitSize = calculateAspectFitSize(containerSize: geo.size, imageSize: image.size)
            let originX = (geo.size.width - aspectFitSize.width) / 2
            let originY = (geo.size.height - aspectFitSize.height) / 2

            ZStack(alignment: .topLeading) {
                // Background image
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: aspectFitSize.width, height: aspectFitSize.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                // Masks Overlay container exactly aligned with image frame
                ZStack(alignment: .topLeading) {
                    ForEach(masks) { mask in
                        let maskRect = rectForMask(mask, in: aspectFitSize)
                        let isActive = (mask.id == activeMaskId)
                        let isSelected = (mask.id == selectedMaskId)

                        renderMaskBox(
                            mask: mask,
                            rect: maskRect,
                            isActive: isActive,
                            isSelected: isSelected
                        )
                    }

                    // Temporary drag rectangle while user is drawing a new mask
                    if isEditable, let current = currentDragRect {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(MedhaTheme.Colors.accent.opacity(0.35))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(MedhaTheme.Colors.accent, style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                            )
                            .frame(width: current.width, height: current.height)
                            .offset(x: current.minX, y: current.minY)
                    }
                }
                .frame(width: aspectFitSize.width, height: aspectFitSize.height)
                .offset(x: originX, y: originY)
                .contentShape(Rectangle())
                .gesture(isEditable ? drawGesture(in: aspectFitSize) : nil)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: - Mask Rendering
    @ViewBuilder
    private func renderMaskBox(
        mask: ImageOcclusionMask,
        rect: CGRect,
        isActive: Bool,
        isSelected: Bool
    ) -> some View {
        if isEditable {
            // Editor mode
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? MedhaTheme.Colors.accent.opacity(0.4) : Color.orange.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(isSelected ? MedhaTheme.Colors.accent : Color.orange, lineWidth: isSelected ? 2.5 : 1.5)
                    )

                if let label = mask.label, !label.isEmpty {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .lineLimit(1)
                } else {
                    Text("\(mask.orderIndex + 1)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(3)
                        .background(Color.black.opacity(0.65))
                        .clipShape(Circle())
                }
            }
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
            .onTapGesture {
                onSelectMask?(mask)
            }
        } else {
            // Study Session Mode
            let shouldHide: Bool = {
                if mode == .hideOneRevealOne {
                    // Hide ONLY the active mask
                    return isActive && !isAnswerRevealed
                } else {
                    // Hide ALL masks; if answer revealed, un-occlude ONLY active mask
                    if isActive {
                        return !isAnswerRevealed
                    } else {
                        return true // Other masks remain covered
                    }
                }
            }()

            let isRevealedActive = isActive && isAnswerRevealed

            if shouldHide {
                // Occlusion covering box
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isActive ? MedhaTheme.Colors.accent.opacity(0.92) : Color.gray.opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isActive ? Color.white.opacity(0.8) : Color.clear, lineWidth: isActive ? 2 : 0)
                        )
                        .shadow(color: isActive ? MedhaTheme.Colors.accent.opacity(0.5) : Color.black.opacity(0.2), radius: isActive ? 6 : 2)

                    if isActive {
                        Image(systemName: "questionmark")
                            .font(.system(size: max(10, min(rect.height * 0.5, 18)), weight: .bold))
                            .foregroundColor(.white)
                    } else if mode == .hideAllRevealOne {
                        Image(systemName: "lock.fill")
                            .font(.system(size: max(8, min(rect.height * 0.4, 12)), weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isAnswerRevealed)
            } else if isRevealedActive {
                // Answer revealed for the active mask! Show distinctive green border & label
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(MedhaTheme.Colors.ratingEasy, lineWidth: 2.5)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(MedhaTheme.Colors.ratingEasy.opacity(0.18))
                        )

                    if let label = mask.label, !label.isEmpty {
                        Text(label)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(MedhaTheme.Colors.textPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(MedhaTheme.Colors.bgSurface.opacity(0.95))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(MedhaTheme.Colors.ratingEasy.opacity(0.7), lineWidth: 1)
                            )
                            .shadow(radius: 3)
                    }
                }
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Drag Gesture for Drawing Masks
    private func drawGesture(in containerSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let start = value.startLocation
                let current = value.location

                let minX = max(0, min(start.x, current.x))
                let minY = max(0, min(start.y, current.y))
                let maxX = min(containerSize.width, max(start.x, current.x))
                let maxY = min(containerSize.height, max(start.y, current.y))

                self.currentDragRect = CGRect(x: minX, y: minY, width: max(10, maxX - minX), height: max(10, maxY - minY))
            }
            .onEnded { value in
                guard let rect = currentDragRect, rect.width >= 12, rect.height >= 12 else {
                    currentDragRect = nil
                    return
                }

                // Convert to normalized coordinates (0.0 ... 1.0)
                let normX = rect.minX / containerSize.width
                let normY = rect.minY / containerSize.height
                let normW = rect.width / containerSize.width
                let normH = rect.height / containerSize.height

                let normalizedRect = CGRect(x: normX, y: normY, width: normW, height: normH)
                onAddMask?(normalizedRect)
                currentDragRect = nil
            }
    }

    // MARK: - Geometry Helpers
    private func rectForMask(_ mask: ImageOcclusionMask, in containerSize: CGSize) -> CGRect {
        CGRect(
            x: mask.x * containerSize.width,
            y: mask.y * containerSize.height,
            width: mask.width * containerSize.width,
            height: mask.height * containerSize.height
        )
    }

    private func calculateAspectFitSize(containerSize: CGSize, imageSize: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return containerSize }
        let widthRatio = containerSize.width / imageSize.width
        let heightRatio = containerSize.height / imageSize.height
        let scale = min(widthRatio, heightRatio)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }
}
