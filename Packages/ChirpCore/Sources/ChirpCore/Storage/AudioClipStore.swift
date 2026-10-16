@preconcurrency import AVFoundation
import Foundation

/// Keeps the newest `limit` clips as 16 kHz WAV files. Only used when "keep audio" is on.
public struct AudioClipStore: Sendable {
    public let directory: URL
    public let limit: Int

    public init(directory: URL, limit: Int = 50) {
        self.directory = directory
        self.limit = limit
    }

    /// Returns the file name. Names start with a timestamp, so sorting by name sorts by age.
    public func save(_ samples: [Float], now: Date = Date()) throws -> String {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        let name = "\(formatter.string(from: now))-\(UUID().uuidString.prefix(8)).wav"

        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: Double(SilenceFilter.sampleRate),
            channels: 1, interleaved: false)!
        let fileSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: SilenceFilter.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
        ]
        let file = try AVAudioFile(
            forWriting: directory.appendingPathComponent(name), settings: fileSettings,
            commonFormat: .pcmFormatFloat32, interleaved: false)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            buffer.floatChannelData![0].update(from: src.baseAddress!, count: samples.count)
        }
        try file.write(from: buffer)
        try prune()
        return name
    }

    public func prune() throws {
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasSuffix(".wav") }
            .sorted()
        for name in files.dropLast(limit) {
            try FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
    }

    /// Reads any WAV file and returns 16 kHz mono samples.
    public static func loadSamples(from url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let target = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: Double(SilenceFilter.sampleRate),
            channels: 1, interleaved: false)!
        let input = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: input)
        guard let converter = AVAudioConverter(from: file.processingFormat, to: target) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let ratio = target.sampleRate / file.processingFormat.sampleRate
        let output = AVAudioPCMBuffer(
            pcmFormat: target, frameCapacity: AVAudioFrameCount(Double(input.frameLength) * ratio) + 1024)!
        // The converter calls this block synchronously, inside convert(to:).
        nonisolated(unsafe) var fed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if fed {
                status.pointee = .endOfStream
                return nil
            }
            fed = true
            status.pointee = .haveData
            return input
        }
        if let error { throw error }
        return Array(UnsafeBufferPointer(start: output.floatChannelData![0], count: Int(output.frameLength)))
    }
}
