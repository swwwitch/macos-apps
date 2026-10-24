import Foundation
import UniformTypeIdentifiers

/// 取り込みの設定。UserDefaults とログイン情報から作る（Mirror）
struct MirrorOptions: @unchecked Sendable {
    /// ほかのドメインにある CSS・JS・画像・フォントも保存する
    var externalAssets = true
    /// サブドメインのページもたどる
    var subdomains = false
    /// 開始 URL のフォルダーより上のページはたどらない
    var startFolderOnly = false
    var obeyRobots = true
    /// ページをたどる深さ（0 は無制限）
    var maxDepth = 0
    /// 保存するファイル数の上限（0 は無制限）
    var maxFiles = 10_000
    var connections = 4
    /// 失敗したときに取り直す回数（タイムアウト・接続の失敗・429・5xx だけ）
    var retries = 2
    /// 取得を始める間隔（秒）。0.5〜1.5倍の幅で揺らす
    var interval: Double = 0
    /// 取り込まない URL（1行に1つ。* は任意の文字列、* が無ければ URL に含まれるかで判定）
    var excludes: [String] = []
    /// 上書きのとき、変わっていないファイル（HTML・CSS 以外）は取り直さない
    var skipUnchanged = true
    /// 指定したときは、当てはまるページだけをたどる（表示に必要なファイルは指定に関係なく取る）
    var includes: [String] = []
    /// sitemap.xml（robots.txt の Sitemap:）に載っているページもたどる
    var useSitemap = false
    /// JavaScript の中に書かれたファイルの URL も拾う（推測）
    var scanScripts = false
    /// 取らないファイルの拡張子（小文字、. なし）
    var excludedTypes: [String] = []
    /// 1ファイルと合計の大きさの上限（MB、0 は無制限）
    var maxFileMB = 0
    var maxTotalMB = 0
    /// 上書きのとき、サイトから消えたファイルをゴミ箱に入れる
    var purgeRemoved = false
    /// 中断した取り込みの続きから取り込む
    var resume = false
    /// 保存せず、リンク切れだけを調べる
    var checkOnly = false
    /// ログインで得た Cookie（アプリ内のブラウザーから）と、Basic 認証の名前とパスワード
    var cookies: [HTTPCookie] = []
    var credential: URLCredential?
    var isLoggedIn: Bool { !cookies.isEmpty || credential != nil }
}

/// 取り込み中の出来事。メインスレッドへ順に届ける
enum MirrorEvent: Sendable {
    case saved(url: String, path: String)
    case failed(url: String, reason: String)
    case skipped(url: String, reason: String)
    case counts(saved: Int, failed: Int, waiting: Int)
    case rewriting(total: Int)
    case finished(MirrorSummary)
}

struct MirrorSummary: Sendable {
    /// 保存した（リンクの確認では、正常だった）件数
    var saved = 0
    var failed = 0
    /// 上書きで、変わっていなかったので取り直さなかった件数
    var unchanged = 0
    var rewritten = 0
    var cancelled = false
    var limitReached = false
    /// 合計の大きさの上限に達した
    var sizeLimitReached = false
    var robotsBlocked = 0
    /// サイトから消えたのでゴミ箱に入れた件数
    var purged = 0
    /// 中止したので、続きから取り込める
    var resumable = false
    /// 開始ページを保存したファイル
    var startPage: URL?
    /// 記録ファイル（取り込みフォルダーの SiteMirror-log.txt か、リンクの確認の報告）
    var log: URL?
    var root: URL
}

/// 1回の取り込み。1つの Task の中だけで使う（取得だけを子タスクに出す）
final class Crawler {
    private enum Purpose: String, Sendable, Codable {
        /// たどるページ
        case page
        /// ページの表示に必要なファイル
        case asset
        /// リンクの確認で、たどらずに有無だけ確かめるページ（ほかのサイトなど）
        case external
    }
    private struct Job: Sendable, Codable {
        let url: URL
        let depth: Int
        let purpose: Purpose
        /// リンクしていたファイル（保存先の相対パス。リンクの確認ではページの URL）。記録に参照元として書く
        let from: String?
    }
    private enum Kind: String, Codable { case html, css, other }
    private struct Entry: Codable {
        let path: String
        let url: URL
        let kind: Kind
        let encodingValue: UInt
        var encoding: String.Encoding { String.Encoding(rawValue: encodingValue) }
        init(path: String, url: URL, kind: Kind, encoding: String.Encoding) {
            self.path = path; self.url = url; self.kind = kind; encodingValue = encoding.rawValue
        }
    }
    /// 記録ファイルに書く失敗・除外・削除の1件
    private struct Note: Codable {
        let url: String
        let reason: String
        let from: String?
    }
    /// 中止したときに取り込みフォルダーに残す、続きから取り込むための状態
    private struct ResumeState: Codable {
        let start: URL
        let queue: [Job]
        let seen: [String]
        let entries: [String: Entry]
        let documents: [String]
        let siteHosts: [String]
        let startFolder: String
        let failures: [Note]
        let skips: [Note]
        let saved: Int
        let totalBytes: Int64
    }
    /// 取得のときの大きさと種類の制限
    private struct Limits: Sendable {
        let maxBytes: Int64
        let types: [String]
    }
    private struct Fetched: Sendable {
        var finalURL: URL?
        var status = 0
        var mime: String?
        var charset: String?
        var etag: String?
        var lastModified: String?
        var data: Data?
        var error: String?
        var retried = 0
        /// 大きさ・種類の制限で取らなかった理由
        var rejected: String?
    }
    /// 前回までに保存したファイル。上書きのとき、同じ URL を同じファイルに保存し、変わっていなければ取り直さない
    private struct Saved: Codable {
        var path: String
        var kind: String
        var etag: String?
        var lastModified: String?
    }

