import Foundation

/// The folder name of the Keyboard Maestro macro 「Folder Maker（案件）」, now built from a pattern (名前の規則).
/// Default {client}-{project}-{date}-{memo} gives クライアント[-地域]-YYYYMMDD[-備考], e.g. ricoh-osaka-20261014.
struct FolderName: Equatable {
    var client = ""
    var region = ""
    var year = ""
    var month = ""
    var day = ""
    var memo = ""
    var useToday = true
    var pattern = FolderName.defaultPattern
    var dateStyle = DateStyle.compact

    static let defaultPattern = "{client}-{project}-{date}-{memo}"
    static let tokens = ["client", "project", "date", "memo"]

    /// How {date} is written. A missing day or month shortens it (2026-10, 2026).
    enum DateStyle: String, CaseIterable {
        case compact, hyphen, dot, underscore, short
        var example: String {
            switch self {
            case .compact: return "20261014"
            case .hyphen: return "2026-10-14"
            case .dot: return "2026.10.14"
            case .underscore: return "2026_10_14"
            case .short: return "261014"
            }
        }
        func format(_ y: Int, _ m: Int?, _ d: Int?) -> String {
            let separator: String
            switch self {
            case .compact, .short: separator = ""
            case .hyphen: separator = "-"
            case .dot: separator = "."
            case .underscore: separator = "_"
            }
            var parts = [self == .short ? String(format: "%02d", y % 100) : String(format: "%04d", y)]
            if let m { parts.append(String(format: "%02d", m)) }
            if m != nil, let d { parts.append(String(format: "%02d", d)) }
            return parts.joined(separator: separator)
        }
    }

    enum Problem: Error, Equatable {
        case emptyClient, badYear, badMonth, badDay, dayWithoutMonth, badCharacter, tooLong, emptyName, windowsName
        var key: String {
            switch self {
            case .emptyClient: return "problem.emptyClient"
            case .badYear: return "problem.badYear"
            case .badMonth: return "problem.badMonth"
            case .badDay: return "problem.badDay"
            case .dayWithoutMonth: return "problem.dayWithoutMonth"
            case .badCharacter: return "problem.badCharacter"
            case .tooLong: return "problem.tooLong"
            case .emptyName: return "problem.emptyName"
            case .windowsName: return "problem.windowsName"
            }
        }
    }

