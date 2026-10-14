import Foundation

/// A node of the parsed note body. Text nodes have an empty `name`.
final class HTMLNode {
    let name: String
    var attributes: [String: String]
    var children: [HTMLNode] = []
    var text: String
    init(name: String, attributes: [String: String] = [:], text: String = "") {
        self.name = name; self.attributes = attributes; self.text = text
    }
    var isText: Bool { name.isEmpty }
    /// All text inside, with <br> as a newline (for <pre> and captions).
    var rawText: String {
        if isText { return text }
        if name == "br" { return "\n" }
        return children.map(\.rawText).joined()
    }
    func first(_ tag: String) -> HTMLNode? {
        for child in children {
            if child.name == tag { return child }
            if let found = child.first(tag) { return found }
        }
        return nil
    }
}

/// A small HTML parser for the note body (well-formed except for void elements).
enum HTMLParser {
    static let voidElements: Set<String> = ["br", "img", "hr", "input", "meta", "link", "source", "wbr", "col", "area", "embed", "param", "track"]
    static let rawElements: Set<String> = ["script", "style"]

    static func parse(_ html: String) -> HTMLNode {
        let root = HTMLNode(name: "#root")
        var stack = [root]
        let chars = Array(html.unicodeScalars)
        var index = 0
        var textStart = 0
        func flushText(_ end: Int) {
            guard end > textStart else { return }
            var scalars = String.UnicodeScalarView(); scalars.append(contentsOf: chars[textStart..<end])
            stack.last!.children.append(HTMLNode(name: "", text: decodeEntities(String(scalars))))
        }
        func scalarString(_ range: Range<Int>) -> String {
            var scalars = String.UnicodeScalarView(); scalars.append(contentsOf: chars[range]); return String(scalars)
        }
        func find(_ needle: String, from start: Int) -> Int? {
            let target = Array(needle.unicodeScalars)
            var i = start
            while i + target.count <= chars.count {
                if chars[i..<(i + target.count)].elementsEqual(target) { return i }
                i += 1
            }
            return nil
        }
        while index < chars.count {
            guard chars[index] == "<", index + 1 < chars.count else { index += 1; continue }
            let next = chars[index + 1]
            if next == "!" {
                // Comment or doctype.
                flushText(index)
                if scalarString(index..<min(index + 4, chars.count)) == "<!--" {
                    index = (find("-->", from: index + 4).map { $0 + 3 }) ?? chars.count
                } else {
                    index = (find(">", from: index).map { $0 + 1 }) ?? chars.count
                }
                textStart = index
                continue
            }
            let isClose = next == "/"
            let nameStart = index + (isClose ? 2 : 1)
            guard nameStart < chars.count, chars[nameStart].properties.isAlphabetic else { index += 1; continue }
            // Find the end of the tag, honoring quoted attribute values.
            var end = nameStart
            var quote: Unicode.Scalar?
            while end < chars.count {
                let c = chars[end]
                if let q = quote { if c == q { quote = nil } } else if c == "\"" || c == "'" { quote = c } else if c == ">" { break }
                end += 1
            }
            guard end < chars.count else { break }
            flushText(index)
            let inside = scalarString(nameStart..<end)
            index = end + 1
            textStart = index
            let (name, attributes, selfClosing) = parseTag(inside)
            if isClose {
                if let position = stack.lastIndex(where: { $0.name == name }), position > 0 { stack.removeSubrange(position...) }
                continue
            }
            let node = HTMLNode(name: name, attributes: attributes)
            stack.last!.children.append(node)
            if rawElements.contains(name) {
                // Skip the contents of <script> and <style>.
                let close = find("</\(name)", from: index) ?? chars.count
                index = (find(">", from: close).map { $0 + 1 }) ?? chars.count
                textStart = index
            } else if !voidElements.contains(name) && !selfClosing {
                stack.append(node)
            }
        }
        flushText(chars.count)
        return root
    }

