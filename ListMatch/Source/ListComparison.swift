import Foundation

/// Compares two lists of lines (e-mail addresses, names, IDs…) and finds what is only on one side.
struct ListComparison: Equatable {
    struct Options: Equatable {
        /// Treat "A@example.com" and "a@example.com" as the same item.
        var ignoreCase = true
        /// Treat full-width and half-width forms ("ＡＢＣ１" / "ABC1") as the same item.
        var ignoreWidth = false
        /// Besides line breaks, also split items at spaces (half- and full-width), commas (, ，) and tabs.
        var splitAtSpaces = false
        var splitAtCommas = false
        var splitAtTabs = false
        /// Sort the results instead of keeping the order of the original list.
        var sortResults = false
        /// Compare only the e-mail addresses found in the text ("Name <a@x.jp>", "a@x.jp; b@x.jp", CSV rows…).
        var emailOnly = false
        /// Compare one column (1-based) of rows split at the separators, such as the e-mail column of a CSV. 0 = every field.
        var column = 0
        /// With a column chosen: leave out the first non-empty line (the header row).
        var skipHeader = false

        /// A column applies only when separators are chosen and addresses are not being picked out.
        var usesColumn: Bool { column > 0 && !emailOnly && splitsAtAny }
        var splitsAtAny: Bool { splitAtSpaces || splitAtCommas || splitAtTabs }
    }

    struct Side: Equatable {
        /// Distinct items in the order they first appear (as written, trimmed).
        var items: [String] = []
        /// Lines that repeat an earlier item.
        var duplicateCount = 0
        /// E-mail mode: non-empty lines without an address; column mode: lines without that column (ignored).
        var skippedCount = 0
        /// Where the items that are also in the other list sit in the text (every occurrence, for dimming).
        var commonRanges: [NSRange] = []
    }

    /// One item and where it is in the text (UTF-16 offsets, as NSTextView uses).
    struct Token {
        var item: String
        var range: NSRange
    }

    var left = Side()
    var right = Side()
    var leftOnly: [String] = []
    var rightOnly: [String] = []
    /// Items in both lists (left list's order and spelling).
    var common: [String] = []
    var commonCount = 0
    /// Both lists together without repeats: the left list, then what is only in the right one.
    var merged: [String] = []

    /// `rightOptions` lets the right list use its own column (a CSV on one side, a plain list on the other);
    /// matching (case, width) and sorting follow `options`.
    static func compare(_ leftText: String, _ rightText: String, options: Options = Options(), rightOptions: Options? = nil) -> ListComparison {
        var result = ListComparison()
        let leftScan = scan(leftText, options), rightScan = scan(rightText, rightOptions ?? options)
        let (leftItems, leftKeys, leftDuplicates) = distinct(leftScan.tokens, options)
        let (rightItems, rightKeys, rightDuplicates) = distinct(rightScan.tokens, options)
        let leftSet = Set(leftKeys), rightSet = Set(rightKeys)
        func commonRanges(_ tokens: [Token], _ other: Set<String>) -> [NSRange] {
            tokens.filter { other.contains(key($0.item, options)) }.map(\.range)
        }
        result.left = Side(items: leftItems, duplicateCount: leftDuplicates, skippedCount: leftScan.skipped, commonRanges: commonRanges(leftScan.tokens, rightSet))
        result.right = Side(items: rightItems, duplicateCount: rightDuplicates, skippedCount: rightScan.skipped, commonRanges: commonRanges(rightScan.tokens, leftSet))
        result.leftOnly = zip(leftItems, leftKeys).filter { !rightSet.contains($0.1) }.map(\.0)
        result.rightOnly = zip(rightItems, rightKeys).filter { !leftSet.contains($0.1) }.map(\.0)
        result.common = zip(leftItems, leftKeys).filter { rightSet.contains($0.1) }.map(\.0)
        result.commonCount = result.common.count
        result.merged = leftItems + result.rightOnly
        if options.sortResults {
            result.merged.sort { $0.localizedStandardCompare($1) == .orderedAscending }
            result.common.sort { $0.localizedStandardCompare($1) == .orderedAscending }
            result.leftOnly.sort { $0.localizedStandardCompare($1) == .orderedAscending }
            result.rightOnly.sort { $0.localizedStandardCompare($1) == .orderedAscending }
        }
        return result
    }

    /// The items of a list: split into lines (and separators), trimmed, empty ones dropped.
    static func items(_ text: String, _ options: Options) -> [String] {
        scan(text, options).tokens.map(\.item)
    }

    private static let trimmed = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{FEFF}"))

