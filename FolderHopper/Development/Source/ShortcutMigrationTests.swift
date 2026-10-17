import Foundation
import Carbon

// Run: swiftc -parse-as-library Source/GlobalShortcut.swift Source/ShortcutMigrationTests.swift -o /tmp/t && /tmp/t
@main struct ShortcutMigrationTests {
    static func main() {
        let suite = "ShortcutMigrationTests-\(ProcessInfo.processInfo.processIdentifier)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let ctrlOptCmd = UInt32(controlKey | optionKey | cmdKey)
        // Popup indices (0.1.96 and earlier) → saved combo; old keys stay.
        defaults.set(3, forKey: "shortcutModifierIndex")          // ⌃⌘
        defaults.set(25, forKey: "shortcutKeyIndex")              // Z
        defaults.set(Int(controlKey | shiftKey), forKey: "applicationsShortcutModifiers")
        defaults.set(26, forKey: "applicationsShortcutKeyIndex")  // Space
        GlobalShortcut.migrate(defaults)
        let window = GlobalShortcut.stored(defaults.object(forKey: "shortcutCombo"))!
        precondition(window.code == 6 && window.modifiers == UInt32(controlKey | cmdKey))
        let apps = GlobalShortcut.stored(defaults.object(forKey: "applicationsShortcutCombo"))!
        precondition(apps.code == 49 && apps.modifiers == UInt32(controlKey | shiftKey))
        precondition(defaults.integer(forKey: "shortcutKeyIndex") == 25 && defaults.object(forKey: "applicationsShortcutModifiers") != nil)
        // Migration runs once: a later change is not overwritten.
        defaults.set(GlobalShortcut.storable(code: 0, modifiers: ctrlOptCmd), forKey: "shortcutCombo")
        GlobalShortcut.migrate(defaults)
        precondition(GlobalShortcut.stored(defaults.object(forKey: "shortcutCombo"))!.code == 0)
        // Nothing saved: the defaults ⌃⌥⌘M and ⌃⌥⌘⇧A.
        let fresh = UserDefaults(suiteName: suite + "-fresh")!
        defer { fresh.removePersistentDomain(forName: suite + "-fresh") }
        GlobalShortcut.migrate(fresh)
        precondition(GlobalShortcut.stored(fresh.object(forKey: "shortcutCombo"))! == (46, ctrlOptCmd))
        precondition(GlobalShortcut.stored(fresh.object(forKey: "applicationsShortcutCombo"))! == (0, GlobalShortcut.applicationsDefaultModifiers))
        // Round trip and rejection of a key without ⌃⌥⌘.
        let value = GlobalShortcut.storable(code: 14, modifiers: UInt32(optionKey | cmdKey))
        precondition(GlobalShortcut.stored(value)! == (14, UInt32(optionKey | cmdKey)))
        precondition(GlobalShortcut.stored(GlobalShortcut.storable(code: 14, modifiers: UInt32(shiftKey))) == nil)
        print("PASS: popup indices → combo, one-time migration, defaults, round trip")
    }
}
