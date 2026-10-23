import Foundation

/// 書式の変更1回分。range を replacement に置き換え、そのあと selection を選ぶ
struct TextEdit: Equatable {
    let range: NSRange
    let replacement: String
    let selection: NSRange
}

/// エディタの書式（選択した文字への太字など、カーソルのある段落への見出し・リスト・引用など）
enum MarkdownFormat {
    // MARK: - Inline

    /// 選択を marker で囲む。すでに囲まれていれば外す。選択が無ければ marker を2つ入れて間にカーソル
    static func toggleWrap(_ text: String, selection: NSRange, marker: String) -> TextEdit {
        toggle(text, selection: selection, open: marker, close: marker)
    }

    /// <s>〜</s>（取り消し線）で囲む・外す
    static func toggleStrikethrough(_ text: String, selection: NSRange) -> TextEdit {
        toggle(text, selection: selection, open: "<s>", close: "</s>")
    }

    /// <u>〜</u>（下線）で囲む・外す
    static func toggleUnderline(_ text: String, selection: NSRange) -> TextEdit {
        toggle(text, selection: selection, open: "<u>", close: "</u>")
    }

    /// <!-- --> で囲む・外す
    static func toggleComment(_ text: String, selection: NSRange) -> TextEdit {
        toggle(text, selection: selection, open: "<!-- ", close: " -->")
    }

    private static func toggle(_ text: String, selection: NSRange, open: String, close: String) -> TextEdit {
        let string = text as NSString
        let openLength = (open as NSString).length, closeLength = (close as NSString).length
        let selected = string.substring(with: selection)
        // Markers just outside the selection: remove them.
        if selection.location >= openLength, NSMaxRange(selection) + closeLength <= string.length,
           string.substring(with: NSRange(location: selection.location - openLength, length: openLength)) == open,
           string.substring(with: NSRange(location: NSMaxRange(selection), length: closeLength)) == close,
           !isPartOfLongerMarker(string, before: selection.location - openLength, after: NSMaxRange(selection) + closeLength, marker: open) {
            let range = NSRange(location: selection.location - openLength, length: selection.length + openLength + closeLength)
            return TextEdit(range: range, replacement: selected,
                            selection: NSRange(location: range.location, length: selection.length))
        }
        // Markers inside the selection: remove them.
        if selected.count >= open.count + close.count, selected.hasPrefix(open), selected.hasSuffix(close),
           !(open == "*" && selected.hasPrefix("**") && !selected.hasPrefix("***")) {
            let inner = (selected as NSString).substring(with: NSRange(location: openLength, length: (selected as NSString).length - openLength - closeLength))
            return TextEdit(range: selection, replacement: inner,
                            selection: NSRange(location: selection.location, length: (inner as NSString).length))
        }
        return TextEdit(range: selection, replacement: open + selected + close,
                        selection: NSRange(location: selection.location + openLength, length: selection.length))
    }

    /// 斜体の「*」が太字の「**」の一部かどうか
    private static func isPartOfLongerMarker(_ string: NSString, before: Int, after: Int, marker: String) -> Bool {
        guard marker == "*" || marker == "_" else { return false }
        let left = before > 0 ? string.substring(with: NSRange(location: before - 1, length: 1)) : ""
        let right = after < string.length ? string.substring(with: NSRange(location: after, length: 1)) : ""
        return left == marker && right == marker
    }

    /// [選択](https://) を入れて「https://」を選ぶ。選択がURLなら [](URL) にして [] の中へ
    static func link(_ text: String, selection: NSRange, image: Bool) -> TextEdit {
        let selected = (text as NSString).substring(with: selection)
        let bang = image ? "!" : ""
        if selected.range(of: #"^(https?://|mailto:)\S+$"#, options: .regularExpression) != nil {
            let replacement = bang + "[](" + selected + ")"
            return TextEdit(range: selection, replacement: replacement,
                            selection: NSRange(location: selection.location + (bang as NSString).length + 1, length: 0))
        }
        let placeholder = "https://"
        let replacement = bang + "[" + selected + "](" + placeholder + ")"
        let urlStart = selection.location + (bang as NSString).length + 1 + (selected as NSString).length + 2
        return TextEdit(range: selection, replacement: replacement,
                        selection: NSRange(location: urlStart, length: (placeholder as NSString).length))
    }

    // MARK: - Blocks

    enum Block: Equatable {
        case heading(Int), paragraph, quote, unorderedList, orderedList
    }

