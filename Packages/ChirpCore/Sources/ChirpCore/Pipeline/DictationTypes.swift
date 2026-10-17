import Foundation

public enum CleanupStatus: Equatable, Sendable {
    case used
    case skipped
    case snippet
    case rejected(CleanupRejection)

    /// Stored in the history table, for example "rejected.timeout".
    public var storageValue: String {
        switch self {
        case .used: "used"
        case .skipped: "skipped"
        case .snippet: "snippet"
        case let .rejected(reason): "rejected.\(reason.rawValue)"
        }
    }
}

public struct StepTimings: Equatable, Sendable {
    public var transcribeMs = 0
    public var cleanupMs = 0
    public var insertMs = 0
    public var totalMs = 0

    public init() {}
}

public struct DictationInput: Sendable {
    public var samples: [Float]
    public var context: AppContext
    public var settings: ChirpSettings
    public var audioFileName: String?
    public var rawText: String?
    public var remainingTranscribeMs = 0

    public init(samples: [Float], context: AppContext, settings: ChirpSettings, audioFileName: String? = nil, rawText: String? = nil) {
        self.samples = samples
        self.context = context
        self.settings = settings
        self.audioFileName = audioFileName
        self.rawText = rawText
    }
}

public struct DictationResult: Equatable, Sendable {
    public var rawText: String
    public var finalText: String
    public var style: Style
    public var cleanup: CleanupStatus
    public var insert: InsertOutcome
    public var timings: StepTimings
    public var usedDictionaryEntryIDs: Set<UUID>
}

public enum DictationOutcome: Equatable, Sendable {
    case noSpeech
    case transcriptionFailed(String)
    case delivered(DictationResult)
}
