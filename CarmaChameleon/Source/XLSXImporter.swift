import Foundation

/// Excel (.xlsx) → HTML tables, one per sheet, for pandoc's HTML reader.
/// pandoc's own xlsx reader prints integers as "120.0" and dates as serial numbers; this keeps values
/// as Excel shows them: integers without decimals, dates as yyyy/MM/dd, formulas as their cached results.
enum XLSXImporter {
    static func error(_ key: String) -> NSError {
        NSError(domain:"PandocDesk.XLSX",code:1,userInfo:[NSLocalizedDescriptionKey:NSLocalizedString(key,comment:"")])
    }

    /// Reads an archive entry with the IDML importer's bounded unzip, reporting Excel-specific errors.
    private static func entry(_ archive: URL, _ name: String, cancelled: () -> Bool) throws -> IDMLImporter.Node? {
        do { return try IDMLImporter.parse(IDMLImporter.read(archive, name, cancelled: cancelled)) }
        catch is CancellationError { throw CancellationError() }
        catch let failure as NSError where failure.domain == "PandocDesk.IDML" {
            if failure.localizedDescription == NSLocalizedString("idmlTooLarge", comment: "") { throw error("xlsxTooLarge") }
            return nil
        }
    }

    static func html(from archive: URL, cancelled: () -> Bool) throws -> String {
        guard let workbook = try entry(archive, "xl/workbook.xml", cancelled: cancelled) else { throw error("xlsxInvalid") }
        let relations = try entry(archive, "xl/_rels/workbook.xml.rels", cancelled: cancelled)
        var targets: [String: String] = [:]
        var sharedPath = "xl/sharedStrings.xml", stylesPath = "xl/styles.xml"
        for relation in relations?.descendants("Relationship") ?? [] {
            guard let id = relation.attributes["Id"], let target = relation.attributes["Target"] else { continue }
            let path = target.hasPrefix("/") ? String(target.dropFirst()) : "xl/" + target
            targets[id] = path
            let type = relation.attributes["Type"] ?? ""
            if type.hasSuffix("/sharedStrings") { sharedPath = path }
            if type.hasSuffix("/styles") { stylesPath = path }
        }
        let shared: [String] = (try entry(archive, sharedPath, cancelled: cancelled))?.descendants("si").map { item in
            item.descendants("t").map(\.text).joined()
        } ?? []
        let dateStyles = dateStyleIndexes(try entry(archive, stylesPath, cancelled: cancelled))
        let date1904 = workbook.descendants("workbookPr").first?.attributes["date1904"].map { $0 == "1" || $0 == "true" } ?? false

        var body = ""
        var tables = 0
        for sheet in workbook.descendants("sheet") {
            if cancelled() { throw CancellationError() }
            let id = sheet.attributes["r:id"] ?? sheet.attributes["id"] ?? sheet.attributes.first { $0.key.hasSuffix(":id") }?.value ?? ""
            guard let path = targets[id], let worksheet = try entry(archive, path, cancelled: cancelled) else { continue }
            let rows = cells(worksheet, shared: shared, dateStyles: dateStyles, date1904: date1904)
            guard !rows.isEmpty else { continue }
            tables += 1
            body += "<h2>" + escape(sheet.attributes["name"] ?? "Sheet") + "</h2>\n<table>\n<thead><tr>"
            body += rows[0].map { "<th>" + escape($0) + "</th>" }.joined() + "</tr></thead>\n<tbody>\n"
            for row in rows.dropFirst() { body += "<tr>" + row.map { "<td>" + escape($0) + "</td>" }.joined() + "</tr>\n" }
            body += "</tbody>\n</table>\n"
        }
        guard tables > 0 else { throw error("xlsxEmpty") }
        return "<!doctype html><html><head><meta charset=\"utf-8\"></head><body>\n" + body + "</body></html>\n"
    }

