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
        func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
            var value: CFTypeRef?
            return AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success ? value : nil
        }
        func numericText(_ element: AXUIElement) -> (String, String)? {
            for key in [kAXValueAttribute, kAXTitleAttribute, kAXDescriptionAttribute] {
                if let text = attribute(element, key) as? String, SignInversion.flip(text) != nil { return (key, text) }
            }
            return nil
        }
        func isField(_ element: AXUIElement) -> Bool {
            guard let role = attribute(element, kAXRoleAttribute) as? String,
                  [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role),
                  (attribute(element, kAXEnabledAttribute) as? Bool) != false,
                  (attribute(element, kAXSubroleAttribute) as? String) != kAXSecureTextFieldSubrole else { return false }
            return true
        }
        func focusedField() -> AXUIElement? {
            // Adobe modal dialogs can expose the dialog itself as the application focus.
            if let raw = attribute(root, kAXFocusedUIElementAttribute), CFGetTypeID(raw) == AXUIElementGetTypeID() {
                var focused = raw as! AXUIElement
                for _ in 0..<4 {
                    if isField(focused), numericText(focused) != nil { return focused }
                    guard let parent = attribute(focused, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
                    focused = parent as! AXUIElement
                }
            }
            let windows = (attribute(root, kAXWindowsAttribute) as? [AXUIElement]) ?? []
            var queue = windows, candidates: [AXUIElement] = []
            var visited = 0
            let deadline = Date().addingTimeInterval(0.15)
            while !queue.isEmpty && visited < 160 && Date() < deadline {
                let node = queue.removeFirst(); visited += 1
                if isField(node), numericText(node) != nil {
                    if (attribute(node, kAXFocusedAttribute) as? Bool) == true { return node }
                    if let text = attribute(node, kAXSelectedTextAttribute) as? String, !text.isEmpty,
                       SignInversion.flip(text) != nil { candidates.append(node) }
                }
                queue.append(contentsOf: (attribute(node, kAXChildrenAttribute) as? [AXUIElement]) ?? [])
            }
            return candidates.count == 1 ? candidates[0] : nil
        }
        guard let field = focusedField(), let (valueKey, original) = numericText(field) else {
            diagnostics.error("sign: no uniquely focused numeric AX field")
            status(L("sign.unsupported")); return false
        }
        func read(_ key: String) -> CFTypeRef? { attribute(field, key) }
        var selectedRange: CFRange?
        if let raw = read(kAXSelectedTextRangeAttribute), CFGetTypeID(raw) == AXValueGetTypeID() {
            var range = CFRange()
            if AXValueGetValue(raw as! AXValue, .cfRange, &range), range.location >= 0, range.length >= 0 { selectedRange = range }
        }
        let selectedText = read(kAXSelectedTextAttribute) as? String
        let selected: String
        if let range = selectedRange, range.length > 0 {
            let source = original as NSString
            guard range.location <= source.length, range.length <= source.length - range.location else { return false }
            selected = source.substring(with: NSRange(location: range.location, length: range.length))
        } else if let selectedText, !selectedText.isEmpty { selected = selectedText }
        else { selected = original }
        guard let converted = SignInversion.flip(selected) else { status(L("sign.notNumeric")); return false }
        func stillFocused() -> Bool {
            return allowed() && NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier
                && !ExcludedApps.shared.frontAppExcluded
                && focusedField().map { CFEqual($0, field) } == true
                && (read(valueKey) as? String) == original
        }
        guard stillFocused() else { return false }
        if converted == selected { return true }
        var settable = DarwinBoolean(false)
        if let range = selectedRange,
           let replacement = SignInversion.replacement(value: original, selection: NSRange(location: range.location, length: range.length)),
           AXUIElementIsAttributeSettable(field, kAXValueAttribute as CFString, &settable) == .success, settable.boolValue,
           AXUIElementSetAttributeValue(field, kAXValueAttribute as CFString, replacement.value as CFString) == .success {
            var selection = CFRange(location: replacement.selection.location, length: replacement.selection.length)
            if let value = AXValueCreate(.cfRange, &selection) { AXUIElementSetAttributeValue(field, kAXSelectedTextRangeAttribute as CFString, value) }
            status(L("sign.done")); return true
        }
        // Custom Illustrator dialogs lack writable AXValue/selection attributes. Type into the
        // verified numeric field instead, preserving the clipboard and native text-edit undo.
        // If selection information is absent, select the whole numeric field first.
        let hasSelection = (selectedRange?.length ?? 0) > 0 || !(selectedText ?? "").isEmpty
        guard SignInversion.flip(original) != nil else { status(L("sign.notNumeric")); return false }
        let eventSource = CGEventSource(stateID: .privateState)
        guard let down = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: false),
              let selectDown = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: true),
              let selectUp = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: false) else { return false }
        let text = Array(converted.utf16)
        down.flags = []; up.flags = []
        down.keyboardSetUnicodeString(stringLength: text.count, unicodeString: text)
        up.keyboardSetUnicodeString(stringLength: text.count, unicodeString: text)
        selectDown.flags = .maskCommand; selectUp.flags = .maskCommand
        DispatchQueue.main.async { [weak self] in
            guard let self, stillFocused() else { return }
            // Recheck the readable selection before dispatching any replacement.
            if let selectedText, (read(kAXSelectedTextAttribute) as? String) != selectedText { return }
            if !hasSelection { selectDown.postToPid(app.processIdentifier); selectUp.postToPid(app.processIdentifier) }
            down.postToPid(app.processIdentifier); up.postToPid(app.processIdentifier)
            self.status(L("sign.sent"))
        }
        return true
    }
}
