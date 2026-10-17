import AppKit
import SwiftUI

struct OnboardingView: View {
    let controller: AppController
    @State private var steps: [Step] = []
    @State private var index = 0
    @State private var justGranted = false
    @State private var needsRestart = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum Step: Equatable {
        case welcome, permission(Permission), fnKey, download, done
    }

    var body: some View {
        ZStack {
            if steps.indices.contains(index) {
                page(for: steps[index])
                    .id(index)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: index)
        .frame(width: 480, height: 420)
        .overlay(alignment: .bottom) {
            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { i in
                    Circle().fill(i == index ? Color.primary : Color(nsColor: .tertiaryLabelColor)).frame(width: 6, height: 6)
                }
            }
            .padding(.bottom, 18)
        }
        .onAppear { steps = Self.buildSteps(controller: controller); index = 0 }
        .onReceive(timer) { _ in tick() }
        .onExitCommand { }
    }

    static func buildSteps(controller: AppController) -> [Step] {
        var steps: [Step] = [.welcome]
        for p in [Permission.microphone, .inputMonitoring, .accessibility] where !p.isGranted { steps.append(.permission(p)) }
        if controller.settings.triggerKey == .fn { steps.append(.fnKey) }
        switch controller.status {
        case .ready, .paused, .recording, .recordingPaused, .working: break
        default: steps.append(.download)
        }
        steps.append(.done)
        return steps
    }

    @ViewBuilder private func page(for step: Step) -> some View {
        switch step {
        case .welcome:
            StepPage(symbol: "waveform", title: "Welcome to Saywise",
                     line: "Hold Fn, speak, let go. Your words appear where you type. English, Hindi, or both. Everything stays on this Mac.",
                     button: "Continue", action: next)
        case let .permission(p):
            StepPage(symbol: symbol(for: p), title: p.title, line: p.reason,
                     button: needsRestart && p == .inputMonitoring ? "Restart Saywise" : "Allow",
                     secondLine: needsRestart && p == .inputMonitoring ? "Saywise needs a quick restart to use this." : nil,
                     granted: justGranted) {
                if needsRestart && p == .inputMonitoring { AppRelauncher.relaunch(); return }
                p.request(); p.openSettingsIfCannotAsk()
            }
        case .fnKey:
            StepPage(symbol: "globe", title: "One setting for Fn",
                     line: "By default Fn opens the emoji picker. Set \"Press 🌐 key to\" to \"Do Nothing\".",
                     button: "Open Keyboard Settings", secondaryButton: "Done, continue", secondaryAction: next) {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
            }
        case .download:
            DownloadStep(controller: controller)
        case .done:
            StepPage(symbol: "checkmark.circle.fill", symbolColor: .green, title: "You're set",
                     line: "Hold Fn in any app and start talking.", button: "Open Saywise") {
                WindowCoordinator.shared.closeSetup()
                WindowCoordinator.shared.showMain()
            }
        }
    }

    private func symbol(for p: Permission) -> String {
        switch p { case .microphone: "mic.fill"; case .inputMonitoring: "keyboard"; case .accessibility: "accessibility" }
    }

    private func next() {
        justGranted = false
        if index + 1 < steps.count { index += 1 }
    }

    private func tick() {
        guard steps.indices.contains(index) else { return }
        switch steps[index] {
        case let .permission(p) where p.isGranted:
            if p == .inputMonitoring {
                controller.startHotkeyIfAllowed()
                if !controller.hotkeyIsRunning { needsRestart = true; return }
            }
            guard !justGranted else { return }
            justGranted = true
            Task { try? await Task.sleep(for: .seconds(0.6)); next() }
        case .download:
            switch controller.status {
            case .ready, .paused: next()
            default: break
            }
        default: break
        }
    }
}

private struct StepPage: View {
    var symbol: String
    var symbolColor: Color = .accentColor
    var title: String
    var line: String
    var button: String
    var secondLine: String? = nil
    var secondaryButton: String? = nil
    var secondaryAction: (() -> Void)? = nil
    var granted = false
    var action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Image(systemName: symbol).font(.system(size: 44)).foregroundStyle(symbolColor).opacity(granted ? 0 : 1)
                Image(systemName: "checkmark.circle.fill").font(.system(size: 44)).foregroundStyle(.green).opacity(granted ? 1 : 0)
            }
            .animation(.easeOut(duration: 0.2), value: granted)
            .padding(.bottom, 18)
            Text(title).font(.title2.weight(.semibold)).padding(.bottom, 8)
            Text(line).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 340)
            if let secondLine {
                Text(secondLine).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.top, 6)
            }
            Button(button, action: action).buttonStyle(.borderedProminent).controlSize(.large).padding(.top, 26)
            if let secondaryButton, let secondaryAction {
                Button(secondaryButton, action: secondaryAction).buttonStyle(.link).padding(.top, 10)
            }
            Spacer()
        }
        .padding(40)
    }
}

private struct DownloadStep: View {
    let controller: AppController
    @State private var showDetails = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "arrow.down.circle").font(.system(size: 44)).foregroundStyle(Color.accentColor).padding(.bottom, 18)
            Text("Downloading models").font(.title2.weight(.semibold)).padding(.bottom, 8)
            Text("About 4 GB, once. After this, Saywise never uses the network.")
                .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 340)
            Group {
                if case .failed = controller.status {
                    VStack(spacing: 8) {
                        Text("The download stopped.").font(.callout)
                        Button("Try again") { Task { await controller.loadModels() } }.buttonStyle(.borderedProminent)
                        Button(showDetails ? "Hide details" : "Details") { showDetails.toggle() }.buttonStyle(.link).font(.caption)
                        if showDetails {
                            Text(controller.failureDetail).font(.caption).foregroundStyle(.secondary)
                                .textSelection(.enabled).frame(maxWidth: 360)
                        }
                    }
                } else {
                    VStack(spacing: 6) {
                        ProgressView(value: controller.modelProgress).frame(width: 260)
                        Text(controller.modelProgressText).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 26)
            Spacer()
        }
        .padding(40)
    }
}
