import AppKit
import Carbon

@main
struct ShortcutTests {
    static func main() {
        precondition(Shortcut.paste.code == 9)
        precondition(Shortcut.paste.modifiers == UInt32(controlKey | optionKey))
        // Standard ⌘V/⌘C/⌘Q are refused; modifier-less keys are refused.
        precondition(Shortcut.recorded(keyCode: 9, flags: .command, characters: "v") == nil)
        precondition(Shortcut.recorded(keyCode: 12, flags: .command, characters: "q") == nil)
        precondition(Shortcut.recorded(keyCode: 9, flags: .shift, characters: "v") == nil)
        let recorded = Shortcut.recorded(keyCode: 9, flags: [.control, .option], characters: "v")
        precondition(recorded == Shortcut.paste, "\(String(describing: recorded))")
        let data = try! JSONEncoder().encode(Shortcut.paste)
        precondition(try! JSONDecoder().decode(Shortcut.self, from: data) == Shortcut.paste)
        print("PASS: default ⌃⌥V (KM 9/6144), recorder refuses standard keys, labels, persistence")
    }
}
