import AppKit
import Carbon

/// Result of one key press. Only the app name is kept (B12).
enum LaunchOutcome {
    case activated(String)
    case launched(String)
    case alreadyFront(String)
    case failed(String)
}

/// Starts or switches to an app with NSWorkspace / NSRunningApplication only (no Accessibility, no Apple events).
enum Launcher {
    /// How long to wait before checking that a plain activation really brought the app to the front.
    static let verifyDelay: TimeInterval = 0.35

    /// The app to launch, following the row's version mode. Standard mode asks Launch Services first and
    /// falls back to the saved path; "newest" compares every copy found; "path" uses only the saved path.
    static func appURL(for entry: LaunchEntry) -> URL? {
        let saved = entry.path.isEmpty ? nil : URL(fileURLWithPath: entry.path)
        let savedExists = saved.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        switch entry.versionMode {
        case .system:
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: entry.bundleID) { return url }
            return savedExists ? saved : nil
        case .path:
            return savedExists ? saved : nil
        case .newest:
            let found = copies(of: entry)
            return VersionRules.newest(found.map { ($0.url.path, $0.version) }).map { URL(fileURLWithPath: $0) }
        }
    }
    static func isInstalled(_ entry: LaunchEntry) -> Bool { appURL(for: entry) != nil }

    /// Every copy with the entry's Bundle ID: the ones Launch Services knows, the saved path, and apps one folder
    /// down next to the saved app's folder (/Applications/Adobe InDesign 2025/… and …2026/…).
    static func copies(of entry: LaunchEntry) -> [(url: URL, version: String)] {
        // Rows redraw often; a short cache keeps the folder scan off every redraw.
        let key = entry.bundleID + "|" + entry.path
        if let cached = copyCache[key], Date().timeIntervalSince(cached.time) < 5 { return cached.copies }
        let found = scanCopies(of: entry)
        copyCache[key] = (Date(), found)
        return found
    }
    private static var copyCache: [String: (time: Date, copies: [(url: URL, version: String)])] = [:]
    private static func scanCopies(of entry: LaunchEntry) -> [(url: URL, version: String)] {
        var urls = NSWorkspace.shared.urlsForApplications(withBundleIdentifier: entry.bundleID)
        if !entry.path.isEmpty {
            let saved = URL(fileURLWithPath: entry.path)
            urls.append(saved)
            let grandparent = saved.deletingLastPathComponent().deletingLastPathComponent()
            let folders = (try? FileManager.default.contentsOfDirectory(at: grandparent, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
            for folder in folders where folder.pathExtension.isEmpty {
                let inside = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
                urls += inside.filter { $0.pathExtension == "app" }
            }
        }
        var seen = Set<String>()
        return urls.compactMap { url -> (URL, String)? in
            let path = url.resolvingSymlinksInPath().standardizedFileURL.path
            guard seen.insert(path).inserted, let bundle = Bundle(url: url), bundle.bundleIdentifier == entry.bundleID else { return nil }
            let info = bundle.infoDictionary ?? [:]
            return (URL(fileURLWithPath: path), info["CFBundleShortVersionString"] as? String ?? info["CFBundleVersion"] as? String ?? "0")
        }
    }
    /// "21.6.0.57" etc. for the row caption.
    static func version(of url: URL) -> String? {
        let info = Bundle(url: url)?.infoDictionary ?? [:]
        return info["CFBundleShortVersionString"] as? String ?? info["CFBundleVersion"] as? String
    }

    /// The running process of the chosen copy. In standard mode any copy counts; otherwise only the chosen one,
    /// so pressing the key for InDesign 2026 does not bring a running 2025 forward.
    static func runningApp(for entry: LaunchEntry) -> NSRunningApplication? {
        let all = NSRunningApplication.runningApplications(withBundleIdentifier: entry.bundleID).filter { !$0.isTerminated }
        guard entry.versionMode != .system else { return all.first }
        guard let target = appURL(for: entry)?.resolvingSymlinksInPath().standardizedFileURL.path else { return nil }
        return all.first { $0.bundleURL?.resolvingSymlinksInPath().standardizedFileURL.path == target }
    }
    static func run(_ entry: LaunchEntry, completion: @escaping (LaunchOutcome) -> Void) {
        if let item = entry.openPath { openItem(item, entry: entry, completion: completion); return }
        let running = runningApp(for: entry)
        // Pressing the key for the app already in front does nothing.
        if let running, running.processIdentifier == NSWorkspace.shared.frontmostApplication?.processIdentifier {
            // The input source is still switched, so the key also works as "switch to ABC" in that app.
            if entry.switchToABC, !InputSource.selectABC() { completion(.failed(L("fail.abc"))); return }
            completion(.alreadyFront(entry.name)); return
        }
        if let running, !entry.reopen {
            running.unhide()
            _ = running.activate(options: entry.allWindows ? [.activateAllWindows, .activateIgnoringOtherApps] : [.activateIgnoringOtherApps])
            // macOS 14+ may refuse activation requested by a background app; fall back to Launch Services, which may not.
            DispatchQueue.main.asyncAfter(deadline: .now() + verifyDelay) {
                if NSWorkspace.shared.frontmostApplication?.processIdentifier == running.processIdentifier {
                    finish(entry, app: running, launched: false, completion: completion)
                } else {
                    open(entry, wasRunning: true, completion: completion)
                }
            }
            return
        }
        open(entry, wasRunning: running != nil, completion: completion)
    }

    /// Launch Services launch / activation. For a running app this also sends the "reopen" event,
    /// so an app without windows opens one (like clicking its Dock icon).
    private static func open(_ entry: LaunchEntry, wasRunning: Bool, completion: @escaping (LaunchOutcome) -> Void) {
        guard let url = appURL(for: entry) else { completion(.failed(String(format: L("fail.notFound"), entry.name))); return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { app, error in
            DispatchQueue.main.async {
                guard let app, error == nil else {
                    completion(.failed(String(format: L("fail.open"), entry.name, error?.localizedDescription ?? ""))); return
                }
                if entry.allWindows { _ = app.activate(options: [.activateAllWindows]) }
                finish(entry, app: app, launched: !wasRunning, completion: completion)
            }
        }
    }

    /// Opens a folder or file with the entry's app (launching it if needed), then applies the row's options.
    private static func openItem(_ path: String, entry: LaunchEntry, completion: @escaping (LaunchOutcome) -> Void) {
        let item = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: item.path) else { completion(.failed(String(format: L("fail.openPath"), path))); return }
        guard let url = appURL(for: entry) else { completion(.failed(String(format: L("fail.notFound"), entry.name))); return }
        let wasRunning = runningApp(for: entry) != nil
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false
        NSWorkspace.shared.open([item], withApplicationAt: url, configuration: configuration) { app, error in
            DispatchQueue.main.async {
                guard let app, error == nil else {
                    completion(.failed(String(format: L("fail.open"), entry.name, error?.localizedDescription ?? ""))); return
                }
                if entry.allWindows { _ = app.activate(options: [.activateAllWindows]) }
                finish(entry, app: app, launched: !wasRunning, completion: completion)
            }
        }
    }

    /// Delay before selecting ABC, so an app that restores its own input source on activation does not undo it.
    static let inputSourceDelay: TimeInterval = 0.2

    private static func finish(_ entry: LaunchEntry, app: NSRunningApplication, launched: Bool, completion: @escaping (LaunchOutcome) -> Void) {
        if entry.hideOthers { hideOthers(except: app) }
        let outcome: LaunchOutcome = launched ? .launched(entry.name) : .activated(entry.name)
        guard entry.switchToABC else { completion(outcome); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + inputSourceDelay) {
            completion(InputSource.selectABC() ? outcome : .failed(L("fail.abc")))
        }
    }

    /// Hides every other regular app (the Finder too, as in ⌥⌘H). Accessory apps such as this one are left alone.
    static func hideOthers(except app: NSRunningApplication) {
        for other in NSWorkspace.shared.runningApplications
        where other.activationPolicy == .regular && other.processIdentifier != app.processIdentifier && !other.isHidden {
            other.hide()
        }
    }
}

/// Keyboard input source switching (Text Input Sources; no permission needed).
enum InputSource {
    static let abcID = "com.apple.keylayout.ABC"
    /// Selects "ABC". False if it is not in the enabled input sources (System Settings > Keyboard > Input Sources).
    static func selectABC() -> Bool {
        let filter = [kTISPropertyInputSourceID as String: abcID] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
              let source = list.first else { return false }
        return TISSelectInputSource(source) == noErr
    }
}
