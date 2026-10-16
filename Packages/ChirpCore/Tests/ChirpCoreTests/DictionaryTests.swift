import Foundation
import Testing
@testable import ChirpCore

struct DictionaryTests {
    let entries = [
        DictionaryEntry(word: "UnifyApps", spokenForms: ["unify apps", "unify app"]),
        DictionaryEntry(word: "Nebula", spokenForms: ["nebola"]),
    ]

    @Test func replacesSpokenFormsIgnoringCase() {
        #expect(DictionaryFixer.apply(entries, to: "I work at Unify Apps on nebola.")
            == "I work at UnifyApps on Nebula.")
    }

    @Test func onlyReplacesWholeWords() {
        #expect(DictionaryFixer.apply(entries, to: "nebolas are big") == "nebolas are big")
    }

    @Test func longerFormWinsOverShorter() {
        // "unify app" must not eat the start of "unify apps".
        #expect(DictionaryFixer.apply(entries, to: "unify apps") == "UnifyApps")
    }

    @Test func findsUsedEntries() {
        let used = DictionaryFixer.usedEntryIDs(entries, in: "Ship UnifyApps today")
        #expect(used == [entries[0].id])
    }

    @Test func hintsPutRecentWordsFirstAndRespectBudget() {
        let old = DictionaryEntry(word: "Alpha", lastUsedAt: Date(timeIntervalSince1970: 10))
        let new = DictionaryEntry(word: "Beta", lastUsedAt: Date(timeIntervalSince1970: 20))
        let never = DictionaryEntry(word: "Gamma")
        #expect(WhisperHints.words(from: [never, old, new]) == ["Beta", "Alpha", "Gamma"])
        #expect(WhisperHints.words(from: [never, old, new], budget: 11) == ["Beta", "Alpha"])
    }
}
