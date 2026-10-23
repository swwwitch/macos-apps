import Foundation

/// 原稿の整形。コードブロック（```・~~~）の中は変えない
enum MarkdownTidy {
    enum Rule: String, CaseIterable {
        /// 行末の空白を削除（Markdownの改行になる2個以上の空白は、次の行が本文なら2個にそろえて残す）
        case trailingSpaces
        /// 行頭のスペース・タブ（全角スペースも）を削除。フェンス付きコード・<pre>の中は残す
        case leadingSpaces
        /// スペース・タブだけの行を空行にする
        case whitespaceLines
        /// 3行以上続く空行を1行に
        case blankLines
        /// 空行をすべて削除（コードブロックの中は残す）。「すべて整える」には含めない
        case removeBlankLines
        /// 見出し・リストの記号のあとにスペースを入れる（##見出し → ## 見出し、-項目 → - 項目、1.項目 → 1. 項目）
        case markerSpaces
        /// リストの記号（* と +）を「-」にそろえる
        case listMarkers
        /// 全角の英数字を半角に
        case halfwidthAlphanumerics
        /// 和欧間のスペース（日本語と半角英数字のあいだの半角スペース）を削除。インラインコードの中は変えない
        case japaneseLatinSpaces
        /// twitter.com（www.・mobile. も）を x.com に。「すべて整える」には含めない
        case twitterToX
        /// URLの utm_ で始まるパラメーター（utm_source など）を削除。「すべて整える」には含めない
        case removeUTM
        /// HTMLの部分（行頭がタグで始まり空行までのまとまり）の改行と空白を詰める。「すべて整える」には含めない
        case minifyHTML

        /// 「すべて整える」で実行するもの（Minify・空行を削除・x.comへの置き換え・utmパラメーターの削除は除く）
        static let standard: [Rule] = allCases.filter { ![.minifyHTML, .removeBlankLines, .twitterToX, .removeUTM].contains($0) }
    }

    /// 日本語の文字（漢字・かな・全角の記号と句読点）
    private static let japanese = #"[\p{Han}\p{Hiragana}\p{Katakana}\x{3000}-\x{303F}\x{30FC}\x{FF01}-\x{FF60}]"#

    static func apply(_ rules: [Rule], to text: String) -> String {
        var lines = text.normalizedLineBreaks.components(separatedBy: "\n")
        let code = codeLines(lines)
        if rules.contains(.leadingSpaces) { lines = removeLeadingSpaces(lines, code: code) }
        for rule in rules where ![.blankLines, .removeBlankLines, .minifyHTML, .leadingSpaces].contains(rule) {
            for index in lines.indices where !code.contains(index) {
                let next = index + 1 < lines.count ? lines[index + 1] : ""
                lines[index] = tidy(lines[index], rule: rule, nextLine: next)
            }
        }
        if rules.contains(.minifyHTML) {
            lines = minifyHTML(lines, code: codeLines(lines))
        }
        if rules.contains(.blankLines) || rules.contains(.removeBlankLines) {
            let limit = rules.contains(.removeBlankLines) ? 0 : 1
            var result: [String] = []
            var blanks = 0
            for (index, line) in lines.enumerated() {
                let blank = !code.contains(index) && line.trimmingCharacters(in: .whitespaces).isEmpty
                blanks = blank ? blanks + 1 : 0
                if blanks <= limit { result.append(line) }
            }
            lines = result
        }
        return lines.joined(separator: "\n")
    }

    /// URLから utm_ で始まるパラメーターを外す。ほかのパラメーター・#以降・閉じかっこ（リンクの終わり）はそのまま
    static func removingUTM(_ url: String) -> String {
        guard let question = url.firstIndex(of: "?") else { return url }
        let rest = url[url.index(after: question)...]
        let tailStart = rest.firstIndex(where: { "#)".contains($0) }) ?? rest.endIndex
        let query = String(rest[..<tailStart])
        // In HTML, parameters are separated by "&amp;".
        let separator = query.contains("&amp;") ? "&amp;" : "&"
        let kept = query.components(separatedBy: separator).filter { !$0.lowercased().hasPrefix("utm_") && !$0.isEmpty }
        let base = String(url[..<question])
        return base + (kept.isEmpty ? "" : "?" + kept.joined(separator: separator)) + String(rest[tailStart...])
    }

