import AppKit
import SwiftUI

/// Click toggles recording, drag moves the panel. AppKit handles the mouse so a drag never counts as a click.
private final class FloatingBarHostView: NSView {
    let pauseButton = NSButton()
    let stopButton = NSButton()
    var pillFrame = NSRect.zero
    var onClick: () -> Void = {}
    var onMoved: (NSPoint) -> Void = { _ in }
    var onHover: (Bool) -> Void = { _ in }
    private var dragStart: NSPoint?
    private var windowStart: NSPoint?
    private var dragged = false
    private var tracking: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard pillFrame.contains(local) else { return nil }
        if !pauseButton.isHidden, pauseButton.frame.contains(local) { return pauseButton }
        if !stopButton.isHidden, stopButton.frame.contains(local) { return stopButton }
        return self
    }

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
        if dragged, let window {
            onMoved(window.convertPoint(toScreen: NSPoint(x: pillFrame.midX, y: pillFrame.midY)))
        } else { onClick() }
        dragStart = nil; windowStart = nil
    }
}

/// Never takes focus, so the text still pastes into the app the user was typing in.
private final class FloatingBarPanel: NSPanel {
    init(content: NSView) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 32, height: 32),
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
final class FloatingBarController: NSObject {
    private static let centerKey = "floatingBarCenter"
    let model = BarModel()
    private let panel: FloatingBarPanel
    private let hosting: NSHostingView<FloatingBarView>
    private let messageHosting: NSHostingView<FloatingBarMessageView>
    private let glass = NSVisualEffectView()
    private let host: FloatingBarHostView
    private weak var controller: AppController?
    private var flashTask: Task<Void, Never>?
    private var visible = false

