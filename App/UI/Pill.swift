import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class PillModel {
    enum Phase: Equatable {
        case hidden
        case recording
        case working
        case message(String)
    }

    static let barCount = 24

    var phase: Phase = .hidden
    var levels = Array(repeating: Float(0), count: barCount)

    func push(_ level: Float) {
        levels.removeFirst()
        levels.append(level)
    }
}

struct PillView: View {
    let model: PillModel

    var body: some View {
        HStack(spacing: 8) {
            switch model.phase {
            case .hidden:
                EmptyView()
            case .recording:
                HStack(alignment: .center, spacing: 2) {
                    ForEach(Array(model.levels.enumerated()), id: \.offset) { _, level in
                        Capsule()
                            .fill(.white)
                            .frame(width: 3, height: 4 + CGFloat(min(1, level * 12)) * 20)
                    }
                }
            case .working:
                ProgressView().controlSize(.small).tint(.white)
                Text("Working").foregroundStyle(.white)
            case let .message(text):
                Text(text).foregroundStyle(.white)
            }
        }
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(Capsule().fill(.black.opacity(0.85)))
        .fixedSize()
        .animation(.easeOut(duration: 0.08), value: model.levels)
    }
}

/// Never takes focus, so the cursor stays in the user's app.
final class PillPanel: NSPanel {
    init(model: PillModel) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 48),
            styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        isFloatingPanel = true
        hidesOnDeactivate = false
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = NSHostingView(rootView: PillView(model: model))
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PillController {
    let model = PillModel()
    private lazy var panel = PillPanel(model: model)
    private var hideTask: Task<Void, Never>?

    func show(_ phase: PillModel.Phase) {
        hideTask?.cancel()
        model.phase = phase
        if phase == .recording { model.levels = Array(repeating: 0, count: PillModel.barCount) }
        guard let screen = NSScreen.main else { return }
        let size = panel.contentView?.fittingSize ?? NSSize(width: 260, height: 48)
        let frame = screen.visibleFrame
        panel.setFrame(
            NSRect(x: frame.midX - size.width / 2, y: frame.minY + 48, width: size.width, height: size.height),
            display: true)
        panel.orderFrontRegardless()
    }

    /// Shows a short message for 3 seconds.
    func flash(_ text: String) {
        show(.message(text))
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    func hide() {
        hideTask?.cancel()
        model.phase = .hidden
        panel.orderOut(nil)
    }
}
