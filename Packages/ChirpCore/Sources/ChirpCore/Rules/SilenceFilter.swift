import Foundation

/// A simple energy check. It stops Whisper from inventing text on silence.
public enum SilenceFilter {
    public static let sampleRate = 16_000
    /// 30 ms at 16 kHz.
    public static let frameSize = 480
    /// About -40 dBFS.
    public static let rmsThreshold: Float = 0.01
    public static let minSpeechSeconds = 0.25

    public static func speechSeconds(in samples: [Float]) -> Double {
        var speechFrames = 0
        var start = 0
        while start + frameSize <= samples.count {
            var sum: Float = 0
            for i in start..<(start + frameSize) { sum += samples[i] * samples[i] }
            if (sum / Float(frameSize)).squareRoot() >= rmsThreshold { speechFrames += 1 }
            start += frameSize
        }
        return Double(speechFrames * frameSize) / Double(sampleRate)
    }

    public static func hasSpeech(_ samples: [Float]) -> Bool {
        speechSeconds(in: samples) >= minSpeechSeconds
    }
}
