import AppKit
import SwiftUI

struct SetupView: View {
    let controller: AppController
    @State private var granted: [Permission: Bool] = [:]
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Set up Chirp").font(.title2.bold())
            if let error = controller.settingsError {
                Text(error).foregroundStyle(.orange)
            }
            ForEach(Permission.allCases) { permission in
                HStack(alignment: .top) {
                    Image(systemName: granted[permission] == true ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(granted[permission] == true ? .green : .secondary)
                    VStack(alignment: .leading) {
                        Text(permission.title).bold()
                        Text(permission.reason).font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if granted[permission] != true {
                        Button("Allow") { permission.request() }
                        Button("Open Settings") { permission.openSettings() }
                    }
                }
            }
            Divider()
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text("Fn key").bold()
                    Text("In System Settings > Keyboard, set \"Press 🌐 key to\" to \"Do Nothing\". Otherwise Fn also opens the emoji picker.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Open Keyboard Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
                }
            }
            Divider()
            ModelStatusView(controller: controller)
            Spacer()
            HStack {
                Text("After you allow Input Monitoring, restart Chirp once.")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Restart Chirp") { AppRelauncher.relaunch() }
            }
        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 480)
        .onAppear(perform: refresh)
        .onReceive(timer) { _ in refresh() }
    }

    private func refresh() {
        for permission in Permission.allCases { granted[permission] = permission.isGranted }
        controller.startHotkeyIfAllowed()
    }
}

struct ModelStatusView: View {
    let controller: AppController

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Models").bold()
            switch controller.status {
            case let .loadingModels(message):
                Text(message).font(.callout)
                ProgressView(value: controller.modelProgress)
            case let .failed(message):
                Text(message).font(.callout).foregroundStyle(.red)
                Button("Retry") { Task { await controller.loadModels() } }
            case .starting:
                Text("Starting…").font(.callout)
            default:
                Label("Models are ready", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}
