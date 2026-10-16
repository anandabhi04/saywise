import Foundation

public enum Style: String, Codable, CaseIterable, Sendable {
    case chat, email, code, document, raw
    /// Every app with no rule. Cleans like `document`.
    case other

    public var displayName: String {
        switch self {
        case .chat: "Chat"
        case .email: "Email"
        case .code: "Code"
        case .document: "Document"
        case .raw: "Raw"
        case .other: "Default"
        }
    }
}

public enum LanguageMode: String, Codable, CaseIterable, Sendable {
    case auto, english, hindi
}

public enum SpeechEngine: String, Codable, CaseIterable, Sendable {
    case whisper, qwen3ASR
}

public enum TriggerKey: String, Codable, CaseIterable, Sendable {
    case fn, rightOption, rightCommand, rightControl
}

public enum HistoryRetention: String, Codable, CaseIterable, Sendable {
    case off, days7, days30, forever

    /// nil means keep forever.
    public var days: Int? {
        switch self {
        case .off: 0
        case .days7: 7
        case .days30: 30
        case .forever: nil
        }
    }
}

public struct DictionaryEntry: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    /// Spelled exactly like this in the output.
    public var word: String
    /// Fix rules: each spoken form is replaced by `word`.
    public var spokenForms: [String]
    public var lastUsedAt: Date?

    public init(id: UUID = UUID(), word: String, spokenForms: [String] = [], lastUsedAt: Date? = nil) {
        self.id = id
        self.word = word
        self.spokenForms = spokenForms
        self.lastUsedAt = lastUsedAt
    }
}

public struct Snippet: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var trigger: String
    public var expansion: String

    public init(id: UUID = UUID(), trigger: String, expansion: String) {
        self.id = id
        self.trigger = trigger
        self.expansion = expansion
    }
}

public struct TitleRule: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    /// Case-insensitive text to look for in a browser window title.
    public var contains: String
    public var style: Style

    public init(id: UUID = UUID(), contains: String, style: Style) {
        self.id = id
        self.contains = contains
        self.style = style
    }

    public static let defaults: [TitleRule] = [
        TitleRule(contains: "Gmail", style: .email),
        TitleRule(contains: "Outlook", style: .email),
        TitleRule(contains: "Slack", style: .chat),
        TitleRule(contains: "WhatsApp", style: .chat),
        TitleRule(contains: "Google Docs", style: .document),
        TitleRule(contains: "Notion", style: .document),
    ]
}

public struct AppContext: Equatable, Sendable {
    public var bundleID: String?
    public var appName: String?
    public var windowTitle: String?

    public init(bundleID: String? = nil, appName: String? = nil, windowTitle: String? = nil) {
        self.bundleID = bundleID
        self.appName = appName
        self.windowTitle = windowTitle
    }
}
