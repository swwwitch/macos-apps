import AppKit

/// フォントキャッシュの消去（FontExplorer X Pro の Clean System / Application Font Caches に当たる）。システムとアプリで別の項目にする（ユーザー指定）。
/// システム：atsutil databases（-removeUser はこのユーザーの分で権限なし、-remove はシステム全体で管理者の権限）。消したあと再起動が要る。
/// アプリ：Adobe アプリのフォントの控え（AdobeFnt*.lst など）をゴミ箱に入れる。アプリを起動すると作り直される。場所は 2026-10-24 にこの Mac で確かめた
@MainActor
enum FontCacheCleaner {
    // MARK: システム

    static func cleanSystemCaches() {
        let alert = NSAlert()
        alert.messageText = L("システムのフォントキャッシュを消去しますか？")
        alert.informativeText = L("macOSのフォントの控えを消します。文字化けやフォントの重複が直らないときに使います。消したあとMacを再起動（またはログアウト）すると作り直されます。「システム全体も消去」は管理者のパスワードが要ります。")
        alert.addButton(withTitle: L("このユーザーの分を消去"))
        alert.addButton(withTitle: L("システム全体も消去…"))
        alert.addButton(withTitle: L("キャンセル")).keyEquivalent = "\u{1b}"
        let response = alert.runModal()
        let succeeded: Bool
        switch response {
        case .alertFirstButtonReturn: succeeded = runUserReset()
        case .alertSecondButtonReturn: succeeded = runSystemReset()
        default: return
        }
        guard succeeded else { return }
        let done = NSAlert()
        done.messageText = L("フォントキャッシュを消去しました")
        done.informativeText = L("Macを再起動すると、フォントキャッシュが作り直されます。開いている書類を保存してから再起動してください。")
        done.addButton(withTitle: L("あとで再起動"))
        done.addButton(withTitle: L("今すぐ再起動…"))
        if done.runModal() == .alertSecondButtonReturn { requestRestart() }
    }

    private static func runUserReset() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/atsutil")
        process.arguments = ["databases", "-removeUser"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            fail(error.localizedDescription)
            return false
        }
        guard process.terminationStatus == 0 else {
            fail(String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))
            return false
        }
        return true
    }

    /// システム全体：管理者の権限で atsutil databases -remove（このユーザーの分も消える）
    private static func runSystemReset() -> Bool {
        var error: NSDictionary?
        NSAppleScript(source: "do shell script \"/usr/bin/atsutil databases -remove\" with administrator privileges")?.executeAndReturnError(&error)
        if let error {
            // 認証を取り消したとき（-128）は何も言わない
            if (error[NSAppleScript.errorNumber] as? Int) != -128 { fail(error[NSAppleScript.errorMessage] as? String ?? "") }
            return false
        }
        return true
    }

    /// 標準の再起動の確認を出す（loginwindow に再起動を頼む。開いている書類の保存は各アプリが聞く）
    private static func requestRestart() {
        var error: NSDictionary?
        NSAppleScript(source: "tell application \"loginwindow\" to «event aevtrrst»")?.executeAndReturnError(&error)
    }

    // MARK: アプリ（Adobe）

    /// フォントの控えを作る Adobe アプリ。起動中は消さない（使用中の控えを消すと作り直されず、終了時に書き戻される）
    static let adobeApps = ["com.adobe.InDesign", "com.adobe.illustrator", "com.adobe.Photoshop", "com.adobe.InCopy",
                            "com.adobe.AfterEffects", "com.adobe.PremierePro", "com.adobe.Acrobat.Pro"]

    static func cleanApplicationCaches() {
        let running = NSWorkspace.shared.runningApplications.filter { app in
            adobeApps.contains { app.bundleIdentifier?.hasPrefix($0) == true }
        }
        if !running.isEmpty {
            let alert = NSAlert()
            alert.messageText = L("Adobeアプリを終了してください")
            alert.informativeText = L("起動中のアプリ：%@\nアプリが使っている間は、フォントキャッシュを消しても作り直されません。終了してから、もう一度実行してください。",
                                      running.compactMap(\.localizedName).joined(separator: L("、")))
            alert.runModal()
            return
        }
        let files = adobeCacheFiles()
        guard !files.isEmpty else {
            let alert = NSAlert()
            alert.messageText = L("Adobeアプリのフォントキャッシュは見つかりませんでした")
            alert.runModal()
            return
        }
        let alert = NSAlert()
        alert.messageText = L("Adobeアプリのフォントキャッシュを消去しますか？")
        alert.informativeText = L("%d個のファイルをゴミ箱に入れます。InDesign・Illustratorなどのフォントメニューが古いまま・重複するときに使います。次にアプリを起動すると作り直されます（初回の起動は少し時間がかかります）。", files.count)
        alert.addButton(withTitle: L("ゴミ箱に入れる"))
        alert.addButton(withTitle: L("キャンセル")).keyEquivalent = "\u{1b}"
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        var moved = 0
        var failures: [String] = []
        for file in files {
            do {
                try FileManager.default.trashItem(at: file, resultingItemURL: nil)
                moved += 1
            } catch {
                failures.append(file.lastPathComponent)
            }
        }
        LibraryStore.shared.status = L("Adobeアプリのフォントキャッシュを%d個ゴミ箱に入れました", moved)
            + (failures.isEmpty ? "" : L("、失敗 %d", failures.count))
    }

    /// このユーザーの Adobe のフォントの控え。Photoshop の「CT Font Cache」はフォルダーの中身（Backups の控えは除く）
    static func adobeCacheFiles() -> [URL] {
        let library = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library")
        let roots = ["Preferences", "Caches/Adobe", "Caches/Adobe InDesign", "Application Support/Adobe"].map { library.appendingPathComponent($0) }
        var found: [URL] = []
        for root in roots {
            // 読めないフォルダー（ほかのアプリの保護された設定など）で止まらないよう、エラーは飛ばして続ける
            guard let items = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                                                             options: [.skipsPackageDescendants], errorHandler: { _, _ in true }) else { continue }
            while let item = items.nextObject() as? URL {
                // 設定フォルダーの中は Adobe のものだけを見る（ほかのアプリの設定には入らない）
                // skipDescendants は「直前に返したフォルダー」の中を飛ばすので、フォルダーのときだけ呼ぶ
                // （ファイルで呼ぶと、その前に返した Illustrator の設定フォルダーまで飛ばされていた）
                let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                if root.lastPathComponent == "Preferences", items.level == 1,
                   !(item.lastPathComponent.hasPrefix("Adobe") || item.lastPathComponent.hasPrefix("AIRobin")) {
                    if isDirectory { items.skipDescendants() }
                    continue
                }
                if items.level > 6 { if isDirectory { items.skipDescendants() }; continue }
                let name = item.lastPathComponent
                let path = item.path
                // 控えのバックアップと、合成フォントに関わるもの（AdobeFntComposite.lst など）は消さない
                if path.contains("/Backups/") || name.contains("Composite") { continue }
                let isCache = (name.hasPrefix("AdobeFnt") && name.hasSuffix(".lst")) || name == "AdobeFontList.lst"
                    || (path.contains("/CT Font Cache/") && (try? item.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true)
                if isCache { found.append(item) }
            }
        }
        return found
    }

    private static func fail(_ detail: String) {
        let alert = NSAlert()
        alert.messageText = L("フォントキャッシュを消去できませんでした")
        alert.informativeText = detail
        alert.runModal()
    }
}
