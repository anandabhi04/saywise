import Foundation
import Testing
@testable import ChirpCore

struct DictationPipelineTests {
    let slack = AppContext(bundleID: "com.tinyspeck.slackmacgap", appName: "Slack")
    let notes = AppContext(bundleID: "com.apple.Notes", appName: "Notes")

    func pipeline(
        transcript: String,
        transcribeError: Error? = nil,
        cleaner: FakeCleaner = FakeCleaner(reply: { _ in "Cleaned text here." }),
        inserter: RecordingInserter = RecordingInserter(),
        history: (any HistoryWriting)? = RecordingHistory(),
        timeout: Duration = .seconds(2)
    ) -> DictationPipeline {
        DictationPipeline(
            transcriber: FakeTranscriber(text: transcript, error: transcribeError),
            cleaner: cleaner, inserter: inserter, history: history, cleanupTimeout: timeout,
            now: { Date(timeIntervalSince1970: 1000) })
    }

    func delivered(_ outcome: DictationOutcome) -> DictationResult? {
        if case let .delivered(result) = outcome { return result }
        return nil
    }

    @Test func silenceProducesNoSpeechAndNoPaste() async {
        let inserter = RecordingInserter()
        let p = pipeline(transcript: "hello", inserter: inserter)
        let outcome = await p.run(DictationInput(samples: Array(repeating: 0, count: 16_000), context: notes, settings: ChirpSettings()))
        #expect(outcome == .noSpeech)
        #expect(inserter.inserted.withLock { $0 }.isEmpty)
    }

    @Test func hallucinationProducesNoSpeech() async {
        let short = Array(speechSamples.prefix(8_000)) + Array(repeating: 0, count: 8_000)
        let outcome = await pipeline(transcript: "Thank you for watching.")
            .run(DictationInput(samples: short, context: notes, settings: ChirpSettings()))
        #expect(outcome == .noSpeech)
    }

    @Test func transcriptionErrorIsReported() async {
        let outcome = await pipeline(transcript: "", transcribeError: TestError())
            .run(DictationInput(samples: speechSamples, context: notes, settings: ChirpSettings()))
        guard case .transcriptionFailed = outcome else {
            Issue.record("expected transcriptionFailed, got \(outcome)")
            return
        }
    }

    @Test func usesCleanedTextPastesAndSavesHistory() async throws {
        let inserter = RecordingInserter()
        let history = RecordingHistory()
        let cleaner = FakeCleaner(reply: { _ in "Can we move the sync to Friday?" })
        let outcome = await pipeline(transcript: "um can we move the sync to friday", cleaner: cleaner, inserter: inserter, history: history)
            .run(DictationInput(samples: speechSamples, context: notes, settings: ChirpSettings()))
        let result = try #require(delivered(outcome))
        #expect(result.finalText == "Can we move the sync to Friday?")
        #expect(result.cleanup == .used)
        #expect(result.style == .document)
        #expect(inserter.inserted.withLock { $0 } == ["Can we move the sync to Friday?"])
        let saved = history.entries.withLock { $0 }
        #expect(saved.count == 1)
        #expect(saved.first?.rawText == "um can we move the sync to friday")
        #expect(saved.first?.cleanup == "used")
        #expect(saved.first?.appBundleID == "com.apple.Notes")
    }

    @Test func shortTextSkipsCleanup() async {
        let cleaner = FakeCleaner(reply: { _ in Issue.record("cleaner must not run"); return "" })
        let result = delivered(await pipeline(transcript: "Sounds good.", cleaner: cleaner)
            .run(DictationInput(samples: speechSamples, context: slack, settings: ChirpSettings())))
        #expect(result?.cleanup == .skipped)
        #expect(result?.finalText == "Sounds good")
    }

