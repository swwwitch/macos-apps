import Foundation
import Carbon
@main struct ShortcutTests {
    static func main() throws {
        let name = "SuperKakkoReplace.Tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let custom = Shortcut(code: 40, modifiers: 512, label: "test")
        defaults.set(try JSONEncoder().encode(["round": custom, "smartSingle": custom]), forKey: "bracketBindings")
        defaults.set(["example.excluded"], forKey: "excluded")
        defaults.set(false, forKey: "keepRunning")
        let migrated = Shortcut.loadBindings(defaults: defaults)
        precondition(migrated["round"]?.signature == Shortcut.initial.signature)
        precondition(migrated["smartSingle"]?.signature == custom.signature)
        precondition(defaults.data(forKey: "bindingsBeforeArticle") != nil)
        precondition(defaults.stringArray(forKey: "excluded") == ["example.excluded"])
        precondition(!defaults.bool(forKey: "keepRunning"))
        precondition(defaults.integer(forKey: "articleShortcutRevision") == 1)
        precondition(Shortcut.articleDefaults.count == 26)
        precondition(Set(Shortcut.articleDefaults.values.map(\.signature)).count == 26)
        let full = UInt32(cmdKey | shiftKey), half = UInt32(cmdKey | shiftKey | optionKey), force = UInt32(cmdKey | controlKey | optionKey)
        let expected: [(String, UInt32, UInt32)] = [
            ("round",25,full),("square",33,full),("lenticular",24,full),("angle",30,full),
            ("doubleAngle",42,full),("corner",41,full),("curly",29,full),("doubleCorner",27,full),("smartDouble",39,full),
            ("asciiRound",29,half),("asciiSquare",33,half),("asciiCurly",30,half),("asciiAngle",47,half),("asciiSingle",41,half),("asciiDouble",39,half),
            ("force_round",25,force),("force_square",33,force),("force_corner",41,force),("force_angle",30,force),("force_doubleAngle",42,force),
            ("css",44,force),("html",29,force),("spaces",49,full),("removeOuter",51,full),("removeAll",51,half),("palette",32,half)
        ]
        for (id,code,modifiers) in expected {
            precondition(migrated[id]?.code == code && migrated[id]?.modifiers == modifiers, id)
            precondition(BracketAction.ids.contains(id), "Unregistered action: \(id)")
        }
        defaults.set(try JSONEncoder().encode(["round":custom]), forKey:"bracketBindings")
        precondition(Shortcut.loadBindings(defaults: defaults)["round"]?.signature == custom.signature)
        defaults.set(try JSONEncoder().encode([String: Shortcut]()), forKey: "bracketBindings")
        precondition(Shortcut.loadBindings(defaults: defaults).isEmpty)
        print("PASS: 26 article key mappings, uniqueness, dispatch IDs, one-time migration, backup and later custom/cleared settings")
    }
}
