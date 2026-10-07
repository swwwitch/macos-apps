import Foundation

// Markdown → plain text that keeps the document structure (「構造を保持」).
// Port of https://cssnite.jp/tool/markdown2text.html (see https://note.com/swwwitch/n/n281cc79cdba2).
// Keep the step order identical to the JavaScript original; Tests/markdown2text compares both.

struct MarkdownTextOptions: Equatable {
    enum LinkMode: String, CaseIterable { case text, angle, paren }
    enum NumberMode: String, CaseIterable { case keep, renumber, marker }
    enum BoldMode: String, CaseIterable { case none, bracket }
    enum TableMode: String, CaseIterable { case tab, ascii }
    enum ImageMode: String, CaseIterable { case text, ignore }
    enum HeadingMode: String { case prefix, rule }

    var linkMode = LinkMode.angle
    var linkBelow = true
    var listMarker = "・"
    var numberMode = NumberMode.keep
    var zenkakuIndent = true
    var trimBlank = true
    var trimLeading = true
    var collapseBlank = true
    var blockGap = 1
    var boldMode = BoldMode.none
    var tableMode = TableMode.tab
    var imageMode = ImageMode.text
    var stripHTML = true
    var headingModes = [HeadingMode](repeating: .prefix, count: 6)
    var headingPrefixes = ["", "■", "●", "◇", "", ""]
}

enum MarkdownToText {
    // MARK: Regex helpers (JavaScript semantics: /m → anchorsMatchLines)