    @Test func rawStyleSkipsCleanup() async {
        var settings = ChirpSettings()
        settings.appStyles["com.apple.Notes"] = .raw
        let cleaner = FakeCleaner(reply: { _ in Issue.record("cleaner must not run"); return "" })
        let result = delivered(await pipeline(transcript: "um this stays exactly as spoken", cleaner: cleaner)
            .run(DictationInput(samples: speechSamples, context: notes, settings: settings)))
        #expect(result?.cleanup == .skipped)
        #expect(result?.finalText == "um this stays exactly as spoken")
    }

    @Test func slowCleanupFallsBackToRawText() async {
        let cleaner = FakeCleaner(reply: { _ in "Too late." }, delay: .seconds(5))
        let clock = ContinuousClock()
        let start = clock.now
        let result = delivered(await pipeline(transcript: "this is the raw text from whisper", cleaner: cleaner, timeout: .milliseconds(100))
            .run(DictationInput(samples: speechSamples, context: notes, settings: ChirpSettings())))
        #expect(result?.cleanup == .rejected(.timeout))
        #expect(result?.finalText == "this is the raw text from whisper")
        #expect(clock.now - start < .seconds(2))
    }

    @Test func failingCleanupFallsBack() async {
        let cleaner = FakeCleaner(reply: { _ in "" }, error: TestError())
        let result = delivered(await pipeline(transcript: "this is the raw text from whisper", cleaner: cleaner)
            .run(DictationInput(samples: speechSamples, context: notes, settings: ChirpSettings())))
        #expect(result?.cleanup == .rejected(.failed))
    }

    @Test func answerLikeCleanupIsRejected() async {
        let cleaner = FakeCleaner(reply: { _ in "Sure! The capital of France is Paris." })
        let result = delivered(await pipeline(transcript: "what is the capital of france", cleaner: cleaner)
            .run(DictationInput(samples: speechSamples, context: notes, settings: ChirpSettings())))
        #expect(result?.cleanup == .rejected(.looksLikeAnswer))
        #expect(result?.finalText == "what is the capital of france")
    }

    @Test func wholeSnippetSkipsCleanup() async {
        var settings = ChirpSettings()
        settings.snippets = [Snippet(trigger: "my email", expansion: "me@example.com")]
        let result = delivered(await pipeline(transcript: "My email.")
            .run(DictationInput(samples: speechSamples, context: notes, settings: settings)))
        #expect(result?.cleanup == .snippet)
        #expect(result?.finalText == "me@example.com")
    }

