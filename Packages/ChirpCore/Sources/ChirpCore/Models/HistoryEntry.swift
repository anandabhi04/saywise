import Foundation

public struct HistoryEntry: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var createdAt: Date
    public var appBundleID: String?
    public var appName: String?
    public var style: String
    public var language: String
    public var audioSeconds: Double
    public var rawText: String
    public var finalText: String
    public var cleanup: String
    public var insertOutcome: String
    public var transcribeMs: Int
    public var cleanupMs: Int
    public var insertMs: Int
    public var totalMs: Int
    public var audioFileName: String?

    public init(
        id: String = UUID().uuidString, createdAt: Date, appBundleID: String?, appName: String?,
        style: String, language: String, audioSeconds: Double, rawText: String, finalText: String,
        cleanup: String, insertOutcome: String, transcribeMs: Int, cleanupMs: Int, insertMs: Int,
        totalMs: Int, audioFileName: String?
    ) {
        self.id = id
        self.createdAt = createdAt
        self.appBundleID = appBundleID
        self.appName = appName
        self.style = style
        self.language = language
        self.audioSeconds = audioSeconds
        self.rawText = rawText
        self.finalText = finalText
        self.cleanup = cleanup
        self.insertOutcome = insertOutcome
        self.transcribeMs = transcribeMs
        self.cleanupMs = cleanupMs
        self.insertMs = insertMs
        self.totalMs = totalMs
        self.audioFileName = audioFileName
    }

    public init(result: DictationResult, input: DictationInput, createdAt: Date) {
        self.init(
            createdAt: createdAt,
            appBundleID: input.context.bundleID,
            appName: input.context.appName,
            style: result.style.rawValue,
            language: input.settings.languageMode.rawValue,
            audioSeconds: Double(input.samples.count) / Double(SilenceFilter.sampleRate),
            rawText: result.rawText,
            finalText: result.finalText,
            cleanup: result.cleanup.storageValue,
            insertOutcome: result.insert.rawValue,
            transcribeMs: result.timings.transcribeMs,
            cleanupMs: result.timings.cleanupMs,
            insertMs: result.timings.insertMs,
            totalMs: result.timings.totalMs,
            audioFileName: input.audioFileName)
    }
}
