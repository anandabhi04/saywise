import AVFoundation
import ChirpCore

enum RecorderError: Error {
    case noInput
}

/// Records the default mic as 16 kHz mono floats in memory.
final class AudioRecorder {
    /// Called on the main thread with the RMS level of each buffer.
    var onLevel: ((Float) -> Void)?
    var onSamples: (([Float]) -> Void)?
    private var recordingID = UUID()

    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var samples: [Float] = []
    private let target = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: Double(SilenceFilter.sampleRate),
        channels: 1, interleaved: false)!

    func start() throws {
        recordingID = UUID()
        let id = recordingID
        lock.withLock { samples.removeAll(keepingCapacity: true) }
        let input = engine.inputNode
        // Read the format each time: it changes when the user switches mics.
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, let converter = AVAudioConverter(from: format, to: target) else {
            throw RecorderError.noInput
        }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.append(buffer, converter: converter, recordingID: id)
        }
        engine.prepare()
        try engine.start()
    }

    func stop() -> [Float] {
        recordingID = UUID()
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        return lock.withLock { samples }
    }

    func cancel() {
        _ = stop()
    }

    private func append(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, recordingID: UUID) {
        let ratio = target.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
        var fed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if fed {
                status.pointee = .noDataNow
                return nil
            }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, let data = output.floatChannelData?[0] else { return }
        let chunk = UnsafeBufferPointer(start: data, count: Int(output.frameLength))
        lock.withLock { samples.append(contentsOf: chunk) }
        let sum = chunk.reduce(Float(0)) { $0 + $1 * $1 }
        let rms = chunk.isEmpty ? 0 : (sum / Float(chunk.count)).squareRoot()
        let copied = Array(chunk)
        DispatchQueue.main.async { [weak self] in
            guard let self, self.recordingID == recordingID else { return }
            self.onLevel?(rms)
            self.onSamples?(copied)
        }
    }
}
