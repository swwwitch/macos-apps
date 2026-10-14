import Foundation

/// 原稿の整形。コードブロック（```・~~~）の中は変えない
enum MarkdownTidy {
    enum Rule: String, CaseIterable {
        /// 行末の空白を削除（Markdownの改行になる2個以上の空白は、次の行が本文なら2個にそろえて残す）
        case trailingSpaces
        /// 3行以上続く空行を1行に
        case blankLines
        /// リストの記号（* と +）を「-」にそろえる
        case listMarkers
        /// 全角の英数字を半角に
        case halfwidthAlphanumerics
        /// 和欧間のスペース（日本語と半角英数字のあいだの半角スペース）を削除。インラインコードの中は変えない
        case japaneseLatinSpaces
        /// HTMLの部分（行頭がタグで始まり空行までのまとまり）の改行と空白を詰める。「すべて整える」には含めない
        case minifyHTML

        /// 「すべて整える」で実行するもの（Minifyは除く）
        static let standard: [Rule] = allCases.filter { $0 != .minifyHTML }
    }

    /// 日本語の文字（漢字・かな・全角の記号と句読点）
    private static let japanese = #"[\p{Han}\p{Hiragana}\p{Katakana}\x{3000}-\x{303F}\x{30FC}\x{FF01}-\x{FF60}]"#

    static func apply(_ rules: [Rule], to text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        let code = codeLines(lines)
        for rule in rules where rule != .blankLines && rule != .minifyHTML {
            for index in lines.indices where !code.contains(index) {
                let next = index + 1 < lines.count ? lines[index + 1] : ""
                lines[index] = tidy(lines[index], rule: rule, nextLine: next)
            }
        }
        if rules.contains(.minifyHTML) {
            lines = minifyHTML(lines, code: codeLines(lines))
        }
        if rules.contains(.blankLines) {
            var result: [String] = []
            var blanks = 0
            for (index, line) in lines.enumerated() {
                let blank = !code.contains(index) && line.trimmingCharacters(in: .whitespaces).isEmpty
                blanks = blank ? blanks + 1 : 0
                if blanks <= 1 { result.append(line) }
            }
            lines = result
        }
        return lines.joined(separator: "\n")
    }

