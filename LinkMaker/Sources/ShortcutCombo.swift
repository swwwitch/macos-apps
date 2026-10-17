import Foundation

/// The saved format stays Shortcut JSON (shortcuts, paletteShortcut); the shared HotkeyField works in KeyCombo.
extension KeyCombo {
    init(_ shortcut: Shortcut) { self.init(code: shortcut.code, modifiers: shortcut.modifiers) }
}
extension Shortcut {
    init(_ combo: KeyCombo) { self.init(code: combo.code, modifiers: combo.modifiers, label: combo.label) }
}