    private static func parseTag(_ inside: String) -> (String, [String: String], Bool) {
        var body = inside.trimmingCharacters(in: .whitespacesAndNewlines)
        let selfClosing = body.hasSuffix("/")
        if selfClosing { body.removeLast() }
        let nameEnd = body.firstIndex(where: { $0.isWhitespace || $0 == "/" }) ?? body.endIndex
        let name = body[..<nameEnd].lowercased()
        var attributes: [String: String] = [:]
        let pattern = #"([^\s=/>]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?"#
        let rest = String(body[nameEnd...])
        let regex = try! NSRegularExpression(pattern: pattern)
        let ns = rest as NSString
        for match in regex.matches(in: rest, range: NSRange(location: 0, length: ns.length)) {
            let key = ns.substring(with: match.range(at: 1)).lowercased()
            var value = ""
            for group in 2...4 where match.range(at: group).location != NSNotFound { value = ns.substring(with: match.range(at: group)) }
            attributes[key] = decodeEntities(value)
        }
        return (name, attributes, selfClosing)
    }

    static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}", "copy": "©", "reg": "®", "trade": "™",
        "hellip": "…", "mdash": "—", "ndash": "–", "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”", "middot": "·",
        "times": "×", "divide": "÷", "yen": "¥", "laquo": "«", "raquo": "»", "bull": "•", "deg": "°", "rarr": "→", "larr": "←",
    ]

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = ""
        var rest = Substring(text)
        while let amp = rest.firstIndex(of: "&") {
            result += rest[..<amp]
            let after = rest[rest.index(after: amp)...]
            if let semi = after.prefix(12).firstIndex(of: ";") {
                let entity = after[..<semi]
                var decoded: String?
                if entity.hasPrefix("#x") || entity.hasPrefix("#X") {
                    decoded = UInt32(entity.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
                } else if entity.hasPrefix("#") {
                    decoded = UInt32(entity.dropFirst()).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
                } else {
                    decoded = namedEntities[String(entity)]
                }
                if let decoded {
                    result += decoded
                    rest = after[after.index(after: semi)...]
                    continue
                }
            }
            result += "&"
            rest = after
        }
        return result + rest
    }
}

/// Converts a note article body (the HTML in the note API's `body`) to Markdown.
/// Follows the 「Markdown整形（Google Chrome）」 Keyboard Maestro macro: the title becomes the h1, embeds become links,
/// image size parameters are dropped, and <br> becomes a hard line break.
struct NoteMarkdown {
    /// Titles of embedded note articles, keyed by their URL (data-src). Missing ones use `noteLinkText`.
    var embedTitles: [String: String] = [:]
    var noteLinkText = "note記事へのリンク"
    var tweetLinkText = "Twitter（現「X」）リンク"
    var imageText = "画像"

    static let paidLine = "このラインより上のエリアが無料で表示されます。"
    static let blockTags: Set<String> = ["p", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "li", "blockquote", "pre", "figure",
                                         "figcaption", "hr", "div", "section", "article", "table", "table-of-contents", "nav", "button"]

    func convert(title: String, html: String) -> String {
        var blocks: [String] = []
        let heading = oneLine(title)
        if !heading.isEmpty { blocks.append("# " + escapeText(heading)) }
        blocks += renderBlocks(HTMLParser.parse(html).children)
        return Self.tidy(blocks.joined(separator: "\n\n"))
    }

    /// URLs (data-src) of embedded note articles, so their titles can be fetched before converting.
    static func noteEmbedURLs(in html: String) -> [String] {
        var result: [String] = []
        func walk(_ node: HTMLNode) {
            if node.name == "figure", node.attributes["embedded-service"] == "note", let src = node.attributes["data-src"], !result.contains(src) { result.append(src) }
            node.children.forEach(walk)
        }
        walk(HTMLParser.parse(html))
        return result
    }

    // MARK: Blocks

    func renderBlocks(_ nodes: [HTMLNode]) -> [String] {
        var blocks: [String] = []
        var inline: [HTMLNode] = []
        func flush() {
            let text = paragraph(inline)
            if !text.isEmpty { blocks.append(text) }
            inline = []
        }
        for node in nodes {
            if !node.isText && (Self.blockTags.contains(node.name) || node.name == "img" && inline.allSatisfy({ $0.isText && $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })) {
                flush()
                if let block = renderBlock(node), !block.isEmpty { blocks.append(block) }
            } else {
                inline.append(node)
            }
        }
        flush()
        return blocks
    }