    private static func tidy(_ line: String, rule: Rule, nextLine: String) -> String {
        switch rule {
        case .trailingSpaces:
            let body = line.replacingOccurrences(of: #"[ \t\x{3000}]+$"#, with: "", options: .regularExpression)
            let spaces = line.count - body.count
            let hardBreak = spaces >= 2 && line.hasSuffix("  ") && !body.isEmpty
                && !nextLine.trimmingCharacters(in: .whitespaces).isEmpty
            return hardBreak ? body + "  " : body
        case .listMarkers:
            // "* * *" is a thematic break, not a list.
            if line.range(of: #"^ *([-*_])( *\1){2,} *$"#, options: .regularExpression) != nil { return line }
            return line.replacingOccurrences(of: #"^( *)[*+]([ \t]+)"#, with: "$1-$2", options: .regularExpression)
        case .halfwidthAlphanumerics:
            return String(String.UnicodeScalarView(line.unicodeScalars.map { scalar in
                // ０-９, Ａ-Ｚ, ａ-ｚ
                switch scalar.value {
                case 0xFF10...0xFF19, 0xFF21...0xFF3A, 0xFF41...0xFF5A: return Unicode.Scalar(scalar.value - 0xFEE0)!
                default: return scalar
                }
            }))
        case .japaneseLatinSpaces:
            // Inline code spans keep their spaces.
            var codes: [String] = []
            var text = line.replacingOccurrences(of: "`[^`]*`", with: "\u{FFFC}", options: .regularExpression)
            if let regex = try? NSRegularExpression(pattern: "`[^`]*`") {
                codes = regex.matches(in: line, range: NSRange(line.startIndex..., in: line)).map { (line as NSString).substring(with: $0.range) }
            }
            text = text.replacingOccurrences(of: "(?<=" + japanese + ") +(?=[A-Za-z0-9])", with: "", options: .regularExpression)
            text = text.replacingOccurrences(of: "(?<=[A-Za-z0-9]) +(?=" + japanese + ")", with: "", options: .regularExpression)
            for code in codes {
                if let range = text.range(of: "\u{FFFC}") { text.replaceSubrange(range, with: code) }
            }
            return text
        case .blankLines, .minifyHTML:
            return line
        }
    }

    /// 行頭がタグで始まるまとまり（空行まで）を1行に詰める。<pre>・<textarea> を含むまとまりは変えない
    private static func minifyHTML(_ lines: [String], code: Set<Int>) -> [String] {
        var result: [String] = []
        var index = 0
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            guard !code.contains(index),
                  trimmed.range(of: #"^<(/?[A-Za-z][A-Za-z0-9-]*[\s/>]|!--)"#, options: .regularExpression) != nil else {
                result.append(lines[index]); index += 1
                continue
            }
            var block: [String] = []
            while index < lines.count, !code.contains(index), !lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                block.append(lines[index]); index += 1
            }
            let joined = block.joined(separator: "\n")
            if joined.range(of: #"<(pre|textarea)\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
                result.append(contentsOf: block)
            } else {
                result.append(minify(joined))
            }
        }
        return result
    }

    static func minify(_ html: String) -> String {
        var text = html.trimmingCharacters(in: .whitespaces)
        // Line breaks between tags carry no meaning; elsewhere they are one space.
        text = text.replacingOccurrences(of: #">[ \t]*\n\s*<"#, with: "><", options: .regularExpression)
        text = text.replacingOccurrences(of: #"[ \t]*\n\s*"#, with: " ", options: .regularExpression)
        // Inside tags: one space between attributes, no padding in style declarations.
        if let tag = try? NSRegularExpression(pattern: #"<[A-Za-z][^>]*>"#) {
            let string = NSMutableString(string: text)
            for match in tag.matches(in: text, range: NSRange(location: 0, length: string.length)).reversed() {
                var inner = string.substring(with: match.range)
                inner = inner.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
                // Only style values lose the padding around ";" and ":" (alt text and URLs keep theirs).
                if let style = try? NSRegularExpression(pattern: #"(style\s*=\s*")([^"]*)(")"#, options: .caseInsensitive) {
                    let tagString = NSMutableString(string: inner)
                    for found in style.matches(in: inner, range: NSRange(location: 0, length: tagString.length)).reversed() {
                        let value = tagString.substring(with: found.range(at: 2))
                            .replacingOccurrences(of: #"\s*([;:])\s*"#, with: "$1", options: .regularExpression)
                        tagString.replaceCharacters(in: found.range(at: 2), with: value)
                    }
                    inner = tagString as String
                }
                inner = inner.replacingOccurrences(of: #"\s*=\s*""#, with: "=\"", options: .regularExpression)
                inner = inner.replacingOccurrences(of: #"\s+(/?>)$"#, with: "$1", options: .regularExpression)
                string.replaceCharacters(in: match.range, with: inner)
            }
            text = string as String
        }
        return text
    }

    /// コードブロックに含まれる行（囲みの行を含む）
    private static func codeLines(_ lines: [String]) -> Set<Int> {
        var result = Set<Int>()
        var fence: String?
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let open = fence {
                result.insert(index)
                if trimmed.hasPrefix(open) { fence = nil }
            } else if let marker = ["```", "~~~"].first(where: { trimmed.hasPrefix($0) }) {
                fence = marker
                result.insert(index)
            }
        }
        return result
    }
}

/// 行の並べ替えと重複の削除（行単位の操作。「すべて整える」には含めない）
enum LineTools {
    /// 同じ内容の行は最初の1行だけ残す。空行はそのまま
    static func removeDuplicates(_ text: String) -> String {
        var seen = Set<String>()
        return map(text) { lines in
            lines.filter { line in
                line.trimmingCharacters(in: .whitespaces).isEmpty || seen.insert(line).inserted
            }
        }
    }

    /// 数字を考えた順（Finderと同じ）で並べ替える
    static func sort(_ text: String, descending: Bool) -> String {
        map(text) { lines in
            let sorted = lines.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            return descending ? sorted.reversed() : sorted
        }
    }

    /// 末尾の改行は行として扱わずに残す
    private static func map(_ text: String, _ transform: ([String]) -> [String]) -> String {
        var lines = text.components(separatedBy: "\n")
        let trailing = lines.count > 1 && lines.last == ""
        if trailing { lines.removeLast() }
        var result = transform(lines).joined(separator: "\n")
        if trailing { result += "\n" }
        return result
    }
}

/// 見出し単位（その見出しから、次の同じか上のレベルの見出しの手前まで）で原稿を並べ替える
enum SectionMover {
    static func sectionRange(of heading: Heading, in all: [Heading], length: Int) -> NSRange {
        let next = all.first { $0.range.location > heading.range.location && $0.level <= heading.level }
        let end = next?.range.location ?? length
        return NSRange(location: heading.range.location, length: end - heading.range.location)
    }

    /// heading の章を target の手前（nil なら末尾）へ移す置き換え。移せない・動かないときはnil
    static func moveEdit(in text: String, all: [Heading], moving heading: Heading, before target: Heading?) -> (range: NSRange, text: String)? {
        let string = text as NSString
        let section = sectionRange(of: heading, in: all, length: string.length)
        let insert = target?.range.location ?? string.length
        // Into itself (or right where it is) means no move.
        guard insert < section.location || insert > NSMaxRange(section) else { return nil }
        let endsWithoutNewline = !text.hasSuffix("\n")
        var body = string.substring(with: section)
        // The last section may lack the blank line that separates it from the next heading.
        if !body.hasSuffix("\n") { body += "\n\n" }
        if insert < section.location {
            var rest = string.substring(with: NSRange(location: insert, length: section.location - insert))
            if NSMaxRange(section) == string.length, endsWithoutNewline {
                // The text now ends with what preceded the moved section.
                while rest.hasSuffix("\n") { rest.removeLast() }
            }
            return (NSRange(location: insert, length: NSMaxRange(section) - insert), body + rest)
        }
        var between = string.substring(with: NSRange(location: NSMaxRange(section), length: insert - NSMaxRange(section)))
        if !between.hasSuffix("\n") { between += "\n\n" }
        if insert == string.length, endsWithoutNewline {
            while body.hasSuffix("\n") { body.removeLast() }
        }
        return (NSRange(location: section.location, length: insert - section.location), between + body)
    }
}

/// 見出しから箇条書きの目次を作る。いちばん浅いレベルを字下げなしにし、深くなるごとに2文字下げる
enum TableOfContents {
    static func make(_ headings: [Heading]) -> String {
        let base = headings.map(\.level).min() ?? 1
        return headings.map { String(repeating: "  ", count: $0.level - base) + "- " + $0.title }.joined(separator: "\n")
    }
}
