import AppKit
import SwiftUI

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
        let everything: Bool
        switch response {
        case .alertFirstButtonReturn: everything = false
        case .alertSecondButtonReturn: everything = true
        default: return
        }
        TaskProgress.shared.begin(L("システムのフォントキャッシュを消去中…"),
                                  detail: everything ? L("管理者のパスワードを入力してください") : L("atsutilを実行しています…"))
        Task {
            // atsutil は数秒かかることがあるので、画面を止めないよう裏で動かす
            let result = await Task.detached(priority: .userInitiated) { everything ? runSystemReset() : runUserReset() }.value
            TaskProgress.shared.end()
            switch result {
            case .success: finishSystemClean()
            case .cancelled: break
            case .failure(let detail): fail(detail)
            }
        }
    }

    enum ResetResult: Sendable { case success, cancelled, failure(String) }

    private static func finishSystemClean() {
        let done = NSAlert()
        done.messageText = L("フォントキャッシュを消去しました")
        done.informativeText = L("Macを再起動すると、フォントキャッシュが作り直されます。開いている書類を保存してから再起動してください。")
        done.addButton(withTitle: L("あとで再起動"))
        done.addButton(withTitle: L("今すぐ再起動…"))
        if done.runModal() == .alertSecondButtonReturn { requestRestart() }
    }

    nonisolated private static func runUserReset() -> ResetResult {
        run("/usr/bin/atsutil", ["databases", "-removeUser"])
    }

    /// システム全体：管理者の権限で atsutil databases -remove（このユーザーの分も消える）。
    /// 裏で動かすため NSAppleScript ではなく osascript で頼む（認証の画面は osascript が出す）
    nonisolated private static func runSystemReset() -> ResetResult {
        let result = run("/usr/bin/osascript", ["-e", "do shell script \"/usr/bin/atsutil databases -remove\" with administrator privileges"])
        // 認証を取り消したとき（-128）は何も言わない
        if case .failure(let detail) = result, detail.contains("-128") { return .cancelled }
        return result
    }

    nonisolated private static func run(_ path: String, _ arguments: [String]) -> ResetResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .failure(error.localizedDescription)
        }
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return process.terminationStatus == 0 ? .success : .failure(output)
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

    /// 起動中の Adobe アプリ（画面のあるものだけ。AIRobin などの補助は本体と一緒に終わる）
    static func runningAdobeApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { app in
            app.activationPolicy == .regular && adobeApps.contains { app.bundleIdentifier?.hasPrefix($0) == true }
        }
    }

    static func cleanApplicationCaches() {
        // 起動中なら、アプリごとの「終了」ボタンを並べたダイアログボックスを出す。すべて終わると「フォントキャッシュを消去」が押せる
        if !runningAdobeApps().isEmpty {
            QuitAdobeAppsWindow.shared.show()
            return
        }
        findApplicationCaches(confirm: true)
    }

    /// 設定フォルダーを奥まで調べるので数秒かかる。画面を止めないよう裏で探す
    static func findApplicationCaches(confirm: Bool) {
        TaskProgress.shared.begin(L("Adobeアプリのフォントキャッシュを探しています…"))
        Task {
            let files = await Task.detached(priority: .userInitiated) { adobeCacheFiles() }.value
            TaskProgress.shared.end()
            confirmApplicationClean(files, confirm: confirm)
        }
    }

    private static func confirmApplicationClean(_ files: [URL], confirm: Bool) {
        guard !files.isEmpty else {
            let alert = NSAlert()
            alert.messageText = L("Adobeアプリのフォントキャッシュは見つかりませんでした")
            alert.runModal()
            return
        }
        if confirm {
            let alert = NSAlert()
            alert.messageText = L("Adobeアプリのフォントキャッシュを消去しますか？")
            alert.informativeText = L("%d個のファイルをゴミ箱に入れます。InDesign・Illustratorなどのフォントメニューが古いまま・重複するときに使います。次にアプリを起動すると作り直されます（初回の起動は少し時間がかかります）。", files.count)
            alert.addButton(withTitle: L("ゴミ箱に入れる"))
            alert.addButton(withTitle: L("キャンセル")).keyEquivalent = "\u{1b}"
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        TaskProgress.shared.begin(L("Adobeアプリのフォントキャッシュを消去中…"))
        Task {
            var moved = 0
            var failures = 0
            for (index, file) in files.enumerated() {
                TaskProgress.shared.update(index, of: files.count, detail: file.lastPathComponent)
                let ok = await Task.detached(priority: .userInitiated) {
                    (try? FileManager.default.trashItem(at: file, resultingItemURL: nil)) != nil
                }.value
                if ok { moved += 1 } else { failures += 1 }
            }
            TaskProgress.shared.end()
            LibraryStore.shared.status = L("Adobeアプリのフォントキャッシュを%d個ゴミ箱に入れました", moved)
                + (failures == 0 ? "" : L("、失敗 %d", failures))
        }
    }

    /// このユーザーの Adobe のフォントの控え。Photoshop の「CT Font Cache」はフォルダーの中身（Backups の控えは除く）
    nonisolated static func adobeCacheFiles() -> [URL] {
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

// MARK: - 起動中の Adobe アプリを終了するダイアログボックス

/// 起動中の Adobe アプリを見張る。終了したアプリも一覧に残し、ボタンをディムにする
@MainActor
final class RunningAdobeApps: ObservableObject {
    struct Entry: Identifiable {
        let id: String
        let name: String
        var app: NSRunningApplication?
        var isRunning: Bool { app.map { !$0.isTerminated } ?? false }
    }

    @Published private(set) var entries: [Entry] = []
    private var observers: [NSObjectProtocol] = []

    init() {
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            })
        }
    }

    isolated deinit {
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    var anyRunning: Bool { entries.contains { $0.isRunning } }

    func refresh() {
        let running = FontCacheCleaner.runningAdobeApps()
        var list = entries.map { entry -> Entry in
            var copy = entry
            copy.app = running.first { $0.bundleIdentifier == entry.id }
            return copy
        }
        for app in running where !list.contains(where: { $0.id == app.bundleIdentifier }) {
            list.append(Entry(id: app.bundleIdentifier ?? UUID().uuidString, name: app.localizedName ?? app.bundleIdentifier ?? "", app: app))
        }
        entries = list
    }

    /// 終了を頼む（保存していない書類があれば、アプリが確認を出す）
    func quit(_ entry: Entry) { entry.app?.terminate() }

    func quitAll() { for entry in entries where entry.isRunning { quit(entry) } }
}

