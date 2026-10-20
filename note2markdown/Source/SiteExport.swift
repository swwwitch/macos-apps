import AppKit

/// サイトをエクスポート: every published article of the signed-in account to <folder>/<key>.md.
/// Images are either left as note URLs or downloaded to <folder>/images/<key>/ and linked relatively.
@MainActor
final class SiteExport: ObservableObject {
    static let shared = SiteExport()

    @Published var folderPath: String { didSet { defaults.set(folderPath, forKey: "siteExportFolder") } }
    /// Download images and link them relatively (off: keep the note URLs).
    @Published var downloadImages: Bool { didSet { defaults.set(downloadImages, forKey: "siteExportDownloadImages") } }
    @Published private(set) var isRunning = false
    @Published private(set) var done = 0
    @Published private(set) var total = 0
    @Published private(set) var failed: [String] = []
    @Published private(set) var message = ""

    private let defaults = UserDefaults.standard
    private var task: Task<Void, Never>?

    private init() {
        folderPath = defaults.string(forKey: "siteExportFolder") ?? ""
        downloadImages = defaults.bool(forKey: "siteExportDownloadImages")
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
        panel.prompt = L("chooseEditorPrompt")
        if !folderPath.isEmpty { panel.directoryURL = URL(fileURLWithPath: folderPath, isDirectory: true) }
        if panel.runModal() == .OK, let url = panel.url { folderPath = url.path }
    }

    func cancel() { task?.cancel() }

    func start(fetchEmbedTitles: Bool) {
        guard !isRunning else { return }
        guard !folderPath.isEmpty else { chooseFolder(); if folderPath.isEmpty { return } else { return start(fetchEmbedTitles: fetchEmbedTitles) } }
        let folder = URL(fileURLWithPath: folderPath, isDirectory: true)
        let withImages = downloadImages
        isRunning = true; done = 0; total = 0; failed = []; message = L("siteExportListing")
        task = Task {
            defer { isRunning = false }
            do {
                guard let cookie = await NoteLogin.shared.cookieHeader() else { message = L("signedOut"); return }
                let urlname = try await Self.currentUserName(cookie: cookie)
                let keys = try await Self.articleKeys(urlname: urlname, cookie: cookie)
                total = keys.count
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                for key in keys {
                    try Task.checkCancellation()
                    message = String(format: L("siteExportProgress"), done + 1, total)
                    do {
                        let article = try await NoteArticle.fetch(key: key, cookie: cookie)
                        var converter = makeConverter()
                        if fetchEmbedTitles { converter.embedTitles = await NoteArticle.titles(for: NoteMarkdown.noteEmbedURLs(in: article.body)) }
                        var markdown = converter.convert(title: article.title, html: article.body, keywords: article.keywords)
                        if withImages { markdown = await Self.localizeImages(markdown, key: key, folder: folder) }
                        try markdown.write(to: folder.appendingPathComponent(key + ".md"), atomically: true, encoding: .utf8)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch NoteArticle.Failure.noBody {
                        // Image or talk posts have no text body: nothing to export.
                    } catch {
                        failed.append(key)
                    }
                    done += 1
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
                message = String(format: L("siteExportDone"), done - failed.count, total) + (failed.isEmpty ? "" : " " + String(format: L("siteExportFailed"), failed.joined(separator: ", ")))
            } catch is CancellationError {
                message = String(format: L("siteExportCancelled"), done, total)
            } catch {
                message = L("siteExportError") + error.localizedDescription
            }
        }
    }

    // MARK: note API

    private static func json(_ url: URL, cookie: String) async throws -> [String: Any] {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpShouldHandleCookies = false
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200, let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NoteArticle.Failure.badResponse(status)
        }
        return object
    }

    /// The signed-in account's urlname (note.com/<urlname>).
    static func currentUserName(cookie: String) async throws -> String {
        let object = try await json(URL(string: "https://note.com/api/v2/current_user")!, cookie: cookie)
        let data = object["data"] as? [String: Any]
        guard let name = data?["urlname"] as? String ?? (data?["user"] as? [String: Any])?["urlname"] as? String, !name.isEmpty else {
            throw NoteArticle.Failure.forbidden
        }
        return name
    }

    /// Keys of all published text articles, newest first.
    static func articleKeys(urlname: String, cookie: String) async throws -> [String] {
        var keys: [String] = []
        var page = 1
        while true {
            try Task.checkCancellation()
            var components = URLComponents(string: "https://note.com/api/v2/creators/\(urlname)/contents")!
            components.queryItems = [URLQueryItem(name: "kind", value: "note"), URLQueryItem(name: "page", value: String(page))]
            let data = try await json(components.url!, cookie: cookie)["data"] as? [String: Any] ?? [:]
            let contents = data["contents"] as? [[String: Any]] ?? []
            for item in contents {
                guard let key = item["key"] as? String, !keys.contains(key) else { continue }
                if let type = item["type"] as? String, type != "TextNote" { continue }
                keys.append(key)
            }
            if contents.isEmpty || data["isLastPage"] as? Bool != false || page >= 500 { break }
            page += 1
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        return keys
    }

    // MARK: Images

    /// Downloads the images (![…](https://…)) to images/<key>/ and links them relatively. Failed downloads keep the URL.
    static func localizeImages(_ markdown: String, key: String, folder: URL) async -> String {
        let regex = try! NSRegularExpression(pattern: #"!\[[^\]\n]*\]\((https?://[^)\s]+)\)"#)
        let ns = markdown as NSString
        var urls: [String] = []
        for match in regex.matches(in: markdown, range: NSRange(location: 0, length: ns.length)) {
            let url = ns.substring(with: match.range(at: 1))
            if !urls.contains(url) { urls.append(url) }
        }
        guard !urls.isEmpty else { return markdown }
        let directory = folder.appendingPathComponent("images").appendingPathComponent(key)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var result = markdown
        var used: Set<String> = []
        for (index, address) in urls.enumerated() {
            guard let url = URL(string: address), let (data, response) = try? await URLSession.shared.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200 else { continue }
            var name = url.lastPathComponent
            if name.isEmpty || name == "/" || used.contains(name) {
                let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension
                name = String(format: "%03d.", index + 1) + ext
            }
            used.insert(name)
            guard (try? data.write(to: directory.appendingPathComponent(name))) != nil else { continue }
            result = result.replacingOccurrences(of: "](\(address))", with: "](images/\(key)/\(name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name))")
        }
        return result
    }
}
