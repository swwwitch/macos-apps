import AppKit
import ApplicationServices

/// Conditional event tap: unrelated apps/fields and failed writes receive the original key.
@MainActor
final class SignInversionWatcher {
    var combo: KeyCombo?
    var allowed: () -> Bool = { false }
    var status: (String) -> Void = { _ in }
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var swallowed: Int64?

    func start() {
        guard tap == nil, combo != nil, AXIsProcessTrusted() else { return }
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue) | (CGEventMask(1) << CGEventType.keyUp.rawValue)
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                               eventsOfInterest: mask, callback: { _, type, event, info in
            guard let info else { return Unmanaged.passUnretained(event) }
            return MainActor.assumeIsolated {
                Unmanaged<SignInversionWatcher>.fromOpaque(info).takeUnretainedValue().handle(type, event)
            }
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else { status(L("sign.unavailable")); return }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        CGEvent.tapEnable(tap: tap, enable: true)
        status(L("sign.ready"))
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil; tap = nil; swallowed = nil
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .keyUp, swallowed == code { swallowed = nil; return nil }
        guard type == .keyDown, let combo, code == Int64(combo.code), HotkeyRecorder.shared.recordingID == nil else { return Unmanaged.passUnretained(event) }
        let flags = event.flags
        let modifiers: UInt32 = (flags.contains(.maskCommand) ? KeyCombo.command : 0)
            | (flags.contains(.maskControl) ? KeyCombo.control : 0)
            | (flags.contains(.maskAlternate) ? KeyCombo.option : 0)
            | (flags.contains(.maskShift) ? KeyCombo.shift : 0)
        guard modifiers == combo.modifiers, allowed(), let app = NSWorkspace.shared.frontmostApplication,
              Illustrator.isIllustrator(app), !ExcludedApps.shared.frontAppExcluded else { return Unmanaged.passUnretained(event) }
        if event.getIntegerValueField(.keyboardEventAutorepeat) != 0, swallowed == code { return nil }
        guard invert(in: app) else { return Unmanaged.passUnretained(event) }
        swallowed = code
        return nil
    }

    private func invert(in app: NSRunningApplication) -> Bool {
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.05)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(root, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return false }
        let field = focused as! AXUIElement
        func read(_ key: String) -> CFTypeRef? {
            var value: CFTypeRef?
            return AXUIElementCopyAttributeValue(field, key as CFString, &value) == .success ? value : nil
        }
        guard let role = read(kAXRoleAttribute) as? String, [kAXTextFieldRole, kAXComboBoxRole].contains(role),
              (read(kAXEnabledAttribute) as? Bool) == true,
              (read(kAXSubroleAttribute) as? String) != kAXSecureTextFieldSubrole,
              let original = read(kAXValueAttribute) as? String,
              let rawRange = read(kAXSelectedTextRangeAttribute), CFGetTypeID(rawRange) == AXValueGetTypeID() else { return false }
        var range = CFRange()
        guard AXValueGetValue(rawRange as! AXValue, .cfRange, &range), range.location >= 0, range.length >= 0 else { return false }
        guard let replacement = SignInversion.replacement(value: original, selection: NSRange(location: range.location, length: range.length)) else { return false }
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(field, kAXValueAttribute as CFString, &settable) == .success, settable.boolValue,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier,
              !ExcludedApps.shared.frontAppExcluded, (read(kAXValueAttribute) as? String) == original else { return false }
        var currentFocus: CFTypeRef?
        guard AXUIElementCopyAttributeValue(root, kAXFocusedUIElementAttribute as CFString, &currentFocus) == .success,
              let currentFocus, CFEqual(currentFocus, field) else { return false }
        // Zero is a valid no-op: consume the hotkey so Option-minus cannot insert a dash.
        if replacement.value == original { return true }
        var latestRange = CFRange()
        guard let latestRaw = read(kAXSelectedTextRangeAttribute), CFGetTypeID(latestRaw) == AXValueGetTypeID(),
              AXValueGetValue(latestRaw as! AXValue, .cfRange, &latestRange), latestRange.location == range.location,
              latestRange.length == range.length else { return false }
        guard AXUIElementSetAttributeValue(field, kAXValueAttribute as CFString, replacement.value as CFString) == .success else { return false }
        var selection = CFRange(location: replacement.selection.location, length: replacement.selection.length)
        if let value = AXValueCreate(.cfRange, &selection) {
            AXUIElementSetAttributeValue(field, kAXSelectedTextRangeAttribute as CFString, value)
        }
        status(L("sign.done"))
        return true
    }
}
