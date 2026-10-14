import Foundation

/// プレビュー用にMarkdownをHTMLにする（CommonMarkの主な書き方だけ）。
/// 行頭のHTMLはそのまま通すので、Doorkeeper用の <h2 style="…"> も色付きで表示される
enum MarkdownHTML {
    /// lineAnchors: ブロックの手前に <span data-line="原稿の行番号（0始まり）"> を入れる（スクロール合わせ用）
    static func render(_ markdown: String, lineAnchors: Bool = false) -> String {
        var lines = markdown.normalizedLineBreaks.components(separatedBy: "\n")
        var offset = 0
        // YAML front matter is not shown.
        if lines.first?.trimmingCharacters(in: .whitespaces) == "---",
           let end = lines.dropFirst().firstIndex(where: { ["---", "..."].contains($0.trimmingCharacters(in: .whitespaces)) }) {
            lines.removeSubrange(0...end)
            offset = end + 1
        }
        return renderBlocks(lines, lineOffset: lineAnchors ? offset : nil)
    }

    private static func renderBlocks(_ lines: [String], lineOffset: Int? = nil) -> String {
        var html: [String] = []
        var paragraph: [String] = []
        var quote: [String] = []
        var list = ListBuilder()
        var index = 0

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            html.append("<p>" + paragraph.map(inline).joined(separator: "\n").replacingOccurrences(of: "  \n", with: "<br>\n") + "</p>")
            paragraph = []
        }
        func flushQuote() {
            guard !quote.isEmpty else { return }
            html.append("<blockquote>" + renderBlocks(quote) + "</blockquote>")
            quote = []
        }
        func flushAll() { flushParagraph(); flushQuote(); html.append(list.close()) }
        func mark(_ line: Int) {
            if let lineOffset { html.append("<span data-line=\"\(line + lineOffset)\"></span>") }
        }

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            defer { index += 1 }

