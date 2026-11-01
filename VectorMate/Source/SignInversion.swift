import Foundation

/// Text-only conversion; no rounding, clipboard access or loss of unit/spacing.
enum SignInversion {
    static func flip(_ text: String) -> String? {
        let pattern = #"^(\s*)([-+]?)([0-9]+(?:\.[0-9]+)?|\.[0-9]+)([ \t]*(?:[\p{L}%°]+)?[ \t]*)$"#
        guard !text.contains("\n"), !text.contains("\r"),
              let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)),
              match.range.length == (text as NSString).length else { return nil }
        let source = text as NSString
        let number = source.substring(with: match.range(at: 3))
        // Preserve all representations of zero, including negative zero and unit-bearing zero.
        guard number.contains(where: { "123456789".contains($0) }) else { return text }
        let sign = source.substring(with: match.range(at: 2)) == "-" ? "" : "-"
        return source.substring(with: match.range(at: 1)) + sign + number + source.substring(with: match.range(at: 4))
    }

    static func replacement(value: String, selection: NSRange) -> (value: String, selection: NSRange)? {
        let source = value as NSString
        guard selection.location != NSNotFound, selection.location <= source.length,
              selection.length <= source.length - selection.location else { return nil }
        let range = selection.length == 0 ? NSRange(location: 0, length: source.length) : selection
        guard let converted = flip(source.substring(with: range)) else { return nil }
        return (source.replacingCharacters(in: range, with: converted), NSRange(location: range.location, length: (converted as NSString).length))
    }
}