    private let start: URL
    private let root: URL
    private let logFile: URL
    private let options: MirrorOptions
    private let emit: @Sendable (MirrorEvent) -> Void
    private let session: URLSession
    /// サイトのホスト（www. を除いたもの）。開始ページの転送先も加える
    private var siteHosts: Set<String>
    private var startFolder: String
    private var queue: [Job] = []
    private var head = 0
    private var seen = Set<String>()
    private var entries: [String: Entry] = [:]
    private var documents: [Entry] = []
    private var usedPaths = Set<String>()
    private var usedFolders = Set<String>()
    private var robots: Robots?
    private var summary: MirrorSummary
    private let excludes: [(text: String, regex: NSRegularExpression)]
    private var previous: [String: Saved] = [:]
    private var manifest: [String: Saved] = [:]
    private let includes: [(text: String, regex: NSRegularExpression)]
    /// 記録ファイルに書く失敗・除外・削除（URL・理由・参照元）
    private var failures: [Note] = []
    private var skips: [Note] = []
    private var purgedNotes: [Note] = []
    /// 取得中の取り込み（中止したとき、続きに回す）
    private var inFlight: [String: Job] = [:]
    private var totalBytes: Int64 = 0
    /// 今回リンクで見つかった URL と、保存した（変更なしを含む）URL、404・410 だった URL。サイトから消えたファイルの判定に使う
    private var referenced = Set<String>()
    private var touched = Set<String>()
    private var gone = Set<String>()
    private let startedAt = Date()
    /// 取り込みフォルダーに置く記録と、保存したファイルの一覧。サイトのファイルとぶつからないよう名前を取っておく
    static let logName = "SiteMirror-log.txt"
    static let manifestName = ".sitemirror.json"
    static let resumeName = ".sitemirror-resume.json"
    /// ログイン中はログアウトのリンクをたどらない（たどるとログインが切れる）
    private static let logout = try! NSRegularExpression(pattern: "(log|sign)[-_]?(out|off)", options: .caseInsensitive)

    /// root は取り込みフォルダー。logFile は記録の書き出し先（リンクの確認では保存先の中の報告ファイル）
    init(start: URL, root: URL, logFile: URL? = nil, options: MirrorOptions, emit: @escaping @Sendable (MirrorEvent) -> Void) {
        self.start = start
        self.root = root
        self.logFile = logFile ?? root.appendingPathComponent(Crawler.logName)
        self.options = options
        self.emit = emit
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpMaximumConnectionsPerHost = max(1, options.connections)
        configuration.timeoutIntervalForRequest = 30
        configuration.httpAdditionalHeaders = ["User-Agent": Crawler.userAgent]
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        // ログインの Cookie を入れる。取り込み中にサーバーが返した Cookie もここに足される
        for cookie in options.cookies { configuration.httpCookieStorage?.setCookie(cookie) }
        session = URLSession(configuration: configuration, delegate: AuthDelegate(credential: options.credential), delegateQueue: nil)
        siteHosts = [Crawler.siteKey(start.host ?? "")]
        startFolder = Crawler.folder(of: start)
        summary = MirrorSummary(root: root)
        excludes = options.excludes.compactMap { Crawler.pattern($0) }
        includes = options.includes.compactMap { Crawler.pattern($0) }
        guard !options.checkOnly else { return }
        usedPaths.insert(Crawler.logName.lowercased())
        usedPaths.insert(Crawler.manifestName)
        usedPaths.insert(Crawler.resumeName)
        if let data = try? Data(contentsOf: root.appendingPathComponent(Crawler.manifestName)),
           let saved = try? JSONDecoder().decode([String: Saved].self, from: data) {
            previous = saved
            manifest = saved
            for item in saved.values { reserve(item.path) }
        }
        if options.resume, let data = try? Data(contentsOf: root.appendingPathComponent(Crawler.resumeName)),
           let state = try? JSONDecoder().decode(ResumeState.self, from: data), state.start == start {
            queue = state.queue
            seen = Set(state.seen)
            entries = state.entries
            let byPath = Dictionary(state.entries.values.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
            documents = state.documents.compactMap { byPath[$0] }
            siteHosts = Set(state.siteHosts)
            startFolder = state.startFolder
            failures = state.failures
            skips = state.skips
            summary.saved = state.saved
            summary.failed = state.failures.count
            totalBytes = state.totalBytes
            for entry in state.entries.values { reserve(entry.path) }
            resumed = true
        }
    }
    /// 続きから取り込んでいる（開始ページは取り直さない）
    private var resumed = false

    static let userAgent: String = {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) SiteMirror/\(version)"
    }()