    private func renderBlock(_ node: HTMLNode) -> String? {
        switch node.name {
        case "p": return paragraph(node.children)
        case "h1", "h2", "h3", "h4", "h5", "h6":
            let text = oneLine(renderInline(node.children))
            return text.isEmpty ? nil : String(repeating: "#", count: Int(String(node.name.last!))!) + " " + text
        case "ul", "ol": return list(node)
        case "blockquote": return quote(renderBlocks(node.children).joined(separator: "\n\n"))
        case "pre": return codeBlock(node)
        case "hr": return "---"
        case "figure": return figure(node)
        case "img": return image(node, caption: nil)
        case "table": return table(node)
        case "table-of-contents", "nav", "button", "figcaption": return nil
        default: return renderBlocks(node.children).joined(separator: "\n\n")
        }
    }

    private func paragraph(_ nodes: [HTMLNode]) -> String {
        var text = renderInline(nodes).replacingOccurrences(of: Self.paidLine, with: "")
        // Trim spaces and line breaks at both ends (a trailing <br> would leave "  \n").
        while let last = text.last, last.isWhitespace { text.removeLast() }
        while let first = text.first, first.isWhitespace { text.removeFirst() }
        return text.components(separatedBy: "\n").map { line in
            let trimmed = line.drop(while: { $0 == " " })
            return escapeLineStart(String(trimmed))
        }.joined(separator: "\n")
    }

