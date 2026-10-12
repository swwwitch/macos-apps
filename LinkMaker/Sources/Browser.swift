import AppKit
import ApplicationServices

/// A supported browser. The Keyboard Maestro group targeted Safari, Chrome, Firefox, Edge and ChatGPT Atlas;
/// the other Chromium browsers behave like Chrome.
struct Browser: Hashable {
    enum Kind { case safari, chromium, firefox }
    let name: String
    let bundleID: String
    let kind: Kind

    static let all: [Browser] = [
        Browser(name: "Safari", bundleID: "com.apple.Safari", kind: .safari),
        Browser(name: "Google Chrome", bundleID: "com.google.Chrome", kind: .chromium),
        Browser(name: "Firefox", bundleID: "org.mozilla.firefox", kind: .firefox),
        Browser(name: "Microsoft Edge", bundleID: "com.microsoft.edgemac", kind: .chromium),
        Browser(name: "Brave Browser", bundleID: "com.brave.Browser", kind: .chromium),
        Browser(name: "Arc", bundleID: "company.thebrowser.Browser", kind: .chromium),
        Browser(name: "Vivaldi", bundleID: "com.vivaldi.Vivaldi", kind: .chromium),
        Browser(name: "ChatGPT Atlas", bundleID: "com.openai.atlas", kind: .chromium),
    ]
    static func find(_ bundleID: String?) -> Browser? { all.first { $0.bundleID == bundleID } }

    /// File ➤ New Private Window (Safari/Chromium ⇧⌘N, Firefox ⇧⌘P).
    var privateWindowKey: (UInt16, CGEventFlags) { kind == .firefox ? (35, [.maskCommand, .maskShift]) : (45, [.maskCommand, .maskShift]) }
    /// Reload ignoring cache (Safari ⌥⌘R, others ⇧⌘R), as in 「強制リロード」.
    var forceReloadKey: (UInt16, CGEventFlags) { kind == .safari ? (15, [.maskCommand, .maskAlternate]) : (15, [.maskCommand, .maskShift]) }
    /// AppleScript can list tabs in Safari and the Chromium browsers (not Firefox).
    var canListTabs: Bool { kind != .firefox }
    var isInstalled: Bool { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil }
}

struct PageInfo { var title: String; var url: String }

enum BrowserBridge {
    // MARK: Reading the page (Accessibility)

    /// Title and URL of the focused tab. URL from the web area (DocklessLauncher's method); the title from the web area,
    /// falling back to the window title.
    static func page(pid: pid_t) -> PageInfo? {
        guard AXIsProcessTrusted() else { return nil }
        let app = AXUIElementCreateApplication(pid)
        // Chrome and Firefox build their accessibility tree on request.
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        guard let window = element(app, kAXFocusedWindowAttribute) ?? (value(app, kAXWindowsAttribute) as? [AXUIElement])?.first else { return nil }
        let windowTitle = value(window, kAXTitleAttribute) as? String ?? ""
        var budget = 4000
        guard let area = webArea(window, depth: 0, budget: &budget) else { return PageInfo(title: windowTitle, url: "") }
        var url = ""
        if let u = value(area, "AXURL") { url = (u as? URL)?.absoluteString ?? (u as? String) ?? "" }
        // Chrome puts the page title in AXTitle, Safari in AXDescription.
        let title = [value(area, kAXTitleAttribute) as? String, value(area, kAXDescriptionAttribute) as? String]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty } ?? windowTitle
        return PageInfo(title: title, url: url)
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
    private static func webArea(_ e: AXUIElement, depth: Int, budget: inout Int) -> AXUIElement? {
        budget -= 1
        guard budget > 0, depth < 30 else { return nil }
        if value(e, kAXRoleAttribute) as? String == "AXWebArea", value(e, "AXURL") != nil { return e }
        for child in (value(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] {
            if let found = webArea(child, depth: depth + 1, budget: &budget) { return found }
        }
        return nil
    }

    /// Fallback when the web area has no URL (the engine's ⌘L ⌘C for Firefox/Edge): copies the address bar
    /// and puts the previous clipboard back unless something else was copied meanwhile.
    static func addressBarURL(pid: pid_t) -> String? {
        let pasteboard = NSPasteboard.general
        let saved = PasteboardSnapshot.take()
        let before = pasteboard.changeCount
        key(37, .maskCommand, to: pid)                         // ⌘L
        usleep(120_000)
        key(8, .maskCommand, to: pid)                          // ⌘C
        guard waitForChange(from: before, timeout: 0.6) else { key(53, [], to: pid); return nil }
        let copied = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let ours = pasteboard.changeCount
        key(53, [], to: pid)                                   // Esc (leave the address bar)
        if pasteboard.changeCount == ours { saved.restore() }
        guard let copied, copied.contains("://") || copied.contains(".") else { return nil }
        return copied.contains("://") ? copied : "https://" + copied
    }

    // MARK: Driving the browser (keys posted to the process, so our own hotkeys are not hit again)

    static func key(_ code: UInt16, _ flags: CGEventFlags, to pid: pid_t) {
        guard let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false) else { return }
        down.flags = flags; up.flags = flags
        down.postToPid(pid); up.postToPid(pid)
    }

