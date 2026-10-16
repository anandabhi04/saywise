import ChirpCore
import SwiftUI

struct SettingsView: View {
    @Bindable var controller: AppController

    var body: some View {
        TabView {
            GeneralTab(controller: controller).tabItem { Label("General", systemImage: "gearshape") }
            LanguageTab(controller: controller).tabItem { Label("Language", systemImage: "globe") }
            ModelsTab(controller: controller).tabItem { Label("Models", systemImage: "cpu") }
            DictionaryTab(controller: controller).tabItem { Label("Dictionary", systemImage: "character.book.closed") }
            SnippetsTab(controller: controller).tabItem { Label("Snippets", systemImage: "text.badge.plus") }
            AppStylesTab(controller: controller).tabItem { Label("App styles", systemImage: "app.badge") }
            HistorySettingsTab(controller: controller).tabItem { Label("History", systemImage: "clock") }
        }
        .padding()
        .frame(minWidth: 640, minHeight: 460)
    }
}

struct GeneralTab: View {
    @Bindable var controller: AppController

    var body: some View {
        Form {
            Picker("Dictation key", selection: $controller.settings.triggerKey) {
                ForEach(TriggerKey.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            Toggle("Start at login", isOn: $controller.settings.launchAtLogin)
            Toggle("Play sounds", isOn: $controller.settings.soundsEnabled)
            if let error = controller.settingsError {
                Text(error).foregroundStyle(.orange)
            }
        }
        .formStyle(.grouped)
    }
}

struct LanguageTab: View {
    @Bindable var controller: AppController

    var body: some View {
        Form {
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
        .formStyle(.grouped)
    }
}

struct ModelsTab: View {
    @Bindable var controller: AppController
    @State private var modelIDDraft = ""
    @State private var sizes: [(String, String)] = []

    var body: some View {
        Form {
            Section("Status") {
                ModelStatusView(controller: controller)
            }
            Section("Cleanup model") {
                TextField("Hugging Face id", text: $modelIDDraft)
                HStack {
                    Button("Apply") { controller.settings.cleanupModelID = modelIDDraft }
                        .disabled(modelIDDraft == controller.settings.cleanupModelID || modelIDDraft.isEmpty)
                    Button("Use default") { modelIDDraft = ChirpSettings.defaultCleanupModelID }
                }
            }
            Section("Downloaded") {
                ForEach(sizes, id: \.0) { name, size in
                    LabeledContent(name, value: size)
                }
                HStack {
                    Button("Show in Finder") { NSWorkspace.shared.open(controller.paths.modelsDirectory) }
                    Button("Download again") { controller.redownloadModels() }
                }
            }
        }
        .formStyle(.grouped)
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
