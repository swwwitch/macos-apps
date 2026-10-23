import Foundation

/// The stored Shortcut and the shared KeyCombo hold the same Carbon code and modifiers; the label is derived again.
extension Shortcut {
    init(_ combo: KeyCombo) { self.init(code: combo.code, modifiers: combo.modifiers, label: combo.label) }
    var combo: KeyCombo { KeyCombo(code: code, modifiers: modifiers) }
}
