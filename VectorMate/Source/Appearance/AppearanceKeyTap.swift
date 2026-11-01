import AppKit
import ApplicationServices

/// Command keys through an event tap, so a key can be left to Illustrator while text is being typed.
/// Needs Accessibility; without it the Carbon hotkeys are used and every key runs its command.
@MainActor final class KeyTap {
    /// Combo → command id, set by the model while the palette is shown.
    var keys: [KeyCombo: String] = [:]
    /// Called with the command id for a key press that was taken.
    var action: ((String) -> Void)?
    private var port: CFMachPort?
    private var source: CFRunLoopSource?

    var isRunning: Bool { port.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    /// Creates the tap on first use. Returns false when it cannot be created (no Accessibility permission).
    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        if port == nil && enabled {
            guard AXIsProcessTrusted() else { return false }
            let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask,
                                               callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let tap = Unmanaged<KeyTap>.fromOpaque(context).takeUnretainedValue()
                return MainActor.assumeIsolated { tap.handle(type, event) }
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
            self.port = port
            source = CFMachPortCreateRunLoopSource(nil, port, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let port { CGEvent.tapEnable(tap: port, enable: enabled) }
        return true
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown, let front = Illustrator.front else { return Unmanaged.passUnretained(event) }
        let flags = event.flags
        var modifiers: UInt32 = 0
        if flags.contains(.maskCommand) { modifiers |= KeyCombo.command }
        if flags.contains(.maskShift) { modifiers |= KeyCombo.shift }
        if flags.contains(.maskAlternate) { modifiers |= KeyCombo.option }
        if flags.contains(.maskControl) { modifiers |= KeyCombo.control }
        let combo = KeyCombo(code: UInt32(event.getIntegerValueField(.keyboardEventKeycode)), modifiers: modifiers)
        guard let id = keys[combo] else { return Unmanaged.passUnretained(event) }
        // Keys without ⌘ or ⌃ type characters: leave them to Illustrator while a type tool is active
        // (or when Illustrator does not answer, e.g. a dialog box is open).
        if modifiers & (KeyCombo.command | KeyCombo.control) == 0 && IllustratorState.isTyping(front.processIdentifier) {
            return Unmanaged.passUnretained(event)
        }
        // A held key runs the command once.
        if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
            DispatchQueue.main.async { self.action?(id) }
        }
        return nil
    }
}

enum IllustratorState {
    /// The type tools (and text editing, which switches to the Type tool) report a name with "Type Tool".
    static let script = "(function () { try { return /Type Tool/.test(String(app.getSelectedToolName())) ? \"1\" : \"0\"; } catch (e) { return \"0\"; } })();"

    /// Asks Illustrator with `do javascript` (event misc/DjxM), waiting at most `timeout`.
    /// No answer in time (a dialog box, a long command) counts as typing, so the key reaches Illustrator.
    static func isTyping(_ pid: pid_t, timeout: TimeInterval = 0.3) -> Bool {
        let code = { (text: String) in text.utf8.reduce(UInt32(0)) { $0 << 8 | UInt32($1) } }
        let event = NSAppleEventDescriptor(eventClass: code("misc"), eventID: code("DjxM"),
                                           targetDescriptor: NSAppleEventDescriptor(processIdentifier: pid),
                                           returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        event.setParam(NSAppleEventDescriptor(string: script), forKeyword: keyDirectObject)
        guard let reply = try? event.sendEvent(options: [.waitForReply, .neverInteract], timeout: timeout) else { return true }
        return reply.paramDescriptor(forKeyword: keyDirectObject)?.stringValue == "1"
    }
}
