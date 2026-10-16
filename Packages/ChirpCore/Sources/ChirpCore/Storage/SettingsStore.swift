import Foundation

public struct SettingsStore: Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    /// A missing file gives defaults. A broken file throws, so it is never silently replaced.
    public func load() throws -> ChirpSettings {
        guard FileManager.default.fileExists(atPath: url.path) else { return ChirpSettings() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ChirpSettings.self, from: Data(contentsOf: url))
    }

    public func save(_ settings: ChirpSettings) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(settings).write(to: url, options: .atomic)
    }
}
