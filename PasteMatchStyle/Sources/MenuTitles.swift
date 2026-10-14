import Foundation

/// Menu item titles that mean "paste as plain text". Foundation-only for the tests.
enum MenuTitles {
    static let key = "menuTitles"

    /// The KM macro 「Universal Paste Without Style」 (in its order), the titles of 「Paste and Match Style」,
    /// Word's English title, Excel's titles, and the macOS zh/ko titles (AppKit MenuCommands.loctable).
    static let initial = [
        "Paste and Match Style",
        "ペーストしてスタイルを合わせる",
        "貼り付けてスタイルを合わせる",
        "Paste without Formatting",
        "書式なしで貼り付け",
        "書式なしでペースト",
        "Paste as Plain Text",
        "プレーンテキストとして貼り付け",
        "Keep Text Only",
        "テキストのみ保持",
        "Match Destination Formatting",
        "貼り付け先の書式に合わせる",
        "スタイルなしペースト",
        "Paste and Match Formatting",
        "Paste and Match Destination Formatting",
        "貼り付けて書式設定に合わせる",
        "粘贴并匹配样式",
        "붙여넣고 스타일 일치"
    ]

    /// Searched first (with one level of submenus); the other menus are searched one level only.
    static let editMenuNames: Set<String> = ["edit", "編集", "编辑", "編輯", "편집"]

    /// Case, surrounding and repeated spaces, and a trailing "…" or "..." are ignored.
    static func normalize(_ title: String) -> String {
        var text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        for suffix in ["…", "..."] where text.hasSuffix(suffix) { text = String(text.dropLast(suffix.count)) }
        return text.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
    }

    /// One title per line; blank lines and duplicates (after normalizing) are dropped, the order is kept.
    static func parse(_ text: String) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for line in text.components(separatedBy: .newlines) {
            let title = line.trimmingCharacters(in: .whitespaces)
            let key = normalize(title)
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            result.append(title)
        }
        return result
    }

    static func load(_ defaults: UserDefaults = .standard) -> [String] { defaults.stringArray(forKey: key) ?? initial }
    static func save(_ titles: [String], _ defaults: UserDefaults = .standard) { defaults.set(titles, forKey: key) }
}
