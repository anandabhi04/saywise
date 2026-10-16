import Foundation

public struct ChirpPaths: Sendable {
    public let root: URL

    public init(root: URL) { self.root = root }

    public static let standard = ChirpPaths(
        root: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Saywise", isDirectory: true))

    public var settingsFile: URL { root.appendingPathComponent("settings.json") }
    public var historyDatabase: URL { root.appendingPathComponent("history.sqlite") }
    public var audioDirectory: URL { root.appendingPathComponent("audio", isDirectory: true) }
    public var modelsDirectory: URL { root.appendingPathComponent("models", isDirectory: true) }
}
