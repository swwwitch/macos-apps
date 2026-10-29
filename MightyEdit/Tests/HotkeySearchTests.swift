import Foundation

@main struct HotkeySearchTests {
    static func main() {
        let rows = [("カンマを付ける", "⌃⌥⌘,"), ("カンマを取る", "⌃⌥⌘."), ("数値を合計", "⌃⌥⌘="), ("改行を削除", "⌃J")]
        func found(_ query: String) -> [Int] {
            rows.indices.filter { HotkeySearch.matches(query, title: rows[$0].0, labels: [rows[$0].1]) }
        }
        precondition(found("") == [0, 1, 2, 3])
        precondition(found("カンマ") == [0, 1])
        precondition(found("合計") == [2])
        precondition(found("⌃⌥⌘,") == [0])
        precondition(found("Command + Control + Option + ,") == [0])
        precondition(found("CTRL+ALT+CMD+.") == [1])
        precondition(found("＝") == [2])
        precondition(found("⇧⌃⌥⌘=").isEmpty)
        precondition(found("存在しない").isEmpty)
        precondition(found("⌥") == [0, 1, 2])
        precondition(found("j") == [3])
        print("Passed function names, punctuation, modifier aliases, order, width and no-match searches")
    }
}
