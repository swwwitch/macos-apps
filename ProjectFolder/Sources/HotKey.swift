import AppKit
import Carbon

/// The stored form of a hotkey (UserDefaults JSON: code, modifiers, label). Recording and registering use the shared
/// HotkeyField and HotkeySet (Shared/HotkeyRecorder); ShortcutCombo.swift converts to and from KeyCombo.
struct Shortcut: Codable, Equatable, Hashable {
    var code: UInt32
    var modifiers: UInt32
    var label: String
    var signature: String { "\(code):\(modifiers)" }

    static let command = UInt32(cmdKey), shift = UInt32(shiftKey), option = UInt32(optionKey), control = UInt32(controlKey)

    /// Keyboard Maestro modifiers (⌘256 ⇧512 ⌥2048 ⌃4096) are the same bits as Carbon's.
    static func km(_ code: UInt32, _ modifiers: UInt32, _ key: String) -> Shortcut {
        Shortcut(code: code, modifiers: modifiers, label: prefix(modifiers) + key)
    }
    static func prefix(_ m: UInt32) -> String {
        (m & control != 0 ? "⌃" : "") + (m & option != 0 ? "⌥" : "") + (m & shift != 0 ? "⇧" : "") + (m & command != 0 ? "⌘" : "")
    }
}

