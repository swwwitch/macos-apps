import Foundation

/// Subtitles (.srt) → CSV / TSV, one row per cue: number, start time (HH:MM:SS), handle, comment.
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

    static func convert(input: URL, folder: URL, delimiter: String) throws -> URL {
        guard let data = try? Data(contentsOf:input) else { throw ImageExport.error("srtInvalid") }
        let text = String(data:data, encoding:.utf8) ?? String(data:data, encoding:.shiftJIS) ?? String(decoding:data, as:UTF8.self)
        let cues = parse(text)
        guard !cues.isEmpty else { throw ImageExport.error("srtInvalid") }
        let header = ["#", NSLocalizedString("srtTime", comment:""), NSLocalizedString("srtHandle", comment:""), NSLocalizedString("srtComment", comment:"")]
        let temp = folder.appendingPathComponent(".PandocDesk-" + UUID().uuidString + ".tmp")
        try Data(table(cues, delimiter:delimiter, header:header).utf8).write(to:temp)
        do { return try ImageExport.publish(temp, folder:folder, name:input.deletingPathExtension().lastPathComponent, ext:delimiter == "\t" ? "tsv" : "csv") }
        catch { try? FileManager.default.removeItem(at:temp); throw error }
    }
}
