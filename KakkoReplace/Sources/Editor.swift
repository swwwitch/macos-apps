import AppKit
import ApplicationServices
func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }
final class Editor {
    struct Recovery { let element: AXUIElement; let pid: pid_t; let before: String; let after: String; let range: NSRange; let original: NSRange; let replacement: String }
    private var recovery: Recovery?
    var recoveryPID: pid_t? { recovery?.pid }
    private var busy = false
    private var pendingClipboard: (items: [[NSPasteboard.PasteboardType: Data]], change: Int)?
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
    /// The element's text in the coordinates of AXSelectedTextRange. Chrome's contenteditable (note editor) puts "\n"
    /// between paragraphs in AXValue but leaves them out of the ranges and AXStringForRange (measured), so its text is
    /// read without them. Native text views return AXValue itself.
    func text(_ element: AXUIElement) -> String? {
        guard let value = attribute(element, kAXValueAttribute) as? String else { return nil }
        guard value.contains("\n") else { return value }
        if string(element, length: value.utf16.count) == value { return value }
        let joined = value.replacingOccurrences(of: "\n", with: "")
        return string(element, length: joined.utf16.count) == joined ? joined : value
    }
    private func string(_ element: AXUIElement, length: Int) -> String? {
        var r = CFRange(location: 0, length: length)
        guard let span = AXValueCreate(.cfRange, &r) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXStringForRangeParameterizedAttribute as CFString, span, &value) == .success else { return nil }
        return value as? String
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
              let original = range(element), let value = text(element),
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
              text(element) == value else { return L("cancelled") }
        if expected == value { return L("unchanged") }
        let (status, after) = write(edit.replacement, at: original.location, to: element, pid: pid, before: value, expected: expected)
        guard status == .success, let after else { recovery = nil; return status == .unverified ? L("unverified") : L("failed") }
        recovery = Recovery(element: element, pid: pid, before: value, after: after, range: NSRange(location: original.location, length: edit.replacement.utf16.count), original: original, replacement: selected)
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid, let current = focused(pid), CFEqual(current, element), select(edit.selection, on: element) else { return L("partial") }
        return L("success")
    }
    enum WriteResult { case success, unverified, failed }
    /// Replaces the selection through AX. Chrome's contenteditable (e.g. the note editor) reports success but keeps
    /// the text (measured), so when the text is still unchanged the replacement is pasted with ⌘V instead (as MightyEdit does).
    /// Returns the text read back after the edit, for the recovery check.
    private func write(_ replacement: String, at location: Int, to element: AXUIElement, pid: pid_t, before: String, expected: String) -> (WriteResult, String?) {
        let status = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, replacement as CFString)
        if let after = waitForEdit(replacement, at: location, in: element, before: before, expected: expected, seconds: 0.15) { return (.success, after) }
        guard text(element) == before,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == pid, let current = focused(pid), CFEqual(current, element) else {
            return (status == .success ? .unverified : .failed, nil)
        }
        guard paste(replacement, pid: pid), let after = waitForEdit(replacement, at: location, in: element, before: before, expected: expected, seconds: 1) else { return (.failed, nil) }
        return (.success, after)
    }
    /// Polls every 20 ms; native text views update synchronously, Chrome after about 50 ms.
    /// Chrome reports an empty paragraph as "\n" and drops it once text goes in, so a changed value that holds
    /// `inserted` at `location` also counts (measured: "\n" + （） → "（）").
    private func waitForEdit(_ inserted: String, at location: Int, in element: AXUIElement, before: String, expected: String, seconds: TimeInterval) -> String? {
        let deadline = Date().addingTimeInterval(seconds)
        while true {
            if let value = text(element) {
                if value == expected { return value }
                if value != before {
                    if inserted.isEmpty { return value }
                    let span = NSRange(location: location, length: inserted.utf16.count)
                    if NSMaxRange(span) <= value.utf16.count, (value as NSString).substring(with: span) == inserted { return value }
                }
            }
            if Date() >= deadline { return nil }
            usleep(20_000)
        }
    }
    /// Chrome applies a new selection about 30 ms later (measured), so the readback is polled.
    private func select(_ selection: NSRange, on element: AXUIElement) -> Bool {
        guard setRange(selection, on: element) else { return false }
        let deadline = Date().addingTimeInterval(0.3)
        while range(element) != selection {
            if Date() >= deadline { return false }
            usleep(20_000)
        }
        return true
    }
    /// Sends ⌘V with `text` on the clipboard, then puts the previous clipboard back unless something else copied meanwhile.
    private func paste(_ text: String, pid: pid_t) -> Bool {
        // Restoring an empty selection deletes the selected brackets; there is nothing to paste.
        if text.isEmpty {
            guard let source = CGEventSource(stateID: .privateState),
                  let down = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: false) else { return false }
            down.flags = []; up.flags = []
            down.postToPid(pid); up.postToPid(pid)
            return true
        }
        let pasteboard = NSPasteboard.general
        // A paste within the restore delay keeps the user's clipboard from the first one, not our own text.
        let previous = pendingClipboard.flatMap { $0.change == pasteboard.changeCount ? $0.items : nil } ?? (pasteboard.pasteboardItems ?? []).map { item in
            var saved: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types { if let data = item.data(forType: type) { saved[type] = data } }
            return saved
        }
        guard let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else { return false }
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else { return false }
        let change = pasteboard.changeCount
        pendingClipboard = (previous, change)
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.postToPid(pid)
        up.postToPid(pid)
        // The target reads the clipboard asynchronously; restore after it has had time to paste.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard pasteboard.changeCount == change else { return }
            self?.pendingClipboard = nil
            pasteboard.clearContents()
            let items = previous.map { saved -> NSPasteboardItem in
                let item = NSPasteboardItem()
                for (type, data) in saved { item.setData(data, forType: type) }
                return item
            }
            if !items.isEmpty { pasteboard.writeObjects(items) }
        }
        return true
    }
    func restore(expectedPID: pid_t? = nil) -> String {
        guard let r = recovery, expectedPID == nil || expectedPID == r.pid, text(r.element) == r.after else { return L("restoreUnavailable") }
        // Only the original input element and unchanged text may be restored.
        guard select(r.range, on: r.element),
              write(r.replacement, at: r.range.location, to: r.element, pid: r.pid, before: r.after, expected: r.before).0 == .success else { return L("failed") }
        recovery = nil
        return select(r.original, on: r.element) ? L("restored") : L("partial")
    }
}
