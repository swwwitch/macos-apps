import AppKit
import SwiftUI

/// 一覧の1行
struct LogRow: Identifiable {
    enum State { case saved, failed, skipped }
    let id: Int
    let state: State
    let url: String
    /// 保存先（取り込みフォルダーからの相対パス）か、失敗・除外の理由
    let detail: String
}

@MainActor
final class Mirror: ObservableObject {
    static let shared = Mirror()

    // 「設定の共有」で同期するキーは syncedKeys に限定する。URL・履歴・保存先はMac固有。
    static let lastURLKey = "lastURL"
    static let outputFolderKey = "outputFolderPath"
    static let externalAssetsKey = "includeExternalAssets"
    static let subdomainsKey = "includeSubdomains"
    static let startFolderOnlyKey = "startFolderOnly"
    static let obeyRobotsKey = "obeyRobots"
    static let maxDepthKey = "maxDepth"
    static let maxFilesKey = "maxFiles"
    static let connectionsKey = "connections"
    static let retriesKey = "retries"
    static let intervalKey = "requestInterval"
    static let excludesKey = "excludePatterns"
    static let skipUnchangedKey = "skipUnchanged"
    static let includesKey = "includePatterns"
    static let useSitemapKey = "useSitemap"
    static let scanScriptsKey = "scanScripts"
    static let excludedTypesKey = "excludedTypes"
    static let maxFileMBKey = "maxFileMB"
    static let maxTotalMBKey = "maxTotalMB"
    static let purgeRemovedKey = "purgeRemoved"
    static let syncedKeys: Set<String> = [externalAssetsKey, subdomainsKey, startFolderOnlyKey, obeyRobotsKey, maxDepthKey, maxFilesKey,
                                          connectionsKey, retriesKey, intervalKey, excludesKey, skipUnchangedKey,
                                          includesKey, useSitemapKey, scanScriptsKey, excludedTypesKey, maxFileMBKey, maxTotalMBKey, purgeRemovedKey]

    @Published var urlText: String {
        didSet { UserDefaults.standard.set(urlText, forKey: Mirror.lastURLKey) }
    }
    private let history: URLHistory
    @Published private(set) var recentURLs: [String]
    @Published private(set) var outputFolder: URL
    @Published var checkOnlyMode = false
    @Published private(set) var isRunning = false
    @Published private(set) var isRewriting = false
    /// 保存せずリンク切れだけを調べている（前回の実行がリンクの確認だった）
    @Published private(set) var isCheckOnly = false
    @Published private(set) var rows: [LogRow] = []
    @Published private(set) var saved = 0
    @Published private(set) var failed = 0
    @Published private(set) var waiting = 0
    @Published private(set) var status = ""
    /// 前回の取り込み先と開始ページ
    @Published private(set) var resultFolder: URL?
    @Published private(set) var startPage: URL?
    @Published var message: (title: String, body: String)?

    private var task: Task<Void, Never>?
    /// 今回新しく作った取り込みフォルダーか（1件も保存できなかったときに消してよいのはこのときだけ）
    private var createdRoot = false
    /// 前回の取り込みの記録ファイル
    @Published private(set) var logFile: URL?
    @Published private(set) var diffReport: URL?
    /// 終了の確認で「中止して終了」を選んだとき、書き換えが終わってから呼ぶ
    var onFinished: (() -> Void)?