    @Test func wholeSnippetInCodeStyleIsPastedVerbatim() async throws {
        var settings = ChirpSettings()
        settings.snippets = [Snippet(trigger: "sign off", expansion: "Best regards")]
        let inserter = RecordingInserter()
        let history = RecordingHistory()
        let cleaner = FakeCleaner(reply: { _ in Issue.record("cleaner must not run"); return "" })
        let result = try #require(delivered(await pipeline(
            transcript: "Sign off.", cleaner: cleaner, inserter: inserter, history: history)
            .run(DictationInput(samples: speechSamples,
                context: AppContext(bundleID: "com.apple.dt.Xcode"), settings: settings))))
        #expect(result.style == .code)
        #expect(result.cleanup == .snippet)
        #expect(result.finalText == "Best regards")
        #expect(inserter.inserted.withLock { $0 } == ["Best regards"])
        #expect(history.entries.withLock { $0.first?.finalText } == "Best regards")
    }

    @Test func inlineSnippetSurvivesCleanup() async {
        var settings = ChirpSettings()
        settings.snippets = [Snippet(trigger: "my email", expansion: "me@example.com")]
        let cleaner = FakeCleaner(reply: { request in
            #expect(request.userMessage.contains("⟦S1⟧"))
            return "Please send the report to ⟦S1⟧ today."
        })
        let result = delivered(await pipeline(transcript: "um please send the report to my email today", cleaner: cleaner)
            .run(DictationInput(samples: speechSamples, context: notes, settings: settings)))
        #expect(result?.finalText == "Please send the report to me@example.com today.")
    }

    @Test func dictionaryFixesApplyAndUsedWordsAreReported() async {
        var settings = ChirpSettings()
        let entry = DictionaryEntry(word: "UnifyApps", spokenForms: ["unify apps"])
        settings.dictionary = [entry]
        let cleaner = FakeCleaner(reply: { request in
            #expect(request.userMessage.contains("UnifyApps"))
            return "I joined UnifyApps last year."
        })
        let result = delivered(await pipeline(transcript: "i joined unify apps last year", cleaner: cleaner)
            .run(DictationInput(samples: speechSamples, context: notes, settings: settings)))
        #expect(result?.finalText == "I joined UnifyApps last year.")
        #expect(result?.usedDictionaryEntryIDs == [entry.id])
    }

    @Test func hindiOutputIsRomanizedEvenWhenCleanupSkipped() async {
        var settings = ChirpSettings()
        settings.appStyles["com.apple.Notes"] = .raw
        let result = delivered(await pipeline(transcript: "कल meeting है, 5 बजे")
            .run(DictationInput(samples: speechSamples, context: notes, settings: settings)))
        #expect(result?.finalText == "kal meeting hai, 5 baje")
    }

    @Test func devanagariFromCleanerIsRomanized() async {
        let cleaner = FakeCleaner(reply: { _ in "कल meeting है, 5 बजे?" })
        let result = delivered(await pipeline(transcript: "कल meeting है matlab 5 बजे", cleaner: cleaner)
            .run(DictationInput(samples: speechSamples, context: notes, settings: ChirpSettings())))
        #expect(result?.cleanup == .used)
        #expect(result?.finalText == "kal meeting hai, 5 baje?")
    }

    @Test func cleanerSeesHindiInRomanLetters() async {
        let cleaner = FakeCleaner(reply: { request in
            #expect(!Romanizer.containsDevanagari(request.userMessage))
            #expect(request.userMessage.contains("kya"))
            return "kya meri hindi tum samajh sakte ho bhai?"
        })
        let result = delivered(await pipeline(transcript: "क्या मेरी हिंदी तुम समझ सकते हो भाई", cleaner: cleaner)
            .run(DictationInput(samples: speechSamples, context: notes, settings: ChirpSettings())))
        #expect(result?.cleanup == .used)
    }

    @Test func translatedCleanupFallsBackToRomanLetters() async {
        let cleaner = FakeCleaner(reply: { _ in "Can you understand my Hindi, brother?" })
        let result = delivered(await pipeline(transcript: "क्या मेरी हिंदी तुम समझ सकते हो भाई", cleaner: cleaner)
            .run(DictationInput(samples: speechSamples, context: notes, settings: ChirpSettings())))
        #expect(result?.cleanup == .rejected(.translated))
        #expect(result?.finalText == Romanizer.romanize("क्या मेरी हिंदी तुम समझ सकते हो भाई"))
    }

    @Test func noHistoryWhenStoreIsNil() async {
        let result = delivered(await pipeline(transcript: "this is a longer sentence here", history: nil)
            .run(DictationInput(samples: speechSamples, context: notes, settings: ChirpSettings())))
        #expect(result != nil)
    }

    @Test func historyFailureDoesNotBlockDelivery() async {
        let inserter = RecordingInserter()
        let cleaner = FakeCleaner(reply: { _ in "Can we move the sync to Friday?" })
        let outcome = await pipeline(transcript: "um can we move the sync to friday", cleaner: cleaner, inserter: inserter, history: ThrowingHistory())
            .run(DictationInput(samples: speechSamples, context: notes, settings: ChirpSettings()))
        #expect(delivered(outcome)?.finalText == "Can we move the sync to Friday?")
        #expect(inserter.inserted.withLock { $0 } == ["Can we move the sync to Friday?"])
    }
}
