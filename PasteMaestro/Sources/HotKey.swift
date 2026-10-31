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
    /// ⌃⌘C — copy the selection and add its lines to the list. Key code 8 = C.
    static let add = Shortcut(code: 8, modifiers: UInt32(controlKey | cmdKey), label: "⌃⌘C")
    /// Historical default; retained for compatibility with previously stored values.
    static let oldAdd = Shortcut(code: 8, modifiers: UInt32(optionKey), label: "⌥C")
    static let increment = Shortcut(code: 9, modifiers: UInt32(optionKey), label: "⌥V")
    static let style = Shortcut(code: 9, modifiers: UInt32(cmdKey | shiftKey), label: "⇧⌘V")
    var signature: String { "\(code):\(modifiers)" }
}
