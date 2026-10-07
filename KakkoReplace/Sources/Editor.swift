import AppKit
import ApplicationServices
func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }
final class Editor {
    struct Recovery { let element: AXUIElement; let pid: pid_t; let before: String; let after: String; let range: NSRange; let original: NSRange; let replacement: String }
    private var recovery: Recovery?
    var recoveryPID: pid_t? { recovery?.pid }
    private var busy = false
    func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
        return value
    }
    func range(_ element: AXUIElement) -> NSRange? {
        guard let v = attribute(element, kAXSelectedTextRangeAttribute), CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
        var r = CFRange()
        guard AXValueGetValue(unsafeBitCast(v, to: AXValue.self), .cfRange, &r), r.location >= 0, r.length >= 0 else { return nil }
        return NSRange(location: r.location, length: r.length)
    }
    func setRange(_ range: NSRange, on element: AXUIElement) -> Bool {
        var r = CFRange(location: range.location, length: range.length)
        guard let v = AXValueCreate(.cfRange, &r) else { return false }
        return AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, v) == .success
    }
    func focused(_ pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.35)
        guard let value = attribute(app, kAXFocusedUIElementAttribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }
    func perform(pid: pid_t, action: String = "round", force: Bool = false, trimSpaces: Bool = false) -> String {
        guard !busy else { return L("busy") }
        busy = true; defer { busy = false }
        guard AXIsProcessTrusted() else { return L("permissionNeeded") }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
              let element = focused(pid), attribute(element, kAXSubroleAttribute) as? String != "AXSecureTextField",
              let original = range(element), let value = attribute(element, kAXValueAttribute) as? String,
              original.location <= value.utf16.count, original.length <= value.utf16.count - original.location else { return L("unsupported") }
        for key in [kAXSelectedTextAttribute, kAXSelectedTextRangeAttribute] {
            var settable: DarwinBoolean = false
            guard AXUIElementIsAttributeSettable(element, key as CFString, &settable) == .success, settable.boolValue else { return L("unsupported") }
        }
        let selected = (value as NSString).substring(with: original)
        guard attribute(element, kAXSelectedTextAttribute) as? String == selected else { return L("unsupported") }
        let edit = BracketEdit.make(selected, at: original.location, action: action, force: force, trimSpaces: trimSpaces)
        let expected = (value as NSString).replacingCharacters(in: original, with: edit.replacement)
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid, let current = focused(pid), CFEqual(current, element), range(element) == original,
              attribute(element, kAXValueAttribute) as? String == value else { return L("cancelled") }
        if expected == value { return L("unchanged") }
        let status = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, edit.replacement as CFString)
        guard attribute(element, kAXValueAttribute) as? String == expected else {
            recovery = nil
            return status == .success ? L("unverified") : L("failed")
        }
        recovery = Recovery(element: element, pid: pid, before: value, after: expected, range: NSRange(location: original.location, length: edit.replacement.utf16.count), original: original, replacement: selected)
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid, let current = focused(pid), CFEqual(current, element), setRange(edit.selection, on: element), range(element) == edit.selection else { return L("partial") }
        return L("success")
    }
    func restore(expectedPID: pid_t? = nil) -> String {
        guard let r = recovery, expectedPID == nil || expectedPID == r.pid, attribute(r.element, kAXValueAttribute) as? String == r.after else { return L("restoreUnavailable") }
        // Only the original input element and unchanged text may be restored.
        guard setRange(r.range, on: r.element), range(r.element) == r.range,
              AXUIElementSetAttributeValue(r.element, kAXSelectedTextAttribute as CFString, r.replacement as CFString) == .success,
              attribute(r.element, kAXValueAttribute) as? String == r.before else { return L("failed") }
        recovery = nil
        return setRange(r.original, on: r.element) && range(r.element) == r.original ? L("restored") : L("partial")
    }
}
