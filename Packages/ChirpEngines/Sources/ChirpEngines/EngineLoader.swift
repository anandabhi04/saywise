import ChirpCore
import Foundation

public enum EngineLoader {
    public static func transcriber(
        for engine: SpeechEngine, modelsDirectory: URL,
        progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> any Transcriber {
        switch engine {
        case .whisper:
            try await WhisperKitTranscriber.load(modelsDirectory: modelsDirectory, progress: progress)
        case .qwen3ASR:
            try await Qwen3ASRTranscriber.load(modelsDirectory: modelsDirectory, progress: progress)
        }
    }
}