    func run() async -> MirrorSummary {
        defer { session.invalidateAndCancel() }
        if options.obeyRobots || options.useSitemap { robots = await Robots.load(for: start, session: session) }
        if !resumed {
            enqueue(start, depth: 0, purpose: .page, from: nil, force: true)
            if options.useSitemap { await loadSitemaps() }
        }
        var nextStart = Date.distantPast
        // nil は間隔待ちのタイマー。取得の結果と同じ group で待ち、どちらか早い方で次に進む
        await withTaskGroup(of: (Job, Fetched)?.self) { group in
            var running = 0
            var timer = false
            while !Task.isCancelled {
                while running < max(1, options.connections), head < queue.count, !summary.sizeLimitReached {
                    if options.interval > 0 {
                        let delay = nextStart.timeIntervalSinceNow
                        if delay > 0 {
                            if !timer {
                                timer = true
                                group.addTask { try? await Task.sleep(for: .seconds(delay)); return nil }
                            }
                            break
                        }
                        nextStart = Date().addingTimeInterval(options.interval * Double.random(in: 0.5...1.5))
                    }
                    let job = queue[head]
                    head += 1
                    let request = request(for: job)
                    let session = self.session
                    let retries = options.retries
                    let probe = options.checkOnly && job.purpose != .page
                    let limits = limits
                    inFlight[Crawler.key(job.url)] = job
                    group.addTask { (job, await Crawler.fetch(request, session: session, retries: retries, probe: probe, limits: limits)) }
                    running += 1
                }
                guard running > 0 || timer, let result = await group.next() else { break }
                guard let (job, fetched) = result else { timer = false; continue }
                running -= 1
                if Task.isCancelled { break }
                inFlight[Crawler.key(job.url)] = nil
                handle(job, fetched)
                emit(.counts(saved: summary.saved, failed: summary.failed, waiting: queue.count - head + running))
            }
            group.cancelAll()
        }
        summary.cancelled = Task.isCancelled
        if !options.checkOnly {
            // 中止したら、残りと取得中だったものを続きに回せるよう状態を残す。最後まで取れたら消す
            let resumeFile = root.appendingPathComponent(Crawler.resumeName)
            if summary.cancelled {
                saveResume(to: resumeFile)
            } else {
                try? FileManager.default.removeItem(at: resumeFile)
            }
            if options.purgeRemoved, !summary.cancelled, !summary.limitReached, !summary.sizeLimitReached { purgeRemoved() }
            // 中止しても、保存したところまではリンクを書き換えて開けるようにする
            emit(.rewriting(total: documents.count))
            for document in documents { if rewrite(document) { summary.rewritten += 1 } }
            if let entry = entries[Crawler.key(start)] { summary.startPage = root.appendingPathComponent(entry.path) }
            if let data = try? JSONEncoder().encode(manifest) {
                try? data.write(to: root.appendingPathComponent(Crawler.manifestName), options: .atomic)
            }
        }
        writeLog()
        return summary
    }

    // MARK: 取得

    private func request(for job: Job) -> URLRequest {
        var request = URLRequest(url: job.url)
        // 前回の取り込みで保存した画像などは、変わっていなければ 304 が返り、取り直さない
        if options.skipUnchanged, job.purpose == .asset, let saved = previous[Crawler.key(job.url)], saved.kind == Kind.other.rawValue,
           FileManager.default.fileExists(atPath: root.appendingPathComponent(saved.path).path) {
            if let etag = saved.etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
            if let modified = saved.lastModified { request.setValue(modified, forHTTPHeaderField: "If-Modified-Since") }
        }
        return request
    }

    /// 一時的な失敗（タイムアウト・接続の失敗・429・5xx）は、待ってから retries 回まで取り直す。
    /// probe は中身の要らない確認で、まず HEAD で尋ね、断られたら GET にする（CSS は中のリンクを調べるので GET）
    private static func fetch(_ request: URLRequest, session: URLSession, retries: Int, probe: Bool, limits: Limits) async -> Fetched {
        var attempt = 0
        while true {
            var result = await once(request, session: session, head: probe && request.url?.pathExtension.lowercased() != "css", limits: limits)
            if probe, result.data != nil, result.status >= 400 || result.mime == "text/css" {
                result = await once(request, session: session, head: false, limits: limits)
            }
            result.retried = attempt
            guard attempt < retries, !Task.isCancelled, let wait = retryDelay(result, attempt: attempt) else { return result }
            try? await Task.sleep(for: .seconds(wait))
            if Task.isCancelled { return Fetched() }
            attempt += 1
        }
    }

    /// 1回取得する。応答のヘッダーで大きさと種類を確かめ、制限を超えるものは中身を読まずに打ち切る
    private static func once(_ request: URLRequest, session: URLSession, head: Bool, limits: Limits) async -> Fetched {
        var request = request
        if head { request.httpMethod = "HEAD" }
        do {
            let (bytes, response) = try await session.bytes(for: request)
            let http = response as? HTTPURLResponse
            var result = Fetched(finalURL: response.url ?? request.url, status: http?.statusCode ?? 200,
                                 mime: response.mimeType?.lowercased(), charset: response.textEncodingName,
                                 etag: http?.value(forHTTPHeaderField: "ETag"), lastModified: http?.value(forHTTPHeaderField: "Last-Modified"))
            if (200..<300).contains(result.status), !head {
                if limits.maxBytes > 0, response.expectedContentLength > limits.maxBytes {
                    bytes.task.cancel()
                    result.rejected = L("大きすぎるため取りません（%@）", size(response.expectedContentLength))
                    return result
                }
                if let mime = result.mime, let ext = UTType(mimeType: mime)?.preferredFilenameExtension?.lowercased(), limits.types.contains(ext) {
                    bytes.task.cancel()
                    result.rejected = L("取らない種類（.%@）", ext)
                    return result
                }
            }
            var data = Data()
            if response.expectedContentLength > 0 { data.reserveCapacity(Int(min(response.expectedContentLength, 64 << 20))) }
            for try await byte in bytes {
                data.append(byte)
                if limits.maxBytes > 0, data.count > limits.maxBytes {
                    bytes.task.cancel()
                    result.rejected = L("大きすぎるため取りません（%@）", size(Int64(data.count)) + "+")
                    return result
                }
            }
            result.data = data
            return result
        } catch {
            let code = (error as? URLError)?.code
            return Fetched(status: code.map { -$0.rawValue } ?? 0, error: code == .cancelled ? nil : error.localizedDescription)
        }
    }

