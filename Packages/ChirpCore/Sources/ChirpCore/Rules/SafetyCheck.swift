import Foundation

public enum CleanupRejection: String, Codable, Sendable {
    case timeout, failed, empty, tooShort, tooLong, placeholderChanged, looksLikeAnswer, translated
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
        if looksTranslated(input: input, output: trimmed) { return .translated }
        return nil
    }

    static let minSharedWords = 0.5

    /// A cleanup keeps the speaker's words. A translation shares almost none of them.
    /// Words are compared by their consonants, so "sakate" and "sakte" or "men" and "mein" match.
    static func looksTranslated(input: String, output: String) -> Bool {
        let outputWords = words(output)
        guard outputWords.count >= 4 else { return false }
        let spoken = Set(words(input).map(skeleton))
        let shared = outputWords.filter { spoken.contains(skeleton($0)) }.count
        return Double(shared) / Double(outputWords.count) < minSharedWords
    }

    private static func words(_ text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    private static func skeleton(_ word: String) -> String {
        var out = ""
        for c in word where !"aeiou".contains(c) && out.last != c { out.append(c) }
        return out.isEmpty ? word : out
    }

    static func placeholderSet(in text: String) -> Set<String> {
        guard let regex = try? NSRegularExpression(pattern: "⟦S\\d+⟧") else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return Set(regex.matches(in: text, range: range).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        })
    }

    /// "Sure, here is..." is an answer, unless the speaker said that word or phrase too.
    static func looksLikeAnswer(input: String, output: String) -> Bool {
        let out = output.lowercased()
        return answerOpeners.contains { opener in
            startsWithWord(out, opener) && !containsWholeWord(input, opener)
        }
    }

    private static func containsWholeWord(_ text: String, _ phrase: String) -> Bool {
        guard let regex = TextNormalizer.wholeWordRegex(phrase) else { return false }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private static func startsWithWord(_ text: String, _ word: String) -> Bool {
        guard text.hasPrefix(word) else { return false }
        guard let next = text.dropFirst(word.count).first else { return true }
        return !next.isLetter
    }
}
