import Foundation

/// HTML・CSS の中の URL 1つ。位置は文書の生の文字列（UTF-16）での範囲で持ち、書き換えはこの範囲を置き換える
struct FoundLink {
    enum Role {
        /// たどるページ（a・iframe など）
        case page
        /// ページの表示に必要なファイル（img・script・CSS など）
        case asset
    }
    enum Context {
        /// HTML の属性値（& を &amp; にして書く）
        case html
        /// CSS の url()・@import
        case css
    }
    let range: NSRange
    /// 書かれていたままの値（文字参照は解いたもの）
    let raw: String
    /// 解決した URL（# 以降を除く）
    let url: URL
    let fragment: String?
    let role: Role
    let context: Context
}

/// 書き換えで消す範囲（<base> と、書き換えたファイルでは合わなくなる integrity・crossorigin）
struct Removal {
    let range: NSRange
}

enum SiteLinks {
    // MARK: HTML

    private static let comment = try! NSRegularExpression(pattern: "<!--[\\s\\S]*?-->")
    /// script・style の中身。script は飛ばし、style は CSS として読む
    private static let rawText = try! NSRegularExpression(
        pattern: "<(script|style)\\b[^>]*>([\\s\\S]*?)</\\1\\s*>", options: .caseInsensitive)
    private static let tag = try! NSRegularExpression(
        pattern: "<([a-zA-Z][a-zA-Z0-9:-]*)((?:\\s+[^\\s\"'>/=]+(?:\\s*=\\s*(?:\"[^\"]*\"|'[^']*'|[^\\s\"'>]+))?)*)\\s*/?>")
    private static let attribute = try! NSRegularExpression(
        pattern: "(\\s+)([^\\s\"'>/=]+)(?:\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s\"'>]+)))?")

    /// HTML の中のリンクと、書き換えのときに消す範囲
    static func html(_ text: String, documentURL: URL) -> (links: [FoundLink], removals: [Removal]) {
        let ns = text as NSString
        let all = NSRange(location: 0, length: ns.length)
        var skipped: [NSRange] = comment.matches(in: text, range: all).map(\.range)
        var styles: [NSRange] = []
        for match in rawText.matches(in: text, range: all) where !inside(match.range.location, skipped) {
            let body = match.range(at: 2)
            skipped.append(body)
            if ns.substring(with: match.range(at: 1)).lowercased() == "style" { styles.append(body) }
        }
        let tags = tag.matches(in: text, range: all).filter { !inside($0.range.location, skipped) }

        // <base href> は、ほかのリンクを解決する前に読む
        var base = documentURL
        var removals: [Removal] = []
        for match in tags where ns.substring(with: match.range(at: 1)).lowercased() == "base" {
            for attr in attributes(ns, match.range(at: 2)) where attr.name == "href" {
                if let url = resolve(attr.value, documentURL) { base = url }
            }
            removals.append(Removal(range: match.range))
        }

        var links: [FoundLink] = []
        for match in tags {
            let name = ns.substring(with: match.range(at: 1)).lowercased()
            guard name != "base" else { continue }
            let attrs = attributes(ns, match.range(at: 2))
            let rel = attrs.first { $0.name == "rel" }.map { decode($0.value).lowercased() } ?? ""
            for attr in attrs {
                if attr.name == "style" {
                    links += css(ns, range: attr.valueRange, base: base)
                    continue
                }
                if (attr.name == "integrity" || attr.name == "crossorigin"), ["link", "script", "img", "source", "video", "audio"].contains(name) {
                    removals.append(Removal(range: attr.wholeRange))
                    continue
                }
                if name == "meta", attr.name == "content" {
                    let equiv = attrs.first { $0.name == "http-equiv" }.map { decode($0.value).lowercased() }
                    if equiv == "refresh" { links += refresh(ns, attr.valueRange, base) }
                    continue
                }
                guard let role = role(tag: name, attribute: attr.name, rel: rel) else { continue }
                if attr.name.hasSuffix("srcset") {
                    links += srcset(ns, attr.valueRange, base)
                } else if let link = link(ns, attr.valueRange, base, role, .html) {
                    links.append(link)
                }
            }
        }
        for range in styles { links += css(ns, range: range, base: base) }
        return (links, removals)
    }

    /// タグと属性から、たどるページか表示に必要なファイルかを決める。対象外は nil
    static func role(tag: String, attribute: String, rel: String) -> FoundLink.Role? {
        switch (tag, attribute) {
        case ("a", "href"), ("area", "href"), ("iframe", "src"), ("frame", "src"):
            return .page
        case ("link", "href"):
            let assetRels = ["stylesheet", "icon", "apple-touch-icon", "apple-touch-icon-precomposed", "mask-icon",
                             "preload", "modulepreload", "prefetch", "manifest", "image_src"]
            let words = rel.split(whereSeparator: \.isWhitespace).map(String.init)
            if words.contains(where: assetRels.contains) { return .asset }
            return words.contains(where: ["next", "prev", "alternate"].contains) ? .page : nil
        case ("img", "src"), ("img", "srcset"), ("img", "data-src"), ("img", "data-srcset"),
             ("source", "src"), ("source", "srcset"), ("source", "data-srcset"),
             ("script", "src"), ("video", "src"), ("video", "poster"), ("audio", "src"), ("track", "src"),
             ("embed", "src"), ("object", "data"), ("input", "src"),
             ("body", "background"), ("table", "background"), ("td", "background"), ("th", "background"),
             ("image", "href"), ("image", "xlink:href"), ("use", "href"), ("use", "xlink:href"):
            return .asset
        default:
            return nil
        }
    }

