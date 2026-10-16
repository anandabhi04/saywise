import Foundation

enum TextNormalizer {
    static let edgePunctuation = CharacterSet(charactersIn: ".,!?;:\"'")

    /// Lowercased, trimmed, with punctuation removed from both ends.
    static func loose(_ text: String) -> String {
        text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: edgePunctuation)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }

    /// A case-insensitive regex for `phrase` that only matches whole words.
    static func wholeWordRegex(_ phrase: String) -> NSRegularExpression? {
        let pattern = "(?<![\\p{L}\\p{N}\\p{M}])" + NSRegularExpression.escapedPattern(for: phrase) + "(?![\\p{L}\\p{N}\\p{M}])"
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }
}
