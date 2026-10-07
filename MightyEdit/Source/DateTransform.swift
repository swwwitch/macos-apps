import Foundation

enum DateTransform {
    static let operations: [TextTransform] = [.dateToISO, .dateToCompact, .removeDatePadding, .dateToJapanese, .dateToEra, .dateToGregorian, .removeDateYear, .addDateYear, .weekdayShort, .weekdayLong]
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }
    private static let pattern = #"(?<![0-9０-９年-])(?:(?<jy>[0-9]{4})年(?<jm>[0-9]{1,2})月(?<jd>[0-9]{1,2})日|(?<iy>[0-9]{4})-(?<im>[0-9]{1,2})-(?<id>[0-9]{1,2})|(?<era>令和|平成|昭和|大正|明治)(?<ey>元|[0-9]{1,4})年(?<em>[0-9]{1,2})月(?<ed>[0-9]{1,2})日|(?<nm>[0-9]{1,2})月(?<nd>[0-9]{1,2})日|(?<hm>[0-9]{1,2})-(?<hd>[0-9]{1,2})(?!-[0-9]))(?![0-9０-９])(?<weekday>（[日月火水木金土](?:曜日)?）|\([日月火水木金土](?:曜日)?\))?"#

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