    private static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private var limits: Limits {
        Limits(maxBytes: options.checkOnly ? 0 : Int64(options.maxFileMB) << 20, types: options.checkOnly ? [] : options.excludedTypes)
    }

    /// 取り直すまでの秒数。取り直さない失敗は nil
    private static func retryDelay(_ fetched: Fetched, attempt: Int) -> Double? {
        let backoff = Double(1 << attempt)
        if fetched.data == nil {
            let transient: [URLError.Code] = [.timedOut, .networkConnectionLost, .cannotConnectToHost, .notConnectedToInternet, .dnsLookupFailed]
            return transient.map({ -$0.rawValue }).contains(fetched.status) ? backoff : nil
        }
        guard [408, 425, 429, 500, 502, 503, 504].contains(fetched.status) else { return nil }
        return backoff
    }

    private func handle(_ job: Job, _ fetched: Fetched) {
        let address = job.url.absoluteString
        let retried = fetched.retried > 0 ? L("（%d回再試行）", fetched.retried) : ""
        let key = Crawler.key(job.url)
        if let rejected = fetched.rejected {
            skip(address, rejected, job.from)
            return
        }
        guard let data = fetched.data, let finalURL = fetched.finalURL else {
            if let error = fetched.error { fail(address, error + retried, job.from) }
            return
        }
        if fetched.status == 304, let saved = previous[key] {
            let entry = Entry(path: saved.path, url: finalURL, kind: .other, encoding: .utf8)
            entries[key] = entry
            entries[Crawler.key(finalURL)] = entry
            touched.insert(key)
            summary.saved += 1
            summary.unchanged += 1
            emit(.saved(url: address, path: L("%@（変更なし）", saved.path)))
            return
        }
        guard (200..<300).contains(fetched.status) || (300..<400).contains(fetched.status) && fetched.status != 304 else {
            if [404, 410].contains(fetched.status) { gone.insert(key) }
            fail(address, "HTTP \(fetched.status)" + retried, job.from)
            return
        }
        if options.checkOnly {
            check(job, fetched, data: data, finalURL: finalURL)
            return
        }
        // 開始ページが転送されたら、転送先のホストもサイトとして扱う（http→https・www の有無など）
        if job.url == start, let host = finalURL.host { siteHosts.insert(Crawler.siteKey(host)); startFolder = Crawler.folder(of: finalURL) }
        if let existing = entries[Crawler.key(finalURL)] {
            entries[key] = existing
            return
        }
        if job.purpose == .page, !inPageScope(finalURL) {
            skip(address, L("サイトの外へ転送"), job.from)
            return
        }
        let kind = Crawler.kind(fetched.mime, finalURL)
        // 前回と同じ URL は同じファイルに保存する（上書き）
        let path: String
        if let saved = previous[key] ?? previous[Crawler.key(finalURL)], saved.kind == kind.rawValue {
            path = saved.path
        } else {
            path = localPath(for: finalURL, kind: kind, mime: fetched.mime)
        }
        let file = root.appendingPathComponent(path)
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
        } catch {
            fail(address, error.localizedDescription, job.from)
            return
        }
        let encoding = kind == .other ? .utf8 : Crawler.encoding(of: data, header: fetched.charset, html: kind == .html)
        let entry = Entry(path: path, url: finalURL, kind: kind, encoding: encoding)
        entries[key] = entry
        entries[Crawler.key(finalURL)] = entry
        manifest[key] = Saved(path: path, kind: kind.rawValue, etag: fetched.etag, lastModified: fetched.lastModified)
        touched.insert(key)
        summary.saved += 1
        emit(.saved(url: address, path: path))
        totalBytes += Int64(data.count)
        if options.maxTotalMB > 0, totalBytes > Int64(options.maxTotalMB) << 20 { summary.sizeLimitReached = true }

