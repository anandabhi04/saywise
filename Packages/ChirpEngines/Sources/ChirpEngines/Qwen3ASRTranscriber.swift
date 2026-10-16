import ChirpCore
import Foundation
import Qwen3ASR

public final class Qwen3ASRTranscriber: Transcriber, @unchecked Sendable {
    public static let smallModelID = "aufklarer/Qwen3-ASR-0.6B-MLX-4bit"
    public static let largeModelID = "aufklarer/Qwen3-ASR-1.7B-MLX-4bit"

    private let model: Qwen3ASRModel
    /// The model is not safe to call from two threads at once.
    private let lock = NSLock()

    private init(model: Qwen3ASRModel) { self.model = model }

    public static func load(
        modelsDirectory: URL, modelID: String = smallModelID,
        progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> Qwen3ASRTranscriber {
        let folder = modelsDirectory
            .appendingPathComponent("qwen3-asr", isDirectory: true)
            .appendingPathComponent(modelID.replacingOccurrences(of: "/", with: "_"), isDirectory: true)
        let model = try await Qwen3ASRModel.fromPretrained(
            modelId: modelID, cacheDir: folder, progressHandler: { fraction, _ in progress(fraction) })
        return Qwen3ASRTranscriber(model: model)
    }

    public func transcribe(_ samples: [Float], language: LanguageMode, hints: [String]) async throws -> String {
        let context = hints.isEmpty ? nil : hints.joined(separator: ", ")
        let text = lock.withLock {
            model.transcribe(audio: samples, sampleRate: SilenceFilter.sampleRate, language: Self.name(for: language), context: context)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func name(for mode: LanguageMode) -> String? {
        switch mode {
        case .auto: nil
        case .english: "English"
        case .hindi: "Hindi"
        }
    }
}
