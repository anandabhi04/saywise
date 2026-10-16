import ChirpCore
import SwiftUI

struct RecentCard: View {
    var entries: [HistoryEntry]
    var open: (HistoryEntry) -> Void
    var seeAll: () -> Void
    @State private var hovered: HistoryEntry.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recent").font(.headline)
                Spacer()
                Button("See all", action: seeAll).buttonStyle(.link).font(.caption)
            }
            .padding(.bottom, 8)
            if entries.isEmpty {
                Text("Nothing yet.").font(.callout).foregroundStyle(.secondary).padding(.top, 4)
            }
            ForEach(entries) { entry in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.finalText).font(.body).lineLimit(1)
                        Text("\(entry.appName ?? "Unknown app") · \(entry.createdAt.formatted(.relative(presentation: .named)))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { copy(entry.finalText) } label: { Image(systemName: "doc.on.doc") }
                        .buttonStyle(.borderless).foregroundStyle(.secondary)
                        .opacity(hovered == entry.id ? 1 : 0)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onHover { hovered = $0 ? entry.id : nil }
                .onTapGesture { open(entry) }
                if entry.id != entries.last?.id { Divider() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
