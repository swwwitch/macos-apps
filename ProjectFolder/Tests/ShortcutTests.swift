import AppKit
import Carbon
@main struct ShortcutTests {
    static func main() {
        // KM modifiers are Carbon's: ⌥ 2048, ⌥⇧⌘ 2816, ⌃⌥⌘ 6400.
        precondition(Shortcut.km(1, 2048, "S").modifiers == UInt32(optionKey) && Shortcut.km(1, 2048, "S").label == "⌥S")
        precondition(Shortcut.km(15, 2816, "R").label == "⌥⇧⌘R" && Shortcut.km(13, 6400, "W").label == "⌃⌥⌘W")
        let data = try! JSONEncoder().encode(["copyURL": Shortcut.km(1, 2048, "S")])
        precondition(try! JSONDecoder().decode([String: Shortcut].self, from: data)["copyURL"]?.label == "⌥S")
        print("PASS: KM modifier mapping, labels, persistence")
    }
}
