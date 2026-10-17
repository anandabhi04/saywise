import AppKit
import ChirpCore

struct PasteInserter: TextInserter {
    func insert(_ text: String) async -> InsertOutcome {
        await Self.perform(text)
    }

    @MainActor
    static func perform(_ text: String) async -> InsertOutcome {
        let pasteboard = NSPasteboard.general
        guard AXIsProcessTrusted() else {
            copy(text, to: pasteboard)
            return .copiedNoPermission
        }
        guard PasteDecision.shouldPaste(focusedRole: ContextReader.focusedRole()) else {
            copy(text, to: pasteboard)
            return .copiedNoTextField
        }
        copy(text, to: pasteboard)
        pressCommandV()
        return .pasted
    }

    private static func copy(_ text: String, to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private static func pressCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
