import Foundation
import UniformTypeIdentifiers

/// 取り込みの設定。UserDefaults から作る（Mirror.options）
struct MirrorOptions: Sendable {
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
    var saved = 0
    var failed = 0
    var rewritten = 0
    var cancelled = false
    var limitReached = false
    var robotsBlocked = 0
    /// 開始ページを保存したファイル
    var startPage: URL?
    var root: URL
}

/// 1回の取り込み。1つの Task の中だけで使う（取得だけを子タスクに出す）
final class Crawler {
    private struct Job {
        let url: URL
        let depth: Int
        let role: FoundLink.Role
    }
    private enum Kind { case html, css, other }
    private struct Entry {
        let path: String
        let url: URL
        let kind: Kind
        let encoding: String.Encoding
    }
    private struct Fetched: Sendable {
        var finalURL: URL?
        var status = 0
        var mime: String?
        var charset: String?
        var data: Data?
        var error: String?
    }

    private let start: URL
    private let root: URL
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

    init(start: URL, root: URL, options: MirrorOptions, emit: @escaping @Sendable (MirrorEvent) -> Void) {
        self.start = start
        self.root = root
        self.options = options
        self.emit = emit
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpMaximumConnectionsPerHost = max(1, options.connections)
        configuration.timeoutIntervalForRequest = 30
        configuration.httpAdditionalHeaders = ["User-Agent": Crawler.userAgent]
        session = URLSession(configuration: configuration)
        siteHosts = [Crawler.siteKey(start.host ?? "")]
        startFolder = Crawler.folder(of: start)
        summary = MirrorSummary(root: root)
    }

    static let userAgent: String = {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) SiteMirror/\(version)"
    }()

    func run() async -> MirrorSummary {
        defer { session.invalidateAndCancel() }
        if options.obeyRobots { robots = await Robots.load(for: start, session: session) }
        enqueue(start, depth: 0, role: .page, force: true)
        await withTaskGroup(of: (Job, Fetched).self) { group in
            var running = 0
            while !Task.isCancelled {
                while running < max(1, options.connections), head < queue.count {
                    let job = queue[head]
                    head += 1
                    let session = self.session
                    group.addTask { (job, await Crawler.fetch(job.url, session: session)) }
                    running += 1
                }
                guard running > 0, let (job, fetched) = await group.next() else { break }
                running -= 1
                handle(job, fetched)
                emit(.counts(saved: summary.saved, failed: summary.failed, waiting: queue.count - head + running))
            }
            group.cancelAll()
        }
        summary.cancelled = Task.isCancelled
        // 中止しても、保存したところまではリンクを書き換えて開けるようにする
        emit(.rewriting(total: documents.count))
        for document in documents { if rewrite(document) { summary.rewritten += 1 } }
        if let entry = entries[Crawler.key(start)] { summary.startPage = root.appendingPathComponent(entry.path) }
        return summary
    }

    // MARK: 取得

    private static func fetch(_ url: URL, session: URLSession) async -> Fetched {
        do {
            let (data, response) = try await session.data(from: url)
            let http = response as? HTTPURLResponse
            return Fetched(finalURL: response.url ?? url, status: http?.statusCode ?? 200,
                           mime: response.mimeType?.lowercased(), charset: response.textEncodingName, data: data)
        } catch {
            return Fetched(error: (error as? URLError)?.code == .cancelled ? nil : error.localizedDescription)
        }
    }

    private func handle(_ job: Job, _ fetched: Fetched) {
        let address = job.url.absoluteString
        guard let data = fetched.data, let finalURL = fetched.finalURL else {
            if let error = fetched.error { fail(address, error) }
            return
        }
        guard (200..<400).contains(fetched.status) else {
            fail(address, "HTTP \(fetched.status)")
            return
        }
        // 開始ページが転送されたら、転送先のホストもサイトとして扱う（http→https・www の有無など）
        if job.url == start, let host = finalURL.host { siteHosts.insert(Crawler.siteKey(host)); startFolder = Crawler.folder(of: finalURL) }
        if let existing = entries[Crawler.key(finalURL)] {
            entries[Crawler.key(job.url)] = existing
            return
        }
        if job.role == .page, !inPageScope(finalURL) {
            emit(.skipped(url: address, reason: L("サイトの外へ転送")))
            return
        }
        let kind: Kind
        switch fetched.mime {
        case "text/html", "application/xhtml+xml": kind = .html
        case "text/css": kind = .css
        default: kind = finalURL.pathExtension.lowercased() == "css" ? .css : .other
        }
        let path = localPath(for: finalURL, kind: kind, mime: fetched.mime)
        let file = root.appendingPathComponent(path)
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
        } catch {
            fail(address, error.localizedDescription)
            return
        }
        let encoding = kind == .other ? .utf8 : Crawler.encoding(of: data, header: fetched.charset, html: kind == .html)
        let entry = Entry(path: path, url: finalURL, kind: kind, encoding: encoding)
        entries[Crawler.key(job.url)] = entry
        entries[Crawler.key(finalURL)] = entry
        summary.saved += 1
        emit(.saved(url: address, path: path))

        guard kind != .other, let text = String(data: data, encoding: encoding) else { return }
        documents.append(entry)
        if kind == .html {
            // 素材として取った HTML（link rel=preload など）からはたどらない
            guard job.role == .page else { return }
            for link in SiteLinks.html(text, documentURL: finalURL).links {
                if link.role == .page {
                    if options.maxDepth == 0 || job.depth < options.maxDepth { enqueue(link.url, depth: job.depth + 1, role: .page) }
                } else {
                    enqueue(link.url, depth: job.depth, role: .asset)
                }
            }
        } else {
            for link in SiteLinks.css(text, documentURL: finalURL) { enqueue(link.url, depth: job.depth, role: .asset) }
        }
    }

    private func fail(_ address: String, _ reason: String) {
        summary.failed += 1
        emit(.failed(url: address, reason: reason))
    }

    private func enqueue(_ url: URL, depth: Int, role: FoundLink.Role, force: Bool = false) {
        let key = Crawler.key(url)
        guard !seen.contains(key) else { return }
        if !force {
            switch role {
            case .page: guard inPageScope(url) else { return }
            case .asset: guard options.externalAssets || inSite(url) else { return }
            }
        }
        if role == .page, let robots, inSite(url), !robots.allows(url) {
            seen.insert(key)
            summary.robotsBlocked += 1
            emit(.skipped(url: url.absoluteString, reason: L("robots.txtで除外")))
            return
        }
        if options.maxFiles > 0, seen.count >= options.maxFiles {
            summary.limitReached = true
            return
        }
        seen.insert(key)
        queue.append(Job(url: url, depth: depth, role: role))
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
        usedPaths.insert(path.lowercased())
        var prefix = ""
        for part in parts {
            prefix = prefix.isEmpty ? part : prefix + "/" + part
            usedFolders.insert(prefix.lowercased())
        }
        return path
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

/// robots.txt の User-agent: * と SiteMirror の Disallow・Allow（長く一致した方を使う）
struct Robots: Sendable {
    private var rules: [(allow: Bool, pattern: String)] = []

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
