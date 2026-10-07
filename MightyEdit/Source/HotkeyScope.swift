import Foundation

/// Where a function hotkey is active. Missing key = global (behavior before 0.1.59).
enum HotkeyScope: String, CaseIterable {
    case global, palette
    var title: String { self == .global ? L("scope.global") : L("scope.palette") }
    static func key(_ id: Int) -> String { "shortcutScope-\(id)" }
    static func load(_ id: Int, defaults: UserDefaults = .standard) -> Self {
        defaults.string(forKey: key(id)).flatMap(Self.init(rawValue:)) ?? .global
    }
    static func save(_ scope: Self, id: Int, defaults: UserDefaults = .standard) {
        defaults.set(scope.rawValue, forKey: key(id))
    }
    /// Whether an assigned, enabled, conflict-free hotkey stays registered right now.
    /// Blocked (excluded app or MightyEdit in front) always releases the key (B21).
    func shouldRegister(paletteVisible: Bool, blocked: Bool) -> Bool { !blocked && (self == .global || paletteVisible) }
    /// Re-check at key release: a palette-only hotkey does nothing once the palette is gone.
    func allowsAction(paletteVisible: Bool) -> Bool { self == .global || paletteVisible }
}
