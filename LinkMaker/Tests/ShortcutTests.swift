import AppKit
import Carbon
@main struct ShortcutTests {
    static func main() {
        // KM modifiers are Carbon's: ⌥ 2048, ⌥⇧⌘ 2816, ⌃⌥⌘ 6400.
        precondition(Shortcut.km(1, 2048, "S").modifiers == UInt32(optionKey) && Shortcut.km(1, 2048, "S").label == "⌥S")
        precondition(Shortcut.km(15, 2816, "R").label == "⌥⇧⌘R" && Shortcut.km(13, 6400, "W").label == "⌃⌥⌘W")
        // Stored Shortcut ↔ the shared field's KeyCombo keeps the key and modifiers (the label is redrawn from the layout).
        let stored = Shortcut.km(40, 4864, "K")
        let combo = KeyCombo(stored)
        precondition(combo.code == 40 && combo.modifiers == 4864 && Shortcut(combo).signature == stored.signature)
        precondition(KeyCombo(Shortcut(combo)) == combo)
        let data = try! JSONEncoder().encode(["copyURL": Shortcut.km(1, 2048, "S")])
        precondition(try! JSONDecoder().decode([String: Shortcut].self, from: data)["copyURL"]?.label == "⌥S")
        print("PASS: KM modifier mapping, labels, KeyCombo round trip, persistence")
    }
}
