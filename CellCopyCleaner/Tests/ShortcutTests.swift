import AppKit
import Carbon
@main struct ShortcutTests {
    static func main() {
        precondition(Shortcut.clean.code == 8 && Shortcut.clean.modifiers == UInt32(cmdKey | optionKey) && Shortcut.clean.modifiers == 2304)
        // Standard ⌘C/⌘V/⌘Q are refused; modifier-less keys are refused.
        precondition(Shortcut.recorded(keyCode: 8, flags: .command, characters: "c") == nil)
        precondition(Shortcut.recorded(keyCode: 12, flags: .command, characters: "q") == nil)
        precondition(Shortcut.recorded(keyCode: 8, flags: .shift, characters: "c") == nil)
        let recorded = Shortcut.recorded(keyCode: 8, flags: [.command, .option], characters: "c")
        precondition(recorded == Shortcut.clean, "\(String(describing: recorded))")
        precondition(Shortcut.recorded(keyCode: 8, flags: [.command, .option, .control], characters: "c")?.label == "⌃⌥⌘C")
        let data = try! JSONEncoder().encode(Shortcut.clean)
        precondition(try! JSONDecoder().decode(Shortcut.self, from: data) == Shortcut.clean)
        print("PASS: default ⌥⌘C (KM 8/2304), recorder refuses standard keys, labels, persistence")
    }
}