@MainActor
final class QuitAdobeAppsWindow {
    static let shared = QuitAdobeAppsWindow()
    private var window: NSWindow?

    func show() {
        window?.close()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 200),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = L("フォントキャッシュを消去")
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: QuitAdobeAppsView())
        hosting.sizingOptions = [.preferredContentSize]
        window.contentView = hosting
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() { window?.close() }
}

private struct QuitAdobeAppsView: View {
    @StateObject private var apps = RunningAdobeApps()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Adobeアプリを終了してください")).font(.headline)
            Text(L("アプリが使っている間は、フォントキャッシュを消しても作り直されません。すべて終了すると「フォントキャッシュを消去」を押せます。保存していないドキュメントがあれば、それぞれのアプリが確認します。"))
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(apps.entries) { entry in
                    HStack(spacing: 8) {
                        if let icon = entry.app?.icon {
                            Image(nsImage: icon).resizable().frame(width: 18, height: 18).opacity(entry.isRunning ? 1 : 0.4)
                        }
                        Button(L("%@を終了", entry.name)) { apps.quit(entry) }
                            .disabled(!entry.isRunning)
                        if !entry.isRunning {
                            Text(L("終了しました")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Button(L("すべてのAdobeアプリを終了")) { apps.quitAll() }
                    .disabled(!apps.anyRunning)
                    .padding(.top, 4)
            }
            HStack {
                Spacer()
                Button(L("キャンセル")) { QuitAdobeAppsWindow.shared.close() }
                    .keyboardShortcut(.cancelAction)
                Button(L("フォントキャッシュを消去")) {
                    QuitAdobeAppsWindow.shared.close()
                    FontCacheCleaner.findApplicationCaches(confirm: false)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(apps.anyRunning)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
