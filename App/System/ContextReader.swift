import AppKit
import ApplicationServices
import ChirpCore

enum ContextReader {
    static func current() -> AppContext {
        let app = NSWorkspace.shared.frontmostApplication
        var title: String?
        if let pid = app?.processIdentifier {
            let axApp = AXUIElementCreateApplication(pid)
            // Electron apps (Slack, VS Code) only expose their text fields after this is set.
            AXUIElementSetAttributeValue(axApp, "AXManualAccessibility" as CFString, kCFBooleanTrue)
            if let window = element(axApp, kAXFocusedWindowAttribute) {
                title = string(window, kAXTitleAttribute)
            }
        }
        return AppContext(bundleID: app?.bundleIdentifier, appName: app?.localizedName, windowTitle: title)
    }

    /// AX role of the focused element, or nil when nothing has focus.
    static func focusedRole() -> String? {
        guard let focused = element(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute) else { return nil }
        return string(focused, kAXRoleAttribute)
    }

    private static func element(_ parent: AXUIElement, _ name: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(parent, name as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }

    private static func string(_ parent: AXUIElement, _ name: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(parent, name as CFString, &value) == .success else { return nil }
        return value as? String
    }
}