    /// The macro's 「西暦の計算」: from November on, new projects are for next year.
    static func defaultYear(for date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> Int {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return (parts.month ?? 1) < 11 ? parts.year! : parts.year! + 1
    }

    private static func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private static func number(_ text: String) -> Int? {
        // Full-width digits typed with the Japanese input method count as digits.
        let ascii = trimmed(text).applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? trimmed(text)
        guard !ascii.isEmpty, ascii.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(ascii)
    }

    /// The date in `dateStyle`; an empty day drops the day, an empty month drops month and day.
    func datePart(today: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> Result<String, Problem> {
        if useToday {
            let p = calendar.dateComponents([.year, .month, .day], from: today)
            return .success(dateStyle.format(p.year!, p.month!, p.day!))
        }
        guard let y = Self.number(year), (1000...9999).contains(y) else { return .failure(.badYear) }
        let monthText = Self.trimmed(month), dayText = Self.trimmed(day)
        if monthText.isEmpty { return dayText.isEmpty ? .success(dateStyle.format(y, nil, nil)) : .failure(.dayWithoutMonth) }
        guard let m = Self.number(monthText), (1...12).contains(m) else { return .failure(.badMonth) }
        if dayText.isEmpty { return .success(dateStyle.format(y, m, nil)) }
        guard let d = Self.number(dayText), (1...31).contains(d),
              let date = calendar.date(from: DateComponents(year: y, month: m, day: d)),
              calendar.component(.day, from: date) == d else { return .failure(.badDay) }
        return .success(dateStyle.format(y, m, d))
    }

    /// Fills the pattern. An empty item is left out together with the separator before it
    /// (or after it, when it comes first), so "{client}-{region}-{date}" without a region is client-date.
    static func render(_ pattern: String, _ values: [String: String]) -> String {
        enum Part { case literal(String), token(String) }
        var parts: [Part] = []
        var rest = Substring(pattern)
        while let open = rest.firstIndex(of: "{") {
            guard let close = rest[open...].firstIndex(of: "}") else { break }
            let name = String(rest[rest.index(after: open)..<close])
            if values.keys.contains(name) {
                if open > rest.startIndex { parts.append(.literal(String(rest[..<open]))) }
                parts.append(.token(name))
            } else {
                parts.append(.literal(String(rest[...close])))
            }
            rest = rest[rest.index(after: close)...]
        }
        if !rest.isEmpty { parts.append(.literal(String(rest))) }
        var out: [Part] = []
        var dropNextLiteral = false
        var anyValue = false
        for part in parts {
            switch part {
            case .literal(let text):
                if dropNextLiteral { dropNextLiteral = false; continue }
                out.append(.literal(text))
            case .token(let name):
                let value = values[name] ?? ""
                if value.isEmpty {
                    if case .literal? = out.last, anyValue { out.removeLast() } else { dropNextLiteral = true }
                } else {
                    out.append(.literal(value)); anyValue = true; dropNextLiteral = false
                }
            }
        }
        return out.map { if case .literal(let text) = $0 { return text } else { return "" } }.joined()
    }

    func build(today: Date = Date()) -> Result<String, Problem> {
        let client = Self.trimmed(client), region = Self.trimmed(region), memo = Self.trimmed(memo)
        var date = ""
        if pattern.contains("{date}") {
            switch datePart(today: today) {
            case .failure(let problem): return .failure(problem)
            case .success(let value): date = value
            }
        }
        // {region} is the 1.5 name of {project} (the field was 地域); old patterns keep working.
        let name = Self.render(pattern, ["client": client, "project": region, "region": region, "date": date, "memo": memo])
            .trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return .failure(.emptyName) }
        // "/" cannot be in a file name and ":" shows as "/" in Finder; a leading "." would hide the folder.
        if name.contains("/") || name.contains(":") || name.hasPrefix(".") || name.contains(where: { $0.isNewline }) { return .failure(.badCharacter) }
        if name.utf8.count > 255 { return .failure(.tooLong) }
        return .success(name)
    }
}

/// Bulk mode: one folder per line of pasted text. "/" in a line makes subfolders (案件/素材).
enum BulkNames {
    struct Entry: Equatable {
        /// The line as typed (after trimming), for the preview.
        var line: String
        /// Relative path to create, or nil when the line cannot be used.
        var path: String?
        var problem: FolderName.Problem?
        /// An empty file instead of a folder (projects only).
        var isFile = false
        /// Template named in the structure ("index.html < html5.html").
        var template: String?
    }

    /// Bullets and numbering that come with pasted lists: "- ", "* ", "・", "•", "1. ", "1) ".
    static func stripBullet(_ line: String) -> String {
        var text = line
        for bullet in ["- ", "* ", "+ ", "・", "•", "◦", "‣"] where text.hasPrefix(bullet) {
            text.removeFirst(bullet.count); return text.trimmingCharacters(in: .whitespaces)
        }
        if let range = text.range(of: #"^\d{1,3}[.)] +"#, options: .regularExpression) { text.removeSubrange(range) }
        return text.trimmingCharacters(in: .whitespaces)
    }

    /// Heading lines: a line followed by "+" lines is not made itself; each "+" line becomes 「見出し 項目」
    /// (Project / +A / +B → Project A, Project B). A blank line or the next heading ends the group.
    /// "+" lines without a heading are made as they are. ("-" is a level, like "/".) Projects pass grouping: false.
    static func expandHeadings(_ text: String) -> [String] {
        var result: [String] = []
        var heading: String?
        var used = false
        func flush() { if let heading, !used { result.append(heading) }; heading = nil; used = false }
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { flush(); result.append(""); continue }
            if line.hasPrefix("+") {
                let item = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                if let heading { if !item.isEmpty { result.append(heading + " " + item) }; used = true }
                else if !item.isEmpty { result.append(item) }
            } else {
                flush(); heading = line
            }
        }
        flush()
        return result
    }

