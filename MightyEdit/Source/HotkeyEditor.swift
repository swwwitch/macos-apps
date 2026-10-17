import AppKit
import Carbon

/// A saved MightyEdit hotkey: shortcutDigit-<id> and paletteInvocation.binding hold `encoded` (1000 + modifiers × 128 + key).
/// The settings record keys with the shared HotkeyField (Shared/HotkeyRecorder) and convert through KeyCombo.
struct HotkeyBinding: Equatable {
    var key: UInt32
    var modifiers: UInt32
    /// Recorded from the physical key: no JIS remapping in `actual` (see literalOffset).
    var literal = false
    /// Added to `encoded` only for a literal binding whose key would otherwise be remapped (key 24 on JIS),
    /// so every other saved value keeps the old form. A multiple of 128, so the key part stays readable.
    static let literalOffset = 100_000_000
    var encoded: Int { (literal && Self.isJIS && key == 24 ? Self.literalOffset : 0) + 1000 + Int(modifiers) * 128 + Int(key) }
    static func decode(_ value: Int) -> Self? {
        if value >= literalOffset { return decode(value - literalOffset).map { var b = $0; b.literal = true; return b } }
        guard value >= 1000 else { return nil }
        let v = value - 1000
        return Self(key: UInt32(v % 128), modifiers: UInt32(v / 128))
    }
    static var isJIS: Bool { KBGetLayoutType(Int16(LMGetKbdType())) == kKeyboardJIS }
    /// The physical key to register. Older settings chose "=" from a list; on JIS that is ⇧-.
    var actual: Self {
        if !literal && key == 24 && Self.isJIS {
            return Self(key: 27, modifiers: modifiers | UInt32(shiftKey))
        }
        return self
    }
    var label: String { combo.label }
    /// The shared recorder's form, as the key is really registered.
    var combo: KeyCombo { KeyCombo(code: actual.key, modifiers: actual.modifiers) }
    init(key: UInt32, modifiers: UInt32, literal: Bool = false) { self.key = key; self.modifiers = modifiers; self.literal = literal }
    /// A key recorded by the shared field.
    init(_ combo: KeyCombo) { self.init(key: combo.code, modifiers: combo.modifiers, literal: true) }
}
