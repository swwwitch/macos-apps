import AppKit
import Carbon

/// The stored Shortcut JSON (code, modifiers, label) and the shared KeyCombo convert both ways without loss.
@main
struct ComboTests {
    static func main() {
        let stored = #"{"code":9,"modifiers":2048,"label":"⌥V"}"#.data(using: .utf8)!
        let shortcut = try! JSONDecoder().decode(Shortcut.self, from: stored)
        let combo = shortcut.combo
        precondition(combo == KeyCombo(code: 9, modifiers: 2048))
        // KeyCombo itself also reads the stored JSON (the label is ignored).
        precondition(try! JSONDecoder().decode(KeyCombo.self, from: stored) == combo)
        let back = Shortcut(combo)
        precondition(back.code == shortcut.code && back.modifiers == shortcut.modifiers)
        let again = try! JSONDecoder().decode(Shortcut.self, from: try! JSONEncoder().encode(back))
        precondition(again.combo == combo)
        print("PASS: stored ⌥V → KeyCombo → stored keeps code and modifiers")
    }
}
