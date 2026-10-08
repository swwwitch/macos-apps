import Compression
import CoreGraphics
import Foundation

// Finds the background painted at the start of a PDF page and writes the page without it.
// A background is, before anything else is painted:
//   1. a filled rectangle covering at least 98% of the page box (Illustrator, PowerPoint…), or
//   2. a Form XObject drawn on its own, usually inside q…Q (InDesign parent pages).
// Images, text, strokes and other shapes end the search, so a cover photo is kept.
// The rewritten page is serialized by PDFPageWriter because PDFKit cannot save edited content streams.

struct PDFBackgroundColor: Equatable, Hashable {
    /// Fill components as written: 1 = gray, 3 = RGB, 4 = CMYK. Spot tints count as gray.
    var components: [CGFloat]

    var cgColor: CGColor {
        let c = components
        switch c.count {
        case 3: return CGColor(srgbRed: c[0], green: c[1], blue: c[2], alpha: 1)
        case 4: return CGColor(srgbRed: (1 - c[0]) * (1 - c[3]), green: (1 - c[1]) * (1 - c[3]), blue: (1 - c[2]) * (1 - c[3]), alpha: 1)
        case 1: return CGColor(gray: c[0], alpha: 1)
        default: return CGColor(gray: 0.5, alpha: 1)
        }
    }
}

struct PDFBackground: Equatable {
    /// Stable across pages and launches: same drawing → same key.
    var signature: String
    var colors: [PDFBackgroundColor]
    /// Byte ranges of the page content to drop.
    var ranges: [Range<Int>]
}

enum PDFBackgroundFinder {
    static let coverage: CGFloat = 0.98

    /// nil when the page starts with real content.
    static func find(page: CGPDFPage, box: CGRect) -> PDFBackground? {
        guard let content = PDFPageContent.data(of: page) else { return nil }
        return find(content: content, resources: PDFPageContent.resources(of: page), box: box)
    }

    static func find(content: Data, resources: CGPDFDictionaryRef?, box: CGRect) -> PDFBackground? {
        let ops = PDFContentLexer.operations(Array(content))
        var ctm = CGAffineTransform.identity, stack: [CGAffineTransform] = []
        var fill: [CGFloat] = [0]
        var path: [CGRect] = [], pathStart: Int?, pathIsRects = true, clipping = false
        // Open q blocks and the parent-page forms drawn in them so far.
        var blocks: [(start: Int, forms: [String], colors: [PDFBackgroundColor])] = []
        var ranges: [Range<Int>] = [], parts: [String] = [], colors: [PDFBackgroundColor] = []

        func stop() -> PDFBackground? {
            guard !ranges.isEmpty else { return nil }
            return PDFBackground(signature: parts.joined(separator: "+"), colors: colors, ranges: merged(ranges))
        }

        for op in ops {
            switch op.name {
            case "q":
                stack.append(ctm); blocks.append((op.range.lowerBound, [], []))
            case "Q":
                if let saved = stack.popLast() { ctm = saved }
                if let block = blocks.popLast(), !block.forms.isEmpty {
                    // The block drew only parent-page forms (anything else would have stopped the scan).
                    ranges.removeAll { $0.lowerBound >= block.start }
                    ranges.append(block.start..<op.range.upperBound)
                    parts += block.forms; colors += block.colors
                }
            case "cm":
                if let m = op.numbers, m.count == 6 { ctm = CGAffineTransform(a: m[0], b: m[1], c: m[2], d: m[3], tx: m[4], ty: m[5]).concatenating(ctm) }
            case "g", "rg", "k", "sc", "scn":
                if let n = op.numbers, !n.isEmpty { fill = n }
            case "cs":
                fill = [0]
            case "CS", "SC", "SCN", "G", "RG", "K", "gs", "ri", "w", "J", "j", "M", "d", "i", "BMC", "BDC", "EMC", "MP", "DP", "Tc", "Tw", "Tz", "TL", "Tf", "Tr", "Ts":
                break
            case "re":
                if pathStart == nil { pathStart = op.range.lowerBound }
                if let n = op.numbers, n.count == 4 { path.append(CGRect(x: n[0], y: n[1], width: n[2], height: n[3]).standardized.applying(ctm)) }
            case "m", "l", "c", "v", "y", "h":
                if pathStart == nil { pathStart = op.range.lowerBound }
                pathIsRects = false
            case "W", "W*":
                clipping = true
            case "n":
                path = []; pathStart = nil; pathIsRects = true; clipping = false
            case "f", "F", "f*":
                guard pathIsRects, !clipping, path.count == 1, let start = pathStart, covers(path[0], box) else { return stop() }
                ranges.append(start..<op.range.upperBound)
                parts.append("fill:" + fill.map { String(format: "%.3f", $0) }.joined(separator: ","))
                colors.append(PDFBackgroundColor(components: fill))
                path = []; pathStart = nil
            case "Do":
                guard let name = op.name0, let form = formStream(named: name, in: resources) else { return stop() }
                let data = PDFPageContent.decoded(form) ?? Data()
                let key = "form:" + fnv1a(data)
                if blocks.isEmpty {
                    ranges.append(op.range); parts.append(key); colors += fillColors(in: data)
                } else {
                    blocks[blocks.count - 1].forms.append(key); blocks[blocks.count - 1].colors += fillColors(in: data)
                }
            default:
                // Text, images, shading, strokes, inline images: real content begins.
                return stop()
            }
        }
        return stop()
    }

