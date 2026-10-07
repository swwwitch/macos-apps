import Foundation

/// Keeps a held shortcut pending until the trigger key is released. A change of
/// foreground application or configuration cancels it, never retargets it.
struct HotkeyReleaseGate {
    enum Result { case waiting, cancelled, perform }
    private var pending: (id: Int, pid: Int32)?

    mutating func begin(id: Int, pid: Int32) -> Bool {
        guard pending == nil else { return false }
        pending = (id, pid)
        return true
    }

    mutating func poll(frontPID: Int32?, keyHeld: Bool, enabled: Bool) -> Result {
        guard let pending else { return .cancelled }
        guard enabled, frontPID == pending.pid else {
            cancel()
            return .cancelled
        }
        guard !keyHeld else { return .waiting }
        cancel()
        return .perform
    }

    mutating func cancel() { pending = nil }
}
