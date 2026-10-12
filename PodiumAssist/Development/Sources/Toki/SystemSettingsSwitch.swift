import AppKit
@preconcurrency import ApplicationServices

/// Turns a switch in System Settings on or off by its AXIdentifier (measured: the label is localized, the identifier is not).
/// Used where macOS refuses the preference write (com.apple.universalaccess needs Full Disk Access) and only the
/// System Settings switch applies the change at once. Requires the Accessibility permission.
enum SystemSettingsSwitch {
    static let reduceTransparency = (pane: "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?Display",
                                     identifier: "AX_REDUCE_TRANSPARENCY")
    static let reduceMotion = (pane: "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?Motion",
                               identifier: "AX_REDUCE_MOTION")
    private static let settingsBundleID = "com.apple.systempreferences"

    @MainActor
    static func set(pane: String, identifier: String, to value: Bool) async throws {
        guard AXIsProcessTrusted() else { throw SettingsError(L("アクセシビリティの許可が必要です。設定の「起動・常駐」で許可してください。")) }
        guard let url = URL(string: pane) else { return }
        let wasRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: settingsBundleID).isEmpty
        NSWorkspace.shared.open(url)
        defer {
            // Leave System Settings as it was: close it only when it was opened for this change.
            if !wasRunning { NSRunningApplication.runningApplications(withBundleIdentifier: settingsBundleID).forEach { $0.terminate() } }
        }
        // The pane loads asynchronously; wait up to about 8 seconds for the switch to appear.
        var element: AXUIElement?
        for _ in 0..<40 {
            try await Task.sleep(nanoseconds: 200_000_000)
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: settingsBundleID).first,
               let found = find(identifier, in: AXUIElementCreateApplication(app.processIdentifier)) {
                element = found
                break
            }
        }
        guard let element else { throw SettingsError(L("システム設定の項目が見つかりませんでした。")) }
        if state(of: element) != value {
            AXUIElementPerformAction(element, kAXPressAction as CFString)
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        guard state(of: element) == value else { throw SettingsError(L("システム設定を変更できませんでした。")) }
    }

    private static func state(of element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success else { return nil }
        return (value as? NSNumber)?.boolValue
    }

    /// Depth-first search through windows; bounded so a changed layout cannot loop for long.
    private static func find(_ identifier: String, in root: AXUIElement) -> AXUIElement? {
        var stack = [root]
        var visited = 0
        while let element = stack.popLast(), visited < 5000 {
            visited += 1
            var id: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &id) == .success, id as? String == identifier {
                return element
            }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
               let list = children as? [AXUIElement] {
                stack.append(contentsOf: list.reversed())
            }
        }
        return nil
    }
}
