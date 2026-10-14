import Foundation

/// 原稿に混ざったHTMLをMarkdownに置き換える。Markdownで書かれた部分とコードブロック（```・~~~）はそのまま。
/// 見出し・段落・改行・強調・リンク・画像・リスト・引用・コード・区切り線を変換し、そのほかのタグは外して中身を残す
enum HTMLToMarkdown {
    /// keep: 中を変換せずそのまま残す要素（"div"・"table"。入れ子を含む）
    static func convert(_ text: String, keep: Set<String> = []) -> String {
        // Fenced code blocks pass through untouched; only the text between them is converted.
        var output: [String] = []
        var chunk: [String] = []
        var fence: String?
        func flush() {
            if !chunk.isEmpty { output.append(convertChunk(chunk.joined(separator: "\n"), keep: keep)); chunk = [] }
        }
        for line in text.normalizedLineBreaks.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let open = fence {
                output.append(line)
                if trimmed.hasPrefix(open) { fence = nil }
            } else if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                flush()
                fence = String(trimmed.prefix(3))
                output.append(line)
            } else {
                chunk.append(line)
            }
        }
        flush()
        return output.joined(separator: "\n")
    }

    private static func convertChunk(_ source: String, keep: Set<String>) -> String {
        guard source.range(of: "<[a-zA-Z/!]", options: .regularExpression) != nil else { return source }
        var text = source
        // <pre> keeps its contents verbatim; protect them from the inline rules with placeholders.
        var preserved: [String] = []
        if !keep.isEmpty {
            // Each outermost kept element (<div>…</div>, <table>…</table>) stays exactly as written, in place.
            let string = NSMutableString(string: text)
            for range in elementRanges(keep, in: text).reversed() {
                preserved.append(string.substring(with: range))
                string.replaceCharacters(in: range, with: "\u{FFFC}\(preserved.count - 1)\u{FFFC}")
            }
            text = string as String
        }
        text = replace(#"<pre\b[^>]*>(?:\s*<code\b[^>]*>)?([\s\S]*?)(?:</code>\s*)?</pre>"#, in: text) { groups in
            preserved.append("```\n" + decode(groups[1]).trimmingCharacters(in: .newlines) + "\n```")
            return "\n\n\u{FFFC}\(preserved.count - 1)\u{FFFC}\n\n"
        }
        // Block elements.
        text = replace(#"<h([1-6])\b[^>]*>([\s\S]*?)</h\1\s*>"#, in: text) { groups in
            "\n\n" + String(repeating: "#", count: Int(groups[1]) ?? 1) + " " + oneLine(inline(groups[2])) + "\n\n"
        }
        text = replace(#"<blockquote\b[^>]*>([\s\S]*?)</blockquote>"#, in: text) { groups in
            let body = inline(blocks(groups[1])).trimmingCharacters(in: .whitespacesAndNewlines)
            return "\n\n" + body.components(separatedBy: "\n").map { $0.isEmpty ? ">" : "> " + $0 }.joined(separator: "\n") + "\n\n"
        }
        text = replace(#"<ol\b[^>]*>([\s\S]*?)</ol>"#, in: text) { groups in
            var number = 0
            let items = replace(#"<li\b[^>]*>([\s\S]*?)(?:</li>|(?=<li\b)|$)"#, in: groups[1]) { item in
                number += 1
                return "\n\(number). " + oneLine(inline(item[1]))
            }
            return "\n\n" + strip(items).trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n"
        }
        text = replace(#"<ul\b[^>]*>([\s\S]*?)</ul>"#, in: text) { groups in
            let items = replace(#"<li\b[^>]*>([\s\S]*?)(?:</li>|(?=<li\b)|$)"#, in: groups[1]) { item in
                "\n- " + oneLine(inline(item[1]))
            }
            return "\n\n" + strip(items).trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n"
        }
        text = blocks(text)
        text = inline(text)
        text = strip(text)
        text = decode(text)
        for (index, block) in preserved.enumerated() {
            text = text.replacingOccurrences(of: "\u{FFFC}\(index)\u{FFFC}", with: block)
        }
        // Tidy: no trailing spaces on lines, at most one blank line in a row, no blank lines at the ends.
        text = replace(#"[ \t]+\n"#, in: text) { _ in "\n" }
        text = replace(#"\n{3,}"#, in: text) { _ in "\n\n" }
        let leading = String(source.prefix { $0 == "\n" }), trailing = String(source.reversed().prefix { $0 == "\n" })
        return leading + text.trimmingCharacters(in: .newlines) + trailing
    }

    /// いちばん外側の要素の範囲（入れ子を数える。div の中の table などもまとめて1つ）。閉じていなければ末尾まで
    private static func elementRanges(_ names: Set<String>, in text: String) -> [NSRange] {
        let alternatives = names.sorted().joined(separator: "|")
        guard let regex = try? NSRegularExpression(pattern: "<(/?)(?:" + alternatives + #")\b[^>]*>"#, options: .caseInsensitive) else { return [] }
        let length = (text as NSString).length
        var ranges: [NSRange] = []
        var depth = 0, start = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: length)) {
            let closing = match.range(at: 1).length > 0
            if !closing {
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

    /// 段落・div・改行・区切り線を空行と改行にする
    private static func blocks(_ text: String) -> String {
        var text = replace(#"<br\s*/?>"#, in: text) { _ in "\n" }
        text = replace(#"<hr\b[^>]*>"#, in: text) { _ in "\n\n---\n\n" }
        text = replace(#"</?(?:p|div|section|article|header|footer|table|tr)\b[^>]*>"#, in: text) { _ in "\n\n" }
        return text
    }

    /// 強調・コード・リンク・画像
    private static func inline(_ text: String) -> String {
        var text = replace(#"<img\b([^>]*)>"#, in: text) { groups in
            "![" + (attribute("alt", in: groups[1]) ?? "") + "](" + (attribute("src", in: groups[1]) ?? "") + ")"
        }
        text = replace(#"<a\b([^>]*)>([\s\S]*?)</a>"#, in: text) { groups in
            guard let href = attribute("href", in: groups[1]) else { return groups[2] }
            return "[" + oneLine(groups[2]) + "](" + href + ")"
        }
        text = replace(#"<(strong|b)\b[^>]*>([\s\S]*?)</\1>"#, in: text) { groups in "**" + groups[2] + "**" }
        text = replace(#"<(em|i)\b[^>]*>([\s\S]*?)</\1>"#, in: text) { groups in "*" + groups[2] + "*" }
        text = replace(#"<code\b[^>]*>([\s\S]*?)</code>"#, in: text) { groups in "`" + groups[1] + "`" }
        return text
    }

    /// 残ったタグ（span など）を外す。<https://…> のような自動リンクは残す
    private static func strip(_ text: String) -> String {
        replace(#"</?[a-zA-Z][a-zA-Z0-9-]*(?:\s[^>]*)?/?>"#, in: text) { _ in "" }
    }

    private static func oneLine(_ text: String) -> String {
        strip(text).replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func attribute(_ name: String, in attributes: String) -> String? {
        let pattern = "\\b" + name + #"\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: attributes, range: NSRange(attributes.startIndex..., in: attributes)) else { return nil }
        for group in 1...3 {
            if let range = Range(match.range(at: group), in: attributes) { return String(attributes[range]) }
        }
        return nil
    }

    static func decode(_ text: String) -> String {
        var text = text
        for (entity, character) in [("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"), ("&amp;", "&")] {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        return text
    }

    /// 正規表現の一致を後ろから順に置き換える。groups[0]は一致全体、見つからないグループは空文字
    private static func replace(_ pattern: String, in text: String, _ transform: ([String]) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return text }
        let string = NSMutableString(string: text)
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: string.length))
        // Evaluate front to back (numbering in <ol>), then substitute back to front so ranges stay valid.
        let replacements = matches.map { match in
            (match.range, transform((0..<match.numberOfRanges).map { index in
                let range = match.range(at: index)
                return range.location == NSNotFound ? "" : (text as NSString).substring(with: range)
            }))
        }
        for (range, replacement) in replacements.reversed() { string.replaceCharacters(in: range, with: replacement) }
        return string as String
    }
}
