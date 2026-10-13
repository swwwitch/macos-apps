import AppKit
import Carbon

@main
struct ShortcutTests {
    static func main() {
        precondition(Shortcut.increment.code == 9)
        precondition(Shortcut.increment.modifiers == UInt32(optionKey))
        // Standard ⌘V/⌘C/⌘Q are refused; modifier-less keys are refused.
        precondition(Shortcut.recorded(keyCode: 9, flags: .command, characters: "v") == nil)
        precondition(Shortcut.recorded(keyCode: 12, flags: .command, characters: "q") == nil)
        precondition(Shortcut.recorded(keyCode: 9, flags: .shift, characters: "v") == nil)
        let recorded = Shortcut.recorded(keyCode: 9, flags: .option, characters: "v")
        precondition(recorded == Shortcut.increment, "\(String(describing: recorded))")
        let data = try! JSONEncoder().encode(Shortcut.increment)
        precondition(try! JSONDecoder().decode(Shortcut.self, from: data) == Shortcut.increment)
        print("PASS: default ⌥V (KM 9/2048), recorder refuses standard keys, labels, persistence")
    }
}
