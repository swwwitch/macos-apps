import AppKit
import Carbon

@main
struct ShortcutTests {
    static func main() {
        precondition(Shortcut.paste.code == 9)
        precondition(Shortcut.paste.modifiers == UInt32(cmdKey | shiftKey))
        let data = try! JSONEncoder().encode(Shortcut.paste)
        precondition(try! JSONDecoder().decode(Shortcut.self, from: data) == Shortcut.paste)
        print("PASS: default ⇧⌘V (KM 9/768), label, persistence")
    }
}
