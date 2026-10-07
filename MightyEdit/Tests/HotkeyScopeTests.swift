import Foundation

@main struct HotkeyScopeTests {
    static func main() {
        let suite = "HotkeyScopeTests-\(ProcessInfo.processInfo.processIdentifier)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        // Existing users have no key: every hotkey stays global (behavior before 0.1.59).
        precondition(defaults.object(forKey: HotkeyScope.key(2)) == nil)
        precondition(HotkeyScope.load(2, defaults: defaults) == .global)
        precondition(HotkeyScope.key(10000) == "shortcutScope-10000")
        HotkeyScope.save(.palette, id: 2, defaults: defaults)
        precondition(defaults.string(forKey: "shortcutScope-2") == "palette")
        precondition(HotkeyScope.load(2, defaults: defaults) == .palette)
        precondition(HotkeyScope.load(4, defaults: defaults) == .global) // per action
        let relaunched = UserDefaults(suiteName: suite)!
        precondition(HotkeyScope.load(2, defaults: relaunched) == .palette)
        HotkeyScope.save(.global, id: 2, defaults: defaults)
        precondition(defaults.string(forKey: "shortcutScope-2") == "global" && HotkeyScope.load(2, defaults: defaults) == .global)
        defaults.set("bogus", forKey: HotkeyScope.key(3))
        precondition(HotkeyScope.load(3, defaults: defaults) == .global) // unknown value falls back
        precondition(HotkeyScope.global.title == "すべてのアプリ" && HotkeyScope.palette.title == "パレット表示中のみ")
        // Registration: scope × palette visible × blocked (excluded app or MightyEdit in front).
        let expected: [(HotkeyScope, Bool, Bool, Bool)] = [
            (.global, false, false, true), (.global, true, false, true),
            (.global, false, true, false), (.global, true, true, false),
            (.palette, false, false, false), (.palette, true, false, true),
            (.palette, false, true, false), (.palette, true, true, false)
        ]
        for (scope, visible, blocked, register) in expected {
            precondition(scope.shouldRegister(paletteVisible: visible, blocked: blocked) == register, "\(scope) visible=\(visible) blocked=\(blocked)")
        }
        // Action-time re-check: a palette-only key does nothing once the palette is hidden.
        precondition(HotkeyScope.global.allowsAction(paletteVisible: false) && HotkeyScope.global.allowsAction(paletteVisible: true))
        precondition(!HotkeyScope.palette.allowsAction(paletteVisible: false) && HotkeyScope.palette.allowsAction(paletteVisible: true))
        print("Passed scope default, persistence, fallback, registration matrix and action-time checks")
    }
}
