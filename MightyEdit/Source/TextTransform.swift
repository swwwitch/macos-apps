import Foundation

enum TextTransform: Int, CaseIterable {
    case join, number, bullet, removeList, markdown, circled, alphabet, addCommas, removeCommas
    case removeBlankLines, spaceLines, addPeriod, removePeriod, bracketNumber, bracketAlphabet
    case minify
    case joinAll
    case narrowAlphanumerics, widenKana, removeJapaneseSpaces, addJapaneseSpaces
    case sum
    case fullwidthWestern, halfwidthWestern, capitalizeWords, titleCase

    case blackCircled, kanji, formalKanji, circledAlphabet, romanUpper, romanLower
    case checkmark, emptyBox, checkedBox, taskList

    case sortLines, uniqueLines, joinWestern, wrapLines
    case randomLines
    case toggleDateFormat
    case camelCase
    case specialTypography
    case dateToISO, dateToJapanese, dateToEra, dateToGregorian, removeDateYear, addDateYear, weekdayShort, weekdayLong

    case beautify
    case dateToCompact
    case removeDatePadding
    case trimLineEdges, sortLineLength, countText, affixLines

    static let specialLists: [TextTransform] = [.blackCircled, .kanji, .formalKanji, .circledAlphabet, .romanUpper, .romanLower, .checkmark, .emptyBox, .checkedBox, .taskList]

    private static func japaneseNumber(_ number: Int) -> String {
        if number >= 10000 {
            for (unit, label) in [(1000000000000, "兆"), (100000000, "億"), (10000, "万")] where number >= unit {
                let remainder = number % unit
                return japaneseNumber(number / unit) + label + (remainder == 0 ? "" : japaneseNumber(remainder))
            }
        }
        let digits = Array("〇一二三四五六七八九")
        var remainder = number
        var result = ""
        for (unit, label) in [(1000, "千"), (100, "百"), (10, "十")] {
            let digit = remainder / unit
            if digit > 0 { result += (digit == 1 ? "" : String(digits[digit])) + label }
            remainder %= unit
        }
        if remainder > 0 { result += String(digits[remainder]) }
        return result
    }

    static func wrappedText(_ text: String, count: Int) -> String {
        guard count > 0 else { return text }
        var result = ""
        var column = 0
        for character in text {
            if character.unicodeScalars.allSatisfy({ CharacterSet.newlines.contains($0) }) {
                result.append(character)
                column = 0
            } else {
                if column == count { result += "\n"; column = 0 }
                result.append(character)
                column += 1
            }
        }
        return result
    }

    private static func toggledDates(_ text: String) -> String {
        // Match both formats in one pass so replacements cannot be converted twice.
        let regex = try! NSRegularExpression(pattern: #"(?<![\p{Nd}])(?:([0-9]{4})年([0-9]{1,2})月([0-9]{1,2})日|([0-9]{4})-([0-9]{2})-([0-9]{2})(?![\p{Nd}]))"#)
        var result = text
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            let japanese = match.range(at: 1).location != NSNotFound
            let start = japanese ? 1 : 4
            let values = (start...(start + 2)).map { Int((text as NSString).substring(with: match.range(at: $0)))! }
            let (year, month, day) = (values[0], values[1], values[2])
            guard year > 0, (1...12).contains(month) else { continue }
            let leap = year % 400 == 0 || (year % 4 == 0 && year % 100 != 0)
            let days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
            guard (1...days[month - 1]).contains(day), let range = Range(match.range, in: result) else { continue }
            let replacement = japanese ? String(format: "%04d-%02d-%02d", year, month, day)
                : String(format: "%04d年%02d月%02d日", year, month, day)
            result.replaceSubrange(range, with: replacement)
        }
        return result
    }

