import AppKit

// MARK: - 受け渡しフォルダー

/// 受け渡しフォルダーにある書き出しファイル1つ（アプリ1つ分）
struct FolderEntry: Identifiable {
    enum State {
        /// このMacの設定より新しい（またはこのMacにまだ設定がない）
        case newer
        /// このMacの設定の方が新しいか同じ
        case older
        /// このMacにアプリがない
        case notInstalled
    }
    let url: URL
    let app: Package.App
    let host: String
    let created: Date?
    let state: State
    var id: String { app.bundleID }
}

extension Courier {
    /// 受け渡しフォルダー（Dropbox など）。パスはMacごとに異なるので、設定の共有には含めない
    static let folderKey = "courierFolder"
    /// 登録したアプリを終了したときに、受け渡しフォルダーへ自動で書き出す
    static let autoExportKey = "autoExportOnQuit"
    /// このMacで取り込んだ・書き出した・同じと確かめたフォルダーのファイルの書き出し日時（Bundle ID → 日時）。Macごと
    static let handledKey = "handledFolderExports"

    /// この日時までのフォルダーのファイルは処理済み
    func handledDate(_ bundleID: String) -> Date? {
        (UserDefaults.standard.dictionary(forKey: Courier.handledKey) as? [String: Date])?[bundleID]
    }

    func markHandled(_ bundleID: String, _ date: Date) {
        var all = UserDefaults.standard.dictionary(forKey: Courier.handledKey) as? [String: Date] ?? [:]
        if let old = all[bundleID], old >= date { return }
        all[bundleID] = date
        UserDefaults.standard.set(all, forKey: Courier.handledKey)
    }

    var folder: URL? {
        guard let path = UserDefaults.standard.string(forKey: Courier.folderKey) else { return nil }
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isFolder), isFolder.boolValue else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// 保存してあるが見つからない（Dropbox が止まっている・外付けディスクを外したなど）
    var folderMissing: Bool {
        UserDefaults.standard.string(forKey: Courier.folderKey) != nil && folder == nil
    }

