import Foundation

public enum PasteDecision {
    /// Roles where Cmd+V cannot mean "insert text".
    static let nonTextRoles: Set<String> = [
        "AXButton", "AXOutline", "AXList", "AXTable", "AXImage", "AXMenu",
        "AXMenuBar", "AXMenuItem", "AXRadioButton", "AXCheckBox",
    ]

    /// `focusedRole` is the AX role of the focused element, or nil when nothing has focus.
    public static func shouldPaste(focusedRole: String?) -> Bool {
        guard let role = focusedRole else { return false }
        return !nonTextRoles.contains(role)
    }
}
