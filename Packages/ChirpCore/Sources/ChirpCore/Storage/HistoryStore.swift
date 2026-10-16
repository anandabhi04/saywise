import Foundation
import GRDB

extension HistoryEntry: FetchableRecord, PersistableRecord {}

public final class HistoryStore: HistoryWriting, Sendable {
    private let db: DatabaseQueue

    public init(path: String) throws {
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: path).deletingLastPathComponent(), withIntermediateDirectories: true)
        db = try DatabaseQueue(path: path)
        try Self.migrator.migrate(db)
    }

    public init(inMemory: Void = ()) throws {
        db = try DatabaseQueue()
        try Self.migrator.migrate(db)
    }

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "historyEntry") { t in
                t.primaryKey("id", .text)
                t.column("createdAt", .datetime).notNull().indexed()
                t.column("appBundleID", .text)
                t.column("appName", .text)
                t.column("style", .text).notNull()
                t.column("language", .text).notNull()
                t.column("audioSeconds", .double).notNull()
                t.column("rawText", .text).notNull()
                t.column("finalText", .text).notNull()
                t.column("cleanup", .text).notNull()
                t.column("insertOutcome", .text).notNull()
                t.column("transcribeMs", .integer).notNull()
                t.column("cleanupMs", .integer).notNull()
                t.column("insertMs", .integer).notNull()
                t.column("totalMs", .integer).notNull()
                t.column("audioFileName", .text)
            }
        }
        return migrator
    }

    public func save(_ entry: HistoryEntry) async throws {
        try await db.write { try entry.insert($0) }
    }

    /// Newest first. `search` matches raw or final text, ignoring case.
    public func recent(limit: Int = 500, search: String? = nil) async throws -> [HistoryEntry] {
        try await db.read { db in
            var request = HistoryEntry.order(Column("createdAt").desc)
            if let search, !search.isEmpty {
                let pattern = "%\(search)%"
                request = request.filter(Column("rawText").like(pattern) || Column("finalText").like(pattern))
            }
            return try request.limit(limit).fetchAll(db)
        }
    }

    public func delete(id: String) async throws {
        _ = try await db.write { try HistoryEntry.deleteOne($0, key: id) }
    }

    public func deleteAll() async throws {
        _ = try await db.write { try HistoryEntry.deleteAll($0) }
    }

    /// Deletes rows older than `date`. Returns how many were deleted.
    @discardableResult
    public func purge(olderThan date: Date) async throws -> Int {
        try await db.write { try HistoryEntry.filter(Column("createdAt") < date).deleteAll($0) }
    }
}
