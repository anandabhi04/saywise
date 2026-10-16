import Observation
import SwiftUI

@MainActor
@Observable
final class BarModel {
    enum Phase: Equatable {
        case idle
        case listening(handsFree: Bool)
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
    @State private var showEsc = false

    var body: some View {
        content
            .font(.system(size: 13, weight: .medium).monospacedDigit())
            .foregroundStyle(.white)
            .frame(height: 34)
            .frame(minWidth: 52)
            .padding(.horizontal, isCompact ? 0 : 14)
            .background(
                Capsule().fill(.black.opacity(model.hovering ? 0.42 : 0.3))
                    .overlay(Capsule().strokeBorder(.white.opacity(model.hovering ? 0.2 : 0.12), lineWidth: 0.5)))
            .opacity(model.phase == .micOff ? 0.7 : 1)
            .scaleEffect(model.hovering && isCompact ? 1.03 : 1)
            .animation(.easeOut(duration: 0.12), value: model.hovering)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.phase)
            .fixedSize()
            .help(model.phase == .idle ? "Talk · drag to move" : "")
            .onChange(of: model.phase, initial: true) { _, phase in
                showEsc = false
                if case .listening = phase {
                    Task { try? await Task.sleep(for: .seconds(1)); if case .listening = model.phase { withAnimation { showEsc = true } } }
                }
            }
    }

    private var isCompact: Bool {
        switch model.phase {
        case .idle, .pasted, .micOff, .loading: true
        default: false
        }
    }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .idle:
            Image(systemName: "mic.fill").font(.system(size: 14)).opacity(0.85).frame(width: 52)
        case let .listening(handsFree):
            HStack(spacing: 0) {
                if handsFree {
                    Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(.red)
                } else {
                    StatusDot(color: .red, pulsing: true)
                }
                Spacer(minLength: 0)
                WaveView(levels: model.levels, barWidth: 2.5, maxHeight: 18)
                Spacer(minLength: 0)
                Text("esc").font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.5), lineWidth: 1))
                    .opacity(showEsc ? 0.5 : 0)
            }
            .frame(width: 184 - 28)
        case .finishing:
            HStack(spacing: 9) { ProgressView().controlSize(.small).tint(.white); Text("Finishing") }
        case .pasted:
            Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold)).foregroundStyle(.green).frame(width: 52)
        case .copied:
            HStack(spacing: 9) { Image(systemName: "doc.on.clipboard"); Text("Copied · ⌘V to paste") }
        case .micOff:
            Image(systemName: "mic.slash.fill").font(.system(size: 14)).opacity(0.5).frame(width: 52)
        case .loading:
            ProgressView().controlSize(.small).tint(.white).opacity(0.7).frame(width: 52)
        case let .message(text, isError):
            HStack(spacing: 9) {
                if isError { Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange) }
                Text(text)
            }
        }
    }
}
