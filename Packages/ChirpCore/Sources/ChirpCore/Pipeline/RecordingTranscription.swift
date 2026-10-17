import Foundation

public enum AudioChunkBoundary {
    public static let minimumSamples = 15 * SilenceFilter.sampleRate
    private static let frameSize = SilenceFilter.sampleRate / 100
    private static let quietFrames = 30

    public static func end(in samples: [Float], after offset: Int) -> Int? {
        guard samples.count - offset >= minimumSamples else { return nil }
        let start = max(offset, samples.count - 5 * SilenceFilter.sampleRate)
        var quiet = 0
        var candidate: Int?
        for frame in stride(from: start, through: samples.count - frameSize, by: frameSize) {
            var sum: Float = 0
            for i in frame..<(frame + frameSize) { sum += samples[i] * samples[i] }
            if (sum / Float(frameSize)).squareRoot() < SilenceFilter.rmsThreshold {
                quiet += 1
                let end = frame + frameSize
                if quiet >= quietFrames, end - offset >= minimumSamples { candidate = end }
            } else {
                quiet = 0
            }
        }
        return candidate
    }
}

/// Owns one recording, including any transcription still running when recording stops.
@MainActor
public final class RecordingTranscription {
    public private(set) var sampleCount = 0
    public private(set) var chunkCount = 0
    private var samples: [Float] = []
    private var offset = 0
    private var parts: [String] = []
    private var task: Task<Void, Never>?
    private var failure: Error?
    private var stopped = false
    private var cancelled = false
    private let transcriber: any Transcriber
    private let language: LanguageMode
    private let hints: [String]

    public init(transcriber: any Transcriber, language: LanguageMode, hints: [String]) {
        self.transcriber = transcriber
        self.language = language
        self.hints = hints
    }

    public func append(_ buffer: [Float]) {
        guard !stopped else { return }
        samples.append(contentsOf: buffer)
        sampleCount += buffer.count
        startChunkIfReady()
    }

    public func finish() async throws -> String {
        stopped = true
        await task?.value
        try checkFailure()
        if offset < samples.count {
            let text = try await transcribe(Array(samples[offset...]))
            try checkFailure()
            if !text.isEmpty { parts.append(text) }
        }
        samples.removeAll()
        return parts.joined(separator: " ")
    }

    public func cancel() {
        cancelled = true
        stopped = true
        task?.cancel()
        samples.removeAll()
        parts.removeAll()
    }

    private func checkFailure() throws {
        try Task.checkCancellation()
        if cancelled { throw CancellationError() }
        if let failure { throw failure }
    }

    private func startChunkIfReady() {
        guard task == nil, failure == nil, !stopped,
              let end = AudioChunkBoundary.end(in: samples, after: offset) else { return }
        let chunk = Array(samples[offset..<end])
        offset = end
        chunkCount += 1
        task = Task {
            do {
                let text = try await transcribe(chunk)
                try checkFailure()
                if !text.isEmpty { parts.append(text) }
            } catch {
                if !cancelled { failure = error }
            }
            task = nil
            startChunkIfReady()
        }
    }

    private func transcribe(_ chunk: [Float]) async throws -> String {
        let speechSeconds = SilenceFilter.speechSeconds(in: chunk)
        guard speechSeconds >= SilenceFilter.minSpeechSeconds else { return "" }
        let text = try await transcriber.transcribe(chunk, language: language, hints: hints)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return HallucinationFilter.isLikely(text, speechSeconds: speechSeconds) ? "" : text
    }
}
