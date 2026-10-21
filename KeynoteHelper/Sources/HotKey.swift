import AppKit
import Carbon

/// The stored form of a hotkey (UserDefaults JSON: code, modifiers, label). Recording and registering use the shared
/// HotkeyField and HotkeySet (Shared/HotkeyRecorder); ShortcutCombo.swift converts to and from KeyCombo.
struct Shortcut: Codable, Equatable {
    var code: UInt32
    var modifiers: UInt32
    var label: String
    /// `km` is the Keyboard Maestro modifier value (⌘256 ⇧512 ⌥2048 ⌃4096), the same bits as Carbon's.
    init(code: UInt32, modifiers: UInt32, label: String) { self.code = code; self.modifiers = modifiers; self.label = label }
    init(_ code: UInt32, km: UInt32) { self.init(code: code, modifiers: km, label: KeyCombo(code: code, modifiers: km).label) }
    var signature: String { "\(code):\(modifiers)" }
    /// No ⌘ and no ⌃: the key also types a character (⌥L, ⇧1), so it is left to text editing.
    var typesCharacter: Bool { modifiers & UInt32(cmdKey | controlKey) == 0 }
}
