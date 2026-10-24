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

    // UserDefaults のキー。outputFolderKey 以外は「設定の共有」で同期する
    static let lastURLKey = "lastURL"
    static let outputFolderKey = "outputFolderPath"
    static let externalAssetsKey = "includeExternalAssets"
    static let subdomainsKey = "includeSubdomains"
    static let startFolderOnlyKey = "startFolderOnly"
    static let obeyRobotsKey = "obeyRobots"
    static let maxDepthKey = "maxDepth"
    static let maxFilesKey = "maxFiles"
    static let connectionsKey = "connections"
    static let syncedKeys: Set<String> = [externalAssetsKey, subdomainsKey, startFolderOnlyKey, obeyRobotsKey, maxDepthKey, maxFilesKey, connectionsKey]

    @Published var urlText: String {
        didSet { UserDefaults.standard.set(urlText, forKey: Mirror.lastURLKey) }
    }
    @Published private(set) var outputFolder: URL
    @Published private(set) var isRunning = false
    @Published private(set) var isRewriting = false
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
    /// 終了の確認で「中止して終了」を選んだとき、書き換えが終わってから呼ぶ
    var onFinished: (() -> Void)?

    private init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [Mirror.externalAssetsKey: true, Mirror.subdomainsKey: false, Mirror.startFolderOnlyKey: false,
                                     Mirror.obeyRobotsKey: true, Mirror.maxDepthKey: 0, Mirror.maxFilesKey: 10_000, Mirror.connectionsKey: 4])
        urlText = defaults.string(forKey: Mirror.lastURLKey) ?? ""
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
                             connections: min(8, max(1, defaults.integer(forKey: Mirror.connectionsKey))))
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

    var canStart: Bool { !isRunning && Mirror.startURL(from: urlText) != nil }

    func start() {
        guard !isRunning else { return }
        guard let url = Mirror.startURL(from: urlText) else {
            message = (L("URLを確認してください"), L("「https://example.com/」のように入力します。"))
            return
        }
        guard let (root, overwriting) = chooseRoot(for: url.host ?? "site") else { return }
        createdRoot = !overwriting
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        } catch {
            message = (L("保存先のフォルダーを作れません"), error.localizedDescription)
            return
        }
        rows = []
        saved = 0; failed = 0; waiting = 0
        resultFolder = root
        startPage = nil
        logFile = nil
        isRunning = true
        isRewriting = false
        status = L("取り込み中…")
        let options = options
        let emit: @Sendable (MirrorEvent) -> Void = { event in
            DispatchQueue.main.async { MainActor.assumeIsolated { Mirror.shared.apply(event) } }
        }
        task = Task.detached(priority: .userInitiated) {
            let summary = await Crawler(start: url, root: root, options: options, emit: emit).run()
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
        var parts = [L("%d件を保存", summary.saved)]
        if summary.failed > 0 { parts.append(L("%d件は失敗", summary.failed)) }
        if summary.robotsBlocked > 0 { parts.append(L("%d件はrobots.txtで除外", summary.robotsBlocked)) }
        if summary.limitReached { parts.append(L("ファイル数の上限に達しました")) }
        let head: String
        if summary.cancelled { head = L("中止しました（保存したところまでリンクを書き換えました）") }
        else if summary.saved == 0 { head = L("保存できませんでした") }
        else if summary.failed > 0 || summary.limitReached { head = L("一部を保存しました") }
        else { head = L("取り込みました") }
        status = head + " — " + parts.joined(separator: L("、"))
        if summary.saved == 0, !summary.cancelled {
            message = (L("保存できませんでした"), rows.first { $0.state == .failed }?.detail ?? L("URLとネットワークの接続を確認してください。"))
            // 新しく作ったフォルダーに記録しか無ければ消す（上書きした既存のフォルダーは残す）
            if createdRoot, let root = resultFolder,
               (try? FileManager.default.contentsOfDirectory(atPath: root.path))?.allSatisfy({ $0 == Crawler.logName }) == true {
                try? FileManager.default.removeItem(at: root)
                resultFolder = nil
            }
        }
        onFinished?()
        onFinished = nil
    }

    /// 取り込みフォルダーを決める。保存先が同じサイトのフォルダーそのものか、中に同じサイトのフォルダーがあれば、
    /// 上書きするか別のフォルダーにするかを確かめる。キャンセルなら nil
    private func chooseRoot(for host: String) -> (URL, overwriting: Bool)? {
        let inside = outputFolder.appendingPathComponent(host, isDirectory: true)
        let existing: URL
        if outputFolder.lastPathComponent.lowercased() == host.lowercased() {
            existing = outputFolder
        } else if FileManager.default.fileExists(atPath: inside.path) {
            existing = inside
        } else {
            return (inside, false)
        }
        let alert = NSAlert()
        alert.messageText = L("「%@」フォルダーがあります", existing.lastPathComponent)
        alert.informativeText = L("上書きすると、取り込んだファイルで置き換えます。今回取り込まなかったファイルはそのまま残ります。")
        alert.addButton(withTitle: L("上書き"))
        alert.addButton(withTitle: L("別のフォルダーに保存"))
        let cancel = alert.addButton(withTitle: L("キャンセル"))
        cancel.keyEquivalent = "\u{1b}"
        switch alert.runModal() {
        case .alertFirstButtonReturn: return (existing, true)
        case .alertSecondButtonReturn: return (Mirror.uniqueFolder(in: existing.deletingLastPathComponent(), name: host), false)
        default: return nil
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