    /// カーソルのある段落（選択している行すべて）を見出し・段落・引用・リストにする。引用とリストは切り替え
    static func setBlock(_ text: String, selection: NSRange, to block: Block) -> TextEdit {
        let string = text as NSString
        let range = lineRange(string, selection)
        var lines = string.substring(with: range).normalizedLineBreaks.components(separatedBy: "\n")
        let trailingNewline = lines.last == "" && lines.count > 1
        if trailingNewline { lines.removeLast() }
        let content = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        switch block {
        case .heading(let level):
            lines = lines.map { line in
                guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return line }
                return String(repeating: "#", count: level) + " " + stripHeading(line)
            }
        case .paragraph:
            lines = lines.map(stripHeading)
        case .quote:
            let all = !content.isEmpty && content.allSatisfy { $0.trimmingCharacters(in: .whitespaces).hasPrefix(">") }
            lines = lines.map { line in
                if all { return line.replacingOccurrences(of: #"^(\s*)> ?"#, with: "$1", options: .regularExpression) }
                return line.isEmpty ? ">" : "> " + line
            }
        case .unorderedList, .orderedList:
            let ordered = block == .orderedList
            let pattern = ordered ? #"^\s*\d{1,9}[.)][ \t]+"# : #"^\s*[-*+][ \t]+"#
            let all = !content.isEmpty && content.allSatisfy { $0.range(of: pattern, options: .regularExpression) != nil }
            var number = 0
            lines = lines.map { line in
                guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return line }
                // Any list marker (and a heading mark) gives way to the new one.
                let body = stripHeading(String(line.drop(while: { $0.isWhitespace })).replacingOccurrences(of: #"^\s*([-*+]|\d{1,9}[.)])[ \t]+"#, with: "", options: .regularExpression))
                if all { return body }
                number += 1
                return (ordered ? "\(number). " : "- ") + body
            }
        }
        var replacement = lines.joined(separator: "\n")
        if trailingNewline { replacement += "\n" }
        let length = (replacement as NSString).length - (trailingNewline ? 1 : 0)
        return TextEdit(range: range, replacement: replacement, selection: NSRange(location: range.location, length: length))
    }

    /// 選択している行（選択がなければカーソルのある行）を ``` で囲む。囲まれていれば外す。空行には空の囲みを入れて中にカーソル
    static func toggleCodeBlock(_ text: String, selection: NSRange) -> TextEdit {
        let string = text as NSString
        let range = lineRange(string, selection)
        var lines = string.substring(with: range).normalizedLineBreaks.components(separatedBy: "\n")
        let trailingNewline = lines.last == "" && lines.count > 1
        if trailingNewline { lines.removeLast() }
        let tail = trailingNewline ? "\n" : ""
        if lines.count >= 2, lines[0].trimmingCharacters(in: .whitespaces).hasPrefix("```"),
           lines[lines.count - 1].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
            let inner = lines[1..<(lines.count - 1)].joined(separator: "\n")
            return TextEdit(range: range, replacement: inner + (inner.isEmpty ? "" : tail),
                            selection: NSRange(location: range.location, length: (inner as NSString).length))
        }
        let body = lines.joined(separator: "\n")
        if body.trimmingCharacters(in: .whitespaces).isEmpty {
            return TextEdit(range: range, replacement: "```\n\n```" + tail, selection: NSRange(location: range.location + 4, length: 0))
        }
        return TextEdit(range: range, replacement: "```\n" + body + "\n```" + tail,
                        selection: NSRange(location: range.location + 4, length: (body as NSString).length))
    }

    /// 選択している行の字下げを増やす（半角スペース2つ）・減らす
    static func indent(_ text: String, selection: NSRange, outdent: Bool) -> TextEdit {
        let string = text as NSString
        let range = lineRange(string, selection)
        var lines = string.substring(with: range).normalizedLineBreaks.components(separatedBy: "\n")
        let trailingNewline = lines.last == "" && lines.count > 1
        if trailingNewline { lines.removeLast() }
        lines = lines.map { line in
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return line }
            if !outdent { return "  " + line }
            if line.hasPrefix("\t") { return String(line.dropFirst()) }
            return String(line.dropFirst(min(2, line.prefix { $0 == " " }.count)))
        }
        var replacement = lines.joined(separator: "\n")
        if trailingNewline { replacement += "\n" }
        let length = (replacement as NSString).length - (trailingNewline ? 1 : 0)
        return TextEdit(range: range, replacement: replacement, selection: NSRange(location: range.location, length: length))
    }

