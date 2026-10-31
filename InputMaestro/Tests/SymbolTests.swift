import Foundation
@main struct SymbolTests {
    static func main() {
        let items = SymbolDefinitions.all
        precondition(items.count == 8)
        precondition(items.map(\.text) == ["⌃", "⌥", "⌘", "⇧", "←", "↓", "→", "↑"])
        precondition(items.map(\.code) == [38, 40, 37, 34, 38, 40, 37, 34])
        precondition(items.prefix(4).allSatisfy { !$0.isArrow && $0.modifiers == 2048 | 512 })
        precondition(items.suffix(4).allSatisfy { $0.isArrow && $0.modifiers == 4096 | 2048 | 512 })
        precondition(Set(items.map { "\($0.code):\($0.modifiers)" }).count == 8)
        print("PASS: eight InsertSnippets modifier / arrow symbols and original default hotkeys")
    }
}
