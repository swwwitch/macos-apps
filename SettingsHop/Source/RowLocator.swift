import AppKit
import ApplicationServices

/// Scrolls a System Settings pane to one row after it opens (needs Accessibility permission).
/// URL anchors do not scroll to rows such as Desktop & Dock › Default web browser, so the row's control is focused through AX,
/// which makes System Settings scroll it into view.
enum RowLocator {
    struct Target {
        /// Settings extension whose Localizable.loctable has the row label in every language.
        let extensionPath: String
        let labelKey: String
    }

    /// The row label in all languages System Settings may be shown in.
    static func labels(_ target: Target) -> Set<String> {
        let url = URL(fileURLWithPath: target.extensionPath).appendingPathComponent("Contents/Resources/Localizable.loctable")
        guard let data = try? Data(contentsOf: url),
              let table = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: [String: Any]] else { return [target.labelKey] }
        return Set(table.values.compactMap { $0[target.labelKey] as? String }).union([target.labelKey])
    }

    /// Waits for the pane to load (up to `timeout`), then focuses the row's control and opens its popup (as Space would).
    /// Runs off the main thread; returns whether the row was found.
    static func reveal(_ target: Target, timeout: TimeInterval = 5) -> Bool {
        let names = labels(target)
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: Pane.settingsBundleID).first,
               let (label, parent) = find(names, in: AXUIElementCreateApplication(app.processIdentifier)) {
                // Focusing the popup next to the label scrolls the row into view; AXScrollToVisible alone reports success without scrolling.
                let control = children(parent).first { role($0) == kAXPopUpButtonRole as String }
                if let control, AXUIElementSetAttributeValue(control, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success {
                    Thread.sleep(forTimeInterval: 0.3)
                    AXUIElementPerformAction(control, kAXPressAction as CFString)
                    return true
                }
                return AXUIElementPerformAction(label, "AXScrollToVisible" as CFString) == .success
            }
            Thread.sleep(forTimeInterval: 0.2)
        } while Date() < deadline
        return false
    }

    private static func value(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var result: AnyObject?
        return AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success ? result : nil
    }
    private static func role(_ element: AXUIElement) -> String? { value(element, kAXRoleAttribute) as? String }
    private static func children(_ element: AXUIElement) -> [AXUIElement] { value(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] }

    /// Depth-first search for a static text whose value is one of `names`; returns it with its parent.
    /// Walking the whole app takes about 0.1 s here (only AppleScript's `entire contents` is slow), so no path is assumed.
    private static func find(_ names: Set<String>, in element: AXUIElement, parent: AXUIElement? = nil, depth: Int = 0) -> (AXUIElement, AXUIElement)? {
        guard depth < 40 else { return nil }
        if let parent, role(element) == kAXStaticTextRole as String, let text = value(element, kAXValueAttribute) as? String, names.contains(text) {
            return (element, parent)
        }
        for child in children(element) {
            if let found = find(names, in: child, parent: element, depth: depth + 1) { return found }
        }
        return nil
    }
}
