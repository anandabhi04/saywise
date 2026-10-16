import AppKit
import ChirpCore
import SwiftUI

struct DictionaryTab: View {
    @Bindable var controller: AppController

    var body: some View {
        VStack(alignment: .leading) {
            Text("Words Saywise must spell exactly. \"Heard as\" lists what the speech model writes instead, separated by commas.")
                .font(.callout).foregroundStyle(.secondary)
            List {
                ForEach($controller.settings.dictionary) { $entry in
                    HStack {
                        TextField("Word", text: $entry.word).frame(width: 180)
                        TextField("Heard as (optional)", text: spokenForms($entry))
                        Button(role: .destructive) {
                            controller.settings.dictionary.removeAll { $0.id == entry.id }
                        } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                    }
                }
            }
            Button("Add word") { controller.settings.dictionary.append(DictionaryEntry(word: "")) }
        }
    }

    private func spokenForms(_ entry: Binding<DictionaryEntry>) -> Binding<String> {
        Binding(
            get: { entry.wrappedValue.spokenForms.joined(separator: ", ") },
            set: { text in
                entry.wrappedValue.spokenForms = text.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            })
    }
}

struct SnippetsTab: View {
    @Bindable var controller: AppController

    var body: some View {
        VStack(alignment: .leading) {
            Text("Say the trigger and Saywise types the text. Example: \"my email\".")
                .font(.callout).foregroundStyle(.secondary)
            List {
                ForEach($controller.settings.snippets) { $snippet in
                    HStack(alignment: .top) {
                        TextField("Trigger", text: $snippet.trigger).frame(width: 160)
                        TextField("Text", text: $snippet.expansion, axis: .vertical).lineLimit(1...4)
                        Button(role: .destructive) {
                            controller.settings.snippets.removeAll { $0.id == snippet.id }
                        } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                    }
                }
            }
            Button("Add snippet") { controller.settings.snippets.append(Snippet(trigger: "", expansion: "")) }
        }
    }
}

struct AppStylesTab: View {
    @Bindable var controller: AppController

    var body: some View {
        Form {
            Section("Your app rules") {
                ForEach(controller.settings.appStyles.keys.sorted(), id: \.self) { bundleID in
                    HStack {
                        Text(Self.appName(bundleID)).frame(maxWidth: .infinity, alignment: .leading)
                        Picker("", selection: styleBinding(bundleID)) {
                            ForEach(Style.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .frame(width: 140)
                        Button(role: .destructive) {
                            controller.settings.appStyles[bundleID] = nil
                        } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                    }
                }
                Button("Add app…", action: addApp)
            }
            Section("Browser title rules") {
                ForEach($controller.settings.titleRules) { $rule in
                    HStack {
                        TextField("Title contains", text: $rule.contains)
                        Picker("", selection: $rule.style) {
                            ForEach(Style.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .frame(width: 140)
                        Button(role: .destructive) {
                            controller.settings.titleRules.removeAll { $0.id == rule.id }
                        } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                    }
                }
                Button("Add title rule") {
                    controller.settings.titleRules.append(TitleRule(contains: "", style: .other))
                }
            }
            Section("Built in") {
                Text(Self.builtInSummary).font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func styleBinding(_ bundleID: String) -> Binding<Style> {
        Binding(
            get: { controller.settings.appStyles[bundleID] ?? .other },
            set: { controller.settings.appStyles[bundleID] = $0 })
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url,
              let bundleID = Bundle(url: url)?.bundleIdentifier
        else { return }
        controller.settings.appStyles[bundleID] = StyleResolver.builtIn[bundleID] ?? .other
    }

    static func appName(_ bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    static var builtInSummary: String {
        Dictionary(grouping: StyleResolver.builtIn, by: \.value)
            .sorted { $0.key.displayName < $1.key.displayName }
            .map { style, apps in
                "\(style.displayName): " + apps.map { appName($0.key) }.sorted().joined(separator: ", ")
            }
            .joined(separator: "\n")
    }
}

struct HistorySettingsTab: View {
    @Bindable var controller: AppController
    @State private var confirmClear = false

    var body: some View {
        Form {
            Picker("Keep history", selection: $controller.settings.historyRetention) {
                Text("Off").tag(HistoryRetention.off)
                Text("7 days").tag(HistoryRetention.days7)
                Text("30 days").tag(HistoryRetention.days30)
                Text("Forever").tag(HistoryRetention.forever)
            }
            Toggle("Keep audio of the last 50 dictations", isOn: $controller.settings.keepAudio)
            Button("Show audio folder") { NSWorkspace.shared.open(controller.paths.audioDirectory) }
            Button("Clear all history…", role: .destructive) { confirmClear = true }
        }
        .formStyle(.grouped)
        .confirmationDialog("Delete all history?", isPresented: $confirmClear) {
            Button("Delete all", role: .destructive) { Task { await controller.clearHistory() } }
        } message: {
            Text("This cannot be undone.")
        }
    }
}