    /// Puts `url` in the address bar of the window in front and opens it (⌘L, paste, Return), like the macros.
    /// Pasting avoids the address bar's inline completion; the clipboard is restored afterwards.
    static func go(to url: String, pid: pid_t, afterDelay delay: TimeInterval = 0) {
        let saved = PasteboardSnapshot.take()
        let pasteboard = NSPasteboard.general
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            key(37, .maskCommand, to: pid)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                pasteboard.clearContents()
                pasteboard.setString(url, forType: .string)
                let ours = pasteboard.changeCount
                key(9, .maskCommand, to: pid)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    key(36, [], to: pid)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        if pasteboard.changeCount == ours { saved.restore() }
                    }
                }
            }
        }
    }

    /// Opens URLs in a specific browser (a new tab, like 「SafariControl NewTab」/「OpenURL」).
    static func open(_ urls: [String], in browser: Browser, activate: Bool = true, completion: @escaping (Bool) -> Void) {
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleID) else { completion(false); return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activate
        NSWorkspace.shared.open(urls.compactMap(URL.init(string:)), withApplicationAt: app, configuration: configuration) { _, error in
            DispatchQueue.main.async { completion(error == nil) }
        }
    }

    static func waitForChange(from count: Int, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while NSPasteboard.general.changeCount == count && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        return NSPasteboard.general.changeCount != count
    }

    // MARK: Apple events (only for tab lists and the Finder window)

    enum ScriptResult { case value(String), denied, failed(String) }

    static func run(_ source: String) -> ScriptResult {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return .failed("") }
        let result = script.executeAndReturnError(&error)
        if let error {
            let number = error[NSAppleScript.errorNumber] as? Int ?? 0
            if number == -1743 || number == -1744 { return .denied }
            return .failed(error[NSAppleScript.errorMessage] as? String ?? String(number))
        }
        return .value(result.stringValue ?? "")
    }

    /// Title and URL of every tab in the front window. Separators are control characters that never appear in titles.
    static func tabs(of browser: Browser) -> Result<[(title: String, url: String)], ScriptError> {
        let id = browser.bundleID
        let body = browser.kind == .safari
            ? "set {t, u} to {name, URL} of every tab of front window"
            : "set {t, u} to {title, URL} of every tab of front window"
        let source = """
        tell application id "\(id)"
            if (count of windows) is 0 then return ""
            \(body)
        end tell
        set out to ""
        repeat with i from 1 to count of u
            set x to item i of u
            if x is missing value then set x to ""
            set y to item i of t
            if y is missing value then set y to ""
            set out to out & y & (ASCII character 31) & x & (ASCII character 30)
        end repeat
        return out
        """
        switch run(source) {
        case .denied: return .failure(.denied)
        case .failed(let message): return .failure(.failed(message))
        case .value(let text):
            let tabs = text.split(separator: "\u{1E}").compactMap { record -> (title: String, url: String)? in
                let parts = record.split(separator: "\u{1F}", omittingEmptySubsequences: false)
                return parts.count == 2 ? (String(parts[0]), String(parts[1])) : nil
            }
            return .success(tabs)
        }
    }
    enum ScriptError: Error { case denied, failed(String) }

    /// Folder of the front Finder window, or nil (no window, or a window without a folder such as Recents).
    static func frontFinderFolder() -> Result<URL?, ScriptError> {
        let source = """
        tell application id "com.apple.finder"
            if (count of Finder windows) is 0 then return ""
            try
                return POSIX path of (target of front Finder window as alias)
            on error
                return ""
            end try
        end tell
        """
        switch run(source) {
        case .denied: return .failure(.denied)
        case .failed(let message): return .failure(.failed(message))
        case .value(let path): return .success(path.isEmpty ? nil : URL(fileURLWithPath: path, isDirectory: true))
        }
    }
}

/// Clipboard contents kept in memory only while the macros' clipboard steps run (B10: never overwrite a newer copy).
struct PasteboardSnapshot {
    var items: [[NSPasteboard.PasteboardType: Data]]
    static func take() -> PasteboardSnapshot {
        PasteboardSnapshot(items: (NSPasteboard.general.pasteboardItems ?? []).map { item in
            var data: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types { if let d = item.data(forType: type) { data[type] = d } }
            return data
        })
    }
    func restore() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        pasteboard.writeObjects(items.map { entry in
            let item = NSPasteboardItem()
            for (type, data) in entry { item.setData(data, forType: type) }
            return item
        })
    }
}
