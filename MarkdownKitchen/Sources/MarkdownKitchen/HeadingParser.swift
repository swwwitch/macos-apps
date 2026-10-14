import Foundation

/// Markdownの見出し1件。rangeは原稿（UTF-16）での見出し行の位置
struct Heading: Identifiable, Equatable {
    let id: Int
    let level: Int
    let title: String
    let range: NSRange
    /// Setextの下線（=・-）の行。ATXはnil
    var underline: NSRange? = nil
    /// HTMLの見出し（<h2>…</h2>）で、開始タグと終了タグのレベルの数字の位置
    var htmlLevelDigits: [NSRange]? = nil
}

/// 原稿から見出しを抜き出す。ATX（# 見出し）・Setext（下線の=・-）・行頭のHTML見出し（<h1>〜<h6>）に対応し、
/// コードブロック・YAMLフロントマター・HTMLコメントの中は見出しとみなさない
enum HeadingParser {
    static func headings(in text: String) -> [Heading] {
        let lines = splitLines(text)
        let string = text as NSString
        var result: [Heading] = []
        var index = 0
        // YAML front matter: only at the very first line.
        if let first = lines.first, first.text.trimmingCharacters(in: .whitespaces) == "---" {
            if let end = lines.dropFirst().firstIndex(where: { ["---", "..."].contains($0.text.trimmingCharacters(in: .whitespaces)) }) {
                index = end + 1
            }
        }
        var fence: (marker: Character, count: Int)?
        var inComment = false
        while index < lines.count {
            let line = lines[index]
            defer { index += 1 }
            if inComment {
                if line.text.contains("-->") { inComment = false }
                continue
            }
            if let open = fence {
                if let close = fenceMarker(line.text), close.marker == open.marker, close.count >= open.count,
                   close.rest.trimmingCharacters(in: .whitespaces).isEmpty {
                    fence = nil
                }
                continue
            }
            if let marker = fenceMarker(line.text) {
                fence = (marker.marker, marker.count)
                continue
            }
            let trimmed = line.text.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("<!--") {
                if !trimmed.contains("-->") { inComment = true }
                continue
            }
            if let html = htmlHeading(in: string, lines: lines, at: index) {
                result.append(Heading(id: index, level: html.level, title: html.title, range: html.range, htmlLevelDigits: html.digits))
                index = html.lastLine // The closing tag may be on a later line.
                continue
            }
            if let (level, title) = atx(line.text) {
                result.append(Heading(id: index, level: level, title: title, range: line.range))
                continue
            }
            if index + 1 < lines.count, let level = setextLevel(lines[index + 1].text), canBeSetextTitle(line.text) {
                result.append(Heading(id: index, level: level, title: trimmed, range: line.range, underline: lines[index + 1].range))
                index += 1 // The underline belongs to this heading.
            }
        }
        return result
    }

    /// 見出しを書き出す形式
    enum Format: String, CaseIterable {
        /// markdownSpaced: レベルが変わるところに空行を入れる（同じレベルが続く間は詰める）
        /// tree: いちばん浅いレベルを基準に、深い見出しへ「└ 」（さらに深いと全角スペースで字下げ）
        /// simpleTOC: いちばん浅いレベルに「1. 」の通し番号、深い見出しは全角スペースで字下げ（記号なし）
        case markdown, markdownSpaced, tree, simpleTOC, indented
    }

    static func render(_ headings: [Heading], format: Format) -> String {
        var lines: [String] = []
        let base = headings.map(\.level).min() ?? 1
        for (index, heading) in headings.enumerated() {
            switch format {
            case .markdown, .markdownSpaced:
                if format == .markdownSpaced, index > 0, headings[index - 1].level != heading.level { lines.append("") }
                lines.append(String(repeating: "#", count: heading.level) + " " + heading.title)
            case .tree:
                let depth = heading.level - base
                lines.append(depth == 0 ? heading.title : String(repeating: "\u{3000}", count: depth - 1) + "└ " + heading.title)
            case .simpleTOC:
                lines.append(simpleTOCPrefix(headings, index: index, base: base) + heading.title)
            case .indented:
                lines.append(String(repeating: "\t", count: heading.level - 1) + heading.title)
            }
        }
        return lines.joined(separator: "\n")
    }

