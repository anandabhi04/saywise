import AppKit
import SwiftUI

/// Click toggles recording, drag moves the panel. AppKit handles the mouse so a drag never counts as a click.
private final class FloatingBarHostView: NSView {
    var onClick: () -> Void = {}
    var onMoved: (NSPoint) -> Void = { _ in }
    var onHover: (Bool) -> Void = { _ in }
    private var dragStart: NSPoint?
    private var windowStart: NSPoint?
    private var dragged = false
    private var tracking: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? self : nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) { onHover(true) }
    override func mouseExited(with event: NSEvent) { onHover(false) }

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        windowStart = window?.frame.origin
        dragged = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStart, let windowStart, let window else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - dragStart.x, dy = now.y - dragStart.y
        if !dragged && hypot(dx, dy) < 4 { return }
        dragged = true
        window.setFrameOrigin(NSPoint(x: windowStart.x + dx, y: windowStart.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        if dragged, let frame = window?.frame { onMoved(NSPoint(x: frame.midX, y: frame.midY)) } else { onClick() }
        dragStart = nil; windowStart = nil
    }
}

/// Never takes focus, so the text still pastes into the app the user was typing in.
private final class FloatingBarPanel: NSPanel {
    init(content: NSView) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 52, height: 34),
                   styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        isFloatingPanel = true
        hidesOnDeactivate = false
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isExcludedFromWindowsMenu = true
        appearance = NSAppearance(named: .darkAqua)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = content
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class FloatingBarController {
    private static let centerKey = "floatingBarCenter"
    let model = BarModel()
    private let panel: FloatingBarPanel
    private let hosting: NSHostingView<FloatingBarView>
    private let glass = NSVisualEffectView()
    private weak var controller: AppController?
    private var flashTask: Task<Void, Never>?
    private var visible = false

    init(controller: AppController) {
        self.controller = controller
        let host = FloatingBarHostView(frame: NSRect(x: 0, y: 0, width: 52, height: 34))
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.wantsLayer = true
        glass.layer?.cornerRadius = 17
        glass.layer?.masksToBounds = true
        glass.frame = host.bounds
        glass.autoresizingMask = [.width, .height]
        host.addSubview(glass)
        hosting = NSHostingView(rootView: FloatingBarView(model: model))
        hosting.frame = host.bounds
        hosting.autoresizingMask = [.width, .height]
        hosting.layer?.backgroundColor = .clear
        host.addSubview(hosting)
        panel = FloatingBarPanel(content: host)
        host.onClick = { [weak self] in self?.clicked() }
        host.onHover = { [weak self] in self?.model.hovering = $0 }
        host.onMoved = { [weak self] center in
            UserDefaults.standard.set(NSStringFromPoint(center), forKey: Self.centerKey)
            self?.layout()
        }
    }

    func setVisible(_ visible: Bool) {
        self.visible = visible
        if visible { rest(); layout(); panel.orderFrontRegardless() } else { panel.orderOut(nil) }
    }

    func show(_ phase: BarModel.Phase) {
        flashTask?.cancel()
        if case .listening = phase {
            if case .listening = model.phase {} else { model.resetLevels() }
        }
        model.phase = phase
        layout()
        if visible || !isResting(phase) { panel.orderFrontRegardless() }
    }

    func flash(_ phase: BarModel.Phase, for seconds: Double) {
        show(phase)
        flashTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.rest()
        }
    }

    /// The bar's resting look follows the controller's status.
    func rest() {
        flashTask?.cancel()
        guard let controller else { return }
        switch controller.status {
        case .paused: model.phase = .micOff
        case .starting, .loadingModels: model.phase = .loading
        default: model.phase = .idle
        }
        layout()
        if !visible { panel.orderOut(nil) }
    }

    private func isResting(_ phase: BarModel.Phase) -> Bool {
        switch phase { case .idle, .micOff, .loading: true; default: false }
    }

    private func clicked() {
        guard let controller else { return }
        switch model.phase {
        case .copied, .message: rest()
        case .micOff:
            controller.setMicOn(true)
            flash(.message("Mic on", isError: false), for: 1.5)
        case .loading:
            flash(.message("Getting ready · \(controller.modelProgressText)", isError: false), for: 2)
        case .finishing, .pasted: break
        case .idle, .listening: controller.toggleRecording(from: .floatingButton)
        }
    }

    /// Resize around the saved center, kept 12 pt inside the screen. The frame is set without
    /// animation; SwiftUI animates the content.
    private func layout() {
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize
        let center = savedCenter() ?? defaultCenter()
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) ?? NSScreen.main else { return }
        let bounds = screen.visibleFrame.insetBy(dx: 12, dy: 12)
        var origin = NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
        origin.x = min(max(origin.x, bounds.minX), bounds.maxX - size.width)
        origin.y = min(max(origin.y, bounds.minY), bounds.maxY - size.height)
        panel.setFrame(NSRect(origin: origin, size: size), display: true, animate: false)
    }

    private func savedCenter() -> NSPoint? {
        guard let text = UserDefaults.standard.string(forKey: Self.centerKey) else { return nil }
        let center = NSPointFromString(text)
        return NSScreen.screens.contains { $0.visibleFrame.contains(center) } ? center : nil
    }

    private func defaultCenter() -> NSPoint {
        let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        return NSPoint(x: frame.midX, y: frame.minY + 20 + 17)
    }
}
