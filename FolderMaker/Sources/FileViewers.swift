import AppKit
import ApplicationServices

/// Finder and Path Finder: the folder of the front window, opening the new folder, and Path Finder's sidebar.
/// Reading windows follows LinkMaker's BrowserBridge.openFolderWindows() (Path Finder is often used with Finder closed).
enum FileViewers {
    struct Viewer { let name: String; let bundleID: String; let pid: pid_t }
    enum ScriptError: Error { case denied(String), failed(String) }

    static let pathFinderIDs = ["com.cocoatech.PathFinder-setapp", "com.cocoatech.PathFinder"]

    static func running() -> [Viewer] {
        let ids = ["com.apple.finder"] + pathFinderIDs
        return NSWorkspace.shared.runningApplications.compactMap { app in
            guard let id = app.bundleIdentifier, ids.contains(id), !app.isTerminated else { return nil }
            return Viewer(name: id == "com.apple.finder" ? "Finder" : "Path Finder", bundleID: id, pid: app.processIdentifier)
        }
    }

    enum Outcome { case value(String), denied, failed(String) }
    static func run(_ source: String) -> Outcome {
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

    /// Folder of the front Finder / Path Finder window (the viewer whose window is higher on screen wins).
    /// nil: no window with a folder (Recents and search results have none).
    static func frontFolder() -> Result<URL?, ScriptError> {
        // Owner PIDs in on-screen order are readable without Screen Recording.
        let onScreen = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? [])
            .filter { ($0[kCGWindowLayer as String] as? Int) == 0 }
            .compactMap { $0[kCGWindowOwnerPID as String] as? pid_t }
        // Viewers whose windows are on another Space or minimized still count, after those on screen.
        let viewers = running().sorted { (onScreen.firstIndex(of: $0.pid) ?? .max) < (onScreen.firstIndex(of: $1.pid) ?? .max) }
        var denied: String?
        var failure: String?
        for viewer in viewers {
            // Path Finder answers only `front finder window` (indexed windows fail: measured 2026-10-14).
            let source = viewer.bundleID == "com.apple.finder" ? """
            tell application id "com.apple.finder"
                repeat with w in Finder windows
                    try
                        return POSIX path of (target of w as alias)
                    end try
                end repeat
                return ""
            end tell
            """ : """
            tell application id "\(viewer.bundleID)"
                if (count of finder windows) is 0 then return ""
                try
                    return POSIX path of (target of front finder window)
                on error
                    return ""
                end try
            end tell
            """
            switch run(source) {
            case .denied: denied = denied ?? viewer.name
            case .failed(let message): failure = failure ?? message
            case .value(let path):
                if !path.isEmpty { return .success(URL(fileURLWithPath: path, isDirectory: true)) }
            }
        }
        if let denied { return .failure(.denied(denied)) }
        if let failure { return .failure(.failed(failure)) }
        return .success(nil)
    }

    /// Recent folders of Finder (FXRecentFolders) and Path Finder (PFFileHistoryManager), newest first, as FolderHopper reads them (from LinkMaker 1.2.5).
    /// Read-only; other apps' preferences are never changed. Missing folders and packages are skipped.
    static func recentFolders(limit: Int = 10) -> [URL] {
        func preferences(_ domain: String) -> [String: Any] {
            CFPreferencesCopyMultiple(nil, domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String: Any] ?? [:]
        }
        func resolve(_ data: Data) -> URL? {
            var stale = false
            return try? URL(resolvingBookmarkData: data, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale)
        }
        var urls = (preferences("com.apple.finder")["FXRecentFolders"] as? [[String: Any]] ?? []).compactMap { ($0["file-bookmark"] as? Data).flatMap(resolve) }
        for domain in ["com.cocoatech.PathFinder-setapp", "com.cocoatech.PathFinder"] {
            guard let data = preferences(domain)["PFFileHistoryManager"] as? Data,
                  let decoder = try? NSKeyedUnarchiver(forReadingFrom: data) else { continue }
            decoder.requiresSecureCoding = true
            decoder.setClass(PFHistoryArchive.self, forClassName: "PFFileHistoryMgr")
            let history = decoder.decodeObject(of: PFHistoryArchive.self, forKey: NSKeyedArchiveRootObjectKey)
            decoder.finishDecoding()
            urls += (history?.folders ?? []).compactMap(resolve)
        }
        var seen = Set<String>()
        return Array(urls.filter {
            let url = $0.standardizedFileURL
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            return values?.isDirectory == true && values?.isPackage != true && seen.insert(url.path).inserted
        }.prefix(limit))
    }