    /// シンプル目次の行頭：いちばん浅いレベルは「n. 」、深い見出しは深さの分の全角スペース
    static func simpleTOCPrefix(_ headings: [Heading], index: Int, base: Int) -> String {
        let depth = headings[index].level - base
        if depth > 0 { return String(repeating: "\u{3000}", count: depth) }
        let number = headings[...index].filter { $0.level == base }.count
        return "\(number). "
    }

    /// 見出しを1段上げ（delta = -1）・下げ（+1）たときの置き換え。範囲は後ろから順に並べる。
    /// Setextの見出しはATXに書き換え、HTMLの見出しはタグの数字（<h2>…</h2>）だけを変える。1〜6を超える見出しがあればnil
    static func shiftEdits(_ headings: [Heading], by delta: Int, in text: String) -> [(range: NSRange, text: String)]? {
        guard headings.allSatisfy({ (1...6).contains($0.level + delta) }) else { return nil }
        let string = text as NSString
        let edits: [(range: NSRange, text: String)] = headings.flatMap { heading -> [(range: NSRange, text: String)] in
            let marks = String(repeating: "#", count: heading.level + delta)
            if let digits = heading.htmlLevelDigits {
                return digits.map { ($0, String(heading.level + delta)) }
            }
            if let underline = heading.underline {
                let whole = NSRange(location: heading.range.location, length: NSMaxRange(underline) - heading.range.location)
                return [(whole, marks + " " + heading.title)]
            }
            // Keep the indent, the title and any closing sequence; change only the opening #s.
            let line = string.substring(with: heading.range)
            let indent = line.prefix { $0 == " " }.count
            return [(NSRange(location: heading.range.location + indent, length: heading.level), marks)]
        }
        return edits.sorted { $0.range.location > $1.range.location }
    }

    // MARK: - HTML headings

    /// 行頭（空白3個まで）の <hN …> から対応する </hN> まで。空行を越えては探さない
    private static let htmlPattern = try! NSRegularExpression(
        pattern: "<h([1-6])(?=[\\s>/])[^>]*>([\\s\\S]*?)</h(\\1)\\s*>", options: [.caseInsensitive])
    private static let tagPattern = try! NSRegularExpression(pattern: "<[^>]*>")
    private static let spacePattern = try! NSRegularExpression(pattern: "\\s+")

    private static func htmlHeading(in string: NSString, lines: [Line], at index: Int)
        -> (level: Int, title: String, range: NSRange, digits: [NSRange], lastLine: Int)? {
        let line = lines[index]
        guard let body = dropIndent(line.text), body.lowercased().hasPrefix("<h") else { return nil }
        var last = index
        while last + 1 < lines.count, last - index < 50,
              !lines[last + 1].text.trimmingCharacters(in: .whitespaces).isEmpty { last += 1 }
        let start = line.range.location + (line.text.count - body.count)
        let block = NSRange(location: start, length: NSMaxRange(lines[last].range) - start)
        guard let match = htmlPattern.firstMatch(in: string as String, options: [.anchored], range: block),
              let level = Int(string.substring(with: match.range(at: 1))) else { return nil }
        let end = NSMaxRange(match.range)
        let endLine = (index...last).first { NSMaxRange(lines[$0].range) >= end } ?? last
        let range = NSRange(location: line.range.location, length: NSMaxRange(lines[endLine].range) - line.range.location)
        return (level, plainTitle(string.substring(with: match.range(at: 2))), range,
                [match.range(at: 1), match.range(at: 3)], endLine)
    }

    /// タグを外し、主な文字参照を戻し、空白を1つにまとめる
    static func plainTitle(_ html: String) -> String {
        var text = tagPattern.stringByReplacingMatches(in: html, range: NSRange(location: 0, length: (html as NSString).length), withTemplate: "")
        for (entity, character) in [("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&amp;", "&")] {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        text = spacePattern.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length), withTemplate: " ")
        return text.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Lines

