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

    @Test func openerAnywhereInInputIsTheSpeakers() {
        #expect(SafetyCheck.evaluate(input: "um i can come at five", output: "I can come at five.", placeholders: []) == nil)
    }

    @Test func rejectsAnswersButNotSpeakerWhoSaidSure() {
        let question = "what is the capital of france"
        #expect(SafetyCheck.evaluate(input: question, output: "Sure! It is Paris.", placeholders: []) == .looksLikeAnswer)
        #expect(SafetyCheck.evaluate(input: "sure i will be there at five", output: "Sure, I will be there at 5.", placeholders: []) == nil)
    }

    @Test func rejectsHindiTranslatedToEnglish() {
        let spoken = Romanizer.romanize("क्या मेरी हिंदी तुम समझ सकते हो भाई")
        #expect(SafetyCheck.evaluate(input: spoken, output: "Can you understand my Hindi, brother?", placeholders: []) == .translated)
    }

    @Test func acceptsOtherSpellingsOfTheSameHindiWords() {
        let spoken = Romanizer.romanize("क्या तुम हिंगलिस में लिख सकते हो मेरी चीजे")
        #expect(SafetyCheck.evaluate(input: spoken, output: "kya tum hinglish mein likh sakte ho meri cheezein?", placeholders: []) == nil)
    }

    @Test func acceptsHinglishCleanup() {
        let input = "um kal ki meeting matlab cancel ho gayi hai kya"
        #expect(SafetyCheck.evaluate(input: input, output: "Kal ki meeting cancel ho gayi hai kya?", placeholders: []) == nil)
    }
}
