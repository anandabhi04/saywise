import Testing
@testable import ChirpCore

struct SnippetEngineTests {
    let email = Snippet(trigger: "my email", expansion: "me@example.com")
    let address = Snippet(trigger: "my address", expansion: "12 Park Road")

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
