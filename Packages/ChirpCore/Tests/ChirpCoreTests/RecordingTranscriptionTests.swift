import Foundation
import Testing
@testable import ChirpCore

struct RecordingTranscriptionTests {
    let rate = SilenceFilter.sampleRate

    func audio(_ seconds: Int) -> [Float] { Array(repeating: 0.2, count: seconds * rate) }
    func quiet(_ milliseconds: Int) -> [Float] { Array(repeating: 0, count: milliseconds * rate / 1_000) }

    @Test func requiresFifteenSecondsAndThreeHundredMillisecondsOfQuiet() {
        #expect(AudioChunkBoundary.end(in: audio(14) + quiet(300), after: 0) == nil)
        #expect(AudioChunkBoundary.end(in: audio(15) + quiet(290), after: 0) == nil)
        let samples = audio(15) + quiet(300)
        #expect(AudioChunkBoundary.end(in: samples, after: 0) == samples.count)
        #expect(AudioChunkBoundary.end(in: audio(20), after: 0) == nil)
    }

    @Test func ignoresOldGapsAndAlreadyTranscribedAudio() {
        #expect(AudioChunkBoundary.end(in: audio(15) + quiet(300) + audio(6), after: 0) == nil)
        let samples = audio(15) + quiet(300) + audio(10) + quiet(300)
        #expect(AudioChunkBoundary.end(in: samples, after: 15 * rate) == nil)
    }

    @Test func picksNewestGapAndRespectsNonzeroOffset() {
        let samples = audio(16) + quiet(300) + audio(1) + quiet(300) + audio(1)
        #expect(AudioChunkBoundary.end(in: samples, after: rate) == samples.count - rate)
    }

    @Test @MainActor func joinsChunksInOrderAndTranscribesOnlyRemainingAudio() async throws {
        let transcriber = ChunkTranscriber()
        let recording = RecordingTranscription(transcriber: transcriber, language: .hindi, hints: ["Saywise"])
        let first = audio(15) + quiet(300)
        recording.append(first)
        await transcriber.waitForCall()
        recording.append(audio(2))
        let text = try await recording.finish()
        #expect(text == "part1 part2")
        let calls = await transcriber.calls
        #expect(calls.map(\.count) == [first.count, 2 * rate])
        #expect(calls.allSatisfy { $0.language == .hindi && $0.hints == ["Saywise"] })
        #expect(await transcriber.maximumActive == 1)
    }

    @Test @MainActor func serializesChunksAndPicksUpAudioAddedWhileBusy() async throws {
        let transcriber = ChunkTranscriber()
        let recording = RecordingTranscription(transcriber: transcriber, language: .english, hints: [])
        let chunk = audio(15) + quiet(300)
        recording.append(chunk)
        await transcriber.waitForCall()
        recording.append(chunk)
        #expect(recording.chunkCount == 1)
        while recording.chunkCount < 2 { await Task.yield() }
        recording.append(audio(1))
        #expect(try await recording.finish() == "part1 part2 part3")
        #expect(await transcriber.calls.map(\.count) == [chunk.count, chunk.count, rate])
        #expect(await transcriber.maximumActive == 1)
    }

    @Test @MainActor func noGapUsesWholeRecordingAndSilentTailIsSkipped() async throws {
        let transcriber = ChunkTranscriber()
        let recording = RecordingTranscription(transcriber: transcriber, language: .auto, hints: [])
        recording.append(audio(20))
        #expect(try await recording.finish() == "part1")
        #expect(await transcriber.calls.map(\.count) == [20 * rate])
        let silent = RecordingTranscription(transcriber: transcriber, language: .auto, hints: [])
        silent.append(quiet(500))
        #expect(try await silent.finish() == "")
        #expect(await transcriber.calls.count == 1)
    }

    @Test @MainActor func cancellationDropsAnInFlightResultEvenWhenEngineIgnoresCancellation() async {
        let transcriber = ChunkTranscriber()
        let recording = RecordingTranscription(transcriber: transcriber, language: .auto, hints: [])
        recording.append(audio(15) + quiet(300))
        await transcriber.waitForCall()
        recording.cancel()
        do {
            _ = try await recording.finish()
            Issue.record("cancelled recording must not return text")
        } catch is CancellationError {
        } catch { Issue.record("unexpected error: \(error)") }
        #expect(await transcriber.calls.count == 1)
    }

    @Test @MainActor func backgroundFailureIsReportedWithoutRetranscribing() async {
        let transcriber = ChunkTranscriber(fail: true)
        let recording = RecordingTranscription(transcriber: transcriber, language: .english, hints: [])
        recording.append(audio(15) + quiet(300))
        recording.append(audio(2))
        do {
            _ = try await recording.finish()
            Issue.record("expected transcription failure")
        } catch is TestError {
        } catch { Issue.record("unexpected error: \(error)") }
        #expect(await transcriber.calls.count == 1)
    }
}

private actor ChunkTranscriber: Transcriber {
    struct Call: Sendable {
        var count: Int
        var language: LanguageMode
        var hints: [String]
    }
    var calls: [Call] = []
    var active = 0
    var maximumActive = 0
    let fail: Bool

    init(fail: Bool = false) { self.fail = fail }

    func waitForCall() async {
        while calls.isEmpty { await Task.yield() }
    }

    func transcribe(_ samples: [Float], language: LanguageMode, hints: [String]) async throws -> String {
        calls.append(Call(count: samples.count, language: language, hints: hints))
        let index = calls.count
        active += 1
        maximumActive = max(maximumActive, active)
        await Task.detached { try? await Task.sleep(for: .milliseconds(30)) }.value
        active -= 1
        if fail { throw TestError() }
        return " part\(index) "
    }
}
