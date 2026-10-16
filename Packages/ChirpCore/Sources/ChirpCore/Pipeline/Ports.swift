import Foundation

public protocol Transcriber: Sendable {
    func transcribe(_ samples: [Float], language: LanguageMode, hints: [String]) async throws -> String
}

public protocol Cleaner: Sendable {
    func clean(_ request: CleanupRequest) async throws -> String
}

public enum InsertOutcome: String, Codable, Sendable {
    case pasted
    case copiedNoTextField
    case copiedNoPermission
}

public protocol TextInserter: Sendable {
    func insert(_ text: String) async -> InsertOutcome
}

public protocol HistoryWriting: Sendable {
    func save(_ entry: HistoryEntry) async throws
}
