import Observation
import SwiftUI

@MainActor
@Observable
final class BarModel {
    enum Phase: Equatable {
        case idle
        case listening(handsFree: Bool)
        case recordingPaused
        case finishing
        case pasted
        case copied
        case micOff
        case loading
        case message(String, isError: Bool)
    }

    static let barCount = 20

    var phase: Phase = .idle
    var levels = Array(repeating: Float(0), count: barCount)
    var hovering = false

    func push(_ level: Float) {
        levels.removeFirst()
        levels.append(level)
    }

    func resetLevels() { levels = Array(repeating: 0, count: Self.barCount) }
}

struct FloatingBarView: View {
    let model: BarModel
    var recordingDuration: () -> TimeInterval

    var body: some View {
        content
            .foregroundStyle(.white)
            .frame(width: 32)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(.black.opacity(model.hovering ? 0.42 : 0.3))
                    .overlay(Capsule().strokeBorder(.white.opacity(model.hovering ? 0.2 : 0.12), lineWidth: 0.5)))
            .opacity(model.phase == .micOff ? 0.7 : 1)
            .animation(.easeOut(duration: 0.12), value: model.hovering)
            .fixedSize()
            .help(model.phase == .idle ? "Talk · drag to move" : "")
    }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .listening, .recordingPaused:
            VStack(spacing: 8) {
                StatusDot(color: model.phase == .recordingPaused ? .orange : .red,
                          pulsing: model.phase != .recordingPaused)
                VStack(spacing: 2) {
                    ForEach(Array(model.levels.suffix(9).enumerated()), id: \.offset) { _, level in
                        Capsule()
                            .frame(width: 4 + CGFloat(min(1, max(0, level * 12))) * 12, height: 2.5)
                    }
                }
                .opacity(model.phase == .recordingPaused ? 0.35 : 1)
                .animation(.easeOut(duration: 0.08), value: model.levels)
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let seconds = Int(recordingDuration())
                    Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
                        .font(.system(size: 9).monospacedDigit())
                        .opacity(0.7)
                }
                Color.clear.frame(width: 24, height: 24)
                Color.clear.frame(width: 24, height: 24)
            }
        case .finishing, .loading:
            ProgressView().controlSize(.small).tint(.white).frame(height: 16)
        case .pasted:
            Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold)).foregroundStyle(.green).frame(height: 16)
        case .micOff:
            Image(systemName: "mic.slash.fill").font(.system(size: 14)).opacity(0.5).frame(height: 16)
        case .idle, .copied, .message:
            Image(systemName: "mic.fill").font(.system(size: 14)).opacity(0.85).frame(height: 16)
        }
    }
}

struct FloatingBarMessageView: View {
    let model: BarModel

    var body: some View {
        HStack(spacing: 6) {
            if case .message(_, isError: true) = model.phase {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
            }
            Text(text).lineLimit(3).fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 220)
        .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.8)))
        .fixedSize(horizontal: false, vertical: true)
    }

    private var text: String {
        switch model.phase {
        case .copied: "Copied · ⌘V to paste"
        case let .message(text, _): text
        default: ""
        }
    }
}
