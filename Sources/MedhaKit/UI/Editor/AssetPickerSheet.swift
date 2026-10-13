import SwiftUI
import AppKit

public enum AssetPickerMode {
    case cover
    case icon
}

public struct AssetPickerSheet: View {
    @ObservedObject public var store: BlockStore
    public let docId: String
    public let mode: AssetPickerMode
    public let onDismiss: () -> Void

    @State private var selectedTab: String
    @State private var searchQuery: String = ""
    @State private var searchResults: [AssetSearchResult] = []
    @State private var isSearching: Bool = false
    @State private var iconSearchQuery: String = ""
    @State private var iconSearchResults: [AssetSearchResult] = []
    @State private var isSearchingIcons: Bool = false
    @State private var customUrlText: String = ""
    @State private var selectedCategory: AssetPresetCategory = .ghibli

    public init(
        store: BlockStore,
        docId: String,
        mode: AssetPickerMode,
        onDismiss: @escaping () -> Void
    ) {
        self.store = store
        self.docId = docId
        self.mode = mode
        self.onDismiss = onDismiss
        self._selectedTab = State(initialValue: mode == .icon ? "icons" : "presets")
    }

    private let availableIcons: [String] = [
        "doc.text", "brain.head.profile", "lightbulb.fill", "sparkles", "folder.fill",
        "star.fill", "bookmark.fill", "tag.fill", "checklist", "terminal.fill",
        "cube.fill", "flame.fill", "graduationcap.fill", "books.vertical.fill",
        "moon.stars.fill", "sun.max.fill", "cloud.rain.fill", "heart.fill", "bolt.fill",
        "atom", "waveform.path.ecg", "laptopcomputer", "music.note", "paintpalette.fill"
    ]

