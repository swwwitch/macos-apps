import AppKit
import Carbon

/// The stored form of a hotkey (UserDefaults JSON: code, modifiers, label). Recording and registering use the shared
/// HotkeyField and HotkeySet (Shared/HotkeyRecorder); ShortcutCombo.swift converts to and from KeyCombo.
struct Shortcut: Codable, Equatable {
    var code: UInt32
    var modifiers: UInt32
    var label: String
    /// ⌃⌥V — the KM macro's trigger (KeyCode 9, KM modifiers 6144 = ⌃4096 + ⌥2048).
    static let paste = Shortcut(code: 9, modifiers: UInt32(controlKey | optionKey), label: "⌃⌥V")
    /// ⌃⌥⌘C — copy the selection and add its lines to the list. Key code 8 = C.
    /// Not ⌥C: it types "ç" and LinkMaker already uses it.
    static let add = Shortcut(code: 8, modifiers: UInt32(controlKey | optionKey | cmdKey), label: "⌃⌥⌘C")
    /// The default of 1.3.0, replaced on launch unless the user chose it again.
    static let oldAdd = Shortcut(code: 8, modifiers: UInt32(optionKey), label: "⌥C")
    var signature: String { "\(code):\(modifiers)" }
}