    struct Line { let text: String; let range: NSRange }

    /// 改行を除いた行と、その行のUTF-16範囲
    static func splitLines(_ text: String) -> [Line] {
        let string = text as NSString
        var lines: [Line] = []
        var location = 0
        while location < string.length {
            var start = 0, end = 0, contentsEnd = 0
            string.getLineStart(&start, end: &end, contentsEnd: &contentsEnd, for: NSRange(location: location, length: 0))
            let range = NSRange(location: start, length: contentsEnd - start)
            lines.append(Line(text: string.substring(with: range), range: range))
            location = end
        }
        return lines
    }

    // MARK: - Block rules (CommonMark, simplified)

    /// 先頭の空白（3個まで）を除いた残り。4個以上はインデントのコードなのでnil
    private static func dropIndent(_ line: String) -> Substring? {
        let spaces = line.prefix { $0 == " " }.count
        return spaces <= 3 ? line.dropFirst(spaces) : nil
    }

    private static func fenceMarker(_ line: String) -> (marker: Character, count: Int, rest: Substring)? {
        guard let body = dropIndent(line), let marker = body.first, marker == "`" || marker == "~" else { return nil }
        let count = body.prefix { $0 == marker }.count
        guard count >= 3 else { return nil }
        let rest = body.dropFirst(count)
        // A backtick fence's info string may not contain backticks.
        if marker == "`", rest.contains("`") { return nil }
        return (marker, count, rest)
    }

    static func atx(_ line: String) -> (Int, String)? {
        guard let body = dropIndent(line) else { return nil }
        let level = body.prefix { $0 == "#" }.count
        guard (1...6).contains(level) else { return nil }
        let rest = body.dropFirst(level)
        guard rest.isEmpty || rest.first == " " || rest.first == "\t" else { return nil }
        var title = rest.trimmingCharacters(in: .whitespaces)
        // Optional closing sequence: "## Title ##".
        if title.allSatisfy({ $0 == "#" }) {
            title = ""
        } else if let hashes = title.lastIndex(where: { $0 != "#" }), title[hashes] == " " || title[hashes] == "\t",
                  title.index(after: hashes) < title.endIndex {
            title = String(title[..<hashes]).trimmingCharacters(in: .whitespaces)
        }
        return (level, title)
    }

    private static func setextLevel(_ line: String) -> Int? {
        guard let body = dropIndent(line) else { return nil }
        let trimmed = body.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first, first == "=" || first == "-", trimmed.allSatisfy({ $0 == first }) else { return nil }
        return first == "=" ? 1 : 2
    }

    /// 段落の行だけがSetextの見出しになる（リスト・引用・表・区切り線は除く）
    private static func canBeSetextTitle(_ line: String) -> Bool {
        guard let body = dropIndent(line) else { return false }
        let trimmed = body.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, setextLevel(line) == nil else { return false }
        if trimmed.hasPrefix(">") || trimmed.hasPrefix("|") || trimmed.hasPrefix("<") { return false }
        for marker in ["- ", "* ", "+ "] where trimmed.hasPrefix(marker) { return false }
        let digits = trimmed.prefix { $0.isASCII && $0.isNumber }
        if !digits.isEmpty, digits.count <= 9 {
            let after = trimmed.dropFirst(digits.count)
            if after.hasPrefix(". ") || after.hasPrefix(") ") { return false }
        }
        if trimmed.allSatisfy({ $0 == "*" || $0 == "_" || $0 == " " }) { return false }
        return true
    }
}

extension String {
    /// 改行をLFにそろえた文字列。CR+LF、CRだけ（古いMac）、U+2028・U+2029 もLF1つにする。
    /// 原稿欄は CR も改行として表示するので、行で区切る処理はこれを通してから "\n" で分ける
    var normalizedLineBreaks: String {
        guard contains(where: { $0 == "\r" || $0 == "\u{2028}" || $0 == "\u{2029}" }) else { return self }
        return replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n")
    }
}
