import Foundation
import Testing
@testable import ChirpCore

struct FilterTests {
    func tone(seconds: Double, amplitude: Float) -> [Float] {
        let count = Int(seconds * Double(SilenceFilter.sampleRate))
        return (0..<count).map { amplitude * sin(Float($0) * 0.1) }
    }

    @Test func silenceHasNoSpeech() {
        #expect(!SilenceFilter.hasSpeech(Array(repeating: 0, count: 16_000)))
    }

    @Test func loudToneCountsAsSpeech() {
        let samples = tone(seconds: 1, amplitude: 0.2)
        #expect(SilenceFilter.hasSpeech(samples))
        #expect(abs(SilenceFilter.speechSeconds(in: samples) - 0.99) < 0.02)
    }

    @Test func shortBlipIsNotSpeech() {
        let samples = tone(seconds: 0.1, amplitude: 0.2) + Array(repeating: 0, count: 16_000)
        #expect(!SilenceFilter.hasSpeech(samples))
    }

    @Test func dropsKnownPhrasesOnlyWhenSpeechIsShort() {
        #expect(HallucinationFilter.isLikely("Thank you for watching!", speechSeconds: 0.5))
        #expect(!HallucinationFilter.isLikely("Thank you for watching!", speechSeconds: 3))
        #expect(HallucinationFilter.isLikely("[BLANK_AUDIO]", speechSeconds: 5))
        #expect(HallucinationFilter.isLikely("  ", speechSeconds: 5))
        #expect(!HallucinationFilter.isLikely("Thank you, Priya", speechSeconds: 0.5))
    }

    @Test func keepsShortRealThankYou() {
        #expect(!HallucinationFilter.isLikely("Thank you.", speechSeconds: 0.6))
        #expect(HallucinationFilter.isLikely("Thank you for watching.", speechSeconds: 0.6))
    }
}