    private let availableEmojis: [String] = [
        "🌿", "☕", "📖", "✨", "🏮", "🌧️", "🌌", "💻", "📚", "🎨", "🎧", "🪴",
        "🌙", "⭐", "🏯", "⛩️", "🍙", "🍵", "🕯️", "🧭", "🐈‍⬛", "🌸", "🍁", "🪵"
    ]

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(mode == .cover ? "Choose Page Cover" : "Choose Page Icon")
                    .font(.headline)
                    .foregroundColor(MedhaTheme.Colors.textPrimary)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Tabs
            HStack(spacing: 8) {
                if mode == .cover {
                    pickerTabButton(title: "Gallery Presets", icon: "photo.stack", tab: "presets")
                    pickerTabButton(title: "Free Photos & Art", icon: "camera.fill", tab: "unsplash")
                    pickerTabButton(title: "GIPHY", icon: "play.rectangle.fill", tab: "giphy")
                    pickerTabButton(title: "Upload", icon: "arrow.up.circle.fill", tab: "upload")
                    pickerTabButton(title: "Link", icon: "link", tab: "link")
                } else {
                    pickerTabButton(title: "Icons & Emojis", icon: "face.smiling", tab: "icons")
                    pickerTabButton(title: "Upload", icon: "arrow.up.circle.fill", tab: "upload")
                    pickerTabButton(title: "Link", icon: "link", tab: "link")
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider()

            // Tab Content
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedTab {
                    case "presets":
                        presetsView
                    case "unsplash":
                        unsplashSearchView
                    case "giphy":
                        giphySearchView
                    case "upload":
                        uploadView
                    case "link":
                        linkInputView
                    case "icons":
                        iconsAndEmojisView
                    default:
                        EmptyView()
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 580, height: 440)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func pickerTabButton(title: String, icon: String, tab: String) -> some View {
        Button(action: {
            selectedTab = tab
            if tab == "unsplash" && searchResults.isEmpty {
                executeUnsplashSearch("study aesthetic")
            } else if tab == "giphy" && searchResults.isEmpty {
                executeGiphySearch("ghibli")
            }
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
            .foregroundColor(selectedTab == tab ? .accentColor : .primary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Presets Tab
    private var presetsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Category selector
            HStack(spacing: 8) {
                ForEach(AssetPresetCategory.allCases) { cat in
                    Button(action: { selectedCategory = cat }) {
                        HStack(spacing: 4) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 10))
                            Text(cat.rawValue)
                                .font(.system(size: 11, weight: selectedCategory == cat ? .semibold : .regular))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(selectedCategory == cat ? Color.accentColor.opacity(0.2) : Color(NSColor.controlBackgroundColor))
                        .foregroundColor(selectedCategory == cat ? .accentColor : .secondary)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Presets Grid
            let items = AssetCacheService.shared.curatedPresets.filter { $0.category == selectedCategory }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(items) { item in
                    Button(action: {
                        selectAsset(url: item.url)
                    }) {
                        ZStack(alignment: .bottomLeading) {
                            AsyncImage(url: URL(string: item.url)) { phase in
                                switch phase {
                                case .empty:
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.15))
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .failure:
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.2))
                                        .overlay(Image(systemName: "photo").foregroundColor(.secondary))
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .frame(height: 105)
                            .clipped()
                            .cornerRadius(6)

                            LinearGradient(
                                colors: [.black.opacity(0.7), .clear],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                            .frame(height: 40)
                            .cornerRadius(6)

                            Text(item.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(8)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Unsplash Tab
    private var unsplashSearchView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search photos (e.g. coffee, rainy library, mountain)...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        executeUnsplashSearch(searchQuery)
                    }
                if isSearching {
                    ProgressView().scaleEffect(0.6)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(searchResults) { item in
                    Button(action: {
                        selectAsset(url: item.downloadUrl)
                    }) {
                        ZStack(alignment: .bottomLeading) {
                            AsyncImage(url: URL(string: item.previewUrl)) { phase in
                                if let img = phase.image {
                                    img.resizable().scaledToFill()
                                } else {
                                    Rectangle().fill(Color.secondary.opacity(0.15))
                                }
                            }
                            .frame(height: 105)
                            .clipped()
                            .cornerRadius(6)

                            LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .bottom, endPoint: .top)
                                .frame(height: 36)
                                .cornerRadius(6)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.title)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                if let author = item.author {
                                    Text("By \(author)")
                                        .font(.system(size: 8))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .padding(6)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Giphy Animated GIF Tab
    private var giphySearchView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search GIFs (e.g. ghibli, anime study, pixel rain)...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        executeGiphySearch(searchQuery)
                    }
                if isSearching {
                    ProgressView().scaleEffect(0.6)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(searchResults) { item in
                    Button(action: {
                        selectAsset(url: item.downloadUrl)
                    }) {
                        ZStack(alignment: .bottomLeading) {
                            AsyncImage(url: URL(string: item.previewUrl)) { phase in
                                if let img = phase.image {
                                    img.resizable().scaledToFill()
                                } else {
                                    Rectangle().fill(Color.secondary.opacity(0.15))
                                }
                            }
                            .frame(height: 105)
                            .clipped()
                            .cornerRadius(6)

                            LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .bottom, endPoint: .top)
                                .frame(height: 36)
                                .cornerRadius(6)

                            HStack {
                                Text(item.title)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Spacer()
                                Text("GIF")
                                    .font(.system(size: 8, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.purple)
                                    .foregroundColor(.white)
                                    .cornerRadius(3)
                            }
                            .padding(6)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Upload Tab
    private var uploadView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
                .padding(.top, 24)

            VStack(spacing: 4) {
                Text("Upload Image or Animated GIF")
                    .font(.headline)
                Text("Select any PNG, JPEG, GIF, or WebP file from your Mac.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button(action: handleLocalFileUpload) {
                HStack {
                    Image(systemName: "folder")
                    Text("Choose Local File...")
                }
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Link Tab
    private var linkInputView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Paste Image or GIF URL")
                .font(.headline)

            HStack {
                TextField("https://...", text: $customUrlText)
                    .textFieldStyle(.roundedBorder)

                Button("Submit") {
                    if !customUrlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        selectAsset(url: customUrlText.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
                .disabled(customUrlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Text("Works with any direct image link (.png, .jpg, .gif, .webp). The image will be downloaded and safely stored for offline use.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Icons and Emojis Tab
    private var iconsAndEmojisView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Live Online Vector Icon Search (Iconify API)
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search free vector icons (e.g. book, brain, atom, code, calendar)...", text: $iconSearchQuery)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        executeIconifySearch(iconSearchQuery)
                    }
                if isSearchingIcons {
                    ProgressView().scaleEffect(0.6)
                } else if !iconSearchQuery.isEmpty {
                    Button(action: {
                        executeIconifySearch(iconSearchQuery)
                    }) {
                        Text("Search")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)

            if !iconSearchResults.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Online Vector Icons")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(iconSearchResults.count) found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                        ForEach(iconSearchResults) { item in
                            Button(action: {
                                selectAsset(url: item.downloadUrl)
                            }) {
                                VStack(spacing: 4) {
                                    AsyncImage(url: URL(string: item.previewUrl)) { phase in
                                        if let img = phase.image {
                                            img.resizable().scaledToFit()
                                        } else {
                                            Image(systemName: "sparkles")
                                                .font(.system(size: 16))
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                    .frame(width: 24, height: 24)

                                    Text(item.title)
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                .frame(width: 76, height: 58)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider()
            }

            Text("Emojis")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                ForEach(availableEmojis, id: \.self) { emoji in
                    Button(action: {
                        store.setDocumentIcon(docId: docId, icon: emoji)
                        onDismiss()
                    }) {
                        Text(emoji)
                            .font(.system(size: 24))
                            .frame(width: 44, height: 44)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            Text("SF Symbols")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                ForEach(availableIcons, id: \.self) { icon in
                    Button(action: {
                        store.setDocumentIcon(docId: docId, icon: icon)
                        onDismiss()
                    }) {
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Actions
    private func executeIconifySearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSearchingIcons = true
        Task {
            let results = await AssetCacheService.shared.searchIconify(query: trimmed)
            await MainActor.run {
                self.iconSearchResults = results
                self.isSearchingIcons = false
            }
        }
    }

    private func executeUnsplashSearch(_ query: String) {
        isSearching = true
        Task {
            let results = await AssetCacheService.shared.searchUnsplash(query: query)
            await MainActor.run {
                self.searchResults = results
                self.isSearching = false
            }
        }
    }

    private func executeGiphySearch(_ query: String) {
        isSearching = true
        Task {
            let results = await AssetCacheService.shared.searchGiphy(query: query)
            await MainActor.run {
                self.searchResults = results
                self.isSearching = false
            }
        }
    }

    private func selectAsset(url: String) {
        Task {
            // Download & Cache locally in background for full offline reliability
            var resolvedLocalUrl = url
            if let cached = try? await AssetCacheService.shared.downloadAndCache(sourceUrlString: url) {
                resolvedLocalUrl = cached.absoluteString
            }
            await MainActor.run {
                if mode == .cover {
                    store.setDocumentCover(docId: docId, coverUrl: resolvedLocalUrl, coverY: 0.5)
                } else {
                    store.setDocumentIcon(docId: docId, icon: resolvedLocalUrl)
                }
                onDismiss()
            }
        }
    }

    private func handleLocalFileUpload() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image, .png, .jpeg, .gif]

        if panel.runModal() == .OK, let selectedURL = panel.url {
            if let dest = try? AssetCacheService.shared.importLocalFile(from: selectedURL) {
                if mode == .cover {
                    store.setDocumentCover(docId: docId, coverUrl: dest.absoluteString, coverY: 0.5)
                } else {
                    store.setDocumentIcon(docId: docId, icon: dest.absoluteString)
                }
                onDismiss()
            }
        }
    }
}
