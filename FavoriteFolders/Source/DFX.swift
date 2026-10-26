import AppKit

/// Default Folder X: where its favorites are and how to quit and relaunch it around a write.
/// It keeps the favorites in memory and writes Favorites.plist when it quits (measured on 6.3.3), so a file written
/// while it runs would be overwritten. Saving therefore quits it, writes, and opens it again.
enum DFX {
    /// Setapp first: both can be installed, and the data folder is the same.
    static let bundleIDs = ["com.stclairsoft.DefaultFolderX5-setapp", "com.stclairsoft.DefaultFolderX5"]
    static let supportFolder = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/com.stclairsoft.DefaultFolderX5", isDirectory: true)

    static var running: NSRunningApplication? {
        for id in bundleIDs { if let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first(where: { !$0.isTerminated }) { return app } }
        return nil
    }
    static var appURL: URL? { running?.bundleURL ?? bundleIDs.lazy.compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }.first }
    /// The preferences domain of the copy in use.
    static var domain: String { running?.bundleIdentifier ?? appURL.flatMap { Bundle(url: $0)?.bundleIdentifier } ?? bundleIDs[1] }
    static func preference(_ key: String) -> Any? { CFPreferencesCopyAppValue(key as CFString, domain as CFString) }

    /// Folder sets in Default Folder X's order, and the one in use. Falls back to the folders that hold a Favorites.plist.
    static func folderSets() -> (sets: [String], current: String?) {
        let info = preference("folderSetInfo") as? [String: Any]
        let sets = (info?["folderSets"] as? [String]) ?? (preference("folderSets") as? [[String: Any]])?.compactMap { $0["name"] as? String } ?? []
        let current = (info?["currentSet"] as? String) ?? (preference("currentSet") as? String)
        if !sets.isEmpty { return (sets, current) }
        let found = ((try? FileManager.default.contentsOfDirectory(atPath: supportFolder.path)) ?? []).filter {
            FileManager.default.fileExists(atPath: supportFolder.appendingPathComponent($0).appendingPathComponent("Favorites.plist").path)
        }.sorted()
        return (found, current ?? found.first)
    }
    static func favoritesURL(set: String) -> URL { supportFolder.appendingPathComponent(set, isDirectory: true).appendingPathComponent("Favorites.plist") }
    /// Default Folder X's own 「常にソート」: when on, it re-sorts the menu and the order written here is not used.
    static var staysSorted: Bool { (preference("favoritesStaySorted") as? Bool) ?? false }

    /// Asks Default Folder X to quit and waits until it has (it writes its favorites on the way out). Returns false on timeout.
    static func quit(_ app: NSRunningApplication, timeout: TimeInterval = 15) async -> Bool {
        guard app.terminate() || app.isTerminated else { return false }
        let deadline = Date().addingTimeInterval(timeout)
        while !app.isTerminated && Date() < deadline { try? await Task.sleep(nanoseconds: 100_000_000) }
        // Give the file system a moment after the process is gone.
        try? await Task.sleep(nanoseconds: 300_000_000)
        return app.isTerminated
    }
    static func launch(_ url: URL) async -> Bool {
        let configuration = NSWorkspace.OpenConfiguration(); configuration.activates = false
        return await withCheckedContinuation { continuation in
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { app, _ in continuation.resume(returning: app != nil) }
        }
    }
}

/// Copies of Favorites.plist taken right before each save. The newest 30 are kept.
enum Backups {
    static let folder = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/FavoriteFolders/Backups", isDirectory: true)
    static let limit = 30
    /// Backups made before the rename (1.2.0 and earlier, as FavoritesTidy).
    static let legacyFolder = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/FavoritesTidy/Backups", isDirectory: true)
    /// Moves the old backups into the current folder once; files with the same name are left where they are.
    static func migrate() {
        let fm = FileManager.default
        guard let old = try? fm.contentsOfDirectory(at: legacyFolder, includingPropertiesForKeys: nil), !old.isEmpty else { return }
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        for url in old where !fm.fileExists(atPath: folder.appendingPathComponent(url.lastPathComponent).path) {
            try? fm.moveItem(at: url, to: folder.appendingPathComponent(url.lastPathComponent))
        }
        // removeItem deletes folders recursively, so each folder is removed only after checking it is empty.
        for dir in [legacyFolder, legacyFolder.deletingLastPathComponent()] {
            guard (try? fm.contentsOfDirectory(atPath: dir.path).filter { $0 != ".DS_Store" })?.isEmpty == true else { break }
            try? fm.removeItem(at: dir)
        }
    }
    static func save(_ file: URL, set: String) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyyMMdd-HHmmss"; return f.string(from: Date()) }()
        let safeSet = set.replacingOccurrences(of: "/", with: "-")
        try FileManager.default.copyItem(at: file, to: folder.appendingPathComponent("Favorites-\(safeSet)-\(stamp).plist"))
        for url in pruned(((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])) {
            try? FileManager.default.removeItem(at: url)
        }
    }
    /// The backups beyond the newest `limit`, ordered by the yyyyMMdd-HHmmss.plist suffix (set names differ in length).
    static func pruned(_ urls: [URL]) -> [URL] {
        Array(urls.filter { $0.pathExtension == "plist" }
            .sorted { $0.lastPathComponent.suffix(21) > $1.lastPathComponent.suffix(21) }
            .dropFirst(limit))
    }
}
