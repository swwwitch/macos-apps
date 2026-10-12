import Foundation

/// Pure text rules ported from the Keyboard Maestro macros (「Make Link（エンジン）」 and the copy macros).
/// No AppKit here so Tests/Rules can run them directly.
enum LinkRules {
    // MARK: Title

    /// Titles that mean "no page" (the engine cancelled on these).
    static let emptyPageTitles = ["スタートページ", "新しいタブ", "新規タブ", "Start Page", "New Tab", "Favorites", "お気に入り"]

    static func isEmptyPage(title: String, url: String) -> Bool {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.isEmpty || url.hasPrefix("about:") || url.hasPrefix("chrome://newtab") || url.hasPrefix("edge://newtab") || url.hasPrefix("favorites://") { return true }
        return emptyPageTitles.contains(t) || t.contains("新しいタブ") || t.contains("新規タブ")
    }

    /// Window-title suffixes added by browsers (only used when the page title itself could not be read).
    private static let browserSuffix = try! NSRegularExpression(
        pattern: #"\s+[-—–]\s+(Google Chrome|Microsoft Edge|Brave|Vivaldi|Mozilla Firefox|Firefox|Arc|ChatGPT Atlas|Original profile)(\s+[-—–]\s+.*)?$"#)
    private static let unreadCount = try! NSRegularExpression(pattern: #"^\(\d+\)\s"#)

    /// 「タイトル冒頭の(番号)を削除」 plus the Chrome/Firefox window suffixes the engine removed.
    static func cleanTitle(_ raw: String) -> String {
        var title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        title = replace(browserSuffix, in: title, with: "")
        title = replace(unreadCount, in: title, with: "")
        title = title.replacingOccurrences(of: " — Original profile", with: "")
        return title.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: URL

    /// ASIN in /dp/, /product/ or /ASIN/ (10 characters, case-insensitive like the macro).
    private static let asinPattern = try! NSRegularExpression(pattern: #"/(?:dp|gp/product|product|ASIN)/([A-Z0-9]{10})"#, options: .caseInsensitive)

    static func amazonASIN(_ url: String) -> String? {
        guard isAmazon(url), let match = asinPattern.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
              let range = Range(match.range(at: 1), in: url) else { return nil }
        return String(url[range]).uppercased()
    }
    static func isAmazon(_ url: String) -> Bool {
        guard let host = URLComponents(string: url)?.host?.lowercased() else { return false }
        return host == "amazon.co.jp" || host.hasSuffix(".amazon.co.jp") || host == "amzn.asia"
    }
    /// Short product link; with an associate ID, the macro's affiliate form (ID without "-22" is completed).
    static func amazonLink(asin: String, associateID: String) -> String {
        var id = associateID.trimmingCharacters(in: .whitespacesAndNewlines)
        if id.isEmpty { return "https://www.amazon.co.jp/dp/\(asin)" }
        if id.lowercased().hasSuffix("-22") { id = String(id.dropLast(3)) }
        return "https://www.amazon.co.jp/exec/obidos/ASIN/\(asin)/\(id)-22/ref=nosim"
    }

    /// Query parameters removed from every URL.
    static let trackingParameters: Set<String> = ["fbclid", "gclid", "coliid", "igshid", "mc_cid", "mc_eid", "yclid", "msclkid"]
    /// Hosts whose query carries the page itself (search results, videos); only tracking parameters are removed there.
    static let queryHosts = ["google.com", "google.co.jp", "youtube.com", "youtu.be"]

    /// The engine's 「URL整形」: Amazon → short /dp/ link; tracking parameters removed; with `simplify`,
    /// the whole query is dropped except on search/video hosts or when it carries an `id` parameter; trailing index.html removed.
    static func cleanURL(_ raw: String, simplify: Bool) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let asin = amazonASIN(trimmed) { return "https://www.amazon.co.jp/dp/\(asin)" }
        guard var parts = URLComponents(string: trimmed), let scheme = parts.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return trimmed }
        let host = parts.host?.lowercased() ?? ""
        if var items = parts.queryItems {
            items.removeAll { trackingParameters.contains($0.name.lowercased()) || $0.name.lowercased().hasPrefix("utm_") }
            let keepsQuery = queryHosts.contains { host == $0 || host.hasSuffix("." + $0) } || items.contains { $0.name.lowercased() == "id" }
            if simplify && !keepsQuery { items = [] }
            parts.queryItems = items.isEmpty ? nil : items
        }
        if parts.path.hasSuffix("/index.html") { parts.path.removeLast("index.html".count) }
        return parts.string ?? trimmed
    }

    // MARK: Formats

    enum Format: String, CaseIterable { case url, titleLine, titleSpace, markdown, html }

    static func format(_ format: Format, title: String, url: String) -> String {
        switch format {
        case .url: return url
        case .titleLine: return title + "\n" + url
        case .titleSpace: return title + " " + url
        case .markdown: return "- [" + markdownEscaped(title) + "](" + url.replacingOccurrences(of: ")", with: "%29") + ")"
        case .html: return "<a href=\"" + htmlEscaped(url) + "\">" + htmlEscaped(title) + "</a>"
        }
    }
    static func markdownEscaped(_ s: String) -> String { s.replacingOccurrences(of: "[", with: "\\[").replacingOccurrences(of: "]", with: "\\]") }
    static func htmlEscaped(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// 「開いているすべてのタブ」: one entry per tab, new-tab pages skipped.
    enum TabListFormat: String { case urls, titled, markdown }
    static func tabList(_ tabs: [(title: String, url: String)], format: TabListFormat) -> String {
        let pages = tabs.filter { !isEmptyPage(title: $0.title, url: $0.url) }
        switch format {
        case .urls: return pages.map(\.url).joined(separator: "\n")
        case .titled: return pages.map { $0.title + "\n" + $0.url }.joined(separator: "\n\n")
        case .markdown: return pages.map { Self.format(.markdown, title: $0.title, url: $0.url) }.joined(separator: "\n")
        }
    }

    // MARK: Edit mode (note / Tally / Doorkeeper)

    enum EditTarget: Equatable { case url(String), alreadyEditing, unsupported }

    static func editURL(for url: String) -> EditTarget {
        if url.contains("editor.note.com") { return .alreadyEditing }
        if let groups = captures(#"^https://note\.com/[^/]+/n/([^/?#]+)"#, in: url) { return .url("https://editor.note.com/notes/\(groups[0])/edit/") }
        if url.range(of: #"tally\.so/forms/[A-Za-z0-9]+/edit/?$"#, options: .regularExpression) != nil { return .alreadyEditing }
        if let groups = captures(#"^(https://tally\.so/forms/[A-Za-z0-9]+)(?:/|$)"#, in: url) { return .url(groups[0] + "/edit") }
        if url.contains("manage.doorkeeper.jp") { return .alreadyEditing }
        if let groups = captures(#"^https://([A-Za-z0-9-]+)\.doorkeeper\.jp(/events/[0-9]+)"#, in: url), groups[0] != "www" {
            return .url("https://manage.doorkeeper.jp/groups/\(groups[0])\(groups[1])/edit")
        }
        return .unsupported
    }

    // MARK: Other

    /// URLs in free text (「URLを開く（クリップボードから）」), without a trailing ")" like the macro's regex.
    static func extractURLs(_ text: String) -> [String] {
        let pattern = try! NSRegularExpression(pattern: #"https?://[\w!?/+\-_~=;.,*&@#$%()'\[\]]+(?<![).,])"#)
        var seen = Set<String>()
        return pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { Range($0.range, in: text).map { String(text[$0]) } }
            .filter { seen.insert($0).inserted }
    }

    /// Lines to search (「選択したテキストを別タブで個別に検索」): leading "- " and "・" removed, blank lines skipped.
    static func searchTerms(_ text: String) -> [String] {
        text.components(separatedBy: .newlines).map { line -> String in
            var s = line.trimmingCharacters(in: .whitespaces)
            if s.hasPrefix("- ") { s.removeFirst(2) } else if s.hasPrefix("・") { s.removeFirst() }
            return s.trimmingCharacters(in: .whitespaces)
        }.filter { !$0.isEmpty }
    }
    static func searchURL(_ term: String) -> String {
        "https://www.google.com/search?q=" + (term.addingPercentEncoding(withAllowedCharacters: queryAllowed) ?? term)
    }
    static func translateURL(_ url: String, target: String) -> String {
        "https://translate.google.com/translate?sl=auto&tl=\(target)&u=" + (url.addingPercentEncoding(withAllowedCharacters: queryAllowed) ?? url)
    }
    private static let queryAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics; set.insert(charactersIn: "-._~"); return set
    }()

    // MARK: Selected text (「Make Link (misc)」)

    /// 「Jina整形」: each URL as https://r.jina.ai/<URL> (a page AI tools can read), one per line.
    static func jinaLines(_ urls: [String]) -> String { urls.map { "https://r.jina.ai/" + $0 }.joined(separator: "\n") }
    /// 「選択した文字列を物書堂で検索」.
    static func dictionaryURL(_ text: String) -> String {
        "mkdictionaries:///?text=" + (text.trimmingCharacters(in: .whitespacesAndNewlines).addingPercentEncoding(withAllowedCharacters: queryAllowed) ?? text)
    }
    /// 「URLを抜き出し、テキストファイルとして書き出す」: url-yyyyMMdd-HHmmss.txt, one URL per line.
    static func urlListFileName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "url-" + formatter.string(from: date)
    }
    static func urlList(_ urls: [String]) -> String { urls.joined(separator: "\n") + "\n" }
    /// Suggested webloc name for a URL typed into the name prompt: the host without "www.".
    static func suggestedName(for url: String) -> String {
        var host = URLComponents(string: url)?.host ?? "link"
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return host
    }
    /// Web addresses in a file's 「ダウンロード元」 (kMDItemWhereFroms: the file's URL, then the page it came from).
    static func webSources(_ whereFroms: [String]) -> [String] {
        var seen = Set<String>()
        return whereFroms.filter { ($0.hasPrefix("http://") || $0.hasPrefix("https://")) && seen.insert($0).inserted }
    }

    /// A file name from the page title: "/" and ":" are not allowed in Finder names; length capped.
    static func fileName(_ title: String, fallback: String) -> String {
        var name = title.replacingOccurrences(of: "/", with: "").replacingOccurrences(of: ":", with: "")
            .components(separatedBy: .controlCharacters).joined().trimmingCharacters(in: .whitespacesAndNewlines)
        while name.hasPrefix(".") { name.removeFirst() }
        if name.isEmpty { name = fallback }
        return String(name.prefix(120))
    }

    // MARK: Helpers

    private static func replace(_ regex: NSRegularExpression, in s: String, with template: String) -> String {
        regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: template)
    }
    private static func captures(_ pattern: String, in s: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        return (1..<match.numberOfRanges).map { Range(match.range(at: $0), in: s).map { String(s[$0]) } ?? "" }
    }
}
