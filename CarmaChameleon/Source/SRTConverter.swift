import Foundation

/// Subtitles (.srt) → CSV / TSV / Excel (.xlsx), one row per cue: number, start time (HH:MM:SS), handle, comment.
/// A cue text "handle: comment" is split at the first ": "; text without it becomes the comment with an empty handle.
/// Multi-line cue text is joined with a space. The header row starts with "#".
enum SRTConverter {
    struct Cue: Equatable { let number: String; let time: String; let handle: String; let comment: String }

    static func parse(_ source: String) -> [Cue] {
        var text = source.replacingOccurrences(of:"\r\n", with:"\n").replacingOccurrences(of:"\r", with:"\n")
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        let timing = try! NSRegularExpression(pattern:"^\\s*(\\d{1,2}):(\\d{2}):(\\d{2})[,.]\\d{1,3}\\s*-->")
        var cues: [Cue] = []
        for block in text.components(separatedBy:"\n\n") {
            let lines = block.components(separatedBy:"\n").filter { !$0.trimmingCharacters(in:.whitespaces).isEmpty }
            guard let timeIndex = lines.firstIndex(where: { timing.firstMatch(in:$0, range:NSRange($0.startIndex..., in:$0)) != nil }) else { continue }
            let timeLine = lines[timeIndex]
            let match = timing.firstMatch(in:timeLine, range:NSRange(timeLine.startIndex..., in:timeLine))!
            let part = { (i: Int) in String(timeLine[Range(match.range(at:i), in:timeLine)!]) }
            let time = String(format:"%02d", Int(part(1)) ?? 0) + ":" + part(2) + ":" + part(3)
            let number = timeIndex > 0 ? lines[timeIndex - 1].trimmingCharacters(in:.whitespaces) : String(cues.count + 1)
            let body = lines[(timeIndex + 1)...].map { $0.trimmingCharacters(in:.whitespaces) }.joined(separator:" ")
            if let colon = body.range(of:": ") {
                cues.append(Cue(number:number, time:time, handle:String(body[..<colon.lowerBound]), comment:String(body[colon.upperBound...])))
            } else {
                cues.append(Cue(number:number, time:time, handle:"", comment:body))
            }
        }
        return cues
    }

    /// CSV quotes fields that need it (RFC 4180); TSV replaces tabs inside fields with spaces.
    static func table(_ cues: [Cue], delimiter: String, header: [String]) -> String {
        func field(_ value: String) -> String {
            if delimiter == "\t" { return value.replacingOccurrences(of:"\t", with:" ") }
            guard value.contains(delimiter) || value.contains("\"") || value.contains("\n") else { return value }
            return "\"" + value.replacingOccurrences(of:"\"", with:"\"\"") + "\""
        }
        let rows = [header] + cues.map { [$0.number, $0.time, $0.handle, $0.comment] }
        return rows.map { $0.map(field).joined(separator:delimiter) }.joined(separator:"\n") + "\n"
    }