    /// フォルダーにある、そのアプリの書き出しファイル。名前ではなく中身の Bundle ID で探す（表示名は言語やMacで異なることがある）
    func folderFiles(_ bundleID: String, in folder: URL) -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "settingscourier" && Package(url: $0)?.apps.contains { $0.bundleID == bundleID } == true }
    }

    /// 書き出し先は「<アプリ名>.settingscourier」。別のアプリが同じ名前を使っているときだけ Bundle ID を添える
    func folderFile(_ app: CourierApp, in folder: URL) -> URL {
        let name = app.name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let url = folder.appendingPathComponent(name + ".settingscourier")
        if let other = Package(url: url), !other.apps.contains(where: { $0.bundleID == app.bundleID }) {
            return folder.appendingPathComponent("\(name) (\(app.bundleID)).settingscourier")
        }
        return url
    }

    /// フォルダーに書き出し、同じアプリの古い名前のファイル（ほかのMacで別の名前で書いたもの・以前の Bundle ID の名前）を消す
    func writeToFolder(_ package: Package, _ app: CourierApp, in folder: URL) throws -> URL {
        let url = folderFile(app, in: folder)
        try package.data().write(to: url, options: .atomic)
        for old in folderFiles(app.bundleID, in: folder) where old.standardizedFileURL != url.standardizedFileURL {
            // 複数のアプリをまとめたファイルは消さない
            if Package(url: old)?.apps.count == 1 { try? FileManager.default.removeItem(at: old) }
        }
        return url
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = L("選択")
        panel.message = L("設定を受け渡すフォルダーを選んでください（Dropbox・iCloud Drive などほかのMacと同期しているフォルダー）")
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        UserDefaults.standard.set(url.path, forKey: Courier.folderKey)
        scanFolder()
    }

    func clearFolder() {
        UserDefaults.standard.removeObject(forKey: Courier.folderKey)
        scanFolder()
    }

    func showFolder() {
        if let folder { NSWorkspace.shared.open(folder) }
    }

    /// フォルダーのファイルを読み、このMacの設定ファイルの更新日時と比べる。設定の値は読まない（読むと確認が出るアプリがある）
    func scanFolder() {
        guard let folder,
              let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else {
            folderEntries = []
            return
        }
        var entries: [FolderEntry] = []
        for url in files where url.pathExtension == "settingscourier" {
            guard let package = Package(url: url) else { continue }
            for app in package.apps {
                // cfprefsd はファイルへの書き出しを後回しにすることがあるので、設定ファイルの日時だけでなく処理済みの記録とも比べる
                let local = (try? FileManager.default.attributesOfItem(atPath: preferencesFile(app.bundleID).path))?[.modificationDate] as? Date
                let seen = [local, handledDate(app.bundleID)].compactMap { $0 }.max()
                let state: FolderEntry.State
                if appURL(app.bundleID) == nil {
                    state = .notInstalled
                } else if package.host == Host.current().localizedName ?? "" {
                    // このMacが書き出したファイル
                    state = .older
                } else if let seen, let created = package.created, created <= seen {
                    state = .older
                } else {
                    state = .newer
                }
                entries.append(FolderEntry(url: url, app: app, host: package.host, created: package.created, state: state))
            }
        }
        folderEntries = entries.sorted { $0.app.name.localizedStandardCompare($1.app.name) == .orderedAscending }
    }

    var newerEntries: [FolderEntry] { folderEntries.filter { $0.state == .newer } }

    func hasNewer(_ bundleID: String) -> Bool {
        folderEntries.contains { $0.app.bundleID == bundleID && $0.state == .newer }
    }

    /// 選んだファイルをまとめて、取り込みの確認に渡す
    func importFromFolder(_ entries: [FolderEntry]) {
        guard !entries.isEmpty else { return }
        // 書き出したMacはファイルごとに異なるので、確認画面には出さない
        let package = Package(apps: entries.map(\.app), replace: false, host: "")
        // 取り込んだら（または同じと分かったら）処理済みにする日時
        folderImportDates = Dictionary(entries.compactMap { e in e.created.map { (e.app.bundleID, $0) } }, uniquingKeysWith: max)
        pendingImport = PackageBox(package: package, name: L("受け渡しフォルダー"))
    }

    // MARK: 自動書き出し

    func watchTerminations() {
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification,
                                                          object: nil, queue: .main) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard let id = app?.bundleIdentifier else { return }
            // 終了したアプリの設定が書き終わるのを少し待つ
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                MainActor.assumeIsolated { Courier.shared.autoExport(id) }
            }
        }
    }

    /// 登録したアプリが終了したら、受け渡しフォルダーへ書き出す。値が変わっていなければ書かない
    /// サンドボックスのアプリは、読むと確認が出るので、このセッションで読むのを許したかフルディスクアクセスがあるときだけ
    func autoExport(_ bundleID: String) {
        guard UserDefaults.standard.bool(forKey: Courier.autoExportKey), let folder,
              let app = apps.first(where: { $0.bundleID == bundleID }) else { return }
        if let until = suppressAutoExport[bundleID], until > Date() { return }
        suppressAutoExport[bundleID] = nil
        let time = Date().formatted(date: .omitted, time: .shortened)
        guard canRead(bundleID) else {
            lastAutoExport = L("%@：%@ 設定を読む許可がないため書き出しませんでした（フルディスクアクセスを許可するか、メインウインドウで「設定を読む」を押してください）", time, app.name)
            return
        }
        let values = readSettings(bundleID)
        guard !isUnreadable(bundleID, values) else {
            lastAutoExport = L("%@：%@ 設定を読めなかったため書き出しませんでした", time, app.name)
            return
        }
        let exported = values.filter { isIncluded(bundleID, $0.key, $0.value) }
        if let file = folderFiles(bundleID, in: folder).first,
           let old = Package(url: file)?.apps.first(where: { $0.bundleID == bundleID }),
           (old.values as NSDictionary).isEqual(to: exported) {
            return
        }
        do {
            _ = try writeToFolder(Package(apps: [.init(bundleID: bundleID, name: app.name, values: exported)], replace: false), app, in: folder)
            lastAutoExport = L("%@：%@ を書き出しました", time, app.name)
            markHandled(bundleID, Date())
        } catch {
            lastAutoExport = L("%@：%@ を書き出せませんでした（%@）", time, app.name, error.localizedDescription)
        }
        scanFolder()
    }
}
