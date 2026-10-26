import AppKit
import ApplicationServices

@MainActor
enum DebugFolderOpener {
    static func open(_ url: URL, showHidden: Bool) {
        let ids = ["com.cocoatech.PathFinder", "com.cocoatech.PathFinder-setapp"]
        let running = ids.flatMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0) }.first
        let applicationURL = running?.bundleURL ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.finder")
        guard let applicationURL else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open([url], withApplicationAt: applicationURL, configuration: config) { app, error in
            Task { @MainActor in
                guard error == nil, let app else { return }
                guard showHidden else { return }
                // Path Finder exposes this as a checked menu action, not a scripting property.
                // Never toggle blindly or request Accessibility permission automatically.
                if running != nil, AXIsProcessTrusted() {
                    enableInvisibles(in: app, attempts: 8)
                } else {
                    showInstructions(pathFinder: running != nil)
                }
            }
        }
    }

    private static func enableInvisibles(in app: NSRunningApplication, attempts: Int) {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else {
            if attempts > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { enableInvisibles(in: app, attempts: attempts - 1) }
            }
            return
        }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(root, kAXMenuBarAttribute as CFString, &value) == .success,
              let value else { showInstructions(pathFinder: true); return }
        let menuBar = unsafeBitCast(value, to: AXUIElement.self)
        let bundle = app.bundleURL.flatMap(Bundle.init(url:))
        let title = bundle?.localizedString(forKey: "Show invisibles", value: "Show invisibles", table: nil) ?? "Show invisibles"
        guard let item = find(title: title, in: menuBar, depth: 5) else {
            if attempts > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { enableInvisibles(in: app, attempts: attempts - 1) }
            } else { showInstructions(pathFinder: true) }
            return
        }
        var mark: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(item, kAXMenuItemMarkCharAttribute as CFString, &mark)
        if let mark = mark as? String, !mark.isEmpty { return }
        guard result == .success || result == .noValue else { showInstructions(pathFinder: true); return }
        if AXUIElementPerformAction(item, kAXPressAction as CFString) != .success {
            showInstructions(pathFinder: true)
        }
    }

    private static func find(title: String, in element: AXUIElement, depth: Int) -> AXUIElement? {
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value) == .success,
           value as? String == title { return element }
        guard depth > 0 else { return nil }
        value = nil
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let children = value as? [AXUIElement] else { return nil }
        for child in children {
            if let result = find(title: title, in: child, depth: depth - 1) { return result }
        }
        return nil
    }

    private static func showInstructions(pathFinder: Bool) {
        let alert = NSAlert()
        alert.messageText = L("不可視項目の表示")
        alert.informativeText = pathFinder
            ? L("OH MY FONTを開きました。不可視項目が見えない場合は、Path Finderの「表示」メニューで不可視項目の表示をオンにしてください。自動切替にはアクセシビリティの許可が必要です。")
            : L("OH MY FONTを開きました。FinderでCommand＋Shift＋ピリオドを押すと、不可視項目の表示を切り替えられます。")
        alert.runModal()
    }
}
