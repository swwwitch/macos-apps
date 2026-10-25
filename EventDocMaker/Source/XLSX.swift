import Foundation

/// Reads the cell values (cached results for formulas) of one sheet of an .xlsx file.
/// Phonetic guides (ルビ, <rPh>) in shared strings are left out.
enum XLSX {
    enum Failure: LocalizedError {
        case unreadable(String), noSheet(String)
        var errorDescription: String? {
            switch self {
            case .unreadable(let part): return String(format: L("xlsx.unreadable"), part)
            case .noSheet(let name): return String(format: L("xlsx.noSheet"), name)
            }
        }
    }

    /// (column, row) → value, 1-based.
    static func read(_ file: URL, sheet name: String?) throws -> [Cell: String] {
        let workbook = try part(file, "xl/workbook.xml")
        let rels = try part(file, "xl/_rels/workbook.xml.rels")
        let sheets = Attributes.collect(workbook, element: "sheet")
        guard let sheet = sheets.first(where: { name == nil || $0["name"] == name }), let rid = sheet["r:id"],
              let target = Attributes.collect(rels, element: "Relationship").first(where: { $0["Id"] == rid })?["Target"] else {
            throw Failure.noSheet(name ?? "")
        }
        let path = target.hasPrefix("/") ? String(target.dropFirst()) : "xl/" + target
        let strings = (try? part(file, "xl/sharedStrings.xml")).map(SharedStrings.parse) ?? []
        return SheetCells.parse(try part(file, path), strings: strings)
    }

    struct Cell: Hashable { let column: Int; let row: Int }

    static func column(_ letters: Substring) -> Int { letters.reduce(0) { $0 * 26 + Int($1.asciiValue! - 64) } }

    private static func part(_ file: URL, _ name: String) throws -> Data {
        let process = Process(), pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", file.path, name]
        process.standardOutput = pipe; process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, !data.isEmpty else { throw Failure.unreadable(name) }
        return data
    }

    private final class Attributes: NSObject, XMLParserDelegate {
        var element = "", found: [[String: String]] = []
        static func collect(_ data: Data, element: String) -> [[String: String]] {
            let delegate = Attributes(); delegate.element = element
            let parser = XMLParser(data: data); parser.delegate = delegate; parser.parse()
            return delegate.found
        }
        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
            if name == element { found.append(attributes) }
        }
    }

    private final class SharedStrings: NSObject, XMLParserDelegate {
        var items: [String] = [], current = "", inText = false, phonetic = 0
        static func parse(_ data: Data) -> [String] {
            let delegate = SharedStrings(); let parser = XMLParser(data: data); parser.delegate = delegate; parser.parse()
            return delegate.items
        }
        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
            switch name {
            case "si": current = ""
            case "rPh": phonetic += 1
            case "t": inText = phonetic == 0
            default: break
            }
        }
        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            switch name {
            case "si": items.append(current)
            case "rPh": phonetic -= 1
            case "t": inText = false
            default: break
            }
        }
        func parser(_ parser: XMLParser, foundCharacters string: String) { if inText { current += string } }
    }

    private final class SheetCells: NSObject, XMLParserDelegate {
        var strings: [String] = [], cells: [Cell: String] = [:]
        var ref = "", type = "", value = "", inValue = false, inline = ""
        static func parse(_ data: Data, strings: [String]) -> [Cell: String] {
            let delegate = SheetCells(); delegate.strings = strings
            let parser = XMLParser(data: data); parser.delegate = delegate; parser.parse()
            return delegate.cells
        }
        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
            switch name {
            case "c": ref = attributes["r"] ?? ""; type = attributes["t"] ?? ""; value = ""; inline = ""
            case "v", "t": inValue = true
            default: break
            }
        }
        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            switch name {
            case "v", "t": inValue = false
            case "c":
                var text = type == "inlineStr" ? inline : value
                if type == "s", let index = Int(value), strings.indices.contains(index) { text = strings[index] }
                let letters = ref.prefix { $0.isLetter }, digits = ref.drop { $0.isLetter }
                if !text.isEmpty, let row = Int(digits), !letters.isEmpty { cells[Cell(column: XLSX.column(letters), row: row)] = text }
            default: break
            }
        }
        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard inValue else { return }
            if type == "inlineStr" { inline += string } else { value += string }
        }
    }
}

/// Events in the sheet 「新しいまとめ」: labels in column A, one event per column from B (row 3 holds its number #).
enum SheetImport {
    static let sheetName = "新しいまとめ"
    static let defaultFile = NSHomeDirectory() + "/sw Dropbox/takano masahiro/Dropbox-shared/livestream-配信/配信に関してのまとめ.xlsx"

    static func events(from cells: [XLSX.Cell: String]) -> [[String: String]] {
        // Row of each field: the n-th row whose column-A label (trimmed) matches.
        var rowOf: [String: Int] = [:], seen: [String: Int] = [:], numberRow: Int?
        for row in (cells.keys.filter { $0.column == 1 }.map(\.row)).sorted() {
            let label = cells[XLSX.Cell(column: 1, row: row)]!.trimmingCharacters(in: .whitespaces)
            if label == "#" { numberRow = row; continue }
            seen[label, default: 0] += 1
            if let field = Schema.fields.first(where: { $0.excelLabel.trimmingCharacters(in: .whitespaces) == label && $0.occurrence == seen[label] }) { rowOf[field.key] = row }
        }
        guard let numberRow else { return [] }
        // Event columns: the run from B while row # holds a number (the lookup columns further right are not events).
        var events: [[String: String]] = []
        var column = 2
        while let number = cells[XLSX.Cell(column: column, row: numberRow)], Int(number) != nil {
            var values: [String: String] = ["#": number]
            for (key, row) in rowOf {
                guard let raw = cells[XLSX.Cell(column: column, row: row)], let field = Schema.field(key) else { continue }
                values[key] = convert(raw, field.kind)
            }
            events.append(values)
            column += 1
        }
        return events
    }

    /// Excel dates are day serials from 1899-12-30; times are fractions of a day.
    static func convert(_ raw: String, _ kind: Field.Kind) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let number = Double(text) else { return text }
        switch kind {
        case .compactDate, .isoDate:
            guard number > 1000, let date = utc.date(byAdding: .day, value: Int(number), to: excelEpoch) else { return text }
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = kind == .compactDate ? "yyyyMMdd" : "yyyy-MM-dd"
            return formatter.string(from: date)
        case .time:
            guard number < 1 else { return text }
            let minutes = Int((number * 24 * 60).rounded())
            return String(format: "%02d:%02d", minutes / 60, minutes % 60)
        default:
            if number == number.rounded(), abs(number) < 1e15 { return String(Int(number)) }
            return String(format: "%.6f", number).replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
        }
    }
    private static let utc: Calendar = { var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "UTC")!; return calendar }()
    private static let excelEpoch: Date = {
        var components = DateComponents(); components.year = 1899; components.month = 12; components.day = 30
        return utc.date(from: components)!
    }()
}
