import Foundation
import Synchronization

public struct CleanupTimeout: Error {}

final class OnceGate: Sendable {
    private let done = Mutex(false)

    func claim() -> Bool {
        done.withLock { done in
            if done { return false }
            done = true
            return true
        }
    }
}

enum Timeout {
    /// Returns as soon as the timeout passes, even if `operation` ignores cancellation.
    /// A task group would wait for a slow MLX generation to finish, so this uses
    /// unstructured tasks and a continuation instead.
    static func race<T: Sendable>(
        _ timeout: Duration,
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let gate = OnceGate()
        return try await withCheckedThrowingContinuation { continuation in
            let work = Task {
                do {
                    let value = try await operation()
                    if gate.claim() { continuation.resume(returning: value) }
                } catch {
                    if gate.claim() { continuation.resume(throwing: error) }
                }
            }
            Task {
                try? await Task.sleep(for: timeout)
                if gate.claim() {
                    work.cancel()
                    continuation.resume(throwing: CleanupTimeout())
                }
            }
        }
    }
}

extension Duration {
    var milliseconds: Int {
        Int(components.seconds) * 1000 + Int(components.attoseconds / 1_000_000_000_000_000)
    }
}
