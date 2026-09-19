import SwiftUI

public struct MainSplitView: View {
    @ObservedObject public var store: BlockStore
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    public init(store: BlockStore) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            NavigationSplitView {
                SidebarView(store: store)
                    .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 270)
            } detail: {
                switch store.activeMainView {
                case .editor:
                    HStack(spacing: 0) {
                        if store.isDocumentTreeVisible {
                            DocumentTreeView(store: store)
                                .frame(minWidth: 220, idealWidth: 260, maxWidth: 340)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                            Divider()
                        }

                        BlockEditorView(store: store)

                        if store.isNotesAIAssistantPresented {
                            Divider()
                            NotesAIAssistantView(store: store)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }

                        if store.isInspectorPresented {
                            Divider()
                            InspectorView(store: store)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                case .flashcards:
                    FlashcardManagerView(store: store)
                case .palace:
                    MemoryPalaceView(store: store)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    TopLeftTimerView(timerManager: store.timerManager)
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    if store.activeMainView == .editor {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                store.toggleDocumentTree()
                            }
                        }) {
                            Label("Notes Tab", systemImage: "sidebar.left")
                        }
                        .help(store.isDocumentTreeVisible ? "Hide Notes & Folders Tab" : "Show Notes & Folders Tab")

                        Button(action: {
                            store.createDocument()
                        }) {
                            Label("New Note", systemImage: "plus")
                        }
                        .help("New Note (⌘N)")

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                store.toggleNotesAIAssistant()
                            }
                        }) {
                            Label("AI Assistant", systemImage: "sparkles")
                        }
                        .help("Toggle AI Notes Assistant")
                        .foregroundColor(store.isNotesAIAssistantPresented ? .purple : .primary)
                    }

                    Button(action: {
                        store.isCommandPalettePresented = true
                    }) {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .help("Spotlight Search (⌘K)")

                    if store.activeMainView == .editor {
                        Menu {
                            Button("Copy as Markdown") {
                                let md = store.exportCurrentAsMarkdown()
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(md, forType: .string)
                            }
                            Button("Copy as JSON") {
                                let json = store.exportCurrentAsJSON()
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(json, forType: .string)
                            }
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .help("Export Document (⌘E)")

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                store.isInspectorPresented.toggle()
                            }
                        }) {
                            Label("Inspector", systemImage: "sidebar.right")
                        }
                        .help("Toggle Inspector (⌘I)")
                    }
                }
            }

            // Command Palette Modal Overlay (⌘K)
            if store.isCommandPalettePresented {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture {
                        store.isCommandPalettePresented = false
                    }

                CommandPaletteView(store: store, isPresented: $store.isCommandPalettePresented)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }

            // Block Reference Picker Modal Overlay
            if store.isBlockPickerPresented {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture {
                        store.isBlockPickerPresented = false
                    }

                BlockPickerView(store: store, isPresented: $store.isBlockPickerPresented)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: store.isCommandPalettePresented)
        .animation(.easeInOut(duration: 0.15), value: store.isBlockPickerPresented)
    }
}
