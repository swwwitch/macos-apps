import Foundation

/// One installed InDesign bundle. The marker file lives in its Contents/MacOS folder.
struct InDesignApp: Identifiable, Equatable {
    let url: URL
    let name: String
    let version: String
    var id: String { url.path }
    var macOSFolder: URL { url.appendingPathComponent("Contents/MacOS", isDirectory: true) }
    var markerFile: URL { macOSFolder.appendingPathComponent(AsyncExports.fileName, isDirectory: false) }
}

/// `off`: the marker file exists, so background export is disabled.
enum MarkerState: Equatable {
    case off
    case on
    case invalid
}

enum AsyncExports {
    static let fileName = "DisableAsyncExports.txt"
    static let bundleID = "com.adobe.InDesign"

    /// Finds InDesign bundles directly in each root or one level down ("Adobe InDesign 2026/Adobe InDesign 2026.app").
    static func discover(roots: [URL], extra: [URL] = []) -> [InDesignApp] {
        let fm = FileManager.default
        var candidates: [URL] = []
        for root in roots {
            guard let children = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { continue }
            for child in children where child.lastPathComponent.hasPrefix("Adobe InDesign") {
                if child.pathExtension == "app" { candidates.append(child); continue }
                let nested = (try? fm.contentsOfDirectory(at: child, includingPropertiesForKeys: nil)) ?? []
                candidates += nested.filter { $0.pathExtension == "app" }
            }
        }
        candidates += extra.filter { !$0.path.contains("/.Trash/") && !$0.path.contains("/Backups.backupdb/") }
        var seen = Set<String>()
        var apps: [InDesignApp] = []
        for url in candidates {
            let resolved = url.resolvingSymlinksInPath().standardizedFileURL
            guard seen.insert(resolved.path).inserted, let app = app(at: resolved) else { continue }
            apps.append(app)
        }
        // Newest release first.
        return apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedDescending }
    }

    /// Returns nil unless the bundle is InDesign (not InDesign Server or another app) with a Contents/MacOS folder.
    static func app(at url: URL) -> InDesignApp? {
        guard url.pathExtension == "app", let bundle = Bundle(url: url), bundle.bundleIdentifier == bundleID else { return nil }
        var isDirectory: ObjCBool = false
        let folder = url.appendingPathComponent("Contents/MacOS").path
        guard FileManager.default.fileExists(atPath: folder, isDirectory: &isDirectory), isDirectory.boolValue else { return nil }
        // The bundle folder name carries the release year ("Adobe InDesign 2026"); CFBundleName does not.
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        return InDesignApp(url: url, name: url.deletingPathExtension().lastPathComponent, version: version)
    }

    /// Does not follow symlinks: anything other than a regular file at the marker path is reported, never touched.
    static func state(of app: InDesignApp) -> MarkerState {
        var info = stat()
        guard lstat(app.markerFile.path, &info) == 0 else { return errno == ENOENT ? .on : .invalid }
        return (info.st_mode & S_IFMT) == S_IFREG ? .off : .invalid
    }

    /// Apps whose state actually needs changing; re-evaluated immediately before running.
    static func targets(_ apps: [InDesignApp], turnOff: Bool) -> [InDesignApp] {
        apps.filter { state(of: $0) == (turnOff ? .on : .off) }
    }

    static func shellQuote(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Only absolute paths ending in Contents/MacOS/DisableAsyncExports.txt are accepted.
    static func isMarkerPath(_ path: String) -> Bool {
        path.hasPrefix("/") && path.hasSuffix(".app/Contents/MacOS/" + fileName) && !path.contains("/../")
    }

    /// Shell command for the privileged path. `-n` checks keep a concurrent change from being clobbered.
    static func command(for apps: [InDesignApp], turnOff: Bool) -> String? {
        let paths = apps.map { $0.markerFile.path }
        guard !paths.isEmpty, paths.allSatisfy(isMarkerPath) else { return nil }
        return paths.map { path in
            let q = shellQuote(path)
            return turnOff ? "{ [ -e \(q) ] || /usr/bin/touch \(q); }" : "{ [ ! -f \(q) ] || [ -L \(q) ] || /bin/rm -f \(q); }"
        }.joined(separator: " && ")
    }

    static func appleScriptString(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    static func appleScript(command: String, prompt: String) -> String {
        "do shell script \(appleScriptString(command)) with prompt \(appleScriptString(prompt)) with administrator privileges"
    }

    /// Writes without a password when the folder is writable (e.g. a user-owned copy). Returns false to fall back to admin.
    static func changeWithoutPrivileges(_ app: InDesignApp, turnOff: Bool) -> Bool {
        let fm = FileManager.default
        guard fm.isWritableFile(atPath: app.macOSFolder.path) else { return false }
        if turnOff {
            return fm.createFile(atPath: app.markerFile.path, contents: Data())
        }
        do { try fm.removeItem(at: app.markerFile); return true } catch { return false }
    }
}
