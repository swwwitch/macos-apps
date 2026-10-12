import AppKit
import ApplicationServices

/// Reads the page URL of the browser in front and hands a key back to it (Accessibility; no Apple events).
enum URLCondition {
    /// The URL of the focused window's web area, or nil (no permission, not a browser, nothing loaded).
    static func frontURL(pid: pid_t) -> String? {
        guard AXIsProcessTrusted() else { return nil }
        let app = AXUIElementCreateApplication(pid)
        // Chrome and Firefox build their accessibility tree on request.
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        guard let window = element(app, kAXFocusedWindowAttribute) ?? (value(app, kAXWindowsAttribute) as? [AXUIElement])?.first else { return nil }
        var budget = 4000
        return webAreaURL(window, depth: 0, budget: &budget)
    }
    private static func value(_ e: AXUIElement, _ name: String) -> CFTypeRef? {
        var v: CFTypeRef?
        return AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success ? v : nil
    }
    private static func element(_ e: AXUIElement, _ name: String) -> AXUIElement? {
        guard let v = value(e, name), CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return (v as! AXUIElement)
    }
    /// Depth-first, bounded, so a huge page cannot stall the key press.
    private static func webAreaURL(_ e: AXUIElement, depth: Int, budget: inout Int) -> String? {
        budget -= 1
        guard budget > 0, depth < 30 else { return nil }
        if value(e, kAXRoleAttribute) as? String == "AXWebArea", let url = value(e, "AXURL") {
            if let u = url as? URL { return u.absoluteString }
            if let s = url as? String { return s }
        }
        for child in (value(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] {
            if let found = webAreaURL(child, depth: depth + 1, budget: &budget) { return found }
        }
        return nil
    }
    /// Sends the shortcut to the app in front `taps` times. Posted to that process directly,
    /// so it does not hit this app's own hot key again.
    static func passThrough(_ shortcut: Shortcut, taps: Int, to pid: pid_t) {
        guard let source = CGEventSource(stateID: .privateState) else { return }
        var flags: CGEventFlags = []
        if shortcut.modifiers & Shortcut.command != 0 { flags.insert(.maskCommand) }
        if shortcut.modifiers & Shortcut.option != 0 { flags.insert(.maskAlternate) }
        if shortcut.modifiers & Shortcut.control != 0 { flags.insert(.maskControl) }
        if shortcut.modifiers & Shortcut.shift != 0 { flags.insert(.maskShift) }
        for _ in 0..<max(1, taps) {
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(shortcut.code), keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(shortcut.code), keyDown: false) else { return }
            down.flags = flags; up.flags = flags
            down.postToPid(pid); up.postToPid(pid)
        }
    }
}
