import AppKit
import ApplicationServices

/// Reads the URL shown in the front browser window with the Accessibility API (LinkMaker / DocklessLauncher's method:
/// the AXURL of the window's AXWebArea). Works with Safari, Firefox and the Chromium browsers without Apple events.
enum FrontBrowser {
    static let bundleIDs: [String: String] = [
        "com.apple.Safari": "Safari",
        "com.apple.SafariTechnologyPreview": "Safari Technology Preview",
        "com.google.Chrome": "Google Chrome",
        "com.google.Chrome.canary": "Google Chrome Canary",
        "org.mozilla.firefox": "Firefox",
        "com.microsoft.edgemac": "Microsoft Edge",
        "com.brave.Browser": "Brave Browser",
        "company.thebrowser.Browser": "Arc",
        "com.vivaldi.Vivaldi": "Vivaldi",
        "com.operasoftware.Opera": "Opera",
        "com.openai.atlas": "ChatGPT Atlas",
    ]

    enum Failure: Error, Equatable {
        case notTrusted
        case noBrowser
        case noURL(String)
    }

    /// The browser whose window is frontmost on screen (this app's own windows are skipped), as (name, pid).
    static func frontmost() -> (name: String, pid: pid_t)? {
        let own = ProcessInfo.processInfo.processIdentifier
        let running = Dictionary(NSWorkspace.shared.runningApplications.compactMap { app -> (pid_t, String)? in
            guard let id = app.bundleIdentifier, let name = bundleIDs[id] else { return nil }
            return (app.processIdentifier, name)
        }, uniquingKeysWith: { first, _ in first })
        guard !running.isEmpty else { return nil }
        // Window list is front to back; owner PIDs are readable without Screen Recording.
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        for window in windows where (window[kCGWindowLayer as String] as? Int) == 0 {
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t, pid != own, let name = running[pid] else { continue }
            return (name, pid)
        }
        return nil
    }

    /// URL of the page in the front browser window.
    static func currentURL() -> Result<(browser: String, url: String), Failure> {
        guard AXIsProcessTrusted() else { return .failure(.notTrusted) }
        guard let browser = frontmost() else { return .failure(.noBrowser) }
        let app = AXUIElementCreateApplication(browser.pid)
        // Chrome and Firefox build their accessibility tree on request.
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        guard let window = element(app, kAXFocusedWindowAttribute) ?? element(app, kAXMainWindowAttribute)
                ?? (value(app, kAXWindowsAttribute) as? [AXUIElement])?.first else { return .failure(.noURL(browser.name)) }
        var budget = 4000
        guard let area = webArea(window, depth: 0, budget: &budget), let raw = value(area, "AXURL") else { return .failure(.noURL(browser.name)) }
        let url = (raw as? URL)?.absoluteString ?? (raw as? String) ?? ""
        return url.isEmpty ? .failure(.noURL(browser.name)) : .success((browser.name, url))
    }

    private static func value(_ e: AXUIElement, _ name: String) -> CFTypeRef? {
        var v: CFTypeRef?
        return AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success ? v : nil
    }
    private static func element(_ e: AXUIElement, _ name: String) -> AXUIElement? {
        guard let v = value(e, name), CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return (v as! AXUIElement)
    }
    /// Depth-first and bounded, so a huge page cannot stall the app.
    private static func webArea(_ e: AXUIElement, depth: Int, budget: inout Int) -> AXUIElement? {
        budget -= 1
        guard budget > 0, depth < 30 else { return nil }
        if value(e, kAXRoleAttribute) as? String == "AXWebArea", value(e, "AXURL") != nil { return e }
        for child in (value(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] {
            if let found = webArea(child, depth: depth + 1, budget: &budget) { return found }
        }
        return nil
    }
}
