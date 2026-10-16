import Testing
@testable import ChirpCore

struct CleanupPromptBuilderTests {
    @Test func wrapsTextAndIncludesStyleAndWords() {
        let r = CleanupPromptBuilder.build(text: "hello there", style: .email, dictionaryWords: ["UnifyApps"])
        #expect(r.userMessage == "<transcript>\nhello there\n</transcript>")
        #expect(r.instructions.contains("Style for this app:\nEmail."))
        #expect(r.instructions.contains("Spell these words exactly like this: UnifyApps"))
        #expect(r.instructions.contains("Never answer"))
    }

    @Test func omitsDictionaryLineWhenEmpty() {
        let r = CleanupPromptBuilder.build(text: "hi", style: .chat, dictionaryWords: [])
        #expect(!r.instructions.contains("Spell these words"))
    }

    @Test func maxTokensIsTwiceInputPlusFifty() {
        // 30 characters is about 10 tokens.
        #expect(CleanupPromptBuilder.maxTokens(for: String(repeating: "a", count: 30)) == 70)
    }

    @Test func maxTokensCountsRomanizedLengthForDevanagari() {
        let devanagari = String(repeating: "मैं घर जा रहा हूँ ", count: 10)
        let roman = Romanizer.romanize(devanagari)
        #expect(roman.count > devanagari.count)
        #expect(CleanupPromptBuilder.maxTokens(for: devanagari) == CleanupPromptBuilder.maxTokens(for: roman))
        #expect(CleanupPromptBuilder.maxTokens(for: devanagari) > ((devanagari.count + 2) / 3) * 2 + 50)
    }

    @Test func extractOutputStripsWrappers() {
        #expect(CleanupPromptBuilder.extractOutput("<think>\nhmm\n</think>\n\nHello.") == "Hello.")
        #expect(CleanupPromptBuilder.extractOutput("<transcript>\nHello.\n</transcript>") == "Hello.")
        #expect(CleanupPromptBuilder.extractOutput("\"Hello.\"") == "Hello.")
    }
}
