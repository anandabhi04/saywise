import AppKit
import SwiftUI

struct MenuContent: View {
    let controller: AppController

    var body: some View {
        Text(controller.statusText)
        Divider()
        Button(controller.status == .paused ? "Resume Chirp" : "Pause Chirp") { controller.togglePause() }
        if controller.shouldShowSetup {
            Button("Finish setup…") { WindowCoordinator.shared.showSetup() }
        }
        Divider()
        Button("Quit Chirp") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
