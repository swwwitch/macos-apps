import Foundation

enum DateTransform {
    static let operations: [TextTransform] = [.dateToISO, .dateToCompact, .removeDatePadding, .dateToJapanese, .dateToEra, .dateToGregorian, .removeDateYear, .addDateYear, .weekdayShort, .weekdayLong]
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }
    private static let pattern = #"(?<![0-9０-９年-])(?:(?<jy>[0-9]{4})年(?<jm>[0-9]{1,2})月(?<jd>[0-9]{1,2})日|(?<iy>[0-9]{4})-(?<im>[0-9]{1,2})-(?<id>[0-9]{1,2})|(?<era>令和|平成|昭和|大正|明治)(?<ey>元|[0-9]{1,4})年(?<em>[0-9]{1,2})月(?<ed>[0-9]{1,2})日|(?<nm>[0-9]{1,2})月(?<nd>[0-9]{1,2})日|(?<hm>[0-9]{1,2})-(?<hd>[0-9]{1,2})(?!-[0-9]))(?![0-9０-９])(?<weekday>（[日月火水木金土](?:曜日)?）|\([日月火水木金土](?:曜日)?\))?"#

    /// Candidates for 日付スペシャル, grouped for the menu: every date in the selection rewritten in one format.
    /// Accepts yyyy/m/d, yyyy.m.d, yyyymmdd and m/d as well (existing dates only). Results equal to the selection
    /// and repeated candidates are left out, as are empty groups. `padded` adds zero-padded months and days.
    static func variants(_ text: String, padded: Bool = false, currentYear: Int? = nil) -> [[String]] {
        let calendar = self.calendar
        // Rewrite the extra input forms as yyyy-m-d or m-d, which the other operations read.
        let extra = try! NSRegularExpression(pattern: #"(?<![0-9/.])([0-9]{4})([/.])([0-9]{1,2})\2([0-9]{1,2})(?![0-9/.])|(?<![0-9])([0-9]{4})([0-9]{2})([0-9]{2})(?![0-9])|(?<![0-9/.])([0-9]{1,2})/([0-9]{1,2})(?![0-9/.])"#)
        var source = text
        for match in extra.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            let groups = match.range(at: 1).location != NSNotFound ? [1, 3, 4] : (match.range(at: 5).location != NSNotFound ? [5, 6, 7] : [8, 9])
            let parts = groups.map { Int((text as NSString).substring(with: match.range(at: $0)))! }
            let year = parts.count == 3 ? parts[0] : 2000 // A leap year, so 2/29 without a year is accepted.
            guard DateComponents(calendar: calendar, year: year, month: parts[parts.count - 2], day: parts[parts.count - 1]).isValidDate,
                  let range = Range(match.range, in: source) else { continue }
            source.replaceSubrange(range, with: parts.map(String.init).joined(separator: "-"))
        }
        let dates = try! NSRegularExpression(pattern: pattern).matches(in: source, range: NSRange(source.startIndex..., in: source))
        guard !dates.isEmpty else { return [] }
        // Start from dates without a weekday, so the plain forms are offered too.
        for match in dates.reversed() {
            if let range = Range(match.range(withName: "weekday"), in: source) { source.removeSubrange(range) }
        }
        let base = [TextTransform.addDateYear, .dateToISO].reduce(source) { apply($0, operation: $1, currentYear: currentYear) }
        var japaneseCalendar = Calendar(identifier: .japanese)
        japaneseCalendar.timeZone = calendar.timeZone
        let eraFormatter = DateFormatter()
        eraFormatter.locale = Locale(identifier: "ja_JP")
        eraFormatter.calendar = japaneseCalendar
        eraFormatter.timeZone = calendar.timeZone
        eraFormatter.dateFormat = "GGGG"
        let iso = try! NSRegularExpression(pattern: #"(?<![0-9])([0-9]{4})-([0-9]{2})-([0-9]{2})(?![0-9])"#)
        struct Day { let year, month, day, weekday: Int; let era: String?; let eraYear: Int }
        /// Rewrites every valid yyyy-mm-dd in the base text; a date the format cannot express is kept.
        /// Nil when no date could be expressed.
        func format(_ make: (Day) -> String?) -> String? {
            var result = base
            var converted = false
            for match in iso.matches(in: base, range: NSRange(base.startIndex..., in: base)).reversed() {
                let parts = (1...3).map { Int((base as NSString).substring(with: match.range(at: $0)))! }
                guard let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)),
                      calendar.dateComponents([.year, .month, .day], from: date) == DateComponents(year: parts[0], month: parts[1], day: parts[2]) else { continue }
                let era = eraFormatter.string(from: date)
                let known = parts[0] >= 1873 && ["令和", "平成", "昭和", "大正", "明治"].contains(era)
                let day = Day(year: parts[0], month: parts[1], day: parts[2], weekday: calendar.component(.weekday, from: date) - 1,
                              era: known ? era : nil, eraYear: japaneseCalendar.component(.year, from: date))
                if let text = make(day), let range = Range(match.range, in: result) { result.replaceSubrange(range, with: text); converted = true }
            }
            return converted ? result : nil
        }
        let weekdays = Array("日月火水木金土").map(String.init)
        let englishWeekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        let abbreviations = ["令和": "R", "平成": "H", "昭和": "S", "大正": "T", "明治": "M"]
        func two(_ value: Int) -> String { String(format: "%02d", value) }
        let kanjiDigits = Array("〇一二三四五六七八九").map(String.init)
        func fullwidth(_ text: String) -> String {
            String(String.UnicodeScalarView(text.unicodeScalars.map { (0x30...0x39).contains($0.value) ? UnicodeScalar($0.value + 0xFEE0)! : $0 }))
        }
        func kanji(_ value: Int) -> String { // 14 → 十四, 31 → 三十一
            let digits = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
            return value < 10 ? digits[value] : (value / 10 == 1 ? "" : digits[value / 10]) + "十" + digits[value % 10]
        }
        func eraYear(_ d: Day) -> String { d.eraYear == 1 ? "元" : String(d.eraYear) }
        // Without zero padding by default; `padded` offers the padded form first (identical ones are dropped).
        func both(_ make: @escaping (Day, (Int) -> String) -> String?) -> [String?] {
            (padded ? [format { make($0, two) }] : []) + [format { make($0, String.init) }]
        }
        let groups: [[String?]] = [
            both { "\($0.year)年\($1($0.month))月\($1($0.day))日" } + both { "\($0.year)年\($1($0.month))月\($1($0.day))日（\(weekdays[$0.weekday])）" }
                + both { "\($0.year)年\($1($0.month))月\($1($0.day))日（\(weekdays[$0.weekday])曜日）" }
                + both { "\($0.year)年\($1($0.month))月\($1($0.day))日 \(weekdays[$0.weekday])曜日" },
            both { d, p in d.era.map { "\($0)\(eraYear(d))年\(p(d.month))月\(p(d.day))日" } }
                + both { d, p in d.era.map { "\($0)\(eraYear(d))年\(p(d.month))月\(p(d.day))日（\(weekdays[d.weekday])）" } }
                + both { d, p in d.era.map { "\($0)\(eraYear(d))年\(p(d.month))月\(p(d.day))日（\(weekdays[d.weekday])曜日）" } },
            both { d, p in d.era.map { "\(abbreviations[$0]!)\(d.eraYear).\(p(d.month)).\(p(d.day))" } }
                + both { d, p in d.era.map { "\(abbreviations[$0]!)\(d.eraYear)/\(p(d.month))/\(p(d.day))" } },
            // Month and day alone read naturally only without zero padding.
            [format { "\($0.month)月\($0.day)日（\(weekdays[$0.weekday])）" }, format { "\($0.month)月\($0.day)日（\(weekdays[$0.weekday])曜日）" },
             format { "\($0.month)/\($0.day)（\(weekdays[$0.weekday])）" }],
            both { "\($0.year)-\($1($0.month))-\($1($0.day))" } + both { "\($0.year)/\($1($0.month))/\($1($0.day))" }
                + both { "\($0.year)/\($1($0.month))/\($1($0.day))（\(weekdays[$0.weekday])）" } + both { "\($0.year).\($1($0.month)).\($1($0.day))" }
                + [format { "\($0.year)\(two($0.month))\(two($0.day))" }],
            [format { "\(months[$0.month - 1].prefix(3)) \($0.day), \($0.year)" }, format { "\(months[$0.month - 1]) \($0.day), \($0.year)" },
             format { "\(englishWeekdays[$0.weekday]), \(months[$0.month - 1].prefix(3)) \($0.day), \($0.year)" }],
            [format { fullwidth("\($0.year)年\($0.month)月\($0.day)日") },
             format { "\($0.year)".map { kanjiDigits[$0.wholeNumberValue!] }.joined() + "年\(kanji($0.month))月\(kanji($0.day))日" },
             format { d in d.era.map { "\($0)\(d.eraYear == 1 ? "元" : kanji(d.eraYear))年\(kanji(d.month))月\(kanji(d.day))日" } }]
        ]
        var seen: Set<String> = [text]
        return groups.map { $0.compactMap { $0 }.filter { seen.insert($0).inserted } }.filter { !$0.isEmpty }
    }

    static func apply(_ text: String, operation: TextTransform, currentYear: Int? = nil) -> String {
        let calendar = self.calendar
        let thisYear = currentYear ?? calendar.component(.year, from: Date())
        let inputPattern = operation == .dateToCompact
            ? pattern.replacingOccurrences(of: "(?:(?<jy>", with: "(?:(?<cy>[0-9]{4})(?<cm>[0-9]{2})(?<cd>[0-9]{2})|(?<jy>")
            : pattern
        let regex = try! NSRegularExpression(pattern: inputPattern)
        let eraFormatter = DateFormatter()
        eraFormatter.locale = Locale(identifier: "ja_JP")
        eraFormatter.calendar = Calendar(identifier: .japanese)
        eraFormatter.timeZone = calendar.timeZone
        eraFormatter.dateFormat = "GGGG"
        var result = text
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            func value(_ name: String) -> String? {
                let range = match.range(withName: name)
                return range.location == NSNotFound ? nil : (text as NSString).substring(with: range)
            }
            func number(_ name: String) -> Int { Int(value(name) ?? "") ?? 0 }
            let sourceEra = value("era")
            let isISO = value("iy") != nil || value("hm") != nil
            let missingYear = value("nm") != nil || value("hm") != nil
            let year: Int
            let month: Int
            let day: Int
            if let sourceEra {
                let base = ["令和": 2018, "平成": 1988, "昭和": 1925, "大正": 1911, "明治": 1867][sourceEra]!
                let eraYear = value("ey") == "元" ? 1 : number("ey")
                guard eraYear > 0 else { continue }
                year = base + eraYear
                month = number("em"); day = number("ed")
            } else if operation == .dateToCompact && value("cy") != nil {
                year = number("cy"); month = number("cm"); day = number("cd")
            } else if value("jy") != nil {
                year = number("jy"); month = number("jm"); day = number("jd")
            } else if value("iy") != nil {
                year = number("iy"); month = number("im"); day = number("id")
            } else {
                year = thisYear
                month = number(isISO ? "hm" : "nm"); day = number(isISO ? "hd" : "nd")
            }
            guard (1...9999).contains(year), (1...12).contains(month), (1...31).contains(day),
                  let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) else { continue }
            let parts = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
            guard parts.year == year, parts.month == month, parts.day == day else { continue }
            // Gregorian dates only: Japanese lunisolar dates before 1873 are not inferred.
            if let sourceEra { guard year >= 1873, eraFormatter.string(from: date) == sourceEra else { continue } }
            let original = (text as NSString).substring(with: match.range)
            let suffix = value("weekday") ?? ""
            let baseText = suffix.isEmpty ? original : String(original.dropLast(suffix.count))
            let weekday = Array("日月火水木金土")[parts.weekday! - 1]
            let japanese = String(format: "%04d年%02d月%02d日", year, month, day)
            let iso = String(format: "%04d-%02d-%02d", year, month, day)
            let replacement: String
            switch operation {
            case .removeDatePadding:
                if isISO {
                    replacement = (missingYear ? "" : String(baseText.prefix(4)) + "-") + "\(month)-\(day)" + suffix
                } else if let monthEnd = baseText.firstIndex(of: "月") {
                    let prefix: String
                    if let yearEnd = baseText[..<monthEnd].lastIndex(of: "年") { prefix = String(baseText[...yearEnd]) }
                    else { prefix = "" }
                    replacement = prefix + "\(month)月\(day)日" + suffix
                } else { continue }
            case .dateToCompact:
                guard !missingYear else { continue }
                replacement = String(format: "%04d%02d%02d", year, month, day)
            case .dateToISO:
                guard !missingYear else { continue }
                replacement = iso + suffix
            case .dateToJapanese:
                guard !missingYear else { continue }
                replacement = japanese + suffix
            case .dateToEra:
                guard !missingYear, year >= 1873 else { continue }
                let era = eraFormatter.string(from: date)
                guard ["令和", "平成", "昭和", "大正", "明治"].contains(era) else { continue }
                var japaneseCalendar = Calendar(identifier: .japanese)
                japaneseCalendar.timeZone = calendar.timeZone
                let eraYear = japaneseCalendar.component(.year, from: date)
                replacement = era + (eraYear == 1 ? "元" : String(eraYear)) + String(format: "年%02d月%02d日", month, day) + suffix
            case .dateToGregorian:
                guard sourceEra != nil else { continue }
                replacement = japanese + suffix
            case .removeDateYear:
                guard !missingYear else { continue }
                // Preserve the source's month/day spelling when removing only its year.
                if isISO { replacement = String(baseText.dropFirst(5)) + suffix }
                else if let yearEnd = baseText.firstIndex(of: "年") { replacement = String(baseText[baseText.index(after: yearEnd)...]) + suffix }
                else { continue }
            case .addDateYear:
                guard missingYear else { continue }
                let updatedSuffix = suffix.isEmpty ? "" : "（\(weekday)\(suffix.contains("曜日") ? "曜日" : "")）"
                replacement = (isISO ? iso : japanese) + updatedSuffix
            case .weekdayShort, .weekdayLong:
                replacement = baseText + "（\(weekday)\(operation == .weekdayLong ? "曜日" : "")）"
            default: continue
            }
            if let range = Range(match.range, in: result) { result.replaceSubrange(range, with: replacement) }
        }
        return result
    }
}
