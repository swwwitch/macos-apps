import Foundation

enum LineTools {
    static func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n").replacingOccurrences(of: "\u{2029}", with: "\n")
    }
    static func mapLines(_ text: String, transform: (String) -> String) -> String {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return text }
        var lines = normalized.components(separatedBy: "\n")
        let trailing = normalized.hasSuffix("\n")
        if trailing { lines.removeLast() }
        return lines.map(transform).joined(separator: "\n") + (trailing ? "\n" : "")
    }
    static func trim(_ text: String) -> String { mapLines(text) { $0.trimmingCharacters(in: .whitespaces) } }
    static func affix(_ text: String, prefix: String, suffix: String) -> String { mapLines(text) { prefix + $0 + suffix } }
    /// Breaks the line at every occurrence of `separator`; spaces and tabs around each break are removed.
    /// `prefix` is then added to every non-empty line.
    static func split(_ text: String, at separator: String, keepSeparator: Bool, prefix: String = "") -> String {
        guard !separator.isEmpty else { return prefix.isEmpty ? text : mapLines(text) { $0.isEmpty ? $0 : prefix + $0 } }
        let blanks: Set<Character> = [" ", "\t", "　"]
        var pieces = normalize(text).components(separatedBy: separator)
        for index in pieces.indices {
            if index > 0 { pieces[index] = String(pieces[index].drop { blanks.contains($0) }) }
            if index < pieces.count - 1 {
                while let last = pieces[index].last, blanks.contains(last) { pieces[index].removeLast() }
            }
        }
        let result = pieces.joined(separator: (keepSeparator ? separator : "") + "\n")
        return prefix.isEmpty ? result : mapLines(result) { $0.isEmpty ? $0 : prefix + $0 }
    }
    static func sortByLength(_ text: String) -> String {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return text }
        var lines = normalized.components(separatedBy: "\n")
        let trailing = normalized.hasSuffix("\n")
        if trailing { lines.removeLast() }
        let ascending = zip(lines, lines.dropFirst()).allSatisfy { $0.count <= $1.count }
        let sorted = lines.enumerated().sorted {
            if $0.element.count == $1.element.count { return $0.offset < $1.offset }
            return ascending ? $0.element.count > $1.element.count : $0.element.count < $1.element.count
        }.map(\.element)
        return sorted.joined(separator: "\n") + (trailing ? "\n" : "")
    }
    static func statistics(_ text: String) -> String {
        let normalized = normalize(text)
        let chars = normalized.filter { $0 != "\n" }.count
        let noSpaces = normalized.filter { !$0.isWhitespace }.count
        let lines = normalized.isEmpty ? 0 : normalized.components(separatedBy: "\n").count - (normalized.hasSuffix("\n") ? 1 : 0)
        return L("stats.body", String(chars), String(noSpaces), String(lines))
    }
}
