import AppKit

// MARK: - 一緒に運ぶファイル

/// 設定（defaults）の外にあるアプリのデータ（Default Folder X のお気に入りの Favorites.plist など）を、設定と一緒に運ぶ
/// パスはホームからの「~/…」で持つ（ユーザー名が異なるMacでも同じ場所を指す）。ホームの外のファイルは扱わない
private let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path

/// 「~/…」をフルパスにする。ホームの外を指すものは nil
func expandHomePath(_ path: String) -> URL? {
    guard path.hasPrefix("~/") else { return nil }
    let url = URL(fileURLWithPath: home + "/" + String(path.dropFirst(2))).standardizedFileURL
    return url.path.hasPrefix(home + "/") ? url : nil
}

/// フルパスを「~/…」にする。ホームの外なら nil
func abbreviateHomePath(_ url: URL) -> String? {
    let path = url.standardizedFileURL.path
    return path.hasPrefix(home + "/") ? "~/" + path.dropFirst(home.count + 1) : nil
}

/// ほかのアプリのコンテナの中。読むと「ほかのアプリからのデータ」の確認が出る
func isContainerPath(_ path: String) -> Bool {
    path.hasPrefix("~/Library/Containers/") || path.hasPrefix("~/Library/Group Containers/")
}

/// 1つのファイルの上限。書き出しファイルに中身をそのまま入れるので、大きすぎるものは運ばない
let extraFileLimit = 20 * 1024 * 1024

extension Courier {
    /// アプリごとの一緒に運ぶファイル（Bundle ID → 「~/…」の配列）。設定の共有で同期する
    static let extraFilesKey = "extraFiles"

    func extraFiles(_ bundleID: String) -> [String] {
        (UserDefaults.standard.dictionary(forKey: Courier.extraFilesKey) as? [String: [String]])?[bundleID] ?? []
    }

    func setExtraFilesPublic(_ bundleID: String, _ paths: [String]) { setExtraFiles(bundleID, paths) }

    private func setExtraFiles(_ bundleID: String, _ paths: [String]) {
        var all = UserDefaults.standard.dictionary(forKey: Courier.extraFilesKey) as? [String: [String]] ?? [:]
        all[bundleID] = paths.isEmpty ? nil : paths
        UserDefaults.standard.set(all, forKey: Courier.extraFilesKey)
        refresh()
    }

    func chooseExtraFiles(_ app: CourierApp) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.showsHiddenFiles = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        panel.prompt = L("追加")
        panel.message = L("%@の設定と一緒に運ぶファイルを選んでください（ホームフォルダーの中のファイル）", app.name)
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }
        var paths = extraFiles(app.bundleID)
        var outside: [String] = []
        for url in panel.urls {
            guard let path = abbreviateHomePath(url) else { outside.append(url.lastPathComponent); continue }
            if !paths.contains(path) { paths.append(path) }
        }
        setExtraFiles(app.bundleID, paths)
        if !outside.isEmpty {
            message = (L("追加できないファイルがあります"), L("ホームフォルダーの外のファイルは運べません：%@", outside.joined(separator: L("、"))))
        }
    }

    func removeExtraFile(_ bundleID: String, _ path: String) {
        setExtraFiles(bundleID, extraFiles(bundleID).filter { $0 != path })
    }

    /// 一緒に運ぶファイルの中身。無いファイル・大きすぎるファイルは入れない
    /// includeContainers が偽なら、コンテナの中のファイルは読まない（自動書き出しで確認を出さない）
    func readExtraFiles(_ bundleID: String, includeContainers: Bool = true) -> [String: Data] {
        var result: [String: Data] = [:]
        for path in extraFiles(bundleID) {
            if !includeContainers, isContainerPath(path) { continue }
            guard let url = expandHomePath(path),
                  let size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int,
                  size <= extraFileLimit, let data = try? Data(contentsOf: url) else { continue }
            result[path] = data
        }
        return result
    }

    /// 取り込むファイルを書く（nil は削除）。書けなかったパスを返す
    func writeExtraFiles(_ writes: [String: Data?]) -> [String] {
        var failed: [String] = []
        for (path, data) in writes {
            guard let url = expandHomePath(path) else { failed.append(path); continue }
            do {
                if let data {
                    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try data.write(to: url, options: .atomic)
                    if (try? Data(contentsOf: url)) != data { failed.append(path) }
                } else if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
            } catch {
                failed.append(path)
            }
        }
        return failed
    }
}

// MARK: - アプリごとの候補

extension Courier {
    /// 設定の外にデータを置くことが分かっているアプリの、運ぶとよいファイル
    /// Default Folder X：お気に入りは使用中のフォルダーセットの Favorites.plist（Setapp 版も「-setapp」の付かないフォルダーを使う。2026-10-24 確認）
    func suggestedExtraFiles(_ bundleID: String) -> [String] {
        guard bundleID.hasPrefix("com.stclairsoft.DefaultFolderX") else { return [] }
        guard let set = (readSettings(bundleID)["folderSetInfo"] as? NSDictionary)?["currentSet"] as? String else { return [] }
        let support = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let candidates = [bundleID, "com.stclairsoft.DefaultFolderX5"].map {
            support.appendingPathComponent($0).appendingPathComponent(set).appendingPathComponent("Favorites.plist")
        }
        let newest = candidates.filter { FileManager.default.fileExists(atPath: $0.path) }
            .max { modified($0) < modified($1) }
        return newest.flatMap(abbreviateHomePath).map { [$0] } ?? []
    }

    private func modified(_ url: URL) -> Date {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date ?? .distantPast
    }

    /// 候補のうち、まだ一覧に無いもの
    func missingSuggestions(_ bundleID: String) -> [String] {
        let current = extraFiles(bundleID)
        return suggestedExtraFiles(bundleID).filter { !current.contains($0) }
    }

    func addExtraFiles(_ bundleID: String, _ paths: [String]) {
        let current = extraFiles(bundleID)
        setExtraFilesPublic(bundleID, current + paths.filter { !current.contains($0) })
    }
}
