import Foundation

public enum DictionaryFixer {
    /// Replaces every spoken form with its word. Longer forms go first so
    /// "unify apps platform" wins over "unify apps".
    public static func apply(_ entries: [DictionaryEntry], to text: String) -> String {
        let rules = entries
            .flatMap { entry in entry.spokenForms.map { (spoken: $0, word: entry.word) } }
            .filter { !$0.spoken.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { $0.spoken.count > $1.spoken.count }
        var out = text
        for rule in rules {
            guard let regex = TextNormalizer.wholeWordRegex(rule.spoken) else { continue }
            let range = NSRange(out.startIndex..., in: out)
            out = regex.stringByReplacingMatches(
                in: out, range: range,
                withTemplate: NSRegularExpression.escapedTemplate(for: rule.word))
        }
        return out
    }

    /// Ids of entries whose word appears in `text`. Used to keep recent words first in hints.
    public static func usedEntryIDs(_ entries: [DictionaryEntry], in text: String) -> Set<UUID> {
        var ids = Set<UUID>()
        for entry in entries {
            guard let regex = TextNormalizer.wholeWordRegex(entry.word) else { continue }
            if regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                ids.insert(entry.id)
            }
        }
        return ids
    }
}
