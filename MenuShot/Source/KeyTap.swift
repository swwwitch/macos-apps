import AppKit
import Carbon

/// Watches for one key combination with a listen-only event tap (Input Monitoring permission).
/// A Carbon hotkey does not arrive while another app tracks an open menu (measured on macOS 26), but a session tap still sees the key.
/// The tap only compares each key with the combination; nothing is stored or passed on, and the key still reaches the front app.
@MainActor final class KeyTap {
    var combo: KeyCombo?
    var onPress: (() -> Void)?
    /// Skips presses while a hotkey field is recording.
    var isPaused: () -> Bool = { false }
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    /// Asks without prompting.
    static var hasPermission: Bool { CGPreflightListenEventAccess() }

    /// Returns false when the tap cannot be created (no Input Monitoring permission).
    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: mask, callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let owner = Unmanaged<KeyTap>.fromOpaque(context).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                DispatchQueue.main.async { MainActor.assumeIsolated { owner.reenable() } }
            } else if type == .keyDown, event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                let code = UInt32(event.getIntegerValueField(.keyboardEventKeycode)), modifiers = KeyTap.carbonModifiers(event.flags)
                DispatchQueue.main.async { MainActor.assumeIsolated { owner.handle(code: code, modifiers: modifiers) } }
            }
            return Unmanaged.passUnretained(event)
        }, userInfo: context) else { return false }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap; self.source = source
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil
    }

    private func reenable() { if let tap { CGEvent.tapEnable(tap: tap, enable: true) } }

    private func handle(code: UInt32, modifiers: UInt32) {
        guard let combo, combo.code == code, combo.modifiers == modifiers, !isPaused() else { return }
        onPress?()
    }

    /// ⌘⇧⌥⌃ from an event, in Carbon's form (KeyCombo). Caps Lock and the Fn key are ignored.
    nonisolated static func carbonModifiers(_ flags: CGEventFlags) -> UInt32 {
        (flags.contains(.maskCommand) ? KeyCombo.command : 0) | (flags.contains(.maskShift) ? KeyCombo.shift : 0)
            | (flags.contains(.maskAlternate) ? KeyCombo.option : 0) | (flags.contains(.maskControl) ? KeyCombo.control : 0)
    }
}
