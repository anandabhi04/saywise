import Foundation

public enum WhisperHints {
    /// Whisper's prompt holds about 224 tokens. 600 characters stays under that for
    /// typical words. The engine also cuts at the token level.
    public static let characterBudget = 600

    /// Dictionary words for the speech engine prompt, most recently used first.
    public static func words(from entries: [DictionaryEntry], budget: Int = characterBudget) -> [String] {
        let sorted = entries.sorted { a, b in
            switch (a.lastUsedAt, b.lastUsedAt) {
            case let (x?, y?) where x != y: return x > y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.word.localizedCaseInsensitiveCompare(b.word) == .orderedAscending
            }
        }
        var result: [String] = []
        var used = 0
        for entry in sorted {
            guard !entry.word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let cost = entry.word.count + (result.isEmpty ? 0 : 2)
            if used + cost > budget { break }
            result.append(entry.word)
            used += cost
        }
        return result
    }
}