    /// Items with their ranges, and (e-mail mode) the number of non-empty lines without an address.
    static func scan(_ text: String, _ options: Options) -> (tokens: [Token], skipped: Int) {
        if options.emailOnly { return emailTokens(in: text) }
        if options.usesColumn { return columnTokens(in: text, options) }
        let source = text as NSString
        let breaks = CharacterSet.newlines.union(separators(options))
        func isIn(_ set: CharacterSet, _ unit: unichar) -> Bool { Unicode.Scalar(unit).map(set.contains) ?? false }
        var tokens: [Token] = []
        func emit(_ from: Int, _ to: Int) {
            var start = from, end = to
            while start < end, isIn(trimmed, source.character(at: start)) { start += 1 }
            while end > start, isIn(trimmed, source.character(at: end - 1)) { end -= 1 }
            guard end > start else { return }
            let range = NSRange(location: start, length: end - start)
            tokens.append(Token(item: source.substring(with: range), range: range))
        }
        var start = 0
        for index in 0..<source.length where isIn(breaks, source.character(at: index)) {
            emit(start, index)
            start = index + 1
        }
        emit(start, source.length)
        return (tokens, 0)
    }

    /// The separators chosen besides line breaks (full-width spaces and commas included).
    static func separators(_ options: Options) -> CharacterSet {
        var separators = CharacterSet()
        if options.splitAtSpaces { separators.insert(charactersIn: " \u{3000}") }
        if options.splitAtCommas { separators.insert(charactersIn: ",，") }
        if options.splitAtTabs { separators.insert(charactersIn: "\t") }
        return separators
    }

    /// The list rewritten one item per line when it contains a chosen separator (nil when nothing would change).
    /// Repeats are kept: only the layout changes.
    static func splitIntoLines(_ text: String, _ options: Options) -> String? {
        let separators = separators(options)
        guard !options.emailOnly, options.column == 0, !separators.isEmpty, text.rangeOfCharacter(from: separators) != nil else { return nil }
        let lines = items(text, options)
        return lines.isEmpty ? nil : lines.joined(separator: "\n") + "\n"
    }

    /// The lines: `content` without the line break, `full` with it (CRLF counts as one break).
    static func lineRanges(_ source: NSString) -> [(content: NSRange, full: NSRange)] {
        var lines: [(NSRange, NSRange)] = [], location = 0
        repeat {
            var start = 0, end = 0, contentsEnd = 0
            source.getLineStart(&start, end: &end, contentsEnd: &contentsEnd, for: NSRange(location: location, length: 0))
            lines.append((NSRange(location: start, length: contentsEnd - start), NSRange(location: start, length: end - start)))
            location = end
        } while location < source.length
        return lines
    }

    /// Column mode: field `column` of each row, fields split at the separators outside double quotes ("a, b" stays one
    /// field). Surrounding quotes are dropped. Rows without that column are counted as skipped.
    static func columnTokens(in text: String, _ options: Options) -> (tokens: [Token], skipped: Int) {
        let source = text as NSString
        let separators = separators(options)
        func isIn(_ set: CharacterSet, _ unit: unichar) -> Bool { Unicode.Scalar(unit).map(set.contains) ?? false }
        var tokens: [Token] = [], skipped = 0, headerSkipped = !options.skipHeader
        for (line, _) in lineRanges(source) {
            // Field boundaries outside quotes.
            var fields: [NSRange] = [], start = line.location, quoted = false
            for index in line.location..<NSMaxRange(line) {
                let unit = source.character(at: index)
                if unit == 0x22 { quoted.toggle() } else if !quoted, isIn(separators, unit) {
                    fields.append(NSRange(location: start, length: index - start)); start = index + 1
                }
            }
            fields.append(NSRange(location: start, length: NSMaxRange(line) - start))
            let blank = source.substring(with: line).trimmingCharacters(in: trimmed).isEmpty
            if blank { continue }
            if !headerSkipped { headerSkipped = true; continue }
            // Repeated spaces would make empty fields: ignore them when spaces separate.
            if options.splitAtSpaces { fields = fields.filter { !source.substring(with: $0).trimmingCharacters(in: trimmed).isEmpty } }
            guard options.column <= fields.count else { skipped += 1; continue }
            var range = fields[options.column - 1]
            func trim(_ set: CharacterSet) {
                while range.length > 0, isIn(set, source.character(at: range.location)) { range.location += 1; range.length -= 1 }
                while range.length > 0, isIn(set, source.character(at: NSMaxRange(range) - 1)) { range.length -= 1 }
            }
            trim(trimmed)
            if range.length >= 2, source.character(at: range.location) == 0x22, source.character(at: NSMaxRange(range) - 1) == 0x22 {
                range.location += 1; range.length -= 2; trim(trimmed)
            }
            guard range.length > 0 else { skipped += 1; continue }
            tokens.append(Token(item: source.substring(with: range).replacingOccurrences(of: "\"\"", with: "\""), range: range))
        }
        return (tokens, skipped)
    }

