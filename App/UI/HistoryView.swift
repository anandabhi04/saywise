import AppKit
import ChirpCore
import SwiftUI

struct HistoryView: View {
    let controller: AppController
    @Binding var focus: HistoryEntry.ID?
    @State private var entries: [HistoryEntry] = []
    @State private var search = ""
    @State private var expanded: HistoryEntry.ID?
    @State private var confirmClear = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("History").font(.largeTitle.bold())
                        Spacer()
                        TextField("Search", text: $search).textFieldStyle(.roundedBorder).frame(width: 240)
                        Menu {
                            Button("Clear all…", role: .destructive) { confirmClear = true }
                        } label: { Image(systemName: "ellipsis.circle") }
                        .menuStyle(.borderlessButton).frame(width: 28)
                    }
                    .padding(.bottom, 8)
                    if entries.isEmpty {
                        emptyState
                    }
                    ForEach(groups, id: \.title) { group in
                        Text(group.title.uppercased())
                            .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                            .kerning(0.6).padding(.top, 22).padding(.bottom, 6)
                        ForEach(group.entries) { entry in
                            HistoryRow(entry: entry, expanded: expanded == entry.id) {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                    expanded = expanded == entry.id ? nil : entry.id
                                }
                            } delete: {
                                Task { await delete(entry) }
                            }
                            .id(entry.id)
                        }
                    }
                }
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(32).padding(.top, 12)
            }
            .onChange(of: focus, initial: true) { _, id in
                guard let id else { return }
                expanded = id
                focus = nil
                Task { await Task.yield(); withAnimation { proxy.scrollTo(id, anchor: .center) } }
            }
        }
        .confirmationDialog("Delete all history?", isPresented: $confirmClear) {
            Button("Delete all", role: .destructive) { Task { await controller.clearHistory() } }
        } message: { Text("This cannot be undone.") }
        .task(id: search) { await reload() }
        .onChange(of: controller.historyRevision) { Task { await reload() } }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform").font(.system(size: 40)).foregroundStyle(.tertiary)
            Text("Your dictations will show up here.").font(.body).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.top, 120)
    }

    private struct Group { var title: String; var entries: [HistoryEntry] }

    private var groups: [Group] {
        let cal = Calendar.current
        var result: [Group] = []
        for entry in entries {
            let title: String
            if cal.isDateInToday(entry.createdAt) { title = "Today" }
            else if cal.isDateInYesterday(entry.createdAt) { title = "Yesterday" }
            else { title = entry.createdAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) }
            if result.last?.title == title { result[result.count - 1].entries.append(entry) }
            else { result.append(Group(title: title, entries: [entry])) }
        }
        return result
    }

    private func reload() async {
        entries = (try? await controller.history?.recent(search: search)) ?? []
        if let focus, entries.contains(where: { $0.id == focus }) { expanded = focus }
    }

    private func delete(_ entry: HistoryEntry) async {
        await controller.deleteHistoryEntry(entry)
        await reload()
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry
    let expanded: Bool
    let toggle: () -> Void
    let delete: () -> Void
    @State private var hovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.finalText).font(.body).lineLimit(expanded ? nil : 2)
                    Text("\(entry.appName ?? "Unknown app") · \(entry.createdAt.formatted(date: .omitted, time: .shortened)) · \(Int(entry.audioSeconds.rounded())) s")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { copy(entry.finalText) } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless).foregroundStyle(.secondary).opacity(hovered || expanded ? 1 : 0).help("Copy")
            }
            if expanded {
                HStack(alignment: .top, spacing: 12) {
                    textBox("Heard", entry.rawText)
                    textBox("Written", entry.finalText)
                }
                .padding(.top, 12)
                Text("\(entry.style) · \(entry.language) · \(entry.cleanup) · \(entry.insertOutcome) · speech \(entry.transcribeMs) ms · cleanup \(entry.cleanupMs) ms · paste \(entry.insertMs) ms")
                    .font(.caption).foregroundStyle(.secondary).padding(.top, 10)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(expanded ? Color(nsColor: .controlBackgroundColor) : .clear))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(.separator, lineWidth: expanded ? 0.5 : 0))
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .onTapGesture(perform: toggle)
        .contextMenu {
            Button("Copy") { copy(entry.finalText) }
            Button("Delete", role: .destructive, action: delete)
        }
    }

    private func textBox(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                Spacer()
                Button { copy(text) } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.borderless).foregroundStyle(.secondary)
            }
            Text(text).font(.callout).foregroundStyle(.primary).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quaternary))
    }
}

@MainActor
func copy(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}
