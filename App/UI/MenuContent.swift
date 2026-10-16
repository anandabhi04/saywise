import AppKit
import SwiftUI

struct MenuContent: View {
    let controller: AppController

    var body: some View {
        Text(controller.statusText)
        Divider()
        Button("Open Saywise") { WindowCoordinator.shared.showMain() }.keyboardShortcut("o")
        Button("History") { WindowCoordinator.shared.showHistory() }
        Button("Settings…") { WindowCoordinator.shared.showSettings() }.keyboardShortcut(",")
        Button(controller.status == .paused ? "Resume Saywise" : "Pause Saywise") { controller.togglePause() }
        if controller.shouldShowSetup {
            Button("Finish setup…") { WindowCoordinator.shared.showSetup() }
        }
        Divider()
        Button("Quit Saywise") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
