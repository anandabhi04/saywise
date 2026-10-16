import ChirpCore
import Foundation
import WhisperKit

public actor WhisperKitTranscriber: Transcriber {
    /// Matches only the "openai_whisper-large-v3-v20240930_turbo/" folder in argmaxinc/whisperkit-coreml.
    public static let modelName = "large-v3-v20240930_turbo"
    /// Whisper's prompt limit.
    static let maxPromptTokens = 224

    private let kit: WhisperKit

    private init(kit: WhisperKit) { self.kit = kit }

    public static func load(
        modelsDirectory: URL, progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> WhisperKitTranscriber {
        let base = modelsDirectory.appendingPathComponent("whisperkit", isDirectory: true)
        let folder: URL
        if let existing = downloadedModelFolder(in: base) {
            // WhisperKit.download always asks the Hub for the file list, so skip it once the model is on disk.
            folder = existing
        } else {
            folder = try await WhisperKit.download(
                variant: modelName, downloadBase: base,
                progressCallback: { progress($0.fractionCompleted) })
            // Written only after download returns, so an interrupted download is never trusted.
            FileManager.default.createFile(atPath: folder.appendingPathComponent(completeMarker).path, contents: Data())
        }
        // tokenizerFolder keeps the tokenizer under Chirp's folder: saved on the first load, found there after.
        let config = WhisperKitConfig(
            modelFolder: folder.path, tokenizerFolder: base,
            verbose: false, prewarm: true, load: true, download: false)
        return WhisperKitTranscriber(kit: try await WhisperKit(config))
    }

    /// The folder WhisperKit.download fills: <base>/models/argmaxinc/whisperkit-coreml/openai_whisper-<variant>.
    static let completeMarker = ".chirp-complete"

    static func downloadedModelFolder(in base: URL) -> URL? {
        let folder = base
            .appendingPathComponent("models/argmaxinc/whisperkit-coreml", isDirectory: true)
            .appendingPathComponent("openai_whisper-\(modelName)", isDirectory: true)
        // Files arrive in random order, so file checks alone can pass on a half-finished download.
        let required = [completeMarker, "config.json", "MelSpectrogram.mlmodelc/coremldata.bin",
                        "AudioEncoder.mlmodelc/coremldata.bin", "TextDecoder.mlmodelc/coremldata.bin"]
        let complete = required.allSatisfy {
            FileManager.default.fileExists(atPath: folder.appendingPathComponent($0).path)
        }
        return complete ? folder : nil
    }

    public func transcribe(_ samples: [Float], language: LanguageMode, hints: [String]) async throws -> String {
        var options = DecodingOptions(
            task: .transcribe, language: Self.code(for: language), temperature: 0,
            usePrefillPrompt: true, detectLanguage: language == .auto,
            skipSpecialTokens: true, withoutTimestamps: true)
        if !hints.isEmpty, let tokenizer = kit.tokenizer {
            let tokens = tokenizer.encode(text: " " + hints.joined(separator: ", "))
                .filter { $0 < tokenizer.specialTokens.specialTokenBegin }
            options.promptTokens = Array(tokens.prefix(Self.maxPromptTokens))
        }
        let results = try await kit.transcribe(audioArray: samples, decodeOptions: options)
        return results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func code(for mode: LanguageMode) -> String? {
        switch mode {
        case .auto: nil
        case .english: "en"
        case .hindi: "hi"
        }
    }
}
