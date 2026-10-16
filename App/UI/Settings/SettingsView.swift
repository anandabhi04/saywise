import AppKit
import ChirpCore
import SwiftUI

struct SettingsView: View {
    @Bindable var controller: AppController
    @State private var modelIDDraft = ""
    @State private var sizes: [(String, String)] = []
    @State private var confirmClear = false

    var body: some View {
        Form {
            Section("Talk") {
                Picker("Talk key", selection: $controller.settings.triggerKey) {
                    ForEach(TriggerKey.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Toggle("Show floating bar", isOn: $controller.settings.showFloatingButton)
                Toggle("Play sounds", isOn: $controller.settings.soundsEnabled)
            }
            Section("Language") {
                Picker("Language", selection: $controller.settings.languageMode) {
                    Text("Auto detect").tag(LanguageMode.auto)
                    Text("English").tag(LanguageMode.english)
                    Text("Hindi / Hinglish").tag(LanguageMode.hindi)
                }
                Text("Hindi is always written in Roman letters, for example \"kal meeting hai\".")
                    .font(.callout).foregroundStyle(.secondary)
                Picker("Speech engine", selection: $controller.settings.speechEngine) {
                    Text("Whisper large-v3-turbo").tag(SpeechEngine.whisper)
                    Text("Qwen3-ASR 0.6B (testing)").tag(SpeechEngine.qwen3ASR)
                }
            }
            Section("Models") {
                LabeledContent("Status") { ModelStatusView(controller: controller) }
                TextField("Cleanup model", text: $modelIDDraft, prompt: Text("Hugging Face id"))
                HStack {
                    Button("Apply") { controller.settings.cleanupModelID = modelIDDraft }
                        .disabled(modelIDDraft == controller.settings.cleanupModelID || modelIDDraft.isEmpty)
                    Button("Use default") { modelIDDraft = ChirpSettings.defaultCleanupModelID }
                }
                ForEach(sizes, id: \.0) { name, size in LabeledContent(name, value: size) }
                HStack {
                    Button("Show in Finder") { NSWorkspace.shared.open(controller.paths.modelsDirectory) }
                    Button("Download again") { controller.redownloadModels() }
                }
            }
            Section("History") {
                Picker("Keep history", selection: $controller.settings.historyRetention) {
                    Text("Off").tag(HistoryRetention.off)
                    Text("7 days").tag(HistoryRetention.days7)
                    Text("30 days").tag(HistoryRetention.days30)
                    Text("Forever").tag(HistoryRetention.forever)
                }
                Toggle("Keep audio of the last 50 dictations", isOn: $controller.settings.keepAudio)
                Button("Show audio folder") { NSWorkspace.shared.open(controller.paths.audioDirectory) }
                Button("Delete all history…", role: .destructive) { confirmClear = true }
            }
            Section("General") {
                Toggle("Start at login", isOn: $controller.settings.launchAtLogin)
                if let error = controller.settingsError { Text(error).foregroundStyle(.orange) }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
        .confirmationDialog("Delete all history?", isPresented: $confirmClear) {
            Button("Delete all", role: .destructive) { Task { await controller.clearHistory() } }
        } message: { Text("This cannot be undone.") }
        .onAppear {
            modelIDDraft = controller.settings.cleanupModelID
            sizes = Self.folderSizes(in: controller.paths.modelsDirectory)
        }
    }

    static func folderSizes(in directory: URL) -> [(String, String)] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.sorted().map { name in
            let url = directory.appendingPathComponent(name)
            var bytes: Int64 = 0
            let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey]
            if let files = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys) {
                for case let file as URL in files {
                    bytes += Int64((try? file.resourceValues(forKeys: Set(keys)).totalFileAllocatedSize) ?? 0)
                }
            }
            return (name, ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
        }
    }
}

struct ModelStatusView: View {
    let controller: AppController

    var body: some View {
        switch controller.status {
        case .loadingModels:
            VStack(alignment: .trailing, spacing: 4) {
                ProgressView(value: controller.modelProgress).frame(width: 160)
                Text(controller.modelProgressText).font(.caption).foregroundStyle(.secondary)
            }
        case .failed:
            HStack(spacing: 8) {
                Label("Could not load", systemImage: "exclamationmark.circle.fill").foregroundStyle(.orange)
                Button("Try again") { Task { await controller.loadModels() } }.controlSize(.small)
            }
        case .starting:
            Text("Starting…").foregroundStyle(.secondary)
        default:
            Label("Ready", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        }
    }
}
