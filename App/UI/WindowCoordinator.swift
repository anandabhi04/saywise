import AppKit
import SwiftUI

/// Opens and reuses the main, Setup, Settings and History windows. They are plain
/// AppKit windows hosting SwiftUI views, because the app's only scene is the menu bar extra.
@MainActor
final class WindowCoordinator {
    static let shared = WindowCoordinator()

    var controller: AppController?
    private var windows: [String: NSWindow] = [:]

    func showMain() {
        guard let controller else { return }
        show("main", title: "Saywise", size: NSSize(width: 520, height: 700)) {
            MainView(controller: controller)
        }
    }

    func showSetup() {
        guard let controller else { return }
        show("setup", title: "Set up Saywise", size: NSSize(width: 600, height: 520)) {
            SetupView(controller: controller)
        }
    }

    func showSettings() {
        guard let controller else { return }
        show("settings", title: "Saywise Settings", size: NSSize(width: 680, height: 520)) {
            SettingsView(controller: controller)
        }
    }

    func showHistory() {
        guard let controller else { return }
        show("history", title: "Saywise History", size: NSSize(width: 820, height: 560)) {
            HistoryView(controller: controller)
        }
    }

    private func show<Content: View>(
        _ id: String, title: String, size: NSSize, @ViewBuilder content: () -> Content
    ) {
        if let window = windows[id] {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = title
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: content())
        window.setContentSize(size)
        window.center()
        windows[id] = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
