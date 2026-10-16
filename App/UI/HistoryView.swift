import AppKit
import ChirpCore
import SwiftUI

struct HistoryView: View {
    let controller: AppController
    @State private var entries: [HistoryEntry] = []
    @State private var search = ""
    @State private var selection: HistoryEntry.ID?
    @State private var confirmClear = false

    var body: some View {
        NavigationSplitView {
            List(entries, selection: $selection) { entry in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.finalText).lineLimit(2)
                        Text("\(entry.appName ?? "Unknown app") · \(entry.createdAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { copy(entry.finalText) } label: { Image(systemName: "doc.on.doc") }
                        .buttonStyle(.borderless)
                        .help("Copy")
                }
                .contextMenu {
                    Button("Copy") { copy(entry.finalText) }
                    Button("Delete", role: .destructive) { Task { await delete(entry) } }
                }
            }
            .searchable(text: $search)
            .navigationSplitViewColumnWidth(min: 280, ideal: 340)
        } detail: {
            if let entry = entries.first(where: { $0.id == selection }) {
                HistoryDetail(entry: entry)
            } else {
                Text("Select a dictation").foregroundStyle(.secondary)
            }
        }
        .toolbar {
            Button("Clear all…", role: .destructive) { confirmClear = true }
        }
        .confirmationDialog("Delete all history?", isPresented: $confirmClear) {
            Button("Delete all", role: .destructive) { Task { await controller.clearHistory() } }
        } message: {
            Text("This cannot be undone.")
        }
        .task(id: search) { await reload() }
        .onChange(of: controller.historyRevision) { Task { await reload() } }
    }

    private func reload() async {
        entries = (try? await controller.history?.recent(search: search)) ?? []
    }

    private func delete(_ entry: HistoryEntry) async {
        try? await controller.history?.delete(id: entry.id)
        await reload()
    }
}

struct HistoryDetail: View {
    let entry: HistoryEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    textBox("Raw", entry.rawText)
                    textBox("Clean", entry.finalText)
                }
                Grid(alignment: .leading, verticalSpacing: 4) {
                    row("App", entry.appName ?? entry.appBundleID ?? "Unknown")
                    row("Style", entry.style)
                    row("Language", entry.language)
                    row("Cleanup", entry.cleanup)
                    row("Paste", entry.insertOutcome)
                    row("Audio", String(format: "%.1f s", entry.audioSeconds))
                    row("Time", "speech \(entry.transcribeMs) ms · cleanup \(entry.cleanupMs) ms · paste \(entry.insertMs) ms · total \(entry.totalMs) ms")
                }
                .font(.callout)
            }
            .padding()
        }
    }

    private func textBox(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button { copy(text) } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless)
            }
            Text(text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value)
        }
    }
}

@MainActor
func copy(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}