    static func covers(_ rect: CGRect, _ box: CGRect) -> Bool {
        let overlap = rect.intersection(box)
        guard !overlap.isNull, box.width > 0, box.height > 0 else { return false }
        return overlap.width * overlap.height >= box.width * box.height * coverage
    }

    static func formStream(named name: String, in resources: CGPDFDictionaryRef?) -> CGPDFStreamRef? {
        guard let resources else { return nil }
        var xobjects: CGPDFDictionaryRef?, stream: CGPDFStreamRef?, subtype: UnsafePointer<CChar>?
        guard CGPDFDictionaryGetDictionary(resources, "XObject", &xobjects), let xobjects,
              CGPDFDictionaryGetStream(xobjects, name, &stream), let stream,
              let dict = CGPDFStreamGetDictionary(stream),
              CGPDFDictionaryGetName(dict, "Subtype", &subtype), let subtype, String(cString: subtype) == "Form" else { return nil }
        return stream
    }

    /// Colors of the fills inside a form, for the swatch shown to the user.
    static func fillColors(in data: Data) -> [PDFBackgroundColor] {
        var fill: [CGFloat] = [0], result: [PDFBackgroundColor] = []
        for op in PDFContentLexer.operations(Array(data)) {
            switch op.name {
            case "g", "rg", "k", "sc", "scn": if let n = op.numbers, !n.isEmpty { fill = n }
            case "f", "F", "f*", "B", "B*", "b", "b*":
                let color = PDFBackgroundColor(components: fill)
                if !result.contains(color) { result.append(color) }
            default: break
            }
        }
        return result
    }

    static func merged(_ ranges: [Range<Int>]) -> [Range<Int>] {
        var result: [Range<Int>] = []
        for range in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = result.last, range.lowerBound <= last.upperBound { result[result.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound) }
            else { result.append(range) }
        }
        return result
    }

    static func fnv1a(_ data: Data) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in data { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        return String(hash, radix: 16)
    }

    /// The page content with the background ranges cut out.
    static func removing(_ background: PDFBackground, from content: Data) -> Data {
        var result = Data(), cursor = 0
        let bytes = Array(content)
        for range in background.ranges {
            result.append(contentsOf: bytes[cursor..<range.lowerBound]); result.append(0x0a)
            cursor = range.upperBound
        }
        result.append(contentsOf: bytes[cursor...])
        return result
    }
}

