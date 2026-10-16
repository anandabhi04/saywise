import ChirpCore
import ChirpEngines
import Foundation

/// Runs every clip in a manifest through the real pipeline and prints accuracy and speed.
/// Usage: ChirpBench --manifest TestClips/manifest.json [--engine whisper|qwen3ASR] [--no-cleanup]
@main
enum ChirpBench {
    struct Manifest: Decodable {
        struct Clip: Decodable {
            var file: String
            /// For the summary: "english", "hindi" or "hinglish".
            var group: String
            var language: LanguageMode
            var appBundleID: String?
            var expected: String
        }

        var clips: [Clip]
    }

    struct Row {
        var clip: Manifest.Clip
        var audioSeconds: Double
        var rawWER: Double
        var finalWER: Double
        var cleanup: String
        var timings: StepTimings
        var finalText: String
    }

    struct NullInserter: TextInserter {
        func insert(_ text: String) async -> InsertOutcome { .pasted }
    }

    static func main() async {
        do {
            try await run()
        } catch {
            let message = "ChirpBench: \(error.localizedDescription)\n"
            FileHandle.standardError.write(Data(message.utf8))
            exit(1)
        }
    }

    static func run() async throws {
        let args = CommandLine.arguments
        guard let manifestPath = value(after: "--manifest", in: args) else {
            print("Usage: ChirpBench --manifest <path> [--engine whisper|qwen3ASR] [--no-cleanup]")
            exit(2)
        }
        let engineName = value(after: "--engine", in: args) ?? "whisper"
        guard let engine = SpeechEngine(rawValue: engineName) else {
            let valid = SpeechEngine.allCases.map(\.rawValue).joined(separator: ", ")
            FileHandle.standardError.write(Data("ChirpBench: unknown engine '\(engineName)'. Valid values: \(valid)\n".utf8))
            exit(2)
        }
        let skipCleanup = args.contains("--no-cleanup")
        let manifestURL = URL(fileURLWithPath: manifestPath)
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))

        let clipDirectory = manifestURL.deletingLastPathComponent()
        let missing = manifest.clips.map(\.file).filter {
            !FileManager.default.fileExists(atPath: clipDirectory.appendingPathComponent($0).path)
        }
        guard missing.isEmpty else {
            FileHandle.standardError.write(Data("ChirpBench: missing clip files: \(missing.joined(separator: ", "))\n".utf8))
            exit(1)
        }

        let paths = ChirpPaths.standard
        let settings = (try? SettingsStore(url: paths.settingsFile).load()) ?? ChirpSettings()
        print("Loading \(engine.rawValue) and \(settings.cleanupModelID)…")
        let transcriber = try await EngineLoader.transcriber(for: engine, modelsDirectory: paths.modelsDirectory)
        let cleaner = try await MLXCleaner.load(modelID: settings.cleanupModelID, modelsDirectory: paths.modelsDirectory)
        await cleaner.warmUp()
        let pipeline = DictationPipeline(transcriber: transcriber, cleaner: cleaner, inserter: NullInserter(), history: nil)

        var rows: [Row] = []
        for clip in manifest.clips {
            let url = manifestURL.deletingLastPathComponent().appendingPathComponent(clip.file)
            let samples = try AudioClipStore.loadSamples(from: url)
            let bundleID = clip.appBundleID ?? "bench.default"
            var clipSettings = settings
            clipSettings.languageMode = clip.language
            if skipCleanup { clipSettings.appStyles[bundleID] = .raw }
            let outcome = await pipeline.run(DictationInput(
                samples: samples, context: AppContext(bundleID: bundleID), settings: clipSettings))
            guard case let .delivered(result) = outcome else {
                print("\(clip.file): \(outcome)")
                continue
            }
            rows.append(Row(
                clip: clip,
                audioSeconds: Double(samples.count) / Double(SilenceFilter.sampleRate),
                rawWER: WordErrorRate.compute(reference: clip.expected, hypothesis: Romanizer.romanize(result.rawText)),
                finalWER: WordErrorRate.compute(reference: clip.expected, hypothesis: result.finalText),
                cleanup: result.cleanup.storageValue,
                timings: result.timings,
                finalText: result.finalText))
        }
        printReport(rows, engine: engine)
    }

    static func printReport(_ rows: [Row], engine: SpeechEngine) {
        print("\n## Clips (\(engine.rawValue))\n")
        print("| file | audio s | raw WER | final WER | cleanup | speech ms | cleanup ms | total ms | target | output |")
        print("|---|---|---|---|---|---|---|---|---|---|")
        for r in rows {
            let target = targetMs(audioSeconds: r.audioSeconds)
            let verdict = r.timings.totalMs <= target ? "ok" : "SLOW (\(target))"
            print("| \(r.clip.file) | \(f(r.audioSeconds)) | \(pct(r.rawWER)) | \(pct(r.finalWER)) | \(r.cleanup) | \(r.timings.transcribeMs) | \(r.timings.cleanupMs) | \(r.timings.totalMs) | \(verdict) | \(r.finalText.replacingOccurrences(of: "\n", with: " ")) |")
        }
        print("\n## Summary by group\n")
        print("| group | clips | mean raw WER | mean final WER | fallbacks | p50 total ms | p90 total ms |")
        print("|---|---|---|---|---|---|---|")
        for name in Set(rows.map(\.clip.group)).sorted() {
            let group = rows.filter { $0.clip.group == name }
            let totals = group.map(\.timings.totalMs).sorted()
            let fallbacks = group.filter { $0.cleanup.hasPrefix("rejected") }.count
            print("| \(name) | \(group.count) | \(pct(mean(group.map(\.rawWER)))) | \(pct(mean(group.map(\.finalWER)))) | \(fallbacks) | \(percentile(totals, 0.5)) | \(percentile(totals, 0.9)) |")
        }
    }

    /// Spec section 4.1.
    static func targetMs(audioSeconds: Double) -> Int {
        switch audioSeconds {
        case ...5: 700
        case ...10: 1000
        default: 3000
        }
    }

    static func value(after flag: String, in args: [String]) -> String? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static func mean(_ values: [Double]) -> Double { values.reduce(0, +) / Double(max(values.count, 1)) }
    static func percentile(_ sorted: [Int], _ p: Double) -> Int { sorted[min(sorted.count - 1, Int(Double(sorted.count) * p))] }
    static func pct(_ v: Double) -> String { String(format: "%.1f%%", v * 100) }
    static func f(_ v: Double) -> String { String(format: "%.1f", v) }
}