    /// Rows of display strings; trailing empty rows and columns are removed.
    private static func cells(_ worksheet: IDMLImporter.Node, shared: [String], dateStyles: Set<Int>, date1904: Bool) -> [[String]] {
        var grid: [Int: [Int: String]] = [:]
        var nextRow = 0
        for row in worksheet.descendants("row") {
            let rowIndex = (row.attributes["r"].flatMap(Int.init) ?? nextRow + 1) - 1
            nextRow = rowIndex + 1
            var nextColumn = 0
            for cell in row.children where cell.name == "c" {
                let column = cell.attributes["r"].map(columnIndex) ?? nextColumn
                nextColumn = column + 1
                let value = cell.children.first { $0.name == "v" }?.text ?? ""
                let text: String
                switch cell.attributes["t"] ?? "n" {
                case "s": text = Int(value).flatMap { shared.indices.contains($0) ? shared[$0] : nil } ?? ""
                case "inlineStr": text = cell.descendants("t").map(\.text).joined()
                case "b": text = value == "1" ? "TRUE" : "FALSE"
                case "str", "e": text = value
                default:
                    guard let number = Double(value) else { text = value; break }
                    let style = cell.attributes["s"].flatMap(Int.init) ?? 0
                    text = dateStyles.contains(style) ? formatDate(number, date1904: date1904) : formatNumber(number)
                }
                if !text.isEmpty { grid[rowIndex, default: [:]][column] = text }
            }
        }
        guard let lastRow = grid.keys.max(), let lastColumn = grid.values.flatMap(\.keys).max() else { return [] }
        let firstRow = grid.keys.min() ?? 0
        return (firstRow...lastRow).map { r in (0...lastColumn).map { grid[r]?[$0] ?? "" } }
    }

    /// "B12" → 1
    private static func columnIndex(_ reference: String) -> Int {
        var index = 0
        for scalar in reference.unicodeScalars {
            guard scalar.value >= 65 && scalar.value <= 90 else { break }
            index = index * 26 + Int(scalar.value - 64)
        }
        return max(0, index - 1)
    }

    static func formatNumber(_ number: Double) -> String {
        if number.rounded() == number && abs(number) < 1e15 { return String(Int64(number)) }
        return String(format: "%.15g", number)
    }

    static func formatDate(_ serial: Double, date1904: Bool) -> String {
        // Excel's 1900 system counts the fictional 1900-02-29, so serial 60+ is offset by one day.
        let days = date1904 ? serial + 1462 : (serial < 60 ? serial + 1 : serial)
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "UTC")!
        let base = calendar.date(from: DateComponents(year: 1899, month: 12, day: 30))!
        let date = base.addingTimeInterval((days * 86400).rounded())
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = serial.rounded(.down) == serial ? "yyyy/MM/dd" : (serial < 1 ? "HH:mm" : "yyyy/MM/dd HH:mm")
        return formatter.string(from: date)
    }

    /// Cell style indexes (cellXfs) whose number format is a date or time.
    private static func dateStyleIndexes(_ styles: IDMLImporter.Node?) -> Set<Int> {
        guard let styles else { return [] }
        var customDate: Set<Int> = []
        for format in styles.descendants("numFmt") {
            guard let id = format.attributes["numFmtId"].flatMap(Int.init), let code = format.attributes["formatCode"] else { continue }
            // Ignore quoted text and [colour]/[locale] sections, then look for date/time tokens.
            let stripped = code.replacingOccurrences(of: "\"[^\"]*\"|\\[[^\\]]*\\]|\\\\.", with: "", options: .regularExpression).lowercased()
            if stripped.range(of: "[ymdhs]", options: .regularExpression) != nil && !stripped.contains("general") { customDate.insert(id) }
        }
        let builtinDate: Set<Int> = Set(14...22).union([27, 30, 36, 45, 46, 47, 50, 57])
        guard let cellXfs = styles.descendants("cellXfs").first else { return [] }
        var result: Set<Int> = []
        for (index, xf) in cellXfs.children.filter({ $0.name == "xf" }).enumerated() {
            guard let id = xf.attributes["numFmtId"].flatMap(Int.init) else { continue }
            if builtinDate.contains(id) || customDate.contains(id) { result.insert(index) }
        }
        return result
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\n", with: "<br>")
    }
}
