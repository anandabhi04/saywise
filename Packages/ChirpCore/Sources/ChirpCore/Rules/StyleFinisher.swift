import Foundation

/// Small fixed rules applied after cleanup, on every path.
public enum StyleFinisher {
    public static func finish(_ text: String, style: Style) -> String {
        var out = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard style == .chat || style == .code else { return out }
        if out.hasSuffix("."), !out.hasSuffix(".."), isSingleSentence(out) {
            out.removeLast()
        }
        if style == .code { out = lowercasingFirstWord(out) }
        return out
    }

    /// No other sentence mark before the final one.
    static func isSingleSentence(_ text: String) -> Bool {
        !text.dropLast().contains { ".?!\n".contains($0) }
    }

    /// "Git status" -> "git status", but "README" and "iPhone" stay.
    static func lowercasingFirstWord(_ text: String) -> String {
        guard let first = text.first, first.isUppercase else { return text }
        let word = text.prefix { !$0.isWhitespace }
        guard word.dropFirst().allSatisfy({ !$0.isUppercase }) else { return text }
        return first.lowercased() + text.dropFirst()
    }
}
