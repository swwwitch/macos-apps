import AppKit
import Carbon

/// The stored form of a hotkey (UserDefaults JSON: code, modifiers, label). Recording and registering use the shared
/// HotkeyField and HotkeySet (Shared/HotkeyRecorder); ShortcutCombo.swift converts to and from KeyCombo.
struct Shortcut: Codable, Equatable {
    var code: UInt32
    var modifiers: UInt32
    var label: String
    /// ⇧⌘V — the KM macros' trigger (KeyCode 9, KM modifiers 768 = ⌘256 + ⇧512).
    static let paste = Shortcut(code: 9, modifiers: UInt32(cmdKey | shiftKey), label: "⇧⌘V")
    var signature: String { "\(code):\(modifiers)" }
}
