import Testing
@testable import ChirpCore

struct WordErrorRateTests {
    @Test func identicalIsZero() {
        #expect(WordErrorRate.compute(reference: "Hello, world!", hypothesis: "hello world") == 0)
    }

    @Test func countsSubstitutionsInsertionsDeletions() {
        #expect(WordErrorRate.compute(reference: "a b c d", hypothesis: "a x c") == 0.5)
        #expect(WordErrorRate.compute(reference: "a b", hypothesis: "a b c d") == 1.0)
    }
}
