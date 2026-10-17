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
    func text(_ element: AXUIElement) -> String? { attribute(element, kAXValueAttribute) as? String }
    func focused(_ pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.35)
        guard let value = attribute(app, kAXFocusedUIElementAttribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }
    func perform(pid: pid_t, action: String = "round", force: Bool = false, trimSpaces: Bool = false) -> String {
        guard !busy else { return L("busy") }
        busy = true; defer { busy = false }
        guard AccessibilitySection.isTrusted else { return AccessibilityText.text("blocked") }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
              let element = focused(pid), attribute(element, kAXSubroleAttribute) as? String != "AXSecureTextField" else { return L("unsupported") }
        // Web content (Safari, Chrome, Firefox, Electron apps such as Notion) cannot be edited reliably through AX
        // (measured): the index ranges drift from AXValue (Safari 7 characters after a few headings, Firefox skips list
        // bullets), writes are ignored (Safari, Chrome) or replace other text (Firefox: the last paragraph), and Google Docs
        // exposes only a stand-in field holding one space. It is edited with ⌘C/⌘V and arrow keys instead.
        if isWebContent(element) {
            return performViaCopy(markedSelection(element), paragraphEnd: markedSelectionEndsParagraph(element), element: element, pid: pid, action: action, force: force, trimSpaces: trimSpaces)
        }
        guard let original = range(element), let value = text(element),
              original.location <= value.utf16.count, original.length <= value.utf16.count - original.location else { return L("unsupported") }
        for key in [kAXSelectedTextAttribute, kAXSelectedTextRangeAttribute] {
            var settable: DarwinBoolean = false
            guard AXUIElementIsAttributeSettable(element, key as CFString, &settable) == .success, settable.boolValue else { return L("unsupported") }
        }
        let selected = (value as NSString).substring(with: original)
        guard attribute(element, kAXSelectedTextAttribute) as? String == selected else { return L("unsupported") }
        let edit = BracketEdit.make(selected, at: original.location, action: action, force: force, trimSpaces: trimSpaces,
                                    paragraphEnd: endsParagraph(value, at: NSMaxRange(original)))
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
    /// Web content carries text markers or DOM attributes; Notion's page editor has only the DOM ones (measured).
    private func isWebContent(_ element: AXUIElement) -> Bool {
        var names: CFArray?
        guard AXUIElementCopyAttributeNames(element, &names) == .success, let names = names as? [String] else { return false }
        return names.contains { ["AXSelectedTextMarkerRange", "AXDOMClassList", "AXDOMIdentifier", "ChromeAXNodeId"].contains($0) }
    }
    /// The selected text as the text markers of web content report it, or nil where they are not available.
    private func markedSelection(_ element: AXUIElement) -> String? {
        guard let markers = attribute(element, "AXSelectedTextMarkerRange") else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, "AXStringForTextMarkerRange" as CFString, markers, &value) == .success else { return nil }
        return value as? String
    }
    /// True at the end of the text or before a line or paragraph break.
    private func endsParagraph(_ value: String, at index: Int) -> Bool {
        let s = value as NSString
        guard index < s.length else { return true }
        guard let next = UnicodeScalar(s.character(at: index)) else { return false }
        return CharacterSet.newlines.contains(next)
    }
    /// Whether the text-marker selection ends a paragraph: the next character is a break, or there is none. False where markers are not available.
    private func markedSelectionEndsParagraph(_ element: AXUIElement) -> Bool {
        func parameterized(_ key: String, _ argument: CFTypeRef) -> CFTypeRef? {
            var value: CFTypeRef?
            guard AXUIElementCopyParameterizedAttributeValue(element, key as CFString, argument, &value) == .success else { return nil }
            return value
        }
        guard let markers = attribute(element, "AXSelectedTextMarkerRange"),
              let end = parameterized("AXEndTextMarkerForTextMarkerRange", markers) else { return false }
        guard let next = parameterized("AXNextTextMarkerForTextMarker", end), !CFEqual(next, end) else { return true }
        guard let span = parameterized("AXTextMarkerRangeForUnorderedTextMarkers", [end, next] as CFArray),
              let following = parameterized("AXStringForTextMarkerRange", span) as? String else { return false }
        return following.isEmpty || following.unicodeScalars.allSatisfy { CharacterSet.newlines.contains($0) }
    }
    /// Copies the selection with ⌘C, pastes the edit over it and selects with arrow keys. The result cannot be read
    /// back reliably, and there is no restore (the target's ⌘Z undoes it). An empty marker selection skips the copy;
    /// Google Docs' stand-in always reports " ", so its selection is copied. Without markers, nothing copied means no selection.
    private func performViaCopy(_ marked: String?, paragraphEnd: Bool, element: AXUIElement, pid: pid_t, action: String, force: Bool, trimSpaces: Bool) -> String {
        recovery = nil
        var copied = ""
        if marked != "" {
            let pasteboard = NSPasteboard.general
            let saved = pendingClipboard.flatMap { $0.change == pasteboard.changeCount ? $0.items : nil } ?? clipboardItems()
            let before = pasteboard.changeCount
            guard let source = CGEventSource(stateID: .privateState),
                  let down = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false) else { return L("failed") }
            down.flags = .maskCommand; up.flags = .maskCommand
            down.postToPid(pid); up.postToPid(pid)
            let deadline = Date().addingTimeInterval(0.5)
            while pasteboard.changeCount == before, Date() < deadline { usleep(20_000) }
            if pasteboard.changeCount != before {
                copied = pasteboard.string(forType: .string) ?? ""
                // paste() restores the user's clipboard, not the copied text.
                pendingClipboard = (saved, pasteboard.changeCount)
            } else if marked != nil && marked != " " {
                // A known selection that did not copy must not be pasted over (it would be deleted).
                return L("failed")
            }
        }
        let edit = BracketEdit.make(copied, at: 0, action: action, force: force, trimSpaces: trimSpaces, paragraphEnd: paragraphEnd)
        guard edit.replacement != copied else { restoreClipboard(); return L("unchanged") }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid, let current = focused(pid), CFEqual(current, element) else { restoreClipboard(); return L("cancelled") }
        guard paste(edit.replacement, pid: pid) else { restoreClipboard(); return L("failed") }
        usleep(150_000)
        return selectByKeys(edit, pid: pid) ? L("success") : L("partial")
    }
    private func clipboardItems() -> [[NSPasteboard.PasteboardType: Data]] {
        (NSPasteboard.general.pasteboardItems ?? []).map { item in
            var saved: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types { if let data = item.data(forType: type) { saved[type] = data } }
            return saved
        }
    }
    /// Puts back the clipboard held in pendingClipboard unless something else copied meanwhile.
    private func restoreClipboard() {
        let pasteboard = NSPasteboard.general
        guard let pending = pendingClipboard, pending.change == pasteboard.changeCount else { return }
        pendingClipboard = nil
        pasteboard.clearContents()
        let items = pending.items.map { saved -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in saved { item.setData(data, forType: type) }
            return item
        }
        if !items.isEmpty { pasteboard.writeObjects(items) }
    }
    /// After a paste the caret follows the replacement; ← moves it back to the end of `edit.selection`, ⇧← selects it.
    /// Counted in characters, as the arrow keys move.
    private func selectByKeys(_ edit: BracketEdit, pid: pid_t) -> Bool {
        let replacement = edit.replacement as NSString
        let selection = edit.selection
        guard NSMaxRange(selection) <= replacement.length,
              let source = CGEventSource(stateID: .privateState) else { return false }
        let tail = replacement.substring(from: NSMaxRange(selection)).count
        let inner = replacement.substring(with: selection).count
        for (count, flags) in [(tail, CGEventFlags()), (inner, CGEventFlags.maskShift)] {
            for _ in 0..<count {
                guard let down = CGEvent(keyboardEventSource: source, virtualKey: 123, keyDown: true),
                      let up = CGEvent(keyboardEventSource: source, virtualKey: 123, keyDown: false) else { return false }
                down.flags = flags; up.flags = flags
                down.postToPid(pid); up.postToPid(pid)
            }
        }
        return true
    }
    enum WriteResult { case success, unverified, failed }
    /// Replaces the selection through AX. When a native field reports success but keeps the text, the replacement is
    /// pasted with ⌘V instead (as MightyEdit does).
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
    /// Polls every 20 ms; native text views update synchronously. A changed value that holds `inserted` at `location`
    /// also counts, for fields that normalise the rest of the text.
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
    /// Some fields apply a new selection a little later, so the readback is polled.
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
        let previous = pendingClipboard.flatMap { $0.change == pasteboard.changeCount ? $0.items : nil } ?? clipboardItems()
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
            self?.restoreClipboard()
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