    /// Ranges: "A...C" → A, B, C; "1...3" → 1, 2, 3; "01...12" keeps the zero padding. "…" works too; "*" counts (takano-4*3 → 4, 5, 6; takano-*3 → 1, 2, 3).
    /// The first range in a line is expanded (prefix and suffix kept); up to 500 items, descending ranges allowed.
    static func expandRange(_ line: String) -> [String] {
        // A letter range must not touch other letters ("abc...def" stays a name); a number range must not touch digits.
        // "A...C" / "1...3": start to end. "*" counts instead: "4*3" → 4, 5, 6; "*3" starts at 1; "A*3" → A, B, C.
        let pattern = #"(?<![A-Za-z])([A-Za-z])(?:\.\.\.|…)([A-Za-z])(?![A-Za-z])|(?<!\d)(\d+)(?:\.\.\.|…)(\d+)(?!\d)|(?<!\d)(\d+)\*(\d+)(?!\d)|(?<![A-Za-z])([A-Za-z])\*(\d+)(?!\d)|(?<![A-Za-z0-9])\*(\d+)(?!\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let whole = Range(match.range, in: line) else { return [line] }
        func group(_ i: Int) -> String? { Range(match.range(at: i), in: line).map { String(line[$0]) } }
        var start: String, end: String
        if let a = group(1), let b = group(2) { start = a; end = b }
        else if let a = group(3), let b = group(4) { start = a; end = b }
        else if let a = group(5), let n = Int(group(6) ?? ""), n > 0, let s = Int(a) {
            start = a
            let last = String(s + n - 1)
            end = a.hasPrefix("0") ? String(repeating: "0", count: max(0, a.count - last.count)) + last : last
        } else if let a = group(7), let n = Int(group(8) ?? ""), n > 0, let scalar = a.unicodeScalars.first,
                  let lastScalar = UnicodeScalar(scalar.value + UInt32(n - 1)),
                  CharacterSet.letters.contains(lastScalar), CharacterSet.uppercaseLetters.contains(scalar) == CharacterSet.uppercaseLetters.contains(lastScalar) {
            start = a; end = String(lastScalar)
        } else if let b = group(9), let n = Int(b), n > 0 {
            start = b.hasPrefix("0") ? String(repeating: "0", count: max(0, b.count - 1)) + "1" : "1"
            end = b.hasPrefix("0") ? String(repeating: "0", count: max(0, b.count - String(n).count)) + String(n) : String(n)
        } else { return [line] }
        let prefix = String(line[..<whole.lowerBound]), suffix = String(line[whole.upperBound...])
        var items: [String] = []
        if let x = Int(start), let y = Int(end) {
            let width = (start.hasPrefix("0") || end.hasPrefix("0")) ? max(start.count, end.count) : 0
            guard abs(y - x) < 500 else { return [line] }
            for n in stride(from: x, through: y, by: x <= y ? 1 : -1) {
                let digits = String(n)
                items.append(String(repeating: "0", count: max(0, width - digits.count)) + digits)
            }
        } else if let x = start.unicodeScalars.first, let y = end.unicodeScalars.first,
                  start.count == 1, end.count == 1, Int(start) == nil, Int(end) == nil,
                  (CharacterSet.uppercaseLetters.contains(x)) == (CharacterSet.uppercaseLetters.contains(y)) {
            for v in stride(from: Int(x.value), through: Int(y.value), by: x.value <= y.value ? 1 : -1) {
                items.append(String(UnicodeScalar(UInt32(v))!))
            }
        } else {
            return [line]
        }
        return items.map { prefix + $0 + suffix }
    }

    /// Options for checking names: Windows-safe names when the folders are shared with Windows, and whether the
    /// destination volume tells "A" from "a" (then "ABC" and "abc" are two folders).
    struct Options: Equatable {
        var windowsSafe = false
        var caseSensitive = false
        static let standard = Options()
    }

    /// Indentation (tabs, or spaces with the shallowest indent as one level) becomes leading "/", as in projects.
    /// Lines that start with "-" or a bullet are only trimmed, so heading items keep working.
    static func indentToSlashes(_ text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        let unit = max(1, lines.compactMap { line -> Int? in
            let spaces = line.prefix { $0 == " " }.count
            return spaces > 0 && !line.trimmingCharacters(in: .whitespaces).isEmpty ? spaces : nil
        }.min() ?? 1)
        return lines.map { line in
            let rest = line.drop { $0 == " " || $0 == "\t" }
            // "+" items (headings) and other bullets keep their place; they are not levels.
            if rest.isEmpty || rest.hasPrefix("+") { return String(rest) }
            var body = rest
            var dashes = 0
            // Leading "-" works like "/": "-marine" goes into the line above, "--" one level deeper.
            while body.first == "-" { dashes += 1; body = body.dropFirst() }
            if dashes > 0 { body = body.drop { $0 == " " } }
            let indent = line.prefix { $0 == " " || $0 == "\t" }
            let level = indent.filter { $0 == "\t" }.count + Int((Double(indent.filter { $0 == " " }.count) / Double(unit)).rounded()) + dashes
            return String(repeating: "/", count: level) + body
        }
    }