enum PDFPageContent {
    /// The decoded content stream(s), joined with newlines.
    static func data(of page: CGPDFPage) -> Data? {
        guard let dict = page.dictionary else { return nil }
        var stream: CGPDFStreamRef?, array: CGPDFArrayRef?
        if CGPDFDictionaryGetStream(dict, "Contents", &stream), let stream {
            return decoded(stream)
        }
        guard CGPDFDictionaryGetArray(dict, "Contents", &array), let array else { return nil }
        var result = Data()
        for i in 0..<CGPDFArrayGetCount(array) {
            var part: CGPDFStreamRef?
            guard CGPDFArrayGetStream(array, i, &part), let part, let data = decoded(part) else { return nil }
            result.append(data); result.append(0x0a)
        }
        return result
    }

    static func decoded(_ stream: CGPDFStreamRef) -> Data? {
        var format = CGPDFDataFormat.raw
        return CGPDFStreamCopyData(stream, &format) as Data?
    }

    /// Page resources, following inheritance from the page tree.
    static func resources(of page: CGPDFPage) -> CGPDFDictionaryRef? {
        var node = page.dictionary
        while let current = node {
            var resources: CGPDFDictionaryRef?, parent: CGPDFDictionaryRef?
            if CGPDFDictionaryGetDictionary(current, "Resources", &resources) { return resources }
            node = CGPDFDictionaryGetDictionary(current, "Parent", &parent) ? parent : nil
        }
        return nil
    }
}

/// Splits a content stream into operators with their operands and byte ranges.
enum PDFContentLexer {
    struct Operation {
        var name: String
        var operands: [Token]
        var range: Range<Int>
        var numbers: [CGFloat]? {
            let values = operands.compactMap { if case .number(let n) = $0.kind { return n } else { return nil } }
            return values.isEmpty ? nil : values
        }
        /// First name operand (Do, gs, cs…).
        var name0: String? { operands.lazy.compactMap { if case .name(let n) = $0.kind { return n } else { return nil } }.first }
    }
    struct Token {
        enum Kind { case number(CGFloat), name(String), other, keyword(String) }
        var kind: Kind
        var start: Int
    }

    static func isWhite(_ b: UInt8) -> Bool { b == 0x20 || b == 0x0a || b == 0x0d || b == 0x09 || b == 0x0c || b == 0x00 }
    static func isDelimiter(_ b: UInt8) -> Bool { "()<>[]{}/%".utf8.contains(b) }