    private func list(_ node: HTMLNode) -> String? {
        let ordered = node.name == "ol"
        var number = Int(node.attributes["start"] ?? "") ?? 1
        var lines: [String] = []
        for item in node.children where !item.isText {
            let content = item.name == "li" ? renderBlocks(item.children) : [renderBlock(item) ?? ""]
            let body = content.filter { !$0.isEmpty }.joined(separator: "\n")
            let marker = ordered ? "\(number). " : "- "
            number += 1
            let indent = String(repeating: " ", count: marker.count)
            let itemLines = body.components(separatedBy: "\n")
            lines.append(marker + itemLines[0])
            lines += itemLines.dropFirst().map { $0.isEmpty ? "" : indent + $0 }
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    private func quote(_ text: String) -> String? {
        let body = text.trimmingCharacters(in: .newlines)
        guard !body.isEmpty else { return nil }
        return body.components(separatedBy: "\n").map { $0.isEmpty ? ">" : "> " + $0 }.joined(separator: "\n")
    }

    private func codeBlock(_ node: HTMLNode) -> String {
        var code = node.rawText.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\u{00A0}", with: " ")
        while code.hasSuffix("\n") { code.removeLast() }
        while code.hasPrefix("\n") { code.removeFirst() }
        var fence = "```"
        while code.contains(fence) { fence += "`" }
        let language = (node.first("code")?.attributes["class"] ?? "").components(separatedBy: " ")
            .first(where: { $0.hasPrefix("language-") }).map { String($0.dropFirst(9)) } ?? ""
        return fence + language + "\n" + code + "\n" + fence
    }

    private func figure(_ node: HTMLNode) -> String? {
        let source = node.attributes["data-src"].flatMap { $0.isEmpty ? nil : $0 } ?? node.first("a")?.attributes["href"]
        if let service = node.attributes["embedded-service"] {
            guard let source else { return nil }
            switch service {
            case "note":
                return "- " + link(embedTitles[source] ?? noteLinkText, source)
            case "twitter":
                return "- " + link(tweetLinkText, source)
            case "youtube":
                return source
            case "external-article":
                let title = oneLine(node.first("strong")?.rawText ?? "")
                return "- " + (title.isEmpty ? "<\(source)>" : link(title, source))
            case "attachment":
                let name = oneLine(node.first("strong")?.rawText ?? "")
                return "- " + (name.isEmpty ? "<\(source)>" : link(name, source))
            default:
                return "- <\(source)>"
            }
        }
        let caption = oneLine(node.first("figcaption")?.rawText ?? "")
        let content = node.children.filter { $0.name != "figcaption" }
        if content.count == 1, let img = content.first, img.name == "img" { return image(img, caption: caption) }
        if content.count == 1, let a = content.first, a.name == "a", let img = a.first("img") {
            let picture = image(img, caption: caption) ?? ""
            let target = a.attributes["href"] ?? ""
            return target.isEmpty || cleanImageURL(target) == cleanImageURL(img.attributes["src"] ?? "") ? picture : "[\(picture)](\(target))"
        }
        var blocks = renderBlocks(content)
        if !caption.isEmpty { blocks.append(escapeText(caption)) }
        return blocks.joined(separator: "\n\n")
    }

    private func image(_ node: HTMLNode, caption: String?) -> String? {
        guard let src = node.attributes["src"], !src.isEmpty else { return nil }
        var alt = caption ?? ""
        if alt.isEmpty { alt = oneLine(node.attributes["alt"] ?? "") }
        if alt.isEmpty { alt = imageText }
        return "![\(escapeBrackets(alt))](\(cleanImageURL(src)))"
    }

    private func table(_ node: HTMLNode) -> String? {
        var rows: [[String]] = []
        func collect(_ n: HTMLNode) {
            for child in n.children {
                if child.name == "tr" {
                    rows.append(child.children.filter { $0.name == "td" || $0.name == "th" }
                        .map { oneLine(renderInline($0.children)).replacingOccurrences(of: "|", with: "\\|") })
                } else if !child.isText { collect(child) }
            }
        }
        collect(node)
        guard let width = rows.map(\.count).max(), width > 0 else { return nil }
        let padded = rows.map { $0 + Array(repeating: "", count: width - $0.count) }
        var lines = ["| " + padded[0].joined(separator: " | ") + " |", "|" + Array(repeating: " --- |", count: width).joined()]
        lines += padded.dropFirst().map { "| " + $0.joined(separator: " | ") + " |" }
        return lines.joined(separator: "\n")
    }

    // MARK: Inline

    func renderInline(_ nodes: [HTMLNode]) -> String {
        var result = ""
        for node in nodes {
            let piece = inline(node)
            // Collapsed whitespace: no double spaces where two pieces meet.
            if result.hasSuffix(" ") && piece.hasPrefix(" ") { result += piece.dropFirst() } else { result += piece }
        }
        return result
    }

    private func inline(_ node: HTMLNode) -> String {
        if node.isText {
            let collapsed = node.text.replacingOccurrences(of: #"[ \t\r\n]+"#, with: " ", options: .regularExpression)
            return escapeText(collapsed)
        }
        switch node.name {
        case "br": return "  \n"
        case "strong", "b": return wrap(renderInline(node.children), "**")
        case "em", "i": return wrap(renderInline(node.children), "*")
        case "s", "del", "strike": return wrap(renderInline(node.children), "~~")
        case "code":
            let code = oneLine(node.rawText)
            guard !code.isEmpty else { return "" }
            var fence = "`"
            while code.contains(fence) { fence += "`" }
            let pad = code.hasPrefix("`") || code.hasSuffix("`") ? " " : ""
            return fence + pad + code + pad + fence
        case "a":
            let href = node.attributes["href"] ?? ""
            if let img = node.first("img") {
                let picture = image(img, caption: nil) ?? ""
                return href.isEmpty || cleanImageURL(href) == cleanImageURL(img.attributes["src"] ?? "") ? picture : "[\(picture)](\(href))"
            }
            // Bold inside link text is dropped, as the macro did ([**text**](url) → [text](url)).
            var text = oneLine(renderInline(node.children)).replacingOccurrences(of: "**", with: "")
            text = text.trimmingCharacters(in: .whitespaces)
            if href.isEmpty { return text }
            if text.isEmpty || unescape(text) == href { return "<\(href)>" }
            return link(text, href, escaped: true)
        case "img": return image(node, caption: nil) ?? ""
        case "script", "style", "button", "nav", "table-of-contents": return ""
        default: return renderInline(node.children)
        }
    }

    private func wrap(_ text: String, _ mark: String) -> String {
        let core = text.trimmingCharacters(in: .whitespaces)
        guard !core.isEmpty else { return text }
        let leading = text.hasPrefix(" ") ? " " : "", trailing = text.hasSuffix(" ") ? " " : ""
        return leading + mark + core + mark + trailing
    }

    private func link(_ text: String, _ url: String, escaped: Bool = false) -> String {
        "[\(escapeBrackets(escaped ? text : escapeText(text)))](\(url.replacingOccurrences(of: " ", with: "%20").replacingOccurrences(of: ")", with: "%29")))"
    }

    // MARK: Escaping and cleanup

    /// Removes note's resize parameters from image URLs (?width=…&height=…&fit=bounds&quality=…).
    func cleanImageURL(_ url: String) -> String {
        guard url.contains("st-note.com"), let query = url.firstIndex(of: "?") else { return url }
        return String(url[..<query])
    }

    private func oneLine(_ text: String) -> String {
        text.replacingOccurrences(of: #"\s*\n\s*"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func escapeBrackets(_ text: String) -> String {
        text.replacingOccurrences(of: "[", with: "\\[").replacingOccurrences(of: "]", with: "\\]")
    }

    private func unescape(_ text: String) -> String {
        text.replacingOccurrences(of: #"\\([\\`*_<\[\]])"#, with: "$1", options: .regularExpression)
    }

    /// Escapes characters that would otherwise start Markdown formatting inside running text.
    /// Backtick pairs the author typed (`code`) are kept as code spans; a lone `*` or `_` is left as is.
    func escapeText(_ text: String) -> String {
        guard text.contains(where: { "\\`*_<".contains($0) }) else { return text }
        let chars = Array(text)
        func isWord(_ c: Character) -> Bool { c.isLetter || c.isNumber }
        // A `_` can only take part in emphasis at a word boundary (file_name is safe).
        let boundaryUnderscores = chars.indices.filter { i in
            chars[i] == "_" && (i == 0 || !isWord(chars[i - 1]) || i + 1 == chars.count || !isWord(chars[i + 1]))
        }.count
        let asterisks = chars.filter { $0 == "*" }.count
        var result = ""
        var i = 0
        while i < chars.count {
            let c = chars[i]
            let prev = i > 0 ? chars[i - 1] : " ", next = i + 1 < chars.count ? chars[i + 1] : " "
            if c == "`" {
                var run = 0
                while i + run < chars.count, chars[i + run] == "`" { run += 1 }
                // Look for a closing run of the same length: keep the span verbatim.
                var j = i + run
                var closing: Int?
                while j < chars.count {
                    if chars[j] == "`" {
                        var other = 0
                        while j + other < chars.count, chars[j + other] == "`" { other += 1 }
                        if other == run { closing = j; break }
                        j += other
                    } else { j += 1 }
                }
                if let closing {
                    result += String(chars[i..<(closing + run)])
                    i = closing + run
                } else {
                    result += String(repeating: "\\`", count: run)
                    i += run
                }
                continue
            }
            switch c {
            case "\\" where next.isASCII && (next.isPunctuation || next.isSymbol): result += "\\\\"
            case "*" where asterisks >= 2: result += "\\*"
            case "_" where boundaryUnderscores >= 2 && (!isWord(prev) || !isWord(next)): result += "\\_"
            case "<" where next.isASCII && (next.isLetter || next == "/" || next == "!"): result += "\\<"
            default: result.append(c)
            }
            i += 1
        }
        return result
    }

    /// Keeps a paragraph line from being read as a heading, quote, list item or rule.
    private func escapeLineStart(_ line: String) -> String {
        if line.hasPrefix("#") || line.hasPrefix(">") || line.hasPrefix("+ ") || line.hasPrefix("- ") || line.hasPrefix("* ") || line == "-" || line.hasPrefix("=") {
            return "\\" + line
        }
        if line.range(of: #"^\d+[.)] "#, options: .regularExpression) != nil, let dot = line.firstIndex(where: { $0 == "." || $0 == ")" }) {
            return line[..<dot] + "\\" + line[dot...]
        }
        return line
    }

    /// No trailing spaces except hard breaks, at most one blank line in a row, and a final newline.
    static func tidy(_ text: String) -> String {
        var lines = text.components(separatedBy: "\n").map { line -> String in
            if line.hasSuffix("  "), line.trimmingCharacters(in: .whitespaces).isEmpty == false { return line.replacingOccurrences(of: #" {3,}$"#, with: "  ", options: .regularExpression) }
            return line.replacingOccurrences(of: #"[ \t]+$"#, with: "", options: .regularExpression)
        }
        var result: [String] = []
        var inFence: String?
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let fence = inFence {
                if trimmed == fence { inFence = nil }
                result.append(line); continue
            }
            if trimmed.hasPrefix("```") { inFence = String(trimmed.prefix(while: { $0 == "`" })) }
            if line.isEmpty, result.last?.isEmpty ?? true { continue }
            result.append(line)
        }
        while result.last?.isEmpty == true { result.removeLast() }
        lines = result
        return lines.joined(separator: "\n") + "\n"
    }
}