    /// Workbook with inline strings (no shared strings or styles); "#" is a number, the rest text.
    /// rowsPerSheet > 0 splits the cues into sheets named by their row range ("1-100", "101-200"…), each with the header row.
    static func writeXLSX(_ cues: [Cue], header: [String], sheet: String, rowsPerSheet: Int = 0, to output: URL) throws {
        let fm = FileManager.default
        let package = fm.temporaryDirectory.appendingPathComponent("PandocDesk-xlsx-" + UUID().uuidString, isDirectory:true)
        defer { try? fm.removeItem(at:package) }
        func save(_ path: String, _ body: String) throws {
            let url = package.appendingPathComponent(path)
            try fm.createDirectory(at:url.deletingLastPathComponent(), withIntermediateDirectories:true)
            try Data(("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n" + body).utf8).write(to:url)
        }
        func cell(_ value: String, _ column: Int, _ row: Int) -> String {
            let ref = String(UnicodeScalar(UInt8(65 + column))) + String(row)
            if column == 0, row > 1, Int(value) != nil { return "<c r=\"\(ref)\"><v>\(value)</v></c>" }
            return "<c r=\"\(ref)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(IDMLImporter.escape(value))</t></is></c>"
        }
        func sheetXML(_ part: ArraySlice<Cue>) -> String {
            let rows = ([header] + part.map { [$0.number, $0.time, $0.handle, $0.comment] }).enumerated().map { index, values in
                "<row r=\"\(index + 1)\">" + values.enumerated().map { cell($1, $0, index + 1) }.joined() + "</row>"
            }.joined()
            return "<worksheet xmlns=\"\(main)\"><sheetViews><sheetView workbookViewId=\"0\"><pane ySplit=\"1\" topLeftCell=\"A2\" activePane=\"bottomLeft\" state=\"frozen\"/></sheetView></sheetViews><cols><col min=\"1\" max=\"1\" width=\"6\" customWidth=\"1\"/><col min=\"2\" max=\"2\" width=\"10\" customWidth=\"1\"/><col min=\"3\" max=\"3\" width=\"16\" customWidth=\"1\"/><col min=\"4\" max=\"4\" width=\"80\" customWidth=\"1\"/></cols><sheetData>\(rows)</sheetData></worksheet>"
        }
        let main = "http://schemas.openxmlformats.org/spreadsheetml/2006/main", rel = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        let size = rowsPerSheet > 0 ? rowsPerSheet : max(cues.count, 1)
        let parts = stride(from:0, to:max(cues.count, 1), by:size).map { cues[min($0, cues.count)..<min($0 + size, cues.count)] }
        // Excel refuses sheet names over 31 characters or with []:*?/\.
        let base = String(sheet.map { "[]:*?/\\".contains($0) ? "_" : $0 })
        func sheetName(_ index: Int) -> String {
            guard parts.count > 1 else { return String((base.isEmpty ? "Sheet1" : base).prefix(31)) }
            let first = parts[index].startIndex + 1, last = parts[index].endIndex
            return first == last ? String(first) : "\(first)-\(last)"
        }
        let indices = parts.indices
        try save("[Content_Types].xml", "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" + indices.map { "<Override PartName=\"/xl/worksheets/sheet\($0 + 1).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" }.joined() + "</Types>")
        try save("_rels/.rels", "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"\(rel)/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>")
        try save("xl/workbook.xml", "<workbook xmlns=\"\(main)\" xmlns:r=\"\(rel)\"><sheets>" + indices.map { "<sheet name=\"\(IDMLImporter.escape(sheetName($0)))\" sheetId=\"\($0 + 1)\" r:id=\"rId\($0 + 1)\"/>" }.joined() + "</sheets></workbook>")
        try save("xl/_rels/workbook.xml.rels", "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" + indices.map { "<Relationship Id=\"rId\($0 + 1)\" Type=\"\(rel)/worksheet\" Target=\"worksheets/sheet\($0 + 1).xml\"/>" }.joined() + "</Relationships>")
        for index in indices { try save("xl/worksheets/sheet\(index + 1).xml", sheetXML(parts[index])) }
        let p = Process(); p.executableURL = URL(fileURLWithPath:"/usr/bin/zip"); p.arguments = ["-q","-X","-r",output.path,"[Content_Types].xml","_rels","xl"]; p.currentDirectoryURL = package
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice; try p.run(); p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw ImageExport.error("xlsxWriteFailed") }
    }

    /// delimiter: "," (.csv), "\t" (.tsv) or "xlsx" (rowsPerSheet > 0 splits it into sheets).
    static func convert(input: URL, folder: URL, delimiter: String, rowsPerSheet: Int = 0) throws -> URL {
        guard let data = try? Data(contentsOf:input) else { throw ImageExport.error("srtInvalid") }
        let text = String(data:data, encoding:.utf8) ?? String(data:data, encoding:.shiftJIS) ?? String(decoding:data, as:UTF8.self)
        let cues = parse(text)
        guard !cues.isEmpty else { throw ImageExport.error("srtInvalid") }
        let header = ["#", NSLocalizedString("srtTime", comment:""), NSLocalizedString("srtHandle", comment:""), NSLocalizedString("srtComment", comment:"")]
        let stem = input.deletingPathExtension().lastPathComponent
        let temp = folder.appendingPathComponent(".PandocDesk-" + UUID().uuidString + ".tmp")
        if delimiter == "xlsx" { try writeXLSX(cues, header:header, sheet:stem, rowsPerSheet:rowsPerSheet, to:temp) }
        else { try Data(table(cues, delimiter:delimiter, header:header).utf8).write(to:temp) }
        do { return try ImageExport.publish(temp, folder:folder, name:stem, ext:delimiter == "xlsx" ? "xlsx" : delimiter == "\t" ? "tsv" : "csv") }
        catch { try? FileManager.default.removeItem(at:temp); throw error }
    }
}