        if kind == .other {
            if options.scanScripts, Crawler.isScript(fetched.mime, finalURL) {
                scanScript(String(decoding: data, as: UTF8.self), url: finalURL, job: job, from: path)
            }
            return
        }
        guard let text = String(data: data, encoding: encoding) else { return }
        documents.append(entry)
        follow(job, kind: kind, text: text, url: finalURL, from: path)
        if kind == .html, options.scanScripts { scanScript(text, url: finalURL, job: job, from: path) }
    }

    /// リンクの確認：保存せず、ページなら中のリンクをたどる
    private func check(_ job: Job, _ fetched: Fetched, data: Data, finalURL: URL) {
        if job.url == start, let host = finalURL.host { siteHosts.insert(Crawler.siteKey(host)); startFolder = Crawler.folder(of: finalURL) }
        summary.saved += 1
        emit(.saved(url: job.url.absoluteString, path: "HTTP \(fetched.status)"))
        let kind = Crawler.kind(fetched.mime, finalURL)
        guard kind != .other, job.purpose != .external, job.purpose == .page || kind == .css,
              job.purpose != .page || inPageScope(finalURL),
              let text = String(data: data, encoding: Crawler.encoding(of: data, header: fetched.charset, html: kind == .html)) else { return }
        follow(job, kind: kind, text: text, url: finalURL, from: finalURL.absoluteString)
    }

    private func follow(_ job: Job, kind: Kind, text: String, url: URL, from: String) {
        if kind == .html {
            // 素材として取った HTML（link rel=preload など）からはたどらない
            guard job.purpose == .page else { return }
            for link in SiteLinks.html(text, documentURL: url).links {
                if link.role == .page {
                    if options.maxDepth == 0 || job.depth < options.maxDepth {
                        enqueue(link.url, depth: job.depth + 1, purpose: .page, from: from)
                    } else if options.checkOnly {
                        enqueue(link.url, depth: job.depth + 1, purpose: .external, from: from)
                    }
                } else {
                    enqueue(link.url, depth: job.depth, purpose: .asset, from: from)
                }
            }
        } else {
            for link in SiteLinks.css(text, documentURL: url) { enqueue(link.url, depth: job.depth, purpose: .asset, from: from) }
        }
    }

    private static func isScript(_ mime: String?, _ url: URL) -> Bool {
        (mime ?? "").contains("javascript") || ["js", "mjs"].contains(url.pathExtension.lowercased())
    }

    /// JavaScript（と HTML の中のスクリプト）に書かれたファイルの URL を、表示に必要なファイルとして取る
    private func scanScript(_ text: String, url: URL, job: Job, from: String) {
        for found in SiteLinks.scriptURLs(text, base: url) { enqueue(found, depth: job.depth, purpose: .asset, from: from) }
    }

    private static func kind(_ mime: String?, _ url: URL) -> Kind {
        switch mime {
        case "text/html", "application/xhtml+xml": return .html
        case "text/css": return .css
        default: return url.pathExtension.lowercased() == "css" ? .css : .other
        }
    }

    private func fail(_ address: String, _ reason: String, _ from: String?) {
        summary.failed += 1
        failures.append(Note(url: address, reason: reason, from: from))
        emit(.failed(url: address, reason: reason))
    }

    private func skip(_ address: String, _ reason: String, _ from: String?) {
        skips.append(Note(url: address, reason: reason, from: from))
        emit(.skipped(url: address, reason: reason))
    }

    private func enqueue(_ url: URL, depth: Int, purpose: Purpose, from: String?, force: Bool = false) {
        let key = Crawler.key(url)
        referenced.insert(key)
        guard !seen.contains(key) else { return }
        var purpose = purpose
        if !force {
            switch purpose {
            case .page:
                // リンクの確認では、範囲の外のページも有無だけ確かめる
                if !inPageScope(url) {
                    guard options.checkOnly else { return }
                    purpose = .external
                }
            case .asset: guard options.checkOnly || options.externalAssets || inSite(url) else { return }
            case .external: break
            }
            let address = url.absoluteString
            let range = NSRange(location: 0, length: (address as NSString).length)
            // 取り込むURLを指定したときは、当てはまるページだけをたどる
            if purpose == .page, !includes.isEmpty, !includes.contains(where: { $0.regex.firstMatch(in: address, range: range) != nil }) { return }
            let ext = url.pathExtension.lowercased()
            if !options.checkOnly, !ext.isEmpty, options.excludedTypes.contains(ext) {
                seen.insert(key)
                skip(address, L("取らない種類（.%@）", ext), from)
                return
            }
            if let match = excludes.first(where: { $0.regex.firstMatch(in: address, range: NSRange(location: 0, length: (address as NSString).length)) != nil }) {
                seen.insert(key)
                skip(address, L("除外するURL「%@」", match.text), from)
                return
            }
            if options.isLoggedIn, purpose == .page,
               Crawler.logout.firstMatch(in: address, range: NSRange(location: 0, length: (address as NSString).length)) != nil {
                seen.insert(key)
                skip(address, L("ログアウトのリンク"), from)
                return
            }
        }
        if purpose == .page, let robots, inSite(url), !robots.allows(url) {
            seen.insert(key)
            summary.robotsBlocked += 1
            skip(url.absoluteString, L("robots.txtで除外"), from)
            return
        }
        if options.maxFiles > 0, seen.count >= options.maxFiles {
            summary.limitReached = true
            return
        }
        seen.insert(key)
        queue.append(Job(url: url, depth: depth, purpose: purpose, from: from))
    }

    /// 除外する URL の1行。* は任意の文字列で、URL のどこかに当てはまれば除外
    private static func pattern(_ line: String) -> (text: String, regex: NSRegularExpression)? {
        let text = line.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !text.hasPrefix("#") else { return nil }
        let escaped = NSRegularExpression.escapedPattern(for: text).replacingOccurrences(of: "\\*", with: ".*")
        guard let regex = try? NSRegularExpression(pattern: escaped, options: .caseInsensitive) else { return nil }
        return (text, regex)
    }

    // MARK: 記録

    /// 取り込みフォルダーに、結果と失敗・除外の一覧（URL・理由・参照元）をテキストで残す。上書きのときは置き換える
    private func writeLog() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        var lines = [options.checkOnly ? L("SiteMirror リンクの確認") : L("SiteMirror 取り込みの記録"), "",
                     L("開始URL : %@", start.absoluteString),
                     L("日時 : %@", formatter.string(from: startedAt)),
                     options.checkOnly ? L("正常 : %d件", summary.saved) : L("保存 : %d件", summary.saved),
                     L("失敗 : %d件", summary.failed),
                     L("除外 : %d件", skips.count)]
        if summary.unchanged > 0 { lines.append(L("変更なし : %d件（取り直していません）", summary.unchanged)) }
        if summary.cancelled { lines.append(L("途中で中止しました")) }
        if summary.limitReached { lines.append(L("ファイル数の上限に達しました")) }
        if summary.sizeLimitReached { lines.append(L("合計の大きさの上限に達しました")) }
        if summary.resumable { lines.append(L("続きから取り込めます（同じフォルダーに取り込むと尋ねます）")) }
        if !purgedNotes.isEmpty { lines.append(L("ゴミ箱に入れた : %d件（サイトから消えたファイル）", purgedNotes.count)) }
        for (title, items, third) in [(L("失敗"), failures, L("参照元")), (L("除外"), skips, L("参照元")),
                                      (L("ゴミ箱に入れたファイル"), purgedNotes, L("保存したファイル"))] where !items.isEmpty {
            lines += ["", "## \(title)（\(items.count)）", [L("URL"), L("理由"), third].joined(separator: "\t")]
            lines += items.map { [$0.url, $0.reason, $0.from ?? "-"].joined(separator: "\t") }
        }
        if (try? (lines.joined(separator: "\n") + "\n").write(to: logFile, atomically: true, encoding: .utf8)) != nil {
            summary.log = logFile
        }
    }

    /// 相対リンクが、取り込みフォルダーの中の保存済みのファイルを指しているか
    private func existsLocally(_ raw: String, from document: String) -> Bool {
        let path = String(raw.prefix { $0 != "?" && $0 != "#" })
        guard !path.isEmpty, !path.hasPrefix("/"), let decoded = path.removingPercentEncoding else { return false }
        let folder = root.appendingPathComponent(document).deletingLastPathComponent()
        let target = folder.appendingPathComponent(decoded).standardizedFileURL
        guard target.path.hasPrefix(root.standardizedFileURL.path + "/") else { return false }
        var isFolder: ObjCBool = false
        return FileManager.default.fileExists(atPath: target.path, isDirectory: &isFolder) && !isFolder.boolValue
    }

    // MARK: sitemap・続き・削除

    /// robots.txt の Sitemap:（無ければ /sitemap.xml）を読み、載っているページをたどる。サイトマップの索引は50ファイルまで
    private func loadSitemaps() async {
        var pending = robots?.sitemaps.compactMap { URL(string: $0) } ?? []
        if pending.isEmpty, let url = URL(string: "/sitemap.xml", relativeTo: start)?.absoluteURL { pending = [url] }
        var read = Set<String>()
        while !pending.isEmpty, read.count < 50, !Task.isCancelled {
            let url = pending.removeFirst()
            guard read.insert(url.absoluteString).inserted,
                  let (data, response) = try? await session.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200 else { continue }
            let xml = String(decoding: data, as: UTF8.self)
            let locs = SiteLinks.sitemapLocations(xml)
            if xml.contains("<sitemapindex") {
                pending += locs
            } else {
                for loc in locs { enqueue(loc, depth: 1, purpose: .page, from: url.lastPathComponent) }
            }
        }
    }

    private func saveResume(to file: URL) {
        let remaining = Array(inFlight.values) + queue[head...]
        let state = ResumeState(start: start, queue: remaining, seen: Array(seen), entries: entries,
                                documents: documents.map(\.path), siteHosts: Array(siteHosts), startFolder: startFolder,
                                failures: failures, skips: skips, saved: summary.saved, totalBytes: totalBytes)
        if let data = try? JSONEncoder().encode(state), (try? data.write(to: file, options: .atomic)) != nil {
            summary.resumable = true
        }
    }

    /// 前回保存したのに、今回どこからもリンクされていないか 404・410 だったファイルをゴミ箱に入れる
    /// （一時的に取れなかったもの、除外したもの、範囲の外にしたものは残す）
    private func purgeRemoved() {
        for (key, saved) in previous where !touched.contains(key) && (gone.contains(key) || !referenced.contains(key)) {
            let file = root.appendingPathComponent(saved.path)
            manifest[key] = nil
            guard FileManager.default.fileExists(atPath: file.path),
                  (try? FileManager.default.trashItem(at: file, resultingItemURL: nil)) != nil else { continue }
            summary.purged += 1
            purgedNotes.append(Note(url: key, reason: gone.contains(key) ? L("サイトから削除された") : L("どこからもリンクされていない"), from: saved.path))
            // 空になったフォルダーも片付ける
            var folder = file.deletingLastPathComponent()
            while folder.path.hasPrefix(root.path + "/"),
                  (try? FileManager.default.contentsOfDirectory(atPath: folder.path))?.allSatisfy({ $0 == ".DS_Store" }) == true {
                try? FileManager.default.removeItem(at: folder)
                folder = folder.deletingLastPathComponent()
            }
        }
    }

    // MARK: 範囲

    /// www. の有無は同じサイトとみなす
    private static func siteKey(_ host: String) -> String {
        let lower = host.lowercased()
        return lower.hasPrefix("www.") ? String(lower.dropFirst(4)) : lower
    }

    private func isSiteHost(_ url: URL) -> Bool { siteHosts.contains(Crawler.siteKey(url.host ?? "")) }

    /// サイトのホストか、オンならサブドメイン
    private func inSite(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
        if isSiteHost(url) { return true }
        let key = Crawler.siteKey(host)
        return options.subdomains && siteHosts.contains { key.hasSuffix("." + $0) }
    }

    private func inPageScope(_ url: URL) -> Bool {
        guard inSite(url) else { return false }
        guard options.startFolderOnly, isSiteHost(url) else { return true }
        return url.path.hasPrefix(startFolder) || url.path + "/" == startFolder
    }

    private static func folder(of url: URL) -> String {
        let path = url.path.isEmpty ? "/" : url.path
        if url.absoluteString.hasSuffix("/") || path == "/" { return path.hasSuffix("/") ? path : path + "/" }
        return (path as NSString).deletingLastPathComponent.appending("/").replacingOccurrences(of: "//", with: "/")
    }

    /// 同じファイルの目印。http と https、# 以降、既定のポートは区別しない
    private static func key(_ url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.fragment = nil
        let host = siteKey(components?.host ?? "")
        let port = components?.port.map { ":\($0)" } ?? ""
        let path = components?.percentEncodedPath.isEmpty == false ? components!.percentEncodedPath : "/"
        let query = components?.percentEncodedQuery.map { "?" + $0 } ?? ""
        return host + port + path + query
    }

    // MARK: 保存先

    /// サイトのファイルは取り込みフォルダーの直下、ほかのホストは _hosts/<ホスト>/ に置く
    private func localPath(for url: URL, kind: Kind, mime: String?) -> String {
        var parts: [String] = []
        if !isSiteHost(url) {
            let port = url.port.map { "_\($0)" } ?? ""
            parts = ["_hosts", (url.host ?? "unknown").lowercased() + port]
        }
        let decoded = url.path(percentEncoded: false)
        parts += decoded.split(separator: "/").map(String.init)
        let isFolder = decoded.isEmpty || decoded.hasSuffix("/")
        var name = isFolder || parts.count == (isSiteHost(url) ? 0 : 2) ? "index" : parts.removeLast()
        let ext = (name as NSString).pathExtension.lowercased()
        switch kind {
        case .html where !["html", "htm", "xhtml", "shtml"].contains(ext): name += ".html"
        case .css where ext != "css": name += ".css"
        case .other where ext.isEmpty:
            if let mime, let preferred = UTType(mimeType: mime)?.preferredFilenameExtension { name += "." + preferred }
        default: break
        }
        if let query = url.query, !query.isEmpty { name = Crawler.insert("_" + Crawler.hash(query), into: name) }
        parts = parts.map(Crawler.clean)
        var file = Crawler.clean(name)
        let folder = parts.joined(separator: "/")
        func full(_ file: String) -> String { folder.isEmpty ? file : folder + "/" + file }
        // 大文字と小文字だけが異なる名前、フォルダーと同じ名前は番号を付けて分ける
        var number = 2
        let original = file
        while usedPaths.contains(full(file).lowercased()) || usedFolders.contains(full(file).lowercased()) {
            file = Crawler.insert("-\(number)", into: original)
            number += 1
        }
        let path = full(file)
        reserve(path)
        return path
    }

    /// 保存先のパスと、その途中のフォルダーを使用済みにする
    private func reserve(_ path: String) {
        usedPaths.insert(path.lowercased())
        var prefix = ""
        for part in path.split(separator: "/").dropLast() {
            prefix = prefix.isEmpty ? String(part) : prefix + "/" + part
            usedFolders.insert(prefix.lowercased())
        }
    }

    /// 拡張子の前に差し込む
    private static func insert(_ suffix: String, into name: String) -> String {
        let ext = (name as NSString).pathExtension
        guard !ext.isEmpty else { return name + suffix }
        return (name as NSString).deletingPathExtension + suffix + "." + ext
    }

    /// Finder で扱えない文字を除き、長すぎる名前を縮める
    private static func clean(_ part: String) -> String {
        var name = String(part.map { $0 == ":" || $0 == "\\" || $0.asciiValue.map { $0 < 0x20 } == true ? "_" : $0 })
        if name == "." || name == ".." || name.isEmpty { name = "_" + name }
        if name.utf8.count > 200 {
            let ext = (name as NSString).pathExtension
            let stem = String((name as NSString).deletingPathExtension.prefix(80))
            name = stem + "_" + hash(name) + (ext.isEmpty || ext.count > 10 ? "" : "." + ext)
        }
        return name
    }

    /// クエリをファイル名に入れるための短い目印（FNV-1a）
    private static func hash(_ text: String) -> String {
        var value: UInt32 = 0x811C9DC5
        for byte in text.utf8 { value = (value ^ UInt32(byte)) &* 0x0100_0193 }
        return String(format: "%08x", value)
    }

    // MARK: 文字コード

    /// ヘッダー → <meta charset>・@charset → UTF-8。どれでも読めなければ ISO Latin 1（バイトをそのまま保つ）
    private static func encoding(of data: Data, header: String?, html: Bool) -> String.Encoding {
        var names: [String] = []
        if let header { names.append(header) }
        let head = String(decoding: data.prefix(4096), as: UTF8.self)
        let pattern = html ? "<meta[^>]+charset\\s*=\\s*[\"']?([A-Za-z0-9_:.-]+)" : "@charset\\s+\"([^\"]+)\""
        if let range = head.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
            let match = String(head[range])
            if let name = match.range(of: "[A-Za-z0-9_:.-]+$", options: .regularExpression) { names.append(String(match[name])) }
        }
        for name in names {
            let cf = CFStringConvertIANACharSetNameToEncoding(name as CFString)
            guard cf != kCFStringEncodingInvalidId else { continue }
            let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cf))
            if String(data: data, encoding: encoding) != nil { return encoding }
        }
        return String(data: data, encoding: .utf8) != nil ? .utf8 : .isoLatin1
    }

    // MARK: 書き換え

    /// 保存したファイルへのリンクは相対パスに、保存しなかった相対リンクは元の絶対 URL にする
    private func rewrite(_ document: Entry) -> Bool {
        let file = root.appendingPathComponent(document.path)
        guard let data = try? Data(contentsOf: file), let text = String(data: data, encoding: document.encoding) else { return false }
        let links: [FoundLink]
        var replacements: [(NSRange, String)] = []
        if document.kind == .html {
            let found = SiteLinks.html(text, documentURL: document.url)
            links = found.links
            replacements = found.removals.map { ($0.range, "") }
        } else {
            links = SiteLinks.css(text, documentURL: document.url)
        }
        for link in links {
            let fragment = link.fragment.map { "#" + $0 } ?? ""
            var value: String
            if let target = entries[Crawler.key(link.url)] {
                value = RelativePath.link(from: document.path, to: target.path) + fragment
            } else if !SiteLinks.isAbsolute(link.raw), existsLocally(link.raw, from: document.path) {
                // 続きから取り込んだときの、書き換え済みの相対リンク（保存したファイルを指している）
                continue
            } else if !SiteLinks.isAbsolute(link.raw) {
                value = link.url.absoluteString + fragment
            } else {
                continue
            }
            if link.context == .html {
                value = value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "\"", with: "&quot;")
            }
            replacements.append((link.range, value))
        }
        guard !replacements.isEmpty else { return true }
        guard let output = SiteLinks.apply(replacements, to: text).data(using: document.encoding) else { return false }
        return (try? output.write(to: file, options: .atomic)) != nil
    }
}

