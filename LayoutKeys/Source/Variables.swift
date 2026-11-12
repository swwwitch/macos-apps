import Foundation

/// From VectorKeys (1.20.0). A deliberately narrow source transform: standalone var declarations with literal defaults.
/// Comments, strings and regular-expression literals are opaque; ambiguous declarations stop execution.
enum VariableOverrides {
    struct Failure: LocalizedError {
        let key: String
        let name: String
        var errorDescription: String? { String(format: L(key), name) }
    }
    struct Token { let text: String; let range: NSRange; let literalString: Bool }
    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
    private static func tokens(_ source: String) throws -> [Token] {
        let ns = source as NSString, units = Array(source.utf16)
        var result: [Token] = [], i = 0
        func word(_ c: UInt16) -> Bool { c == 36 || c == 95 || (65...90).contains(c) || (97...122).contains(c) || (48...57).contains(c) || c > 127 }
        func add(_ start: Int, _ end: Int, string: Bool = false) {
            let range = NSRange(location: start, length: end - start)
            result.append(Token(text: ns.substring(with: range), range: range, literalString: string))
        }
        while i < units.count {
            let c = units[i]
            if c == 32 || c == 9 || c == 10 || c == 13 || c == 0xfeff { i += 1; continue }
            let start = i
            if c == 47 && i + 1 < units.count && units[i + 1] == 47 {
                i += 2; while i < units.count && units[i] != 10 && units[i] != 13 { i += 1 }; continue
            }
            if c == 47 && i + 1 < units.count && units[i + 1] == 42 {
                i += 2
                while i + 1 < units.count && !(units[i] == 42 && units[i + 1] == 47) { i += 1 }
                guard i + 1 < units.count else { throw Failure(key: "override.syntax", name: "") }
                i += 2; continue
            }
            if c == 34 || c == 39 || c == 96 {
                i += 1; var closed = false
                while i < units.count {
                    if units[i] == 92 { i += 2; continue }
                    if units[i] == c { i += 1; closed = true; break }
                    i += 1
                }
                guard closed else { throw Failure(key: "override.syntax", name: "") }
                add(start, i, string: c != 96); continue
            }
            // A slash where an operand can start denotes a regular-expression literal.
            let regexAfter: Set<String> = ["=", "(", "[", ",", ":", ";", "!", "?", "return", "case", "&&", "||", "{", "}"]
            if c == 47 && (result.isEmpty || regexAfter.contains(result.last!.text)) {
                i += 1; var inClass = false, closed = false
                while i < units.count && units[i] != 10 && units[i] != 13 {
                    if units[i] == 92 { i += 2; continue }
                    if units[i] == 91 { inClass = true }
                    if units[i] == 93 { inClass = false }
                    if units[i] == 47 && !inClass { i += 1; closed = true; break }
                    i += 1
                }
                guard closed else { throw Failure(key: "override.syntax", name: "") }
                while i < units.count && word(units[i]) { i += 1 }
                add(start, i); continue
            }
            if (48...57).contains(c) || (c == 46 && i + 1 < units.count && (48...57).contains(units[i + 1])) {
                i += 1
                while i < units.count {
                    let next = units[i]
                    if word(next) || next == 46 { i += 1 }
                    else if (next == 43 || next == 45) && (units[i - 1] == 101 || units[i - 1] == 69) { i += 1 }
                    else { break }
                }
            } else if word(c) {
                i += 1; while i < units.count && word(units[i]) { i += 1 }
            } else { i += 1 }
            add(start, i)
        }
        return result
    }
    /// A `var SW_… = literal;` the window offers to change. `note` is the comment after the `;` on the same line.
    struct Candidate: Hashable, Identifiable {
        let name: String
        let value: String
        let literal: String
        var note = ""
        var id: String { name }
        var isBoolean: Bool { literal == "true" || literal == "false" }
        /// The values to pick from: true/false, or a 「[left|right|up]」 list in the comment.
        var choices: [String] {
            if isBoolean { return ["true", "false"] }
            guard let range = note.range(of: #"\[[^\[\]|]+(\|[^\[\]|]+)+\]"#, options: .regularExpression) else { return [] }
            return note[range].dropFirst().dropLast().split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        /// The comment without the choice list.
        var explanation: String {
            guard let range = note.range(of: #"\s*\[[^\[\]|]+(\|[^\[\]|]+)+\]"#, options: .regularExpression) else { return note }
            return note.replacingCharacters(in: range, with: "").trimmingCharacters(in: .whitespaces)
        }
    }
    /// 「;  /* 空ならパレット */」 → 「空ならパレット」.
    static func trailingNote(in source: String, after location: Int) -> String {
        let ns = source as NSString
        let lineEnd = ns.lineRange(for: NSRange(location: location, length: 0))
        var text = ns.substring(with: NSRange(location: location, length: NSMaxRange(lineEnd) - location)).trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("//") { text = String(text.dropFirst(2)) }
        else if text.hasPrefix("/*"), let close = text.range(of: "*/") { text = String(text[text.index(text.startIndex, offsetBy: 2)..<close.lowerBound]) }
        else { return "" }
        return text.trimmingCharacters(in: .whitespaces)
    }
    /// Decode literal strings only; never evaluate source to discover settings.
    private static func stringValue(_ literal: String) -> String? {
        let chars = Array(literal.utf16)
        guard chars.count >= 2 else { return nil }
        var output: [UInt16] = [], i = 1
        let escapes: [UInt16: UInt16] = [110: 10, 114: 13, 116: 9, 98: 8, 102: 12, 118: 11]
        while i < chars.count - 1 {
            let c = chars[i]; i += 1
            if c != 92 { output.append(c); continue }
            guard i < chars.count - 1 else { return nil }
            let next = chars[i]; i += 1
            if let escaped = escapes[next] { output.append(escaped) }
            else if next == 120 || next == 117 {
                let count = next == 120 ? 2 : 4
                guard i + count <= chars.count - 1 else { return nil }
                let hex = String(decoding: chars[i..<i + count], as: UTF16.self)
                guard let value = UInt16(hex, radix: 16) else { return nil }
                output.append(value); i += count
            } else if next == 10 { continue }
            else if next == 13 { if i < chars.count - 1 && chars[i] == 10 { i += 1 } }
            else if next == 48 {
                guard i >= chars.count - 1 || !(48...57).contains(chars[i]) else { return nil }
                output.append(0)
            } else if (49...57).contains(next) { return nil }
            else { output.append(next) }
        }
        return String(decoding: output, as: UTF16.self)
    }
    static func candidates(in source: String, file: Bool = false) -> [Candidate] {
        guard let ts = try? tokens(source) else { return [] }
        var found: [Candidate] = []
        for i in ts.indices where ts[i].text == "var" {
            guard i + 4 < ts.count else { continue }
            let name = ts[i + 1].text
            guard name.hasPrefix("SW_"), name.count > 3, ts[i + 2].text == "=" else { continue }
            let start = i + 3
            let end = ["+", "-"].contains(ts[start].text) ? start + 1 : start
            guard end + 1 < ts.count, ts[end + 1].text == ";" else { continue }
            let range = NSRange(location: ts[start].range.location, length: NSMaxRange(ts[end].range) - ts[start].range.location)
            let literal = (source as NSString).substring(with: range)
            let value: String
            if ts[start].literalString {
                guard let decoded = stringValue(literal) else { continue }
                value = decoded
            } else { value = literal }
            // Discovery uses exactly the same supported-declaration checks as execution.
            guard (try? apply(to: source, names: [name], values: [value], file: file)) != nil else { continue }
            found.append(Candidate(name: name, value: value, literal: literal, note: trailingNote(in: source, after: NSMaxRange(ts[end + 1].range))))
        }
        return found
    }
    /// The SW_ variables of a script file (empty for .jsxbin, a missing file or text that is not UTF-8).
    static func candidates(forFile path: String) -> [Candidate] {
        guard URL(fileURLWithPath: path).pathExtension.lowercased() != "jsxbin",
              let source = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        return candidates(in: source, file: true)
    }
    static func apply(to source: String, names: [String], values: [String], file: Bool = false) throws -> String {
        let requests = names.enumerated().map { ($0.element.trimmingCharacters(in: .whitespacesAndNewlines), values.indices.contains($0.offset) ? values[$0.offset] : "") }.filter { !$0.0.isEmpty }
        guard !requests.isEmpty else { return source }
        var seen: Set<String> = []
        for (name, _) in requests {
            guard matches(name, #"^[A-Za-z_$][A-Za-z0-9_$]*$"#) else { throw Failure(key: "override.identifier", name: name) }
            guard seen.insert(name).inserted else { throw Failure(key: "override.duplicate", name: name) }
        }
        let ts = try tokens(source)
        if file {
            for i in ts.indices {
                if ts[i].text == "#", i + 1 < ts.count, ts[i + 1].text == "include" { throw Failure(key: "override.fileContext", name: "#include") }
                if ts[i].text == "$", i + 2 < ts.count, ts[i + 1].text == ".", ["fileName", "evalFile"].contains(ts[i + 2].text) { throw Failure(key: "override.fileContext", name: "$.") }
            }
        }
        let numeric = #"^[+-]?(?:(?:0|[1-9]\d*)(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$"#
        var replacements: [(NSRange, String)] = []
        for (name, input) in requests {
            // Count every declaration, including unsupported multi-declarations, to avoid choosing a scope by accident.
            let candidates = ts.indices.filter { i in
                guard ts[i].text == name, i > 0 else { return false }
                return ["var", "let", "const"].contains(ts[i - 1].text) || ts[i - 1].text == ","
            }
            guard candidates.count == 1, let n = candidates.first else { throw Failure(key: candidates.isEmpty ? "override.missing" : "override.ambiguous", name: name) }
            guard ts[n - 1].text == "var", n + 3 < ts.count, ts[n + 1].text == "=" else { throw Failure(key: "override.unsupported", name: name) }
            let prefix = (source as NSString).substring(to: ts[n - 1].range.location)
            let linePrefix = prefix.components(separatedBy: .newlines).last ?? ""
            guard linePrefix.trimmingCharacters(in: .whitespaces).isEmpty else { throw Failure(key: "override.unsupported", name: name) }
            let start = n + 2
            var end = start
            if ["+", "-"].contains(ts[start].text) { end += 1 }
            guard end + 1 < ts.count, ts[end + 1].text == ";" else { throw Failure(key: "override.unsupported", name: name) }
            let range = NSRange(location: ts[start].range.location, length: NSMaxRange(ts[end].range) - ts[start].range.location)
            let original = (source as NSString).substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
            let replacement: String
            if ts[start].literalString && start == end {
                let data = try JSONSerialization.data(withJSONObject: input, options: [.fragmentsAllowed])
                replacement = String(data: data, encoding: .utf8)!.replacingOccurrences(of: "\u{2028}", with: "\\u2028").replacingOccurrences(of: "\u{2029}", with: "\\u2029")
            } else if original == "true" || original == "false" {
                let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
                guard value == "true" || value == "false" else { throw Failure(key: "override.boolean", name: name) }
                replacement = value
            } else {
                let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
                guard matches(original, numeric), matches(value, numeric), let number = Double(value), number.isFinite else { throw Failure(key: "override.number", name: name) }
                replacement = value
            }
            replacements.append((range, replacement))
        }
        let result = NSMutableString(string: source)
        for (range, replacement) in replacements.sorted(by: { $0.0.location > $1.0.location }) { result.replaceCharacters(in: range, with: replacement) }
        return result as String
    }
}
