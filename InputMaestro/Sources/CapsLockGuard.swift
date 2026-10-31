import AppKit
import IOKit
import IOKit.hidsystem

// Copied from FnNumpad/Sources/CapsLockGuard.swift.
/// Caps Lock as the trigger: pressing it still toggles the caps lock, and its release is never sent as an event.
/// When a hold was used for a command, the caps lock goes back to how it was before that press.
/// Only Caps Lock's own physical state is read (CGEventSource.keyState), while it is down.
@MainActor
final class CapsLockGuard {
    /// The caps lock state before the toggle of the current hold.
    private var before: Bool?
    private var used = false
    private var timer: Timer?

    static var isDown: Bool { CGEventSource.keyState(.hidSystemState, key: 57) }

    /// Caps Lock toggled the lock (a flagsChanged event); only a toggle made while the key is down belongs to a hold.
    func toggled(to on: Bool) {
        guard Self.isDown else { return }
        if before == nil { before = !on }
        watch()
    }

    /// A command was used while Caps Lock was held.
    func markUsed() {
        used = true
        watch()
    }

    // Polled only while Caps Lock is down after a toggle or a conversion (its release has no event).
    private func watch() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
    }

    private func check() {
        guard !Self.isDown else { return }
        timer?.invalidate(); timer = nil
        if used, let before {
            // After the system's own handling of the release.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { Self.setCapsLock(before) }
        }
        used = false
        before = nil
    }

    static func setCapsLock(_ on: Bool) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        var connect: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect) == KERN_SUCCESS else { return }
        defer { IOServiceClose(connect) }
        IOHIDSetModifierLockState(connect, Int32(kIOHIDCapsLockState), on)
    }
}
