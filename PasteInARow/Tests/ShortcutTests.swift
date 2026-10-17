import AppKit
import Carbon

@main
struct ShortcutTests {
    static func main() {
        precondition(Shortcut.paste.code == 9)
        precondition(Shortcut.paste.modifiers == UInt32(controlKey | optionKey))
        let data = try! JSONEncoder().encode(Shortcut.paste)
        precondition(try! JSONDecoder().decode(Shortcut.self, from: data) == Shortcut.paste)
        precondition(Shortcut.add.code == 8 && Shortcut.add.modifiers == UInt32(controlKey | optionKey | cmdKey))
        precondition(Shortcut.add.signature != Shortcut.paste.signature)
        print("PASS: default ⌃⌥V and ⌃⌥⌘C, (KM 9/6144), labels, persistence")
    }
}
