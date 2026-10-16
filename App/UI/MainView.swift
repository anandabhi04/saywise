import AppKit
import ChirpCore
import SwiftUI

struct MainView: View {
    @Bindable var controller: AppController
    @State private var needsSetup = false
    @State private var recent: [HistoryEntry] = []
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            statusSection
            Divider()
            Toggle(isOn: Binding(get: { controller.isMicOn }, set: { controller.setMicOn($0) })) {
                VStack(alignment: .leading) {
                    Text("Mic on").bold()
                    Text("When off, Saywise does not listen. The \(controller.settings.triggerKey.displayName) key and the floating button do nothing.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .disabled(!canToggleMic)
            Divider()
            talkSection
            Divider()
            recentSection
            Divider()
            HStack {
                Toggle("Show floating button", isOn: $controller.settings.showFloatingButton)
                Spacer()
                Button("Settings…") { WindowCoordinator.shared.showSettings() }
            }
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 640)
        .onAppear(perform: refreshSetup)
        .onReceive(timer) { _ in refreshSetup() }
        .task { await reloadRecent() }
        .onChange(of: controller.historyRevision) { Task { await reloadRecent() } }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: controller.menuBarSymbol)
                    .foregroundStyle(statusColor)
                Text(controller.statusText).font(.headline)
            }
            if case .loadingModels = controller.status {
                ProgressView(value: controller.modelProgress)
            }
            if needsSetup || modelsFailed {
                HStack {
                    Label(needsSetup ? "Some permissions are missing." : "The models did not load.",
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("Fix") { WindowCoordinator.shared.showSetup() }
                }
            }
        }
    }

    private var talkSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Button { controller.toggleRecording(from: .window) } label: {
                    ZStack {
                        Circle().fill(isRecordingHere ? Color.red : Color.accentColor)
                        if isWorkingHere {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            Image(systemName: isRecordingHere ? "stop.fill" : "mic.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 64, height: 64)
                }
                .buttonStyle(.plain)
                .disabled(!canTalkHere)
                VStack(alignment: .leading) {
                    Text(talkTitle).bold()
                    Text("Your words appear in the box below.").font(.callout).foregroundStyle(.secondary)
                }
            }
            TextEditor(text: $controller.windowText)
                .font(.body)
                .frame(minHeight: 120)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
            HStack {
                Button("Copy") { copy(controller.windowText) }
                    .disabled(controller.windowText.isEmpty)
                Button("Clear") { controller.windowText = "" }
                    .disabled(controller.windowText.isEmpty)
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent").bold()
                Spacer()
                Button("Show all history") { WindowCoordinator.shared.showHistory() }
                    .buttonStyle(.link)
            }
            if recent.isEmpty {
                Text("Nothing yet.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(recent) { entry in
                HStack(alignment: .top) {
                    Text(entry.finalText).lineLimit(2)
                    Spacer()
                    Button { copy(entry.finalText) } label: { Image(systemName: "doc.on.doc") }
                        .buttonStyle(.borderless)
                        .help("Copy")
                }
            }
        }
    }

    private var isRecordingHere: Bool {
        controller.status == .recording && controller.recordingSource == .window
    }

    private var isWorkingHere: Bool {
        controller.status == .working && controller.recordingSource == .window
    }

    private var modelsFailed: Bool {
        if case .failed = controller.status { return true }
        return false
    }

    private var canTalkHere: Bool { controller.status == .ready || isRecordingHere }

    private var canToggleMic: Bool { controller.status == .ready || controller.status == .paused }

    private var talkTitle: String {
        if isRecordingHere { return "Listening… click to stop" }
        if isWorkingHere { return "Working…" }
        return "Click to talk"
    }

    private var statusColor: Color {
        switch controller.status {
        case .ready: .green
        case .recording: .red
        case .failed: .orange
        default: .secondary
        }
    }

    private func refreshSetup() {
        needsSetup = controller.needsSetup
        controller.startHotkeyIfAllowed()
    }

    private func reloadRecent() async {
        recent = (try? await controller.history?.recent(limit: 5)) ?? []
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
