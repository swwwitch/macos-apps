import AppKit
import Carbon

/// The stored form of a hotkey (UserDefaults JSON: code, modifiers, label). Recording and registering use the shared
/// HotkeyField and HotkeySet (Shared/HotkeyRecorder); ShortcutCombo.swift converts to and from KeyCombo.
struct Shortcut: Codable, Equatable {
    var code: UInt32
    var modifiers: UInt32
    var label: String
    /// ⌥⌘C — the KM macro's trigger (KeyCode 8, KM modifiers 2304 = ⌘256 + ⌥2048).
    static let clean = Shortcut(code: 8, modifiers: UInt32(cmdKey | optionKey), label: "⌥⌘C")
    var signature: String { "\(code):\(modifiers)" }
}

