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
        let saved = ClipboardSnapshot(pasteboard)
        copy(text, to: pasteboard)
        let ourChange = pasteboard.changeCount
        pressCommandV()
        // The target app reads the clipboard after it handles Cmd+V, so wait before restoring.
        try? await Task.sleep(for: .milliseconds(300))
        // If the user copied something new meanwhile, keep theirs.
        if pasteboard.changeCount == ourChange { saved.restore(to: pasteboard) }
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

/// Every item and type on the clipboard, so it can be put back after pasting.
struct ClipboardSnapshot {
    let items: [[NSPasteboard.PasteboardType: Data]]

    init(_ pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        }
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let restored = items.map { types -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in types { item.setData(data, forType: type) }
            return item
        }
        if !restored.isEmpty { pasteboard.writeObjects(restored) }
    }
}
