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
