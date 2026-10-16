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
        // Once the download is marked complete, offline mode skips the Hub round trip that every launch would make.
        let offline = isDownloaded(folder)
        let model = try await Qwen3ASRModel.fromPretrained(
            modelId: modelID, cacheDir: folder, offlineMode: offline,
            progressHandler: { fraction, _ in progress(fraction) })
        if !offline {
            FileManager.default.createFile(atPath: folder.appendingPathComponent(completeMarker).path, contents: Data())
        }
        return Qwen3ASRTranscriber(model: model)
    }

    static let completeMarker = ".chirp-complete"

    /// Files arrive in random order, so the marker (written after fromPretrained succeeds) decides.
    /// The file checks only add to it: config, tokenizer files, and every weight shard.
    static func isDownloaded(_ folder: URL) -> Bool {
        let fm = FileManager.default
        func has(_ name: String) -> Bool { fm.fileExists(atPath: folder.appendingPathComponent(name).path) }
        guard [completeMarker, "config.json", "vocab.json", "merges.txt", "tokenizer_config.json"].allSatisfy(has),
              let files = try? fm.contentsOfDirectory(atPath: folder.path),
              files.contains(where: { $0.hasSuffix(".safetensors") })
        else { return false }
        if let data = try? Data(contentsOf: folder.appendingPathComponent("model.safetensors.index.json")),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let weightMap = json["weight_map"] as? [String: String] {
            return Set(weightMap.values).allSatisfy(has)
        }
        return true
    }

    public func transcribe(_ samples: [Float], language: LanguageMode, hints: [String]) async throws -> String {
        let context = hints.isEmpty ? nil : hints.joined(separator: ", ")
        // The default 448-token cap silently cuts long dictations, so the cap grows with the audio.
        let maxTokens = max(448, Int(Double(samples.count) / 16_000 * 25) + 64)
        let text = lock.withLock {
            model.transcribe(
                audio: samples, sampleRate: SilenceFilter.sampleRate, language: Self.name(for: language),
                maxTokens: maxTokens, context: context)
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