    private static func camelCased(_ text: String) -> String {
        // Preserve line separators, indentation and punctuation outside word groups.
        let groups = try! NSRegularExpression(pattern: #"[A-Za-z0-9]+(?:[ \t_-]+[A-Za-z0-9]+)*"#)
        var result = text
        for match in groups.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            let group = (text as NSString).substring(with: match.range)
                .replacingOccurrences(of: #"([A-Z]+)([A-Z][a-z])"#, with: "$1 $2", options: .regularExpression)
                .replacingOccurrences(of: #"([a-z0-9])([A-Z])"#, with: "$1 $2", options: .regularExpression)
            let words = group.components(separatedBy: CharacterSet(charactersIn: " \t_-"))
                .filter { !$0.isEmpty }.map { $0.lowercased() }
            let replacement = words.enumerated().map { index, word in
                index == 0 ? word : String(word.prefix(1)).uppercased() + word.dropFirst()
            }.joined()
            if let range = Range(match.range, in: result) { result.replaceSubrange(range, with: replacement) }
        }
        return result
    }

    private func formatWestern(_ text: String) -> String {
        if self == .fullwidthWestern || self == .halfwidthWestern {
            return String(String.UnicodeScalarView(text.unicodeScalars.map { scalar in
                let value = scalar.value
                if self == .fullwidthWestern {
                    if value == 0x20 { return UnicodeScalar(0x3000)! }
                    if (0x21...0x7E).contains(value) { return UnicodeScalar(value + 0xFEE0)! }
                } else {
                    if value == 0x3000 { return UnicodeScalar(0x20)! }
                    if (0xFF01...0xFF5E).contains(value) { return UnicodeScalar(value - 0xFEE0)! }
                }
                return scalar
            }))
        }
        let words = try! NSRegularExpression(pattern: #"[A-Za-z]+(?:['’][A-Za-z]+)*"#)
        let minor: Set<String> = ["a", "an", "the", "and", "but", "or", "nor", "for", "so", "yet", "as", "at", "by", "in", "of", "on", "per", "to", "via", "vs", "with", "from", "into", "onto", "over", "under", "up", "off"]
        // Process titles independently on each line, preserving the exact separators.
        let lines = try! NSRegularExpression(pattern: #"[^\r\n\u2028\u2029]+"#)
        var output = text
        for lineMatch in lines.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            let line = (text as NSString).substring(with: lineMatch.range)
            let matches = words.matches(in: line, range: NSRange(line.startIndex..., in: line))
            var transformed = line
            for (index, match) in matches.enumerated().reversed() {
                let word = (line as NSString).substring(with: match.range).lowercased()
                let previousEnd = index > 0 ? NSMaxRange(matches[index - 1].range) : 0
                let between = (line as NSString).substring(with: NSRange(location: previousEnd, length: match.range.location - previousEnd))
                let startsSubtitle = between.contains(":") || between.contains("—") || between.contains("–")
                let lower = self == .titleCase && minor.contains(word) && index > 0 && index < matches.count - 1 && !startsSubtitle
                let result = lower ? word : String(word.prefix(1)).uppercased() + word.dropFirst()
                if let range = Range(match.range, in: transformed) { transformed.replaceSubrange(range, with: result) }
            }
            if let range = Range(lineMatch.range, in: output) { output.replaceSubrange(range, with: transformed) }
        }
        return output
    }

    enum SumError: LocalizedError {
        case noNumbers, precision
        var errorDescription: String? {
            switch self {
            case .noNumbers: return L("err.sumNoNumbers")
            case .precision: return L("err.sumPrecision")
            }
        }
    }

    static func summedText(_ text: String) throws -> String {
        func canonical(_ value: String) -> String {
            let negative = value.hasPrefix("-")
            let unsigned = negative ? String(value.dropFirst()) : value
            let parts = unsigned.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            let integer = String(parts[0].drop(while: { $0 == "0" }))
            let fraction = parts.count > 1 ? String(parts[1].reversed().drop(while: { $0 == "0" }).reversed()) : ""
            let digits = (integer.isEmpty ? "0" : integer) + (fraction.isEmpty ? "" : "." + fraction)
            return negative && digits != "0" ? "-" + digits : digits
        }
        // Normalize only the extraction copy. The selected source is kept verbatim.
        let source = String(String.UnicodeScalarView(text.unicodeScalars.map { scalar in
            if (0xFF10...0xFF19).contains(scalar.value) || [0xFF0B, 0xFF0D, 0xFF0E, 0xFF0C].contains(scalar.value) {
                return UnicodeScalar(scalar.value - 0xFEE0)!
            }
            return scalar
        })).replacingOccurrences(of: "−", with: "-")
        let pattern = #"[-+]?(?:[0-9]{1,3}(?:,[0-9]{3})+|[0-9]+)(?:\.[0-9]+)?|[-+]?\.[0-9]+"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: source, range: NSRange(source.startIndex..., in: source))
        guard !matches.isEmpty else { throw SumError.noNumbers }
        var total = Decimal.zero
        for match in matches {
            var token = (source as NSString).substring(with: match.range).replacingOccurrences(of: ",", with: "")
            if token.hasPrefix("+") { token.removeFirst() }
            if token.hasPrefix(".") { token = "0" + token }
            if token.hasPrefix("-.") { token = "-0" + token.dropFirst() }
            let significant = token.filter { $0.isNumber }.drop(while: { $0 == "0" })
            guard significant.count <= 38, var value = Decimal(string: token, locale: Locale(identifier: "en_US_POSIX")), !value.isNaN else {
                throw SumError.precision
            }
            guard canonical(token) == canonical(NSDecimalNumber(decimal: value).stringValue) else { throw SumError.precision }
            var next = Decimal.zero
            guard NSDecimalAdd(&next, &total, &value, .plain) == .noError else { throw SumError.precision }
            total = next
        }
        let result = TextTransform.addCommas.apply(NSDecimalNumber(decimal: total).stringValue)
        let newline = text.contains("\r\n") ? "\r\n" : text.contains("\r") && !text.contains("\n") ? "\r" : "\n"
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let separator = normalized.hasSuffix("\n\n") ? "" : normalized.hasSuffix("\n") ? newline : newline + newline
        return text + separator + "合計：" + result
    }

    private func formatTypography(_ text: String) -> String {
        if self == .narrowAlphanumerics {
            return String(String.UnicodeScalarView(text.unicodeScalars.map { scalar in
                let value = scalar.value
                if (0xFF10...0xFF19).contains(value) || (0xFF21...0xFF3A).contains(value) || (0xFF41...0xFF5A).contains(value) {
                    return UnicodeScalar(value - 0xFEE0)!
                }
                return scalar
            }))
        }
        if self == .widenKana {
            let runs = try! NSRegularExpression(pattern: #"[\uFF61-\uFF9F]+"#)
            var result = text
            for match in runs.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
                let kana = (text as NSString).substring(with: match.range)
                if let converted = kana.applyingTransform(.fullwidthToHalfwidth, reverse: true),
                   let range = Range(match.range, in: result) {
                    result.replaceSubrange(range, with: converted.precomposedStringWithCanonicalMapping)
                }
            }
            return result
        }
        let japanese = #"[\p{Han}\p{Hiragana}\p{Katakana}々〆〇ー\u3099\u309A]"#
        let spaces = self == .addJapaneseSpaces ? #"[ \u3000]*"# : #"[ \u3000]+"#
        let pattern = "(?<=\(japanese))\(spaces)(?=[A-Za-z0-9])|(?<=[A-Za-z0-9])\(spaces)(?=\(japanese))"
        return text.replacingOccurrences(of: pattern, with: self == .addJapaneseSpaces ? " " : "", options: .regularExpression)
    }

    // Textual replacement avoids floating-point rounding and preserves long numbers.
    private static let numericToken = try! NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9_.,])[0-9]+(?:,[0-9]+)*(?:\.[0-9]+)?(?![A-Za-z0-9_]|[.,][0-9])"#)
    private static let groupedInteger = try! NSRegularExpression(pattern: #"^[0-9]{1,3}(?:,[0-9]{3})+$"#)

    private func formatCommas(_ text: String) -> String {
        var output = text
        for match in Self.numericToken.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            let token = (text as NSString).substring(with: match.range)
            let parts = token.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            let integer = String(parts[0])
            // Do not interpret CSV-like or malformed comma sequences as thousands separators.
            if integer.contains(","), Self.groupedInteger.firstMatch(in: integer, range: NSRange(integer.startIndex..., in: integer)) == nil { continue }
            let digits = integer.replacingOccurrences(of: ",", with: "")
            if parts.count == 1 && digits.count == 4 {
                let source = text as NSString
                let before = source.substring(to: match.range.location)
                let after = source.substring(from: NSMaxRange(match.range))
                let yearSuffix = after.range(of: #"^[ \t　]*年"#, options: .regularExpression) != nil
                let yearLabel = before.range(of: #"西暦[ \t　:：]*$"#, options: .regularExpression) != nil
                let dateSuffix = after.range(of: #"^[-/](?:0?[1-9]|1[0-2])[-/](?:0?[1-9]|[12][0-9]|3[01])(?![0-9])"#, options: .regularExpression) != nil
                let yearRange = after.range(of: #"^[ \t　]*[-–〜～][ \t　]*[0-9]{4}[ \t　]*年"#, options: .regularExpression) != nil
                if yearSuffix || yearLabel || dateSuffix || yearRange { continue }
            }
            let formatted: String
            if self == .removeCommas {
                formatted = digits
            } else {
                var result = ""
                let count = digits.count
                for (index, digit) in digits.enumerated() {
                    if index > 0 && (count - index) % 3 == 0 { result += "," }
                    result.append(digit)
                }
                formatted = result
            }
            let replacement = formatted + (parts.count == 2 ? "." + parts[1] : "")
            if let range = Range(match.range, in: output) { output.replaceSubrange(range, with: replacement) }
        }
        return output
    }

    // A decimal (3.14) or a word beginning with '-' is not a list marker.
    private static let marker = try! NSRegularExpression(
        pattern: #"^(?:[-+*][\t 　]+\[[ xX]\][\t 　]*|[一二三四五六七八九十百千万億兆壱弐参拾]+、|[壱弐参四五六七八九拾百千万億兆]+(?=[\t 　])|[❶-❿⓫-⓴Ⓐ-Ⓩ]|[✓□✅]\uFE0F?|［(?:[0-9０-９]+|[A-Za-z]+)］|\[(?:[0-9]+|[A-Za-z]+)\]|[0-9０-９]+[.．](?![0-9０-９])|[A-Za-z]+[.．](?=[\t 　]|$)|[0-9０-９]+[)）、]|[(（][0-9０-９]+[)）]|[①-⑳㉑-㉟㊱-㊿]|[・･•●○▪◦‣⁃]|[-+*][\t 　]+)[\t 　]*"#
    )

    private static func removingMarkers(_ line: String) -> (indent: String, body: String) {
        let indent = String(line.prefix { $0 == " " || $0 == "\t" || $0 == "　" })
        var body = String(line.dropFirst(indent.count))
        // Also repair prefixes accumulated by earlier versions or repeated pastes.
        while let match = marker.firstMatch(in: body, range: NSRange(body.startIndex..., in: body)),
              let range = Range(match.range, in: body) {
            body.removeSubrange(range)
        }
        return (indent, body)
    }

    var title: String {
        switch self {
        case .wrapLines: return L("op.wrapLines")
        case .trimLineEdges: return L("op.trimLineEdges")
        case .sortLineLength: return L("op.sortLineLength")
        case .countText: return L("op.countText")
        case .affixLines: return L("op.affixLines")
        case .removeDatePadding: return L("op.removeDatePadding")
        case .dateToCompact: return L("op.dateToCompact")
        case .dateToISO: return L("op.dateToISO")
        case .dateToJapanese: return L("op.dateToJapanese")
        case .dateToEra: return L("op.dateToEra")
        case .dateToGregorian: return L("op.dateToGregorian")
        case .removeDateYear: return L("op.removeDateYear")
        case .addDateYear: return L("op.addDateYear")
        case .weekdayShort: return L("op.weekdayShort")
        case .weekdayLong: return L("op.weekdayLong")
        case .toggleDateFormat: return L("op.toggleDateFormat")
        case .randomLines: return L("op.randomLines")
        case .sortLines: return L("op.sortLines")
        case .uniqueLines: return L("op.uniqueLines")
        case .joinWestern: return L("op.joinWestern")
        case .join: return L("op.join")
        case .number: return L("op.number")
        case .bullet: return L("op.bullet")
        case .removeList: return L("op.removeList")
        case .markdown: return L("op.markdown")
        case .circled: return L("op.circled")
        case .alphabet: return L("op.alphabet")
        case .addCommas: return L("op.addCommas")
        case .removeCommas: return L("op.removeCommas")
        case .removeBlankLines: return L("op.removeBlankLines")
        case .spaceLines: return L("op.spaceLines")
        case .addPeriod: return L("op.addPeriod")
        case .removePeriod: return L("op.removePeriod")
        case .bracketNumber: return L("op.bracketNumber")
        case .bracketAlphabet: return L("op.bracketAlphabet")
        case .beautify: return L("op.beautify")
        case .minify: return L("op.minify")
        case .joinAll: return L("op.joinAll")
        case .narrowAlphanumerics: return L("op.narrowAlphanumerics")
        case .widenKana: return L("op.widenKana")
        case .removeJapaneseSpaces: return L("op.removeJapaneseSpaces")
        case .addJapaneseSpaces: return L("op.addJapaneseSpaces")
        case .sum: return L("op.sum")
        case .fullwidthWestern: return L("op.fullwidthWestern")
        case .halfwidthWestern: return L("op.halfwidthWestern")
        case .capitalizeWords: return L("op.capitalizeWords")
        case .specialTypography: return L("op.specialTypography")
        case .camelCase: return L("op.camelCase")
        case .titleCase: return L("op.titleCase")
        case .blackCircled: return L("op.blackCircled")
        case .kanji: return L("op.kanji")
        case .formalKanji: return L("op.formalKanji")
        case .circledAlphabet: return L("op.circledAlphabet")
        case .romanUpper: return L("op.romanUpper")
        case .romanLower: return L("op.romanLower")
        case .checkmark: return L("op.checkmark")
        case .emptyBox: return L("op.emptyBox")
        case .checkedBox: return L("op.checkedBox")
        case .taskList: return L("op.taskList")
        }
    }

    private func prefix(_ index: Int) -> String {
        switch self {
        case .blackCircled:
            let symbols = Array("❶❷❸❹❺❻❼❽❾❿⓫⓬⓭⓮⓯⓰⓱⓲⓳⓴")
            return index <= symbols.count ? "\(symbols[index - 1]) " : "(\(index)) "
        case .kanji: return Self.japaneseNumber(index) + "、"
        case .formalKanji:
            return Self.japaneseNumber(index).replacingOccurrences(of: "一", with: "壱").replacingOccurrences(of: "二", with: "弐").replacingOccurrences(of: "三", with: "参").replacingOccurrences(of: "十", with: "拾") + " "
        case .circledAlphabet:
            if index <= 26 { return String(UnicodeScalar(0x24B6 + index - 1)!) + " " }
            return "(\(index)) "
        case .romanUpper, .romanLower:
            guard index <= 3999 else { return "(\(index)) " }
            var remaining = index
            var roman = ""
            for (value, symbol) in [(1000,"M"),(900,"CM"),(500,"D"),(400,"CD"),(100,"C"),(90,"XC"),(50,"L"),(40,"XL"),(10,"X"),(9,"IX"),(5,"V"),(4,"IV"),(1,"I")] {
                while remaining >= value { roman += symbol; remaining -= value }
            }
            return (self == .romanLower ? roman.lowercased() : roman) + ". "
        case .checkmark: return "✓ "
        case .emptyBox: return "□ "
        case .checkedBox: return "✅ "
        case .taskList: return "- [ ] "
        case .number: return "\(index). "
        case .bracketNumber: return "［\(index)］ "
        case .markdown: return "- "
        case .circled:
            let symbols = Array("①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳㉑㉒㉓㉔㉕㉖㉗㉘㉙㉚㉛㉜㉝㉞㉟㊱㊲㊳㊴㊵㊶㊷㊸㊹㊺㊻㊼㊽㊾㊿")
            return index <= symbols.count ? "\(symbols[index - 1]) " : "(\(index)) "
        case .alphabet, .bracketAlphabet:
            var number = index
            var letters = ""
            while number > 0 {
                number -= 1
                letters = String(UnicodeScalar(65 + number % 26)!) + letters
                number /= 26
            }
            return self == .bracketAlphabet ? "［\(letters)］ " : letters + ". "
        default: return "・"
        }
    }

    func apply(_ text: String) -> String {
        if DateTransform.operations.contains(self) { return DateTransform.apply(text, operation: self) }
        if self == .specialTypography { return TypographyOption.applyAll(text, options: TypographyOption.allCases) }
        if self == .camelCase { return Self.camelCased(text) }
        if self == .toggleDateFormat { return Self.toggledDates(text) }
        if self == .wrapLines { return Self.wrappedText(text, count: 40) }
        if [.fullwidthWestern, .halfwidthWestern, .capitalizeWords, .titleCase].contains(self) { return formatWestern(text) }
        if self == .sum { return (try? Self.summedText(text)) ?? text }
        if [.narrowAlphanumerics, .widenKana, .removeJapaneseSpaces, .addJapaneseSpaces].contains(self) { return formatTypography(text) }
        if self == .trimLineEdges { return LineTools.trim(text) }
        if self == .sortLineLength { return LineTools.sortByLength(text) }
        if self == .countText || self == .affixLines { return text } // Handled by the panel; never replace with a count.
        if self == .beautify { return HTMLMinifier.beautify(text) }
        if self == .minify { return HTMLMinifier.minify(text) }
        if self == .addCommas || self == .removeCommas { return formatCommas(text) }
        // Treat CRLF as one newline, and support pasted Unicode separators.
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n")
        if self == .joinAll { return normalized.replacingOccurrences(of: "\n", with: "") }
        if self == .sortLines || self == .uniqueLines || self == .randomLines {
            guard !normalized.isEmpty else { return text }
            var lines = normalized.components(separatedBy: "\n")
            let trailing = normalized.hasSuffix("\n")
            if trailing { lines.removeLast() }
            if self == .randomLines {
                lines.shuffle()
            } else if self == .sortLines {
                let ascending = lines.sorted { $0.compare($1, options: [.numeric], locale: Locale(identifier: "ja_JP")) == .orderedAscending }
                // The previous replacement stays selected: clicking again reverses it.
                // Derive direction from the text, so switching selections resets naturally.
                lines = lines == ascending ? Array(ascending.reversed()) : ascending
            } else {
                var seen = Set<String>()
                lines = lines.filter { seen.insert($0).inserted }
            }
            return lines.joined(separator: "\n") + (trailing ? "\n" : "")
        }
        if self == .join || self == .joinWestern {
            let lines = normalized.components(separatedBy: "\n")
            var result = ""
            var previousWasBlank = true
            for (index, line) in lines.enumerated() {
                let blank = line.trimmingCharacters(in: .whitespaces).isEmpty
                if index > 0 && (previousWasBlank || blank) { result += "\n" }
                if self == .joinWestern && index > 0 && !previousWasBlank && !blank {
                    while let last = result.last, last == " " || last == "\t" || last == "　" { result.removeLast() }
                    result += " " + line.drop(while: { $0 == " " || $0 == "\t" || $0 == "　" })
                } else {
                    result += line
                }
                previousWasBlank = blank
            }
            return result
        }
        if self == .removeBlankLines || self == .spaceLines {
            let lines = normalized.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard !lines.isEmpty else { return "" }
            return lines.joined(separator: self == .spaceLines ? "\n\n" : "\n") + (normalized.hasSuffix("\n") ? "\n" : "")
        }
        if self == .addPeriod || self == .removePeriod {
            return normalized.components(separatedBy: "\n").map { line in
                let suffix = String(line.reversed().prefix { $0.unicodeScalars.allSatisfy { CharacterSet.whitespaces.contains($0) } }.reversed())
                var body = String(line.dropLast(suffix.count))
                guard !body.isEmpty else { return line }
                if self == .addPeriod {
                    if !body.hasSuffix("。") { body += "。" }
                } else {
                    while body.hasSuffix("。") { body.removeLast() }
                }
                return body + suffix
            }.joined(separator: "\n")
        }
        var index = 0
        return normalized.components(separatedBy: "\n").map { line in
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return line }
            let (indent, body) = Self.removingMarkers(line)
            if self == .removeList { return indent + body }
            guard !body.trimmingCharacters(in: .whitespaces).isEmpty else { return indent }
            index += 1
            return indent + prefix(index) + body
        }.joined(separator: "\n")
    }
}
