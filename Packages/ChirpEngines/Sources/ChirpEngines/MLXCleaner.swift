import ChirpCore
import Foundation
import HuggingFace
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

public final class MLXCleaner: Cleaner {
    private let container: ModelContainer

    private init(container: ModelContainer) { self.container = container }

    public static func load(
        modelID: String, modelsDirectory: URL,
        progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> MLXCleaner {
        let hub = HubClient(cache: HubCache(
            cacheDirectory: modelsDirectory.appendingPathComponent("huggingface", isDirectory: true)))
        let container = try await loadModelContainer(
            from: #hubDownloader(hub),
            using: #huggingFaceTokenizerLoader(),
            configuration: ModelConfiguration(id: modelID),
            progressHandler: { progress($0.fractionCompleted) })
        return MLXCleaner(container: container)
    }

    public func clean(_ request: CleanupRequest) async throws -> String {
        // A fresh session per call: no chat history leaks between dictations.
        let session = ChatSession(
            container,
            instructions: request.instructions,
            generateParameters: GenerateParameters(maxTokens: request.maxTokens, temperature: 0),
            additionalContext: ["enable_thinking": false])
        return try await session.respond(to: request.userMessage)
    }

    /// The first generation compiles Metal kernels. Doing it at launch keeps the first dictation fast.
    public func warmUp() async {
        _ = try? await clean(CleanupPromptBuilder.build(
            text: "um this is a quick warm up sentence", style: .other, dictionaryWords: []))
    }
}
