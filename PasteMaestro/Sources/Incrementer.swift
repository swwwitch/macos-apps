import Foundation

/// What was counted up. Foundation-only for the tests.
enum IncrementKind: String, Equatable {
    case date, number, circled, letter, none
}

struct IncrementResult: Equatable {
    let text: String
    let kind: IncrementKind
}

/// The rules of the Keyboard Maestro macro 「increment-paste」, generalized:
/// 1. Dates — 「10月13日」「2026年10月13日（火）」 and 「2026-10-13」「2026/10/13」 move by the calendar
///    (month end, leap years, weekday). The macro uses this year when no 年 is written.
/// 2. The last number — 「1-2-3」→「1-2-4」, 「1.2」→「1.3」, 「Chapter 1-1」→「Chapter 1-2」, keeping zeros
///    (「001」→「002」) and full-width digits. Circled numbers ①〜㊿ count as numbers.
/// 3. The last letter when there is no number — 「A」→「B」, 「（A）」→「（B）」, 「Z」→「AA」, case kept.
/// Anything else is left as it is.
enum Incrementer {
    struct Options: Equatable {
        var step = 1
        var dates = true
        var letters = true
    }

    static func increment(_ text: String, options: Options = Options(), currentYear: Int) -> IncrementResult {
        let step = max(1, options.step)
        if options.dates, let dated = incrementDates(text, step: step, currentYear: currentYear) {
            return IncrementResult(text: dated, kind: .date)
        }
        if let numbered = incrementLastNumber(text, step: step) { return numbered }
        if options.letters, let lettered = incrementLastLetter(text, step: step) {
            return IncrementResult(text: lettered, kind: .letter)
        }
        return IncrementResult(text: text, kind: .none)
    }

    // MARK: - Digits

    /// 0–9 or ０–９ → value and whether it is full-width.
    static func digitValue(_ c: Character) -> (Int, Bool)? {
        guard let scalar = c.unicodeScalars.first, c.unicodeScalars.count == 1 else { return nil }
        switch scalar.value {
        case 0x30...0x39: return (Int(scalar.value - 0x30), false)
        case 0xFF10...0xFF19: return (Int(scalar.value - 0xFF10), true)
        default: return nil
        }
    }
    static func digitCharacter(_ value: Int, fullWidth: Bool) -> Character {
        Character(UnicodeScalar((fullWidth ? 0xFF10 : 0x30) + UInt32(value))!)
    }
    static func number(_ s: Substring) -> Int? {
        var result = 0
        for c in s { guard let (d, _) = digitValue(c) else { return nil }; result = result * 10 + d }
        return result
    }
    static func isFullWidth(_ s: Substring) -> Bool { s.first.flatMap { digitValue($0)?.1 } ?? false }

    /// Adds `step` to a digit run of any length (no Int overflow), keeping its width with leading zeros.
    static func add(_ step: Int, to digits: Substring) -> String {
        let fullWidth = isFullWidth(digits)
        var values = digits.map { digitValue($0)?.0 ?? 0 }
        var carry = step
        var i = values.count - 1
        while carry > 0 {
            if i < 0 { values.insert(0, at: 0); i = 0 }
            let sum = values[i] + carry
            values[i] = sum % 10
            carry = sum / 10
            i -= 1
        }
        return String(values.map { digitCharacter($0, fullWidth: fullWidth) })
    }

    /// Date parts: zero-padded only when the original was (「09」→「10」, 「12」→「1」 for 「01」 would be wrong).
    static func formatPart(_ value: Int, like original: Substring, padded: Bool? = nil) -> String {
        let fullWidth = isFullWidth(original)
        let padded = padded ?? (original.count >= 2 && digitValue(original.first!)?.0 == 0)
        var text = String(value)
        if padded && text.count < 2 { text = "0" + text }
        return String(text.map { digitCharacter(Int(String($0))!, fullWidth: fullWidth) })
    }

    // MARK: - Dates