    /// The list without repeated items, keeping the first of each (nil when there is nothing to remove).
    /// Lines mode keeps every other line as written; with separators the list becomes one item per line;
    /// e-mail mode drops lines whose addresses all appeared earlier; column mode drops rows whose field repeats.
    static func removingDuplicates(_ text: String, _ options: Options) -> String? {
        var seen = Set<String>(), removed = 0
        let source = text as NSString
        if !options.emailOnly && !options.usesColumn && !separators(options).isEmpty && text.rangeOfCharacter(from: separators(options)) != nil {
            var kept: [String] = []
            for item in items(text, options) where seen.insert(key(item, options)).inserted { kept.append(item) }
            return kept.count == items(text, options).count ? nil : kept.joined(separator: "\n") + "\n"
        }
        let tokens = scan(text, options).tokens
        var next = 0
        let result = NSMutableString()
        for (_, full) in lineRanges(source) {
            var keys: [String] = []
            while next < tokens.count, tokens[next].range.location < NSMaxRange(full) {
                keys.append(key(tokens[next].item, options))
                next += 1
            }
            if !keys.isEmpty && keys.allSatisfy(seen.contains) { removed += 1; continue }
            keys.forEach { seen.insert($0) }
            result.append(source.substring(with: full))
        }
        return removed == 0 ? nil : result as String
    }

    /// Where `item` first appears in the text (nil when it is not there).
    static func firstRange(of item: String, in text: String, _ options: Options) -> NSRange? {
        let wanted = key(item, options)
        return scan(text, options).tokens.first { key($0.item, options) == wanted }?.range
    }

    // Local part and domain as commonly used in practice (not every form RFC 5322 allows, such as quoted local parts).
    private static let emailPattern = try! NSRegularExpression(pattern: "[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\\.[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?\\.)+[A-Za-z]{2,}")

    /// Full-width ASCII (ａ＠ｘ．ｊｐ) and the ideographic space read as half-width, one UTF-16 unit for one,
    /// so ranges found in the result are ranges in the original text.
    private static func halfWidthASCII(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0xFF01...0xFF5E: scalars.append(Unicode.Scalar(scalar.value - 0xFEE0)!)
            case 0x3000: scalars.append(" ")
            default: scalars.append(scalar)
            }
        }
        return String(scalars)
    }

    /// Every e-mail address in the text, in order, and the number of non-empty lines without one
    /// (headers, names, notes). Full-width addresses are read as half-width.
    static func emailTokens(in text: String) -> (tokens: [Token], skipped: Int) {
        let halfWidth = halfWidthASCII(text)
        let source = halfWidth as NSString
        let matches = emailPattern.matches(in: halfWidth, range: NSRange(location: 0, length: source.length))
        let tokens = matches.map { Token(item: source.substring(with: $0.range), range: $0.range) }
        // Lines without an address: walk the lines and the (sorted) matches together.
        var skipped = 0, next = 0, lineStart = 0
        func endLine(_ lineEnd: Int) {
            var hasAddress = false
            while next < tokens.count, tokens[next].range.location < lineEnd {
                if tokens[next].range.location >= lineStart { hasAddress = true }
                next += 1
            }
            if !hasAddress {
                let line = source.substring(with: NSRange(location: lineStart, length: lineEnd - lineStart))
                if !line.trimmingCharacters(in: trimmed).isEmpty { skipped += 1 }
            }
        }
        for index in 0..<source.length where Unicode.Scalar(source.character(at: index)).map(CharacterSet.newlines.contains) ?? false {
            endLine(index)
            lineStart = index + 1
        }
        endLine(source.length)
        return (tokens, skipped)
    }

    /// The addresses only (see `emailTokens`).
    static func emailAddresses(in text: String) -> (addresses: [String], skipped: Int) {
        let scan = emailTokens(in: text)
        return (scan.tokens.map(\.item), scan.skipped)
    }

    /// The form used to decide whether two items are the same.
    static func key(_ item: String, _ options: Options) -> String {
        var key = item
        if options.ignoreWidth { key = key.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? key }
        if options.ignoreCase { key = key.lowercased() }
        return key
    }

    private static func distinct(_ tokens: [Token], _ options: Options) -> (items: [String], keys: [String], duplicates: Int) {
        var seen = Set<String>(), items: [String] = [], keys: [String] = [], duplicates = 0
        for token in tokens {
            let key = Self.key(token.item, options)
            if seen.insert(key).inserted { items.append(token.item); keys.append(key) } else { duplicates += 1 }
        }
        return (items, keys, duplicates)
    }
}