/// Basic・Digest 認証に、ログインの画面で入れた名前とパスワードで答える（1回失敗したら答えない）
final class AuthDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let credential: URLCredential?
    init(credential: URLCredential?) { self.credential = credential }
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge) async
        -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let methods = [NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest]
        guard let credential, methods.contains(challenge.protectionSpace.authenticationMethod),
              challenge.previousFailureCount == 0 else { return (.performDefaultHandling, nil) }
        return (.useCredential, credential)
    }
}

/// robots.txt の User-agent: * と SiteMirror の Disallow・Allow（長く一致した方を使う）
struct Robots: Sendable {
    private var rules: [(allow: Bool, pattern: String)] = []
    /// Sitemap: に書かれた URL（User-agent に関係なく読む）
    private(set) var sitemaps: [String] = []

    static func load(for site: URL, session: URLSession) async -> Robots? {
        guard var components = URLComponents(url: site, resolvingAgainstBaseURL: false) else { return nil }
        components.path = "/robots.txt"
        components.query = nil
        components.fragment = nil
        guard let url = components.url,
              let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return Robots(String(decoding: data, as: UTF8.self))
    }

    init(_ text: String) {
        var applies = false
        var lastWasAgent = false
        for line in text.split(whereSeparator: \.isNewline) {
            let content = line.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
            let pair = content.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard pair.count == 2 else { continue }
            switch pair[0].lowercased() {
            case "sitemap":
                sitemaps.append(pair[1]); lastWasAgent = false
            case "user-agent":
                let agent = pair[1].lowercased()
                let matches = agent == "*" || agent.contains("sitemirror")
                applies = lastWasAgent ? (applies || matches) : matches
                lastWasAgent = true
            case "disallow" where applies && !pair[1].isEmpty:
                rules.append((false, pair[1])); lastWasAgent = false
            case "allow" where applies:
                rules.append((true, pair[1])); lastWasAgent = false
            default:
                lastWasAgent = false
            }
        }
    }

    func allows(_ url: URL) -> Bool {
        var target = url.path.isEmpty ? "/" : url.path
        if let query = url.query { target += "?" + query }
        var best: (allow: Bool, length: Int)?
        for rule in rules where Robots.matches(rule.pattern, target) {
            if best == nil || rule.pattern.count > best!.length || (rule.pattern.count == best!.length && rule.allow) {
                best = (rule.allow, rule.pattern.count)
            }
        }
        return best?.allow ?? true
    }

    /// * は任意の文字列、末尾の $ は終わり
    private static func matches(_ pattern: String, _ path: String) -> Bool {
        var regex = NSRegularExpression.escapedPattern(for: pattern).replacingOccurrences(of: "\\*", with: ".*")
        if regex.hasSuffix("\\$") { regex = String(regex.dropLast(2)) + "$" }
        return path.range(of: "^" + regex, options: .regularExpression) != nil
    }
}