    private static func tidy(_ line: String, rule: Rule, nextLine: String) -> String {
        switch rule {
        case .trailingSpaces:
            let body = line.replacingOccurrences(of: #"[ \t\x{3000}]+$"#, with: "", options: .regularExpression)
            let spaces = line.count - body.count
            let hardBreak = spaces >= 2 && line.hasSuffix("  ") && !body.isEmpty
                && !nextLine.trimmingCharacters(in: .whitespaces).isEmpty
            return hardBreak ? body + "  " : body
        case .twitterToX:
            // Other subdomains (api.twitter.com) and look-alikes (nottwitter.com) are left alone.
            return line.replacingOccurrences(of: #"(?i)(?<![\w.\-])(?:www\.|mobile\.)?twitter\.com(?![\w\-])"#, with: "x.com", options: .regularExpression)
        case .markerSpaces:
            // Headings: "#" to "######" right before the text.
            if line.range(of: #"^ {0,3}#{1,6}[^\s#]"#, options: .regularExpression) != nil {
                return line.replacingOccurrences(of: #"^( {0,3}#{1,6})"#, with: "$1 ", options: .regularExpression)
            }
            // Bullets: not "---", "**bold**" or "*italic*", and not "-5" (a number).
            if line.range(of: #"^\s*[-+][^\s\d\-+]"#, options: .regularExpression) != nil
                || (line.range(of: #"^\s*\*[^\s*]"#, options: .regularExpression) != nil
                    && line.trimmingCharacters(in: .whitespaces).dropFirst().contains("*") == false) {
                return line.replacingOccurrences(of: #"^(\s*[-+*])"#, with: "$1 ", options: .regularExpression)
            }
            // Numbered: "1.項目" but not "1.5" or "2026.10.15".
            if line.range(of: #"^\s*\d{1,9}[.)][^\s\d.)]"#, options: .regularExpression) != nil {
                return line.replacingOccurrences(of: #"^(\s*\d{1,9}[.)])"#, with: "$1 ", options: .regularExpression)
            }
            return line
        case .removeUTM:
            guard line.range(of: "utm_", options: .caseInsensitive) != nil,
                  let regex = try? NSRegularExpression(pattern: #"https?://[^\s<>"'\]]+"#) else { return line }
            let result = NSMutableString(string: line)
            for match in regex.matches(in: line, range: NSRange(location: 0, length: (line as NSString).length)).reversed() {
                result.replaceCharacters(in: match.range, with: removingUTM((line as NSString).substring(with: match.range)))
            }
            return result as String
        case .whitespaceLines:
            return line.trimmingCharacters(in: CharacterSet(charactersIn: " \t\u{3000}")).isEmpty ? "" : line
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
        case .blankLines, .removeBlankLines, .minifyHTML, .leadingSpaces:
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
    /// 明示的な削除操作なので、4スペースの字下げやリストの字下げも削除する。
    private static func removeLeadingSpaces(_ lines: [String], code: Set<Int>) -> [String] {
        var result = lines
        var inPre = false
        for (index, line) in lines.enumerated() {
            if code.contains(index) { continue }
            if inPre || line.range(of: "<pre", options: .caseInsensitive) != nil {
                inPre = line.range(of: "</pre>", options: .caseInsensitive) == nil
                continue
            }
            result[index] = line.replacingOccurrences(of: #"^[ \t\x{3000}]+"#, with: "", options: .regularExpression)
        }
        return result
    }

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
    /// 「divブロックで囲む」の囲みの見た目（設定の「テーマ」タブ）。キーと初期値
    enum DivBox {
        static let backgroundKey = "markdownKitchen.divBackground"
        static let paddingKey = "markdownKitchen.divPadding"
        static let radiusKey = "markdownKitchen.divRadius"
        static let marginKey = "markdownKitchen.divMarginBottom"
        static let defaultBackground = "#efefef"
        static let defaultPadding = "1px 20px 15px"
        static let defaultRadius = "5px"
        static let defaultMargin = "1em"

        static func value(_ key: String, _ fallback: String) -> String {
            let value = UserDefaults.standard.string(forKey: key)?.trimmingCharacters(in: .whitespaces) ?? ""
            return value.isEmpty ? fallback : value
        }
    }

    /// 「divブロックで囲む」の開始タグ
    static var divOpen: String {
        let style = [
            "background-color: " + DivBox.value(DivBox.backgroundKey, DivBox.defaultBackground),
            "padding: " + DivBox.value(DivBox.paddingKey, DivBox.defaultPadding),
            "border-radius: " + DivBox.value(DivBox.radiusKey, DivBox.defaultRadius),
            "margin-bottom: " + DivBox.value(DivBox.marginKey, DivBox.defaultMargin),
        ].joined(separator: "; ") + ";"
        return "<div style=\"\(style.replacingOccurrences(of: "\"", with: "'"))\">"
    }

    /// divブロックで囲む：選択したMarkdownをHTMLにし、divで囲んでMinifyする（1行のHTMLになる）
    static func wrapInDiv(_ text: String) -> String {
        let trailingNewline = text.normalizedLineBreaks.hasSuffix("\n")
        // Blank lines would split the block, and Minify works on one block at a time.
        let html = MarkdownHTML.render(text).components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let open = divOpen
        let wrapped = ([open] + html + ["</div>"]).joined(separator: "\n")
        // Line breaks next to block tags would be left as spaces ("<li>a </li>").
        var minified = MarkdownTidy.apply([.minifyHTML], to: wrapped)
            .replacingOccurrences(of: #"\s+(</(?:p|li|ul|ol|h[1-6]|blockquote|pre|table|thead|tbody|tr|td|th|div)>)"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"(<(?:p|li|ul|ol|h[1-6]|blockquote|table|thead|tbody|tr|td|th)\b[^>]*>)\s+"#, with: "$1", options: .regularExpression)
        // The div keeps its style as written ("; " and ": "); Minify only joins the lines inside.
        if let end = minified.firstIndex(of: ">") { minified = open + minified[minified.index(after: end)...] }
        return minified + (trailingNewline ? "\n" : "")
    }

    /// 同じ内容の行は最初の1行だけ残す。空行はそのまま
    static func removeDuplicates(_ text: String) -> String {
        var seen = Set<String>()
        return map(text) { lines in
            lines.filter { line in
                line.trimmingCharacters(in: .whitespaces).isEmpty || seen.insert(line).inserted
            }
        }
    }

    /// 段落の中の改行を消してつなぐ。前後がどちらも英数字・英語の記号なら半角スペースを1つ挟む。
    /// 空行（段落の区切り）とコードブロックの中はそのまま
    static func joinLines(_ text: String) -> String {
        var lines = text.normalizedLineBreaks.components(separatedBy: "\n")
        let trailing = lines.count > 1 && lines.last == ""
        if trailing { lines.removeLast() }
        var result: [String] = []
        var fence: String?
        var joinable = false  // The last line in result can take the next one.
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let open = fence {
                result.append(line)
                if trimmed.hasPrefix(open) { fence = nil }
                continue
            }
            if let marker = ["```", "~~~"].first(where: { trimmed.hasPrefix($0) }) {
                fence = marker
                result.append(line)
                joinable = false
                continue
            }
            if trimmed.isEmpty {
                result.append(line)
                joinable = false
                continue
            }
            if joinable, let last = result.last {
                let head = last.replacingOccurrences(of: #"[ \t\x{3000}]+$"#, with: "", options: .regularExpression)
                let tail = line.replacingOccurrences(of: #"^[ \t\x{3000}]+"#, with: "", options: .regularExpression)
                result[result.count - 1] = head + (needsSpace(head.last, tail.first) ? " " : "") + tail
            } else {
                result.append(line)
                joinable = true
            }
        }
        var joined = result.joined(separator: "\n")
        if trailing { joined += "\n" }
        return joined
    }

    /// Markdownの要素（見出し・段落・リスト・引用・コード・表・HTML・水平線）が空行なしで隣り合うところに空行を入れる。
    /// 見出しと水平線は前後とも。同じ段落・リスト・引用・表の行どうし、コードブロックの中、Setextの下線の前には入れない
    static func separateBlocks(_ text: String) -> String {
        enum Kind { case heading, rule, code, list, quote, table, html, text }
        var lines = text.normalizedLineBreaks.components(separatedBy: "\n")
        let trailing = lines.count > 1 && lines.last == ""
        if trailing { lines.removeLast() }
        var result: [String] = []
        var previous: Kind?  // Kind of the last non-blank line, nil after a blank line.
        var fence: String?
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let open = fence {
                result.append(line)
                if trimmed.hasPrefix(open) { fence = nil; previous = .code }
                continue
            }
            if trimmed.isEmpty {
                result.append(line)
                previous = nil
                continue
            }
            let kind: Kind
            let indented = line.hasPrefix("  ") || line.hasPrefix("\t")
            if let marker = ["```", "~~~"].first(where: { trimmed.hasPrefix($0) }) {
                fence = marker
                kind = .code
            } else if previous == .text, trimmed.range(of: #"^(=+|-+)$"#, options: .regularExpression) != nil {
                // A Setext underline makes the paragraph above a heading: no blank line before it, one after.
                result.append(line)
                previous = .heading
                continue
            } else if HeadingParser.atx(line) != nil || trimmed.range(of: #"^<h[1-6][\s>]"#, options: [.regularExpression, .caseInsensitive]) != nil {
                kind = .heading
            } else if trimmed.range(of: #"^([-*_])( *\1){2,}$"#, options: .regularExpression) != nil {
                kind = .rule
            } else if trimmed.range(of: #"^([-*+]|\d{1,9}[.)])[ \t]"#, options: .regularExpression) != nil || (previous == .list && indented) {
                kind = .list
            } else if trimmed.hasPrefix(">") {
                kind = .quote
            } else if trimmed.hasPrefix("|") {
                kind = .table
            } else if trimmed.hasPrefix("<") {
                kind = .html
            } else {
                kind = previous == .list ? .list : previous == .quote ? .quote : .text  // Lazy continuation lines.
            }
            if let previous {
                let separate = kind == .heading || kind == .rule || previous == .heading || previous == .rule
                    || previous == .code || kind == .code || kind != previous
                if separate { result.append("") }
            }
            result.append(line)
            previous = fence == nil ? kind : .code
        }
        var joined = result.joined(separator: "\n")
        if trailing { joined += "\n" }
        return joined
    }

    /// 強制改行（行末の空白2つ以上・行末の \・<br>）と、段落の文章どうしの改行を改段落（空行）にする。
    /// リスト・引用・表・見出し・Setextの下線・コードブロック・HTMLの行は分けない
    static func hardBreaksToParagraphs(_ text: String) -> String {
        var lines = text.normalizedLineBreaks.components(separatedBy: "\n")
        let trailing = lines.count > 1 && lines.last == ""
        if trailing { lines.removeLast() }
        var result: [String] = []
        var fence: String?
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let open = fence {
                result.append(line)
                if trimmed.hasPrefix(open) { fence = nil }
                continue
            }
            if let marker = ["```", "~~~"].first(where: { trimmed.hasPrefix($0) }) {
                fence = marker
                result.append(line)
                continue
            }
            if trimmed.hasPrefix("<") { result.append(line); continue }
            // <br> inside the line splits it into paragraphs.
            let ns = line as NSString
            var pieces: [String] = []
            var start = 0
            for match in brTag.matches(in: line, range: NSRange(location: 0, length: ns.length)) {
                pieces.append(ns.substring(with: NSRange(location: start, length: match.range.location - start)))
                start = NSMaxRange(match.range)
            }
            pieces.append(ns.substring(from: start))
            pieces = pieces.map { $0.replacingOccurrences(of: #"[ \t]+$"#, with: "", options: .regularExpression) }
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            if pieces.isEmpty { result.append(""); continue }
            for (offset, piece) in pieces.enumerated() {
                if offset > 0 { result.append("") }
                result.append(piece)
            }
            // A hard break, or a plain line break between two paragraph lines, becomes a paragraph break.
            let hardBreak = line.hasSuffix("  ") || line.hasSuffix("\\")
            let next = index + 1 < lines.count ? lines[index + 1] : ""
            let nextHasText = !next.trimmingCharacters(in: .whitespaces).isEmpty
            if result[result.count - 1].hasSuffix("\\") { result[result.count - 1].removeLast() }
            if nextHasText, hardBreak || (isParagraphLine(line) && isParagraphLine(next) && !isSetextUnderline(next)) {
                result.append("")
            }
        }
        var joined = result.joined(separator: "\n")
        if trailing { joined += "\n" }
        return joined
    }
    /// 段落の文章の行か（リスト・引用・表・見出し・HTML・コードの囲み・水平線ではない）
    private static func isParagraphLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, line.prefix(while: { $0 == " " }).count < 4 else { return false }
        for prefix in [">", "|", "<", "#", "```", "~~~"] where trimmed.hasPrefix(prefix) { return false }
        if trimmed.range(of: #"^([-*+]|\d{1,9}[.)])[ \t]"#, options: .regularExpression) != nil { return false }
        if trimmed.range(of: #"^([-*_])( *\1){2,}$"#, options: .regularExpression) != nil { return false }
        return !isSetextUnderline(line)
    }

    private static func isSetextUnderline(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).range(of: #"^(=+|-+)$"#, options: .regularExpression) != nil
    }

    private static let brTag = try! NSRegularExpression(pattern: #"<br\s*/?>"#, options: .caseInsensitive)

    /// 英数字・英語の記号どうしの境目だけ空白が要る（日本語を挟む境目は詰める）
    private static func needsSpace(_ before: Character?, _ after: Character?) -> Bool {
        guard let before, let after else { return false }
        return before.isASCII && !before.isWhitespace && after.isASCII && !after.isWhitespace
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
        var lines = text.normalizedLineBreaks.components(separatedBy: "\n")
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
