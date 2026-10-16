import Foundation
import Testing
@testable import ChirpCore

struct StorageTests {
    func tempDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    func entry(_ text: String, at seconds: TimeInterval) -> HistoryEntry {
        HistoryEntry(
            createdAt: Date(timeIntervalSince1970: seconds), appBundleID: "com.apple.Notes", appName: "Notes",
            style: "document", language: "auto", audioSeconds: 1, rawText: "raw \(text)", finalText: text,
            cleanup: "used", insertOutcome: "pasted", transcribeMs: 1, cleanupMs: 2, insertMs: 3, totalMs: 6,
            audioFileName: nil)
    }

    @Test func settingsStoreMissingFileGivesDefaults() throws {
        let store = SettingsStore(url: tempDir().appendingPathComponent("settings.json"))
        #expect(try store.load() == ChirpSettings())
    }

    @Test func settingsStoreRoundTrips() throws {
        let store = SettingsStore(url: tempDir().appendingPathComponent("settings.json"))
        var s = ChirpSettings()
        s.dictionary = [DictionaryEntry(word: "Nebula", lastUsedAt: Date(timeIntervalSince1970: 1_700_000_000))]
        try store.save(s)
        #expect(try store.load() == s)
    }

    @Test func settingsStoreThrowsOnBrokenFile() throws {
        let url = tempDir().appendingPathComponent("settings.json")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        #expect(throws: (any Error).self) { try SettingsStore(url: url).load() }
    }

    @Test func historySavesSearchesAndOrdersNewestFirst() async throws {
        let store = try HistoryStore()
        try await store.save(entry("first note", at: 100))
        try await store.save(entry("second NOTE", at: 200))
        try await store.save(entry("other", at: 300))
        #expect(try await store.recent().map(\.finalText) == ["other", "second NOTE", "first note"])
        #expect(try await store.recent(search: "note").map(\.finalText) == ["second NOTE", "first note"])
        #expect(try await store.recent(search: "raw other").map(\.finalText) == ["other"])
    }

    @Test func historyDeleteAndPurge() async throws {
        let store = try HistoryStore()
        let a = entry("a", at: 100)
        try await store.save(a)
        try await store.save(entry("b", at: 200))
        try await store.save(entry("c", at: 300))
        try await store.delete(id: a.id)
        #expect(try await store.purge(olderThan: Date(timeIntervalSince1970: 250)) == 1)
        #expect(try await store.recent().map(\.finalText) == ["c"])
        try await store.deleteAll()
        #expect(try await store.recent().isEmpty)
    }

    @Test func historyFileOnDiskPersists() async throws {
        let path = tempDir().appendingPathComponent("history.sqlite").path
        try await HistoryStore(path: path).save(entry("kept", at: 1))
        #expect(try await HistoryStore(path: path).recent().map(\.finalText) == ["kept"])
    }

    @Test func audioClipStoreKeepsNewestAndReadsBack() throws {
        let store = AudioClipStore(directory: tempDir(), limit: 2)
        let samples = speechSamples
        _ = try store.save(samples, now: Date(timeIntervalSince1970: 1))
        let second = try store.save(samples, now: Date(timeIntervalSince1970: 2))
        let third = try store.save(samples, now: Date(timeIntervalSince1970: 3))
        let files = try FileManager.default.contentsOfDirectory(atPath: store.directory.path).sorted()
        #expect(files == [second, third].sorted())
        let loaded = try AudioClipStore.loadSamples(from: store.directory.appendingPathComponent(third))
        #expect(abs(loaded.count - samples.count) < 50)
        #expect(SilenceFilter.hasSpeech(loaded))
    }

    @Test func audioClipStoreDeletesAllClips() throws {
        let store = AudioClipStore(directory: tempDir())
        defer { try? FileManager.default.removeItem(at: store.directory) }
        try store.deleteAll()
        _ = try store.save(speechSamples)
        _ = try store.save(speechSamples)
        #expect(try FileManager.default.contentsOfDirectory(atPath: store.directory.path).count == 2)
        try store.deleteAll()
        #expect(try FileManager.default.contentsOfDirectory(atPath: store.directory.path).isEmpty)
        try store.deleteAll()
    }

}
