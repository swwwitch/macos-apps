import Foundation

/// 左下の行数・文字数
enum TextStats {
    /// 原稿そのままの行数（空行も数える）と文字数（記号・タグ・改行も数える）
    static func raw(_ text: String) -> (lines: Int, characters: Int) {
        (text.isEmpty ? 0 : HeadingParser.splitLines(text).count, text.count)
    }

    /// 実質：プレビューに出る本文だけ。Markdownの記号・HTMLのタグ・空行を除き、文字数に改行は含めない
    static func content(_ markdown: String) -> (lines: Int, characters: Int) {
        let lines = plainText(markdown)
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return (lines.count, lines.reduce(0) { $0 + $1.count })
    }

    /// Markdownを本文だけのテキストにする（プレビューと同じ解釈）
    static func plainText(_ markdown: String) -> String {
        var html = MarkdownHTML.render(markdown)
        html = replace(#"(?is)<!--.*?-->|<(script|style)\b.*?</\1\s*>"#, in: html, with: "")
        // Block boundaries become line breaks; table cells are separated by a space.
        html = replace(#"(?i)<br\s*/?>|</?(p|div|h[1-6]|li|ul|ol|blockquote|pre|tr|table|thead|tbody|hr|dl|dt|dd|section|article|header|footer)\b[^>]*>"#, in: html, with: "\n")
        html = replace(#"(?i)</t[dh]\s*>"#, in: html, with: " ")
        html = replace(#"<[^>]*>"#, in: html, with: "")
        return decodeEntities(html)
    }

    private static func replace(_ pattern: String, in text: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: template)
    }

    private static let entities = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " "]

    private static func decodeEntities(_ text: String) -> String {
        guard text.contains("&"), let regex = try? NSRegularExpression(pattern: #"&(#[xX]?[0-9A-Fa-f]+|[A-Za-z]+);"#) else { return text }
        let source = text as NSString
        var result = ""
        var last = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)) {
            result += source.substring(with: NSRange(location: last, length: match.range.location - last))
            let name = source.substring(with: match.range(at: 1))
            if name.hasPrefix("#") {
                let hex = name.dropFirst().lowercased().hasPrefix("x")
                let digits = name.dropFirst(hex ? 2 : 1)
                if let value = UInt32(digits, radix: hex ? 16 : 10), let scalar = Unicode.Scalar(value) {
                    result.unicodeScalars.append(scalar)
                } else {
                    result += source.substring(with: match.range)
                }
            } else {
                result += entities[name] ?? source.substring(with: match.range)
            }
            last = NSMaxRange(match.range)
        }
        return result + source.substring(from: last)
    }
}
