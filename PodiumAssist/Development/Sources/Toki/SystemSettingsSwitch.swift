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
    static let settingsBundleID = "com.apple.systempreferences"

    @MainActor
    static func set(pane: String, identifier: String, to value: Bool) async throws {
        try await withPane(pane) { root in
            let element = try await waitFor(identifier, in: root)
            try await press(element, to: value)
        }
    }

    /// Opens the pane, runs `body` with System Settings' accessibility root, and leaves System Settings as it was:
    /// closed again only when it was opened for this change.
    @MainActor
    static func withPane(_ pane: String, _ body: (AXUIElement) async throws -> Void) async throws {
        guard AXIsProcessTrusted() else { throw SettingsError(L("アクセシビリティの許可が必要です。［設定…］の「起動・常駐」で許可してください。")) }
        guard let url = URL(string: pane) else { return }
        let wasRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: settingsBundleID).isEmpty
        NSWorkspace.shared.open(url)
        defer {
            if !wasRunning { NSRunningApplication.runningApplications(withBundleIdentifier: settingsBundleID).forEach { $0.terminate() } }
        }
        // The app may still be launching; wait up to about 4 seconds for its process.
        for _ in 0..<20 {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: settingsBundleID).first {
                try await body(AXUIElementCreateApplication(app.processIdentifier))
                return
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        throw SettingsError(L("システム設定の項目が見つかりませんでした。"))
    }

    /// The pane and its sheets load asynchronously; waits up to about 8 seconds for the element to appear.
    @MainActor
    static func waitFor(_ identifier: String, in root: AXUIElement) async throws -> AXUIElement {
        for _ in 0..<40 {
            try await Task.sleep(nanoseconds: 200_000_000)
            if let found = find(identifier, in: root) { return found }
        }
        throw SettingsError(L("システム設定の項目が見つかりませんでした。"))
    }

    /// Presses a switch (AXCheckBox) when it differs from `value`, then checks the result.
    @MainActor
    static func press(_ element: AXUIElement, to value: Bool) async throws {
        if state(of: element) != value {
            AXUIElementPerformAction(element, kAXPressAction as CFString)
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        guard state(of: element) == value else { throw SettingsError(L("システム設定を変更できませんでした。")) }
    }

    static func state(of element: AXUIElement) -> Bool? {
        (attribute(kAXValueAttribute, of: element) as? NSNumber)?.boolValue
    }

    static func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    /// Depth-first search through windows; bounded so a changed layout cannot loop for long.
    static func find(_ identifier: String, in root: AXUIElement) -> AXUIElement? {
        var stack = [root]
        var visited = 0
        while let element = stack.popLast(), visited < 5000 {
            visited += 1
            if attribute(kAXIdentifierAttribute, of: element) as? String == identifier { return element }
            if let list = attribute(kAXChildrenAttribute, of: element) as? [AXUIElement] {
                stack.append(contentsOf: list.reversed())
            }
        }
        return nil
    }
}
