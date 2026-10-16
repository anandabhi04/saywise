import Foundation

public struct ProtectedText: Equatable, Sendable {
    public var text: String
    /// Placeholder to expansion, for example "⟦S1⟧" -> "me@example.com".
    public var expansions: [String: String]
}

public enum SnippetEngine {
    public static func placeholder(_ number: Int) -> String { "⟦S\(number)⟧" }

    public static func wholeMatch(_ text: String, in snippets: [Snippet]) -> Snippet? {
        let spoken = TextNormalizer.loose(text)
        guard !spoken.isEmpty else { return nil }
        return snippets.first { TextNormalizer.loose($0.trigger) == spoken }
    }

    /// Swaps inline triggers for placeholders so the LLM cannot change them.
    /// A snippet's placeholder number comes from its place in the length-sorted list,
    /// so the same snippet gets the same placeholder in any text.
    public static func protect(_ text: String, snippets: [Snippet]) -> ProtectedText {
        var out = text
        var expansions: [String: String] = [:]
        for (index, snippet) in sortedByTriggerLength(snippets).enumerated() {
            let trigger = snippet.trigger.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trigger.isEmpty, let regex = TextNormalizer.wholeWordRegex(trigger) else { continue }
            let range = NSRange(out.startIndex..., in: out)
            guard regex.firstMatch(in: out, range: range) != nil else { continue }
            let token = placeholder(index + 1)
            out = regex.stringByReplacingMatches(
                in: out, range: range, withTemplate: NSRegularExpression.escapedTemplate(for: token))
            expansions[token] = snippet.expansion
        }
        return ProtectedText(text: out, expansions: expansions)
    }

    public static func expand(_ text: String, using expansions: [String: String]) -> String {
        expansions.reduce(text) { $0.replacingOccurrences(of: $1.key, with: $1.value) }
    }

    public static func expandInline(_ text: String, snippets: [Snippet]) -> String {
        let protected = protect(text, snippets: snippets)
        return expand(protected.text, using: protected.expansions)
    }

    private static func sortedByTriggerLength(_ snippets: [Snippet]) -> [Snippet] {
        snippets.sorted {
            $0.trigger.count != $1.trigger.count ? $0.trigger.count > $1.trigger.count : $0.trigger < $1.trigger
        }
    }
}