    init(controller: AppController) {
        self.controller = controller
        host = FloatingBarHostView(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.wantsLayer = true
        glass.layer?.cornerRadius = 16
        glass.layer?.masksToBounds = true
        glass.frame = host.bounds
        host.addSubview(glass)
        hosting = NSHostingView(rootView: FloatingBarView(model: model, recordingDuration: { [weak controller] in controller?.recordingDuration ?? 0 }))
        hosting.frame = host.bounds
        hosting.layer?.backgroundColor = .clear
        host.addSubview(hosting)
        messageHosting = NSHostingView(rootView: FloatingBarMessageView(model: model))
        messageHosting.isHidden = true
        host.addSubview(messageHosting)
        for button in [host.pauseButton, host.stopButton] {
            button.isBordered = false
            button.title = ""
            button.imagePosition = .imageOnly
            button.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
            button.focusRingType = .none
            button.contentTintColor = .white
            button.wantsLayer = true
            button.layer?.cornerRadius = 12
            button.isHidden = true
            host.addSubview(button)
        }
        host.pauseButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.14).cgColor
        host.pauseButton.action = #selector(toggleRecordingPause)
        host.stopButton.layer?.backgroundColor = NSColor.systemRed.cgColor
        host.stopButton.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: "Stop recording")
        host.stopButton.toolTip = "Stop recording"
        host.stopButton.setAccessibilityLabel("Stop recording")
        host.stopButton.action = #selector(stopRecording)
        panel = FloatingBarPanel(content: host)
        super.init()
        host.pauseButton.target = self
        host.stopButton.target = self
        host.onClick = { [weak self] in self?.clicked() }
        host.onHover = { [weak self] in self?.model.hovering = $0 }
        host.onMoved = { [weak self] center in
            self?.layout(center: center)
        }
    }

    @objc private func toggleRecordingPause() {
        controller?.toggleRecordingPause()
    }

    @objc private func stopRecording() {
        controller?.toggleRecording(from: .floatingButton)
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
        case .recording: model.phase = .listening(handsFree: controller.isHandsFree)
        case .recordingPaused: model.phase = .recordingPaused
        case .working: model.phase = .finishing
        case .paused: model.phase = .micOff
        case .starting, .loadingModels: model.phase = .loading
        default: model.phase = .idle
        }
        layout()
        if !visible && isResting(model.phase) { panel.orderOut(nil) }
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
        case .idle, .listening, .recordingPaused: controller.toggleRecording(from: .floatingButton)
        }
    }

    private func layout(center draggedCenter: NSPoint? = nil) {
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize
        let center = draggedCenter ?? savedCenter() ?? defaultCenter()
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(center) })
                ?? NSScreen.screens.min(by: { distance(from: center, to: $0.frame) < distance(from: center, to: $1.frame) }) else { return }
        let bounds = screen.visibleFrame.insetBy(dx: 8, dy: 8)
        let onLeft = center.x < bounds.midX
        let pillX = onLeft ? bounds.minX : bounds.maxX - size.width
        let pillY = min(max(center.y - size.height / 2, bounds.minY), bounds.maxY - size.height)
        let hasMessage: Bool
        switch model.phase { case .copied, .message: hasMessage = true; default: hasMessage = false }
        messageHosting.isHidden = !hasMessage
        messageHosting.frame.size = NSSize(width: 240, height: 32)
        messageHosting.layoutSubtreeIfNeeded()
        let fittingMessageSize = hasMessage ? messageHosting.fittingSize : .zero
        let messageSize = NSSize(width: ceil(fittingMessageSize.width), height: ceil(fittingMessageSize.height))
        let messageWidth = hasMessage ? messageSize.width + 8 : 0
        let height = max(size.height, messageSize.height)
        let origin = NSPoint(x: pillX - (onLeft ? 0 : messageWidth),
                             y: floor(min(max(pillY - (height - size.height) / 2, bounds.minY), bounds.maxY - height)))
        panel.setFrame(NSRect(origin: origin, size: NSSize(width: size.width + messageWidth, height: height)), display: true, animate: false)
        let pillFrame = NSRect(x: onLeft ? 0 : messageWidth, y: pillY - origin.y, width: size.width, height: size.height)
        host.pillFrame = pillFrame
        glass.frame = pillFrame
        hosting.frame = pillFrame
        messageHosting.frame = NSRect(x: onLeft ? size.width + 8 : 0, y: (height - messageSize.height) / 2,
                                      width: messageSize.width, height: messageSize.height)
        let paused = model.phase == .recordingPaused
        let listening: Bool
        if case .listening = model.phase { listening = true } else { listening = false }
        host.pauseButton.isHidden = !paused && !listening
        host.stopButton.isHidden = !paused && !listening
        let pauseLabel = paused ? "Resume recording" : "Pause recording"
        host.pauseButton.image = NSImage(systemSymbolName: paused ? "play.fill" : "pause.fill", accessibilityDescription: pauseLabel)
        host.pauseButton.toolTip = pauseLabel
        host.pauseButton.setAccessibilityLabel(pauseLabel)
        host.pauseButton.frame = NSRect(x: pillFrame.minX + 4, y: pillFrame.minY + 40, width: 24, height: 24)
        host.stopButton.frame = NSRect(x: pillFrame.minX + 4, y: pillFrame.minY + 8, width: 24, height: 24)
        if draggedCenter != nil {
            let snappedCenter = NSPoint(x: pillX + size.width / 2, y: pillY + size.height / 2)
            UserDefaults.standard.set(NSStringFromPoint(snappedCenter), forKey: Self.centerKey)
        }
    }

    private func distance(from point: NSPoint, to frame: NSRect) -> CGFloat {
        hypot(max(frame.minX - point.x, 0, point.x - frame.maxX),
              max(frame.minY - point.y, 0, point.y - frame.maxY))
    }

    private func savedCenter() -> NSPoint? {
        guard let text = UserDefaults.standard.string(forKey: Self.centerKey) else { return nil }
        let center = NSPointFromString(text)
        return NSScreen.screens.contains { $0.visibleFrame.contains(center) } ? center : nil
    }

    private func defaultCenter() -> NSPoint {
        let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        return NSPoint(x: frame.maxX - 8 - 16, y: frame.midY)
    }
}
