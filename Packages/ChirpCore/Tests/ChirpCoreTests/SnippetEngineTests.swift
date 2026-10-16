import Testing
@testable import ChirpCore

struct SnippetEngineTests {
    let email = Snippet(trigger: "my email", expansion: "me@example.com")
    let address = Snippet(trigger: "my address", expansion: "12 Park Road")

    @Test func blankTriggersAreIgnored() {
        let blank = [Snippet(trigger: "", expansion: "wrong"), Snippet(trigger: " \t\n ", expansion: "wrong")]
        let snippets = blank + [Snippet(trigger: "addr", expansion: "first address")]
        #expect(SnippetEngine.wholeMatch(" \n", in: snippets) == nil)
        let protected = SnippetEngine.protect("send addr now", snippets: snippets)
        #expect(protected.text == "send ⟦S1⟧ now")
        #expect(protected.expansions == ["⟦S1⟧": "first address"])
    }

    @Test func duplicateTriggersUseFirstSnippet() {
        let first = Snippet(trigger: "addr", expansion: "first address")
        let duplicate = Snippet(trigger: "ADDR", expansion: "second address")
        let snippets = [first, duplicate]
        #expect(SnippetEngine.wholeMatch("ADDR", in: snippets) == first)
        let protected = SnippetEngine.protect("addr and ADDR", snippets: snippets)
        #expect(protected.text == "⟦S1⟧ and ⟦S1⟧")
        #expect(protected.expansions == ["⟦S1⟧": "first address"])
        #expect(SnippetEngine.expandInline("addr and ADDR", snippets: snippets)
            == "first address and first address")
    }

    @Test func wholeMatchIgnoresCaseAndEndPunctuation() {
        #expect(SnippetEngine.wholeMatch("My email.", in: [email, address]) == email)
        #expect(SnippetEngine.wholeMatch("send my email", in: [email, address]) == nil)
    }

    @Test func protectsAndExpandsInlineTriggers() {
        let protected = SnippetEngine.protect("Send it to my email please", snippets: [email, address])
        #expect(protected.text == "Send it to ⟦S2⟧ please")
        #expect(SnippetEngine.expand(protected.text, using: protected.expansions)
            == "Send it to me@example.com please")
    }

    @Test func sameSnippetGetsSamePlaceholderInDifferentTexts() {
        let a = SnippetEngine.protect("my address", snippets: [email, address])
        let b = SnippetEngine.protect("my email and my address", snippets: [email, address])
        #expect(a.expansions.first { $0.value == "12 Park Road" }?.key
            == b.expansions.first { $0.value == "12 Park Road" }?.key)
    }

    @Test func expandInlineWithNoTriggerReturnsText() {
        #expect(SnippetEngine.expandInline("hello there", snippets: [email]) == "hello there")
    }
}