    /// 水平線（---）を入れる。空行ならその行に、文字のある行ならその後ろに。前後は空行で区切る（Setextの下線と取り違えないため）
    static func horizontalRule(_ text: String, selection: NSRange) -> TextEdit {
        let string = text as NSString
        var start = 0, end = 0, contentsEnd = 0
        string.getLineStart(&start, end: &end, contentsEnd: &contentsEnd, for: NSRange(location: NSMaxRange(selection), length: 0))
        let line = string.substring(with: NSRange(location: start, length: contentsEnd - start))
        func isBlank(_ range: NSRange) -> Bool { string.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if line.trimmingCharacters(in: .whitespaces).isEmpty {
            let previousBlank = start == 0 || isBlank(string.lineRange(for: NSRange(location: start - 1, length: 0)))
            let nextBlank = end >= string.length || isBlank(string.lineRange(for: NSRange(location: end, length: 0)))
            let insertion = (previousBlank ? "" : "\n") + "---" + (nextBlank ? "" : "\n")
            let range = NSRange(location: start, length: contentsEnd - start)
            let caret = start + (previousBlank ? 0 : 1) + 3  // end of "---"
            return TextEdit(range: range, replacement: insertion, selection: NSRange(location: caret, length: 0))
        }
        let nextBlank = end >= string.length || isBlank(string.lineRange(for: NSRange(location: end, length: 0)))
        let insertion = "\n\n---" + (nextBlank ? "" : "\n")
        return TextEdit(range: NSRange(location: contentsEnd, length: 0), replacement: insertion,
                        selection: NSRange(location: contentsEnd + 5, length: 0))
    }

    /// カーソルのある行の末尾に空行を挟んで新しい段落を始める
    static func newParagraph(_ text: String, selection: NSRange) -> TextEdit {
        let string = text as NSString
        var start = 0, end = 0, contentsEnd = 0
        string.getLineStart(&start, end: &end, contentsEnd: &contentsEnd, for: NSRange(location: NSMaxRange(selection), length: 0))
        let insert = NSRange(location: contentsEnd, length: 0)
        return TextEdit(range: insert, replacement: "\n\n", selection: NSRange(location: contentsEnd + 2, length: 0))
    }

    // MARK: - Moving paragraphs

    /// カーソルのある段落（空行で区切られたまとまり。選択していればその範囲の段落）を前後の段落と入れ替える。
    /// 間の空行はそのまま。動かせなければ nil
    static func moveParagraph(_ text: String, selection: NSRange, up: Bool) -> TextEdit? {
        let lines = HeadingParser.splitLines(text)
        guard !lines.isEmpty else { return nil }
        // Blocks: runs of non-blank lines, as line index ranges.
        var blocks: [ClosedRange<Int>] = []
        var start: Int?
        for (index, line) in lines.enumerated() {
            let blank = line.text.trimmingCharacters(in: .whitespaces).isEmpty
            if !blank, start == nil { start = index }
            if blank, let s = start { blocks.append(s...(index - 1)); start = nil }
        }
        if let s = start { blocks.append(s...(lines.count - 1)) }
        func lineIndex(_ location: Int) -> Int {
            lines.lastIndex { $0.range.location <= location } ?? 0
        }
        let firstLine = lineIndex(selection.location)
        let lastLine = lineIndex(max(selection.location, NSMaxRange(selection) - (selection.length > 0 ? 1 : 0)))
        // On a blank line, the block below is the one to move.
        guard let first = blocks.firstIndex(where: { $0.upperBound >= firstLine }) else { return nil }
        let last = blocks.lastIndex(where: { $0.lowerBound <= lastLine }).map { max($0, first) } ?? first
        let other = up ? first - 1 : last + 1
        guard blocks.indices.contains(other) else { return nil }
        let string = text as NSString
        func span(_ from: Int, _ to: Int) -> NSRange {
            NSRange(location: lines[blocks[from].lowerBound].range.location,
                    length: NSMaxRange(lines[blocks[to].upperBound].range) - lines[blocks[from].lowerBound].range.location)
        }
        let moving = span(first, last)
        let neighbor = span(other, other)
        let (top, bottom) = up ? (neighbor, moving) : (moving, neighbor)
        let gap = NSRange(location: NSMaxRange(top), length: bottom.location - NSMaxRange(top))
        let replacement = string.substring(with: bottom) + string.substring(with: gap) + string.substring(with: top)
        let whole = NSRange(location: top.location, length: NSMaxRange(bottom) - top.location)
        // Keep the caret (or selection) at the same place inside the moved paragraphs.
        let movedStart = up ? whole.location : whole.location + bottom.length + gap.length
        let offset = selection.location - moving.location
        return TextEdit(range: whole, replacement: replacement,
                        selection: NSRange(location: movedStart + max(0, offset), length: selection.length))
    }

    // MARK: - Typing

    /// リスト・引用の行で Return を押したとき：次の行に記号を付ける。中身の無い項目なら記号を消して終える。対象外なら nil
    static func continueList(_ text: String, selection: NSRange) -> TextEdit? {
        let string = text as NSString
        guard selection.length == 0, !insideCodeBlock(string, at: selection.location) else { return nil }
        let lineStart = string.lineRange(for: NSRange(location: selection.location, length: 0)).location
        let head = string.substring(with: NSRange(location: lineStart, length: selection.location - lineStart))
        let full = string.substring(with: string.lineRange(for: NSRange(location: lineStart, length: 0)))
            .trimmingCharacters(in: .newlines)
        guard let match = head.range(of: #"^(\s*)([-*+]|\d{1,9}[.)])([ \t]+)(\[[ xX]\][ \t]+)?|^(\s*>+[ \t]?)"#, options: .regularExpression) else {
            // An indented line (as in MacDown) starts the next line with the same indent.
            let indent = String(head.prefix { $0 == " " || $0 == "\t" })
            guard !indent.isEmpty, indent.count < head.count else { return nil }
            let insertion = "\n" + indent
            return TextEdit(range: selection, replacement: insertion,
                            selection: NSRange(location: selection.location + (insertion as NSString).length, length: 0))
        }
        let prefix = String(head[match])
        // An empty item ends the list: clear its marker.
        if full.trimmingCharacters(in: .whitespaces) == prefix.trimmingCharacters(in: .whitespaces) {
            let range = NSRange(location: lineStart, length: (full as NSString).length)
            return TextEdit(range: range, replacement: "", selection: NSRange(location: lineStart, length: 0))
        }
        var next = prefix
        if let number = prefix.range(of: #"\d{1,9}"#, options: .regularExpression), let value = Int(prefix[number]) {
            next = prefix.replacingCharacters(in: number, with: String(value + 1))
        }
        // A task item continues unchecked.
        next = next.replacingOccurrences(of: #"\[[xX]\]"#, with: "[ ]", options: .regularExpression)
        let insertion = "\n" + next
        return TextEdit(range: selection, replacement: insertion,
                        selection: NSRange(location: selection.location + (insertion as NSString).length, length: 0))
    }

    /// Tab・⇧Tab：リストの行か複数行の選択なら字下げを変える。対象外なら nil（ふつうの Tab）
    static func tab(_ text: String, selection: NSRange, outdent: Bool) -> TextEdit? {
        let string = text as NSString
        let lines = string.substring(with: lineRange(string, selection))
        let multiline = selection.length > 0 && lines.trimmingCharacters(in: .newlines).contains("\n")
        let isList = lines.range(of: #"^\s*([-*+]|\d{1,9}[.)])[ \t]"#, options: .regularExpression) != nil
        guard multiline || isList, !insideCodeBlock(string, at: selection.location) else { return nil }
        if outdent, !multiline, !lines.hasPrefix(" "), !lines.hasPrefix("\t") { return nil }
        let edit = indent(text, selection: selection, outdent: outdent)
        guard selection.length == 0 else { return edit }
        // Keep the caret on the same character.
        let shift = (edit.replacement as NSString).length - edit.range.length
        let caret = max(edit.range.location, selection.location + shift)
        return TextEdit(range: edit.range, replacement: edit.replacement, selection: NSRange(location: caret, length: 0))
    }

    /// location がコードブロック（```・~~~）の中か
    private static func insideCodeBlock(_ string: NSString, at location: Int) -> Bool {
        var fence: String?
        for line in string.substring(to: min(location, string.length)).normalizedLineBreaks.components(separatedBy: "\n").dropLast() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let open = fence {
                if trimmed.hasPrefix(open) { fence = nil }
            } else if let marker = ["```", "~~~"].first(where: { trimmed.hasPrefix($0) }) {
                fence = marker
            }
        }
        return fence != nil
    }

    private static func lineRange(_ string: NSString, _ selection: NSRange) -> NSRange {
        // A selection that ends right after a newline does not include the next line.
        var adjusted = selection
        if selection.length > 0, NSMaxRange(selection) <= string.length,
           string.substring(with: NSRange(location: NSMaxRange(selection) - 1, length: 1)) == "\n" {
            adjusted.length -= 1
        }
        return string.lineRange(for: adjusted)
    }

    private static func stripHeading(_ line: String) -> String {
        line.replacingOccurrences(of: #"^ {0,3}#{1,6}(?:[ \t]+|$)"#, with: "", options: .regularExpression)
    }
}
