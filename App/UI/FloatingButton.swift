import AppKit
import SwiftUI

struct FloatingButtonView: View {
    let controller: AppController

    var body: some View {
        ZStack {
            Circle()
                .fill(background)
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
            if controller.status == .working {
                ProgressView().controlSize(.small).tint(.white)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 52, height: 52)
        .padding(4)
        .help(help)
    }

    private var background: Color {
        switch controller.status {
        case .recording: .red
        case .ready, .working: .black.opacity(0.85)
        default: .gray.opacity(0.85)
        }
    }

    private var symbol: String {
        switch controller.status {
        case .recording: "stop.fill"
        case .ready: "mic.fill"
        default: "mic.slash.fill"
        }
    }

    private var help: String {
        switch controller.status {
        case .recording: "Click to stop"
        case .ready: "Click to talk. Drag to move."
        default: controller.statusText
        }
    }
}

/// Click toggles recording, drag moves the panel. AppKit handles the mouse so a
/// drag never counts as a click.
private final class FloatingButtonHostView: NSView {
    var onClick: () -> Void = {}
    var onMoved: (NSPoint) -> Void = { _ in }
    private var dragStart: NSPoint?
    private var windowStart: NSPoint?
    private var dragged = false

    // The panel never becomes key, so the first click must act right away.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? self : nil }

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        windowStart = window?.frame.origin
        dragged = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStart, let windowStart, let window else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - dragStart.x
        let dy = now.y - dragStart.y
        if !dragged && hypot(dx, dy) < 4 { return }
        dragged = true
        window.setFrameOrigin(NSPoint(x: windowStart.x + dx, y: windowStart.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        if dragged, let origin = window?.frame.origin {
            onMoved(origin)
        } else {
            onClick()
        }
        dragStart = nil
        windowStart = nil
    }
}

/// Never takes focus, so the text still pastes into the app the user was typing in.
private final class FloatingButtonPanel: NSPanel {
    init(content: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 60, height: 60),
            styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        isFloatingPanel = true
        hidesOnDeactivate = false
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = content
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class FloatingButtonController {
    private static let originKey = "floatingButtonOrigin"
    private let panel: FloatingButtonPanel

    init(controller: AppController) {
        let host = FloatingButtonHostView(frame: NSRect(x: 0, y: 0, width: 60, height: 60))
        let hosting = NSHostingView(rootView: FloatingButtonView(controller: controller))
        hosting.frame = host.bounds
        hosting.autoresizingMask = [.width, .height]
        host.addSubview(hosting)
        panel = FloatingButtonPanel(content: host)
        host.onClick = { [weak controller] in controller?.toggleRecording(from: .floatingButton) }
        host.onMoved = { origin in
            UserDefaults.standard.set(NSStringFromPoint(origin), forKey: Self.originKey)
        }
    }

    func setVisible(_ visible: Bool) {
        if visible {
            panel.setFrameOrigin(savedOrigin() ?? defaultOrigin())
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    /// A saved spot is used only while it is still on a screen, for example after a display is unplugged.
    private func savedOrigin() -> NSPoint? {
        guard let text = UserDefaults.standard.string(forKey: Self.originKey) else { return nil }
        let origin = NSPointFromString(text)
        let center = NSPoint(x: origin.x + 30, y: origin.y + 30)
        return NSScreen.screens.contains { $0.visibleFrame.contains(center) } ? origin : nil
    }

    private func defaultOrigin() -> NSPoint {
        let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        return NSPoint(x: frame.maxX - 80, y: frame.midY - 30)
    }
}