            // Fenced code.
            if let fence = ["```", "~~~"].first(where: { trimmed.hasPrefix($0) }) {
                flushAll()
                mark(index)
                var code: [String] = []
                index += 1
                while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix(fence) {
                    code.append(lines[index]); index += 1
                }
                // The info string's first word (```swift) becomes the language class for highlight.js.
                let language = trimmed.dropFirst(fence.count).trimmingCharacters(in: .whitespaces)
                    .prefix { !$0.isWhitespace && !"{`".contains($0) }
                    .filter { $0.isLetter || $0.isNumber || "+#-_.".contains($0) }
                let attribute = language.isEmpty ? "" : " class=\"language-\(language.lowercased())\""
                html.append("<pre><code\(attribute)>" + escape(code.joined(separator: "\n")) + "</code></pre>")
                continue
            }
            if trimmed.isEmpty {
                flushParagraph(); flushQuote()
                // A blank line inside a list keeps the list open unless the next line leaves it.
                if index + 1 >= lines.count || ListBuilder.marker(lines[index + 1]) == nil && !lines[index + 1].hasPrefix("  ") {
                    html.append(list.close())
                }
                continue
            }
            // Raw HTML block: passes through until a blank line.
            if paragraph.isEmpty, trimmed.range(of: #"^<(/?[A-Za-z][A-Za-z0-9-]*[\s/>]|!--)"#, options: .regularExpression) != nil {
                flushAll()
                mark(index)
                var block: [String] = [line]
                while index + 1 < lines.count, !lines[index + 1].trimmingCharacters(in: .whitespaces).isEmpty {
                    index += 1; block.append(lines[index])
                }
                html.append(block.joined(separator: "\n"))
                continue
            }
            if trimmed.hasPrefix(">") {
                flushParagraph(); html.append(list.close())
                if quote.isEmpty { mark(index) }
                var body = trimmed.dropFirst()
                if body.first == " " { body = body.dropFirst() }
                quote.append(String(body))
                continue
            }
            flushQuote()
            // Setext underline turns the paragraph above into a heading.
            if !paragraph.isEmpty, trimmed.range(of: #"^(=+|-+)$"#, options: .regularExpression) != nil, line.prefix(while: { $0 == " " }).count < 4 {
                let level = trimmed.first == "=" ? 1 : 2
                html.append("<h\(level)>" + inline(paragraph.joined(separator: " ")) + "</h\(level)>")
                paragraph = []
                continue
            }
            // GitHub-style table: a header row followed by a delimiter row such as |---|:---:|.
            if paragraph.isEmpty, line.contains("|"), index + 1 < lines.count,
               let alignments = tableAlignments(lines[index + 1]) {
                let header = tableCells(line)
                if header.count == alignments.count {
                    flushAll()
                    mark(index)
                    var rows: [[String]] = []
                    index += 1
                    while index + 1 < lines.count, lines[index + 1].contains("|"),
                          !lines[index + 1].trimmingCharacters(in: .whitespaces).isEmpty {
                        index += 1
                        rows.append(tableCells(lines[index]))
                    }
                    html.append(renderTable(header: header, alignments: alignments, rows: rows))
                    continue
                }
            }
            if let (level, title) = HeadingParser.atx(line) {
                flushAll()
                mark(index)
                html.append("<h\(level)>" + inline(title) + "</h\(level)>")
                continue
            }
            if trimmed.range(of: #"^([-*_])( *\1){2,}$"#, options: .regularExpression) != nil {
                flushAll()
                mark(index)
                html.append("<hr>")
                continue
            }
            if let marker = ListBuilder.marker(line) {
                flushParagraph()
                if !list.isOpen { mark(index) }
                html.append(list.add(indent: marker.indent, ordered: marker.ordered, content: inline(marker.content)))
                continue
            }
            if list.isOpen, paragraph.isEmpty {
                // Lazy continuation: the last <li> is still open, so the text joins it.
                html.append(inline(trimmed))
                continue
            }
            if paragraph.isEmpty { mark(index) }
            paragraph.append(trimmed)
        }
        flushAll()
        return html.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    // MARK: - Tables

    /// 区切りの行（|---|:---:|---:|）なら列ごとの揃え（"left"・"center"・"right"・""）
    static func tableAlignments(_ line: String) -> [String]? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("-"),
              trimmed.range(of: #"^\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?$"#, options: .regularExpression) != nil else { return nil }
        return tableCells(line).map { cell in
            let left = cell.hasPrefix(":"), right = cell.hasSuffix(":")
            return left && right ? "center" : right ? "right" : left ? "left" : ""
        }
    }

    /// 行をセルに分ける。両端の | は外し、インラインコードの中の | と \| は区切りにしない
    static func tableCells(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|"), !trimmed.hasSuffix("\\|") { trimmed.removeLast() }
        var cells: [String] = []
        var current = ""
        var inCode = false
        var previous: Character?
        for character in trimmed {
            if character == "`" { inCode.toggle() }
            if character == "|", !inCode, previous != "\\" {
                cells.append(current)
                current = ""
            } else if character == "|", previous == "\\" {
                current.removeLast()
                current.append("|")
            } else {
                current.append(character)
            }
            previous = character
        }
        cells.append(current)
        return cells.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func renderTable(header: [String], alignments: [String], rows: [[String]]) -> String {
        func cell(_ tag: String, _ text: String, _ column: Int) -> String {
            let align = column < alignments.count && !alignments[column].isEmpty ? " style=\"text-align: \(alignments[column])\"" : ""
            return "<\(tag)\(align)>" + inline(text) + "</\(tag)>"
        }
        var html = "<table><thead><tr>" + header.enumerated().map { cell("th", $1, $0) }.joined() + "</tr></thead>"
        if !rows.isEmpty {
            html += "<tbody>" + rows.map { row in
                // Rows are padded or cut to the header's column count, as on GitHub.
                let cells = (0..<header.count).map { $0 < row.count ? row[$0] : "" }
                return "<tr>" + cells.enumerated().map { cell("td", $1, $0) }.joined() + "</tr>"
            }.joined() + "</tbody>"
        }
        return html + "</table>"
    }

    /// 入れ子のリスト。字下げの深さで階層を決める
    private struct ListBuilder {
        private var stack: [(indent: Int, ordered: Bool)] = []
        var isOpen: Bool { !stack.isEmpty }

        static func marker(_ line: String) -> (indent: Int, ordered: Bool, content: String)? {
            guard let match = line.range(of: #"^( *)([-*+]|\d{1,9}[.)])[ \t]+"#, options: .regularExpression) else { return nil }
            let prefix = line[match]
            let indent = prefix.prefix { $0 == " " }.count
            let ordered = prefix.trimmingCharacters(in: .whitespaces).first?.isNumber == true
            return (indent, ordered, String(line[match.upperBound...]))
        }

        mutating func add(indent: Int, ordered: Bool, content: String) -> String {
            var out = ""
            while let last = stack.last, indent < last.indent {
                out += "</li></\(last.ordered ? "ol" : "ul")>"; stack.removeLast()
            }
            if let last = stack.last, indent > last.indent {
                out += "<\(ordered ? "ol" : "ul")>"; stack.append((indent, ordered))
            } else if let last = stack.last {
                out += "</li>"
                if last.ordered != ordered {
                    out += "</\(last.ordered ? "ol" : "ul")><\(ordered ? "ol" : "ul")>"
                    stack[stack.count - 1].ordered = ordered
                }
            } else {
                out += "<\(ordered ? "ol" : "ul")>"; stack.append((indent, ordered))
            }
            return out + "<li>" + content
        }

        mutating func close() -> String {
            var out = ""
            while let last = stack.popLast() { out += "</li></\(last.ordered ? "ol" : "ul")>" }
            return out
        }
    }

    // MARK: - Inline

    static func inline(_ text: String) -> String {
        var codes: [String] = []
        var links: [String] = []
        // Code spans first, so their contents are not formatted.
        var text = replace(#"`([^`]+)`"#, in: text) { groups in
            codes.append("<code>" + escape(groups[1]) + "</code>")
            return "\u{FFFC}\(codes.count - 1)\u{FFFC}"
        }
        // A "<" that does not start a tag or autolink is text.
        text = replace(#"&(?![A-Za-z]+;|#\d+;)"#, in: text) { _ in "&amp;" }
        text = replace(#"<(?![A-Za-z/!])"#, in: text) { _ in "&lt;" }
        text = replace(#"<(https?://[^>\s]+)>"#, in: text) { groups in "<a href=\"\(groups[1])\">\(groups[1])</a>" }
        text = replace(#"!\[([^\]]*)\]\(([^)\s]+)(?:\s+"[^"]*")?\)"#, in: text) { groups in
            "<img src=\"\(groups[2])\" alt=\"\(groups[1])\">"
        }
        text = replace(#"\[([^\]]+)\]\(([^)\s]+)(?:\s+"[^"]*")?\)"#, in: text) { groups in
            "<a href=\"\(groups[2])\">\(groups[1])</a>"
        }
        text = autolinkURLs(text, links: &links)
        // GFM strikethrough (the Format menu writes <s>, which passes through as HTML).
        text = replace(#"~~(?!\s)(.+?)(?<!\s)~~"#, in: text) { groups in "<del>" + groups[1] + "</del>" }
        text = replace(#"\*\*(.+?)\*\*|__(.+?)__"#, in: text) { groups in "<strong>" + groups[1] + groups[2] + "</strong>" }
        text = replace(#"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?!\*)|(?<![\w_])_(?!\s)(.+?)(?<!\s)_(?![\w_])"#, in: text) { groups in
            "<em>" + groups[1] + groups[2] + "</em>"
        }
        for (index, link) in links.enumerated() { text = text.replacingOccurrences(of: "\u{FFFD}\(index)\u{FFFD}", with: link) }
        for (index, code) in codes.enumerated() { text = text.replacingOccurrences(of: "\u{FFFC}\(index)\u{FFFC}", with: code) }
        return text
    }

    /// 自動リンク：URLだけの文字列（https://・http://・www.）をリンクにする。タグ・リンクの中は変えない。
    /// できたリンクは記号に置き換えておき（強調の _ や * で崩さないため）、最後に戻す
    private static func autolinkURLs(_ text: String, links: inout [String]) -> String {
        var tags: [String] = []
        // Existing links and tags are kept as they are.
        var text = replace(#"(?is)<a\b[^>]*>.*?</a\s*>|<[^>]+>"#, in: text) { groups in
            tags.append(groups[0])
            return "\u{FFFE}\(tags.count - 1)\u{FFFE}"
        }
        // ASCII only, so a URL followed directly by Japanese text ends at the Japanese.
        text = replace(#"(?<![A-Za-z0-9/@.\-])(?:https?://|www\.)[A-Za-z0-9\-._~:/?#\[\]@!$&'()*+,;=%]+"#, in: text) { groups in
            var url = groups[0]
            var trailing = ""
            // Punctuation at the end belongs to the sentence; a ")" only when it is not balanced.
            while let last = url.last {
                if ".,:;!?'\"*_~".contains(last) || (last == ")" && url.filter({ $0 == ")" }).count > url.filter({ $0 == "(" }).count) {
                    trailing = String(last) + trailing
                    url.removeLast()
                } else { break }
            }
            guard url.contains(".") || url.hasPrefix("http"), !url.hasSuffix("://") else { return groups[0] }
            let href = url.hasPrefix("www.") ? "http://" + url : url
            links.append("<a href=\"\(href.replacingOccurrences(of: "\"", with: "%22"))\">\(url)</a>")
            return "\u{FFFD}\(links.count - 1)\u{FFFD}" + trailing
        }
        for (index, tag) in tags.enumerated() { text = text.replacingOccurrences(of: "\u{FFFE}\(index)\u{FFFE}", with: tag) }
        return text
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func replace(_ pattern: String, in text: String, _ transform: ([String]) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let string = NSMutableString(string: text)
        let source = text as NSString
        for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)).reversed() {
            let groups = (0..<match.numberOfRanges).map { index -> String in
                let range = match.range(at: index)
                return range.location == NSNotFound ? "" : source.substring(with: range)
            }
            string.replaceCharacters(in: match.range, with: transform(groups))
        }
        return string as String
    }
}