    private struct Attribute {
        let name: String
        let value: String
        let valueRange: NSRange
        /// 前の空白から値の終わりまで（属性ごと消すとき）
        let wholeRange: NSRange
    }

    private static func attributes(_ ns: NSString, _ range: NSRange) -> [Attribute] {
        guard range.location != NSNotFound, range.length > 0 else { return [] }
        return attribute.matches(in: ns as String, range: range).compactMap { match in
            let name = ns.substring(with: match.range(at: 2)).lowercased()
            guard let valueRange = [3, 4, 5].map({ match.range(at: $0) }).first(where: { $0.location != NSNotFound }) else {
                return Attribute(name: name, value: "", valueRange: NSRange(location: NSNotFound, length: 0), wholeRange: match.range)
            }
            return Attribute(name: name, value: ns.substring(with: valueRange), valueRange: valueRange, wholeRange: match.range)
        }
    }

    /// srcset は「URL 記述子」をカンマで区切ったもの。URL ごとに範囲を出す
    private static func srcset(_ ns: NSString, _ range: NSRange, _ base: URL) -> [FoundLink] {
        guard range.location != NSNotFound else { return [] }
        var links: [FoundLink] = []
        let end = range.location + range.length
        var i = range.location
        func isSpace(_ c: unichar) -> Bool { c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0x0C }
        while i < end {
            while i < end, isSpace(ns.character(at: i)) || ns.character(at: i) == 0x2C { i += 1 }
            let start = i
            while i < end, !isSpace(ns.character(at: i)) { i += 1 }
            var urlEnd = i
            while urlEnd > start, ns.character(at: urlEnd - 1) == 0x2C { urlEnd -= 1 }
            if urlEnd > start, let found = link(ns, NSRange(location: start, length: urlEnd - start), base, .asset, .html) {
                links.append(found)
            }
            // 記述子（1x・300w）を次のカンマまで飛ばす
            if urlEnd == i { while i < end, ns.character(at: i) != 0x2C { i += 1 } }
        }
        return links
    }

    /// <meta http-equiv="refresh" content="0; url=…">
    private static func refresh(_ ns: NSString, _ range: NSRange, _ base: URL) -> [FoundLink] {
        guard range.location != NSNotFound else { return [] }
        let value = ns.substring(with: range) as NSString
        let found = value.range(of: "url\\s*=\\s*['\"]?", options: [.regularExpression, .caseInsensitive])
        guard found.location != NSNotFound else { return [] }
        var length = value.length - (found.location + found.length)
        let rest = value.substring(from: found.location + found.length)
        if let quote = rest.firstIndex(where: { $0 == "'" || $0 == "\"" }) {
            length = (rest[..<quote] as Substring).utf16.count
        }
        let urlRange = NSRange(location: range.location + found.location + found.length, length: length)
        return link(ns, urlRange, base, .page, .html).map { [$0] } ?? []
    }

    // MARK: CSS

    private static let cssURL = try! NSRegularExpression(
        pattern: "url\\(\\s*(?:\"([^\"]*)\"|'([^']*)'|&quot;((?:(?!&quot;)[^)])*)&quot;|([^)'\"\\s]*))\\s*\\)", options: .caseInsensitive)
    private static let cssImport = try! NSRegularExpression(
        pattern: "@import\\s+(?:\"([^\"]*)\"|'([^']*)')", options: .caseInsensitive)

    /// CSS（ファイル・<style>・style 属性）の url() と @import。すべて表示に必要なファイル
    static func css(_ ns: NSString, range: NSRange, base: URL) -> [FoundLink] {
        guard range.location != NSNotFound, range.length > 0 else { return [] }
        var links: [FoundLink] = []
        for regex in [cssURL, cssImport] {
            for match in regex.matches(in: ns as String, range: range) {
                guard let value = (1..<match.numberOfRanges).map({ match.range(at: $0) }).first(where: { $0.location != NSNotFound }),
                      let found = link(ns, value, base, .asset, .css) else { continue }
                links.append(found)
            }
        }
        return links
    }

    static func css(_ text: String, documentURL: URL) -> [FoundLink] {
        let ns = text as NSString
        return css(ns, range: NSRange(location: 0, length: ns.length), base: documentURL)
    }

    // MARK: JavaScript・サイトマップ