    private static let digit = "[0-9０-９]"
    private static let japaneseDate = try! NSRegularExpression(pattern:
        "(?:(\(digit){4})年\\s*)?(?<![0-9０-９])(\(digit){1,2})月(\(digit){1,2})日" +
        // Weekday: in brackets (「（火）」「(火曜日)」) or with 曜 (「火曜日」「火曜」).
        "(?:([（(［\\[])([月火水木金土日])(曜日?)?([）)］\\]])|([月火水木金土日])(曜日?))?")
    private static let numericDate = try! NSRegularExpression(pattern:
        "(?<![0-9０-９])([0-9]{4})([-/.])([0-9]{1,2})\\2([0-9]{1,2})(?![0-9０-９])")
    static let weekdays = ["日", "月", "火", "水", "木", "金", "土"]

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date? {
        guard (1...12).contains(month), day >= 1 else { return nil }
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components),
              calendar.component(.month, from: date) == month, calendar.component(.day, from: date) == day else { return nil }
        return date
    }

    /// Every valid date moves by `step` days. Overlapping matches keep the first; invalid dates (13月, 2月30日) are left.
    static func incrementDates(_ text: String, step: Int, currentYear: Int) -> String? {
        let ns = text as NSString
        let all = NSRange(location: 0, length: ns.length)
        func part(_ m: NSTextCheckingResult, _ i: Int) -> Substring? {
            let r = m.range(at: i)
            return r.location == NSNotFound ? nil : Substring(ns.substring(with: r))
        }
        var edits: [(range: NSRange, text: String)] = []
        for m in japaneseDate.matches(in: text, range: all) {
            guard let monthText = part(m, 2), let dayText = part(m, 3),
                  let month = number(monthText), let day = number(dayText) else { continue }
            let yearText = part(m, 1)
            let year = yearText.flatMap(number) ?? currentYear
            guard let start = date(year, month, day),
                  let moved = calendar.date(byAdding: .day, value: step, to: start) else { continue }
            let c = calendar.dateComponents([.year, .month, .day, .weekday], from: moved)
            var result = ""
            if let yearText {
                // Keeps what was between 年 and the month (a space, if any).
                let between = ns.substring(with: NSRange(location: m.range(at: 1).upperBound, length: m.range(at: 2).location - m.range(at: 1).upperBound))
                result += formatPart(c.year!, like: yearText) + between
            }
            result += formatPart(c.month!, like: monthText) + "月" + formatPart(c.day!, like: dayText) + "日"
            let weekday = weekdays[c.weekday! - 1]
            if let open = part(m, 4), let close = part(m, 7) {
                result += open + weekday + (part(m, 6) ?? "") + close
            } else if let suffix = part(m, 9), part(m, 8) != nil {
                result += weekday + suffix
            }
            edits.append((m.range, result))
        }
        for m in numericDate.matches(in: text, range: all) where !edits.contains(where: { NSIntersectionRange($0.range, m.range).length > 0 }) {
            guard let yearText = part(m, 1), let separator = part(m, 2), let monthText = part(m, 3), let dayText = part(m, 4),
                  let year = number(yearText), (1900...2999).contains(year),
                  let start = date(year, number(monthText)!, number(dayText)!),
                  let moved = calendar.date(byAdding: .day, value: step, to: start) else { continue }
            let c = calendar.dateComponents([.year, .month, .day], from: moved)
            // 「2025-12-31」 is ISO style: two-digit month and day stay two digits.
            let padded = (monthText.count == 2 && dayText.count == 2) || monthText.hasPrefix("0") || dayText.hasPrefix("0")
            edits.append((m.range, String(c.year!) + separator + formatPart(c.month!, like: monthText, padded: padded) + separator + formatPart(c.day!, like: dayText, padded: padded)))
        }
        guard !edits.isEmpty else { return nil }
        let result = NSMutableString(string: text)
        for edit in edits.sorted(by: { $0.range.location > $1.range.location }) {
            result.replaceCharacters(in: edit.range, with: edit.text)
        }
        return result as String
    }

    // MARK: - Numbers

    /// ①〜⑳, ㉑〜㉟, ㊱〜㊿.
    static func circledValue(_ c: Character) -> Int? {
        guard let v = c.unicodeScalars.first?.value, c.unicodeScalars.count == 1 else { return nil }
        switch v {
        case 0x2460...0x2473: return Int(v - 0x2460) + 1
        case 0x3251...0x325F: return Int(v - 0x3251) + 21
        case 0x32B1...0x32BF: return Int(v - 0x32B1) + 36
        default: return nil
        }
    }
    static func circledCharacter(_ value: Int) -> Character? {
        switch value {
        case 1...20: return Character(UnicodeScalar(0x2460 + UInt32(value - 1))!)
        case 21...35: return Character(UnicodeScalar(0x3251 + UInt32(value - 21))!)
        case 36...50: return Character(UnicodeScalar(0x32B1 + UInt32(value - 36))!)
        default: return nil
        }
    }

    /// The last digit run (half- or full-width, not mixed) or circled number in the text.
    static func incrementLastNumber(_ text: String, step: Int) -> IncrementResult? {
        var index = text.endIndex
        while index > text.startIndex {
            let before = text.index(before: index)
            let c = text[before]
            if let value = circledValue(c) {
                // ㊿ cannot go further: the text is left as it is rather than turned into 51.
                guard let next = circledCharacter(value + step) else { return IncrementResult(text: text, kind: .none) }
                return IncrementResult(text: text.replacingCharacters(in: before...before, with: String(next)), kind: .circled)
            }
            if let (_, fullWidth) = digitValue(c) {
                var start = before
                while start > text.startIndex {
                    let prior = text.index(before: start)
                    guard let (_, w) = digitValue(text[prior]), w == fullWidth else { break }
                    start = prior
                }
                let run = text[start...before]
                return IncrementResult(text: text.replacingCharacters(in: start...before, with: add(step, to: run)), kind: .number)
            }
            index = before
        }
        return nil
    }

    // MARK: - Letters

    /// A–Z, a–z, Ａ–Ｚ, ａ–ｚ: (base of its alphabet, offset 0–25).
    static func letter(_ c: Character) -> (base: UInt32, offset: Int)? {
        guard let v = c.unicodeScalars.first?.value, c.unicodeScalars.count == 1 else { return nil }
        for base: UInt32 in [0x41, 0x61, 0xFF21, 0xFF41] where (base...base + 25).contains(v) { return (base, Int(v - base)) }
        return nil
    }

    /// The last letter run counts up like spreadsheet columns, keeping each letter's case: 「AZ」→「BA」, 「z」→「aa」.
    static func incrementLastLetter(_ text: String, step: Int) -> String? {
        guard let lastIndex = text.indices.last(where: { letter(text[$0]) != nil }) else { return nil }
        var start = lastIndex
        while start > text.startIndex, letter(text[text.index(before: start)]) != nil { start = text.index(before: start) }
        var run = text[start...lastIndex].map { letter($0)! }
        for _ in 0..<step {
            var i = run.count - 1
            while true {
                if i < 0 { run.insert((run[0].base, 0), at: 0); break }
                if run[i].offset < 25 { run[i].offset += 1; break }
                run[i].offset = 0
                i -= 1
            }
        }
        let replaced = String(run.map { Character(UnicodeScalar($0.base + UInt32($0.offset))!) })
        return text.replacingCharacters(in: start...lastIndex, with: replaced)
    }
}
