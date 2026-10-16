import SwiftUI

@main
struct ChirpApp: App {
    var body: some Scene {
        MenuBarExtra("Chirp", systemImage: "waveform") {
            Button("Quit Chirp") { NSApplication.shared.terminate(nil) }
        }
    }
}
