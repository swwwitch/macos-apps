import AppKit
import Carbon

// Saved MightyEdit hotkeys ↔ the shared recorder's KeyCombo.
@main struct HotkeyBindingTests {
    static func main() {
        let ctrl = UInt32(controlKey), opt = UInt32(optionKey), cmd = UInt32(cmdKey), shift = UInt32(shiftKey)
        // Old encoded value (popup editor) → KeyCombo → encoded again: unchanged.
        for binding in [HotkeyBinding(key: 14, modifiers: ctrl | opt | cmd), HotkeyBinding(key: 27, modifiers: ctrl),
                        HotkeyBinding(key: 16, modifiers: cmd | ctrl | opt), HotkeyBinding(key: 96, modifiers: ctrl | shift)] {
            let decoded = HotkeyBinding.decode(binding.encoded)!
            precondition(decoded == binding, "decode \(binding)")
            let combo = decoded.combo
            precondition(combo.code == binding.key && combo.modifiers == binding.modifiers, "combo \(binding)")
            precondition(HotkeyBinding(combo).encoded == binding.encoded, "round trip \(binding)")
        }
        // Keys outside the old popup list (Home, keypad) are kept now.
        precondition(HotkeyBinding.decode(HotkeyBinding(key: 115, modifiers: ctrl).encoded)?.key == 115)
        // Key 24 (= on US, ^ on JIS): an older saved "=" still means ⇧- on JIS; a recorded key 24 stays the physical key.
        let legacy = HotkeyBinding.decode(HotkeyBinding(key: 24, modifiers: cmd | ctrl).encoded)!
        let recorded = HotkeyBinding.decode(HotkeyBinding(KeyCombo(code: 24, modifiers: cmd | ctrl)).encoded)!
        if HotkeyBinding.isJIS {
            precondition(legacy.combo == KeyCombo(code: 27, modifiers: cmd | ctrl | shift))
            precondition(recorded.combo == KeyCombo(code: 24, modifiers: cmd | ctrl))
        } else {
            precondition(legacy.combo == KeyCombo(code: 24, modifiers: cmd | ctrl) && recorded.combo == legacy.combo)
        }
        precondition(HotkeyBinding.decode(-1) == nil && HotkeyBinding.decode(5) == nil)
        print("Passed encoded ↔ KeyCombo round trips, wider key range and the JIS key-24 rule (JIS: \(HotkeyBinding.isJIS))")
    }
}
