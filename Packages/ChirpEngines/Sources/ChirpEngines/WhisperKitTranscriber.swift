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
        // Download first (a no-op when the files are there) so the setup window can show progress.
        let folder = try await WhisperKit.download(
            variant: modelName,
            downloadBase: modelsDirectory.appendingPathComponent("whisperkit", isDirectory: true),
            progressCallback: { progress($0.fractionCompleted) })
        let config = WhisperKitConfig(
            modelFolder: folder.path, verbose: false, prewarm: true, load: true, download: false)
        return WhisperKitTranscriber(kit: try await WhisperKit(config))
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
