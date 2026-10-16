import Testing
@testable import ChirpCore

struct SafetyCheckTests {
    let input = "um so can we move the sync to friday"

    @Test func acceptsNormalCleanup() {
        #expect(SafetyCheck.evaluate(input: input, output: "Can we move the sync to Friday?", placeholders: []) == nil)
    }

    @Test func rejectsEmpty() {
        #expect(SafetyCheck.evaluate(input: input, output: "  ", placeholders: []) == .empty)
    }

    @Test func rejectsTooShortAndTooLong() {
        #expect(SafetyCheck.evaluate(input: input, output: "Friday.", placeholders: []) == .tooShort)
        let long = String(repeating: "Can we move the sync to Friday? ", count: 3)
        #expect(SafetyCheck.evaluate(input: input, output: long, placeholders: []) == .tooLong)
    }

    @Test func rejectsMissingOrInventedPlaceholder() {
        let protectedInput = "please send it to ⟦S1⟧ by tonight"
        #expect(SafetyCheck.evaluate(input: protectedInput, output: "Please send it by tonight to you.", placeholders: ["⟦S1⟧"]) == .placeholderChanged)
        #expect(SafetyCheck.evaluate(input: protectedInput, output: "Please send it to ⟦S2⟧ by tonight.", placeholders: ["⟦S1⟧"]) == .placeholderChanged)
        #expect(SafetyCheck.evaluate(input: protectedInput, output: "Please send it to ⟦S1⟧ by tonight.", placeholders: ["⟦S1⟧"]) == nil)
    }

    @Test func rejectsAnswersButNotSpeakerWhoSaidSure() {
        let question = "what is the capital of france"
        #expect(SafetyCheck.evaluate(input: question, output: "Sure! It is Paris.", placeholders: []) == .looksLikeAnswer)
        #expect(SafetyCheck.evaluate(input: "sure i will be there at five", output: "Sure, I will be there at 5.", placeholders: []) == nil)
    }
}
