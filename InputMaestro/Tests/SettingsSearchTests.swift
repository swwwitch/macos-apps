import Foundation
@main struct SearchTests {
    static func main() {
        let entries = [
            SettingsSearchEntry(id: "copy", title: "段落先頭まで選択してコピー", keywords: "⌃⇧←", tab: 2, anchor: "cmd.copyToLineStart"),
            SettingsSearchEntry(id: "caps", title: "切り替えキー", keywords: "Caps Lock JIS", tab: 1, anchor: "page.1"),
            SettingsSearchEntry(id: "launch", title: "ログイン時に起動", keywords: "login", tab: 0, anchor: "page.0")
        ]
        precondition(SettingsSearchIndex.matches("コピー", in: entries).map(\.id) == ["copy"])
        precondition(SettingsSearchIndex.matches("caps lock", in: entries).map(\.id) == ["caps"])
        precondition(SettingsSearchIndex.matches("  CAPS   JIS ", in: entries).map(\.id) == ["caps"])
        precondition(SettingsSearchIndex.matches("⌃⇧←", in: entries).first?.anchor == "cmd.copyToLineStart")
        precondition(SettingsSearchIndex.matches("コピー Caps", in: entries).isEmpty)
        precondition(SettingsSearchIndex.matches("   ", in: entries).isEmpty)
        precondition(SettingsSearchIndex.matches("見つからない", in: entries).isEmpty)
        print("PASS: settings search Japanese, case-insensitive words, key glyphs, anchors, AND matching and empty query")
    }
}