    /// Installed Path Finder (Setapp first, as on this Mac).
    static var pathFinderURL: URL? {
        for id in pathFinderIDs { if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) { return url } }
        return nil
    }
    static var pathFinderBundleID: String? {
        if let app = running().first(where: { pathFinderIDs.contains($0.bundleID) }) { return app.bundleID }
        return pathFinderIDs.first { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
    }

    enum Choice: String, CaseIterable { case automatic, pathFinder, finder }

    /// Automatic: Path Finder when it is running, else Finder (Finder windows are often closed on this Mac).
    static func usesPathFinder(_ choice: Choice) -> Bool {
        switch choice {
        case .finder: return false
        case .pathFinder: return pathFinderURL != nil
        case .automatic: return running().contains { pathFinderIDs.contains($0.bundleID) }
        }
    }

    /// Opens the folder (reveal: selected in its parent instead).
    static func show(_ folder: URL, choice: Choice, reveal: Bool) {
        if usesPathFinder(choice), let app = pathFinderURL {
            if reveal, let id = pathFinderBundleID {
                // `reveal` selects the item in its parent window; an error falls back to opening the parent.
                if case .value = run("tell application id \"\(id)\"\nactivate\nreveal POSIX file \(quoted(folder.path))\nend tell") { return }
            }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.open([reveal ? folder.deletingLastPathComponent() : folder], withApplicationAt: app, configuration: configuration)
        } else if reveal {
            NSWorkspace.shared.activateFileViewerSelecting([folder])
        } else {
            NSWorkspace.shared.open(folder)
        }
    }

    static func quoted(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    enum SidebarError: Error { case noPathFinder, noAccessibility, denied, revealFailed(String), menuNotFound }

    /// The macro's last Path Finder steps: select the new folder in its parent, then ファイル › サイドバーへ追加.
    /// The menu item is pressed through Accessibility (no keystrokes are sent).
    static func addToPathFinderSidebar(_ folder: URL, completion: @escaping (Result<Void, SidebarError>) -> Void) {
        guard let id = pathFinderBundleID else { return completion(.failure(.noPathFinder)) }
        guard AXIsProcessTrusted() else { return completion(.failure(.noAccessibility)) }
        switch run("tell application id \"\(id)\"\nactivate\nreveal POSIX file \(quoted(folder.path))\nend tell") {
        case .denied: return completion(.failure(.denied))
        case .failed(let message): return completion(.failure(.revealFailed(message)))
        case .value: break
        }
        // Path Finder needs a moment to select the revealed item; the menu is retried for up to 2 seconds.
        func attempt(_ remaining: Int) {
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first else { return completion(.failure(.noPathFinder)) }
            if pressSidebarItem(pid: app.processIdentifier) { return completion(.success(())) }
            if remaining == 0 { return completion(.failure(.menuNotFound)) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { attempt(remaining - 1) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { attempt(6) }
    }

    /// Titles of the item in Path Finder's File menu (Japanese and English UI).
    static let sidebarTitles: Set<String> = ["サイドバーへ追加", "サイドバーに追加", "Add to Sidebar"]

    private static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }
    private static func children(_ element: AXUIElement) -> [AXUIElement] {
        (attribute(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []
    }
    private static func pressSidebarItem(pid: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        guard let bar = attribute(app, kAXMenuBarAttribute) else { return false }
        // swiftlint:disable:next force_cast
        for top in children(bar as! AXUIElement) {
            for menu in children(top) {
                for item in children(menu) {
                    guard let title = attribute(item, kAXTitleAttribute) as? String, sidebarTitles.contains(title) else { continue }
                    if let enabled = attribute(item, kAXEnabledAttribute) as? Bool, !enabled { return false }
                    return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success
                }
            }
        }
        return false
    }
}

/// Path Finder's folder history archive (class PFFileHistoryMgr), decoded with secure coding.
final class PFHistoryArchive: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }
    let folders: [Data]
    required init?(coder: NSCoder) {
        folders = coder.decodeObject(of: [NSArray.self, NSData.self], forKey: "folders") as? [Data] ?? []
    }
    func encode(with coder: NSCoder) { coder.encode(folders, forKey: "folders") }
}

/// The macro's 「シンボリックリンク」 group: `ln -s -f` of the new folder into a collection folder such as AT-Recent.
enum RecentLink {
    enum Failure: Error { case noFolder, occupied, failed(String) }
    /// Replaces only an existing symbolic link of the same name; a real file or folder there is left alone (B10).
    static func make(to folder: URL, in collection: URL) -> Result<URL, Failure> {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: collection.path, isDirectory: &isDirectory), isDirectory.boolValue else { return .failure(.noFolder) }
        let link = collection.appendingPathComponent(folder.lastPathComponent)
        if let attributes = try? FileManager.default.attributesOfItem(atPath: link.path) {
            guard attributes[.type] as? FileAttributeType == .typeSymbolicLink else { return .failure(.occupied) }
            do { try FileManager.default.removeItem(at: link) } catch { return .failure(.failed(error.localizedDescription)) }
        }
        do { try FileManager.default.createSymbolicLink(at: link, withDestinationURL: folder) } catch { return .failure(.failed(error.localizedDescription)) }
        return .success(link)
    }
}