    /// 引用符で囲まれた、拡張子でファイルとわかる URL（絶対 URL・// で始まるもの・/ で始まるもの）。推測なので相対パスは拾わない
    private static let scriptURL = try! NSRegularExpression(
        pattern: "[\"'`]((?:https?:)?//[^\"'`\\s<>]+?|/[^/\"'`\\s<>][^\"'`\\s<>]*?)\\.(png|jpe?g|gif|svg|webp|avif|ico|css|js|mjs|json|woff2?|ttf|otf|eot|mp4|webm|mp3|m4a|ogg|pdf)((?:\\?|#)[^\"'`\\s<>]*)?[\"'`]",
        options: .caseInsensitive)

    static func scriptURLs(_ text: String, base: URL) -> [URL] {
        let ns = text as NSString
        var urls: [URL] = []
        for match in scriptURL.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            // 引用符を除いた中身
            let inner = NSRange(location: match.range.location + 1, length: match.range.length - 2)
            let value = ns.substring(with: inner).replacingOccurrences(of: "\\/", with: "/")
            guard let url = resolve(value, base), var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { continue }
            components.fragment = nil
            if let url = components.url { urls.append(url) }
        }
        return urls
    }

    private static let loc = try! NSRegularExpression(pattern: "<loc>\\s*([^<\\s]+)\\s*</loc>", options: .caseInsensitive)

    /// sitemap.xml の <loc>
    static func sitemapLocations(_ xml: String) -> [URL] {
        let ns = xml as NSString
        return loc.matches(in: xml, range: NSRange(location: 0, length: ns.length)).compactMap {
            URL(string: decode(ns.substring(with: $0.range(at: 1))))
        }
    }

    // MARK: 共通

    private static func link(_ ns: NSString, _ range: NSRange, _ base: URL, _ role: FoundLink.Role, _ context: FoundLink.Context) -> FoundLink? {
        guard range.location != NSNotFound, range.length > 0 else { return nil }
        let raw = decode(ns.substring(with: range)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, !raw.hasPrefix("#"), let resolved = resolve(raw, base),
              var components = URLComponents(url: resolved, resolvingAgainstBaseURL: false) else { return nil }
        let fragment = components.fragment
        components.fragment = nil
        guard let url = components.url else { return nil }
        return FoundLink(range: range, raw: raw, url: url, fragment: fragment, role: role, context: context)
    }

    /// http・https の絶対 URL に解決する。mailto: javascript: data: などは nil
    static func resolve(_ value: String, _ base: URL) -> URL? {
        let trimmed = decode(value).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed, relativeTo: base)?.absoluteURL,
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https", url.host != nil else { return nil }
        return url
    }

    /// 書かれていた値が絶対 URL（//host/ を含む）か。相対のまま保存されなかったリンクは絶対 URL に直す
    static func isAbsolute(_ raw: String) -> Bool {
        raw.hasPrefix("//") || raw.range(of: "^[a-zA-Z][a-zA-Z0-9+.-]*:", options: .regularExpression) != nil
    }

    private static func inside(_ location: Int, _ ranges: [NSRange]) -> Bool {
        ranges.contains { NSLocationInRange(location, $0) }
    }

    /// 属性値の文字参照を解く（URL に出てくるものだけ）
    static func decode(_ value: String) -> String {
        guard value.contains("&") else { return value }
        var result = value
        for (entity, char) in [("&amp;", "&"), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&#x2F;", "/"), ("&#47;", "/")] {
            result = result.replacingOccurrences(of: entity, with: char, options: .caseInsensitive)
        }
        let numeric = try! NSRegularExpression(pattern: "&#(x?)([0-9a-fA-F]+);")
        let ns = result as NSString
        for match in numeric.matches(in: result, range: NSRange(location: 0, length: ns.length)).reversed() {
            let hex = ns.substring(with: match.range(at: 1)) == "x"
            guard let code = UInt32(ns.substring(with: match.range(at: 2)), radix: hex ? 16 : 10),
                  let scalar = Unicode.Scalar(code) else { continue }
            result = (result as NSString).replacingCharacters(in: match.range, with: String(Character(scalar)))
        }
        return result
    }

    /// 置き換えを後ろから当てる（範囲がずれないように）。重なる範囲は先に見つけた方を使う
    static func apply(_ replacements: [(NSRange, String)], to text: String) -> String {
        let result = NSMutableString(string: text)
        var lastStart = Int.max
        for (range, value) in replacements.sorted(by: { $0.0.location > $1.0.location }) where NSMaxRange(range) <= lastStart {
            result.replaceCharacters(in: range, with: value)
            lastStart = range.location
        }
        return result as String
    }
}

/// 保存先の相対パスどうしの相対リンク（ファイル名は百分率符号化）
enum RelativePath {
    private static let allowed: CharacterSet = {
        var set = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        set.insert(charactersIn: "!$+,;=@")
        return set
    }()

    static func link(from document: String, to target: String) -> String {
        var from = document.split(separator: "/").map(String.init)
        from.removeLast()
        let to = target.split(separator: "/").map(String.init)
        var common = 0
        while common < from.count, common < to.count - 1, from[common] == to[common] { common += 1 }
        let up = Array(repeating: "..", count: from.count - common)
        let down = to[common...].map { $0.addingPercentEncoding(withAllowedCharacters: allowed) ?? $0 }
        return (up + down).joined(separator: "/")
    }
}