    static func operations(_ s: [UInt8]) -> [Operation] {
        var ops: [Operation] = [], operands: [Token] = [], i = 0, depth = 0
        let n = s.count
        while i < n {
            let b = s[i]
            if isWhite(b) { i += 1; continue }
            let start = i
            switch b {
            case UInt8(ascii: "%"):
                while i < n, s[i] != 0x0a, s[i] != 0x0d { i += 1 }
                continue
            case UInt8(ascii: "("):
                var nest = 0
                while i < n {
                    if s[i] == UInt8(ascii: "\\") { i += 2; continue }
                    if s[i] == UInt8(ascii: "(") { nest += 1 } else if s[i] == UInt8(ascii: ")") { nest -= 1; if nest == 0 { i += 1; break } }
                    i += 1
                }
                operands.append(Token(kind: .other, start: start))
            case UInt8(ascii: "<"):
                if i + 1 < n, s[i + 1] == UInt8(ascii: "<") { i += 2; depth += 1; operands.append(Token(kind: .other, start: start)); continue }
                while i < n, s[i] != UInt8(ascii: ">") { i += 1 }
                i += 1
                operands.append(Token(kind: .other, start: start))
            case UInt8(ascii: ">"):
                i += (i + 1 < n && s[i + 1] == UInt8(ascii: ">")) ? 2 : 1
                depth = max(0, depth - 1)
            case UInt8(ascii: "["), UInt8(ascii: "]"), UInt8(ascii: "{"), UInt8(ascii: "}"):
                i += 1
                if b == UInt8(ascii: "[") || b == UInt8(ascii: "{") { depth += 1; operands.append(Token(kind: .other, start: start)) } else { depth = max(0, depth - 1) }
            case UInt8(ascii: "/"):
                i += 1
                while i < n, !isWhite(s[i]), !isDelimiter(s[i]) { i += 1 }
                let raw = String(decoding: s[(start + 1)..<i], as: UTF8.self)
                operands.append(Token(kind: depth == 0 ? .name(decodeName(raw)) : .other, start: start))
            default:
                i += 1
                while i < n, !isWhite(s[i]), !isDelimiter(s[i]) { i += 1 }
                let word = String(decoding: s[start..<i], as: UTF8.self)
                if let value = Double(word), word.first.map({ $0.isNumber || $0 == "-" || $0 == "+" || $0 == "." }) == true {
                    operands.append(Token(kind: depth == 0 ? .number(CGFloat(value)) : .other, start: start))
                } else if depth > 0 || word == "true" || word == "false" || word == "null" {
                    operands.append(Token(kind: .other, start: start))
                } else {
                    let opStart = operands.first?.start ?? start
                    if word == "BI" {
                        // Inline image: skip to whitespace + EI + whitespace/end.
                        var j = i
                        while j + 2 < n, !(isWhite(s[j]) && s[j + 1] == UInt8(ascii: "E") && s[j + 2] == UInt8(ascii: "I") && (j + 3 == n || isWhite(s[j + 3]))) { j += 1 }
                        i = min(n, j + 3)
                    }
                    ops.append(Operation(name: word, operands: operands, range: opStart..<i))
                    operands = []
                }
            }
        }
        return ops
    }

