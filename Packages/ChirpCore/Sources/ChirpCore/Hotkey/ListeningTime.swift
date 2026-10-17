import Foundation

public struct ListeningTime: Sendable {
    private var elapsed: TimeInterval = 0
    private var startedAt: TimeInterval?

    public init() {}

    public mutating func resume(at time: TimeInterval) {
        guard startedAt == nil else { return }
        startedAt = time
    }

    public mutating func pause(at time: TimeInterval) {
        guard let startedAt else { return }
        elapsed += max(0, time - startedAt)
        self.startedAt = nil
    }

    public func remaining(at time: TimeInterval) -> TimeInterval {
        let listening = startedAt.map { max(0, time - $0) } ?? 0
        return max(0, HotkeyStateMachine.handsFreeLimit - elapsed - listening)
    }
}
