#if APP_STORE
import AppKit

// Only folders explicitly selected in an Open panel become persistent grants.
// All calls run on the main thread. Scopes stay active for this process lifetime.
final class FolderAccess {
    static let shared = FolderAccess()
    private let defaults: UserDefaults
    private let key = "securityScopedFolders.v1"
    private var active: [URL] = []
    private var bookmarks: [String: Data] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        bookmarks = defaults.dictionary(forKey: key) as? [String: Data] ?? [:]
        for (path, data) in bookmarks {
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: data,
                                    options: [.withSecurityScope, .withoutUI, .withoutMounting],
                                    relativeTo: nil, bookmarkDataIsStale: &stale),
                  url.startAccessingSecurityScopedResource() else { continue }
            active.append(url)
            if stale, let refreshed = try? url.bookmarkData(options: .withSecurityScope,
                    includingResourceValuesForKeys: nil, relativeTo: nil) {
                bookmarks[path] = refreshed
            }
        }
        defaults.set(bookmarks, forKey: key)
    }
    deinit { active.forEach { $0.stopAccessingSecurityScopedResource() } }

    func covers(_ url: URL) -> Bool {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        return active.contains {
            let root = $0.resolvingSymlinksInPath().standardizedFileURL.path
            return path == root || path.hasPrefix(root == "/" ? "/" : root + "/")
        }
    }
    func remember(_ url: URL) throws {
        let started = url.startAccessingSecurityScopedResource()
        do {
            let data = try url.bookmarkData(options: .withSecurityScope,
                                            includingResourceValuesForKeys: nil, relativeTo: nil)
            // Resolve immediately so the retained URL has a durable sandbox extension.
            var stale = false
            let scoped = try URL(resolvingBookmarkData: data, options: .withSecurityScope,
                                 relativeTo: nil, bookmarkDataIsStale: &stale)
            guard scoped.startAccessingSecurityScopedResource() else {
                throw MoveFailure(message: L("フォルダのアクセス許可を保持できませんでした。"))
            }
            active.append(scoped)
            bookmarks[url.standardizedFileURL.path] = data
            defaults.set(bookmarks, forKey: key)
            if started { url.stopAccessingSecurityScopedResource() }
        } catch {
            if started { url.stopAccessingSecurityScopedResource() }
            throw error
        }
    }
    func authorize(_ folders: [URL]) throws -> Bool {
        var seen = Set<String>()
        for folder in folders where seen.insert(folder.standardizedFileURL.path).inserted {
            if covers(folder) { continue }
            let panel = NSOpenPanel()
            panel.title = L("フォルダへのアクセスを許可")
            panel.message = L("ファイル操作と取り消しのため、次のフォルダを選択してください。\n") + folder.path
            panel.prompt = L("許可")
            panel.canChooseFiles = false; panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false; panel.canCreateDirectories = false
            panel.directoryURL = folder
            guard panel.runModal() == .OK, let selected = panel.url else { return false }
            // Do not silently act on a different folder if the panel selection changed.
            guard selected.resolvingSymlinksInPath().standardizedFileURL == folder.resolvingSymlinksInPath().standardizedFileURL else {
                throw MoveFailure(message: L("指定されたフォルダが異なるため、操作を中止しました。"))
            }
            try remember(selected)
        }
        return true
    }
}
#endif
