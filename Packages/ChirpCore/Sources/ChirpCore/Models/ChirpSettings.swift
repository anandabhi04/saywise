import Foundation

public struct ChirpSettings: Codable, Equatable, Sendable {
    public static let defaultCleanupModelID = "mlx-community/Qwen3-4B-Instruct-2507-4bit"

    public var triggerKey: TriggerKey = .fn
    public var soundsEnabled = true
    public var launchAtLogin = false
    public var languageMode: LanguageMode = .auto
    public var speechEngine: SpeechEngine = .whisper
    public var cleanupModelID = ChirpSettings.defaultCleanupModelID
    public var dictionary: [DictionaryEntry] = []
    public var snippets: [Snippet] = []
    /// Bundle id to style. Wins over every built-in rule.
    public var appStyles: [String: Style] = [:]
    public var titleRules: [TitleRule] = TitleRule.defaults
    public var historyRetention: HistoryRetention = .days30
    public var keepAudio = false

    public init() {}

    // Missing keys fall back to defaults, so a settings file from an older build still loads.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ChirpSettings()
        triggerKey = try c.decodeIfPresent(TriggerKey.self, forKey: .triggerKey) ?? d.triggerKey
        soundsEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundsEnabled) ?? d.soundsEnabled
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? d.launchAtLogin
        languageMode = try c.decodeIfPresent(LanguageMode.self, forKey: .languageMode) ?? d.languageMode
        speechEngine = try c.decodeIfPresent(SpeechEngine.self, forKey: .speechEngine) ?? d.speechEngine
        cleanupModelID = try c.decodeIfPresent(String.self, forKey: .cleanupModelID) ?? d.cleanupModelID
        dictionary = try c.decodeIfPresent([DictionaryEntry].self, forKey: .dictionary) ?? d.dictionary
        snippets = try c.decodeIfPresent([Snippet].self, forKey: .snippets) ?? d.snippets
        appStyles = try c.decodeIfPresent([String: Style].self, forKey: .appStyles) ?? d.appStyles
        titleRules = try c.decodeIfPresent([TitleRule].self, forKey: .titleRules) ?? d.titleRules
        historyRetention = try c.decodeIfPresent(HistoryRetention.self, forKey: .historyRetention) ?? d.historyRetention
        keepAudio = try c.decodeIfPresent(Bool.self, forKey: .keepAudio) ?? d.keepAudio
    }
}
