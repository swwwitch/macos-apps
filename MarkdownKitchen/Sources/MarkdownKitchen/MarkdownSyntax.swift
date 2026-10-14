import Foundation

/// 原稿の色分け（Markdownの記法ごとの範囲）。後に並ぶものほど優先し、コードは最後に上書きする。
/// HTMLは見出し（<h2>…</h2>）だけMarkdownの見出しと同じに扱い、<div>・<table> の中は色を付けない（MacDown と同じくMarkdownだけを色分け）
enum MarkdownSyntax {
    enum Style: Equatable {
        case heading, markup, strong, emphasis, link, linkTarget, comment, quote, listMarker, rule, code
    }

    struct Span: Equatable {
        let range: NSRange
        let style: Style
    }

    static func spans(in text: String, headings: [Heading]) -> [Span] {
        let string = text as NSString
        let whole = NSRange(location: 0, length: string.length)
        var spans: [Span] = []
        func add(_ pattern: NSRegularExpression, _ style: Style, group: Int = 0) {
            for match in pattern.matches(in: text, range: whole) {
                let range = match.range(at: group)
                if range.location != NSNotFound, range.length > 0 { spans.append(Span(range: range, style: style)) }
            }
        }

        add(quote, .quote)
        add(listMarker, .listMarker, group: 1)
        add(rule, .rule)
        for heading in headings {
            spans.append(Span(range: heading.range, style: .heading))
            if let underline = heading.underline { spans.append(Span(range: underline, style: .markup)) }
            // An HTML heading's tags are dimmed like the #s of a Markdown heading.
            if heading.htmlLevelDigits != nil {
                let line = string.substring(with: heading.range)
                for match in htmlTag.matches(in: line, range: NSRange(location: 0, length: (line as NSString).length)) {
                    spans.append(Span(range: NSRange(location: heading.range.location + match.range.location, length: match.range.length), style: .markup))
                }
            }
            // The opening #s of an ATX heading are dimmed.
            if heading.underline == nil, heading.htmlLevelDigits == nil {
                let line = string.substring(with: heading.range) as NSString
                let marks = line.range(of: #"^ {0,3}#{1,6}"#, options: .regularExpression)
                if marks.location != NSNotFound {
                    spans.append(Span(range: NSRange(location: heading.range.location + marks.location, length: marks.length), style: .markup))
                }
            }
        }
        add(strong, .strong)
        add(emphasis, .emphasis)
        add(link, .link)
        add(linkTarget, .linkTarget, group: 1)
        add(autolink, .link)
        add(comment, .comment)
        add(inlineCode, .code)
        // Fenced code blocks last: nothing inside them is Markdown.
        for range in codeBlocks(string) { spans.append(Span(range: range, style: .code)) }
        // Inside <div> and <table> (with nesting) nothing is colored.
        let ignored = ignoredElements(text)
        guard !ignored.isEmpty else { return spans }
        return spans.filter { span in !ignored.contains { NSIntersectionRange($0, span.range).length > 0 } }
    }

    /// いちばん外側の <div>〜</div>・<table>〜</table>（入れ子を数える。閉じていなければ末尾まで）
    static func ignoredElements(_ text: String) -> [NSRange] {
        let length = (text as NSString).length
        var ranges: [NSRange] = []
        var depth = 0, start = 0
        for match in blockTag.matches(in: text, range: NSRange(location: 0, length: length)) {
            if match.range(at: 1).length == 0 {
                if depth == 0 { start = match.range.location }
                depth += 1
            } else if depth > 0 {
                depth -= 1
                if depth == 0 { ranges.append(NSRange(location: start, length: NSMaxRange(match.range) - start)) }
            }
        }
        if depth > 0 { ranges.append(NSRange(location: start, length: length - start)) }
        return ranges
    }

    /// ```・~~~ で囲んだ範囲（囲みの行を含む）
    static func codeBlocks(_ string: NSString) -> [NSRange] {
        var blocks: [NSRange] = []
        var open: (marker: String, start: Int)?
        var location = 0
        while location < string.length {
            let line = string.lineRange(for: NSRange(location: location, length: 0))
            let trimmed = string.substring(with: line).trimmingCharacters(in: .whitespacesAndNewlines)
            if let current = open {
                if trimmed.hasPrefix(current.marker) {
                    blocks.append(NSRange(location: current.start, length: NSMaxRange(line) - current.start))
                    open = nil
                }
            } else if let marker = ["```", "~~~"].first(where: { trimmed.hasPrefix($0) }) {
                open = (marker, line.location)
            }
            location = NSMaxRange(line)
        }
        if let current = open { blocks.append(NSRange(location: current.start, length: string.length - current.start)) }
        return blocks
    }

    private static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
    }
    private static let quote = regex(#"^ {0,3}>.*$"#)
    private static let listMarker = regex(#"^[ \t]*([-*+]|\d{1,9}[.)])(?=[ \t])"#)
    private static let rule = regex(#"^ {0,3}([-*_])( *\1){2,} *$"#)
    private static let htmlTag = regex(#"</?[A-Za-z][A-Za-z0-9-]*(?:\s[^<>]*)?/?>"#)
    private static let blockTag = try! NSRegularExpression(pattern: #"<(/?)(?:div|table)\b[^>]*>"#, options: .caseInsensitive)
    private static let strong = regex(#"(\*\*|__)(?=\S)[^\n]+?(?<=\S)\1"#)
    private static let emphasis = regex(#"(?<![*\w])\*(?![\s*])[^*\n]+?(?<![\s*])\*(?!\*)|(?<![_\w])_(?![\s_])[^_\n]+?(?<![\s_])_(?![_\w])"#)
    private static let link = regex(#"!?\[[^\]\n]*\]\([^)\n]*\)"#)
    private static let linkTarget = regex(#"\]\(([^)\n]*)\)"#)
    private static let autolink = regex(#"<(?:https?://|mailto:)[^>\s]+>"#)
    private static let comment = try! NSRegularExpression(pattern: #"<!--[\s\S]*?-->"#)
    private static let inlineCode = regex(#"`[^`\n]+`"#)
}
