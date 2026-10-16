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
        #expect(try await store.purge(olderThan: Date(timeIntervalSince1970: 250)).deletedCount == 1)
        #expect(try await store.recent().map(\.finalText) == ["c"])
        try await store.deleteAll()
        #expect(try await store.recent().isEmpty)
    }

    @Test func historyPurgeReturnsOnlyDeletedAudioFileNames() async throws {
        let store = try HistoryStore()
        var old = entry("old", at: 100)
        old.audioFileName = "old.wav"
        var boundary = entry("boundary", at: 200)
        boundary.audioFileName = "kept.wav"
        try await store.save(old)
        try await store.save(entry("no audio", at: 150))
        try await store.save(boundary)

        let result = try await store.purge(olderThan: Date(timeIntervalSince1970: 200))
        #expect(result.deletedCount == 2)
        #expect(result.audioFileNames == ["old.wav"])
        #expect(try await store.recent().map(\.id) == [boundary.id])
        let empty = try await store.purge(olderThan: Date(timeIntervalSince1970: 200))
        #expect(empty.deletedCount == 0)
        #expect(empty.audioFileNames.isEmpty)
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

    @Test func audioClipStoreDeletesOnlyNamedClip() throws {
        let store = AudioClipStore(directory: tempDir())
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let deleted = try store.save(speechSamples)
        let kept = try store.save(speechSamples)
        try store.delete(fileName: deleted)
        #expect(!FileManager.default.fileExists(atPath: store.directory.appendingPathComponent(deleted).path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: store.directory.path) == [kept])
        // A history row may point to a clip already removed by the retention limit.
        try store.delete(fileName: deleted)
    }

    @Test(arguments: ["", ".", "..", "../x", "a/b.wav"])
    func audioClipStoreIgnoresInvalidFileNames(fileName: String) throws {
        let parent = tempDir()
        defer { try? FileManager.default.removeItem(at: parent) }
        let directory = parent.appendingPathComponent("clips", isDirectory: true)
        let nestedDirectory = directory.appendingPathComponent("a", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)
        let outside = parent.appendingPathComponent("x")
        let kept = directory.appendingPathComponent("keep.wav")
        let nested = nestedDirectory.appendingPathComponent("b.wav")
        let contents = Data("keep this file".utf8)
        for file in [outside, kept, nested] {
            try contents.write(to: file)
        }

        try AudioClipStore(directory: directory).delete(fileName: fileName)

        for folder in [parent, directory, nestedDirectory] {
            var isDirectory: ObjCBool = false
            #expect(FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory))
            #expect(isDirectory.boolValue)
        }
        for file in [outside, kept, nested] {
            #expect(FileManager.default.fileExists(atPath: file.path))
            #expect(try Data(contentsOf: file) == contents)
        }
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
