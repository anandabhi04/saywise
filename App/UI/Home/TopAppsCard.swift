import AppKit
import ChirpCore
import SwiftUI

struct TopAppsCard: View {
    var apps: [HistoryStats.AppWords]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top apps").font(.headline)
            if apps.isEmpty {
                Text("No apps yet.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(apps) { app in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Image(nsImage: AppIcons.icon(for: app.bundleID)).resizable().frame(width: 20, height: 20)
                        Text(app.name).font(.body)
                        Spacer()
                        Text(app.words.formatted()).font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        Capsule().fill(Color.accentColor.opacity(0.5))
                            .frame(width: geo.size.width * CGFloat(app.words) / CGFloat(max(1, apps.first?.words ?? 1)))
                    }
                    .frame(height: 3).padding(.leading, 30)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

@MainActor enum AppIcons {
    private static var cache: [String: NSImage] = [:]
    static func icon(for bundleID: String?) -> NSImage {
        let key = bundleID ?? ""
        if let hit = cache[key] { return hit }
        let image: NSImage
        if let bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            image = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            image = NSWorkspace.shared.icon(for: .application)
        }
        cache[key] = image
        return image
    }
}
