import SwiftUI
import AppKit
import MedhaKit

@main
struct MedhaApp: App {
    @StateObject private var store = BlockStore()

    var body: some Scene {
        WindowGroup {
            MainSplitView(store: store)
                .frame(minWidth: 860, minHeight: 540)
                .navigationTitle("Medha — Block PKM")
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    store.createDocument()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Notebook...") {
                    store.createNotebook(name: "New Notebook")
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandGroup(after: .textEditing) {
                Button("Command Palette...") {
                    store.isCommandPalettePresented.toggle()
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("Toggle Inspector") {
                    store.isInspectorPresented.toggle()
                }
                .keyboardShortcut("i", modifiers: .command)

                Button("Knowledge Graph") {
                    store.activeMainView = (store.activeMainView == .graph ? .editor : .graph)
                }
                .keyboardShortcut("g", modifiers: .command)
            }
        }
    }
}
