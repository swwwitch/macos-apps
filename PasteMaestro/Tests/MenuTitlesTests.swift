import Foundation

@main
struct MenuTitlesTests {
    static func main() {
        // Case, spaces and a trailing ellipsis are ignored.
        precondition(MenuTitles.normalize("  Paste and  Match Style… ") == "paste and match style")
        precondition(MenuTitles.normalize("Paste as Plain Text...") == "paste as plain text")
        precondition(MenuTitles.normalize("書式なしでペースト") == "書式なしでペースト")
        // One per line, blank lines and duplicates dropped, order kept.
        let parsed = MenuTitles.parse("Paste and Match Style\n\n  書式なしでペースト \npaste and match style…\r\nKeep Text Only")
        precondition(parsed == ["Paste and Match Style", "書式なしでペースト", "Keep Text Only"], "\(parsed)")
        precondition(MenuTitles.parse(MenuTitles.initial.joined(separator: "\n")) == MenuTitles.initial)
        precondition(MenuTitles.initial.contains("粘贴并匹配样式") && MenuTitles.initial.contains("붙여넣고 스타일 일치"))
        precondition(MenuTitles.editMenuNames.contains(MenuTitles.normalize("Edit")))
        let defaults = UserDefaults(suiteName: "pastematchstyle.tests")!
        defaults.removePersistentDomain(forName: "pastematchstyle.tests")
        precondition(MenuTitles.load(defaults) == MenuTitles.initial)
        MenuTitles.save([], defaults)
        precondition(MenuTitles.load(defaults).isEmpty)   // an emptied list stays empty
        defaults.removePersistentDomain(forName: "pastematchstyle.tests")
        print("PASS: menu titles: normalize, parse (blank/duplicate/order), zh/ko defaults, save/load")
    }
}
