import Foundation

public enum CleanupRejection: String, Codable, Sendable {
    case timeout, failed, empty, tooShort, tooLong, placeholderChanged, looksLikeAnswer
}

public enum SafetyCheck {
    public static let minRatio = 0.4
    public static let maxRatio = 1.5
    static let answerOpeners = ["sure", "here is", "here's", "i can", "certainly", "of course", "as an ai"]

    /// nil means the LLM output is safe to use.
    public static func evaluate(input: String, output: String, placeholders: [String]) -> CleanupRejection? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .empty }
        let ratio = Double(trimmed.count) / Double(max(input.count, 1))
        if ratio < minRatio { return .tooShort }
        if ratio > maxRatio { return .tooLong }
        if placeholderSet(in: trimmed) != Set(placeholders) { return .placeholderChanged }
        if looksLikeAnswer(input: input, output: trimmed) { return .looksLikeAnswer }
        return nil
    }

    static func placeholderSet(in text: String) -> Set<String> {
        guard let regex = try? NSRegularExpression(pattern: "⟦S\\d+⟧") else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return Set(regex.matches(in: text, range: range).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        })
    }

    /// "Sure, here is..." is an answer, unless the speaker also started with "sure".
    static func looksLikeAnswer(input: String, output: String) -> Bool {
        let out = output.lowercased()
        let inp = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return answerOpeners.contains { opener in
            startsWithWord(out, opener) && !startsWithWord(inp, opener)
        }
    }

    private static func startsWithWord(_ text: String, _ word: String) -> Bool {
        guard text.hasPrefix(word) else { return false }
        guard let next = text.dropFirst(word.count).first else { return true }
        return !next.isLetter
    }
}
