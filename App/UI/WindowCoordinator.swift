import AppKit
import ChirpCore
import SwiftUI

/// One main window (sidebar + pages) and one setup window, both AppKit windows hosting SwiftUI,
/// because the app's only scene is the menu bar extra.
@MainActor
final class WindowCoordinator {
    static let shared = WindowCoordinator()

    var controller: AppController?
    let rootState = RootState()
    private var windows: [String: NSWindow] = [:]

    func showMain(page: Page? = nil, focusingHistory id: HistoryEntry.ID? = nil) {
        guard let controller else { return }
        if let page { rootState.page = page }
        if let id { rootState.page = .history; rootState.historyFocus = id }
        show("main", size: NSSize(width: 980, height: 640), minSize: NSSize(width: 820, height: 560)) {
            RootView(controller: controller, state: rootState)
        }
    }

    func showHistory() { showMain(page: .history) }
    func showSettings() { showMain(page: .settings) }

    func showSetup() {
        guard let controller else { return }
        show("setup", size: NSSize(width: 480, height: 420), minSize: nil, resizable: false) {
            SetupView(controller: controller)
        }
    }

    func closeSetup() { windows["setup"]?.close() }

    private func show<Content: View>(
        _ id: String, size: NSSize, minSize: NSSize?, resizable: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        if let window = windows[id] {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        var mask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        if resizable { mask.insert(.resizable) }
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: mask, backing: .buffered, defer: false)
        window.title = "Saywise"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = !resizable
        if let minSize { window.minSize = minSize }
        window.contentViewController = NSHostingController(rootView: content())
        window.setContentSize(size)
        window.center()
        windows[id] = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
