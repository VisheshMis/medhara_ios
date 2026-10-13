import SwiftUI
import AppKit

public struct PageCoverHeaderView: View {
    @ObservedObject public var store: BlockStore
    public let doc: Block

    @State private var isHoveringCover: Bool = false
    @State private var isHoveringHeader: Bool = false
    @State private var isRepositioning: Bool = false
    @State private var tempCoverY: Double = 0.5
    @State private var dragInitialY: Double = 0.5
    @State private var isAssetPickerPresented: Bool = false
    @State private var assetPickerMode: AssetPickerMode = .cover

    private let bannerHeight: CGFloat = 200

    private func resolveURL(_ str: String) -> URL? {
        if str.hasPrefix("/") {
            return URL(fileURLWithPath: str)
        }
        return URL(string: str)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let coverUrl = doc.coverUrl, !coverUrl.isEmpty {
                // Cover Banner with Repositioning & Hover Controls
                ZStack(alignment: .bottomTrailing) {
                    GeometryReader { geo in
                        let yOffset = isRepositioning ? tempCoverY : (doc.coverY ?? 0.5)
                        
                        // We translate the image vertically inside the clipped container based on yOffset (0.0 ... 1.0)
                        AsyncImage(url: resolveURL(coverUrl)) { phase in
                            switch phase {
                            case .empty:
                                Rectangle()
                                    .fill(LinearGradient(
                                        colors: [Color.accentColor.opacity(0.3), Color.purple.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: bannerHeight * 1.8)
                                    .offset(y: -(bannerHeight * 0.8) * CGFloat(yOffset))
                            case .failure:
                                Rectangle()
                                    .fill(Color(NSColor.controlBackgroundColor))
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 32))
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: geo.size.width, height: bannerHeight)
                        .clipped()
                        .contentShape(Rectangle())
                        .gesture(
                            isRepositioning ?
                            DragGesture()
                                .onChanged { value in
                                    let delta = Double(value.translation.height / (bannerHeight * 0.8))
                                    tempCoverY = max(0.0, min(1.0, dragInitialY - delta))
                                }
                                .onEnded { _ in
                                    dragInitialY = tempCoverY
                                }
                            : nil
                        )
                    }
                    .frame(height: bannerHeight)

                    // Repositioning Mode Overlay
                    if isRepositioning {
                        VStack {
                            HStack {
                                Spacer()
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                                        .font(.system(size: 11))
                                    Text("Drag image to reposition")
                                        .font(.system(size: 11, weight: .medium))

                                    Button("Save") {
                                        store.setDocumentCoverY(docId: doc.id, coverY: tempCoverY)
                                        isRepositioning = false
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)

                                    Button("Cancel") {
                                        tempCoverY = doc.coverY ?? 0.5
                                        isRepositioning = false
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                                .shadow(radius: 4)
                                Spacer()
                            }
                            .padding(.top, 12)
                            Spacer()
                        }
                    }

                    // Hover Actions Toolbar (Change cover, Reposition, Remove)
                    if isHoveringCover && !isRepositioning {
                        HStack(spacing: 6) {
                            Button(action: {
                                assetPickerMode = .cover
                                isAssetPickerPresented = true
                            }) {
                                Label("Change cover", systemImage: "photo")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial)
                            .cornerRadius(6)

                            Button(action: {
                                tempCoverY = doc.coverY ?? 0.5
                                dragInitialY = tempCoverY
                                isRepositioning = true
                            }) {
                                Label("Reposition", systemImage: "arrow.up.and.down")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial)
                            .cornerRadius(6)

                            Button(action: {
                                store.setDocumentCover(docId: doc.id, coverUrl: nil, coverY: nil)
                            }) {
                                Label("Remove", systemImage: "trash")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial)
                            .cornerRadius(6)
                        }
                        .padding(12)
                    }
                }
                .onHover { isHoveringCover = $0 }

                // Floating Icon overlapping bottom of cover banner
                HStack(alignment: .bottom) {
                    floatingIconBadge(doc: doc, isOverCover: true)
                        .offset(y: -24)
                    Spacer()
                }
                .padding(.horizontal, 2)
            } else {
                // No cover: Clean Notion action bar above the title
                HStack(spacing: 10) {
                    if doc.icon != nil {
                        floatingIconBadge(doc: doc, isOverCover: false)
                    }

                    HStack(spacing: 8) {
                        if doc.icon == nil {
                            Button(action: {
                                assetPickerMode = .icon
                                isAssetPickerPresented = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "face.smiling")
                                        .font(.system(size: 11))
                                    Text("Add icon")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundColor(isHoveringHeader ? MedhaTheme.Colors.textPrimary : MedhaTheme.Colors.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(MedhaTheme.Colors.bgSurface)
                                .cornerRadius(5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(MedhaTheme.Colors.borderHairline, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        Button(action: {
                            assetPickerMode = .cover
                            isAssetPickerPresented = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "photo")
                                    .font(.system(size: 11))
                                Text("Add cover")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(isHoveringHeader ? MedhaTheme.Colors.textPrimary : MedhaTheme.Colors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(MedhaTheme.Colors.bgSurface)
                            .cornerRadius(5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(MedhaTheme.Colors.borderHairline, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onHover { isHoveringHeader = $0 }
            }
        }
        .sheet(isPresented: $isAssetPickerPresented) {
            AssetPickerSheet(
                store: store,
                docId: doc.id,
                mode: assetPickerMode,
                onDismiss: { isAssetPickerPresented = false }
            )
        }
    }

    // MARK: - Floating Icon Badge
    @ViewBuilder
    private func floatingIconBadge(doc: Block, isOverCover: Bool) -> some View {
        Menu {
            Button(action: {
                assetPickerMode = .icon
                isAssetPickerPresented = true
            }) {
                Label("Change icon", systemImage: "pencil")
            }

            if doc.icon != nil {
                Button(role: .destructive, action: {
                    store.setDocumentIcon(docId: doc.id, icon: nil)
                }) {
                    Label("Remove icon", systemImage: "trash")
                }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .frame(width: isOverCover ? 56 : 46, height: isOverCover ? 56 : 46)
                    .shadow(color: .black.opacity(isOverCover ? 0.25 : 0.08), radius: isOverCover ? 5 : 2, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                if let icon = doc.icon, !icon.isEmpty {
                    if icon.hasPrefix("http") || icon.hasPrefix("file://") || icon.hasPrefix("/") {
                        AsyncImage(url: resolveURL(icon)) { phase in
                            if let img = phase.image {
                                img.resizable().scaledToFit()
                            } else {
                                Image(systemName: "photo")
                            }
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else if icon.count <= 3 && icon.unicodeScalars.first?.properties.isEmoji == true {
                        Text(icon)
                            .font(.system(size: isOverCover ? 30 : 26))
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: isOverCover ? 24 : 20))
                            .foregroundColor(.primary)
                    }
                } else {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary)
                }
            }
        }
        .menuStyle(.borderlessButton)
        .frame(width: isOverCover ? 56 : 46, height: isOverCover ? 56 : 46)
    }
}
