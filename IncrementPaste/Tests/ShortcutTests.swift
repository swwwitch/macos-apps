import AppKit
import Carbon

@main
struct ShortcutTests {
    static func main() {
        precondition(Shortcut.increment.code == 9)
        precondition(Shortcut.increment.modifiers == UInt32(optionKey))
        let data = try! JSONEncoder().encode(Shortcut.increment)
        precondition(try! JSONDecoder().decode(Shortcut.self, from: data) == Shortcut.increment)
        print("PASS: default ⌥V (KM 9/2048), persistence")
    }
}