    /// Resolves #xx escapes in a name.
    static func decodeName(_ raw: String) -> String {
        guard raw.contains("#") else { return raw }
        let u = Array(raw.utf8)
        var bytes: [UInt8] = [], i = 0
        while i < u.count {
            if u[i] == UInt8(ascii: "#"), i + 2 < u.count, let v = UInt8(String(decoding: u[(i + 1)...(i + 2)], as: UTF8.self), radix: 16) { bytes.append(v); i += 3 }
            else { bytes.append(u[i]); i += 1 }
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}

/// Writes one page as a standalone PDF from CoreGraphics' parsed objects.
/// Streams are decoded by CoreGraphics and stored again with Flate (JPEG and JPEG 2000 stay as they are).
final class PDFPageWriter {
    private var objects: [Data?] = []
    private var memo: [Int: Int] = [:]  // CoreGraphics object address → object number

    static func write(page: CGPDFPage, content: Data, box: CGRect, to url: URL) throws {
        let writer = PDFPageWriter()
        guard let pageDict = page.dictionary else { throw KeynoteError.unreadable }
        let catalog = writer.reserve(), pages = writer.reserve(), pageObj = writer.reserve()
        let contents = writer.add(stream: [:], data: content, encoded: false)
        var entries = "/Type /Page /Parent \(pages) 0 R"
        entries += " /MediaBox " + writer.rect(box) + " /CropBox " + writer.rect(box)
        entries += " /Contents \(contents) 0 R"
        if let resources = PDFPageContent.resources(of: page) { entries += " /Resources " + writer.value(dictionary: resources) }
        var group: CGPDFDictionaryRef?
        if CGPDFDictionaryGetDictionary(pageDict, "Group", &group), let group { entries += " /Group " + writer.value(dictionary: group) }
        let rotation = ((page.rotationAngle % 360) + 360) % 360
        if rotation != 0 { entries += " /Rotate \(rotation)" }
        writer.set(pageObj, "<< \(entries) >>")
        writer.set(pages, "<< /Type /Pages /Kids [\(pageObj) 0 R] /Count 1 >>")
        writer.set(catalog, "<< /Type /Catalog /Pages \(pages) 0 R >>")
        guard (try? writer.serialized(root: catalog).write(to: url)) != nil else { throw KeynoteError.writePage }
    }

    private func reserve() -> Int { objects.append(nil); return objects.count }
    private func set(_ number: Int, _ body: String) { objects[number - 1] = Data(body.utf8) }

    private func rect(_ r: CGRect) -> String { "[" + [r.minX, r.minY, r.maxX, r.maxY].map(number).joined(separator: " ") + "]" }

    private func number(_ value: CGFloat) -> String {
        if value == value.rounded(), abs(value) < 1e15 { return String(Int64(value)) }
        var text = String(format: "%.6f", Double(value))
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    private func add(stream entries: [String: String], data: Data, encoded: Bool) -> Int {
        let number = reserve()
        fill(number, stream: entries, data: data, encoded: encoded)
        return number
    }

    private func fill(_ number: Int, stream entries: [String: String], data: Data, encoded: Bool) {
        var dict = entries
        var payload = data
        if !encoded, let deflated = Self.zlib(data) { payload = deflated; dict["Filter"] = "/FlateDecode" }
        dict["Length"] = String(payload.count)
        var body = Data(("<< " + dict.map { "/\($0.key) \($0.value)" }.sorted().joined(separator: " ") + " >>\nstream\n").utf8)
        body.append(payload)
        body.append(Data("\nendstream".utf8))
        objects[number - 1] = body
    }

    private func value(_ object: CGPDFObjectRef) -> String {
        switch CGPDFObjectGetType(object) {
        case .null: return "null"
        case .boolean:
            var v: CGPDFBoolean = 0; CGPDFObjectGetValue(object, .boolean, &v); return v != 0 ? "true" : "false"
        case .integer:
            var v: CGPDFInteger = 0; CGPDFObjectGetValue(object, .integer, &v); return String(v)
        case .real:
            var v: CGPDFReal = 0; CGPDFObjectGetValue(object, .real, &v); return number(v)
        case .name:
            var v: UnsafePointer<CChar>?; CGPDFObjectGetValue(object, .name, &v); return v.map { name(String(cString: $0)) } ?? "null"
        case .string:
            var v: CGPDFStringRef?; CGPDFObjectGetValue(object, .string, &v)
            guard let v, let bytes = CGPDFStringGetBytePtr(v) else { return "<>" }
            return "<" + UnsafeBufferPointer(start: bytes, count: CGPDFStringGetLength(v)).map { String(format: "%02X", $0) }.joined() + ">"
        case .array:
            var v: CGPDFArrayRef?; CGPDFObjectGetValue(object, .array, &v)
            guard let v else { return "[]" }
            var items: [String] = []
            for i in 0..<CGPDFArrayGetCount(v) { var item: CGPDFObjectRef?; if CGPDFArrayGetObject(v, i, &item), let item { items.append(value(item)) } }
            return "[" + items.joined(separator: " ") + "]"
        case .dictionary:
            var v: CGPDFDictionaryRef?; CGPDFObjectGetValue(object, .dictionary, &v)
            return v.map { value(dictionary: $0) } ?? "null"
        case .stream:
            var v: CGPDFStreamRef?; CGPDFObjectGetValue(object, .stream, &v)
            return v.map { "\(reference(stream: $0)) 0 R" } ?? "null"
        @unknown default: return "null"
        }
    }

    /// Dictionaries become indirect objects so shared and cyclic ones are written once.
    private func value(dictionary: CGPDFDictionaryRef) -> String {
        let key = unsafeBitCast(dictionary, to: Int.self)
        if let existing = memo[key] { return "\(existing) 0 R" }
        let number = reserve(); memo[key] = number
        set(number, "<< " + entries(of: dictionary, skipping: ["Parent"]).map { "/\(nameBody($0.0)) \($0.1)" }.joined(separator: " ") + " >>")
        return "\(number) 0 R"
    }

    private func reference(stream: CGPDFStreamRef) -> Int {
        let key = unsafeBitCast(stream, to: Int.self)
        if let existing = memo[key] { return existing }
        let number = reserve(); memo[key] = number
        var format = CGPDFDataFormat.raw
        let data = (CGPDFStreamCopyData(stream, &format) as Data?) ?? Data()
        var dict: [String: String] = [:]
        if let streamDict = CGPDFStreamGetDictionary(stream) {
            for (k, v) in entries(of: streamDict, skipping: ["Length", "Filter", "DecodeParms", "DL"]) { dict[nameBody(k)] = v }
        }
        switch format {
        case .jpegEncoded: dict["Filter"] = "/DCTDecode"
        case .JPEG2000: dict["Filter"] = "/JPXDecode"
        default: break
        }
        fill(number, stream: dict, data: data, encoded: format != .raw)
        return number
    }

    private func entries(of dictionary: CGPDFDictionaryRef, skipping: Set<String>) -> [(String, String)] {
        var result: [(String, String)] = []
        CGPDFDictionaryApplyBlock(dictionary, { key, object, _ in
            let name = String(cString: key)
            if !skipping.contains(name) { result.append((name, self.value(object))) }
            return true
        }, nil)
        return result.sorted { $0.0 < $1.0 }
    }

    private func name(_ raw: String) -> String { "/" + nameBody(raw) }

    private func nameBody(_ raw: String) -> String {
        var text = ""
        for byte in raw.utf8 {
            if byte < 0x21 || byte > 0x7e || PDFContentLexer.isDelimiter(byte) || byte == UInt8(ascii: "#") { text += String(format: "#%02X", byte) }
            else { text += String(UnicodeScalar(byte)) }
        }
        return text
    }

    private func serialized(root: Int) -> Data {
        var out = Data("%PDF-1.7\n%\u{e2}\u{e3}\u{cf}\u{d3}\n".utf8)
        var offsets: [Int] = []
        for (index, body) in objects.enumerated() {
            offsets.append(out.count)
            out.append(Data("\(index + 1) 0 obj\n".utf8))
            out.append(body ?? Data("null".utf8))
            out.append(Data("\nendobj\n".utf8))
        }
        let xref = out.count
        var table = "xref\n0 \(objects.count + 1)\n0000000000 65535 f \n"
        for offset in offsets { table += String(format: "%010d 00000 n \n", offset) }
        table += "trailer\n<< /Size \(objects.count + 1) /Root \(root) 0 R >>\nstartxref\n\(xref)\n%%EOF\n"
        out.append(Data(table.utf8))
        return out
    }

    /// zlib stream (RFC 1950): header + raw deflate + Adler-32.
    static func zlib(_ data: Data) -> Data? {
        guard !data.isEmpty else { return nil }
        let capacity = data.count + data.count / 8 + 1024
        var deflated = Data(count: capacity)
        let size = deflated.withUnsafeMutableBytes { out in
            data.withUnsafeBytes { input in
                compression_encode_buffer(out.bindMemory(to: UInt8.self).baseAddress!, capacity, input.bindMemory(to: UInt8.self).baseAddress!, data.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard size > 0, size < data.count else { return nil }
        var a: UInt32 = 1, b: UInt32 = 0
        for chunk in stride(from: 0, to: data.count, by: 5552) {
            for byte in data[data.startIndex + chunk..<data.startIndex + min(chunk + 5552, data.count)] { a += UInt32(byte); b += a }
            a %= 65521; b %= 65521
        }
        var result = Data([0x78, 0x9c])
        result.append(deflated.prefix(size))
        result.append(contentsOf: [UInt8(b >> 8), UInt8(b & 0xff), UInt8(a >> 8), UInt8(a & 0xff)])
        return result
    }
}
