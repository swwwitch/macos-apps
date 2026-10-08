import Foundation

/// Text file → the same text in UTF-16 (with or without BOM, little or big endian).
/// Automatic reading: the BOM (UTF-8 / UTF-16 / UTF-32) decides; without one UTF-8, then Shift_JIS (CP932), then EUC-JP.
/// The file extension is kept; the input's own BOM is not carried over.
enum TextEncodingConverter {
    static let inputs: Set<String> = ["txt","text","md","markdown","mdown","mkd","csv","tsv","srt","html","htm","xml","json","tex","rst","org","typ","wiki"]
    /// Input encodings offered in the options; "auto" detects. Swift's .shiftJIS already decodes CP932 (①, ㈱, ～).
    static let sourceEncodings: [(id: String, name: String, encoding: String.Encoding?)] = [("auto", "", nil), ("utf8", "UTF-8", .utf8), ("sjis", "Shift_JIS", .shiftJIS), ("euc", "EUC-JP", .japaneseEUC), ("utf16", "UTF-16", .utf16)]

    struct Options: Equatable {
        var bom = true
        var bigEndian = false
        var source = "auto"
        /// "keep", "crlf" or "lf".
        var lineEnding = "keep"
        var composeKana = true
    }

    /// Returns the text and, when detection fell back from UTF-8, the encoding it was read as.
    static func decode(_ data: Data, source: String = "auto") -> (text: String, guessed: String?)? {
        let boms: [([UInt8], String.Encoding)] = [([0xEF,0xBB,0xBF], .utf8), ([0xFF,0xFE,0x00,0x00], .utf32LittleEndian), ([0x00,0x00,0xFE,0xFF], .utf32BigEndian), ([0xFF,0xFE], .utf16LittleEndian), ([0xFE,0xFF], .utf16BigEndian)]
        for (bom, encoding) in boms where data.starts(with:bom) { return String(data:data.dropFirst(bom.count), encoding:encoding).map { ($0, nil) } }
        if let chosen = sourceEncodings.first(where: { $0.id == source })?.encoding {
            // UTF-16 without a BOM: little endian, as Windows writes it.
            return String(data:data, encoding:chosen == .utf16 ? .utf16LittleEndian : chosen).map { ($0, nil) }
        }
        if let text = String(data:data, encoding:.utf8) { return (text, nil) }
        for (name, encoding) in [("Shift_JIS", String.Encoding.shiftJIS), ("EUC-JP", .japaneseEUC)] {
            if let text = String(data:data, encoding:encoding) { return (text, name) }
        }
        return nil
    }

    /// Kana + combining (semi-)voiced mark (U+3099 / U+309A, as macOS often writes) → one character.
    /// Full NFC is not used: it would also replace CJK compatibility ideographs such as 神 (U+FA19).
    static func composeKana(_ text: String) -> String {
        guard text.unicodeScalars.contains(where: { $0.value == 0x3099 || $0.value == 0x309A }) else { return text }
        let pattern = try! NSRegularExpression(pattern:"[\\u3041-\\u30FF][\\u3099\\u309A]")
        let source = text as NSString
        let result = NSMutableString(string:text)
        for match in pattern.matches(in:text, range:NSRange(location:0, length:source.length)).reversed() {
            result.replaceCharacters(in:match.range, with:source.substring(with:match.range).precomposedStringWithCanonicalMapping)
        }
        return result as String
    }

    static func normalizeLineEndings(_ text: String, to mode: String) -> String {
        guard mode != "keep" else { return text }
        let lf = text.replacingOccurrences(of:"\r\n", with:"\n").replacingOccurrences(of:"\r", with:"\n")
        return mode == "crlf" ? lf.replacingOccurrences(of:"\n", with:"\r\n") : lf
    }

    static func encode(_ text: String, bom: Bool, bigEndian: Bool) -> Data {
        var data = Data(bom ? (bigEndian ? [0xFE,0xFF] : [0xFF,0xFE]) : [])
        data.append(text.data(using:bigEndian ? .utf16BigEndian : .utf16LittleEndian)!)
        return data
    }

    /// The second value names the guessed encoding (nil when UTF-8, a BOM or a chosen encoding decided).
    static func convert(input: URL, folder: URL, options: Options) throws -> (url: URL, guessed: String?) {
        guard let data = try? Data(contentsOf:input), let decoded = decode(data, source:options.source) else { throw ImageExport.error("textDecodeFailed") }
        var text = normalizeLineEndings(decoded.text, to:options.lineEnding)
        if options.composeKana { text = composeKana(text) }
        let temp = folder.appendingPathComponent(".PandocDesk-" + UUID().uuidString + ".tmp")
        try encode(text, bom:options.bom, bigEndian:options.bigEndian).write(to:temp)
        do { return (try ImageExport.publish(temp, folder:folder, name:input.deletingPathExtension().lastPathComponent, ext:input.pathExtension), decoded.guessed) }
        catch { try? FileManager.default.removeItem(at:temp); throw error }
    }
}