    private init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [Mirror.externalAssetsKey: true, Mirror.subdomainsKey: false, Mirror.startFolderOnlyKey: false,
                                     Mirror.obeyRobotsKey: true, Mirror.maxDepthKey: 0, Mirror.maxFilesKey: 10_000, Mirror.connectionsKey: 4,
                                     Mirror.retriesKey: 2, Mirror.intervalKey: 0.0, Mirror.excludesKey: "", Mirror.skipUnchangedKey: true,
                                     Mirror.includesKey: "", Mirror.useSitemapKey: false, Mirror.scanScriptsKey: false, Mirror.excludedTypesKey: "",
                                     Mirror.maxFileMBKey: 0, Mirror.maxTotalMBKey: 0, Mirror.purgeRemovedKey: false])
        let previousURL = defaults.string(forKey: Mirror.lastURLKey) ?? ""
        urlText = previousURL
        history = URLHistory(defaults: defaults, previousURL: Mirror.startURL(from: previousURL))
        recentURLs = history.entries
        if let path = defaults.string(forKey: Mirror.outputFolderKey), FileManager.default.fileExists(atPath: path) {
            outputFolder = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            outputFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser
        }
    }

    var options: MirrorOptions {
        let defaults = UserDefaults.standard
        return MirrorOptions(externalAssets: defaults.bool(forKey: Mirror.externalAssetsKey),
                             subdomains: defaults.bool(forKey: Mirror.subdomainsKey),
                             startFolderOnly: defaults.bool(forKey: Mirror.startFolderOnlyKey),
                             obeyRobots: defaults.bool(forKey: Mirror.obeyRobotsKey),
                             maxDepth: max(0, defaults.integer(forKey: Mirror.maxDepthKey)),
                             maxFiles: max(0, defaults.integer(forKey: Mirror.maxFilesKey)),
                             connections: min(8, max(1, defaults.integer(forKey: Mirror.connectionsKey))),
                             retries: min(5, max(0, defaults.integer(forKey: Mirror.retriesKey))),
                             interval: min(10, max(0, defaults.double(forKey: Mirror.intervalKey))),
                             excludes: (defaults.string(forKey: Mirror.excludesKey) ?? "").components(separatedBy: .newlines),
                             skipUnchanged: defaults.bool(forKey: Mirror.skipUnchangedKey),
                             includes: (defaults.string(forKey: Mirror.includesKey) ?? "").components(separatedBy: .newlines),
                             useSitemap: defaults.bool(forKey: Mirror.useSitemapKey),
                             scanScripts: defaults.bool(forKey: Mirror.scanScriptsKey),
                             excludedTypes: Mirror.types(defaults.string(forKey: Mirror.excludedTypesKey) ?? ""),
                             maxFileMB: max(0, defaults.integer(forKey: Mirror.maxFileMBKey)),
                             maxTotalMB: max(0, defaults.integer(forKey: Mirror.maxTotalMBKey)),
                             purgeRemoved: defaults.bool(forKey: Mirror.purgeRemovedKey))
    }

    /// 「mp4, .mov zip」のような書き方から拡張子の一覧にする
    static func types(_ text: String) -> [String] {
        text.lowercased().components(separatedBy: CharacterSet(charactersIn: ",、 \n\t"))
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ". *")) }
            .filter { !$0.isEmpty }
    }

    /// 「example.com」のようにスキームを省いたら https:// を補う
    static func startURL(from text: String) -> URL? {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if value.range(of: "^[a-zA-Z][a-zA-Z0-9+.-]*://", options: .regularExpression) == nil { value = "https://" + value }
        guard var components = URLComponents(string: value), let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https", let host = components.host, host.contains(".") || host == "localhost" else { return nil }
        components.fragment = nil
        if components.path.isEmpty { components.path = "/" }
        return components.url
    }

    func clearURLHistory() {
        guard !isRunning else { return }
        history.clear()
        recentURLs = history.entries
    }

    var canStart: Bool { !isRunning && Mirror.startURL(from: urlText) != nil }

    /// 取り込む。checkOnly なら保存せず、リンク切れを調べて保存先に報告ファイルを書く
    func start(checkOnly: Bool = false) {
        guard !isRunning else { return }
        checkOnlyMode = checkOnly
        guard let url = Mirror.startURL(from: urlText) else {
            message = (L("URLを確認してください"), L("「https://example.com/」のように入力します。"))
            return
        }
        let host = url.host ?? "site"
        let root: URL
        var report: URL?
        var resume = false
        if checkOnly {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            root = outputFolder
            report = outputFolder.appendingPathComponent("\(host)-linkcheck-\(formatter.string(from: Date())).txt")
            createdRoot = false
        } else {
            guard let (folder, overwriting, resuming) = chooseRoot(for: host, start: url) else { return }
            root = folder
            createdRoot = !overwriting
            resume = resuming
            do {
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            } catch {
                message = (L("保存先のフォルダーを作れません"), error.localizedDescription)
                return
            }
        }
        history.record(url)
        recentURLs = history.entries
        rows = []
        saved = 0; failed = 0; waiting = 0
        resultFolder = checkOnly ? nil : root
        startPage = nil
        logFile = nil
        diffReport = nil
        isRunning = true
        isRewriting = false
        isCheckOnly = checkOnly
        status = checkOnly ? L("リンクを調べています…") : L("取り込み中…")
        var options = self.options
        options.checkOnly = checkOnly
        options.resume = resume
        let emit: @Sendable (MirrorEvent) -> Void = { event in
            DispatchQueue.main.async { MainActor.assumeIsolated { Mirror.shared.apply(event) } }
        }
        let login = Login.shared
        task = Task.detached(priority: .userInitiated) { [options] in
            // アプリ内のブラウザーでログインしていれば、その Cookie と認証を使う
            let session = await login.session(for: url)
            var options = options
            options.cookies = session.cookies
            options.credential = session.credential
            let summary = await Crawler(start: url, root: root, logFile: report, options: options, emit: emit).run()
            emit(.finished(summary))
        }
    }

    func cancel() {
        guard isRunning else { return }
        status = L("中止しています…")
        task?.cancel()
    }

    private func apply(_ event: MirrorEvent) {
        switch event {
        case let .saved(url, path): append(.saved, url, path)
        case let .failed(url, reason): append(.failed, url, reason)
        case let .skipped(url, reason): append(.skipped, url, reason)
        case let .counts(saved, failed, waiting):
            self.saved = saved; self.failed = failed; self.waiting = waiting
        case let .rewriting(total):
            isRewriting = true
            waiting = 0
            status = L("リンクを書き換え中…（%d件）", total)
        case let .finished(summary):
            finish(summary)
        }
    }

    private func append(_ state: LogRow.State, _ url: String, _ detail: String) {
        rows.append(LogRow(id: rows.count, state: state, url: url, detail: detail))
    }

    private func finish(_ summary: MirrorSummary) {
        isRunning = false
        isRewriting = false
        task = nil
        saved = summary.saved
        failed = summary.failed
        startPage = summary.startPage
        logFile = summary.log
        diffReport = summary.diffReport
        var parts = [isCheckOnly ? L("%d件は正常", summary.saved) : L("%d件を保存", summary.saved)]
        if summary.unchanged > 0 { parts.append(L("%d件は変更なし", summary.unchanged)) }
        if summary.failed > 0 { parts.append(L("%d件は失敗", summary.failed)) }
        if summary.robotsBlocked > 0 { parts.append(L("%d件はrobots.txtで除外", summary.robotsBlocked)) }
        if summary.limitReached { parts.append(L("ファイル数の上限に達しました")) }
        if summary.sizeLimitReached { parts.append(L("合計の大きさの上限に達しました")) }
        if summary.purged > 0 { parts.append(L("%d件をゴミ箱に入れました", summary.purged)) }
        if summary.resumable { parts.append(L("続きから取り込めます")) }
        let head: String
        if isCheckOnly {
            if summary.cancelled { head = L("中止しました") }
            else if summary.saved == 0 { head = L("調べられませんでした") }
            else if summary.failed > 0 { head = L("リンク切れが%d件あります", summary.failed) }
            else { head = L("リンク切れはありませんでした") }
        } else if summary.cancelled { head = L("中止しました（保存したところまでリンクを書き換えました）") }
        else if summary.saved == 0 { head = L("保存できませんでした") }
        else if summary.failed > 0 || summary.limitReached || summary.sizeLimitReached { head = L("一部を保存しました") }
        else { head = L("取り込みました") }
        if let error = summary.diffError { parts.append(L("差分を保存できませんでした：%@", error)) }
        status = head + " — " + parts.joined(separator: L("、"))
        if summary.saved == 0, !summary.cancelled {
            message = (head, rows.first { $0.state == .failed }?.detail ?? L("URLとネットワークの接続を確認してください。"))
            // 新しく作ったフォルダーに記録しか無ければ消す（上書きした既存のフォルダーは残す）
            if createdRoot, let root = resultFolder,
               (try? FileManager.default.contentsOfDirectory(atPath: root.path))?.allSatisfy({ [Crawler.logName, Crawler.manifestName, Crawler.resumeName].contains($0) }) == true {
                try? FileManager.default.removeItem(at: root)
                resultFolder = nil
                logFile = nil
            }
        }
        if !summary.cancelled && UserDefaults.standard.bool(forKey: "completionNotificationEnabled") {
            NotificationPreferences.shared.post(title: "SiteMirror", body: status,
                identifier: "SiteMirror.latest-result", enabledKey: "completionNotificationEnabled", enabledDefault: false)
        }
        onFinished?()
        onFinished = nil
    }

    /// 取り込みフォルダーを決める。保存先が同じサイトのフォルダーそのものか、中に同じサイトのフォルダーがあれば、
    /// 上書きするか別のフォルダーにするかを確かめる。キャンセルなら nil
    private func chooseRoot(for host: String, start: URL) -> (URL, overwriting: Bool, resume: Bool)? {
        let inside = outputFolder.appendingPathComponent(host, isDirectory: true)
        let existing: URL
        if outputFolder.lastPathComponent.lowercased() == host.lowercased() {
            existing = outputFolder
        } else if FileManager.default.fileExists(atPath: inside.path) {
            existing = inside
        } else {
            return (inside, false, false)
        }
        // 中止した取り込みの続きがあれば、続きからも選べる
        struct Head: Decodable { let start: URL }
        let canResume = (try? Data(contentsOf: existing.appendingPathComponent(Crawler.resumeName)))
            .flatMap { try? JSONDecoder().decode(Head.self, from: $0) }?.start == start
        let alert = NSAlert()
        alert.messageText = L("「%@」フォルダーがあります", existing.lastPathComponent)
        var info = L("上書きすると、取り込んだファイルで置き換えます。今回取り込まなかったファイルはそのまま残ります。")
        if UserDefaults.standard.bool(forKey: Mirror.purgeRemovedKey) {
            info = L("上書きすると、取り込んだファイルで置き換え、サイトから消えたファイルはゴミ箱に入れます。")
        }
        if canResume { info = L("前回の取り込みは途中で中止されています。") + "\n" + info }
        alert.informativeText = info
        if canResume { alert.addButton(withTitle: L("続きから取り込む")) }
        alert.addButton(withTitle: canResume ? L("最初から上書き") : L("上書き"))
        alert.addButton(withTitle: L("別のフォルダーに保存"))
        let cancel = alert.addButton(withTitle: L("キャンセル"))
        cancel.keyEquivalent = "\u{1b}"
        let choice = alert.runModal().rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue - (canResume ? 1 : 0)
        switch choice {
        case -1: return (existing, true, true)
        case 0: return (existing, true, false)
        case 1: return (Mirror.uniqueFolder(in: existing.deletingLastPathComponent(), name: host), false, false)
        default: return nil
        }
    }

    func revealDiff() {
        guard let diffReport else { return }
        guard FileManager.default.fileExists(atPath: diffReport.path), NSWorkspace.shared.open(diffReport) else {
            message = (L("差分を開けませんでした"), L("保存先の SiteMirror-diff で始まる報告ファイルを確認してください。"))
            return
        }
    }

    func revealLog() {
        guard let logFile, FileManager.default.fileExists(atPath: logFile.path) else { return }
        NSWorkspace.shared.open(logFile)
    }

    /// 同じ名前のフォルダーがあれば「名前 2」「名前 3」…にする
    static func uniqueFolder(in parent: URL, name: String) -> URL {
        var candidate = parent.appendingPathComponent(name, isDirectory: true)
        var number = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = parent.appendingPathComponent("\(name) \(number)", isDirectory: true)
            number += 1
        }
        return candidate
    }

    func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = outputFolder
        panel.prompt = L("選択")
        panel.message = L("サイトごとのフォルダーをこの中に作ります")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        outputFolder = url
        UserDefaults.standard.set(url.path, forKey: Mirror.outputFolderKey)
    }

    func revealResult() {
        if let startPage, FileManager.default.fileExists(atPath: startPage.path) {
            NSWorkspace.shared.activateFileViewerSelecting([startPage])
        } else if let resultFolder, FileManager.default.fileExists(atPath: resultFolder.path) {
            NSWorkspace.shared.activateFileViewerSelecting([resultFolder])
        }
    }

    func openInBrowser() {
        guard let startPage, FileManager.default.fileExists(atPath: startPage.path) else { return }
        NSWorkspace.shared.open(startPage)
    }
}
