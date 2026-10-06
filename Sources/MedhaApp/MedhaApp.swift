import SwiftUI
import AppKit
import MedhaKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate()
        ensureMainWindowVisible()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.ensureMainWindowVisible()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.ensureMainWindowVisible()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Exit cleanly when main window is closed so subsequent double-clicks launch fresh
        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate()

        if let window = sender.windows.first(where: { $0.canBecomeMain && !($0 is NSPanel) }) {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            Self.positionWindowOnActiveScreen(window)
            return true
        }

        // If no visible window exists, return true to instruct SwiftUI to recreate the WindowGroup
        return true
    }

    func ensureMainWindowVisible() {
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate()

        for window in NSApp.windows where window.canBecomeMain && !(window is NSPanel) {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            Self.positionWindowOnActiveScreen(window)
        }
    }

    static func positionWindowOnActiveScreen(_ window: NSWindow) {
        if window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }

        // Find the active screen where the user mouse pointer is currently located
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        if let screen = targetScreen {
            let screenVisible = screen.visibleFrame
            let minW: CGFloat = 1000
            let minH: CGFloat = 650
            let w = min(max(window.frame.width > 200 ? window.frame.width : 1100, minW), screenVisible.width - 40)
            let h = min(max(window.frame.height > 200 ? window.frame.height : 800, minH), screenVisible.height - 40)
            let x = screenVisible.minX + (screenVisible.width - w) / 2
            let y = screenVisible.minY + (screenVisible.height - h) / 2
            window.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
        }

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}

// WindowAccessor attaches to the SwiftUI view hierarchy to ensure the NSWindow is immediately configured and visible
struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isReleasedWhenClosed = false
            AppDelegate.positionWindowOnActiveScreen(window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                AppDelegate.positionWindowOnActiveScreen(window)
            }
        }
    }
}

@main
struct MedhaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    @StateObject private var store = BlockStore()

    init() {
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        UserDefaults.standard.set(false, forKey: "NSWindowRestoration")

        // Purge any corrupted split view divider frames or offscreen window frames that cause window disappearances
        let keys = UserDefaults.standard.dictionaryRepresentation().keys
        for key in keys where key.hasPrefix("NSSplitView Subview Frames") || key.hasPrefix("NSWindow Frame") {
            UserDefaults.standard.removeObject(forKey: key)
        }
        UserDefaults.standard.synchronize()

        // Set application icon for macOS Dock
        if let bundleIcon = Bundle.main.image(forResource: "AppIcon") {
            NSApplication.shared.applicationIconImage = bundleIcon
        } else if let resourcePath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
                  let icon = NSImage(contentsOfFile: resourcePath) {
            NSApplication.shared.applicationIconImage = icon
        } else if let fallback = NSImage(contentsOfFile: "Assets/AppIcon.icns") {
            NSApplication.shared.applicationIconImage = fallback
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            MainSplitView(store: store)
                .frame(minWidth: 860, minHeight: 540)
                .navigationTitle("Medha — Block PKM")
                .background(WindowAccessor())
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Window") {
                    if let window = NSApp.windows.first(where: { $0.canBecomeMain && !($0 is NSPanel) }) {
                        window.makeKeyAndOrderFront(nil)
                    } else {
                        openWindow(id: "main")
                    }
                }
                .keyboardShortcut("n", modifiers: [.command, .option])

                Divider()

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

            CommandMenu("View") {
                Button("Zoom In") {
                    store.zoomIn()
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Zoom Out") {
                    store.zoomOut()
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Actual Size") {
                    store.resetZoom()
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }
    }
}