    private static func regex(_ pattern: String, multiline: Bool = false) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: multiline ? [.anchorsMatchLines] : [])
    }

    /// String.replace(/pattern/g, template) with $1-style templates.
    private static func replace(_ text: String, _ pattern: String, _ template: String, multiline: Bool = false) -> String {
        let re = regex(pattern, multiline: multiline)
        return re.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: template)
    }

    /// String.replace(/pattern/g, (match, groups...) => …). Groups that did not participate are nil.
    private static func replace(_ text: String, _ pattern: String, multiline: Bool = false, _ transform: ([String?]) -> String) -> String {
        let re = regex(pattern, multiline: multiline)
        let ns = text as NSString
        var result = ""
        var last = 0
        for match in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: last, length: match.range.location - last))
            var groups: [String?] = []
            for index in 0..<match.numberOfRanges {
                let range = match.range(at: index)
                groups.append(range.location == NSNotFound ? nil : ns.substring(with: range))
            }
            result += transform(groups)
            last = match.range.location + match.range.length
        }
        result += ns.substring(from: last)
        return result
    }

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        regex(pattern).firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private static func firstMatch(_ text: String, _ pattern: String) -> [String?]? {
        let ns = text as NSString
        guard let match = regex(pattern).firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            let range = match.range(at: index)
            return range.location == NSNotFound ? nil : ns.substring(with: range)
        }
    }

    private static func escapeForRegex(_ text: String) -> String { NSRegularExpression.escapedPattern(for: text) }

    // MARK: Display width (full-width = 2, half-width = 1)

    static func displayWidth(_ text: String) -> Int {
        text.unicodeScalars.reduce(0) { width, scalar in
            let value = scalar.value
            return width + ((value > 0xFF && !(value >= 0xFF61 && value <= 0xFF9F)) ? 2 : 1)
        }
    }

    private static func pad(_ text: String, to width: Int) -> String {
        text + String(repeating: " ", count: max(0, width - displayWidth(text)))
    }

    private static func ruledHeading(level: Int, text: String, width: Int) -> String {
        func bar(_ character: String, _ count: Int) -> String { String(repeating: character, count: max(0, count)) }
        switch level {
        case 1, 2: return "◤" + bar("￣", width + 1) + "\n\u{3000}" + text + "\n" + bar("＿", width + 1) + "◢"
        case 3: return text + "\n" + bar("￣", width)
        case 4: return text + "\n" + bar("＿", width)
        case 5: return "■ " + text
        default: return "□ " + text
        }
    }

    // MARK: Tables

    private static func formatTables(_ text: String, mode: MarkdownTextOptions.TableMode) -> String {
        let lines = text.components(separatedBy: "\n")
        var out: [String] = []
        var index = 0
        func isRow(_ line: String) -> Bool { matches(line, #"^\s*\|.*\|\s*$"#) }
        func isSeparator(_ line: String) -> Bool {
            matches(line, #"^\s*\|?[\s:|-]+\|?\s*$"#) && line.contains("-") && !matches(line, "[a-zA-Z0-9ぁ-んァ-ヶ一-龠]")
        }
        while index < lines.count {
            if isRow(lines[index]) {
                var block: [String] = []
                while index < lines.count && isRow(lines[index]) { block.append(lines[index]); index += 1 }
                let rows: [[String]] = block.filter { !isSeparator($0) }.map { line in
                    let inner = replace(replace(line, #"^\s*\|"#, ""), #"\|\s*$"#, "")
                    return inner.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                }
                if mode == .ascii && !rows.isEmpty {
                    let columns = rows.map(\.count).max() ?? 0
                    let widths = (0..<columns).map { column in
                        max(1, rows.map { displayWidth(column < $0.count ? $0[column] : "") }.max() ?? 1)
                    }
                    let border = "+" + widths.map { String(repeating: "-", count: $0 + 2) }.joined(separator: "+") + "+"
                    out.append(border)
                    for (rowIndex, row) in rows.enumerated() {
                        let cells = widths.enumerated().map { column, width in " " + pad(column < row.count ? row[column] : "", to: width) + " " }
                        out.append("|" + cells.joined(separator: "|") + "|")
                        if rowIndex == 0 { out.append(border) }
                    }
                    out.append(border)
                } else {
                    for row in rows { out.append(row.joined(separator: "\t")) }
                }
            } else {
                out.append(lines[index]); index += 1
            }
        }
        return out.joined(separator: "\n")
    }

    // MARK: Conversion

    static func convert(_ markdown: String, options: MarkdownTextOptions = MarkdownTextOptions()) -> String {
        var t = markdown

        // Autolinks <https://…> / <mail@example.com>
        t = replace(t, #"<(https?://[^>\s]+)>"#, "$1")
        t = replace(t, #"<([^>\s@]+@[^>\s]+\.[^>\s]+)>"#, "$1")

        if options.stripHTML { t = HTMLToMarkdown.convert(t) }

        t = replace(t, #"\r\n?"#, "\n")

        // Escapes \* \_ …: protect from syntax processing, restore at the end.
        var escapes: [String] = []
        t = replace(t, #"\\([\\`*_{}\[\]()#+\-.!>~|])"#) { groups in
            escapes.append(groups[1] ?? "")
            return "\u{4}\(escapes.count - 1)\u{4}"
        }

        // Fenced code: keep the content, drop the fence lines.
        t = replace(t, #"^```[^\n]*\n([\s\S]*?)^```[ \t]*$"#, multiline: true) { $0[1] ?? "" }

        // Setext headings → ATX.
        t = replace(t, #"^(?![ \t]*$)(?![ \t]*(?:[-*+][ \t]|\d+\.[ \t]|#|>|\|))(.+)\n=+[ \t]*$"#, "# $1", multiline: true)
        t = replace(t, #"^(?![ \t]*$)(?![ \t]*(?:[-*+][ \t]|\d+\.[ \t]|#|>|\|))(.+)\n-+[ \t]*$"#, "## $1", multiline: true)

        // Reference links.
        var definitions: [String: String] = [:]
        t = replace(t, #"^[ \t]*\[([^\]^]+)\]:[ \t]+(\S+)[^\n]*$"#, multiline: true) { groups in
            definitions[(groups[1] ?? "").lowercased()] = groups[2] ?? ""
            return "\u{3}"
        }
        t = replace(t, #"\[([^\]]+)\]\[([^\]]*)\]"#) { groups in
            let text = groups[1] ?? "", id = groups[2] ?? ""
            let key = (id.isEmpty ? text : id).lowercased()
            if let url = definitions[key] { return "[" + text + "](" + url + ")" }
            return groups[0] ?? ""
        }
        t = replace(t, "^\u{3}$", "", multiline: true)
        t = t.replacingOccurrences(of: "\u{3}", with: "")

        // Footnotes.
        t = replace(t, #"^[ \t]*\[\^([^\]]+)\]:[ \t]*"#, "※$1 ", multiline: true)
        t = replace(t, #"\[\^([^\]]+)\]"#, "※$1")

        // Headings → prefix or rule, followed by a protected blank line (\u0001).
        t = replace(t, #"^(#{1,6})[ \t]+(.*)$"#, multiline: true) { groups in
            let level = (groups[1] ?? "#").count
            let text = (groups[2] ?? "").trimmingCharacters(in: .whitespaces)
            if options.headingModes[level - 1] == .rule {
                return "\n" + ruledHeading(level: level, text: text, width: displayWidth(text)) + "\n\u{1}"
            }
            let prefix = options.headingPrefixes[level - 1]
            return (prefix.isEmpty ? text : prefix + " " + text) + "\n\u{1}"
        }

        // Horizontal rules.
        t = replace(t, #"^[ \t]*([-*_])[ \t]*(?:\1[ \t]*){2,}$"#, "", multiline: true)

        // Blockquotes.
        t = replace(t, #"^>\s?"#, "", multiline: true)

        // Lists.
        let marker = options.listMarker.isEmpty ? "・" : options.listMarker
        func zenkaku(_ indent: String) -> String {
            guard options.zenkakuIndent else { return indent }
            let level = indent.replacingOccurrences(of: "\t", with: "  ").count / 2
            return String(repeating: "\u{3000}", count: level)
        }
        var counters: [Int: Int] = [:]
        var previousWasList = false
        t = t.components(separatedBy: "\n").map { line -> String in
            if let bullet = firstMatch(line, #"^([ \t]*)[-*+][ \t]+(.*)$"#) {
                previousWasList = true
                let body = bullet[2] ?? ""
                if let task = firstMatch(body, #"^\[( |x|X)\][ \t]+(.*)$"#) {
                    let box = task[1] == " " ? "□" : "■"
                    return zenkaku(bullet[1] ?? "") + marker + box + " " + (task[2] ?? "")
                }
                return zenkaku(bullet[1] ?? "") + marker + body
            }
            if let numbered = firstMatch(line, #"^([ \t]*)(\d+)\.[ \t]+(.*)$"#) {
                let rawIndent = numbered[1] ?? ""
                let depth = rawIndent.replacingOccurrences(of: "\t", with: "  ").count
                let body = numbered[3] ?? ""
                let indent = zenkaku(rawIndent)
                switch options.numberMode {
                case .marker:
                    previousWasList = true
                    return indent + marker + body
                case .renumber:
                    if !previousWasList { counters.removeAll() }
                    counters[depth, default: 0] += 1
                    for key in counters.keys where key > depth { counters.removeValue(forKey: key) }
                    previousWasList = true
                    return indent + String(counters[depth]!) + ". " + body
                case .keep:
                    previousWasList = true
                    return indent + (numbered[2] ?? "") + ". " + body
                }
            }
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                counters.removeAll()
                previousWasList = false
                return line
            }
            previousWasList = false
            return line
        }.joined(separator: "\n")

        // Images.
        if options.imageMode == .ignore {
            t = replace(t, #"^[ \t]*!\[[^\]]*\]\([^)]*\)[ \t]*$"#, "", multiline: true)
            t = replace(t, #"[ \t]?!\[[^\]]*\]\([^)]*\)[ \t]?"#, " ")
        } else {
            t = replace(t, #"!\[([^\]]*)\]\([^)]*\)"#, "$1")
        }

        // Gather links below paragraphs / list items.
        let linkPattern = #"\[([^\]]+)\]\(([^)]+)\)"#
        if options.linkBelow {
            func formatLink(_ text: String, _ url: String) -> String {
                options.linkMode == .paren ? text + " (" + url + ")" : text + " <" + url + ">"
            }
            let markerPattern = escapeForRegex(marker)
            let listItemPattern = #"^[\x{3000} \t]*("# + markerPattern + #"|\d+\.[ \t])"#
            let listItemPrefix = #"^[\x{3000} \t]*("# + markerPattern + #"|\d+\.[ \t]+)"#
            func isListItem(_ line: String) -> Bool { matches(line, listItemPattern) }
            func isBlank(_ line: String) -> Bool { line.replacingOccurrences(of: "\u{1}", with: "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            func stripLinks(_ text: String) -> String { replace(text, linkPattern, "") }
            let source = t.components(separatedBy: "\n")
            var result: [String] = []
            var index = 0
            while index < source.count {
                let line = source[index]
                if isBlank(line) { result.append(line); index += 1; continue }
                if isListItem(line) {
                    let bodyOnly = replace(line, listItemPrefix, "")
                    if stripLinks(bodyOnly).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        result.append(line); index += 1; continue
                    }
                    var urls: [(String, String)] = []
                    let indent = firstMatch(line, #"^[\x{3000} \t]*"#)?[0] ?? ""
                    let replaced = replace(line, linkPattern) { groups in
                        urls.append((groups[1] ?? "", groups[2] ?? "")); return groups[1] ?? ""
                    }
                    result.append(replaced)
                    for (text, url) in urls { result.append(indent + "\u{3000}" + formatLink(text, url)) }
                    index += 1
                    continue
                }
                var paragraph: [String] = []
                while index < source.count && !isBlank(source[index]) && !isListItem(source[index]) { paragraph.append(source[index]); index += 1 }
                if stripLinks(paragraph.joined(separator: " ")).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    result.append(contentsOf: paragraph); continue
                }
                var urls: [(String, String)] = []
                let replaced = paragraph.map { line in
                    replace(line, linkPattern) { groups in urls.append((groups[1] ?? "", groups[2] ?? "")); return groups[1] ?? "" }
                }
                result.append(contentsOf: replaced)
                for (text, url) in urls { result.append(formatLink(text, url)) }
            }
            t = result.joined(separator: "\n")
        }

        // Remaining links.
        t = replace(t, linkPattern) { groups in
            let text = groups[1] ?? "", url = groups[2] ?? ""
            switch options.linkMode {
            case .angle: return text + " <" + url + ">"
            case .paren: return text + " (" + url + ")"
            case .text: return text
            }
        }

        // Bold, italic, strikethrough, inline code.
        t = replace(t, #"(\*\*|__)(.*?)\1"#, options.boldMode == .bracket ? "【$2】" : "$2")
        t = replace(t, #"(\*|_)(.*?)\1"#, "$2")
        t = replace(t, "~~(.*?)~~", "$1")
        t = replace(t, "`([^`]+)`", "$1")

        t = formatTables(t, mode: options.tableMode)

        t = replace(t, #"\n{3,}"#, "\n\n")
        if options.trimBlank { t = replace(t, #"^[ \t\x{3000}]+$"#, "", multiline: true) }
        if options.trimLeading { t = replace(t, #"^[ \t]+"#, "", multiline: true) }
        if options.collapseBlank { t = replace(t, #"\n{2,}"#, "\n\n") }
        t = replace(t, #"\n{2,}"#, String(repeating: "\n", count: max(0, min(2, options.blockGap)) + 1))

        // Heading sentinel → exactly one blank line.
        t = replace(t, "\n*\u{1}\n*", "\n\n")
        t = t.replacingOccurrences(of: "\u{1}", with: "")

        t = replace(t, "\u{4}(\\d+)\u{4}") { groups in
            let index = Int(groups[1] ?? "") ?? -1
            return escapes.indices.contains(index) ? escapes[index] : ""
        }

        // trimEnd
        while let last = t.unicodeScalars.last, CharacterSet.whitespacesAndNewlines.contains(last) { t.unicodeScalars.removeLast() }
        return t
    }
}

/// Mixed HTML → Markdown equivalent (the original uses DOMParser; this is a small tolerant parser).
enum HTMLToMarkdown {
    private final class Node {
        let tag: String?          // nil = text
        var text = ""
        var attributes: [String: String] = [:]
        var children: [Node] = []
        weak var parent: Node?
        init(tag: String?) { self.tag = tag }
        var textContent: String { tag == nil ? text : children.map(\.textContent).joined() }
    }
    private static let voidTags: Set<String> = ["br", "hr", "img", "meta", "link", "input", "col", "area", "base", "source", "wbr"]

    static func convert(_ source: String) -> String {
        var src = source
        var fences: [String] = []
        src = replaceAll(src, "```[\\s\\S]*?```") { fences.append($0); return "\u{0}FENCE\(fences.count - 1)\u{0}" }
        var inlines: [String] = []
        src = replaceAll(src, "`[^`\\n]+`") { inlines.append($0); return "\u{0}INL\(inlines.count - 1)\u{0}" }
        func restore(_ text: String) -> String {
            var out = replaceAll(text, "\u{0}INL(\\d+)\u{0}") { match in inlines[Int(match.dropFirst(4).dropLast(1))!] }
            out = replaceAll(out, "\u{0}FENCE(\\d+)\u{0}") { match in fences[Int(match.dropFirst(6).dropLast(1))!] }
            return out
        }
        guard src.range(of: "<[a-zA-Z!/][^>]*>", options: .regularExpression) != nil else { return restore(src) }
        let root = parse(src)
        var markdown = walk(root)
        markdown = markdown.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return restore(markdown).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func replaceAll(_ text: String, _ pattern: String, _ transform: (String) -> String) -> String {
        let re = try! NSRegularExpression(pattern: pattern)
        let ns = text as NSString
        var result = "", last = 0
        for match in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: last, length: match.range.location - last))
            result += transform(ns.substring(with: match.range))
            last = match.range.location + match.range.length
        }
        return result + ns.substring(from: last)
    }

    private static func decodeEntities(_ text: String) -> String {
        var out = text
        for (entity, value) in [("&nbsp;", "\u{00A0}"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'")] {
            out = out.replacingOccurrences(of: entity, with: value)
        }
        out = replaceAll(out, "&#(x?)([0-9A-Fa-f]+);") { match in
            let hex = match.hasPrefix("&#x") || match.hasPrefix("&#X")
            let digits = match.dropFirst(hex ? 3 : 2).dropLast()
            guard let value = UInt32(digits, radix: hex ? 16 : 10), let scalar = Unicode.Scalar(value) else { return match }
            return String(Character(scalar))
        }
        return out.replacingOccurrences(of: "&amp;", with: "&")
    }

    private static func parse(_ html: String) -> Node {
        let root = Node(tag: "body")
        var current = root
        let tagRegex = try! NSRegularExpression(pattern: #"<!--[\s\S]*?-->|<(/?)([a-zA-Z][a-zA-Z0-9]*)([^>]*)>|<![^>]*>"#)
        let attrRegex = try! NSRegularExpression(pattern: #"([a-zA-Z_:][-a-zA-Z0-9_:.]*)\s*=\s*("([^"]*)"|'([^']*)'|([^\s"'>]+))"#)
        let ns = html as NSString
        var last = 0
        func addText(_ text: String) {
            guard !text.isEmpty else { return }
            let node = Node(tag: nil); node.text = decodeEntities(text); node.parent = current; current.children.append(node)
        }
        for match in tagRegex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            addText(ns.substring(with: NSRange(location: last, length: match.range.location - last)))
            last = match.range.location + match.range.length
            guard match.range(at: 2).location != NSNotFound else { continue } // comment / doctype
            let closing = ns.substring(with: match.range(at: 1)) == "/"
            let name = ns.substring(with: match.range(at: 2)).lowercased()
            if closing {
                var node: Node? = current
                while let candidate = node, candidate.tag != name { node = candidate.parent }
                if let found = node, let parent = found.parent { current = parent }
                continue
            }
            let attributesText = ns.substring(with: match.range(at: 3))
            let node = Node(tag: name)
            let attributesNS = attributesText as NSString
            for attribute in attrRegex.matches(in: attributesText, range: NSRange(location: 0, length: attributesNS.length)) {
                let key = attributesNS.substring(with: attribute.range(at: 1)).lowercased()
                let valueRange = [3, 4, 5].map { attribute.range(at: $0) }.first { $0.location != NSNotFound }
                node.attributes[key] = valueRange.map { decodeEntities(attributesNS.substring(with: $0)) } ?? ""
            }
            node.parent = current
            current.children.append(node)
            if !voidTags.contains(name) && !attributesText.hasSuffix("/") { current = node }
        }
        addText(ns.substring(from: last))
        return root
    }

    private static func walk(_ node: Node) -> String {
        var out = ""
        for child in node.children {
            guard let tag = child.tag else {
                out += child.text.replacingOccurrences(of: "[ \\t\\f\\v]+", with: " ", options: .regularExpression)
                continue
            }
            let inner = walk(child)
            let trimmed = inner.trimmingCharacters(in: .whitespacesAndNewlines)
            switch tag {
            case "h1", "h2", "h3", "h4", "h5", "h6":
                out += "\n\n" + String(repeating: "#", count: Int(String(tag.last!))!) + " " + trimmed + "\n\n"
            case "p", "div", "section", "article": out += "\n\n" + trimmed + "\n\n"
            case "br": out += "\n"
            case "hr": out += "\n\n---\n\n"
            case "strong", "b": out += "**" + trimmed + "**"
            case "em", "i": out += "*" + trimmed + "*"
            case "del", "s", "strike": out += "~~" + trimmed + "~~"
            case "code": out += "`" + trimmed + "`"
            case "pre":
                var code = child.textContent
                while code.hasSuffix("\n") { code.removeLast() }
                out += "\n\n```\n" + code + "\n```\n\n"
            case "blockquote":
                out += "\n\n" + trimmed.components(separatedBy: "\n").map { "> " + $0 }.joined(separator: "\n") + "\n\n"
            case "a":
                let href = child.attributes["href"] ?? ""
                out += href.isEmpty ? inner : "[" + trimmed + "](" + href + ")"
            case "img":
                out += "![" + (child.attributes["alt"] ?? "") + "](" + (child.attributes["src"] ?? "") + ")"
            case "ul", "ol":
                out += "\n\n"
                var number = 1
                for item in child.children where item.tag == "li" {
                    let mark = tag == "ol" ? "\(number). " : "- "
                    number += 1
                    out += mark + walk(item).trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
                }
                out += "\n"
            case "li": out += inner
            case "table":
                out += "\n\n"
                var rowIndex = 0
                func rows(_ node: Node) -> [Node] { node.children.flatMap { $0.tag == "tr" ? [$0] : ($0.tag == nil ? [] : rows($0)) } }
                for row in rows(child) {
                    let cells = row.children.filter { $0.tag == "td" || $0.tag == "th" }.map { walk($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    out += "| " + cells.joined(separator: " | ") + " |\n"
                    if rowIndex == 0 { out += "| " + cells.map { _ in "---" }.joined(separator: " | ") + " |\n" }
                    rowIndex += 1
                }
                out += "\n"
            case "script", "style", "head": break
            default: out += inner
            }
        }
        return out
    }
}
