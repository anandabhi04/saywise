import Foundation

/// Phrases Whisper is known to produce from near-silence.
public enum HallucinationFilter {
    static let phrases: Set<String> = [
        "thank you", "thanks for watching", "thank you for watching",
        "thank you so much for watching", "please subscribe", "subscribe",
        "you", "bye", "(music)",
    ]

    public static func isLikely(_ text: String, speechSeconds: Double) -> Bool {
        let spoken = TextNormalizer.loose(text)
        if spoken.isEmpty { return true }
        // Tags like [BLANK_AUDIO] or [Music].
        if spoken.hasPrefix("[") && spoken.hasSuffix("]") { return true }
        return speechSeconds < 2.0 && phrases.contains(spoken)
    }
}
