import ChirpCore
import Foundation
import HuggingFace
import MLX
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

public actor MLXCleaner: Cleaner {
    // Only evaluated instruction caches cross isolation; generation always uses a deep copy.
    private final class InstructionPrefix: @unchecked Sendable {
        let instructions: String
        let tokens: [Int]
        let cache: [KVCache]

        init(instructions: String, tokens: [Int], cache: [KVCache]) {
            self.instructions = instructions
            self.tokens = tokens
            self.cache = cache
        }
    }

    private var prefixes: [Style: InstructionPrefix] = [:]
    private let container: ModelContainer

    private init(container: ModelContainer) { self.container = container }

    public static func load(
        modelID: String, modelsDirectory: URL,
        progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> MLXCleaner {
        let hub = HubClient(cache: HubCache(
            cacheDirectory: modelsDirectory.appendingPathComponent("huggingface", isDirectory: true)))
        guard let repo = Repo.ID(rawValue: modelID) else {
            throw CocoaError(.fileReadInvalidFileName)
        }
        let marker = ".chirp-complete"
        if let folder = try? await hub.downloadSnapshot(of: repo, localFilesOnly: true),
           FileManager.default.fileExists(atPath: folder.appendingPathComponent(marker).path) {
            let container = try await loadModelContainer(
                from: folder, using: #huggingFaceTokenizerLoader())
            return MLXCleaner(container: container)
        }
        let container = try await loadModelContainer(
            from: #hubDownloader(hub),
            using: #huggingFaceTokenizerLoader(),
            configuration: ModelConfiguration(id: modelID),
            progressHandler: { progress($0.fractionCompleted) })
        // Mark only after weights and tokenizer have loaded successfully.
        let folder = try await hub.downloadSnapshot(of: repo, localFilesOnly: true)
        try Data().write(to: folder.appendingPathComponent(marker), options: .atomic)
        return MLXCleaner(container: container)
    }

    public func clean(_ request: CleanupRequest) async throws -> String {
        let existing = prefixes[request.style]
        let (stream, prefix) = try await container.perform {
            (context: ModelContext) async throws -> (AsyncStream<Generation>, InstructionPrefix) in
            let input = try await context.processor.prepare(input: UserInput(
                chat: [.system(request.instructions), .user(request.userMessage)],
                additionalContext: ["enable_thinking": false]))
            let tokens = input.text.tokens.asArray(Int.self)
            let prefix: InstructionPrefix
            if let existing, existing.instructions == request.instructions {
                prefix = existing
            } else {
                // Some chat templates require a user turn.
                let instructionTokens = (try? context.tokenizer.applyChatTemplate(
                    messages: [["role": "system", "content": request.instructions]],
                    tools: nil, additionalContext: ["enable_thinking": false])) ?? []
                let prefixTokens = zip(instructionTokens, tokens).prefix { $0 == $1 }.map { $0.0 }
                let cache = context.model.newCache(parameters: GenerateParameters())
                if !prefixTokens.isEmpty, tokens.starts(with: prefixTokens), prefixTokens.count < tokens.count {
                    _ = context.model(MLXArray(prefixTokens)[.newAxis], cache: cache)
                    eval(cache)
                    prefix = InstructionPrefix(instructions: request.instructions, tokens: prefixTokens, cache: cache)
                } else {
                    prefix = InstructionPrefix(instructions: request.instructions, tokens: [], cache: cache)
                }
            }
            // Validate the token boundary before dropping the prefix from the full prompt.
            let matches = tokens.starts(with: prefix.tokens) && prefix.tokens.count < tokens.count
            let cache = matches ? prefix.cache.map { $0.copy() } : context.model.newCache(parameters: GenerateParameters())
            let remaining = matches ? Array(tokens.dropFirst(prefix.tokens.count)) : tokens
            let stream = try MLXLMCommon.generate(
                input: LMInput(tokens: MLXArray(remaining)), cache: cache,
                parameters: GenerateParameters(maxTokens: request.maxTokens, temperature: 0), context: context)
            return (stream, prefix)
        }
        prefixes[request.style] = prefix
        var output = ""
        for await generation in stream {
            try Task.checkCancellation()
            if case let .chunk(text) = generation { output += text }
        }
        return output
    }

    /// The first generation compiles Metal kernels. Doing it at launch keeps the first dictation fast.
    public func warmUp() async {
        _ = try? await clean(CleanupPromptBuilder.build(
            text: "um this is a quick warm up sentence", style: .other, dictionaryWords: []))
    }
}
