import Foundation
import Synchronization
@testable import ChirpCore

struct FakeTranscriber: Transcriber {
    var text: String
    var error: Error?

    func transcribe(_ samples: [Float], language: LanguageMode, hints: [String]) async throws -> String {
        if let error { throw error }
        return text
    }
}

struct FakeCleaner: Cleaner {
    var reply: @Sendable (CleanupRequest) -> String
    var delay: Duration = .zero
    var error: Error?

    func clean(_ request: CleanupRequest) async throws -> String {
        // A real MLX generation ignores cancellation, so the fake must too.
        if delay > .zero { await Task.detached { try? await Task.sleep(for: delay) }.value }
        if let error { throw error }
        return reply(request)
    }
}

final class RecordingInserter: TextInserter {
    let inserted = Mutex<[String]>([])

    func insert(_ text: String) async -> InsertOutcome {
        inserted.withLock { $0.append(text) }
        return .pasted
    }
}

final class RecordingHistory: HistoryWriting {
    let entries = Mutex<[HistoryEntry]>([])

    func save(_ entry: HistoryEntry) async throws {
        entries.withLock { $0.append(entry) }
    }
}

struct ThrowingHistory: HistoryWriting {
    func save(_ entry: HistoryEntry) async throws { throw TestError() }
}

struct TestError: Error {}

/// One second of a loud tone, which the silence filter counts as speech.
let speechSamples: [Float] = (0..<16_000).map { 0.2 * sin(Float($0) * 0.1) }
