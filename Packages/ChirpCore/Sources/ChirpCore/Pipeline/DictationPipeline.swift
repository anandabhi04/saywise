import Foundation

/// Runs one dictation from audio to pasted text. Spec section 4.
public struct DictationPipeline: Sendable {
    public var transcriber: any Transcriber
    public var cleaner: any Cleaner
    public var inserter: any TextInserter
    public var history: (any HistoryWriting)?
    public var cleanupTimeout: Duration
    public var now: @Sendable () -> Date

    public init(
        transcriber: any Transcriber,
        cleaner: any Cleaner,
        inserter: any TextInserter,
        history: (any HistoryWriting)?,
        cleanupTimeout: Duration = .seconds(2),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.transcriber = transcriber
        self.cleaner = cleaner
        self.inserter = inserter
        self.history = history
        self.cleanupTimeout = cleanupTimeout
        self.now = now
    }

    public func run(_ input: DictationInput) async -> DictationOutcome {
        let clock = ContinuousClock()
        let started = clock.now
        let settings = input.settings
        var timings = StepTimings()

        let speechSeconds = SilenceFilter.speechSeconds(in: input.samples)
        guard speechSeconds >= SilenceFilter.minSpeechSeconds else { return .noSpeech }

        let style = StyleResolver.resolve(input.context, settings: settings)

        let raw: String
        let transcribeStart = clock.now
        do {
            raw = try await transcriber.transcribe(
                input.samples, language: settings.languageMode,
                hints: WhisperHints.words(from: settings.dictionary))
        } catch {
            return .transcriptionFailed(String(describing: error))
        }
        timings.transcribeMs = (clock.now - transcribeStart).milliseconds
        if HallucinationFilter.isLikely(raw, speechSeconds: speechSeconds) { return .noSpeech }

        let fixedRaw = DictionaryFixer.apply(settings.dictionary, to: raw)
        let fallback = DictionaryFixer.apply(settings.dictionary, to: Romanizer.romanize(fixedRaw))

        let cleanupStart = clock.now
        var text: String
        var cleanup: CleanupStatus
        if let snippet = SnippetEngine.wholeMatch(fallback, in: settings.snippets) {
            text = snippet.expansion
            cleanup = .snippet
        } else if style == .raw || TextNormalizer.wordCount(fallback) <= 3 {
            text = SnippetEngine.expandInline(fallback, snippets: settings.snippets)
            cleanup = .skipped
        } else {
            (text, cleanup) = await cleaned(fallback, style: style, settings: settings)
        }
        timings.cleanupMs = (clock.now - cleanupStart).milliseconds
        if cleanup != .snippet { text = StyleFinisher.finish(text, style: style) }

        let insertStart = clock.now
        let insert = await inserter.insert(text)
        timings.insertMs = (clock.now - insertStart).milliseconds
        timings.totalMs = (clock.now - started).milliseconds

        let result = DictationResult(
            rawText: raw, finalText: text, style: style, cleanup: cleanup, insert: insert,
            timings: timings,
            usedDictionaryEntryIDs: DictionaryFixer.usedEntryIDs(settings.dictionary, in: text))
        if let history {
            try? await history.save(HistoryEntry(
                result: result, input: input, createdAt: now()))
        }
        return .delivered(result)
    }

    private func cleaned(
        _ fallback: String, style: Style, settings: ChirpSettings
    ) async -> (String, CleanupStatus) {
        // The LLM gets Roman letters. Given Devanagari, it translated Hindi into English.
        let llmInput = SnippetEngine.protect(fallback, snippets: settings.snippets)
        let request = CleanupPromptBuilder.build(
            text: llmInput.text, style: style, dictionaryWords: settings.dictionary.map(\.word))
        let reject = { (reason: CleanupRejection) in
            (SnippetEngine.expand(llmInput.text, using: llmInput.expansions), CleanupStatus.rejected(reason))
        }
        let output: String
        do {
            output = try await Timeout.race(cleanupTimeout) { [cleaner] in try await cleaner.clean(request) }
        } catch is CleanupTimeout {
            return reject(.timeout)
        } catch {
            return reject(.failed)
        }
        let candidate = Romanizer.romanize(CleanupPromptBuilder.extractOutput(output))
        if let reason = SafetyCheck.evaluate(
            input: llmInput.text, output: candidate, placeholders: Array(llmInput.expansions.keys)) {
            return reject(reason)
        }
        return (SnippetEngine.expand(candidate, using: llmInput.expansions), .used)
    }
}
