import AppKit
import SwiftUI

@main
struct ChirpApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(controller: delegate.controller)
        } label: {
            Image(systemName: delegate.controller.menuBarSymbol)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = AppController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        WindowCoordinator.shared.controller = controller
        controller.start()
        WindowCoordinator.shared.showMain()
        if controller.needsSetup || controller.settingsError != nil {
            WindowCoordinator.shared.showSetup()
        }
    }

    // A click on the Dock icon brings the main window back after it was closed.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WindowCoordinator.shared.showMain()
        return true
    }
}
