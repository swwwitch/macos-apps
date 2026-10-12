import AppKit
import Carbon
@main struct ShortcutTests {
    static func main() {
        // KM and Carbon modifier bits agree.
        precondition(Shortcut.command == UInt32(cmdKey) && Shortcut.shift == UInt32(shiftKey) && Shortcut.option == UInt32(optionKey) && Shortcut.control == UInt32(controlKey))
        precondition(Shortcut.recorded(keyCode: 8, flags: .command) == nil, "⌘C refused")
        precondition(Shortcut.recorded(keyCode: 12, flags: .command) == nil, "⌘Q refused")
        precondition(Shortcut.recorded(keyCode: 2, flags: .shift) == nil, "⇧ alone refused")
        let recorded = Shortcut.recorded(keyCode: 2, flags: [.control, .option])
        precondition(recorded == Shortcut(code: 2, modifiers: Shortcut.control | Shortcut.option))
        precondition(recorded!.modifierSymbols == "⌃⌥")
        precondition(Shortcut(code: 122, modifiers: Shortcut.command | Shortcut.shift).label == "⇧⌘F1")
        precondition(Shortcut(code: 49, modifiers: Shortcut.control).label == "⌃Space")
        let letter = Shortcut(code: 2, modifiers: Shortcut.control | Shortcut.option).label
        precondition(letter.hasPrefix("⌃⌥") && letter.count == 3, letter)
        print("PASS: KM/Carbon modifier bits, recorder refuses standard keys, labels (\(letter), ⇧⌘F1, ⌃Space)")
    }
}
