import Foundation

/// Where a function hotkey is active. Missing key = global (behavior before 0.1.59), except the actions in `paletteDefaults`.
enum HotkeyScope: String, CaseIterable {
    case global, palette
    var title: String { self == .global ? L("scope.global") : L("scope.palette") }
    static func key(_ id: Int) -> String { "shortcutScope-\(id)" }
    /// 0.2.16: 表示形式を切り替え (10000) only acts on the palette, so it defaults to palette-only.
    static let paletteDefaults: Set<Int> = [10000]
    static func load(_ id: Int, defaults: UserDefaults = .standard) -> Self {
        defaults.string(forKey: key(id)).flatMap(Self.init(rawValue:)) ?? (paletteDefaults.contains(id) ? .palette : .global)
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