    /// Leading "/" puts a line inside the line above it with one "/" fewer: "masahiro" then "/marine" is masahiro/marine.
    /// A level without such a line, or anything under a file, keeps an empty part and is shown as unusable.
    static func resolveLevels(_ lines: [String]) -> [String] {
        var stack: [(path: String, isFile: Bool)] = []
        var result: [String] = []
        for raw in lines {
            var rest = Substring(raw)
            var level = 0
            while rest.first == "/" { level += 1; rest = rest.dropFirst() }
            let body = stripBullet(rest.trimmingCharacters(in: .whitespaces))
            // A blank line ends the levels: the next "/" line has nothing to go into.
            guard !body.isEmpty else { if level == 0 { stack = []; result.append(raw) }; continue }
            // The part that names the item (without "< template" and a trailing "/").
            var name = body
            if let mark = name.firstIndex(of: "<") { name = name[..<mark].trimmingCharacters(in: .whitespaces) }
            let forcedFolder = name.hasSuffix("/")
            while name.hasSuffix("/") { name.removeLast() }
            var parent = ""
            if level > 0 {
                if level <= stack.count, !stack[level - 1].isFile { parent = stack[level - 1].path + "/" }
                else { parent = "/" }  // no line to go into: an empty first part makes it unusable
            }
            result.append(parent + body)
            stack = Array(stack.prefix(level))
            stack.append((parent + name, !forcedFolder && Project.looksLikeFile(name.components(separatedBy: "/").last ?? name)))
        }
        return result
    }

    static func parse(_ text: String, grouping: Bool = true, options: Options = .standard) -> [Entry] {
        var seen = Set<String>()
        var entries: [Entry] = []
        let lines = grouping
            ? resolveLevels(expandHeadings(indentToSlashes(text).joined(separator: "\n")).flatMap(expandRange))
            : text.components(separatedBy: .newlines)
        for raw in lines {
            let line = stripBullet(raw.trimmingCharacters(in: .whitespaces))
            guard !line.isEmpty else { continue }
            // Files as in projects: a name with an extension is a file ("memo.txt"), "name < template.ext" picks its
            // template, and a trailing "/" keeps a dotted name a folder ("example.com/").
            var body = line
            var template: String?
            if let mark = body.firstIndex(of: "<") {
                let left = body[..<mark].trimmingCharacters(in: .whitespaces)
                if Project.looksLikeFile(left.components(separatedBy: "/").last ?? left) {
                    template = body[body.index(after: mark)...].trimmingCharacters(in: .whitespaces)
                    body = left
                }
            }
            let forcedFolder = body.hasSuffix("/")
            while body.hasSuffix("/") { body.removeLast() }
            let parts = body.split(separator: "/", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
            var problem: FolderName.Problem?
            for part in parts {
                if part.isEmpty || part == "." || part == ".." || part.hasPrefix(".") || part.contains(":") { problem = .badCharacter; break }
                if part.utf8.count > 255 { problem = .tooLong; break }
                if options.windowsSafe && FileNames.windowsProblem(part) { problem = .windowsName; break }
            }
            if let problem { entries.append(Entry(line: line, path: nil, problem: problem)); continue }
            let path = parts.joined(separator: "/")
            // The same folder twice in the paste is listed once.
            guard seen.insert(options.caseSensitive ? path : path.lowercased()).inserted else { continue }
            let isFile = !forcedFolder && Project.looksLikeFile(parts.last ?? "")
            entries.append(Entry(line: line, path: path, problem: nil, isFile: isFile, template: isFile ? template : nil))
        }
        return entries
    }
}

/// The preview as a tree: each item shows its own name, indented under the nearest item above it that holds it.
/// Without such an item ("x/y" alone) the rest of the path is shown at that level.
enum TreeRows {
    struct Row: Equatable { var depth: Int; var label: String }
    static func rows(_ paths: [String?], lines: [String]) -> [Row] {
        var depthOf: [String: Int] = [:]
        var rows: [Row] = []
        for (index, path) in paths.enumerated() {
            guard let path else { rows.append(Row(depth: 0, label: lines[index])); continue }
            let parts = path.split(separator: "/").map(String.init)
            var depth = 0, start = 0
            // Nearest listed ancestor (longest prefix).
            for cut in stride(from: parts.count - 1, through: 1, by: -1) {
                let ancestor = parts[..<cut].joined(separator: "/").lowercased()
                if let d = depthOf[ancestor] { depth = d + 1; start = cut; break }
            }
            depthOf[path.lowercased()] = depth
            rows.append(Row(depth: depth, label: parts[start...].joined(separator: "/")))
        }
        return rows
    }
}
