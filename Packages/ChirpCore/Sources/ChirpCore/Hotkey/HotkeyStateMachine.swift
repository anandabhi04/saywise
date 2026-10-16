import Foundation

public enum HotkeyEvent: Equatable, Sendable {
    case keyDown(TimeInterval)
    case keyUp(TimeInterval)
    /// Any other key pressed while the trigger key is down, for example Fn+Delete.
    case otherKey
    case escape
    case handsFreeTimeout
}

public enum HotkeyAction: Equatable, Sendable {
    case none
    case start
    case stop
    case cancel
}

/// Hold to talk, double-tap for hands-free, Esc to cancel.
public struct HotkeyStateMachine: Sendable {
    public static let minPress: TimeInterval = 0.3
    public static let doubleTapWindow: TimeInterval = 0.4
    public static let handsFreeLimit: TimeInterval = 600

    enum State: Equatable {
        case idle(lastShortTapUp: TimeInterval?)
        case holding(since: TimeInterval)
        /// Second press of a double-tap is still down.
        case handsFreeArming
        case handsFree
    }

    private(set) var state: State = .idle(lastShortTapUp: nil)

    public init() {}

    public var isHandsFree: Bool { state == .handsFree || state == .handsFreeArming }

    public mutating func handle(_ event: HotkeyEvent) -> HotkeyAction {
        switch (state, event) {
        case let (.idle(lastTap), .keyDown(t)):
            if let lastTap, t - lastTap <= Self.doubleTapWindow {
                state = .handsFreeArming
            } else {
                state = .holding(since: t)
            }
            return .start
        case let (.holding(since), .keyUp(t)):
            if t - since < Self.minPress {
                state = .idle(lastShortTapUp: t)
                return .cancel
            }
            state = .idle(lastShortTapUp: nil)
            return .stop
        case (.holding, .otherKey), (.holding, .escape),
             (.handsFreeArming, .escape), (.handsFree, .escape):
            state = .idle(lastShortTapUp: nil)
            return .cancel
        case (.handsFreeArming, .keyUp):
            state = .handsFree
            return .none
        case (.handsFree, .keyDown), (.handsFree, .handsFreeTimeout):
            state = .idle(lastShortTapUp: nil)
            return .stop
        default:
            return .none
        }
    }
}
