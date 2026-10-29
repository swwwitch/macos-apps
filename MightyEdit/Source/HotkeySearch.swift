import Foundation

/// Normalizes modifier names and symbols without treating punctuation as regex.
enum HotkeySearch {
    static func normalized(_ text: String) -> String {
        var value = text.folding(options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        for (name, symbol) in [("control", "⌃"), ("ctrl", "⌃"), ("option", "⌥"), ("alt", "⌥"), ("command", "⌘"), ("cmd", "⌘"), ("shift", "⇧")] {
            value = value.replacingOccurrences(of: name, with: symbol)
        }
        return value.filter { !$0.isWhitespace && $0 != "+" }
    }

    static func matches(_ query: String, title: String, labels: [String]) -> Bool {
        let needle = normalized(query)
        if needle.isEmpty || normalized(title).contains(needle) { return true }
        let modifiers = Set("⌃⌥⌘⇧")
        let wantedModifiers = Set(needle.filter { modifiers.contains($0) })
        let wantedKey = needle.filter { !modifiers.contains($0) }
        return labels.contains { label in
            let value = normalized(label)
            let actualModifiers = Set(value.filter { modifiers.contains($0) })
            let actualKey = value.filter { !modifiers.contains($0) }
            return wantedModifiers.isSubset(of: actualModifiers) && (wantedKey.isEmpty || actualKey.contains(wantedKey))
        }
    }
}
