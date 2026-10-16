import AppKit
import ChirpCore

/// Watches the trigger key with a listen-only event tap. Needs Input Monitoring.
final class HotkeyMonitor {
    var onEvent: ((HotkeyEvent) -> Void)?
    var triggerKey: TriggerKey = .fn

    private(set) var isRunning = false

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var isDown = false

    /// Returns false when macOS refuses the tap, which means Input Monitoring is missing.
    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                monitor.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque())
        else { isRunning = false; return false }
        self.tap = tap
        isRunning = true
        source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) {
        // macOS turns a tap off if a callback is slow. Turn it back on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            isDown = false
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        let now = NSEvent(cgEvent: event)?.timestamp ?? ProcessInfo.processInfo.systemUptime
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        switch type {
        case .flagsChanged:
            guard keyCode == triggerKey.keyCode else { return }
            let down = event.flags.contains(triggerKey.flag)
            guard down != isDown else { return }
            isDown = down
            onEvent?(down ? .keyDown(now) : .keyUp(now))
        case .keyDown:
            onEvent?(keyCode == Self.escapeKeyCode ? .escape : .otherKey)
        default:
            break
        }
    }

    static let escapeKeyCode: Int64 = 53
}

extension TriggerKey {
    var keyCode: Int64 {
        switch self {
        case .fn: 63
        case .rightOption: 61
        case .rightCommand: 54
        case .rightControl: 62
        }
    }

    var flag: CGEventFlags {
        switch self {
        case .fn: .maskSecondaryFn
        case .rightOption: .maskAlternate
        case .rightCommand: .maskCommand
        case .rightControl: .maskControl
        }
    }

    var displayName: String {
        switch self {
        case .fn: "Fn (🌐)"
        case .rightOption: "Right Option"
        case .rightCommand: "Right Command"
        case .rightControl: "Right Control"
        }
    }
}
